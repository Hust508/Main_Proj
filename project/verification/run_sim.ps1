param([string]$VivadoBin='C:/APP2/VIVADO/2025.1/Vivado/bin',
 [string[]]$Tests=@('ratio_tb','wb_unit_tb','wb_720p_tb','ui_control_tb','coord_tb','gain_tb','mailbox_tb','pointer_bus_tb','overlay_tb','i2c_fault_tb','crop_tb','frame_store_tb','frame_check_tb','group_hold_tb','awb_guard_tb','mc_queue_tb','camera_pipe_tb','csi_packet_tb','red_target_tb','target_ui_tb','tint_tb','shift_ui_tb','telemetry_tb','shape_classify_tb','shape_video_tb','filter_bank_tb','filter_transport_tb','gain_product_tb','osd_tb','filter_720p_tb'))
$ErrorActionPreference='Stop'
if(!$env:PROCESSOR_ARCHITECTURE){$env:PROCESSOR_ARCHITECTURE='AMD64'}
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskRun=Join-Path $PSScriptRoot 'sim_work'
New-Item -ItemType Directory -Force -Path $taskRun | Out-Null
if(!(Test-Path -LiteralPath (Join-Path $taskRun 'transport_expected.hex'))){
 throw 'Generate fixtures first: python verification/generate_filter_fixtures.py (requires NumPy)'
}
$taskSources=@('touch/i2c_reg16_byte.v','touch/config_mailbox.v','touch/gt911_pointer.v','touch/touch_coord_map.v',
 'wb/wb_tint_96.v','wb/wb_ratio_seq.v','wb/wb_gain_lut.v','wb/wb_balance_96.v','wb/camera_gain_apply.v',
 'target/red_shape_classify.v','target/red_target_detect.v','target/target_ascii_font.v','target/red_target_video.v','target/rgb_target_video.v','ui/wb_ui_control.v','ui/wb_ui_overlay.v','ui/wb_ui_font.v',
 'isp/csi_unpacket_2lane.v','isp/raw10_unpacket_2lane.v','isp/uial2axis.v','isp/isp_top.v',
 'isp/demosaic_4x_2_0/demosaic.v','isp/demosaic_4x_2_0/raw_matrix_3x3_buffer.v','isp/demosaic_4x_2_0/zhenghe.v',
 'isp/demosaic_4x_2_0/mipi_to_raw_converter.v','isp/demosaic_4x_2_0/line_buffer_demosaic.v','isp/demosaic_4x_2_0/bilinear_interpolation.v',
 'isp/data128_96/data128_96.v','isp/rgb_brighten_96.v','isp/pixel_art_96.v','isp/image_filter_bank_96.v','isp/filter_arithmetic.v','isp/filter_clock_bridge.v','isp/enhance_window.v','isp/enhance_core.v','isp/enhance_lut.v','isp/sepia_core.v','isp/sepia_lut.v','osd/dsi_osd_overlay.v','osd/osd_logo_rom.v','osd/osd_char_lib.v','wb/frame_stream_fifo.v','wb/camera_frame_check.v','uics500_cfg/uics500regAE.v','uics500_cfg/SC500GainTbl.v','mc_to_user_interface.v','video_in.v','video_out.v','data_96bit_to_128bit.v')
$taskFiles=@($taskSources|ForEach-Object{Join-Path $taskRoot "user_source/hdl_source/$_"})
$taskFiles+=@(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.sv' | ForEach-Object {$_.FullName})
Push-Location -LiteralPath $taskRun
try{
 # A response file avoids cmd.exe's 8191-character limit on long checkouts.
 $taskFiles | ForEach-Object {'"'+$_.Replace('\','/')+'"'} | Set-Content -LiteralPath sources.f -Encoding utf8
 & (Join-Path $VivadoBin 'xvlog.bat') -sv -f sources.f *> compile.log
 if($LASTEXITCODE -ne 0){throw 'RTL compile failed: sim_work/compile.log'}
 foreach($taskTop in $Tests){
  & (Join-Path $VivadoBin 'xelab.bat') $taskTop -s $taskTop --timescale 1ns/1ps *> "${taskTop}_elab.log"
  if($LASTEXITCODE -ne 0){throw "Elaboration failed: $taskTop"}
  & (Join-Path $VivadoBin 'xsim.bat') $taskTop -R *> "${taskTop}_run.log"
  if($LASTEXITCODE -ne 0){throw "Simulation failed: $taskTop"}
  if(!(Select-String -LiteralPath "${taskTop}_run.log" -Pattern '^PASS' -Quiet)){throw "No PASS: $taskTop"}
  Select-String -LiteralPath "${taskTop}_run.log" -Pattern '^PASS' | ForEach-Object{$_.Line}
 }
}finally{Pop-Location}
