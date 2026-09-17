#!/usr/bin/env bash
# Build a tiny libatomic.a shim providing __atomic_is_lock_free for musl
# i686 cross builds. The openssl static lib (compiled via install-musl-openssl.sh)
# references this symbol as a regular function call; Zig's musl sysroot
# doesn't ship libatomic, so without this shim the link step fails with
#   ld.lld: error: undefined symbol: __atomic_is_lock_free
#
# The shim source at .github/patches/libatomic-shim/atomic_shim.c just
# reports "not lock-free" for 8/16-byte atomics — true on i386 anyway,
# so openssl takes the same locking fallback it would with a real
# libatomic.
#
# Only i686 trips this: x86_64/aarch64/riscv64 expand __atomic_is_lock_free
# at compile time (clang/gcc can prove the size is always small enough).
# Skip the build on those targets to keep CI cheap.

set -euo pipefail

: "${TARGET:?TARGET environment variable is required}"

if [[ "${TARGET}" != "i686-unknown-linux-musl" ]]; then
  # No shim needed — clang's compiler-rt expands __atomic_is_lock_free
  # at compile time on these targets, so the symbol never appears in
  # openssl's compiled output.
  exit 0
fi

if ! command -v zig >/dev/null; then
  echo "zig not on PATH; build-libatomic.sh requires it" >&2
  exit 1
fi

zig_target="x86-linux-musl"

runner_temp="${RUNNER_TEMP:-/tmp}"
libatomic_root="${runner_temp}/codex-musl-tools-${TARGET}/libatomic"
libatomic_prefix="${libatomic_root}/prefix"
shim_src="${GITHUB_WORKSPACE}/.github/patches/libatomic-shim/atomic_shim.c"

if [[ ! -f "${libatomic_prefix}/lib/libatomic.a" ]]; then
  mkdir -p "${libatomic_prefix}/lib" "${libatomic_root}/src"
  cp "${shim_src}" "${libatomic_root}/src/atomic_shim.c"

  (
    cd "${libatomic_root}/src"
    # -fno-builtin-__atomic_is_lock_free disables clang's recognition
    # of __atomic_is_lock_free as a language builtin. -fno-builtin alone
    # is not enough: it only covers library functions (memcpy, strlen,
    # ...); the __atomic_* family has its own opt-out.
    zig cc -target "${zig_target}" -c atomic_shim.c \
      -O2 -fno-builtin-__atomic_is_lock_free \
      -o atomic_shim.o
    zig ar rcs "${libatomic_prefix}/lib/libatomic.a" atomic_shim.o
  )
fi

# Make the linker pick up libatomic.a for the target. Appending
# -C link-arg=… to RUSTFLAGS preserves cargo-zigbuild's own linker
# wrapper (which it injects separately via CARGO_TARGET_<TARGET>_LINKER),
# so the static lib path lands on rustc's link line after the .rlib
# archives — guaranteeing libatomic.a is consulted last, after openssl's
# .a has been scanned for undefined symbols.
echo "RUSTFLAGS=${RUSTFLAGS:-} -C link-arg=-L${libatomic_prefix}/lib -C link-arg=-latomic" \
  >> "${GITHUB_ENV:-/dev/null}"
