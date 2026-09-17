#!/usr/bin/env bash
# Build OpenSSL from source for a musl target and emit the per-target
# *_OPENSSL_DIR/_OPENSSL_NO_VENDOR/_OPENSSL_STATIC env vars that openssl-sys
# honours, so cargo zigbuild can link against a target-matching static
# libssl.a / libcrypto.a.
#
# Mirrors openai/codex .github/scripts/install-musl-openssl.sh but adds
# i686 and riscv64gc targets (upstream only knows linux-x86_64 / linux-aarch64)
# and routes the build through Zig cc instead of a hand-rolled zigcc shim,
# since cargo-zigbuild sets CC=zig cc -target $TARGET at link time anyway.
#
# Host: ubuntu-latest (x86_64-unknown-linux-gnu). zig cc produces target
# binaries with musl sysroot when given -target <triple>-linux-musl.

set -euo pipefail

: "${TARGET:?TARGET environment variable is required}"
: "${GITHUB_ENV:?GITHUB_ENV environment variable is required}"

# Locate zig. cargo-zigbuild installs it to ~/.cargo/bin; the workflow step
# also adds Zig's bin dir to GITHUB_PATH, so `command -v zig` resolves
# either way.
if ! command -v zig >/dev/null; then
  echo "zig not on PATH; install-musl-openssl.sh requires it" >&2
  exit 1
fi

case "${TARGET}" in
  x86_64-unknown-linux-musl)   zig_target="x86_64-linux-musl"   openssl_target="linux-x86_64"   ;;
  i686-unknown-linux-musl)     zig_target="x86-linux-musl"      openssl_target="linux-x86"      ;;
  aarch64-unknown-linux-musl)  zig_target="aarch64-linux-musl"  openssl_target="linux-aarch64"  ;;
  riscv64gc-unknown-linux-musl) zig_target="riscv64-linux-musl" openssl_target="linux64-riscv64" ;;
  *)
    echo "Unexpected musl target: ${TARGET}" >&2
    exit 1
    ;;
esac

# 3.6.4 — same pin upstream uses to dodge openssl-src crate lag.
openssl_version="3.6.4"
openssl_sha256="9bffaa1ad1e07b354c21bd3324ec02fa15579f45a7d0494b3e74bc449b7333ef"

runner_temp="${RUNNER_TEMP:-/tmp}"
openssl_root="${runner_temp}/codex-musl-tools-${TARGET}/openssl-${openssl_version}"
openssl_prefix="${openssl_root}/prefix"

# Build only on cold caches; rebuilds are ~3 minutes per arch.
if [[ ! -f "${openssl_prefix}/.complete" ]]; then
  mkdir -p "${openssl_root}"
  archive="${openssl_root}/openssl-${openssl_version}.tar.gz"
  curl -fsSL "https://github.com/openssl/openssl/releases/download/openssl-${openssl_version}/openssl-${openssl_version}.tar.gz" -o "${archive}"
  echo "${openssl_sha256}  ${archive}" | sha256sum -c -
  tar -xzf "${archive}" -C "${openssl_root}"

  (
    cd "${openssl_root}/openssl-${openssl_version}"
    # cc is `zig cc`; zig resolves the right musl sysroot + CRT for -target.
    # -DOPENSSL_NO_SECURE_MEMORY mirrors upstream's hardening tweaks.
    # no-shared / no-module produce static libs only.
    CC="zig cc -target ${zig_target}" \
      perl ./Configure "${openssl_target}" \
        "--prefix=${openssl_prefix}" --openssldir=/usr/local/ssl --libdir=lib \
        no-shared no-module no-tests no-comp no-zlib no-zlib-dynamic \
        no-ssl3 no-md2 no-rc5 no-weak-ssl-ciphers no-camellia no-idea no-seed \
        no-engine no-async -DOPENSSL_NO_SECURE_MEMORY
    make -j"$(nproc)" build_libs
    make install_dev
  )
  touch "${openssl_prefix}/.complete"
fi

# openssl-sys (and rustls via aws-lc-sys's vendored fallback) read
# ${TARGET^^//-/_}_OPENSSL_DIR to find the matching arch's headers/libs.
# Forcing OPENSSL_NO_VENDOR=1 stops the build from falling back to the
# crate's bundled openssl (which would still try to use host CC).
target_env="${TARGET^^}"
target_env="${target_env//-/_}"
{
  echo "${target_env}_OPENSSL_DIR=${openssl_prefix}"
  echo "${target_env}_OPENSSL_NO_VENDOR=1"
  echo "${target_env}_OPENSSL_STATIC=1"
} >> "${GITHUB_ENV}"
