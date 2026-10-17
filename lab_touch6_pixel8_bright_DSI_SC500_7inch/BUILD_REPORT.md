# 8×8 像素画与原图提亮：构建和验证报告

日期：2026-10-16，Asia/Shanghai。目标 PH1P35MDG324，Speed -3，工具 TD 6.2.168116。基线为上一版五模式负片工程，来源及 SHA-256 见 SOURCE_PROVENANCE.json。

## 完成内容

- 新增模式 5：8×8 左上角取样、RGB332 256 色量化、最近邻整块复制，四像素并行，保持原视频吞吐率。
- 源图像 1280×720 对应 160×90 个色块。仅增加一行 160×8 位色号缓存，不增加整帧缓存或额外帧延迟；第一行每块写入后，接下来七行复用。
- 模式 0 原图、模式 2 的视频底图和模式 5 取色使用同一条暗部/中间亮度提升曲线。黑白端点不变，增量最多 32，128 映射为 160。现有 AWB 保留，未来白平衡算法切换尚未实施。
- 原 Sobel、灰度和彩色负片继续处理原 AWB 输出，算法和输入定义保持上一版。
- 触屏循环 0→1→2→3→4→5→0，编号保持三位。全链路帧边界选择和 DDR 四槽标签保留，6/7 仍为非法编号并回到原图。未来 UI 可复用系统时钟域模式请求接口。

247 个源/IP/约束文件与实际构建目录逐字节匹配。相对基线，241 个文件逐字节相同，4 个文件修改（含顶层模式说明注释），新增 2 个 RTL。引脚、时钟、时序例外及所有原 IP 配置不变，没有为新增同步路径豁免时序。

## FPGA 实际构建

已完成综合、布局布线、Slow + Fast 最终时序分析，以及普通/压缩镜像生成。根目录镜像与本次物理实现输出 SHA-256 相同。TD 已重开工程，234 个相对依赖引用均可解析。

| 指标 | 实测 |
|---|---:|
| 建立裕量 SWNS | 0.045 ns |
| 保持裕量 HWNS | 0.020 ns |
| STNS / HTNS | 0 / 0 ns |
| STA coverage | 96.13% |

时序结论适用于现有约束覆盖的路径。工具保留原 IP 的未连接/未驱动信号等警告，详细日志随包保留。新增像素画缓存已被工具识别为 RAM。后续修改必须重新构建并检查新时序。

最终物理资源：

```text
#lut6                   12037   out of  21216   56.74%
#reg                    13801
#slice                  14336   out of  21216   67.57%
#eram                      61   out of    108   56.48%
#dsp                        9   out of     40   22.50%
```

## 仿真：16 项全部通过

以下为实际日志摘要：

```text
PASS tone lift independent arithmetic oracle, all 256 levels, monotonicity, neutral gray, black/white endpoints, <=32 lift, four independent RGB lanes and bypass; 243072 channels
PASS 8x8 RGB332 spatial oracle, first-lane sample, all block rows/columns, valid gaps, extended blanking SOF, coincident SOF, truncated-frame restart, reset and one-cycle controls; 4000 pixels
PASS new style mode=0 1280x720 independent pixel oracle, 921600 pixels, 2764800 ordered bytes, 172800 DDR words, no dropped beats, exact frame/line timing
PASS new style mode=5 1280x720 independent pixel oracle, 921600 pixels, 2764800 ordered bytes, 172800 DDR words, no dropped beats, exact frame/line timing
PASS RGB negative primaries and complements, all 256 levels per channel/lane, random pixels, one-cycle sidebands and reset; 73756 pixels
PASS style mode=4 1280x720 frame, 921600 pixels, 172800 DDR words, all 2764800 bytes in order, exact frame and line timing
PASS grayscale primaries, 256 neutral levels, random independent four-pixel lanes, <=1 luma error, one-cycle sidebands, reset; 73752 pixels
PASS style mode=3 1280x720 frame, 921600 pixels, 172800 DDR words, all 2764800 bytes in order, exact frame and line timing
PASS GT911 serial read/repeated-START/NACK/clear, reset, hold, drag, multi-touch, release debounce, NACK errors and real six-mode cycle, negative/pixel-art hold; reads=65 clears=26 errors=0
PASS I2C stuck-SCL timeout, NACK STOP, stuck-SDA recovery clocks and retry after fault
PASS six frame-boundary modes and 3-bit asynchronous mailbox, lifted color/edge/grayscale/negative/pixel-art independent oracle, invalid-mode fallback, no mid-frame mode change, 3584 pixels
PASS DDR four-slot 3-bit tags, negative and pixel-art modes in every slot and read-slot selection across asynchronous clocks, 24 writes 24 display frames
PASS: full crop address coverage for all four frame buffers, stalled requests, 31-cycle returns, partial-frame restart, and 600-row bounds.
PASS OSD: 4934690 cycles, 2546688 active pixels, three parameter modes, logo=22680 text=2742 unchanged=2521266; all BCD carries and wrap; reset recovery.
PASS EDGE_PIPELINE W=32 H=8 frames=8 pixels=2656 beats=664 DDR_words=498 edge_beats=271 thresholds=80,500
PASS EDGE_PIPELINE W=1280 H=720 frames=6 pixels=7375392 beats=1843848 DDR_words=1382886 edge_beats=914193 thresholds=80,500
```

新像素画单元测试使用独立空间坐标和算术调色板模型，验证第一空间像素所在通道、跨块跨行、缓存刷新、有效数据间隙、两种 SOF 位置、延长 SOF、截断帧重启、复位及一拍同步信号。提亮测试遍历全部 256 级并检查单调性、黑白端点、增量界限、中性灰、独立通道与关闭参数。

原图提亮和像素画各自执行完整 1280×720 测试，核对 921600 个像素、2764800 个有序字节及 172800 个 DDR 打包字，没有丢拍。原灰度与负片也完成整帧回归。

真实 GT911 串行通信模型连接实际六模式循环模块，验证第五次进入像素画、第六次回原图、长按不重复与复位。异步邮箱测试覆盖六模式、帧中请求不影响当前帧和非法模式回退。DDR 标签覆盖负片与像素画分别写入全部四槽、显示读取所选槽的完整三位编号。

原 Sobel（含完整 720P）、裁剪、OSD 和 I²C 故障恢复均通过回归。

## 实体验证范围

本环境没有连接实体 FPGA、摄像头或屏幕，尚不能宣称本版像素画、触屏六模式或提亮强度已经上板验证。完整 DDR、CSI、DSI/DPHY 加密 IP 未进行系统动态仿真；裁剪/标签测试使用 FIFO 行为桩。实际验收请按 README 下载镜像，检查第五次点按、实时运动画面、长按稳定性和原图亮度。
