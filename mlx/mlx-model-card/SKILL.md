---
name: mlx-model-card
description: Write or refresh a real HuggingFace model card for an MLX-converted model published to mlx-community — replaces the bare auto-generated boilerplate (title + pip-install snippet, no description) with an actual description, quantization notes, and family context pulled from the source model. Invoke with /mlx-model-card <mlx-community-repo> [source-repo].
allowed-tools: Bash, Read, Write, WebFetch
---

`mlx_lm`'s and `mlx_vlm`'s own `create_model_card()`/`upload_to_hub()` only ever
write a title, a one-line "converted from X using mlx-lm/vlm version Y", and a
`pip install` + usage snippet. They never carry over an actual description of
what the model is, what it's for, or what changed in conversion. This skill
fills that gap.

## Inputs

- `$1` — target repo, e.g. `mlx-community/Ministral-3-3B-Base-2512-4bit`
- `$2` (optional) — source repo. If omitted, read it from the target's current
  `README.md` front matter (`base_model:` field).

## Steps

1. **Fetch the target's current card** (`https://huggingface.co/{target}/raw/main/README.md`)
   to get its existing front matter (`base_model`, `license`, `tags`, `pipeline_tag`,
   `language`, etc.) — preserve these, don't regenerate them.

2. **Fetch the target's `config.json`** (`https://huggingface.co/{target}/raw/main/config.json`)
   to determine:
   - `quantization` / `quantization_config` block → bits, group_size, mode
   - whether `vision_config` is present → this is a vision-language model;
     note that vision tower + multimodal projector are conventionally kept at
     full precision (mlx-vlm's `skip_multimodal_module` policy skips
     quantizing them) even in an otherwise-quantized model — say so explicitly,
     don't let a reader assume the whole model is N-bit.
   - `architectures` — sanity check this matches what the description says.

3. **Fetch the source repo's real README** (`https://huggingface.co/{source}/raw/main/README.md`).
   Pull out, paraphrasing rather than copying wholesale:
   - What the model actually is (architecture summary, size, key capabilities)
   - Use cases it's positioned for
   - Any family/sibling table (other sizes or variants) — reproduce as a table
     linking to the *mlx-community* equivalents where they exist (check via
     the HF API, `api/models?search=...&author=mlx-community`), not just the
     original org's siblings
   - License

4. **Compose the new card body** (front matter stays as fetched in step 1;
   only `card.text` / everything after the closing `---` changes):

   ```markdown
   # {target}

   {1-2 paragraph real description, paraphrased from source step 3 — what this
   model is, size, key capabilities, intended use cases}

   This is an MLX conversion of [`{source}`](https://huggingface.co/{source}).
   Refer to the [original model card](https://huggingface.co/{source}) for the
   full details.

   ## Quantization notes

   - {bits}-bit, group_size={group_size}, mode={mode} (language model layers)
   - {if VLM: "Vision tower and multimodal projector are kept at full
     precision — only the language backbone is quantized."}
   - Output size: {size on disk}

   ## Model family

   {table of sibling sizes/variants, linking mlx-community versions where
   converted, otherwise the original org's repo — omit this section if there
   are no siblings}

   ## Use with mlx

   {the standard pip-install + generate snippet — mlx-lm for text-only,
   mlx-vlm with an --image example for vision-language models. Match whichever
   tool actually produced this conversion; check `library_name` in the
   original front matter or how the repo's own weights are laid out
   (presence of vision_tower.* keys) if unsure.}

   ## License

   {license from front matter, one line, link to source repo's license terms
   if it references an external policy (e.g. a gated-use policy)}
   ```

5. **Upload only the README.md**, not the model weights:
   ```python
   from huggingface_hub import HfApi
   api = HfApi()
   api.upload_file(
       path_or_fileobj=<local README.md path>,
       path_in_repo="README.md",
       repo_id="{target}",
   )
   ```

## Notes

- Don't invent benchmark numbers, eval scores, or capabilities not stated in
  the source card — if the source doesn't say it, leave it out rather than
  guessing.
- If multiple models share one skill invocation (e.g. a family of 3 you just
  converted), fetch the source family table once and reuse it across all
  three cards' "Model family" sections rather than re-fetching per model.
