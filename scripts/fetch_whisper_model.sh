#!/bin/bash
# Fetch the bundled offline Whisper model + tokenizer into WhisperBundle/.
# Usage: scripts/fetch_whisper_model.sh [tiny|base|small]   (default: base)
# Run once from the repo root before building (WhisperBundle/ is gitignored).
# Layout matches WhisperKit's offline expectations:
#   WhisperBundle/openai_whisper-<M>/                 -> WhisperKitConfig.modelFolder
#   WhisperBundle/tok/models/openai/whisper-<M>/...   -> tokenizerFolder/models/<repo-id>
set -e
cd "$(dirname "$0")/.."

M="${1:-base}"
ROOT="WhisperBundle"
MREPO="argmaxinc/whisperkit-coreml"
TREPO="openai/whisper-$M"
MODELDIR="openai_whisper-$M"

rm -rf "$ROOT"
mkdir -p "$ROOT/$MODELDIR" "$ROOT/tok/models/openai/whisper-$M"

echo "Downloading CoreML model ($MREPO/$MODELDIR)…"
curl -s "https://huggingface.co/api/models/$MREPO/tree/main/$MODELDIR?recursive=true" \
  | python3 -c "import sys,json;[print(f['path']) for f in json.load(sys.stdin) if f.get('type')=='file']" \
  | while read -r p; do
        mkdir -p "$ROOT/$(dirname "$p")"
        curl -sL "https://huggingface.co/$MREPO/resolve/main/$p" -o "$ROOT/$p"
    done

echo "Downloading tokenizer ($TREPO)…"
for f in tokenizer.json tokenizer_config.json config.json special_tokens_map.json \
         added_tokens.json vocab.json merges.txt normalizer.json \
         generation_config.json preprocessor_config.json; do
    curl -sL "https://huggingface.co/$TREPO/resolve/main/$f" -o "$ROOT/tok/models/openai/whisper-$M/$f"
done

echo "Model: $M   Total: $(du -sh "$ROOT" | cut -f1)"
