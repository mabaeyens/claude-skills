---
name: mlx-convert
description: Convert a HuggingFace model to MLX and publish it to mlx-community, end to end (download, pick the right tool, convert preserving all modalities, verify, write a real card, upload, update tracking docs, clean up locally) via a single script -- no manual steps to remember. Invoke with /mlx-convert <hf-repo> [q-bits] [q-group-size].
allowed-tools: Bash, Read
---

This skill is a thin wrapper. All the actual logic lives in
`mlx-conversions/scripts/pipeline.py` -- run it, don't re-derive the steps by
hand:

```bash
cd ~/Projects/mlx-conversions
source ~/.zprofile   # HF_TOKEN
uv run python scripts/pipeline.py --hf-path <source-repo> --q-bits 4 --q-group-size 64
```

For an unquantized (bf16 passthrough) build of a vision-language model:
```bash
uv run python scripts/pipeline.py --hf-path <source-repo> --no-quantize
```

## What the script does (so you know what NOT to redo manually)

1. Fetches the source's `config.json`, decides `mlx_lm` (text-only) vs
   `mlx_vlm` (vision-language) automatically -- checks for
   `vision_config`/`audio_config` or a `*ForConditionalGeneration`
   architecture. Never assume text-only.
2. Checks `mlx-community` doesn't already have this exact repo/quant first --
   exits early if so.
3. Converts, preserving whatever modalities the source has (never silently
   drops vision/audio components -- this was a real bug found 2026-07-18,
   see `mlx-conversions/specs/model-verification.md`).
4. Uploads to the target repo (defaults to `mlx-community/<name>-<bits>bit`).
5. Runs `scripts/verify.py`'s structural (tensor-prefix diff) and functional
   (real generation, image+text too for VLMs) checks.
6. Writes a real model card: description pulled from the source, honest
   verification-status note, quantization/provenance notes, discoverability
   tags.
7. Updates `BACKLOG.md` (checks off the source if it was a tracked
   candidate) and appends a `CHANGELOG.md` entry.
8. Deletes the local copy once verified. Keeps it (for debugging) only if
   verification failed.

## When NOT to use this

- A one-off fix to something already published (e.g. just re-uploading a
  corrected README) -- use the specific script for that
  (`scripts/write_model_cards.py`, `scripts/fix_processor_metadata.py`), not
  the full pipeline.
- Publishing multiple precision variants of the *same* family in one go --
  `scripts/convert_all_precisions.py` already encodes that loop; `pipeline.py`
  handles one (source, target) conversion at a time.
- Text-only models with `--no-quantize` -- not supported yet
  (`scripts/convert.py` always quantizes); the script will refuse and tell
  you so rather than silently ignoring the flag.

## After running

Report what got published (or why it was skipped/failed) concisely. Don't
re-explain the steps above -- the user already knows what the script does
once it's been run a few times; just report the outcome.
