# Use an Ubuntu base image
FROM ubuntu:22.04

# Let’s define some build arguments
ARG TARGETARCH
ARG DGB_VERSION=8.22.1
ENV FNM_PATH="/root/.local/share/fnm"

# Install necessary dependencies
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    git curl build-essential yasm autoconf automake libtool libzmq3-dev pkgconf ca-certificates net-tools jq unzip apache2 nano \
    && rm -rf /var/lib/apt/lists/*

# Download and install DigiByte Core
# We pick x86_64 or arm64 archives depending on $TARGETARCH
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      curl -L -o digibyte.tar.gz https://github.com/DigiByte-Core/digibyte/releases/download/v${DGB_VERSION}/digibyte-v${DGB_VERSION}-x86_64-linux-gnu.tar.gz; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      curl -L -o digibyte.tar.gz https://github.com/DigiByte-Core/digibyte/releases/download/v${DGB_VERSION}/digibyte-v${DGB_VERSION}-aarch64-linux-gnu.tar.gz; \
    else \
      echo "Unsupported or unknown architecture: $TARGETARCH"; \
      exit 1; \
    fi \
    && tar -xzvf digibyte.tar.gz --strip-components=1 -C /usr/local \
    && rm digibyte.tar.gz

# Build ckpool from source
    RUN git clone https://bitbucket.org/ckolivas/ckpool.git /ckpool \
    && cd /ckpool \
    && chmod +x autogen.sh \
    && ./autogen.sh \
    && ./configure \
    && make

# Create necessary directories
RUN mkdir -p /etc/ckpool /etc/digibyte /logs /home/cna.digibyte/mainnet
VOLUME /home/cna.digibyte/mainnet

# Copy in the entrypoint script and make it executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy in the ckpool the healthcheck script and make it executable
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

# Expose DigiByte ports (p2p=8433, RPC=8432) and example ckpool port (3333)
EXPOSE 8433 8432 3333 80

ENTRYPOINT ["/entrypoint.sh"]
