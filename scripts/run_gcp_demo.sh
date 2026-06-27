#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${TRELLIS_REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
VENV_DIR="${TRELLIS_VENV_DIR:-$HOME/trellis-venv}"
HOST="${TRELLIS_GRADIO_SERVER_NAME:-127.0.0.1}"
PORT="${TRELLIS_GRADIO_SERVER_PORT:-7860}"

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
cd "$REPO_DIR"

export ATTN_BACKEND="${ATTN_BACKEND:-xformers}"
export SPARSE_ATTN_BACKEND="${SPARSE_ATTN_BACKEND:-xformers}"
export SPCONV_ALGO="${SPCONV_ALGO:-native}"
export TRELLIS_GRADIO_SERVER_NAME="$HOST"
export TRELLIS_GRADIO_SERVER_PORT="$PORT"
export TRELLIS_GRADIO_SHARE="${TRELLIS_GRADIO_SHARE:-true}"

python app.py
