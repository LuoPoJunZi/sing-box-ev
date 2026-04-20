# Sing-box-EV

中文文档 | [English](./README.en.md)

Sing-box-EV 是一个面向 Linux 服务器的 `sing-box` 管理脚本项目。它提供：

- 一键安装与更新
- TUI 菜单操作
- CLI 快捷命令
- 多协议节点管理（含 Reality / AnyTLS / CFtunnel）
- 基础自动运维（服务管理、日志清理、定时任务）

这份 README 的目标是让两类人都能快速上手：

- 使用者：快速安装和管理节点
- 开发者：即使第一次接触这个项目，也能在 30 分钟内开始改代码

---

## 1. 功能概览

- 支持 20+ 协议与组合
- 菜单 + 命令行双入口
- 订阅聚合导出（Base64 / 临时 Web）
- Reality 域名池管理（健康检查、权重、区域）
- Cloudflare Tunnel 场景支持（无公网 IP 可用）

---

## 2. 运行环境

### 2.1 服务器环境（运行脚本）

- Ubuntu 20.04+
- Debian 11+
- CentOS 7+
- 架构：`x86_64` / `arm64`
- 必须使用 `root`
- 依赖：`wget` `curl` `tar` `jq`（安装脚本会尽量自动补齐）

### 2.2 开发环境（改代码）

- 任意能运行 `bash` 的开发机（Linux / macOS / WSL 推荐）
- 建议安装：
  - `shellcheck`
  - `shfmt`
- 可选：
  - 一台测试 VPS（用于真实验证 `sb add` / `sb restart`）

---

## 3. 快速安装（用户）

```bash
bash <(curl -s -L https://raw.githubusercontent.com/LuoPoJunZi/sing-box-ev/main/install.sh)
```

备用：

```bash
bash <(curl -s -L https://github.com/LuoPoJunZi/sing-box-ev/raw/main/install.sh)
```

安装后常用命令：

```bash
sb          # 打开主菜单
sb help     # 查看帮助
sb version  # 查看版本
sb status   # 查看运行状态
```

---

## 4. 常用命令（用户）

| 命令 | 说明 |
| --- | --- |
| `sb a <protocol>` | 添加节点，例如 `sb a reality` |
| `sb i <name>` | 查看单节点信息 |
| `sb c <name>` | 更改节点配置 |
| `sb d <name>` | 删除节点 |
| `sb sub` | 生成订阅 |
| `sb all` | 列出所有节点链接 |
| `sb log` | 查看日志 |
| `sb update` | 更新核心/脚本 |
| `sb doctor` | 系统诊断（服务/配置/网络） |
| `sb dry-run <command> [args...]` | 预演命令，不执行写入/重启 |
| `sb backup list` | 查看配置快照 |
| `sb backup create [reason]` | 手动创建快照 |
| `sb rollback [snapshot_id]` | 回滚到快照 |
| `sb domain list` | 查看 Reality 域名池 |
| `sb domain add <domain> [weight] [region]` | 添加域名到域名池 |
| `sb domain del <domain>` | 从域名池移除域名 |
| `sb domain test [region] [domain]` | 做健康检查 |
| `sb domain pick [region]` | 预览自动选择结果 |

---

## 5. 仓库结构（开发者必读）

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
│  └─ core
│     ├─ 00_env.sh
│     ├─ 10_ui.sh
│     ├─ 20_validate.sh
│     ├─ 25_domain.sh
│     ├─ 30_runtime.sh
│     ├─ 40_node_query.sh
│     ├─ 50_node_write.sh
│     ├─ 60_sub.sh
│     └─ 70_admin.sh
├─ scripts
│  ├─ lint.sh
│  ├─ smoke.sh
│  └─ smoke-reality.sh
└─ .github/workflows
   ├─ lint.yml
   └─ release.yml
```

### 5.1 模块职责速查

- `00_env.sh`：常量、协议列表、默认值
- `10_ui.sh`：UI 输出、暂停、页脚
- `20_validate.sh`：输入/端口校验
- `25_domain.sh`：Reality 域名池、权重和健康探测
- `30_runtime.sh`：服务启停、Cron 任务
- `40_node_query.sh`：查询/展示/URL 生成
- `50_node_write.sh`：新增/修改/删除配置
- `60_sub.sh`：订阅生成
- `70_admin.sh`：菜单和命令分发

---

## 6. 调用链路（理解代码最快方式）

执行 `sb add reality` 时，路径如下：

1. `sing-box.sh` 接收参数
2. `src/init.sh` 初始化环境并加载核心
3. `src/core.sh` 加载模块并提供兼容包装
4. `src/core/70_admin.sh` 路由命令
5. `src/core/50_node_write.sh` 处理写入
6. `src/core/40_node_query.sh` 生成展示和 URL

简单原则：

- 分发逻辑在 `70_admin.sh`
- 写入逻辑在 `50_node_write.sh`
- 查询展示在 `40_node_query.sh`
- 不要把分发、写入、查询混在同一个改动里

---

## 7. 新人接手开发流程（推荐）

### 7.1 第一次克隆后做什么

```bash
git clone https://github.com/LuoPoJunZi/sing-box-ev.git
cd sing-box-ev
```

阅读顺序建议：

1. `README.md`
2. `CONTRIBUTING.md`
3. `src/core/README.md`
4. `src/core/70_admin.sh`
5. 目标模块（例如 `50_node_write.sh`）

### 7.2 第一个改动怎么做

示例：你要改 `Reality` 新增参数

1. 在 `70_admin.sh` 确认命令入口
2. 在 `50_node_write.sh` 修改入参解析和写入逻辑
3. 在 `40_node_query.sh` 确认 URL/展示同步
4. 若新增默认项，更新 `00_env.sh`
5. 更新帮助文档（`help.sh`）

### 7.3 本地检查

```bash
bash scripts/lint.sh
bash scripts/smoke.sh
# 可选：真实环境下
bash scripts/smoke-reality.sh
```

`smoke-reality.sh` 会创建并删除 Reality 测试节点，请只在测试机执行。

---

## 8. Reality 域名池开发说明

`25_domain.sh` 提供了四类能力：

1. 域名池聚合：内置 + 自定义
2. 加权选择：高权重域名更容易被挑中
3. 健康探测：DNS / TCP443 / TLS 探针（按可用工具降级）
4. 最近避让：避免连续重复同一 SNI

存储文件位于：`$is_sh_dir`（默认 `/etc/sing-box/sh`）

- `domain_custom.list`
- `domain_disabled.list`
- `domain_health.cache`
- `domain_recent.list`

如果你要扩展策略（比如按运营商/ASN），优先从 `25_domain.sh` 扩展，不要把策略散落到 `40/50` 模块。

---

## 9. CI、发布与版本

### 9.1 CI

- `.github/workflows/lint.yml`
- 执行：`shellcheck` + `shfmt`

### 9.2 发布

- `.github/workflows/release.yml`
- 从 `src/init.sh` 的 `is_sh_ver` 提取版本
- 若 tag 不存在则自动打包发布

发布前请确认：

1. `is_sh_ver` 已更新
2. 本地 lint/smoke 通过
3. README 和 help 文档同步

---

## 10. 常见开发任务改哪里

### 新增命令

- 分发：`70_admin.sh`
- 帮助：`help.sh`
- 必要时增加模块函数，再在 `core.sh` 增加包装

### 新增协议字段

- 默认值与列表：`00_env.sh`
- 写入：`50_node_write.sh`
- 展示/URL：`40_node_query.sh`
- 校验：`20_validate.sh`

### 服务行为修改

- 服务控制：`30_runtime.sh`
- systemd 模板和下载：`utils.sh`

---

## 11. 常见问题（开发视角）

### Q1: 为什么改了命令但菜单不生效？

先检查 `70_admin.sh` 是否接入分发，再检查 `core.sh` 是否有包装函数。

### Q2: 为什么 URL 显示不对但配置文件是对的？

配置文件写入在 `50_node_write.sh`，URL 组装在 `40_node_query.sh`，两边都要改。

### Q3: 为什么 lint 通过但运行异常？

Shell 项目容易出现运行时依赖问题（`jq`/`openssl`/`timeout` 等），请在真实 Linux 环境做 smoke。

### Q4: 我只想临时禁用某个 Reality 域名？

直接执行：

```bash
sb domain del example.com
```

对内置域名，这会写入禁用清单，不会改动源码。

---

## 12. 安全与运维提醒

- 生产机不要随意执行来源不明脚本
- 改动涉及 `rm -rf`、`systemctl disable`、`crontab -` 时必须二次确认
- 提交 PR 前请说明风险和回滚方式

---

## 13. 贡献与致谢

- 贡献指南见 [CONTRIBUTING.md](./CONTRIBUTING.md)
- 核心项目：`SagerNet/sing-box`
- 本项目基于 233boy 生态做重构与扩展
- 开源协议：`GPL v3`
