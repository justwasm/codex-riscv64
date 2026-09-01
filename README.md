# codex-riscv64

Builds the [Codex CLI](https://github.com/openai/codex) for **riscv64** (and x86_64) and publishes the binaries as GitHub Releases.

## Binaries

| Target | Release tag | Asset |
| ------ | ----------- | ----- |
| riscv64 (linux-gnu) | `codex-riscv64-latest` | `codex-riscv64-unknown-linux-gnu.tar.gz` |
| x86_64 (linux-gnu) | `codex-x86_64-latest` | `codex-x86_64-unknown-linux-gnu.tar.gz` |

Each tarball contains:

- `codex-<triple>`: the Codex CLI binary
- `bwrap-<arch>`: the bubblewrap sandbox helper used by Codex on Linux

### Install on RISC-V (e.g. VisionFive 2, BPI-F3, Milk-V Pioneer)

```sh
curl -fsSL -o codex-riscv64.tar.gz \
  https://github.com/justwasm/codex-riscv64/releases/latest/download/codex-riscv64-unknown-linux-gnu.tar.gz
tar -xzf codex-riscv64.tar.gz
sudo mv codex-riscv64-unknown-linux-gnu /usr/local/bin/codex
codex --version
```

## How it works

- `.github/workflows/riscv64-build.yml` builds natively on a Cloud-V free RISC-V
  runner (Banana Pi BPI-F3 board, label `banana-pi-f3`, real RV64GC hardware).
  The board is slow (8 cores, ~3.7 GB RAM), so the build is limited to
  `CARGO_BUILD_JOBS=3` and the `target/` directory plus the cargo registry are
  cached via `actions/cache` (GitHub's 10 GB/repo quota, 7-day LRU eviction).
- `.github/workflows/x86_64-build.yml` builds the same pinned revision on a
  standard `ubuntu-latest` runner so the publish pipeline can be validated
  quickly and both architectures stay in sync.
- Each successful build packages the binaries, uploads them as a workflow
  artifact (30-day retention) and publishes them to the rolling release tag,
  overwriting the previous asset.

## Updating the codex revision

The revision is stored in the repository variable `CODEX_PIN`. Bump it without
touching any file:

```sh
gh variable set CODEX_PIN --repo justwasm/codex-riscv64 -b <new-full-sha>
gh workflow run riscv64-build.yml --repo justwasm/codex-riscv64
```

The default (used when the variable is unset) is the commit pinned in the
workflow files.

## RISC-V runner notes

The RISC-V jobs run on a free Cloud-V GitHub runner provisioned per repository
(see the
[Cloud-V docs](https://10x-engineers.github.io/riscv-ci-partners/setting_up_github_runner/)).
Every job starts in a fresh container, so nothing persists between runs: the
cargo caches are the only thing carried over, and they live in GitHub's cache
service. First-time provisioning of a board takes a few minutes.
