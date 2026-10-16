# Hust508 竞赛主工程 · 触屏界面版

当前源码在 v4.0.0 三模式工程上增加固定底部工具栏。SC500CS 摄像头经 FPGA 处理，在 7 寸 DSI 屏显示；点按 **RAW / EDGE / OSD** 按键直接选择彩色原图、黑白边缘和彩色图加水印。详细设计见 [UI 设计说明](UI_DESIGN_AND_IMPLEMENTATION.md)，界面示意见 [UI 预览图](UI_PREVIEW.svg)。

`project/` 根目录的两个 `.bit` 已在 TD 重新生成，包含新 UI；`downloads/` 的 ZIP 仍是 v4.0.0 全屏点击循环版本。

| 入口 | 用途 |
|---|---|
| [project/README.md](project/README.md) | 接线、下载、触摸行为及排查 |
| [project/td_project/lab_touch123_dsi_SC500_7inch.al](project/td_project/lab_touch123_dsi_SC500_7inch.al) | TD 工程入口 |
| [新版压缩烧写文件](project/DSI_TOUCH123_SC500_7inch_compress.bit) | JTAG / SRAM 下载与上板测试 |
| [旧版交付 ZIP](downloads/lab_touch123_DSI_SC500_7inch.zip) | 仅供回退到 v4.0.0 |
| [UI 构建报告](project/UI_BUILD_REPORT.md) | 本次综合、布局布线、时序与镜像校验 |
| [历史构建报告](project/BUILD_REPORT.md) | v4.0.0 验证结果 |
| [版本索引](docs/VERSIONS.md) | 例程一、二、三与主工程的关系 |
| [历史仓库](https://github.com/Hust508/History_Proj) | 早期独立例程 |

硬件：MLKPAI-F02 / FC02、PH1P35MDG324（Speed -3）、SC500CS、配套 7 寸 1024×600 DSI 触摸屏（GT911）。编译工具为安路 TD 6.2.1。

## 打开与重建

把整个仓库放在较短路径，例如 `C:/FPGA/Main_Proj`，保留完整目录。打开上表中的 `.al` 工程，或在 PowerShell 中执行：

```powershell
cd project
./build.ps1 -TdHome D:/Anlogic/TD
```

Python 依赖检查：`python project/verification/check_project.py`。RTL 仿真与下载步骤见工程说明。当前 UI 源码已完成 TD 综合、布局布线和 bitstream 生成，最终 SWNS +0.006 ns、HWNS +0.020 ns。新增测试台尚未运行，实体屏幕仍需上板确认。

## 后续管理

后续功能在本仓库开分支开发，经 Pull Request 合入 `main`。可复现的阶段版本打 Git tag；更新功能时同步更新 README、验证结果和版本索引。具体约定见 [CONTRIBUTING.md](CONTRIBUTING.md)。

`downloads/` 保存原始交付 ZIP，校验值见 [versions.json](versions.json)。`project/BUILD_REPORT.md` 为旧版构建记录；本次 UI 的构建状态以 [UI 构建报告](project/UI_BUILD_REPORT.md) 为准。

原代码与厂商 IP 的版权及使用限制继续适用。
