#!/usr/bin/env bash
set -euo pipefail

# GCP L4 / Deep Learning VM setup for TRELLIS.
# Expected base image:
#   pytorch-2-3-cu121-v20250327-ubuntu-2204-py310
# This image provides Python 3.10, CUDA 12.1, and torch 2.3.0+cu121.

REPO_DIR="${TRELLIS_REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
VENV_DIR="${TRELLIS_VENV_DIR:-$HOME/trellis-venv}"
PYTHON="${PYTHON:-python3}"

log() { printf '\n\033[1;32m[trellis-gcp]\033[0m %s\n' "$*"; }

log "Repo: $REPO_DIR"
log "Venv: $VENV_DIR"

if ! command -v gcc-11 >/dev/null 2>&1 || ! command -v g++-11 >/dev/null 2>&1; then
  log "Installing gcc-11/g++-11 build tools"
  sudo apt-get update
  sudo apt-get install -y gcc-11 g++-11 build-essential git wget curl
fi

log "Creating venv with access to system torch/CUDA packages"
if [ ! -d "$VENV_DIR" ]; then
  "$PYTHON" -m venv --system-site-packages "$VENV_DIR"
fi
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip setuptools wheel

log "Checking base torch/CUDA"
python - <<'PY'
import torch
print('torch:', torch.__version__)
print('cuda:', torch.version.cuda)
print('cuda_available:', torch.cuda.is_available())
assert torch.cuda.is_available(), 'CUDA is not available; check VM image/driver/GPU'
PY

log "Installing TRELLIS basic/demo dependencies with known-compatible pins"
pip install \
  pillow imageio imageio-ffmpeg tqdm easydict opencv-python-headless scipy ninja \
  rembg onnxruntime trimesh open3d xatlas pyvista pymeshfix igraph
pip install git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8
pip install \
  'transformers==4.56.0' \
  'numpy<2' \
  'gradio==4.44.1' \
  'gradio_client==1.3.0' \
  'gradio_litmodel3d==0.0.1' \
  'pydantic==2.10.6'

log "Installing xformers and sparse conv"
pip install 'xformers==0.0.26.post1'
pip install spconv-cu120

log "Building CUDA rasterizer dependencies"
export CC=gcc-11
export CXX=g++-11
pip install --no-build-isolation git+https://github.com/NVlabs/nvdiffrast.git
pip install --no-build-isolation git+https://github.com/JeffreyXiang/diffoctreerast.git
  pip install --no-build-isolation git+https://github.com/JeffreyXiang/CuMesh.git

log "Initializing submodules and installing kaolin"
cd "$REPO_DIR"
git submodule update --init --recursive
pip install kaolin -f https://nvidia-kaolin.s3.us-east-2.amazonaws.com/torch-2.3.0_cu121.html

log "Installing mip-splatting gaussian rasterizer"
if [ ! -d /tmp/mip-splatting ]; then
  git clone https://github.com/autonomousvision/mip-splatting.git /tmp/mip-splatting
else
  git -C /tmp/mip-splatting pull --ff-only || true
fi
pip install --no-build-isolation /tmp/mip-splatting/submodules/diff-gaussian-rasterization/

log "Verifying critical imports"
python - <<'PY'
import torch, gradio, gradio_client, transformers, numpy
print('torch', torch.__version__)
print('gradio', gradio.__version__)
print('gradio_client', gradio_client.__version__)
print('transformers', transformers.__version__)
print('numpy', numpy.__version__)
PY

log "Setup complete. Run: bash scripts/run_gcp_demo.sh"
