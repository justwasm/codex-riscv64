#!/usr/bin/env bash
# Build a tiny libatomic.a shim providing __atomic_is_lock_free for musl
# i686 cross builds. The openssl static lib (compiled via install-musl-openssl.sh)
# references this symbol as a regular function call; Zig's musl sysroot
# doesn't ship libatomic, so without this shim the link step fails with
#   ld.lld: error: undefined symbol: __atomic_is_lock_free
#
# The i386 assembly shim at .github/patches/libatomic-shim/atomic_shim.S
# provides the missing runtime symbol without conflicting with clang's
# __atomic_is_lock_free language builtin.
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
shim_src="${GITHUB_WORKSPACE}/.github/patches/libatomic-shim/atomic_shim.S"

if [[ ! -f "${libatomic_prefix}/lib/libatomic.a" ]]; then
  mkdir -p "${libatomic_prefix}/lib" "${libatomic_root}/src"
  cp "${shim_src}" "${libatomic_root}/src/atomic_shim.S"

  (
    cd "${libatomic_root}/src"
    zig cc -target "${zig_target}" -c atomic_shim.S \
      -o atomic_shim.o
    zig ar rcs "${libatomic_prefix}/lib/libatomic.a" atomic_shim.o
  )
fi

# Force the shim object into the final link regardless of static archive
# ordering. A plain -latomic can be scanned before openssl introduces the
# undefined symbol and therefore skipped by the linker.
echo "RUSTFLAGS=${RUSTFLAGS:-} -C link-arg=-Wl,--whole-archive -C link-arg=${libatomic_prefix}/lib/libatomic.a -C link-arg=-Wl,--no-whole-archive" \
  >> "${GITHUB_ENV:-/dev/null}"
