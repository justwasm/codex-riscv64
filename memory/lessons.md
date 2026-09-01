# Lessons & pitfalls

Session-learned lessons for working with this repo and Cloud-V RISC-V CI.

## Concurrency & run management

- `concurrency: cancel-in-progress: true` cancels **pending** runs of the
  same workflow immediately when a new one is queued. Observed: in-progress
  runs can survive a new push; don't rely on auto-cancel to stop a
  known-failing run — cancel it manually (`gh run cancel <id>`).
- Every push to `main` triggered the workflows until path filters were added
  (`paths:` on the workflow's own file + `scripts/**`). README/docs/memory
  changes now don't re-trigger builds.
- GitHub once auto-created duplicate runs for the same SHA while runs were
  being cancelled/superseded; treat run listings as the source of truth and
  cancel what you don't need.
- Pushing a fixed workflow while an old-version run is executing wastes board
  time: the old run still runs its old (possibly failing) steps. Cancel
  stale in-progress runs explicitly before letting the fixed queue proceed.

## Build

- Missing `libssl-dev` → `openssl-sys` build-script failure. Symptom:
  "Could not find directory of OpenSSL installation". Add it to apt installs.
- `rustup` prints "error: $HOME differs from euid-obtained home directory"
  on the Cloud-V container — it is a warning; installation proceeds.
- Keep `CARGO_BUILD_JOBS` low (3) on the BPI-F3; default 8 OOMs on 3.7 GB.
- `rust-toolchain.toml` in codex pins components (clippy, rustfmt, rust-src);
  install them explicitly before the build step to avoid mid-build surprises.
- Run smoke test (`codex --version`) before packaging so a broken binary
  never reaches the release.

## Caching

- `actions/cache/save@v4` errors if the cache key already exists (i.e. on a
  restore hit). Always guard saves with `cache-hit != 'true'`.
- Compute the cache key from `Cargo.lock` AFTER cloning codex (the lockfile
  is not in this repo); source `$HOME/.cargo/env` in that step so the
  toolchain hash is real, not "unknown".
- GitHub cache quota is 10 GB/repo: keep target dir lean (no debug builds,
  `CARGO_INCREMENTAL=0`), and split registry vs target into two entries.

## Publishing

- Draft releases 404 on `GET /releases/tags/{tag}` — never use drafts in the
  publish script.
- The create-release POST can race with a concurrent run creating the same
  tag: tolerate 422 (`|| true`), then re-fetch the id.
- `gh release delete --cleanup-tag` can fail with 422 if the tag ref was
  already removed; plain `gh release delete` then works.
- Validate the whole publish flow against a throwaway published release
  before the first real build lands (cheap insurance for a 2-hour build).

## Workflow style

- Async over sync: `gh run watch` in background shells, poll statuses via the
  API, never block one task on another when the runner fleet is shared.
- Small steps on the real runner: env check → toolchain → fetch deps →
  build → package/publish. Each push validates one more layer, and failures
  arrive with clear logs instead of a wall of assumptions.
