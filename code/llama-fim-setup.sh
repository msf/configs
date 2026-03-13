#!/usr/bin/env bash
set -euo pipefail

# Setup local FIM code completion: llama.cpp server + Qwen2.5-Coder-3B
#
# Prerequisites:
#   - llama-server in PATH (build llama.cpp with Vulkan/CUDA)
#   - neovim with llama.vim plugin (see nvim/lua/plugins/llama.lua)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v llama-server &>/dev/null; then
    echo "error: llama-server not found in PATH"
    echo "build llama.cpp: https://github.com/ggml-org/llama.cpp"
    exit 1
fi

# Download model (--fim-qwen-3b-default auto-downloads from HuggingFace)
echo "downloading FIM model (if not cached)..."
timeout 120 llama-server --fim-qwen-3b-default --port 0 --no-webui 2>&1 | head -5 || true

# Install systemd user service
mkdir -p "$HOME/.config/systemd/user"
ln -sf "$SCRIPT_DIR/llama-fim.service" "$HOME/.config/systemd/user/llama-fim.service"

systemctl --user daemon-reload
systemctl --user enable --now llama-fim.service

echo "done. verify: curl http://127.0.0.1:8012/health"
echo "logs:   journalctl --user -u llama-fim -f"
