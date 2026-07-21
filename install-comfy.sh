#!/usr/bin/env bash
set -euo pipefail

CreateLinkedDirectory() {
  local directory1
  directory1="$(realpath -m "$1")"

  local directory2
  directory2="$(realpath -m "$2")"

  # If target doesn't exist, copy from source or create a new folder
  if [ ! -d "$directory1" ]; then
    mkdir -p "$(dirname "$directory1")"
    if [ -d "$directory2" ]; then
      cp -r "$directory2" "$directory1"
    else
      mkdir -p "$directory1"
    fi
  fi

  rm -rf "$directory2"
  ln -s "$directory1" "$directory2"
}

# CD to the script location so relative paths work
cd "$(dirname "$(readlink -f "$0")")"

VERSION="$(date +%Y.%m.%d-%H%M)"
ENV="comfy-$VERSION"
WORKSPACE="$(realpath -m "../../installs/$VERSION")"

conda create --name "$ENV" python=3.13 -y
eval "$(conda shell.bash hook)"
conda activate "$ENV"

# Matix-nio is an optional package used in ComfyUI Manager. Adding it here silences a warning that appears on launch.
pip install comfy-cli setuptools sageattention matrix-nio

comfy --workspace="$WORKSPACE" --skip-prompt install --nvidia

comfy node install ComfyUI-KJNodes rgthree-comfy ComfyUI-Easy-Use comfyui-impact-pack ComfyUI_essentials ComfyUI-GGUF comfyui-videohelpersuite comfyui-impact-subpack ComfyUI_UltimateSDUpscale
comfy node install https://github.com/ClownsharkBatwing/RES4LYF

cp config/rgthree_config.json "$WORKSPACE/custom_nodes/rgthree-comfy"

mkdir -p "$WORKSPACE/user/default/workflows"
CreateLinkedDirectory ../models    "$WORKSPACE/models"
CreateLinkedDirectory ../output    "$WORKSPACE/output"
CreateLinkedDirectory ../workflows "$WORKSPACE/user/default/workflows"

LAUNCH_SCRIPT="$WORKSPACE/run.sh"


cat << EOF > "$LAUNCH_SCRIPT"
#!/usr/bin/env bash
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
