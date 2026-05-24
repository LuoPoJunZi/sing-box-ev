# Release Notes

## v1.4.1

### 主要变化

- GitHub Release 说明现在只展示当前版本的“主要变化”，不再显示发布流程、验证建议等维护内容。
- Auto Release 会从 `RELEASE_NOTES.md` 当前版本下的第一段三级标题内容生成 Release 正文，方便保持页面简洁。
- README、英文 README 和贡献说明已同步新的发布说明规则。

## v1.4.0

### 主要变化

- 终端 UI 改为统一的“清爽科技风”配色：青蓝用于品牌标题和链接，绿色用于成功与可选项，黄色用于提醒，红色用于错误或危险提示，灰色用于分隔线和弱提示。
- 新增语义化 UI 颜色函数：`ui_brand`、`ui_success`、`ui_warn`、`ui_error`、`ui_muted`、`ui_link`、`ui_title`、`ui_key`，后续输出样式可以集中维护。
- 保留 `_red`、`_green`、`_yellow`、`_cyan` 等旧函数，避免影响已有脚本调用。
- 主菜单、协议选择页、进阶菜单、节点信息、URL/二维码输出、订阅生成输出已切换到统一主题函数。
- 节点链接统一使用下划线高亮，Reality、CFtunnel 等特殊节点信息不再依赖裸 ANSI 背景色数字。
- 安装阶段和运行阶段使用一致的颜色定义，安装器与 `sb` 主程序观感保持一致。
- 支持 `NO_COLOR`、`TERM=dumb`、非 TTY 环境自动关闭颜色，方便日志复制、CI 输出和脚本管道使用。
