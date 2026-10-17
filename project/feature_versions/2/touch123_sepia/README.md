# 四功能工程：原图、黑白边缘、OSD、棕褐老照片

本版用于 HX1P35A / PH1P35MDG324 -3、SC500CS 摄像头和现有 7 寸 DSI 触摸屏。

## 下载和使用

1. 完整解压到短英文路径，例如 `C:/FPGA/touch123_sepia`。
2. 保持现有摄像头、DSI 屏幕和触摸排线连接。
3. BitWriter 选择 **PH1P35MDG324**，JTAG/SRAM 下载根目录 **`TOUCH123_SEPIA_compress.bit`**。
4. 等画面出现，松开手指，再逐次点按并松开：

**彩色原图 → 黑白边缘 → 原图＋Logo／文字／CNT → 棕褐老照片 → 彩色原图。**

长按、拖动或增加手指不会连续切换；全部手指松开后才接受下一次按下。复位返回彩色原图。原摄像头增益按键功能保留。

`TOUCH123_SEPIA.bit` 是同次构建的普通版本。不要下载历史工程的位流。

## 第四模式的效果

采用：**亮度提取 → 明暗曲线与棕褐映射 → 轻微暗角 → 少量颗粒 → 饱和限幅**。

这是偏单色的老照片效果，人物和背景一起转为棕褐色，保持原画面细节。它不是黑边卡通，也不做背景虚化。四个模式都输出最终画面，不额外增加灰度等中间模式。

亮度采用 `(77R+150G+29B+128)>>8`。曲线表包含轻微黑位抬升和柔和的明暗映射；暗角和颗粒均采用较弱强度。计算为每拍 4 像素、4 级寄存器流水线，不新增整帧缓存或第二遍 DDR 写回。整体显示延迟仍包含原有帧缓存和屏幕扫描。

`preview/portrait_comparison.png` 展示本版 RTL 仿真的真实输出，与软件参考的 921600 个像素逐个相符。它不是 AI 生成的风格示意图。

## 保留的功能和修复

- 原彩色图、原例程二边缘算法、原 Logo/字模/计数器、触摸一次切换逻辑。
- 1280×720 摄像头配置、中心裁剪至 1024×600 的 DSI 链路。
- 像素打包在有效数据间隙保留相位、完整帧发布、四帧槽模式标记、显示读空保护及传输恢复。
- 最新 PAXIADDR 的 DDR 写地址优先修复；没有修改相机曝光、增益、DDR IP 参数、时钟或时序例外来掩盖问题。
- 沿用底部两行诊断显示。它们用于观察此前强光闪黑问题；新顶层已把诊断连线声明移到首次使用之前。

此前强光故障的候选修复仍需实体复测。本版没有连接你的板卡，不能声称已验证强光下长期稳定。

## 工程入口与调节

- 打开 **`retro_project/lab_touch123_dsi_SC500_7inch.al`**。
- 顶层：**`retro_top`**。
- 编译：使用 TD 6.2.1，运行根目录 **`BUILD_RETRO.ps1`**；若安装路径不同，用 `-TdHome` 指定 TD 目录。
- `RETRO_GRAIN` 默认为 1，建议范围 0～3，0 关闭颗粒。
- `RETRO_VIGNETTE` 默认为 1，设 0 关闭暗角。
- 两项参数定义在 `retro_extension/retro_top.v`，通过 ISP 与帧选择器传给 `sepia_core`；修改后必须重新编译。
- `retro_extension/sepia_lut.v` 包含 256 项棕褐曲线；`sepia_lut.json` 给出对应参数和表数据。

`retro_extension` 中部分传输模块沿用历史 `cartoon_*` 名称，以保留已经验证的接口与修复；这些名称不表示含有黑边卡通算法。项目未引用卡通核心或背景虚化模块。`user_source` 为保留的原始源/IP 文件，旧顶层不作为本工程顶层。

## 验证与验收

本版检查结果见 **`VALIDATION.md`** 和 `evidence/`：包含四模式完整 720p 像素核对、真实人像 RTL 输出、字节打包、触摸/I²C、DDR 写顺序、完整帧发布、读空与恢复、裁剪以及原 OSD。

本机重跑：

```text
python retro_verification/run_sepia_tests.py --iverilog <iverilog路径>
python retro_verification/run_sepia_tests.py --full --iverilog <iverilog路径>
python retro_verification/run_portrait_test.py --iverilog <iverilog路径>
python retro_verification/run_regression.py --iverilog <iverilog路径>
```

人像复验需要 Pillow、NumPy，以及包内 `preview/original_720p.png`。默认 Icarus 路径仅作为当前机器的便利设置，可通过 `--iverilog` 覆盖。Windows 后端兼容当前机器的 Icarus 驱动清理问题。

上板先依次确认四模式及长按行为，再在明亮、较暗、纯白、强光切换和移动相机场景下观察。模式三检查 Logo、文字和 CNT；模式四应是全画面棕褐、无描边、无局部抠像。检查底部诊断 R 是否持续增加。JTAG 下载成功不等于已固化；确认稳定后，再按板卡原有方法写入配置 Flash，验证断电重启。
