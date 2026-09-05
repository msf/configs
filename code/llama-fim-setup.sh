#!/usr/bin/env bash
set -euo pipefail

# Setup local FIM code completion: llama.cpp server + Qwen2.5-Coder-3B Q4_K_M
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

LLAMA_DIR="$(dirname "$(readlink -f "$(command -v llama-server)")")"
MODEL_DIR="$HOME/play/llama/models/Qwen2.5-Coder-3B"
MODEL_FILE="Qwen2.5-Coder-3B-Q4_K_M.gguf"
MODEL_REVISION="465c183318f1fcb5774394eee76f1b7f224494ec"

mkdir -p "$MODEL_DIR"
echo "downloading and checking FIM model (if not cached)..."
"$LLAMA_DIR/llama-completion" \
    --model "$MODEL_DIR/$MODEL_FILE" \
    --model-url "https://huggingface.co/bartowski/Qwen2.5-Coder-3B-GGUF/resolve/$MODEL_REVISION/$MODEL_FILE" \
    --ctx-size 512 --predict 0 --no-warmup --prompt test

# Install systemd user service
mkdir -p "$HOME/.config/systemd/user"
ln -sf "$SCRIPT_DIR/llama-fim.service" "$HOME/.config/systemd/user/llama-fim.service"

systemctl --user daemon-reload
systemctl --user enable llama-fim.service
systemctl --user restart llama-fim.service

echo "done. verify: curl http://127.0.0.1:8012/health"
echo "logs:   journalctl --user -u llama-fim -f"
