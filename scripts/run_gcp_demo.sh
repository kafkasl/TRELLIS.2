#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${TRELLIS_REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
VENV_DIR="${TRELLIS_VENV_DIR:-$HOME/trellis-v2-venv}"
HOST="${TRELLIS_GRADIO_SERVER_NAME:-127.0.0.1}"
PORT="${TRELLIS_GRADIO_SERVER_PORT:-7860}"

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
cd "$REPO_DIR"

export ATTN_BACKEND="${ATTN_BACKEND:-flash_attn}"
export SPARSE_ATTN_BACKEND="${SPARSE_ATTN_BACKEND:-flash_attn}"
export SPARSE_CONV_BACKEND="${SPARSE_CONV_BACKEND:-flex_gemm}"
export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"
export TRELLIS_GRADIO_SERVER_NAME="$HOST"
export TRELLIS_GRADIO_SERVER_PORT="$PORT"
export TRELLIS_GRADIO_SHARE="${TRELLIS_GRADIO_SHARE:-false}"
# briaai/RMBG-2.0 from the upstream config is gated; use a public BiRefNet
# checkpoint by default for tokenless GCP demos.
export TRELLIS_REMBG_MODEL="${TRELLIS_REMBG_MODEL:-ZhengPeng7/BiRefNet}"

python app.py
