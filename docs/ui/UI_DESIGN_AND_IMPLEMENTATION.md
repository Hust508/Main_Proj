# 上滑半透明工具栏设计与实现

日期：2026-10-16。工程：`project/`。用户已确认采用当前 1024×600 全屏视频链路、150 像素高面板、50% 透明度和 3 秒自动收起。

## 画面与交互

上电为 RAW 模式，菜单隐藏，1024×600 视频逐像素透传。工程沿用摄像头 1280×720 输入与已有 1024×600 中心裁剪，不缩放视频；隐藏菜单后整屏均可见。面板打开时仅在视频上覆盖 `y=450..599`，每个 RGB 通道按 `(视频 + 面板色)/2` 混合，字母仍使用不透明高对比度颜色。菜单位于既有动态 OSD 之后，不改变采集、DDR 或 DSI 时序。

| 操作 | 判定和结果 |
|---|---|
| 唤出 | 单指从 `y>=500` 起滑，向上至少 100 像素、水平偏移全程不超过 80 像素，1 秒内完成；松手稳定约 30 ms 后显示菜单。本次滑动不能选择模式。 |
| 选择 | 菜单显示时，在同一按钮内按下并松开，移动全程不超过 20 像素，才发出一次命令。高亮反映当前实际显示帧的模式。 |
| 收起 | 菜单显示时，从 `y<=520` 起向下滑至少 80 像素，或轻点面板外的视频区；最后一次操作后约 3 秒自动收起。 |
| 防误触 | 多指、越界、长拖动、滑过按键和短暂松手抖动都不产生模式命令。 |

当前四个按键均位于 `y=[495,580)`：RAW `x=[16,244)`；EDGE `x=[268,496)`；OSD `x=[520,748)`；ART `x=[772,1000)`。ART 为卡通风格，具体算法见 [图像风格化设计](CARTOON_STYLE_DESIGN.md)。界面展开状态见 [UI_PREVIEW.svg](UI_PREVIEW.svg)；图像区域只是示意，实际来自摄像头。原上滑 UI 实现于 2026-10-16，ART 按键于 2026-10-17 增加。

## 数据路径

```text
GT911 0x814E ready / contacts
  ├─ 单指：继续读取 0x8150..0x8153 坐标
  └─ 0x814E 清零 ACK 后发布一次有效报告
       ↓ 25 MHz
touch_ui_controller：坐标方向变换、手势/点击互斥、释放消抖、超时
       ├─ 模式命令 → 原 mode_mailbox → ISP 帧边界 → DDR 帧槽标记
       └─ 菜单显示状态 → 双触发器同步 → DSI 帧边界锁存
       ↓ 52 MHz 显示时钟
视频 → 原动态 OSD → dsi_menu_overlay 透传/半透明混合 → DSI
```

`gt911_touch.v` 沿用原 I²C 地址选择、开漏、错误重试和状态清除流程，新增每个成功报告的 `O_report_valid`。`touch_ui_controller.v` 只在释放消抖完成后决定唤出、收起或选择功能，保证一次手势不会误触按钮。`touch_mode_select.v` 只解码展开菜单内的按钮。触摸坐标方向仍由 `SWAP_XY`、`FLIP_X`、`FLIP_Y` 参数控制。

`dsi_menu_overlay.v` 在显示时钟域用双触发器接收菜单状态，并在 VS 帧边界切换；隐藏时视频不经颜色处理，两级 RGB/VS/HS/DE 寄存器仍对齐。模式高亮沿用显示帧模式标记，切换可能受摄像头帧边界与 DDR 缓存产生数帧延迟。

## 文件与验证

| 路径 | 用途 |
|---|---|
| `../../project/user_source/hdl_source/touch/gt911_touch.v` | 连续坐标及有效报告 |
| `../../project/user_source/hdl_source/touch/touch_ui_controller.v` | 手势、按键命令、菜单状态 |
| `../../project/user_source/hdl_source/touch/touch_mode_select.v` | 四个按键的区域解码 |
| `../../project/user_source/hdl_source/osd/dsi_menu_overlay.v` | 视频透传、半透明工具栏、模式高亮 |
| `../../project/verification/touch_ui_tb.sv` | 唤出/收起、点击、拖动、多指、超时测试 |
| `../../project/verification/menu_tb.sv` | 全帧像素透传、混合、边界测试 |

TD 的 `.al` 和 `syn_1` / `phy_1` 工程配置已登记新增模块。原上滑 UI 的静态时序与镜像校验见 [历史构建报告](UI_SWIPE_BUILD_REPORT.md)；当前四模式结果见 [ART 构建报告](CARTOON_BUILD_REPORT.md)。测试台已加入 `../../project/verification/run_sim.ps1`；实体触摸方向和画面仍需上板确认。上板时先测试四个按钮中心，再测试滑动边界、长按、多指与自动收起。

资料：本地 `D:/FPGA/Reference_Manuals` 中的米联客 7 寸 MIPI 屏手册、SC500CS 数据手册；[工程说明](../../project/README.md)；[Goodix GT911 Programming Guide](https://www.lcd-module.de/fileadmin/eng/pdf/zubehoer/GT911_Programming_Guide_Rev.10.pdf)。
