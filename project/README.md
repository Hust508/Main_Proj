# 四模式摄像头处理：7 寸屏触摸按键界面

默认上电显示**例程一：摄像头彩色原图**，工具栏隐藏，画面仍按既有 1024×600 中心裁剪全屏显示。单指从底部 `y>=500` 向上滑动至少 100 像素并松开，唤出底部 150 像素高的半透明工具栏，再点击对应功能：

**RAW（彩色原图） / EDGE（黑白边缘检测） / OSD（彩色原图 + Logo、文字及帧计数） / ART（卡通风格）**。面板在 `y=450..599` 覆盖视频，背景和按钮与视频各按 50% 混合；文字保持清晰。视频不缩放，选中状态对应实际显示的模式。按键详细坐标和结构见 [UI 设计说明](../docs/ui/UI_DESIGN_AND_IMPLEMENTATION.md)，算法见 [卡通风格设计](../docs/ui/CARTOON_STYLE_DESIGN.md)。

按键需在相同区域按下、松开且移动不超过 20 像素才生效。上滑本身不会切换模式；多指、长拖动及按键间隙不切换。菜单内向下滑动至少 80 像素或轻点外部视频区可关闭，最后一次操作约 3 秒后自动收起。松手约 30 ms 后才处理一次操作；复位回到 RAW 并隐藏菜单。

## 下载与上板

1. 打开当前 `project/td_project/lab_touch123_dsi_SC500_7inch.al` 工程；不要使用 `downloads/` 中的旧版 ZIP。
2. 保持已使用的 SC500CS 摄像头接 CSI、米联客 7 寸屏接 DSI 的连接。触摸信号已在同一根 40-pin 屏幕排线中，不需要额外飞线。
3. 用 BitWriter 选择 **PH1P35MDG324**，JTAG/SRAM 下载根目录的 **`DSI_TOUCH123_SC500_7inch_compress.bit`**。镜像 SHA-256 与 TD 时序结果见 [ART 构建报告](../docs/ui/CARTOON_BUILD_REPORT.md)。建议断电接线、重新上电后首次测试。
4. 等待正常显示后，从屏幕底部上滑唤出工具栏，分别点按 RAW / EDGE / OSD / ART，确认四种画面和选中高亮。向下滑动、轻点视频区及约 3 秒无操作应收起菜单。

当前普通与压缩 `.bit` 的构建状态见 [ART 构建报告](../docs/ui/CARTOON_BUILD_REPORT.md)。实体摄像头、屏幕与触摸仍需上板确认。旧版镜像仍保存在 `downloads/` 原始 ZIP 内。

## 功能与原例程的对应关系

| 模式 | 画面 | 处理方式 |
|---|---|---|
| 例程一 / 内部值 0 | 彩色实时摄像头 | 保留原始白平衡 RGB 像素，不显示 OSD |
| 例程二 / 内部值 1 | 黑白边缘 | 逐字节保留所提供最终例程二的 `edge_detect_96.v`；阈值默认 80 |
| 例程三 / 内部值 2 | 彩色实时图 + OSD | 使用最终例程三的 Logo、字模、黄色“安路 CNT:”和六位显示帧计数 |
| ART / 内部值 3 | 卡通风格实时图 | RGB 每通道四级量化，叠加复用 Sobel 结果的深色轮廓 |

四个模式共享一个摄像头、DDR 和 DSI 工程，无需重新下载、重新初始化屏幕或切换顶层。摄像头仍采集 1280×720，显示中心裁剪的 1024×600。DSI 时序、初始化 ROM、摄像头配置、DDR IP 和 Logo 数据保持原样。

KEY1 复位；KEY2/KEY3 沿用原例程的摄像头增益减/加。OSD 计数在所有模式下持续统计显示帧，因此切回例程三时会继续显示计数；它不是秒数。

点按按键先更新目标模式；处理方式在下一次摄像头帧起始生效，再经原四帧缓存显示。正常视频运行时存在数帧延迟，不是按下同一时刻立即改变每个像素。选中高亮按实际显示帧的模式更新；连续快速点按可能使中间模式只显示很短时间。

## 触摸实现

屏幕组件图标明 **GT911**。通过 I²C 读取 `0x814E` 的 ready 标志和触点数；单指时继续读取 `0x8150..0x8153` 的第一个触点 X/Y 坐标，然后清除状态。每个成功确认的报告交给手势控制器，以区分上滑、下滑、按键点击及多指取消。

- 复位时将 INT 保持低电平，选定 7-bit I²C 地址 `0x5D`（写 `0xBA`，读 `0xBB`）。
- 触摸复位低 20 ms，释放后地址保持 6 ms，INT 继续低 55 ms，再释放 INT 并等 50 ms 开始查询。
- 查询间隔 5 ms，另加 I²C 事务时间。SCL/SDA 均开漏，只驱动低电平或释放。
- 仅在 ready=1、必要的坐标读取成功且状态清零写入成功时消费报告。ready=0、NACK、超时都不作为松手或新按下。
- 滑动与点击互斥；多指不会选中按键，需要全部松开后重新单指操作。短暂松手抖动会被抑制。
- SCL 卡低有 10 ms 事务超时，SDA 卡低会发出九个恢复时钟，然后在后续查询重试。
- 沿用屏幕触摸芯片内已有的校准和配置，不写入其他屏幕的配置表，也不修改屏幕尺寸配置。

I²C 使用系统 25 MHz 时钟，目标不超过 100 kHz；实现留出输入同步和高电平等待时间，实际速率略低。正常工作使用轮询，INT 释放为输入，不依赖保存配置中的中断极性。

## 引脚

根据 MLKPAI-F02 底板原理图第 8 页及屏幕组件 40-pin 图核对：

| FPGA 端口 | FPGA 管脚 | 屏幕 FFC | 用途 |
|---|---|---|---|
| `IO_touch_scl` | P11 | 3 | 触摸 I²C SCL |
| `IO_touch_sda` | R12 | 6 | 触摸 I²C SDA |
| `O_screen_reset_n` | T10 | 33 | GT911 TP-RES，低有效 |
| `IO_touch_int` | U10 | 37 | 地址选择及触摸 INT |
| `O_screen_pwm` | R11 | 29 | 原背光控制 |

底板有 3.3 V ↔ 1.8 V 的 TXS0108 电平转换和上拉。FPGA 侧约束为 LVCMOS33；不要将这一 FPGA 侧电平直接解释成屏幕 FFC 的触摸电平。T10 控制触摸复位，不是 LCD 内部硬复位。

## 修改及重建

打开 `td_project/lab_touch123_dsi_SC500_7inch.al`，顶层 `design_top_wrapper`，TD 6.2.1，目标 PH1P35MDG324，Speed -3。也可运行：

```powershell
./build.ps1 -TdHome D:/Anlogic/TD
```

构建脚本检查本次 bitstream 的时间及建立/保持时序，检查通过后才复制为根目录下载文件。本次结果见 [ART 构建报告](../docs/ui/CARTOON_BUILD_REPORT.md)；`BUILD_REPORT.md`、[固定底栏报告](../docs/ui/UI_BUILD_REPORT.md)与[上滑 UI 报告](../docs/ui/UI_SWIPE_BUILD_REPORT.md)对应旧版构建。

| 主要文件 | 用途 |
|---|---|
| `touch/gt911_touch.v` | GT911 复位、地址选择、查询、坐标读取和状态清除 |
| `touch/touch_ui_controller.v` | 坐标方向、上/下滑、单击、消抖及菜单超时控制 |
| `touch/touch_mode_select.v` | 展开菜单内的按键区域命中 |
| `touch/i2c_reg16_byte.v` | 16-bit 寄存器地址、单字节读写、重复 START、ACK、超时恢复 |
| `touch/touch_press_once.v` | 一次按下只产生一次事件及松手抖动处理 |
| `touch/mode_mailbox.v` | 模式请求跨系统/摄像头时钟传递 |
| `isp/isp_frame_select_96.v` | 对齐彩色/边缘延迟，在帧开始选择四模式 |
| `isp/cartoon_stylize_96.v` | RGB 四级量化与 Sobel 轮廓叠加 |
| `video_in.v`、`video_out.v` | 保存并读取四个 DDR 帧槽对应的模式标记 |
| `osd/dsi_osd_overlay.v` | 在例程三使能 OSD，保持所有模式相同的显示流水延迟 |
| `osd/dsi_menu_overlay.v` | 帧同步显示/隐藏、半透明混合及实际模式高亮 |

这些路径均相对 `user_source/hdl_source/`。`design_top_wrapper.v` 的 `EDGE_THRESHOLD` 和原 OSD 坐标/颜色参数可以调整。`DISPLAY_TEST_PATTERN` 默认 0；设置为 1 会绕过 DDR 摄像头通路，不能用来验收三模式摄像头画面。

## 复验

```powershell
./verification/run_sim.ps1 -VivadoBin C:/APP2/VIVADO/2025.1/Vivado/bin
python ./verification/check_project.py
```

原版仿真记录覆盖触摸串行协议、长按/拖动/多指、松手抖动、I²C 异常、模式请求跨时钟、帧选择、帧槽标记、裁剪地址和动态 OSD。`cartoon_tb.sv`、`mode_pipeline_tb.sv`、`touch_ui_tb.sv` 与 `menu_tb.sv` 已纳入仿真脚本，覆盖卡通像素、四模式选择、手势和半透明菜单。本机若缺少 Vivado 仿真器，测试仍需在可用环境执行。部分测试使用 FIFO 行为桩，不能替代实际 DDR/PHY 系统仿真。TD 用于安路 FPGA 编译；Vivado 仅用作 Verilog 仿真器。

可选用 `check_project.py --ex2-zip 原例程二.zip --ex3-zip 原例程三.zip` 核对来源。验证脚本需要 Python 3.9 或更高版本。

## 上板排查

- 显示正常但不能切换：先看 `u_touch/O_online` 是否为 1、`S_touch_errors` 是否增加，再检查 `S_touch_x/y`、`S_touch_contacts`、`S_touch_select_valid` 和方向参数，最后检查 P11/R12 上的查询与 ACK、T10 复位以及排线触摸接点。
- 可通过调试观察 `S_touch_press`、`S_requested_mode`、`S_isp_frame_mode`、`S_slot_modes`、`S_ddr_frame_mode` 和 `S_visible_mode`，依次区分触摸、采集和显示环节。
- 快速松手后再按未触发：先让全部手指离屏超过 30 ms 再按，确认释放报告正常。
- 画面异常：先复验已运行的原例程，检查采集、DDR 和 DSI；本包没有声称完成实体屏幕验证。

触摸协议参考 Goodix 原始 GT911 Programming Guide（[公开镜像](https://www.lcd-module.de/fileadmin/eng/pdf/zubehoer/GT911_Programming_Guide_Rev.10.pdf)）；接线和芯片型号以你提供的屏幕组件图与项目内开发板原理图为依据。
