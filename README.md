# Hust508 竞赛主工程 · 触屏三模式整合版

当前归档基线：**v4.0.0**。SC500CS 摄像头经 FPGA 处理，在 7 寸 DSI 屏显示；点按屏幕依次切换 **彩色原图 → 黑白边缘 → 彩色图 + OSD → 彩色原图**。

| 入口 | 用途 |
|---|---|
| [project/README.md](project/README.md) | 接线、下载、触摸行为及排查 |
| [project/td_project/lab_touch123_dsi_SC500_7inch.al](project/td_project/lab_touch123_dsi_SC500_7inch.al) | TD 工程入口 |
| [压缩烧写文件](project/DSI_TOUCH123_SC500_7inch_compress.bit) | JTAG / SRAM 下载 |
| [完整交付 ZIP](downloads/lab_touch123_DSI_SC500_7inch.zip) | 直接下载和解压使用 |
| [project/BUILD_REPORT.md](project/BUILD_REPORT.md) | 已有构建与验证结果 |
| [版本索引](docs/VERSIONS.md) | 例程一、二、三与主工程的关系 |
| [后续功能工程](project/feature_versions/README.md) | 从本地开发目录迁入的复古风格与视觉增强工程 |
| [历史仓库](https://github.com/Hust508/History_Proj) | 早期独立例程 |

硬件：MLKPAI-F02 / FC02、PH1P35MDG324（Speed -3）、SC500CS、配套 7 寸 1024×600 DSI 触摸屏（GT911）。编译工具为安路 TD 6.2.1。

## 打开与重建

把整个仓库放在较短路径，例如 `C:/FPGA/Main_Proj`，保留完整目录。打开上表中的 `.al` 工程，或在 PowerShell 中执行：

```powershell
cd project
./build.ps1 -TdHome C:/APP2/ALTD
```

Python 依赖检查：`python project/verification/check_project.py`。RTL 仿真与下载步骤见原工程说明。交付时已完成综合、布局布线与八项 RTL 验证；触屏整合版的实体开发板、摄像头与触摸屏仍需上板确认。

## 后续管理

后续功能在本仓库开分支开发，经 Pull Request 合入 `main`。可复现的阶段版本打 Git tag；更新功能时同步更新 README、验证结果和版本索引。具体约定见 [CONTRIBUTING.md](CONTRIBUTING.md)。

`project/` 逐字节保留本次迁入前的最终交付包，原有源码、IP、约束、相对路径与内部校验文件均保留。`downloads/` 保存原始交付 ZIP，校验值见 [versions.json](versions.json)。

原代码与厂商 IP 的版权及使用限制继续适用。
