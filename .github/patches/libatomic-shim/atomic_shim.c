// Stub for __atomic_is_lock_free, missing from Zig's i686-linux-musl sysroot.
//
// Background: openssl 3.6.x's threads_pthread.c calls
// __atomic_is_lock_free() as a runtime function (not a compiler
// builtin). On glibc this comes from libatomic; on musl+x86_64 it is
// expanded by clang/gcc into a constant; on i686-musl Zig's bundled
// sysroot does not provide it, so cargo-zigbuild's link step fails with
//   ld.lld: error: undefined symbol: __atomic_is_lock_free.
//
// The cheapest correct answer: report "not lock-free" so openssl falls
// back to the locking path. On i686 this is true for 8/16-byte atomics
// anyway, so the runtime behaviour matches what would happen with a
// real libatomic.
//
// Compiled into libatomic.a by .github/scripts/build-libatomic.sh and
// dropped into the musl cross link line.

#include <stddef.h>

int __atomic_is_lock_free(int size, void const *ptr) {
    (void)ptr;
    // Only 1/2/4-byte atomics are guaranteed lock-free on i386.
    return size == 1 || size == 2 || size == 4;
}
