# Multi-arch CLI image built from pre-compiled release binaries
# Downloaded from public homebrew-tap GitHub releases
#
# Build: docker buildx build --platform linux/amd64,linux/arm64 -t codelayers-cli .
# Requires: VERSION build arg (e.g., v0.0.7)

FROM debian:bookworm-slim

ARG VERSION
ARG TARGETARCH

LABEL org.opencontainers.image.description="CodeLayers CLI - Zero-knowledge code visualization agent"
LABEL org.opencontainers.image.source="https://github.com/codelayers-ai/codelayers-action"

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    git \
    jq \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Map Docker TARGETARCH to cargo-dist triple
# TARGETARCH is set by buildx: amd64 or arm64
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) TRIPLE="x86_64-unknown-linux-gnu" ;; \
      arm64) TRIPLE="aarch64-unknown-linux-gnu" ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac; \
    ARCHIVE="codelayers-cli-${TRIPLE}.tar.xz"; \
    URL="https://github.com/codelayers-ai/homebrew-tap/releases/download/${VERSION}/${ARCHIVE}"; \
    echo "Downloading ${URL}"; \
    curl -fsSL "${URL}" -o "/tmp/${ARCHIVE}"; \
    tar xf "/tmp/${ARCHIVE}" --strip-components=1 -C /usr/local/bin; \
    rm "/tmp/${ARCHIVE}"; \
    codelayers --version

# Trust mounted workspaces for git (volume has different owner)
RUN git config --system --add safe.directory '*'

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
