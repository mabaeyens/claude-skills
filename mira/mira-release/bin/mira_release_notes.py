#!/usr/bin/env python3
# Usage: mira_release_notes.py <build_number> <notes>
# Posts "What to Test" notes to all builds for this version (iOS + macOS).
# Waits up to 10 min for the build to appear in ASC after upload.
# On any error prints a warning and exits 0 — never blocks the release.
import base64, json, os, subprocess, ssl, sys, time
import urllib.request, urllib.error

CREDS_FILE = os.path.expanduser("~/.appstoreconnect/mira-release-credentials")
BUNDLE_ID  = "com.mab.OllamaSearch"

if len(sys.argv) < 3:
    print("  Usage: mira_release_notes.py <build_number> <notes>")
    sys.exit(0)

BUILD_VERSION = sys.argv[1]
NOTES = sys.argv[2]

if not os.path.exists(CREDS_FILE):
    print(f"  ⚠ Credentials not found at {CREDS_FILE} — skipping release notes")
    sys.exit(0)

creds = dict(line.strip().split("=", 1) for line in open(CREDS_FILE) if "=" in line)
KEY_ID    = creds["ASC_KEY_ID"]
ISSUER_ID = creds["ASC_ISSUER_ID"]
KEY_PATH  = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")

if not os.path.exists(KEY_PATH):
    print(f"  ⚠ Key not found at {KEY_PATH} — skipping release notes")
    sys.exit(0)

def b64url(data):
    if isinstance(data, str): data = data.encode()
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def make_jwt():
    hdr = b64url(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}, separators=(",", ":")))
    now = int(time.time())
    pld = b64url(json.dumps({"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}, separators=(",", ":")))
    msg = f"{hdr}.{pld}".encode()
    r = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY_PATH, "-"], input=msg, capture_output=True)
    if r.returncode != 0:
        print(f"  ⚠ openssl sign failed — skipping release notes")
        sys.exit(0)
    der = r.stdout
    i = 2
    rl = der[i + 1]; rv = der[i + 2:i + 2 + rl].lstrip(b"\x00").rjust(32, b"\x00")
    i += 2 + rl
    sl = der[i + 1]; sv = der[i + 2:i + 2 + sl].lstrip(b"\x00").rjust(32, b"\x00")
    return f"{hdr}.{pld}.{b64url(rv + sv)}"

def api(method, path, body=None):
    token = make_jwt()
    req = urllib.request.Request(
        f"https://api.appstoreconnect.apple.com{path}",
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    if body:
        req.data = json.dumps(body).encode()
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx) as resp:
            data = resp.read()
            return json.loads(data) if data else {}
    except urllib.error.HTTPError as e:
        if e.code in (204, 409):
            return {}
        err = e.read().decode()[:300]
        print(f"  ⚠ API {method} {path} → {e.code}: {err} — skipping release notes")
        sys.exit(0)

apps = api("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
if not apps.get("data"):
    print("  ⚠ App not found via API — skipping release notes")
    sys.exit(0)
app_id = apps["data"][0]["id"]

# Wait for builds to appear (iOS + macOS both upload; may take a few minutes)
build_ids = []
for attempt in range(20):
    builds = api("GET", f"/v1/builds?filter[app]={app_id}&filter[version]={BUILD_VERSION}&sort=-version&limit=10")
    data = builds.get("data", [])
    if data:
        build_ids = [b["id"] for b in data]
        print(f"  Found {len(build_ids)} build(s) for version {BUILD_VERSION}")
        break
    print(f"  Build not yet in ASC, waiting 30s… ({attempt + 1}/20)")
    time.sleep(30)

if not build_ids:
    print("  ⚠ Builds did not appear in ASC within 10 min — skipping release notes")
    sys.exit(0)

for bid in build_ids:
    locs = api("GET", f"/v1/builds/{bid}/betaBuildLocalizations")
    loc_data = locs.get("data", [])
    if loc_data:
        loc_id = loc_data[0]["id"]
        api("PATCH", f"/v1/betaBuildLocalizations/{loc_id}",
            {"data": {"type": "betaBuildLocalizations", "id": loc_id,
                      "attributes": {"whatsNew": NOTES}}})
        print(f"  ✅ 'What to Test' updated for build {bid}")
    else:
        api("POST", "/v1/betaBuildLocalizations",
            {"data": {"type": "betaBuildLocalizations",
                      "attributes": {"locale": "en-US", "whatsNew": NOTES},
                      "relationships": {"build": {"data": {"type": "builds", "id": bid}}}}})
        print(f"  ✅ 'What to Test' created for build {bid}")
