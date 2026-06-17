#!/usr/bin/env bash
set -euo pipefail

MODELS_DIR="../models"

if [ $# -eq 0 ]; then
    find "$MODELS_DIR" -type f -exec sha256sum {} \;
else
    pattern=$(IFS='|'; echo "$*")
    find "$MODELS_DIR" -type f | while IFS= read -r file; do
        if basename "$file" | grep -qiE "$pattern"; then
            sha256sum "$file"
        fi
    done
fi
