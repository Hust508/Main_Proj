# Hust508 FPGA 摄像头统一工程

当前版本把 `Hproject` 的长按式白平衡 UI、RGB 形状目标功能与 `Yproject` 的图像风格化方向合并到同一个可构建工程。摄像头视频保持原有 1280×720 采集、1024×600 全屏输出和中心裁剪比例；UI 仅覆盖显示像素，不改变视频缩放或画面尺寸。

## 当前入口

| 内容 | 路径 |
|---|---|
| 最新功能、舍弃项、操作与架构 | [统一版设计/开发文档](docs/latest/README.md) |
| 可构建主工程 | [project](project) |
| TD 工程入口 | [wb_ui_dsi.al](project/td_project/wb_ui_dsi.al) |
| 推荐上板镜像 | [DSI_UNIFIED_SC500_7inch_compress.bit](project/DSI_UNIFIED_SC500_7inch_compress.bit) |
| 普通镜像 | [DSI_UNIFIED_SC500_7inch.bit](project/DSI_UNIFIED_SC500_7inch.bit) |
| 本次构建报告 | [BUILD_REPORT.md](project/BUILD_REPORT.md) |

## 功能概览

- 预览页长按约 800 ms 打开设置；顶部、底部为半透明黑色状态栏。
- 白平衡：自动、环境预设、手动色温、B/A 与 G/M 色偏、感光度。
- 滤镜库：原图、黑白、动漫、负片、像素画、边缘。
- 功能库：`FPGA VISION` 水印标签；红、绿、蓝单一主目标的 BALL/CUBE/UNKNOWN 标注。
- 全部滤镜共用 `image_filter_bank_96` 接口、帧同步模式锁存和并行数据路径。

## 重建

```powershell
cd D:/FPGA/Main_Proj/project
./build.ps1 -TdHome D:/Anlogic/TD
```

本次 TD 6.2.1 全流程通过：SWNS `+0.013 ns`、HWNS `+0.021 ns`。硬件平台为 MLKPAI-F02 / FC02、PH1P35MDG324 Speed 3、SC500CS、1024×600 DSI/GT911 屏。实物摄像头和触屏仍需上板验收。

`lab_*` 目录和 `downloads/` 是分支合并带入的阶段工程及历史交付包；最新开发与下载均以 `project/` 和 `DSI_UNIFIED_*` 为准。
