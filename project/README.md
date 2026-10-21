# 八滤镜、白平衡与原版 OSD 统一工程

本目录是 Main_Proj 的最新工程。详细架构、来源、复用、兼容变化见 [本次整合说明](../docs/INTEGRATION_20261018.md)，实际验证结果见 [构建报告](BUILD_REPORT.md)。

1. 用 BitWriter 下载 `DSI_UNIFIED_SC500_7inch_compress.bit`。
2. 初始化完成后，在预览画面固定单指长按约 0.8 秒打开设置。
3. 滤镜库第四行新增“复古”和“视觉增强”，其余六项位置不变。
4. 功能库第一行“OSD 水印”控制原安路 Logo、黄色文字与六位帧计数。设置页隐藏水印，返回预览显示；隐藏时继续计数。
5. WB、色温、色偏、感光度与功能开关各自保持记忆。RGB 主目标功能建议在原图、干净背景和均匀照明下验收。
6. 预览页底栏显示 `延迟 N 帧`：绿色为 0～2 帧、黄色为 3～4 帧、红色为 5 帧以上；`---` 表示尚无有效显示帧。
7. 设置页底部 `诊断信息` 进入独立页面，显示当前/峰值帧龄、丢弃帧、读取溢出和显示欠读；左上角回退。

滤镜菜单包括原图、黑白、动漫、负片、像素画、边缘、复古、视觉增强。水印不再是固定的 FPGA VISION 标签。统一 Sobel 改为逐像素居中窗口，边缘与动漫轮廓相对上一版会有变化。

```powershell
./build.ps1 -TdHome C:/APP2/ALTD
python verification/generate_filter_fixtures.py
./verification/run_sim.ps1
python verification/check_project.py
```

TD 入口为 `td_project/wb_ui_dsi.al`，顶层为 `design_top_wrapper`。默认构建过程检查最终建立 / 保持时序及新产物时间，通过后才更新根目录的 `DSI_UNIFIED_*` 镜像。诊断页构建日志与交付 SHA-256 见 `build_evidence/diagnostics_20261019/`、`DIAGNOSTICS_BUILD_MANIFEST.json`；此前延迟和合入基线记录分别保留在 `build_evidence/latency_20261018/`、`build_evidence/integration_20261018/`。

延迟指标的定义、RTL 数据通路、验证方法和光学端到端测量边界见 [`../docs/LATENCY_VISUALIZATION.md`](../docs/LATENCY_VISUALIZATION.md)。
诊断页布局、计数含义和验收方法见 [`../docs/DIAGNOSTICS_UI.md`](../docs/DIAGNOSTICS_UI.md)。

## 独立 TF 录像版

录像版镜像为 `TF_RECORDING_7inch_compress.bit`，卡片准备、UI 操作、现有功能取舍和验证边界见 [TF_RECORDING.md](docs/TF_RECORDING.md)。它使用 `recording_top`，与上述完整版镜像分开构建；运行 `./build_recording.ps1 -TdHome D:/Anlogic/TD`。本地已生成待写卡镜像 `D:\FPGA\record_card.img`，物理卡未被改写。

本次未连接实体开发板。`DSI_SHAPE_*` 和旧阶段日志属于历史来源，不代表本次统一版镜像。
