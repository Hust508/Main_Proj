# 统一 UI、滤镜与 RGB 目标工程构建报告

日期：2026-10-18（Asia/Shanghai）。目标器件：PH1P35MDG324，Speed 3。工具：Anlogic TD 6.2.1。

## 验证结论

TD 完成综合、布局、布线、建立/保持时序分析以及普通和压缩 bitstream 生成。约束、摄像头采集尺寸、DDR 帧缓存和 1024×600 DSI 输出链路保持原工程设置。

| 指标 | 结果 |
|---|---:|
| SWNS / STNS | `+0.013 ns` / `0 ns` |
| HWNS / HTNS | `+0.021 ns` / `0 ns` |
| LUT6 | 14,792 / 21,216（69.72%） |
| Slice | 15,476 / 21,216（72.94%） |
| 寄存器 | 10,345 / 42,432（24.38%） |
| ERAM20K | 35 / 108（32.41%） |
| DSP | 40 / 40（100%） |

DSP 已无剩余，后续算法不能默认增加乘法器；应继续采用移位加法、时分复用或先释放现有 DSP。当前实现已通过最终时序。

## 产物

| 文件 | 用途 |
|---|---|
| `DSI_UNIFIED_SC500_7inch.bit` | 普通 bitstream |
| `DSI_UNIFIED_SC500_7inch_compress.bit` | 推荐压缩 bitstream |
| `build_evidence/integrated_synthesis_console.txt` | 本次综合日志 |
| `build_evidence/integrated_physical_console.txt` | 本次布局布线/bitgen 日志 |
| `build_evidence/integrated_final_timing.rpt` | 最终时序报告 |
| `build_evidence/integrated_final_area.rpt` | 最终资源报告 |

## 覆盖范围

- `verification/check_project.py` 的工程依赖、相对路径、模块登记和编译序号检查通过。
- TD 全流程编译通过，说明顶层、UI、滤镜、RGB 目标、DDR 和显示链路可以共同综合实现。
- 当前机器未安装 Vivado，合并后的 RTL 仿真回归没有重跑；`filter_bank_tb` 和九页 UI 回归已写入测试集合。
- 没有连接实体开发板，因此摄像头画质、触摸坐标方向、颜色阈值和形状准确率仍需实测。

历史 `build_evidence/*_tb_run.log` 来自 Hproject 阶段版本，只能作为继承模块的历史证据，不计入本次统一版的已执行测试。
