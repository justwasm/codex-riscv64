// Stub for __atomic_is_lock_free, missing from Zig's i686-linux-musl sysroot.
//
// Background: openssl 3.6.x's threads_pthread.c calls
// __atomic_is_lock_free() as a runtime function (not a compiler
// builtin). On glibc this comes from libatomic; on musl+x86_64 it is
// expanded by clang/gcc into a constant; on i686-musl Zig's bundled
// sysroot does not provide it, so cargo-zigbuild's link step fails with
//   ld.lld: error: undefined symbol: __atomic_is_lock_free.
//
// Clang's language-extension builtins (the __atomic_* family,
// __builtin_object_size, etc.) cannot be turned off per-function with
// -fno-builtin-<name> — that flag is only consulted for libc/libm
// symbols. The only clean way to define a function with the same
// symbol as a builtin is to define it under a different name and
// asm-alias it. Compiled into libatomic.a by .github/scripts/build-libatomic.sh
// and dropped into the musl cross link line.
//
// Signature matches clang's predeclaration so the alias resolves
// without surprises: _Bool return, size_t + const volatile ptr. On
// i386 we report 1/2/4-byte as lock-free and 8/16-byte as not — that
// is the truth on this arch, and matches what a real libatomic.a
// would say.

#include <stddef.h>

static _Bool atomic_is_lock_free_shim(size_t size, void const volatile *ptr) {
    (void)ptr;
    return size == 1 || size == 2 || size == 4;
}

// asm-alias overrides the builtin interpretation and exposes the
// symbol under the name openssl/threads_pthread.c actually calls.
__asm__(
    ".global __atomic_is_lock_free\n"
    "__atomic_is_lock_free = atomic_is_lock_free_shim"
);
