#!/usr/bin/env bash
set -eo pipefail

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

BuildSageAttention() {
  local SAGEATTENTION_WORKSPACE="/tmp/sageattention"
  local export MAX_JOBS=$(nproc)
  local export NVCC_APPEND_FLAGS="--threads $(nproc)"

  rm -rf "$SAGEATTENTION_WORKSPACE"
  git clone --depth 1 https://github.com/thu-ml/SageAttention.git "$SAGEATTENTION_WORKSPACE"
  pushd "$SAGEATTENTION_WORKSPACE"
  pip install --no-build-isolation --no-cache-dir .
  popd
  rm -rf "$SAGEATTENTION_WORKSPACE"
}

# CD to the script location so relative paths work
cd "$(dirname "$(readlink -f "$0")")"

# Parse command line flags
INSTALL_SAGE=false
for arg in "$@"; do
  case $arg in
    --install-sage)
      INSTALL_SAGE=true
      shift
      ;;
  esac
done

# Setup Variables
VERSION="$(date +%Y.%m.%d-%H%M)"
ENV="comfy-$VERSION"
WORKSPACE="$(realpath -m "../../installs/$VERSION")"
COMMON="$(realpath -m "..")"

# Create and activate conda environment
conda create --name "$ENV" python=3.12 -y
eval "$(conda shell.bash hook)"
conda activate "$ENV"

# Install pip packages (matrix-nio is just to remove some warnings on startup)
pip install comfy-cli triton matrix-nio

if [ "$INSTALL_SAGE" = true ]; then
  # Install CUDA compiler for Sage Attention
  conda install -c conda-forge cuda-toolkit=13.0 -y

  # Install additional build tools
  pip install ninja setuptools wheel packaging

  # Install Pytorch for CUDA 13.0
  pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130

  BuildSageAttention
else
  echo "Skipping SageAttention installation."
fi

# Install comfy
COMFY_INSTALL_ARGS=(--nvidia --fast-deps)

if [ "$INSTALL_SAGE" = true ]; then
  COMFY_INSTALL_ARGS+=(--skip-torch-or-directml)
fi

echo comfy --workspace="$WORKSPACE" --skip-prompt install "${COMFY_INSTALL_ARGS[@]}"

comfy --workspace="$WORKSPACE" install "${COMFY_INSTALL_ARGS[@]}"

# Install custom nodes
comfy node install --uv-compile --exit-on-fail ComfyUI-KJNodes rgthree-comfy ComfyUI-Easy-Use comfyui-impact-pack comfyui-impact-subpack ComfyUI_essentials comfyui-videohelpersuite ComfyUI_UltimateSDUpscale https://github.com/ClownsharkBatwing/RES4LYF https://github.com/xmarre/ComfyUI-Spectrum-MiniMax-H3

# RGThree setting to create nested file selector in nodes
cp config/rgthree_config.json "$WORKSPACE/custom_nodes/rgthree-comfy"

mkdir -p "$WORKSPACE/user/default/workflows"
CreateLinkedDirectory "$COMMON/models"    "$WORKSPACE/models"
CreateLinkedDirectory "$COMMON/workflows" "$WORKSPACE/user/default/workflows"

LAUNCH_SCRIPT="$WORKSPACE/run.sh"

cat << EOF > "$LAUNCH_SCRIPT"
#!/usr/bin/env bash
set -eo pipefail

eval "\$(conda shell.bash hook)"
conda activate "$ENV"

comfy --workspace="$WORKSPACE" launch -- --output-directory "$COMMON/output" --input-directory "$COMMON/input"
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
