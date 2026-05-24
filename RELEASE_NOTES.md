# Release Notes

## v1.4.0

### 主要变化

- 终端 UI 改为统一的“清爽科技风”配色：青蓝用于品牌标题和链接，绿色用于成功与可选项，黄色用于提醒，红色用于错误或危险提示，灰色用于分隔线和弱提示。
- 新增语义化 UI 颜色函数：`ui_brand`、`ui_success`、`ui_warn`、`ui_error`、`ui_muted`、`ui_link`、`ui_title`、`ui_key`，后续输出样式可以集中维护。
- 保留 `_red`、`_green`、`_yellow`、`_cyan` 等旧函数，避免影响已有脚本调用。
- 主菜单、协议选择页、进阶菜单、节点信息、URL/二维码输出、订阅生成输出已切换到统一主题函数。
- 节点链接统一使用下划线高亮，Reality、CFtunnel 等特殊节点信息不再依赖裸 ANSI 背景色数字。
- 安装阶段和运行阶段使用一致的颜色定义，安装器与 `sb` 主程序观感保持一致。
- 支持 `NO_COLOR`、`TERM=dumb`、非 TTY 环境自动关闭颜色，方便日志复制、CI 输出和脚本管道使用。

### 发布流程

- Auto Release 现在从 `RELEASE_NOTES.md` 中提取当前版本说明作为 GitHub Release 描述。
- 如果当前版本没有对应的 release notes，发布流程会失败，避免再次生成只有一句话的空 Release。
- Shell Lint workflow 增加结构检查，确保模块加载目标和菜单/分发分层规则仍然正确。

### 验证建议

- 发布前运行 `git diff --check`。
- 在 Linux/WSL 环境运行 `bash scripts/lint.sh`。
- 在已安装环境运行 `bash scripts/smoke.sh` 或 `bash scripts/regression-cli.sh`。
- 如涉及真实节点写入，在测试 VPS 按 `docs/VPS_REGRESSION.md` 做回归检查。
