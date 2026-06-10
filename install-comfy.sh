#!/usr/bin/env bash
set -euo pipefail

VERSION="$(date +%Y.%m.%d-%H%M)"
ENV="comfy-$VERSION"
WORKSPACE="$HOME/apps/comfy/installs/$VERSION"

conda create --name "$ENV" python=3.13 -y
eval "$(conda shell.bash hook)"
conda activate "$ENV"

# Matix-nio is an optional package used in ComfyUI Manager. Adding it here silences a warning that appears on launch.
pip install comfy-cli setuptools matrix-nio

comfy --workspace="$WORKSPACE" --skip-prompt install --nvidia

# Disabled: comfyui-inspire-pack comfyui-impact-subpack ComfyUI_UltimateSDUpscale
comfy node install ComfyUI-KJNodes rgthree-comfy ComfyUI-Easy-Use comfyui-impact-pack ComfyUI_essentials ComfyUI-GGUF comfyui-videohelpersuite comfyui-inspire-pack comfyui-impact-subpack ComfyUI_UltimateSDUpscale was-ns https://github.com/ClownsharkBatwing/RES4LYF

rm -rf "$WORKSPACE/models"
ln -s ~/apps/comfy/common/models "$WORKSPACE/models"

mkdir -p "$WORKSPACE/user/default"
ln -s ~/apps/comfy/common/workflows "$WORKSPACE/user/default/workflows"

rm -rf "$WORKSPACE/output"
ln -s ~/apps/comfy/common/output "$WORKSPACE/output"

LAUNCH_SCRIPT="$WORKSPACE/run.sh"


cat << EOF > "$LAUNCH_SCRIPT"
set -euo pipefail

eval "\$(conda shell.bash hook)"
conda activate "$ENV"

comfy --workspace="$WORKSPACE" launch
EOF


chmod +x "$LAUNCH_SCRIPT"

echo ""
echo "Done! To launch:"
echo "$LAUNCH_SCRIPT"
