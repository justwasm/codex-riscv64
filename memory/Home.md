# Memory Index

Consolidated, reusable notes for this repo (codex-riscv64); loaded into every
Crush session via `option context-path` in `.crushrc`. Read topic files on
demand.

## Core topics

- [Repo layout & build pipeline](repo-layout.md)
- [Lessons & pitfalls](lessons.md)

## Facts worth remembering

- This repo builds the [Codex CLI](https://github.com/openai/codex) natively
  on a free Cloud-V RISC-V GitHub runner (Banana Pi BPI-F3, label
  `banana-pi-f3`, 8 cores / 3.7 GB RAM) and publishes rolling GitHub Releases
  for riscv64, x86_64 and i686.
- The codex revision is a repository variable `CODEX_PIN`
  (`gh variable set CODEX_PIN --repo justwasm/codex-riscv64 -b <sha>`); bumping
  it does not require editing workflows. Default fallback lives in the
  workflow `env` blocks.
- Rolling release tags: `codex-riscv64-latest`, `codex-x86_64-latest`,
  `codex-i686-latest`; each holds a single `codex-<triple>.tar.gz` asset that
  is replaced on every successful build.
