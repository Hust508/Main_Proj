# 红色球体与方块识别：构建与验证

日期：2026-10-17，Asia/Shanghai。基于用户本次提供的 lab_wb_shift_DSI_SC500_7inch.zip，SHA-256 见 SOURCE_PROVENANCE.json。PPT 参考为《赛题解析二》第 21 页“扩展要求2——目标检测与识别”。

## 完成功能

在已有红色分割之后增加行轮廓、区域填充/比例/平衡、近圆模板及凸轮廓直边分析。输出 RED BALL、RED CUBE、UNKNOWN。保留单目标范围，不实现三角形类别。识别标签与中心坐标跟随目标框，优先位于上方，靠上或靠右时调整位置；NO TARGET 移至下方中央附近。保留黑框和中心十字。自动白平衡页开关改为“目标识别”，说明文字为“球体或方块”。

新增每行 34 位描述存储，总计 20,400 位；不是新整帧缓存。上一帧轮廓在垂直消隐期分析，第一有效像素锁存类别，消隐不足则中止并降级为 UNKNOWN。测试最大分析耗时 4326 个显示时钟周期。没有改动视频流水深度、时钟、原有顶层配置宽度或 SDC。

## 仿真

本次共 25 项仿真通过：原有 23 项回归及新增 2 项。新增分类测试包含 23 个独立模型输入：球体投影、高光孔洞、较暗红色、不同视角的三维方块透视投影、旋转方块、三角形、细长椭圆、过小/截断/非红色/八边形/分离物体/空画面。测试输入不是相机实拍，不代表现场准确率。

视频/UI 串联测试核对 14,745,600 个有效像素的流长度、未知像素检查、三拍视频同步、两帧确认、类别整帧锁存、标签边界以及实际 UI 输出截图。原颜色回归另外核对 14,745,700 像素的框线/十字/非标注区域。二维色偏、自动增益遥测、触摸和完整 CSI 到显示链路均重跑通过。

```text
PASS sequential Q10 ratios, 300 independent 64-bit division references, zero denominator, clamp and completion
PASS WB all 76 K entries, manual/preset equivalence, rounding/clipping/four lanes, first-pixel SOF, frame-atomic config, gray-world convergence and dark-frame hold; 102484 pixels
PASS WB plus async frame store 1280x720 frame, 921600 pixels, 2764800 byte oracle, 172800 DDR words, no dropped beats, mid-frame K update deferred and exact controls
PASS UI 800ms long press, no click-through, continuous-release debounce, every page/back, all four presets, remembered custom K, captured slider endpoints, touch/physical shared gain, repeat/clamps, multi-touch/movement/fault cancellation
PASS 500 coordinate reports, stored resolutions, portrait swap, clamping, invalid-resolution fallback, both inversions and multi-touch forwarding
PASS shared sensor gain startup, fixed exposure, busy/ACK handshake, latest-value coalescing and original AG16..89 limits
PASS 22-bit held-payload mailbox, asynchronous clocks, rapid coalesced state changes and final latest state
PASS GT911 serial resolution/coordinate reads, little-endian first contact, repeated START/NACK, status-clear ACK commit, coordinate/clear failure retry, release/multi-touch, no configuration writes; reads=44 clears=6
PASS seven Chinese UI pages, 4300800 rendered pixels, exact overlay control latency, frame-latched configuration and exported RTL screenshots
PASS I2C stuck-SCL timeout, NACK STOP, stuck-SDA recovery clocks and retry after fault
PASS full 1024x600 crop/pixel byte order with async DDR/DSI, delayed returns/stalls, 614400 exact pixels, credit-based FIFO protection, one underflow event and next-frame recovery
PASS frame store: asynchronous SOF+first pixel, byte order, incomplete/RX-error rejection, MC drain, exclusive front/latest ownership, overflow/drop/recovery; 5888 writes
PASS CSI completed-frame verdict: exact width/height, missing line, extra word, lane error and recovery
PASS SC500CS group0 0x3800 hold/end/frame release, fixed exposure and every analog gain register pair (1x/2x/4x included)
PASS AWB complete beat/line count, receiver verdict, minimum sample proportion, dark/clipped rejection, luminance-jump hold, maximum Q10 step8 and stable-frame recovery
PASS MC command FIFO: queued writes remain uncommitted through independent address/data stalls, 400 ordered mixed commands, exact write drain
PASS actual two-lane CSI->RAW10->AXIS->demosaic->WB->frame FIFO->MC queue->DDR model->1024x600 output: 4 native frames including B5/G6 manual pixel reference; previous checker rejected all 4, fixed checker accepted all 4; 3 valid frame commits, 2571822 nonblack pixels; no FIFO fault or arbitration collision
PASS real CSI packet boundaries: alternate valid, RAW10 payload end, short FS/FE/LS/LE ignored as image lines, bad width/height/payload error rejection, idle alignment-error immunity and recovery
PASS red target: 1024x600 pixel oracle, RGB negatives, dark/shadow red, run/area rejection, exact inclusive bbox/center/BCD, black border/cross, two-frame confirmation, immediate loss, enable atomicity, screen edges, incomplete frame, three-cycle sync; pixels=14745700
PASS auto-page recognition switch: OFF reset, exact hitbox, one toggle per hold, preview persistence, preset suppression/auto restore, OFF, coherent 23-bit asynchronous mailbox
PASS manual tint all 361 B/A G/M positions, four RGB lanes, independent integer gain oracle, rounding/clipping, neutral identity, disabled bypass, illegal clamp, first-pixel SOF and mid-frame edit deferral; pixels=29120
PASS manual UI nested back, reference B5/G6 mapping, captured two-axis drag and clamp, four arrow taps/repeat, reset preserving K, stored point, auto/red toggle preservation, multi-touch/fault cancellation and physical axis selection/repeat without sensitivity changes, key context restore, coherent 34-bit config
PASS live AWB 37-bit RGB/status mailbox, asynchronous rapid updates, no torn telemetry, actual Q10-to-multiplier readouts, display-frame snapshot and next-frame refresh
PASS shape classifier: 23 independent sphere/projected-3D-cube/triangle/negative fixtures, highlights/shadow, rotation/perspective, exact bbox/center, clipped/small/empty rejection, short-blank abort; max_blank_cycles=4326
PASS shape video/UI chain: default two-frame confirmation, BALL/CUBE/UNKNOWN/NO TARGET, target-anchored bounded label, auto-page target switch, full 1024x600 RGB output and three-cycle video controls; pixels=14745600
```

工具/模板在独立目录重新生成中文 UI，输出与本次构建的 overlay、font ROM 及 font HEX 三文件哈希一致。

## FPGA 构建

TD 6.2.168116，PH1P35MDG324，Speed 3。完成综合、布局布线、Slow/Fast 最终时序及普通/压缩 bitstream。原约束逐字节保留，没有通过降低频率或放宽路径取得通过。

| 指标 | 结果 |
|---|---:|
| SWNS | 0.154 ns |
| HWNS | 0.020 ns |
| STNS / HTNS | 0 / 0 ns |
| STA coverage | 96.39% |

```text
#lut6                   13253   out of  21216   62.47%
#reg                    10085
#slice                  14040   out of  21216   66.18%
#eram                      33   out of    108   30.56%
#dsp                       40   out of     40  100.00%
```

DSP 使用为 40/40，当前设计已成功实现。部分继承 IP 的 RAM_STYLE、未驱动端口、加密 IP/约束覆盖警告见随包日志；时序结论只适用于现有约束覆盖范围。行描述 RAM 的 block 属性也被 TD 提示改用 AUTO，最终总 ERAM 数量见上表，不把描述位数直接等同于新增物理块数。

261 个构建输入与交付哈希一致，可下载镜像与最终物理实现输出逐字节一致。工程可移植性和基线保护检查保留了 248 个原有源/资源文件，包含顶层、白平衡/色偏、触摸控制、遥测、相机、帧缓存、管脚和 IP；SDC 不变。

## 代码改动

```text
user_source/hdl_source/target/red_shape_classify.v
user_source/hdl_source/target/red_target_detect.v
user_source/hdl_source/target/red_target_video.v
user_source/hdl_source/target/target_ascii_font.v
user_source/hdl_source/ui/wb_ui_font.hex
user_source/hdl_source/ui/wb_ui_overlay.v
```

新增分类器，扩展红色统计的行描述输出，更新目标旁标注及英文字模，更新中文生成器/模板/字库；三个 TD 清单登记新模块。触摸控制的位置和行为不变。

## 实物边界

没有连接实际开发板。此算法针对红色球体/方块的单目外观，不能证明体积；相同投影的平面图案可能得到相同类别。多个红色物体没有独立连通域和多框结果。强高光、暗边、遮挡、过小或快速运动可能造成 UNKNOWN 或误分类。首次建议使用哑光红球和方块、干净浅色背景、均匀照明、64～80 像素以上目标，缓慢改变方块角度并检查类别，最后复测已有白平衡和色偏交互。
