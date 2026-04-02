# Core Modules

This folder contains the refactored core modules for the Sing-box-EV script.

## Module Map

- `00_env.sh`
  - Shared constant arrays and default random selectors.
- `10_ui.sh`
  - UI helpers (`msg`, `pause`, list rendering, footer).
- `20_validate.sh`
  - Input and port validation helpers.
- `30_runtime.sh`
  - Runtime/service operations (`manage`, `cron` workflow).
- `40_node_query.sh`
  - Read/query flows (`get`, `info`, `url`, list all nodes).
- `50_node_write.sh`
  - Write/mutate flows (`create`, `add`, `change`, `del`).
- `60_sub.sh`
  - Subscription generation flow.
- `70_admin.sh`
  - CLI/admin dispatch (`update`, `uninstall`, menu, `main` dispatch).

## Compatibility Rule

- Public function names used by CLI remain in `src/core.sh` as thin wrappers.
- Modules expose prefixed internal functions (`ui_*`, `validate_*`, `query_*`, `write_*`, `admin_*`).
- Keep behavior unchanged when moving logic between files.


