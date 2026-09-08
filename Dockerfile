FROM debian:bookworm-slim AS build

RUN apt-get update && (apt-get install -y --no-install-recommends \
    curl ca-certificates build-essential pkg-config gcc-x86-64-linux-gnu libc6-dev-amd64-cross \
    || apt-get install -y --no-install-recommends curl ca-certificates build-essential pkg-config) \
    && rm -rf /var/lib/apt/lists/*

RUN if ! command -v x86_64-linux-gnu-gcc >/dev/null 2>&1; then ln -s "$(command -v gcc)" /usr/local/bin/x86_64-linux-gnu-gcc; fi

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.80.0 --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

RUN rustup target add x86_64-unknown-linux-gnu

WORKDIR /src
COPY Cargo.toml Cargo.lock ./
COPY src ./src

ENV CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=x86_64-linux-gnu-gcc
RUN cargo build --release --target x86_64-unknown-linux-gnu

FROM --platform=linux/amd64 debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip ca-certificates fonts-liberation \
    libnss3 libnspr4 libdbus-1-3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 \
    libcairo2 libasound2 libxshmfence1 libx11-xcb1 libxkbcommon0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN set -eux; \
    URL=$(curl -fsSL --retry 5 --retry-all-errors --retry-delay 3 --connect-timeout 30 \
      https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json \
      | grep -o 'https://storage.googleapis.com/chrome-for-testing-public/[^"]*linux64/chrome-linux64.zip' | head -n1); \
    test -n "$URL"; \
    curl -fL --retry 5 --retry-all-errors --retry-delay 3 --connect-timeout 30 -o /tmp/c.zip "$URL"; \
    unzip -q /tmp/c.zip -d /app; \
    mv /app/chrome-linux64 /app/chrome; \
    rm /tmp/c.zip

COPY --from=build /src/target/x86_64-unknown-linux-gnu/release/turnstile-solver /app/turnstile-solver
COPY --from=build /src/src/devices.json /app/src/devices.json
COPY --from=build /src/src/devices.json /app/devices.json

ENV CHROME_BIN=/app/chrome/chrome
EXPOSE 407
CMD ["/app/turnstile-solver"]
