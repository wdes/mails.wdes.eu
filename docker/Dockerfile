# See: https://github.com/stalwartlabs/mail-server/pull/85
FROM docker.io/debian:bookworm-slim AS source

WORKDIR /source

ARG VERSION="0.4.2"
ADD https://github.com/stalwartlabs/mail-server/archive/refs/tags/v$VERSION.tar.gz /tmp/v$VERSION.tar.gz
RUN tar --strip-components=1 -C /source -xzf /tmp/v$VERSION.tar.gz

RUN apt update && apt install -y patch

# Enhancement: Custom resolver nameservers
ADD https://patch-diff.githubusercontent.com/raw/stalwartlabs/mail-server/pull/141.patch /tmp/141.patch
RUN patch -p1 < /tmp/141.patch

# Fix: Return an error to client if STARTTLS is not available
ADD https://patch-diff.githubusercontent.com/raw/stalwartlabs/mail-server/pull/135.patch /tmp/135.patch
RUN patch -p1 < /tmp/135.patch

FROM --platform=$BUILDPLATFORM docker.io/lukemathwalker/cargo-chef:latest-rust-slim-bookworm AS chef
WORKDIR /build

FROM --platform=$BUILDPLATFORM chef AS planner
COPY --from=source /source .
RUN cargo chef prepare --recipe-path /recipe.json

FROM --platform=$BUILDPLATFORM chef AS builder
ARG TARGETPLATFORM
RUN case "${TARGETPLATFORM}" in \
      "linux/arm64") echo "aarch64-unknown-linux-gnu" > /target.txt && echo "-C linker=aarch64-linux-gnu-gcc" > /flags.txt ;; \
      "linux/amd64") echo "x86_64-unknown-linux-gnu" > /target.txt && echo "-C linker=x86_64-linux-gnu-gcc" > /flags.txt ;; \
      *) exit 1 ;; \
    esac
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -yq build-essential \
                        g++-aarch64-linux-gnu binutils-aarch64-linux-gnu
RUN rustup target add "$(cat /target.txt)"
COPY --from=planner /recipe.json /recipe.json
RUN RUSTFLAGS="$(cat /flags.txt)" cargo chef cook --target "$(cat /target.txt)" --release --recipe-path /recipe.json
COPY --from=source /source .
RUN RUSTFLAGS="$(cat /flags.txt)" cargo build --target "$(cat /target.txt)" --release -p mail-server -p stalwart-cli -p stalwart-install
RUN mv "/build/target/$(cat /target.txt)/release" "/output"

FROM docker.io/debian:bookworm-slim
ENV STALWART_COMPONENT=all-in-one
WORKDIR /opt/stalwart-mail
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -yq ca-certificates
COPY --from=builder /output/stalwart-mail /usr/local/bin
COPY --from=builder /output/stalwart-cli /usr/local/bin
COPY --from=builder /output/stalwart-install /usr/local/bin
COPY ./entrypoint.sh /usr/local/bin
COPY ./configure.sh /usr/local/bin
RUN chmod -R 755 /usr/local/bin
CMD ["/usr/local/bin/stalwart-mail"]

# Get the config
# Run: docker run --rm -it --entrypoint /bin/bash docker-mailserver
# /usr/local/bin/configure.sh
# cat /opt/stalwart-mail/etc/config.toml

# Supports ENVs in the form !ENV_NAME
# See: https://github.com/stalwartlabs/mail-server/blob/v0.4.2/crates/utils/src/config/parser.rs#L381

ENTRYPOINT ["/usr/local/bin/entrypoint.sh", "/etc/config.toml"]
