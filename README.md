# Hproject 阶段工程

本次更新日期：2026-10-17。两份新工程分别保存在同级目录，源码、IP、约束、烧写文件和验证资料保持与各自原始 ZIP 一致。两份工程目前独立运行，尚未整合为同一个镜像。

| 工程 | 阶段功能 | TD 工程入口 | 说明 |
|---|---|---|---|
| [红色目标识别](lab_shape_target_DSI_SC500_7inch/) | 红色球体 / 方块外观识别，保留白平衡、二维色偏、感光度和触屏设置 | `lab_shape_target_DSI_SC500_7inch/td_project/wb_ui_dsi.al` | [工程 README](lab_shape_target_DSI_SC500_7inch/README.md) |
| [六模式图像效果](lab_touch6_pixel8_bright_DSI_SC500_7inch/) | 提亮原图、Sobel、原图+OSD、灰度、负片、8×8 像素画 | `lab_touch6_pixel8_bright_DSI_SC500_7inch/td_project/touch6_dsi.al` | [工程 README](lab_touch6_pixel8_bright_DSI_SC500_7inch/README.md) |
| [此前的白平衡基线](lab_wb_blackfix_DSI_SC500_7inch/) | 本分支上一提交的触屏白平衡 / 感光度 / 黑屏修复工程，完整迁入独立目录 | `lab_wb_blackfix_DSI_SC500_7inch/td_project/wb_ui_dsi.al` | [原说明](lab_wb_blackfix_DSI_SC500_7inch/README.md) |

## 给后续 AI 的 UI 参考

先阅读 **[UI 设计说明与整合约定](docs/UI_DESIGN_AND_INTEGRATION.md)**。文档对应第一份识别工程的实际代码，包含七页状态机、按钮热区、长按与拖动、配色和字模、34 位 UI 配置、跨时钟与视频叠加顺序，以及把六种图像效果加入该 UI 时需要区分的接口。

识别范围目前仅为单个主要红色目标，输出 RED BALL / RED CUBE / UNKNOWN / NO TARGET。不能将其描述为任意颜色、通用类别或独立多目标识别。

## 原始完整工程包

- [红色目标识别 ZIP](downloads/lab_shape_target_DSI_SC500_7inch.zip)
- [六模式图像效果 ZIP](downloads/lab_touch6_pixel8_bright_DSI_SC500_7inch.zip)

建议将选定 ZIP 解压到短英文路径后用 TD 6.2.1 打开，保留工程内部目录关系。不同工程的 `.bit` 文件不要混用。

原始包 SHA-256 见 [SHA256SUMS](SHA256SUMS)，目录与来源记录见 [stage-manifest.json](stage-manifest.json)。此次上传完成文件完整性和工程依赖检查；随包仿真、构建与实体上板状态以各自原始报告为准。
