# Hust508 FPGA 摄像头统一工程

最新工程位于 **[project/](project/)**。本版在统一 UI、白平衡和 RGB 主目标功能的基础上，合入 Lproject 的复古 / 视觉增强滤镜，并恢复原触屏例程的安路 Logo、文字及显示帧计数水印。

| 入口 | 文件 |
|---|---|
| 详细整合说明、来源、复用和兼容变化 | [INTEGRATION_20261018.md](docs/INTEGRATION_20261018.md) |
| 当前 UI / 操作与接口 | [统一版说明](docs/latest/README.md) |
| 延迟指标、实现和验收方法 | [采集到显示的延迟可视化](docs/LATENCY_VISUALIZATION.md) |
| TD 工程 | [wb_ui_dsi.al](project/td_project/wb_ui_dsi.al) |
| 推荐下载镜像 | [DSI_UNIFIED_SC500_7inch_compress.bit](project/DSI_UNIFIED_SC500_7inch_compress.bit) |
| 普通镜像 | [DSI_UNIFIED_SC500_7inch.bit](project/DSI_UNIFIED_SC500_7inch.bit) |
| 本次验证和最终时序 | [BUILD_REPORT.md](project/BUILD_REPORT.md) |

- 单指长按预览约 800 ms，打开右侧设置面板；逐级回退返回。
- 白平衡：自动、环境预设、手动色温、B/A 与 G/M 色偏、感光度。
- 滤镜库：原图、黑白、动漫、负片、像素画、边缘、复古、视觉增强。
- 功能库：原版 OSD 水印、RGB 单一主目标的 BALL/CUBE/UNKNOWN 标注，分别开关。
- 实时性：预览页底栏显示采集画面落后当前摄像头进度的帧数，并以绿 / 黄 / 红提示积压等级。
- 动漫、边缘和视觉增强共用空间窗口与 Sobel；形状分类器按阶段复用乘法器。

摄像头仍采集 1280×720，显示中心裁剪的 1024×600；引脚和原时钟定义保持不变，新增处理域的 FIFO 另有明确的数据路径上限。平台为 MLKPAI-F02 / FC02、PH1P35MDG324 Speed 3、SC500CS、DSI / GT911 屏。实体相机画质和触屏仍需上板验收。

```powershell
cd Main_Proj/project
./build.ps1 -TdHome C:/APP2/ALTD
python verification/generate_filter_fixtures.py
./verification/run_sim.ps1 -VivadoBin C:/APP2/VIVADO/2025.1/Vivado/bin
python verification/check_project.py
```

滤镜参考生成需要 Python 3.9+ / NumPy；UI 字模已交付，通常构建不需重新生成。`lab_*`、`downloads/` 是历史阶段工程和归档，最新工程和镜像以 `project/` 为准。更多来源及限制见整合说明。
