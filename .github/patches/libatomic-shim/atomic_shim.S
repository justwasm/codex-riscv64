# i386 musl libatomic shim for OpenSSL 3.6.x.
#
# Zig's i686-linux-musl sysroot omits libatomic.a, while OpenSSL's
# threads_pthread.c calls __atomic_is_lock_free at runtime. Implement the
# one missing symbol in assembly so clang never sees a conflicting language
# builtin declaration. i386 cdecl: size_t is the first stack argument.

    .text
    .globl __atomic_is_lock_free
    .type __atomic_is_lock_free, @function
__atomic_is_lock_free:
    movl 4(%esp), %eax
    cmpl $4, %eax
    setbe %al
    movzbl %al, %eax
    ret

    .size __atomic_is_lock_free, .-__atomic_is_lock_free
