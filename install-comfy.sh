#!/usr/bin/env bash
set -euo pipefail

VERSION="$(date +%Y.%m.%d-%H%M)"
ENV="comfy-$VERSION"
WORKSPACE="$HOME/apps/comfy/installs/$VERSION"

conda create --name "$ENV" python=3.13 -y
eval "$(conda shell.bash hook)"
conda activate "$ENV"

# Matix-nio is an optional package used in ComfyUI Manager. Adding it here silences a warning that appears on launch.
pip install comfy-cli setuptools sageattention matrix-nio

comfy --workspace="$WORKSPACE" --skip-prompt install --nvidia

comfy node install ComfyUI-KJNodes rgthree-comfy ComfyUI-Easy-Use comfyui-impact-pack ComfyUI_essentials ComfyUI-GGUF comfyui-videohelpersuite comfyui-impact-subpack ComfyUI_UltimateSDUpscale was-ns
comfy node install https://github.com/ClownsharkBatwing/RES4LYF

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

LOCAL_BIN="$HOME/.local/bin"
WRAPPER="$LOCAL_BIN/launch-comfy"
mkdir -p "$LOCAL_BIN"

cat << EOF > "$WRAPPER"
#!/usr/bin/env bash
exec "$LAUNCH_SCRIPT"
EOF

chmod +x "$WRAPPER"

case ":$PATH:" in
    *":$LOCAL_BIN:"*)
        ;;
    *)
        echo ""
        echo "Note: $LOCAL_BIN is not in your PATH."
        echo "Add this line to your ~/.bashrc:"
        echo "  export PATH=\"$LOCAL_BIN:\$PATH\""
        ;;
esac

echo ""
echo "Done! To launch, either run:"
echo "  $LAUNCH_SCRIPT"
echo "  launch-comfy   (if ~/.local/bin is in your PATH)"
