# Contributing

Thanks for helping improve Sing-box-EV.

## Development Principles

- Keep CLI behavior stable by default.
- Prefer small, isolated changes.
- Avoid mixing refactor and feature changes in one PR.
- Never remove user-facing commands without migration notes.

## Script Style

- Target shell: `bash`.
- Prefer quoted variables (`"$var"`) unless intentional word splitting is required.
- Prefer explicit function boundaries and single responsibility per file/module.
- Keep destructive operations (`rm -rf`, service stop/disable) guarded by clear conditions.

## Core Module Layout

- `src/core.sh`: compatibility wrappers and module loading.
- `src/core/00_env.sh`: shared constant arrays/defaults.
- `src/core/10_ui.sh`: UI helpers.
- `src/core/20_validate.sh`: validation helpers.
- `src/core/60_sub.sh`: subscription generation.
- `src/core/admin/`: menu/admin dispatch, update, uninstall.
- `src/core/domain/`: Reality domain pool operations.
- `src/core/node/`: create/change/delete flows.
- `src/core/query/`: read/query/URL flows.
- `src/core/runtime/`: runtime/service/doctor/snapshot operations.
- `src/core/utils/`: runtime utility helpers.

## Quality Checks

CI now runs:

- `shellcheck`
- `shfmt -d -i 4 -ci -sr`

Please run equivalent checks locally before opening a PR.

Local helper:

- `bash scripts/lint.sh`
- `bash scripts/smoke.sh`

## Commit/PR Guidance

- Use clear commit messages with scope (example: `refactor(core): split query module`).
- Include test notes in PR description (what commands were verified).
- For behavior changes, include before/after examples from CLI output.

