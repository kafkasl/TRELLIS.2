#!/usr/bin/env bash
set -euo pipefail

# GCP L4 / Deep Learning VM setup for TRELLIS.2.
# Expected image family: PyTorch CUDA Ubuntu DLVM with NVIDIA driver + CUDA toolkit.
# This script intentionally delegates package selection to upstream setup.sh.
# For SSH-safe long installs, run from the persistent SSH connection
# in a local tmux pane and tee output to a log.

REPO_DIR="${TRELLIS_REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
VENV_DIR="${TRELLIS_VENV_DIR:-$HOME/trellis-venv}"
PYTHON="${PYTHON:-python3}"
TORCH_INDEX_URL="${TORCH_INDEX_URL:-https://download.pytorch.org/whl/cu124}"
SETUP_FLAGS=(--basic --flash-attn --nvdiffrast --nvdiffrec --cumesh --o-voxel --flexgemm)

log() { printf '\n\033[1;32m[trellis-gcp]\033[0m %s\n' "$*"; }

log "Repo: $REPO_DIR"
log "Venv: $VENV_DIR"

log "Installing OS build prerequisites"
sudo apt-get update
sudo apt-get install -y python3.10-venv python3.10-dev build-essential git curl ninja-build

log "Creating Python venv"
if [ ! -d "$VENV_DIR" ]; then
  if [ "${TRELLIS_VENV_SYSTEM_SITE:-0}" = "1" ]; then
    "$PYTHON" -m venv --system-site-packages "$VENV_DIR"
  else
    "$PYTHON" -m venv "$VENV_DIR"
  fi
fi
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip setuptools wheel packaging ninja

log "Installing upstream TRELLIS.2 torch stack"
python -m pip install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url "$TORCH_INDEX_URL"

log "Checking CUDA"
python - <<'PY'
import torch
print('torch:', torch.__version__)
print('cuda:', torch.version.cuda)
print('cuda_available:', torch.cuda.is_available())
assert torch.cuda.is_available(), 'CUDA is not available; check VM image/driver/GPU'
PY

log "Initializing repo submodules"
cd "$REPO_DIR"
git submodule update --init --recursive

log "Running upstream setup.sh ${SETUP_FLAGS[*]}"
export MAX_JOBS="${MAX_JOBS:-4}"
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.9}"
# shellcheck disable=SC1091
. ./setup.sh "${SETUP_FLAGS[@]}"

log "Verifying critical imports"
python - <<'PY'
import importlib, torch
mods = [
    'torch', 'torchaudio', 'torchvision', 'flash_attn', 'cumesh', 'flex_gemm',
    'nvdiffrast.torch', 'nvdiffrec_render', 'nvdiffrec_render.light',
    'o_voxel', 'utils3d', 'utils3d.torch', 'gradio', 'gradio_client',
    'transformers', 'numpy', 'PIL', 'cv2', 'kornia', 'timm',
]
for m in mods:
    mod = importlib.import_module(m)
    print(f'{m}: OK {mod.__dict__.get("__version__", "")}')
print('torch:', torch.__version__, 'cuda:', torch.version.cuda, 'available:', torch.cuda.is_available())
if torch.cuda.is_available():
    print('gpu:', torch.cuda.get_device_name(0))
PY

log "Setup complete. Run: bash scripts/run_gcp_demo.sh"
