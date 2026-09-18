# codex-riscv64

Builds the [Codex CLI](https://github.com/openai/codex) for several Linux
architectures and publishes the binaries as GitHub Releases.

## Releases

- Rolling "always current" tag: [`codex-linux-musl-latest`](https://github.com/justwasm/codex-riscv64/releases/tag/codex-linux-musl-latest).
  A single release with one asset per architecture. Updatable: each run
  overwrites its own asset (x86_64 / i686 / aarch64 / riscv64 stay
  independent of each other within this release).
- Immutable per-run tags: `codex-linux-musl-YYYYMMDD-SHORTSHA`. One tag
  per successful dispatch — every commit that produced a release is
  pinned and downloadable forever. Use these when you need a specific
  revision (regression bisection, comparing two builds, audit).

Both tag families point at the same kind of asset; pick the latest run for
"fresh" or a specific dated tag when you need determinism.

## Binaries

All four architectures ship as fully static musl binaries — no glibc
binding, no system library dependency. Verified before publish:

- `readelf` shows no `PT_INTERP` and no `(NEEDED)` entries.
- The artifact runs under Alpine 3.21 via QEMU user-mode (`--version`,
  `--help`).

### Asset layout

Each tarball contains exactly one binary:

| Tarball | Layout |
| ------- | ------ |
| `codex-<arch>-unknown-linux-musl.tar.gz` | `codex-<arch>-unknown-linux-musl` (the static binary) |

The bundled `bwrap` / `helpers/` from the upstream glibc release are
**intentionally not included** on the musl path. Two reasons:

1. `helpers/` is a vendored `node_modules` tree (browser/terminal control
   helpers, ~70 MB compressed) that's host-ABI-specific — it would have to
   be rebuilt per arch and would re-bloat every tarball. Most users don't
   need it; `codex --help` works without it.
2. `bwrap` (bubblewrap) is only used by codex's opt-in `--sandbox` flag
   when landlock isn't available (older kernels, some musl builds). Modern
   distros — and Alpine 3.21 — ship landlock in the default kernel, so
   codex's default sandbox mode doesn't need bwrap. If you specifically
   need it, install `bubblewrap` via your package manager; codex will pick
   it up at runtime.

If you want the bundled helpers + bwrap instead, see the upstream
[openai/codex](https://github.com/openai/codex) glibc release tarballs.

### Architectures

| Target | Static musl tag |
| ------ | --------------- |
| `x86_64-unknown-linux-musl` | `codex-linux-musl-latest` (asset: `codex-x86_64-unknown-linux-musl.tar.gz`) |
| `i686-unknown-linux-musl` | same tag (asset: `codex-i686-unknown-linux-musl.tar.gz`) |
| `aarch64-unknown-linux-musl` | same tag (asset: `codex-aarch64-unknown-linux-musl.tar.gz`) |
| `riscv64gc-unknown-linux-musl` | same tag (asset: `codex-riscv64-unknown-linux-musl.tar.gz`) |

### Install

The binary works on any x86_64 / i686 / aarch64 / riscv64 Linux (glibc
or musl based). Example for x86_64:

```sh
curl -fsSL -o codex.tar.gz \
  https://github.com/justwasm/codex-riscv64/releases/latest/download/codex-x86_64-unknown-linux-musl.tar.gz
tar -xzf codex.tar.gz
sudo mv codex-x86_64-unknown-linux-musl /usr/local/bin/codex
codex --version
```

For a specific build:

```sh
curl -fsSL -o codex.tar.gz \
  https://github.com/justwasm/codex-riscv64/releases/download/codex-linux-musl-YYYYMMDD-SHORTSHA/codex-<arch>-unknown-linux-musl.tar.gz
```

## How it works

- `.github/workflows/musl-build.yml` is a single matrix job that builds
  `codex` (only) for `x86_64`, `i686`, `aarch64`, `riscv64` × `musl` on
  `ubuntu-latest` GitHub-hosted runners. Cross-compile uses cargo-zigbuild
  with a pinned Zig 0.17 dev build + `zig cc -target <arch>-linux-musl`
  for the C deps (openssl, libatomic shim on i686, libcap).
- The native RISC-V workflow (`.github/workflows/riscv64-build.yml`) and
  the legacy gnu workflows (`x86_64-build.yml`, `i686-build.yml`) remain
  in place as historical artifacts. Their separate per-arch tags
  (`codex-riscv64-latest`, etc.) are kept for backwards compatibility but
  no longer ship new builds.
- Each successful build runs `readelf` to confirm no dynamic loader or
  `NEEDED` entries, then exercises `codex --version` and `--help` under
  Alpine 3.21 + QEMU before publishing.
- Cache layer: `actions/cache` keeps the cargo registry, the `target/`
  build dir, and the musl openssl/libatomic sysroot per architecture.
  Subsequent runs on the same lock hash hit a warm cache and finish in
  minutes instead of the 40-min cold build.

## Updating the codex revision

The revision is stored in the repository variable `CODEX_PIN`. Bump it
without touching any file:

```sh
gh variable set CODEX_PIN --repo justwasm/codex-riscv64 -b <new-full-sha>
gh workflow run musl-build.yml --repo justwasm/codex-riscv64
```

The default (used when the variable is unset) is the commit pinned in the
workflow files.

## RISC-V runner notes (legacy)

`.github/workflows/riscv64-build.yml` still builds natively on a Cloud-V
RISC-V free runner (Banana Pi BPI-F3 board). The musl-build workflow
supersedes it: it cross-compiles `riscv64gc-unknown-linux-musl` from
`ubuntu-latest`. Keep the native RISC-V job as a canary for now in case
cross-compilation regressions surface only on real hardware.
