# Node Dockerfile for hydrophone streaming
# Multi-arch self-contained build for CI/CD deployment

FROM python:3.11-slim-bookworm

LABEL org.opencontainers.image.source="https://github.com/orcasound/orcanode"
LABEL org.opencontainers.image.description="Orcasound hydrophone streaming node"
LABEL org.opencontainers.image.authors="Orcasound <orcanode-devs@orcasound.net>"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    jack-capture \
    jackd2 \
    alsa-utils \
    git \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python dependencies
RUN pip3 install --no-cache-dir \
    boto3 \
    inotify

# Copy application files
WORKDIR /app
COPY . .

# Set environment defaults
ENV DEBIAN_FRONTEND=noninteractive \
    SAMPLE_RATE=48000 \
    CHANNELS=1 \
    NODE_TYPE=hls-only

# Make scripts executable
RUN chmod +x *.sh

# Run the streaming script
CMD ["./stream.sh"]
