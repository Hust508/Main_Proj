# 触屏按键界面 TD 构建报告

日期：2026-10-16（Asia/Shanghai）。工具：Anlogic TD 6.2.168116。目标：PH1P35MDG324，Speed -3。顶层：`design_top_wrapper`。

## 结果

使用 `./build.ps1 -TdHome D:/Anlogic/TD` 完成 RTL 分析、综合、布局、布线、最终静态时序分析和普通/压缩 bitstream 生成。脚本检查最终 SWNS、HWNS 均非负后，才将本次镜像复制到 `project/` 根目录。根目录镜像与 TD `phy_1` 生成文件逐字节一致。

| 指标 | 本次结果 | v4.0.0 历史结果 |
|---|---:|---:|
| 建立裕量 SWNS | **+0.006 ns** | +0.029 ns |
| 保持裕量 HWNS | **+0.020 ns** | +0.020 ns |
| 建立/保持总负裕量 STNS / HTNS | 0 / 0 ns | 0 / 0 ns |
| STA 覆盖率 | 96.08% | 96.05% |
| Slice | 13,968 / 21,216（65.84%） | 13,771 / 21,216（64.91%） |
| LUT6 | 11,552 / 21,216（54.45%） | 11,310 / 21,216（53.31%） |
| ERAM20K / DSP | 61 / 9 | 61 / 9 |

本次最紧的建立路径处于 DDR 用户时钟域，52.181 MHz 显示时钟域的最差建立裕量为 +4.680 ns。全局 +0.006 ns 裕量很窄，虽然符合本次 TD 路由结果，后续改动或重新布局布线仍须复查时序。STA 覆盖率为 96.08%，本结论只适用于约束覆盖的路径，不等于实体上板功能验证。

## 本次可下载镜像

| 文件 | 字节数 | SHA-256 |
|---|---:|---|
| `DSI_TOUCH123_SC500_7inch.bit` | 1,789,539 | `568431698c92bcb5ccd330f0f8a7ee5fbcbba0e5796441f414041dc96538c9bd` |
| `DSI_TOUCH123_SC500_7inch_compress.bit` | 1,433,649 | `044f1eaf07c0f754eaab29d484a9c6a72515b5300f9bc106ed484fdea1107092` |

`downloads/lab_touch123_DSI_SC500_7inch.zip` 仍是 v4.0.0 原始归档，不含此 UI。`BUILD_REPORT.md`、`BUILD_MANIFEST.json` 和原 `build_evidence/` 文件保留为历史构建记录；本次记录分别存于 `build_evidence/ui_synthesis_console.log`、`ui_physical_console.log`、`ui_final_timing.rpt`、`ui_final_area.rpt`，当前全文件校验清单为 `UI_WORKTREE_MANIFEST.json`。

## 尚需验证

本机没有可用的 Vivado/Verilog 仿真器，新增 `touch_bus_tb.sv` 坐标测试和 `menu_tb.sv` 按键/视频测试台未运行。尚未连接实际开发板，触控方向、按键位置和三模式画面需上板实测。运行仿真可使用 `./verification/run_sim.ps1 -VivadoBin <Vivado/bin>`；上板前以本报告的 SHA-256 确认下载的是本次镜像。
