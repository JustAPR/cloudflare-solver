FROM debian:bookworm-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.80.0 --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /src
COPY Cargo.toml Cargo.lock ./
COPY src ./src

RUN cargo build --release

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip jq ca-certificates fonts-liberation fonts-noto-color-emoji \
    libnss3 libnspr4 libdbus-1-3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 \
    libcairo2 libasound2 libxshmfence1 libx11-xcb1 libxkbcommon0 \
    libgl1 libglx-mesa0 libegl1 mesa-vulkan-drivers libvulkan1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        CHROME_PLATFORM="linux-arm64"; \
    else \
        CHROME_PLATFORM="linux64"; \
    fi; \
    URL=$(curl -fsSL --retry 5 --retry-all-errors --retry-delay 3 --connect-timeout 30 \
      https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json \
      | jq -r --arg plat "$CHROME_PLATFORM" '.channels.Beta.downloads.chrome[] | select(.platform == $plat) | .url'); \
    test -n "$URL" && test "$URL" != "null"; \
    curl -fL --retry 5 --retry-all-errors --retry-delay 3 --connect-timeout 30 -o /tmp/c.zip "$URL"; \
    unzip -q /tmp/c.zip -d /app; \
    if [ -d "/app/chrome-linux-arm64" ]; then \
        mv /app/chrome-linux-arm64 /app/chrome; \
    elif [ -d "/app/chrome-linux64" ]; then \
        mv /app/chrome-linux64 /app/chrome; \
    fi; \
    rm /tmp/c.zip; \
    chmod +x /app/chrome/chrome

COPY --from=build /src/target/release/turnstile-solver /app/turnstile-solver
COPY --from=build /src/src/devices.json /app/src/devices.json
COPY --from=build /src/src/devices.json /app/devices.json

ENV CHROME_BIN=/app/chrome/chrome
EXPOSE 407
CMD ["/app/turnstile-solver"]
