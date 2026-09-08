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
    curl ca-certificates fonts-liberation \
    libnss3 libnspr4 libdbus-1-3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 \
    libcairo2 libasound2 libxshmfence1 libx11-xcb1 libxkbcommon0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Google Chrome for current architecture (arm64 or amd64)
RUN set -eux; \
    ARCH=$(dpkg --print-architecture); \
    if [ "$ARCH" = "arm64" ]; then \
        CHROME_DEB="google-chrome-stable_current_arm64.deb"; \
    elif [ "$ARCH" = "amd64" ]; then \
        CHROME_DEB="google-chrome-stable_current_amd64.deb"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi; \
    curl -fL -o /tmp/google-chrome.deb "https://dl.google.com/linux/direct/${CHROME_DEB}"; \
    apt-get update && apt-get install -y /tmp/google-chrome.deb; \
    rm -f /tmp/google-chrome.deb; \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /src/target/release/turnstile-solver /app/turnstile-solver
COPY --from=build /src/src/devices.json /app/src/devices.json
COPY --from=build /src/src/devices.json /app/devices.json

ENV CHROME_BIN=/usr/bin/google-chrome
EXPOSE 407
CMD ["/app/turnstile-solver"]
