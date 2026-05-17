# Core Modules

This folder contains the refactored core modules for the Sing-box-EV script.

## Module Map

- `00_env.sh`
  - Shared constant arrays and default random selectors.
- `10_ui.sh`
  - UI helpers (`msg`, `pause`, list rendering, footer).
- `20_validate.sh`
  - Input and port validation helpers.
- `60_sub.sh`
  - Subscription generation flow.
- `admin/`
  - CLI/admin dispatch (`update`, `uninstall`, menu, `main` dispatch).
- `domain/`
  - Reality domain pool management, health checks, weighted selection.
- `node/`
  - Write/mutate flows (`create`, `add`, `change`, `del`).
- `query/`
  - Read/query flows (`get`, `info`, `url`, list all nodes).
- `runtime/`
  - Runtime/service operations (`manage`, `cron`, `doctor`, snapshot/rollback).
- `ui/`
  - Interactive prompt helpers.
- `utils/`
  - Runtime utilities such as download, BBR, log, and DNS helpers.

## Compatibility Rule

- Public function names used by CLI remain in `src/core.sh` as thin wrappers.
- `src/core.sh` loads the directory-based modules directly.
- Modules expose prefixed internal functions (`ui_*`, `validate_*`, `query_*`, `write_*`, `admin_*`).
- Keep behavior unchanged when moving logic between files.

