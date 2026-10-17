# ART 卡通模式 TD 构建与验证报告

日期：2026-10-17。工程：`../../project/`。工具：Anlogic TD 6.2.168116。器件：PH1P35MDG324，Speed -3。顶层：`design_top_wrapper`。执行 `./build.ps1 -TdHome D:/Anlogic/TD`，物理布局种子为 2；完成 RTL 解析、综合、布局布线、最终静态时序分析，以及普通和压缩 bitstream 生成。构建脚本在建立、保持裕量均非负后才复制下载镜像。

| 指标 | 结果 |
|---|---:|
| 建立裕量 SWNS / 总负裕量 STNS | **+0.061 ns / 0 ns** |
| 保持裕量 HWNS / 总负裕量 HTNS | **+0.020 ns / 0 ns** |
| STA 覆盖率 | 96.19% |
| Slice | 14,393 / 21,216（67.84%） |
| LUT6 | 11,972 / 21,216（56.43%） |
| ERAM20K / DSP | 61 / 9 |

与原三模式上滑 UI 构建相比，Slice 增加 171、LUT6 增加 97，ERAM20K 和 DSP 数量未增加。新 RTL 复用原 Sobel 行缓存；额外逻辑主要为四按钮菜单及像素颜色选择。此比较仅针对两次 TD 构建结果，不代表单模块精确资源数。

| 下载文件（`../../project/`） | 字节数 | SHA-256 |
|---|---:|---|
| `DSI_TOUCH123_SC500_7inch.bit` | 1,789,539 | `579c005b4c350bdc810c342d7ff16323f97cfa65c6d4de01684527cdf6c8ed7a` |
| `DSI_TOUCH123_SC500_7inch_compress.bit` | 1,437,105 | `fb8d4506304c998453f9cb175163dbf2753316ec534a3be0d0a8ea309e97b2de` |

两份根目录镜像的 SHA-256 与本次 `phy_1` 生成的对应 bitstream 完全一致。构建日志和报告存于 `../../project/build_evidence/cartoon_synthesis_console.log`、`cartoon_physical_console.log`、`cartoon_final_timing.rpt`、`cartoon_final_area.rpt`。

当前机器无可用的 Vivado XSIM、Icarus Verilog 或 Verilator，`cartoon_tb.sv`、四模式流水线以及 UI 仿真尚未执行。TD 构建通过说明 RTL 已被解析、综合并满足已约束路径的静态时序；不能证明触摸坐标、摄像头实拍色彩或屏幕显示效果。实体开发板需按[设计文档的上板检查](CARTOON_STYLE_DESIGN.md#验证和上板检查)验证四种模式、ART 轮廓位置、视频连续性和菜单操作。建立裕量仍较窄，后续 RTL 或约束变更须重新运行完整 TD 构建。
