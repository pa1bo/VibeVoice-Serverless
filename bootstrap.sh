#!/bin/bash
set -e

echo "=== VibeVoice Runpod Serverless Bootstrap ==="

# Create runtime directory structure on the network volume
echo "Ensuring directory structure on network volume..."
mkdir -p /runpod-volume/vibevoice/{models,output,demo/voices,torch_cache,hf_home,hf_cache}

# Torch cache lives on the network volume
export TORCH_HOME="/runpod-volume/vibevoice/torch_cache"

# NOTE: We do NOT set HF_HOME / HF_HUB_CACHE here unless provided via the
# endpoint env, so RunPod's smart caching (and any pre-staged volume cache)
# can resolve the model.
if [ -n "$HF_TOKEN" ]; then
    export HF_TOKEN="$HF_TOKEN"
    echo "HuggingFace token configured"
else
    echo "WARNING: HF_TOKEN not set. Model download may fail if model requires authentication."
fi

# All Python dependencies (torch, flash-attn, VibeVoice, LinaCodec, ...) are
# baked into the image, so there is no first-run install step and no venv on
# the volume. The model weights are read from the network volume's HF cache.
echo "Starting VibeVoice handler..."
exec python /workspace/vibevoice/handler.py
