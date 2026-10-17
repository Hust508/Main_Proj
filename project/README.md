# 统一 UI、滤镜与 RGB 目标功能工程

本目录是仓库的最新可构建工程。详细设计、合并取舍、页面热区、模块接口及限制见 [统一版设计/开发文档](../docs/latest/README.md)。

## 上板操作

1. 优先下载 `DSI_UNIFIED_SC500_7inch_compress.bit`。
2. 等待摄像头和屏幕初始化，视频将以 1024×600 全屏显示。
3. 在预览画面固定单指长按约 0.8 秒，进入右侧设置面板。
4. 在“白平衡设置”底部进入“滤镜库”或“功能库”。
5. 用所有页面左上角的“回退”返回；返回预览页后顶部会显示当前滤镜和可选水印。

滤镜库包含原图、黑白、动漫、负片、像素画、边缘。功能库可独立开关水印和目标跟踪。目标跟踪适合在原图模式、浅色干净背景和均匀照明下测试；目标宽高建议至少 64～80 个屏幕像素。

## 构建与检查

```powershell
./build.ps1 -TdHome D:/Anlogic/TD
python verification/check_project.py
```

- TD 入口：`td_project/wb_ui_dsi.al`
- 顶层：`user_source/hdl_source/design_top_wrapper.v`
- UI 控制/绘制：`user_source/hdl_source/ui/`
- 统一滤镜：`user_source/hdl_source/isp/image_filter_bank_96.v`
- RGB 目标标注：`user_source/hdl_source/target/rgb_target_video.v`
- 仿真入口：`verification/run_sim.ps1`
- 构建证据：`build_evidence/integrated_*`

当前环境完成了 TD 综合、布局布线、最终时序和 bitstream 生成；本机没有 Vivado，因此更新后的仿真回归未在本次合并中重跑。已有测试台已扩展到九页 UI 和六种滤镜，需在有 Vivado 的环境执行 `verification/run_sim.ps1`。

## 下载文件辨别

- `DSI_UNIFIED_SC500_7inch*.bit`：本次统一版，可用于当前验证。
- `DSI_SHAPE_SC500_7inch*.bit`：Hproject 历史红色目标版，只作来源记录。
- `lab_*` 和 `downloads/`：阶段工程/归档，不能代表当前 `project/` 源码。
