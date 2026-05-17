# Sing-box-EV

[中文文档](./README.md) | English

Sing-box-EV is a Linux server management script project for `sing-box`.
It provides:

- One-click install and update
- TUI menu + CLI shortcuts
- Multi-protocol node management (including Reality / AnyTLS / CFtunnel)
- Subscription export tools
- Basic ops automation (service control, log cleanup, cron tasks)

This README is written for two audiences:

- Users: install and manage nodes quickly
- Developers: start contributing even on first contact with this codebase

---

## 1. Feature Overview

- 20+ protocols and combinations
- Menu-driven and command-driven workflows
- Subscription export (Base64 / temporary web endpoint)
- Reality domain pool management (health checks, weight, region)
- Cloudflare Tunnel support for no-public-IP scenarios

---

## 2. Environment Requirements

### 2.1 Server Runtime

- Ubuntu 20.04+
- Debian 11+
- CentOS 7+
- Architecture: `x86_64` / `arm64`
- Root user required
- Typical dependencies: `wget` `curl` `tar` `jq` (installer will try to install)

### 2.2 Development Environment

- Any environment with `bash` (Linux/macOS/WSL recommended)
- Recommended tools:
  - `shellcheck`
  - `shfmt`
- Optional:
  - A test VPS for integration checks

---

## 3. Quick Install (User)

```bash
bash <(curl -s -L https://raw.githubusercontent.com/LuoPoJunZi/sing-box-ev/main/install.sh)
```

Fallback:

```bash
bash <(curl -s -L https://github.com/LuoPoJunZi/sing-box-ev/raw/main/install.sh)
```

Common startup commands:

```bash
sb
sb help
sb version
sb status
```

---

## 4. Common Commands (User)

| Command | Description |
| --- | --- |
| `sb a <protocol>` | Add a node, e.g. `sb a reality` |
| `sb i <name>` | Show node details |
| `sb c <name>` | Change node settings |
| `sb d <name>` | Delete node |
| `sb sub` | Generate subscription |
| `sb all` | Print all node URLs |
| `sb log` | Tail runtime logs |
| `sb update` | Update core/script |
| `sb doctor` | Run system diagnostics (service/config/network) |
| `sb dry-run <command> [args...]` | Preview command without applying writes/restarts |
| `sb backup list` | List configuration snapshots |
| `sb backup create [reason]` | Create a snapshot manually |
| `sb rollback [snapshot_id]` | Roll back to a snapshot |
| `sb domain list` | List Reality domain pool |
| `sb domain add <domain> [weight] [region]` | Add a domain |
| `sb domain del <domain>` | Remove/disable a domain |
| `sb domain test [region] [domain]` | Run health checks |
| `sb domain pick [region]` | Preview selected domain |

---

## 5. Repository Structure (Developer)

```text
.
├─ install.sh
├─ sing-box.sh
├─ src
│  ├─ init.sh
│  ├─ core.sh
│  ├─ utils.sh
│  ├─ help.sh
│  ├─ caddy.sh
│  ├─ import.sh
│  ├─ lib
│  │  ├─ fs.sh / json.sh / net.sh
│  │  ├─ manifest.sh / systemd.sh / firewall.sh
│  │  └─ crypto.sh / tunnel.sh
│  └─ core
│     ├─ 00_env.sh
│     ├─ 10_ui.sh
│     ├─ 20_validate.sh
│     ├─ 25_domain.sh
│     ├─ 30_runtime.sh
│     ├─ 40_node_query.sh
│     ├─ 50_node_write.sh
│     ├─ 60_sub.sh
│     ├─ 70_admin.sh
│     ├─ admin / domain / node / query / runtime / ui
│     └─ utils
├─ scripts
│  ├─ check-structure.sh
│  ├─ lint.sh
│  ├─ regression-cli.sh
│  ├─ smoke.sh
│  └─ smoke-reality.sh
├─ docs
│  └─ VPS_REGRESSION.md
└─ .github/workflows
   ├─ lint.yml
   └─ release.yml
```

### 5.1 Module Responsibility Quick Map

- `00_env.sh`: constants and defaults
- `10_ui.sh`: output and UI helpers
- `20_validate.sh`: input/port validation
- `25_domain.sh`: compatibility loader for `src/core/domain/`
- `30_runtime.sh`: compatibility loader for `src/core/runtime/`
- `40_node_query.sh`: compatibility loader for `src/core/query/`
- `50_node_write.sh`: compatibility loader for `src/core/node/`
- `60_sub.sh`: subscription generation
- `70_admin.sh`: compatibility loader for menu and CLI dispatch in `src/core/admin/`
- `src/lib/`: shared install-time and runtime helper libraries
- `src/core/utils/`: runtime utility helpers for download, BBR, logs, and DNS

---

## 6. Execution Flow (Fastest Way to Understand)

For `sb add reality`, the call chain is:

1. `sing-box.sh` receives CLI args
2. `src/init.sh` initializes runtime variables and loads core
3. `src/core.sh` loads modules and compatibility wrappers
4. `src/core/admin/dispatch.sh` dispatches the command
5. `src/core/node/` handles write path
6. `src/core/query/` handles render/URL path

Rule of thumb:

- Dispatch in `src/core/admin/dispatch.sh`
- Write logic in `src/core/node/`
- Read/display logic in `src/core/query/`
- Keep concerns separated in PRs

---

## 7. New Contributor Workflow (Recommended)

### 7.1 First Read Order

1. `README.md`
2. `CONTRIBUTING.md`
3. `src/core/README.md`
4. `src/core/admin/dispatch.sh`
5. Target module (`src/core/node/`, `src/core/query/`, etc.)

### 7.2 First Change Pattern

Example: changing Reality add behavior

1. Check command routing in `src/core/admin/dispatch.sh`
2. Edit input/write logic under `src/core/node/`
3. Sync render and URL under `src/core/query/`
4. Update defaults in `00_env.sh` if needed
5. Update docs in `src/help.sh`

### 7.3 Local Checks

```bash
bash scripts/lint.sh
bash scripts/smoke.sh
bash scripts/regression-cli.sh
# Optional on test host:
bash scripts/smoke-reality.sh
```

`smoke-reality.sh` creates and removes Reality test nodes; run it on test environments only.
Full VPS regression steps are documented in [docs/VPS_REGRESSION.md](./docs/VPS_REGRESSION.md).

For read-only CLI checks:

```bash
bash scripts/regression-cli.sh
```

On a disposable VPS where snapshot creation is allowed:

```bash
ALLOW_WRITES=1 bash scripts/regression-cli.sh
```

---

## 8. Reality Domain Pool Development Notes

`src/core/domain/` provides:

1. Pool aggregation: built-in + custom domains
2. Weighted selection: high weight has higher chance
3. Health probing: DNS / TCP443 / TLS handshake (degrades by available tools)
4. Recent avoidance: reduce repeated SNI reuse

Data files are stored under `$is_sh_dir` (usually `/etc/sing-box/sh`):

- `domain_custom.list`
- `domain_disabled.list`
- `domain_health.cache`
- `domain_recent.list`

If you extend selection strategy, prioritize adding it under `src/core/domain/` instead of scattering logic in query/write modules.

---

## 9. CI, Release, and Versioning

### 9.1 CI

- Workflow: `.github/workflows/lint.yml`
- Checks: `shellcheck` + `shfmt` + structure checks

### 9.2 Release

- Workflow: `.github/workflows/release.yml`
- Version source: `is_sh_ver` in `src/init.sh`
- Auto-release runs when version tag is new

Before release, verify:

1. `is_sh_ver` is updated
2. local lint/smoke checks pass
3. README/help docs reflect behavior
4. VPS regression checklist has been run as appropriate for the risk level

---

## 10. Where to Edit for Common Dev Tasks

### Add a new command

- Routing: `src/core/admin/dispatch.sh`
- Help docs: `src/help.sh`
- Optional wrapper: `src/core.sh`

### Add/change protocol fields

- Defaults: `src/core/00_env.sh`
- Write path: `src/core/node/`
- Display/URL path: `src/core/query/`
- Validation: `src/core/20_validate.sh`

### Change runtime behavior

- Service/cron operations: `src/core/runtime/`
- Service templates: `src/lib/systemd.sh`
- Download logic: `src/core/utils/download.sh`

---

## 11. FAQ (Developer View)

### Q1: I changed a command but it does not show up.

Check command dispatch in `src/core/admin/dispatch.sh` and wrapper exposure in `src/core.sh`.

### Q2: Config is correct but URL output is wrong.

Write logic is under `src/core/node/`; URL rendering is under `src/core/query/`. Both may require updates.

### Q3: Lint passes but runtime fails.

This project depends on runtime tools (`jq`, `openssl`, `timeout`, etc.). Validate on a real Linux host.

### Q4: I want to disable one Reality domain quickly.

```bash
sb domain del example.com
```

For built-in domains, this writes to disable list without source edits.

---

## 12. Security and Ops Reminders

- Do not run unknown scripts on production hosts
- Double-check changes touching `rm -rf`, `systemctl disable`, or `crontab -`
- In PRs, include risk and rollback notes for operational changes

---

## 13. Contribution and Acknowledgements

- Contribution guide: [CONTRIBUTING.md](./CONTRIBUTING.md)
- Upstream core: `SagerNet/sing-box`
- This project is a refactor/extension built on the 233boy ecosystem
- License: GPL v3
