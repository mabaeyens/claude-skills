#!/usr/bin/env python3
# Expires old TestFlight builds, keeping the 4 most recent (2 iOS + 2 macOS).
# On any error prints a warning and exits 0 — never blocks the release.
import base64, json, os, subprocess, ssl, sys, time
import urllib.request, urllib.error

CREDS_FILE = os.path.expanduser("~/.appstoreconnect/mira-release-credentials")
BUNDLE_ID  = "com.mab.OllamaSearch"
KEEP       = 4  # 2 iOS + 2 macOS

if not os.path.exists(CREDS_FILE):
    print(f"  ⚠ Credentials not found at {CREDS_FILE} — skipping expiration")
    sys.exit(0)

creds = dict(line.strip().split("=", 1) for line in open(CREDS_FILE) if "=" in line)
KEY_ID    = creds["ASC_KEY_ID"]
ISSUER_ID = creds["ASC_ISSUER_ID"]
KEY_PATH  = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")

if not os.path.exists(KEY_PATH):
    print(f"  ⚠ Key not found at {KEY_PATH} — skipping expiration")
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
        print(f"  ⚠ openssl sign failed: {r.stderr.decode().strip()} — skipping expiration")
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
        print(f"  ⚠ API {method} {path} → {e.code}: {err} — skipping expiration")
        sys.exit(0)

apps = api("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
if not apps.get("data"):
    print("  ⚠ App not found via API — skipping expiration")
    sys.exit(0)
app_id = apps["data"][0]["id"]

# Fetch all non-expired builds sorted newest first
all_builds, url = [], f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=200"
while url:
    page = api("GET", url)
    for b in page.get("data", []):
        if not b["attributes"].get("expired", False):
            all_builds.append(b)
    next_url = page.get("links", {}).get("next", "")
    url = next_url.replace("https://api.appstoreconnect.apple.com", "") if next_url else None

to_expire = all_builds[KEEP:]
print(f"  Active builds: {len(all_builds)}, keeping {min(KEEP, len(all_builds))}, expiring {len(to_expire)}")
for b in all_builds:
    a = b["attributes"]
    marker = "KEEP" if b in all_builds[:KEEP] else "EXPIRE"
    print(f"  [{marker}] v{a['version']} uploaded {a['uploadedDate'][:10]}")

for b in to_expire:
    a = b["attributes"]
    print(f"  Expiring v{a['version']} uploaded {a['uploadedDate'][:10]}", end=" ")
    api("PATCH", f"/v1/builds/{b['id']}",
        {"data": {"type": "builds", "id": b["id"], "attributes": {"expired": True}}})
    print("✅")

print(f"\n  Done. Kept {min(KEEP, len(all_builds))} most recent build(s).")
