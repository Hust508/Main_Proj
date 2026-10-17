# 实时卡通风格化：设计与开发记录

日期：2026-10-17。目标：沿用 SC500CS 摄像头输入和 1024×600 DSI 全屏输出，增加可触摸切换的实时卡通画面。入口为底部上滑工具栏的 **ART** 按钮，内部模式值 `2'b11`；RAW、EDGE、OSD 分别保持 `0/1/2`。

## 算法

在 ISP 已有的 96-bit RGB888 数据流中，每拍处理四个像素。原 `edge_detect_96` 持续计算 Sobel 边缘，并把每个检测值映射到相邻两个像素。卡通模式把每个颜色通道压为四个色阶，再将边缘处替换成深色轮廓：

```text
Q(c) = {4{c[7:6]}}              // 0、85、170、255
P(R,G,B) = (Q(R), Q(G), Q(B))    // 每通道四级，共 64 种组合
ART(pixel) = 0x101820           // 对应的 Sobel 边缘像素为白
             或 P(R,G,B)        // 非边缘像素
```

Sobel 阈值沿用 `EDGE_THRESHOLD=80`。色阶量化只用位选择/连线；轮廓叠加为每像素一次选择，没有乘法器或额外行、帧缓存。64 色加深色轮廓会产生明显的卡通效果；细节、暗部和渐变会减少，这是该风格的预期结果。原边缘检测以两像素为单位，因此轮廓横向宽度至少约两像素。

## 接入位置与同步

```text
SC500CS 1280×720 → MIPI CSI → 去马赛克 → AWB RGB888 ×4
                                        ├→ 原 Sobel 边缘模块 ─┐
                                        └→ 1 拍彩色延迟 ─────┤→ 量化/轮廓合成
                                                             └→ 帧同步四模式选择
    → 原 96→128 打包 → DDR 四帧缓存（保留模式标签）→ 1024×600 中心裁剪
    → 原 OSD（仅模式 2）→ 上滑半透明工具栏 → DSI 屏
```

`isp_frame_select_96.v` 在 AWB 帧起始锁存两位模式。原 Sobel 数据与彩色寄存器均延迟一拍，`cartoon_stylize_96.v` 仅做组合逻辑，故 ART 与另外三个模式沿用同一 `valid/user/last` 和后续打包时序。模式值随 DDR 帧槽传递到显示端，工具栏选中高亮对应实际显示帧。切换等待下一个摄像头帧边界并经过 DDR 缓存，可能有数帧延迟。OSD 只在模式 2 叠加；ART 的卡通画面不会带例程三水印，但菜单展开时仍有 50% 透明覆盖。

工具栏原有 150 像素高度和 3 秒自动收起行为不变。按钮统一放在 `y=[495,580)`：RAW `[16,244)`，EDGE `[268,496)`，OSD `[520,748)`，ART `[772,1000)`。底部上滑唤出菜单，点 ART 后等待显示帧切换；摄像头采集比例、原 1024×600 全屏裁剪、DDR 和 DSI 参数不变。

## 实施文件

| 文件 | 修改内容 |
|---|---|
| `../../project/user_source/hdl_source/isp/cartoon_stylize_96.v` | 四像素并行量化与深色轮廓合成 |
| `../../project/user_source/hdl_source/isp/isp_frame_select_96.v` | 帧边界锁存模式 3、四模式数据选择 |
| `../../project/user_source/hdl_source/touch/touch_mode_select.v` | ART 触摸命中区及四按钮布局 |
| `../../project/user_source/hdl_source/osd/dsi_menu_overlay.v` | 四按钮半透明工具栏和 ART 文字/高亮 |
| `../../project/td_project/lab_touch123_dsi_SC500_7inch.al` | 登记新 RTL 模块；syn_1/phy_1 配置同步登记 |
| `../../project/verification/cartoon_tb.sv` | 量化边界值与轮廓像素位置 |
| `../../project/verification/mode_pipeline_tb.sv` | 四模式帧锁存、跨时钟命令与像素校验 |
| `../../project/verification/touch_ui_tb.sv`、`../../project/verification/menu_tb.sv` | ART 点击与四按钮绘制区域 |

## 验证和上板检查

执行 `python project/verification/check_project.py` 检查 TD 工程相对路径、文件及哈希；有 Vivado XSIM 时，在 `project/` 执行 `./verification/run_sim.ps1 -VivadoBin <Vivado/bin>`。完整 TD 构建在 `project/` 执行 `./build.ps1 -TdHome D:/Anlogic/TD`，脚本要求最终建立和保持裕量均不为负，才把新普通/压缩 bitstream 放到 `project/` 根目录。实测构建结果、日志和镜像校验值见 [ART 构建报告](CARTOON_BUILD_REPORT.md)。

实体板验收：上电 RAW 彩色全屏；底部上滑，依次点 RAW、EDGE、OSD、ART；ART 应为色块化彩色图并在物体边界出现深色线；收起菜单后屏幕仍被视频占满；再确认触摸高亮、自动收起、帧切换无撕裂及动态画面的连续性。仿真与 TD 静态时序都不能代替板上摄像头、DDR、触摸和 DSI 联调。
