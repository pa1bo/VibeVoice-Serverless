FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PYTHONUNBUFFERED=1 \
    TORCH_HOME=/runpod-volume/vibevoice/torch_cache \
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv python3.12-dev python3-pip \
    git ca-certificates curl build-essential ffmpeg libsndfile1 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.12 /usr/local/bin/python \
    && ln -sf /usr/bin/pip3 /usr/local/bin/pip

WORKDIR /workspace/vibevoice

# --- Heavy dependencies baked into the image ---
# These were previously installed at runtime in bootstrap.sh (into a venv on the
# network volume), which made the first cold start on each volume take minutes.
# Baking them into the image makes cold starts fast and volume-independent.

# PyTorch with CUDA 12.8 support
RUN pip install --no-cache-dir torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 \
    --index-url https://download.pytorch.org/whl/cu128

# flash-attention (prebuilt wheel: cp312 / torch2.8 / cu12)
RUN pip install --no-cache-dir \
    https://github.com/Dao-AILab/flash-attention/releases/download/v2.8.1/flash_attn-2.8.1+cu12torch2.8cxx11abiTRUE-cp312-cp312-linux_x86_64.whl

# Application requirements (runpod, boto3, soundfile, huggingface_hub, LinaCodec, ...)
COPY requirements.txt /workspace/vibevoice/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# VibeVoice library
RUN git clone https://github.com/vibevoice-community/VibeVoice.git /workspace/VibeVoice \
    && pip install --no-cache-dir /workspace/VibeVoice

COPY bootstrap.sh /workspace/vibevoice/bootstrap.sh
COPY handler.py /workspace/vibevoice/handler.py
COPY inference.py /workspace/vibevoice/inference.py
COPY config.py /workspace/vibevoice/config.py

CMD ["bash", "/workspace/vibevoice/bootstrap.sh"]
