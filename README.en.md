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
| `sb doctor` | Run system diagnostics (environment/colors/dependencies/services/ports/config/network) |
| `sb dry-run <command> [args...]` | Preview command without applying writes/restarts |
| `sb dry-run uninstall` | Preview the complete uninstall scope without deleting anything |
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
├─ install.sh                         # one-click installer and bootstrap entry
├─ sing-box.sh                        # installed CLI entry; loads src/init.sh
├─ README.md                          # Chinese documentation
├─ README.en.md                       # English documentation
├─ CONTRIBUTING.md                    # contribution and development rules
├─ docs
│  └─ VPS_REGRESSION.md               # real VPS regression checklist
├─ scripts
│  ├─ check-structure.sh              # validates sourced module targets
│  ├─ check-release.sh                # validates version and release notes
│  ├─ lint.sh                         # local lint wrapper
│  ├─ regression-cli.sh               # repeatable CLI regression checks
│  ├─ smoke.sh                        # basic smoke checks
│  └─ smoke-reality.sh                # Reality-focused smoke checks
├─ .github
│  └─ workflows
│     ├─ lint.yml                     # GitHub Actions: Shell Lint
│     └─ release.yml                  # GitHub Actions: Auto Release
└─ src
   ├─ init.sh                         # initializes paths, runtime state, and core loading
   ├─ core.sh                         # module loading order and compatibility wrappers
   ├─ utils.sh                        # shared helper loader for install/runtime flows
   ├─ help.sh                         # help/about output
   ├─ caddy.sh                        # Caddy configuration generation and maintenance
   ├─ import.sh                       # external configuration import
   ├─ lib                             # shared libraries used by installer and runtime
   │  ├─ crypto.sh                    # UUID and Reality keypair helpers
   │  ├─ firewall.sh                  # firewall port tracking and cleanup
   │  ├─ fs.sh                        # safe file/dir operations and manifest helpers
   │  ├─ json.sh                      # jq writes and config validation helpers
   │  ├─ manifest.sh                  # install manifest read/write helpers
   │  ├─ net.sh                       # IP, port checks, and port allocation
   │  ├─ systemd.sh                   # systemd service writes and cleanup
   │  └─ tunnel.sh                    # Cloudflare Tunnel helpers
   └─ core                            # business core split by responsibility
      ├─ admin
      │  ├─ dispatch.sh               # unified CLI/menu command dispatch
      │  ├─ menu.sh                   # main menu rendering and input
      │  ├─ menu_actions.sh           # menu choice to command mapping
      │  ├─ uninstall.sh              # complete uninstall flow
      │  └─ update.sh                 # core/script/caddy update flow
      ├─ domain
      │  ├─ cli.sh                    # sb domain subcommands
      │  ├─ health.sh                 # DNS/TCP/TLS health checks and cache
      │  ├─ pick.sh                   # Reality SNI auto-pick
      │  ├─ pool.sh                   # built-in/custom/disabled pool merge
      │  └─ store.sh                  # local domain-pool file initialization
      ├─ env
      │  └─ defaults.sh               # protocols, change actions, built-in Reality domains
      ├─ node
      │  ├─ add.sh                    # add-node main flow
      │  ├─ create.sh                 # sing-box JSON config writing
      │  ├─ delete.sh                 # node config deletion
      │  ├─ change.sh                 # change-node main flow
      │  ├─ add/prepare.sh            # add-node parameter preparation
      │  └─ change/actions.sh         # port/key/SNI and other change actions
      ├─ query
      │  ├─ info.sh                   # node information display
      │  ├─ parse.sh                  # config reading and field parsing
      │  ├─ protocol.sh               # protocol JSON fragment preparation
      │  └─ url.sh                    # URL/QR/all-node output
      ├─ runtime
      │  ├─ cron.sh                   # automatic maintenance tasks
      │  ├─ doctor.sh                 # system diagnostics
      │  ├─ rollback.sh               # snapshot rollback
      │  ├─ service.sh                # service start/stop/restart
      │  └─ snapshot.sh               # snapshot create/list helpers
      ├─ sub/generate.sh              # subscription generation
      ├─ ui
      │  ├─ output.sh                 # output, lists, pause, footer
      │  └─ prompt.sh                 # protocol/config/common prompts
      ├─ utils
      │  ├─ bbr.sh                    # BBR enablement
      │  ├─ dns.sh                    # DNS settings
      │  ├─ download.sh               # version lookup and downloads
      │  └─ log.sh                    # log viewing
      └─ validate/input.sh            # domain, port, UUID, and path validation
```

### 5.1 Module Responsibility Quick Map

- `src/core/domain/`: Reality domain pool, weights, health checks, auto-pick
- `src/core/runtime/`: diagnostics, snapshots, rollback, service, cron
- `src/core/query/`: config parsing, node display, URL/QR output
- `src/core/node/`: node add/change/delete flows
- `src/core/admin/`: menu rendering, menu action mapping, CLI dispatch, update, uninstall
- `src/core/env/`: constants, protocol lists, defaults
- `src/core/ui/`: output, interactive prompts, pause, footer
- `src/core/validate/`: input and port validation
- `src/core/sub/`: subscription generation
- `src/lib/`: shared install-time and runtime helper libraries
- `src/core/utils/`: runtime utility helpers for download, BBR, logs, and DNS

Notes:

- Legacy numbered modules have been removed. `src/core.sh` now loads directory-based modules directly.
- The menu and command layers are separated: `menu.sh` only renders and reads choices, `menu_actions.sh` maps choices to commands, and `dispatch.sh` executes commands.
- Add new behavior under the closest responsibility-based module instead of creating another large all-in-one file.

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
4. Update defaults under `src/core/env/` if needed
5. Update docs in `src/help.sh`

### 7.3 Local Checks

```bash
bash scripts/lint.sh
bash scripts/check-release.sh
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

`regression-cli.sh` also runs `NO_COLOR=1 sb doctor` to ensure diagnostics remain readable in plain log output. Regular `sb doctor` prints a terminal color sample to help diagnose SSH/client color issues.

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
- Release body source: the matching version's `### 主要变化` section in `RELEASE_NOTES.md`
- Auto-release runs when version tag is new

Before release, verify:

1. `is_sh_ver` is updated
2. `RELEASE_NOTES.md` contains `### 主要变化` for the target version
3. `bash scripts/check-release.sh` passes
4. local lint/smoke checks pass
5. README/help docs reflect behavior
6. VPS regression checklist has been run as appropriate for the risk level

To verify that a new release tag does not already exist locally before publishing:

```bash
RELEASE_CHECK_STRICT_TAG=1 bash scripts/check-release.sh
```

---

## 10. Where to Edit for Common Dev Tasks

### Add a new command

- Routing: `src/core/admin/dispatch.sh`
- Help docs: `src/help.sh`
- Optional wrapper: `src/core.sh`

### Add/change protocol fields

- Defaults: `src/core/env/`
- Write path: `src/core/node/`
- Display/URL path: `src/core/query/`
- Validation: `src/core/validate/`

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
