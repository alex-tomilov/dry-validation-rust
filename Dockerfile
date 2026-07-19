ARG RUBY_VERSION=3.3.7
ARG RUST_VERSION=1.85.0

FROM rust:${RUST_VERSION}-slim-bookworm AS rust-toolchain

FROM ruby:${RUBY_VERSION}-slim-bookworm AS builder

COPY --from=rust-toolchain /usr/local/cargo /usr/local/cargo
COPY --from=rust-toolchain /usr/local/rustup /usr/local/rustup

ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:${PATH}

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      build-essential \
      clang \
      libclang-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/dry-validation-rust

COPY Gemfile Gemfile.lock dry-validation-rust.gemspec Rakefile ./
COPY .ruby-version .tool-versions rust-toolchain.toml ./
COPY lib/dry/validation/rust/version.rb lib/dry/validation/rust/version.rb

RUN gem install bundler --version 2.5.22 --no-document \
    && bundle config set --local deployment true \
    && bundle config set --local path vendor/bundle \
    && bundle install --jobs 4 --retry 3

COPY benchmark/Gemfile.upstream benchmark/Gemfile.upstream.lock ./benchmark/

RUN BUNDLE_GEMFILE=/opt/dry-validation-rust/benchmark/Gemfile.upstream \
    BUNDLE_IGNORE_CONFIG=1 \
    BUNDLE_FROZEN=true \
    BUNDLE_PATH=/opt/upstream-bundle \
    bundle install --jobs 4 --retry 3

COPY LICENSE NOTICE.md README.md ./
COPY benchmark benchmark
COPY bin bin
COPY examples examples
COPY ext ext
COPY lib lib
COPY script script

RUN bundle exec rake compile \
    && script/demo --json

FROM debian:bookworm-slim AS runtime

ARG VCS_REF

LABEL org.opencontainers.image.title="dry-validation-rust judge demo" \
      org.opencontainers.image.description="Precompiled deterministic Ruby/Rust validation demo" \
      org.opencontainers.image.source="https://github.com/alex-tomilov/dry-validation-rust" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.licenses="MIT"

ENV DVR_IMAGE_REVISION=${VCS_REF} \
    DVR_UPSTREAM_GEM_HOME=/opt/upstream-gems

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      libcrypt1 \
      libffi8 \
      libgmp10 \
      libssl3 \
      libyaml-0-2 \
      time \
      zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 dvr \
    && useradd --uid 10001 --gid dvr --no-create-home --shell /usr/sbin/nologin dvr

WORKDIR /opt/dry-validation-rust

COPY --from=builder /usr/local/bin/ruby /usr/local/bin/ruby
COPY --from=builder /usr/local/lib/libruby.so* /usr/local/lib/
COPY --from=builder /usr/local/lib/ruby/3.3.0 /usr/local/lib/ruby/3.3.0
COPY --from=builder /opt/upstream-bundle/ruby/3.3.0 /opt/upstream-gems
COPY --from=builder --chown=10001:10001 /opt/dry-validation-rust/LICENSE ./LICENSE
COPY --from=builder --chown=10001:10001 /opt/dry-validation-rust/NOTICE.md ./NOTICE.md
COPY --from=builder --chown=10001:10001 /opt/dry-validation-rust/README.md ./README.md
COPY --from=builder --chown=10001:10001 /opt/dry-validation-rust/benchmark ./benchmark
COPY --from=builder --chown=10001:10001 --chmod=0555 /opt/dry-validation-rust/bin/dvr ./bin/dvr
COPY --from=builder --chown=10001:10001 /opt/dry-validation-rust/examples ./examples
COPY --from=builder --chown=10001:10001 /opt/dry-validation-rust/lib ./lib
COPY --from=builder --chown=10001:10001 --chmod=0555 /opt/dry-validation-rust/script/benchmark-smoke ./script/benchmark-smoke
COPY --from=builder --chown=10001:10001 --chmod=0555 /opt/dry-validation-rust/script/benchmark-suite ./script/benchmark-suite
COPY --from=builder --chown=10001:10001 --chmod=0555 /opt/dry-validation-rust/script/demo ./script/demo
COPY --from=builder --chown=10001:10001 /opt/dry-validation-rust/ext/dry_validation_rust/native.so ./ext/dry_validation_rust/native.so

USER 10001:10001

ENTRYPOINT ["/opt/dry-validation-rust/bin/dvr"]
