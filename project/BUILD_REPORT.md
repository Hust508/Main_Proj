# 触摸三模式整合工程：构建与验证报告

交付日期：2026-10-15（Asia/Shanghai）。目标 PH1P35MDG324，Speed -3，TD 6.2.168116。

## 最终构建

本机完成新整合源码的综合、布局布线及普通/压缩 bitstream 生成。默认摄像头模式，边缘阈值 80，上电模式 0（例程一）。

| 项目 | 结果 |
|---|---:|
| 建立裕量 SWNS | 0.029 ns |
| 保持裕量 HWNS | 0.020 ns |
| STA coverage | 96.05% |
| Corner | Slow + Fast |

详细时序、资源及日志见 `build_evidence/`。结论仅适用于已有约束覆盖的路径。保留原工程的异步时钟分组；新增 I²C 异步输入例外及握手模式邮箱的稳定数据路径例外，未对图像处理同步路径增加豁免。

交付副本已在 TD 重新打开并成功解析 109 个源码文件。运行配置和 `.al` 共 222 个相对依赖引用已检查存在。原例程二边缘模块逐字节不变；以最终例程三为基线，231 个既有源/IP 文件不变，6 个文件按整合需求修改，另加入触摸及帧选择模块。

## 已执行 RTL 验证

以下是实际仿真器 PASS 输出：

```text
PASS GT911 serial read/repeated-START/NACK/clear, reset, hold, drag, multi-touch, release debounce, NACK errors and 1-2-3 loop; reads=35 clears=14 errors=3
PASS I2C stuck-SCL timeout, NACK STOP, stuck-SDA recovery clocks and retry after fault
PASS frame-boundary mode selection and asynchronous mailbox, unchanged color/edge pixels, 1792 pixels
PASS DDR four-slot mode tags and read-slot selection across asynchronous clocks, 16 writes 16 display frames
PASS: full crop address coverage for all four frame buffers, stalled requests, 31-cycle returns, partial-frame restart, and 600-row bounds.
PASS OSD: 4934690 cycles, 2546688 active pixels, three parameter modes, logo=22680 text=2742 unchanged=2521266; all BCD carries and wrap; reset recovery.
PASS EDGE_PIPELINE W=32 H=8 frames=8 pixels=2656 beats=664 DDR_words=498 edge_beats=271 thresholds=80,500
PASS EDGE_PIPELINE W=1280 H=720 frames=6 pixels=7375392 beats=1843848 DDR_words=1382886 edge_beats=914193 thresholds=80,500
```

GT911 测试使用真实 SCL/SDA 串行信号行为模型，检查复位/地址选择、重复 START、读地址、最后一字节 NACK、状态写零、无 ready 数据、长按、拖动、多指、松手抖动和通信 NACK。另测 SCL 卡低超时、SDA 卡低九时钟恢复及后续重试。

模式测试覆盖异步系统/摄像头时钟、SOF 与首个有效拍重合及 SOF 在消隐期、帧中途改变请求、四个 DDR 帧槽模式标记。OSD 测试包含动态禁用后彩色透传、透明 Logo/文字、计数进位及回绕。原例程二以独立二维图像 Sobel 参考值和字节流打包队列回归，并覆盖完整 1280×720 图案帧。

## 限制与上板确认

本次未连接实体 FPGA、摄像头或触摸屏，不能宣称实际点亮或触摸实测通过。裁剪地址/模式标记测试使用 FIFO 行为桩；完整 DDR、CSI、DSI/DPHY 加密 IP 未做系统级动态仿真。实际电气上拉、触摸扫描及显示效果需要上板确认。

两个根目录 bitstream 均为本次整合工程生成。建议先在 JTAG/SRAM 中下载压缩版本，按 README 检查循环与长按效果。
