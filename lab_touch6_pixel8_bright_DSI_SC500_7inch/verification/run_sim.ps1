param(
 [string]$VivadoBin='C:/APP2/VIVADO/2025.1/Vivado/bin',
 [string[]]$Tests=@('tone_unit_tb','pixel_unit_tb','bright_720p_tb','pixel_720p_tb','negative_unit_tb','negative_720p_tb','gray_unit_tb','gray_720p_tb','touch_bus_tb','i2c_fault_tb','mode_pipeline_tb','mode_tags_tb','crop_tb','osd_tb','edge_small_tb','edge_720p_tb')
)
$ErrorActionPreference='Stop'
if(!$env:PROCESSOR_ARCHITECTURE){$env:PROCESSOR_ARCHITECTURE='AMD64'}
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskRun=Join-Path $PSScriptRoot 'sim_work'
New-Item -ItemType Directory -Force -Path $taskRun | Out-Null
$taskSources=@(
 'touch/i2c_reg16_byte.v','touch/touch_press_once.v','touch/gt911_touch.v','touch/mode_mailbox.v','touch/touch_mode_cycle.v',
 'isp/rgb_brighten_96.v','isp/pixel_art_96.v','isp/edge_detect_96.v','isp/rgb_to_gray_96.v','isp/isp_frame_select_96.v',
 'osd/dsi_osd_overlay.v','osd/osd_logo_rom.v','osd/osd_char_lib.v','video_in.v','video_out.v','data_96bit_to_128bit.v')
$taskFiles=@($taskSources|ForEach-Object{Join-Path $taskRoot "user_source/hdl_source/$_"})
$taskBenches=@('touch_bus_tb','i2c_fault_tb','mode_pipeline_tb','mode_tags_tb','crop_tb','osd_tb','edge_pipeline_tb','gray_tb','negative_tb','pixel_tb')
$taskTops=$Tests
$taskFiles+=@($taskBenches|ForEach-Object{Join-Path $PSScriptRoot "${_}.sv"})
Push-Location -LiteralPath $taskRun
try {
 & (Join-Path $VivadoBin 'xvlog.bat') -sv @taskFiles *> compile.log
 if($LASTEXITCODE -ne 0){throw 'RTL compile failed: sim_work/compile.log'}
 foreach($taskTop in $taskTops){
  & (Join-Path $VivadoBin 'xelab.bat') $taskTop -s $taskTop --timescale 1ns/1ps *> "${taskTop}_elab.log"
  if($LASTEXITCODE -ne 0){throw "Elaboration failed: $taskTop"}
  & (Join-Path $VivadoBin 'xsim.bat') $taskTop -R *> "${taskTop}_run.log"
  if($LASTEXITCODE -ne 0){throw "Simulation failed: $taskTop"}
  if(!(Select-String -LiteralPath "${taskTop}_run.log" -Pattern '^PASS' -Quiet)){throw "No PASS: $taskTop"}
  Select-String -LiteralPath "${taskTop}_run.log" -Pattern '^PASS' | ForEach-Object{$_.Line}
 }
}finally{Pop-Location}
