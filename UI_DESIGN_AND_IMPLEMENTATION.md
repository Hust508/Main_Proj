# 摄像头处理工程触屏界面设计与实现

日期：2026-10-16。工程位置：`project/`。本文件描述当前已经写入工程的 RTL，而非仅供参考的设想。

## 1. 界面和交互

目标屏幕为 1024×600、RGB888、MIPI DSI。实时摄像头画面保持在全屏视频流中；最末级覆盖一条固定的底部工具栏，覆盖 `y=504..599`。既有例程三的 Logo、文字和帧计数先叠加，再绘制工具栏，因此水印不会盖住按键。工具栏位于摄像头图像的底部 96 行，不更改 1280×720 采集、中心裁剪、DDR 帧缓存或 DSI 时序参数。

| 按键 | 可点击区域，左闭右开 | 画面功能 | 内部模式 |
|---|---|---|---:|
| RAW | `x=[24,312), y=[522,586)` | 摄像头彩色原图 | 0 |
| EDGE | `x=[364,660), y=[522,586)` | 黑白边缘检测 | 1 |
| OSD | `x=[712,1000), y=[522,586)` | 彩色原图加既有水印/帧计数 | 2 |

按键宽度至少 288 像素，高 64 像素；间隙不响应，避免误触。被高亮的按键对应 **当前实际显示帧** 的模式，不是仍在 DDR 流水线中等待显示的触摸请求。点击图像区、底栏空白处、坐标越界、多指输入均不改变模式。按住或拖动只在首次按下产生一个事件；所有手指离屏并经过原有约 30 ms 释放间隔后才能再次触发。

界面预览见 [UI_PREVIEW.svg](UI_PREVIEW.svg)。预览中的图像区域为示意；实际内容来自摄像头。

## 2. 数据通路

```text
GT911 0x814E ready/触点数
  ├─ 单指：读 0x8150..0x8153 的 X/Y 低高字节
  └─ 清除 0x814E 并确认 ACK
       ↓ 一次按下脉冲 + 本次坐标/触点数（25 MHz）
按键区域与方向变换 → 模式请求 → 既有 mode_mailbox
       ↓ 摄像头帧边界生效
既有 ISP / DDR 四帧槽模式标记 → 当前显示帧模式
       ↓
摄像头视频 → 既有动态 OSD → 新的固定工具栏 → RGB24→32 → DSI
```

触摸驱动仍使用原有的 GT911 地址选择、开漏 I²C、错误重试和状态清除规则。单指时在清除 ready 前分四次读取第一个触点的 X/Y，任何一次 I²C 读失败都不消费报告，等待下次轮询重试。状态清除成功后才发布坐标和触点数。既有 `touch_press_once` 决定是否产生按下脉冲，`touch_mode_select` 只负责把这次按下映射到按钮。GT911 寄存器定义参考 [GOODIX GT911 Programming Guide](https://community.renesas.com/cfs-file/__key/communityserver-discussions-components-files/256/GT911-Programming-Guide_5F00_v0.1-_2800_4_2900_.pdf)。

工具栏 `dsi_menu_overlay` 与既有 OSD 一样将 RGB、VS、HS、DE 一起延迟两级，保持视频信号对齐。摄像头图像处理、帧模式邮箱和帧槽标记逻辑均沿用现有模块。按键切换仍受摄像头帧边界和原有 DDR 缓存延迟影响；选中框在新模式实际出现在屏幕时跟着更新。

## 3. 硬件适配与扩展

默认假设 GT911 X 向右、Y 向下，触控分辨率与画面一致。`touch_mode_select.v` 预留 `SWAP_XY`、`FLIP_X`、`FLIP_Y` 参数；第一次上板应分别点击三个按键的中心，确认方向。若实体装配的触摸坐标有旋转或镜像，只改这些参数，显示布局不用改。未改写 GT911 配置表；若该屏触摸 IC 的实际量程不是 1024×600，须先核实其配置并调整映射。

增加功能时，先为新功能定义独立模式/命令，再同步增加 `touch_mode_select` 的区域、`dsi_menu_overlay` 的绘制与图像处理选择逻辑。当前 `mode_mailbox`、ISP 帧选择和 DDR 模式标记使用 2 位模式，最多还能编码一个值；超过四个功能时应统一扩宽这些信号、帧槽标记及相关验证，不应只增加一个屏幕按钮。功能变多时可采用“首页三项 + 二级菜单”，保留现有按键尺寸。

## 4. 文件和验证状态

| 文件 | 作用 |
|---|---|
| `project/user_source/hdl_source/touch/gt911_touch.v` | 读取触点坐标并随有效报告发布 |
| `project/user_source/hdl_source/touch/touch_mode_select.v` | 坐标方向调整、单指过滤及按钮命中 |
| `project/user_source/hdl_source/osd/dsi_menu_overlay.v` | 绘制底栏、按钮、标签、当前模式高亮 |
| `project/user_source/hdl_source/design_top_wrapper.v` | 接入触摸选择与视频覆盖层 |
| `project/verification/touch_bus_tb.sv` | GT911 寄存器/坐标协议检查 |
| `project/verification/menu_tb.sv` | 按键边界、坐标变换、视频像素检查 |

TD 工程入口 `.al` 和两个运行配置 `.prj` 均已登记新源码。更新许可证后，TD 6.2.1 已完成新顶层分析、综合、布局布线和普通/压缩 bitstream 生成。最终 SWNS +0.006 ns、HWNS +0.020 ns、STA 覆盖率 96.08%；完整结果、镜像校验值及限制见 [UI 构建报告](project/UI_BUILD_REPORT.md)。`UI_WORKTREE_MANIFEST.json` 校验当前工程文件，`BUILD_MANIFEST.json` 保留旧版快照。此前许可证过期的记录 `project/build_evidence/ui_build_attempt.log` 仅作过程记录；本次新日志位于同目录的 `ui_*` 文件。`downloads/` 中的原始 ZIP 和历史仿真记录仍对应旧版“全屏点击循环切换”。本机没有可用的 Verilog 仿真器，新增测试台未执行；实体触摸方向、按键位置和三模式画面仍须上板确认。在装有 Vivado 仿真器的环境运行 `project/verification/run_sim.ps1 -VivadoBin <Vivado/bin>`，然后验证三个触点中心、边界、长按、多指和各模式画面。

## 5. 资料依据

- 本地资料目录 `D:/FPGA/Reference_Manuals/MLK_MIPI屏7寸/03_book/米联客7寸MIPI接口液晶屏使用手册(Xilinx).pdf`：1024×600 显示参数和 RGB/DSI 方案。
- 本地资料目录 `D:/FPGA/Reference_Manuals/SC500CS摄像头文件/SC500CS_数据手册_V1.8.pdf`：摄像头接口背景；工程的 1280×720 初始化以现有配置为准。
- [工程说明](project/README.md)：现有 GT911 引脚、初始化、显示裁剪和三模式流水线。
