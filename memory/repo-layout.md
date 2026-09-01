# Repo layout & build pipeline

## Purpose

Builds the Codex CLI (`github.com/openai/codex`, Rust workspace in
`codex-rs/`) for riscv64 on real RISC-V hardware (Cloud-V free runners), plus
x86_64 and i686 reference builds on hosted `ubuntu-latest` runners. All three
publish to rolling GitHub Releases.

## Layout

- `.github/workflows/riscv64-build.yml` — native riscv64 build on Cloud-V
  board runner.
- `.github/workflows/x86_64-build.yml` — native x86_64 build on
  `ubuntu-latest`.
- `.github/workflows/i686-build.yml` — 32-bit x86 cross build
  (`i686-unknown-linux-gnu`) on `ubuntu-latest` with gcc-multilib.
- `memory/` — this knowledge base; `Home.md` is the index.
- `codex/` — NOT in this repo; each job clones `openai/codex` at `CODEX_PIN`.

## Build facts (learned empirically)

- Toolchain: rustup default 1.95.0 (matches `codex-rs/rust-toolchain.toml`);
  riscv64 host triple is `riscv64gc-unknown-linux-gnu`, fully supported.
- Build command: `cargo build --release --locked --bin codex --bin bwrap`
  (mirrors upstream release; bwrap is Codex's sandbox helper, needs libcap).
- System deps: `build-essential pkg-config libcap-dev bubblewrap cmake jq
  libssl-dev`. **libssl-dev is required** — without it the build dies in
  `openssl-sys@0.9.111` with "Could not find directory of OpenSSL
  installation". Upstream CI skips it only because they build musl with a
  hermetic toolchain.
- aws-lc-sys compiles fine natively on riscv64 (the historical risk passed).
- RAM is the constraint on the board (3.7 GB total): `CARGO_BUILD_JOBS=3`,
  `CARGO_INCREMENTAL=0`. A full release build takes roughly 1-2 h on the
  BPI-F3.

## Cloud-V runner behaviour (docs + observed)

- Fresh container per job; nothing persists between runs (no leftover files,
  no installed packages). Install everything in a step, every time.
- Labels: `visionfive2`/`banana-pi-f3`/`milkv-pioneer` (aliases exist). One
  runner per board type per repo; jobs for the same board run sequentially.
- First job for a repo provisions the board (a few minutes); between
  back-to-back jobs there can be a 1-3 min replacement gap.
- Runner image: `cloudv10x/github-actions-riscv` (Ubuntu 24.04 riscv64), ships
  gcc, make, git, curl, sudo, Docker. Node20 actions run (forced to node24);
  `actions/checkout@v4` works.
- Live job logs are NOT streamable while a job runs (API returns
  BlobNotFound); wait for completion then `gh run view --log`.
- Board is shared hardware: avoid pulling enormous images.

## Caching design

- GitHub Actions cache: 10 GB per repo (user-owned repos can raise it, billed),
  LRU eviction after 7 days of inactivity, immutable entries, downloads in
  2 GB segments.
- Two entries per arch, keyed on `sha256(Cargo.lock)` (+ toolchain for
  target): `riscv64-registry-<lock>` (cargo registry + git db) and
  `riscv64-target-<lock>-<toolchain>` (whole `codex/codex-rs/target`).
- `actions/cache/restore@v4` then `save@v4`. **Critical gotcha**:
  `save` fails if the key already exists (cache hit), so each save step must
  be guarded with `if: always() && steps.<id>.outputs.cache-hit != 'true'`.
- First run of a new lock hash is a full rebuild; subsequent runs restore the
  target dir and only re-link.

## Publishing

- Package: tarball with `codex-<triple>` and `bwrap-<arch>`, sha256 logged.
- Artifact via `actions/upload-artifact@v4` (30-day retention), then a rolling
  release via curl + `GITHUB_TOKEN` (no gh CLI dependency on the runner):
  1. GET `/releases/tags/<tag>`; POST to create if missing (tolerate 422
     races with `|| true`).
  2. DELETE stale asset with same name (GET assets, pick by name, DELETE).
  3. POST binary to `uploads.github.com/...?name=<asset>`.
- Gotcha: **draft releases are invisible to GET /releases/tags/{tag}** (404).
  The workflow always creates published releases, so the GET-by-tag flow
  works; validated locally with a throwaway published release.
- `permissions: contents: write` is required on the job for release
  create/delete/upload.
