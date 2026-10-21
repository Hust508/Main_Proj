param([string]$TdHome = 'D:\Anlogic\TD', [switch]$SynthesisOnly)

$ErrorActionPreference = 'Stop'
$taskProjectName = 'tf_recording'
$taskTdExe = Join-Path $TdHome 'bin/td_commands_prompt.exe'
$taskFlow = (Join-Path $TdHome 'doc/scripts/DefaultFlow.tcl').Replace('\', '/')
if (!(Test-Path -LiteralPath $taskTdExe) -or !(Test-Path -LiteralPath $taskFlow)) {
    throw '请用 -TdHome 指定 TD 安装目录。'
}
& python (Join-Path $PSScriptRoot 'tools/create_recording_project.py')
if ($LASTEXITCODE -ne 0) { throw '生成录像版 TD 工程失败。' }
$taskBuildStart = Get-Date
$taskRuns = if ($SynthesisOnly) { @('syn_1') } else { @('syn_1', 'phy_1') }
foreach ($taskRun in $taskRuns) {
    $taskRunDir = Join-Path $PSScriptRoot "td_project/${taskProjectName}_Runs/$taskRun"
    $taskExtra = ''
    if ($taskRun -eq 'phy_1') {
        $taskExtra = "source ../../../tools/finalize_timing.tcl`nset_param bitgen compress off`nbitgen -bit ${taskProjectName}.bit`nset_param bitgen compress on`nbitgen -bit ${taskProjectName}.bit"
    }
    @"
if {[catch {source {$taskFlow}} taskError]} {
    puts stderr `$taskError
    exit 1
}
$taskExtra
exit
"@ | Set-Content -LiteralPath (Join-Path $taskRunDir 'build.tcl') -Encoding ascii
    Push-Location -LiteralPath $taskRunDir
    try {
        & $taskTdExe 'build.tcl' *> 'build_console.txt'
        if ($LASTEXITCODE -ne 0) { throw "TD 构建失败：$taskRun" }
        if (Select-String -LiteralPath 'build_console.txt' -Pattern '\bERROR[: ]' -Quiet) {
            throw "TD 报告错误：$taskRun，请查看 build_console.txt。"
        }
    } finally { Pop-Location }
}
if ($SynthesisOnly) {
    Write-Host '录像版综合完成；尚未布局布线或生成可上板镜像。'
    exit
}
$taskPhysical = Join-Path $PSScriptRoot "td_project/${taskProjectName}_Runs/phy_1"
$taskTiming = Join-Path $taskPhysical "${taskProjectName}_pr.timing"
$taskTimingText = Get-Content -LiteralPath $taskTiming -Raw
$taskSetup = [regex]::Match($taskTimingText, 'SWNS:\s*(-?[0-9.]+)ns')
$taskHold = [regex]::Match($taskTimingText, 'HWNS:\s*(-?[0-9.]+)ns')
if (!$taskSetup.Success -or !$taskHold.Success -or
    [double]$taskSetup.Groups[1].Value -lt 0 -or [double]$taskHold.Groups[1].Value -lt 0) {
    throw '录像版最终时序未通过，镜像留在 phy_1 供排查。'
}
foreach ($taskSuffix in @('', '_compress')) {
    $taskSource = Join-Path $taskPhysical "${taskProjectName}${taskSuffix}.bit"
    if (!(Test-Path -LiteralPath $taskSource) -or (Get-Item -LiteralPath $taskSource).LastWriteTime -lt $taskBuildStart) {
        throw '没有本次构建的新镜像，停止复制。'
    }
    Copy-Item -LiteralPath $taskSource -Destination (Join-Path $PSScriptRoot "TF_RECORDING_7inch${taskSuffix}.bit") -Force
}
Write-Host '录像版镜像已生成；仍需实卡与实机验证。'
