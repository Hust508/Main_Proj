# 上滑半透明工具栏 TD 构建报告

日期：2026-10-16。工具：Anlogic TD 6.2.168116。器件：PH1P35MDG324，Speed -3。顶层：`design_top_wrapper`。

本次版本默认隐藏工具栏，底部上滑唤出 150 像素高的 50% 半透明面板，视频链路和分辨率保持原样。执行 `./build.ps1 -TdHome D:/Anlogic/TD`，完成 RTL 分析、综合、布局布线、最终静态时序分析及普通/压缩位流生成。构建脚本对物理优化使用固定布局种子 2；默认种子曾在既有 DDR PHY 路径产生一条保持违例，未作为交付镜像。新 bitstream 与 `phy_1` 输出逐字节一致。

| 指标 | 本次结果 |
|---|---:|
| 建立裕量 SWNS / 总负裕量 STNS | **+0.002 ns / 0 ns** |
| 保持裕量 HWNS / 总负裕量 HTNS | **+0.020 ns / 0 ns** |
| STA 覆盖率 | 96.23% |
| Slice | 14,222 / 21,216（67.03%） |
| LUT6 | 11,875 / 21,216（55.97%） |
| ERAM20K / DSP | 61 / 9 |

TD 日志存于 `build_evidence/swipe_synthesis_console.log`、`swipe_physical_console.log`、`swipe_final_timing.rpt` 和 `swipe_final_area.rpt`。建立余量仅 0.002 ns，非常窄；后续任何 RTL、约束或布局改动都必须重新运行完整时序检查。静态时序结论只覆盖所约束路径，不代替实体板上的摄像头、触控与显示功能测试。

| 下载文件 | 字节数 | SHA-256 |
|---|---:|---|
| `DSI_TOUCH123_SC500_7inch.bit` | 1,789,539 | `a16fa15c65a211d5e190fba03904e8992e30a822e9beefe86e73390c7c050b54` |
| `DSI_TOUCH123_SC500_7inch_compress.bit` | 1,435,505 | `9f2917e4049bbf9eb101d103e7deb98a74e2fc6578c762dd0f7af4847965d06c` |

本机没有可用的 Vivado/Verilog 仿真器，新增 `touch_ui_tb.sv` 与改写的 `menu_tb.sv` 尚未执行。上板需确认触控坐标方向、上滑起点、点击区域、半透明画面和自动收起。此前固定底栏的 `UI_BUILD_REPORT.md` 与 `ui_*` 日志保留为历史记录；`downloads/` 原始 ZIP 仍是 v4.0.0。
