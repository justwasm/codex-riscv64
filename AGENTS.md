# AGENTS.md

This repository builds the [Codex CLI](https://github.com/openai/codex) for
riscv64 on real RISC-V hardware (free Cloud-V GitHub runners) and publishes
rolling GitHub Releases, with x86_64 and i686 builds on hosted runners.
See `memory/Home.md` (loaded into every Crush session via `.crushrc`) for the
knowledge base, and `README.md` for user-facing instructions.

## Rules

- **Memory**: reusable experience goes into `memory/` as markdown, linked
  from `memory/Home.md`. The index is loaded into every session via
  `option context-path memory/Home.md` in `.crushrc`; keep it current.
- **Trigger discipline**: workflows only run on pushes touching
  `.github/workflows/*.yml` or `scripts/**`. README, memory, `.crushrc` or
  AGENTS.md changes must not be used to trigger builds — use
  `gh workflow run <name>.yml` (workflow_dispatch) instead.
- **Codex revision**: always change the commit via the repository variable
  `CODEX_PIN` (`gh variable set CODEX_PIN -b <sha>`), never by editing
  workflow files, so riscv64/x86_64/i686 stay in sync.
- **Rolling releases**: keep the `codex-<triple>-latest` tags as rolling
  latest builds; never create versioned tags unless asked.
- **Runner reality**: Cloud-V jobs start in fresh containers (nothing
  persists); the BPI-F3 board has 3.7 GB RAM (keep `CARGO_BUILD_JOBS=3`) and
  builds take 1-2 h. Don't re-push blindly to iterate — cancel stale runs
  first, one board, sequential jobs.
- **Cache hygiene**: GitHub cache quota is 10 GB/repo with 7-day LRU
  eviction. Keep the cache design in `memory/repo-layout.md`; any change to
  cache keys must preserve the `cache-hit != 'true'` save guard.
