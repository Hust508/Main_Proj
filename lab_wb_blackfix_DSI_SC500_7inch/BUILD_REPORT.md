# 黑屏回归修复：构建与验证

日期：2026-10-16，Asia/Shanghai。基线是用户反馈“UI 正常、视频全黑”的上一交付版，文件及 SHA-256 见 SOURCE_PROVENANCE.json。

## 已定位的程序错误

实际 `csi_unpacket_2lane` 用两 Lane 的 16 位输入组合为 32 位字，行内 `O_csi_valid` 本来就每隔一拍有效。上一版检查器将每次有效信号下降当作行结束，400 字一行被拆成 400 条只有一字的“短行”，正常帧全部被判坏。帧缓存因而一直没有可显示的完整帧，UI 作为独立叠加层仍正常出现。

上一版的连续 valid 模型没有覆盖该接口节拍。本版将真实解码器纳入回归，能够同时复现旧错误并验证新逻辑。

## 仅三个活动 RTL 文件变化

- `isp/csi_unpacket_2lane.v`：新增 RAW10 payload 结束事件 `O_csi_line_end`，在最后一个有效字之后输出。原有效字和数据逻辑保持不变。
- `wb/camera_frame_check.v`：只在有效拍累计字，只在显式行结束时检查行宽；字间无效拍保持计数。仍检查 400 字/行、720 行，Lane Error 只在有效负载时参与判错。
- `design_top_wrapper.v`：接通解码器到检查器的行结束信号。

白平衡算法、预设/自定义、感光度、GT911、UI、四槽缓存和屏幕输出 RTL 均与上一版逐字节一致；所有时序约束、摄像头寄存器表、管脚和 IP 保持一致。完整性校验继续启用。

## 新增实际解码链路测试

`camera_pipe_tb` 直接连接：实际 CSI 解码 → RAW10 解包 → AXIS → 去马赛克 → 白平衡及提亮 → 字节打包 → 帧 FIFO → MC 命令队列 → DDR 时延模型 → 中心裁剪 → 1024×600 像素输出。RAM/FIFO 原语使用行为模型；自研和例程图像 RTL 使用工程原模块。

输入三帧原生 1280×720，两 Lane 行负载每行 1600 字节，覆盖自动、预设、自定义三种模式（相同的 5500 K 中性测试目标）。每帧实际解码 288000 个 32 位字和 720 个显式行结束。旧版检查器三帧全部判坏，新版三帧全部通过；两个已经被下一帧 SOF 封闭的完整帧成功提交并显示，第三帧等待下次 SOF 是当前协议的正常行为。检查非黑像素输出、灰色测试目标、异步时钟、DDR 读写仲裁，以及 FIFO 无故障。

`csi_packet_tb` 另检查真实 RAW10 包边界、FS/FE/LS/LE 短包、超宽、缺行、有效负载错误、包间空闲错误指示过滤和恢复。

验证目录的 `previous_frame_check.sv` 仅为复现旧错误，不在 TD 活动构建中。

## 已通过 18 项 RTL 仿真

```text
PASS sequential Q10 ratios, 300 independent 64-bit division references, zero denominator, clamp and completion
PASS WB all 76 K entries, manual/preset equivalence, rounding/clipping/four lanes, first-pixel SOF, frame-atomic config, gray-world convergence and dark-frame hold; 102484 pixels
PASS WB plus async frame store 1280x720 frame, 921600 pixels, 2764800 byte oracle, 172800 DDR words, no dropped beats, mid-frame K update deferred and exact controls
PASS UI 800ms long press, no click-through, continuous-release debounce, every page/back, all four presets, remembered custom K, captured slider endpoints, touch/physical shared gain, repeat/clamps, multi-touch/movement/fault cancellation
PASS 500 coordinate reports, stored resolutions, portrait swap, clamping, invalid-resolution fallback, both inversions and multi-touch forwarding
PASS shared sensor gain startup, fixed exposure, busy/ACK handshake, latest-value coalescing and original AG16..89 limits
PASS 22-bit held-payload mailbox, asynchronous clocks, rapid coalesced state changes and final latest state
PASS GT911 serial resolution/coordinate reads, little-endian first contact, repeated START/NACK, status-clear ACK commit, coordinate/clear failure retry, release/multi-touch, no configuration writes; reads=44 clears=6
PASS six Chinese UI pages, 3686400 rendered pixels, exact overlay control latency, frame-latched configuration and exported RTL screenshots
PASS I2C stuck-SCL timeout, NACK STOP, stuck-SDA recovery clocks and retry after fault
PASS full 1024x600 crop/pixel byte order with async DDR/DSI, delayed returns/stalls, 614400 exact pixels, credit-based FIFO protection, one underflow event and next-frame recovery
PASS frame store: asynchronous SOF+first pixel, byte order, incomplete/RX-error rejection, MC drain, exclusive front/latest ownership, overflow/drop/recovery; 5888 writes
PASS CSI completed-frame verdict: exact width/height, missing line, extra word, lane error and recovery
PASS SC500CS group0 0x3800 hold/end/frame release, fixed exposure and every analog gain register pair (1x/2x/4x included)
PASS AWB complete beat/line count, receiver verdict, minimum sample proportion, dark/clipped rejection, luminance-jump hold, maximum Q10 step8 and stable-frame recovery
PASS MC command FIFO: queued writes remain uncommitted through independent address/data stalls, 400 ordered mixed commands, exact write drain
PASS actual two-lane CSI->RAW10->AXIS->demosaic->WB->frame FIFO->MC queue->DDR model->1024x600 output: 3 native frames; previous checker rejected all 3, fixed checker accepted all 3; 2 valid frame commits, 1959063 nonblack pixels; no FIFO fault or arbitration collision
PASS real CSI packet boundaries: alternate valid, RAW10 payload end, short FS/FE/LS/LE ignored as image lines, bad width/height/payload error rejection, idle alignment-error immunity and recovery
```

原有白平衡、触屏、坐标、邮箱、寄存器序列、帧缓存、完整 720P 字节核对和屏幕裁剪均重跑通过。六页中文 UI 实际 RTL 渲染与上一版逐像素一致。

## 本次 FPGA 构建

器件 PH1P35MDG324，Speed 3，TD 6.2.168116。综合、布局布线、最终时序和普通/压缩 bitstream 生成完成。TD 重开工程成功，分析 114 个源文件。交付源/约束与最终构建 257 个输入哈希相同，下载文件与物理实现输出相同。

| 指标 | 最终值 |
|---|---:|
| SWNS | 0.013 ns |
| HWNS | 0.020 ns |
| STNS / HTNS | 0 / 0 ns |
| STA coverage | 94.71% |
| 条件 | Routed，Slow + Fast |

```text
#lut6                    8977   out of  21216   42.31%
#reg                     8575
#slice                   9891   out of  21216   46.62%
#eram                      32   out of    108   29.63%
#dsp                       13   out of     40   32.50%
```

未放宽原有时序约束。覆盖率和保留的 IP 警告见随包报告；时序结论适用于现有约束覆盖范围。

## 实物边界

该错误已在真实解码 RTL 上复现并修复，但开发环境未连接实际开发板。模拟的入口为 DPHY 解码后的 16 位 HS 数据；未模拟加密的 DPHY/DDR/DSI 物理 IP、电气链路和面板。请下载本包 `DSI_WB_FIX_SC500_7inch_compress.bit` 上板复测，避免继续使用带 `WB_STABLE` 名称的旧镜像。

K 值增益表仍沿用未做灰卡标定的演示值；感光度仍显示实际模拟倍率，未声称绝对 ISO。
