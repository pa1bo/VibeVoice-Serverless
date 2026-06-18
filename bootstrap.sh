#!/bin/bash
set -e

echo "=== VibeVoice Runpod Serverless Bootstrap ==="

# Create runtime directory structure on the network volume
echo "Ensuring directory structure on network volume..."
mkdir -p /runpod-volume/vibevoice/{models,output,demo/voices,torch_cache,hf_home,hf_cache}

# Torch cache lives on the network volume
export TORCH_HOME="/runpod-volume/vibevoice/torch_cache"

# The VibeVoice-7B weights are pre-staged in the network volume's HF cache.
# Point HF at it and force offline mode so it reads the local snapshot instead
# of calling the (gated) Hub — which otherwise fails with "does not appear to
# have files named ...". Endpoint env can still override HF_HOME if needed.
export HF_HOME="${HF_HOME:-/runpod-volume/huggingface-cache}"
# HF_HUB_CACHE OVERRIDES HF_HOME for locating hub/ models. A stale endpoint env
# value (e.g. /runpod-volume/vibevoice/hf_cache) sends HF to an empty dir, so it
# can't find the staged VibeVoice-7B model, falls back to the wrong default
# tokenizer (Qwen2.5-1.5B), and crashes. Force it unconditionally — never honor
# an inherited value — so it always derives from HF_HOME.
export HF_HUB_CACHE="$HF_HOME/hub"
export HF_HUB_OFFLINE="${HF_HUB_OFFLINE:-1}"
export TRANSFORMERS_OFFLINE="${TRANSFORMERS_OFFLINE:-1}"
echo "HF_HOME=$HF_HOME  HF_HUB_CACHE=$HF_HUB_CACHE  HF_HUB_OFFLINE=$HF_HUB_OFFLINE"

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
