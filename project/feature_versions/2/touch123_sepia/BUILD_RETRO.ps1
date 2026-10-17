param([string]$TdHome='C:/Anlogic/TD_6.2.1_Engineer_6.2.168.116',[string]$LicenseFile='')
$ErrorActionPreference='Stop'
if($LicenseFile){
    if(!(Test-Path -LiteralPath $LicenseFile)){throw 'License file not found.'}
    $env:TD_LICENSE=(Resolve-Path -LiteralPath $LicenseFile).Path
}
$taskName='lab_touch123_dsi_SC500_7inch'
$taskExe=Join-Path $TdHome 'bin/td_commands_prompt.exe'
$taskFlow=(Join-Path $TdHome 'doc/scripts/DefaultFlow.tcl').Replace('\','/')
if(!(Test-Path -LiteralPath $taskExe)){throw 'Set -TdHome to the TD 6.2.1 directory.'}
$taskStart=Get-Date
foreach($taskRun in @('syn_1','phy_1')){
    $taskDir=Join-Path $PSScriptRoot "retro_project/${taskName}_Runs/$taskRun"
    $taskExtra=''
    if($taskRun -eq 'phy_1'){$taskExtra="set_param bitgen compress on`nbitgen -bit ${taskName}.bit"}
    @"
if {[catch {source {$taskFlow}} taskError]} {
    puts stderr `$taskError
    exit 1
}
$taskExtra
exit
"@ | Set-Content -LiteralPath (Join-Path $taskDir 'build.tcl') -Encoding ascii
    Push-Location -LiteralPath $taskDir
    try{
        & $taskExe 'build.tcl' *> 'build_console.txt'
        if($LASTEXITCODE -ne 0){throw "TD failed: $taskRun"}
        if(Select-String -LiteralPath 'build_console.txt' -Pattern '\bERROR[: ]' -Quiet){throw "TD error: $taskRun/build_console.txt"}
    }finally{Pop-Location}
}
$taskPhy=Join-Path $PSScriptRoot "retro_project/${taskName}_Runs/phy_1"
$taskTiming=Get-Content -LiteralPath (Join-Path $taskPhy "${taskName}_pr.timing") -Raw
$taskSetup=[regex]::Match($taskTiming,'SWNS:\s*(-?[0-9.]+)ns')
$taskHold=[regex]::Match($taskTiming,'HWNS:\s*(-?[0-9.]+)ns')
if(!$taskSetup.Success -or !$taskHold.Success){throw 'Timing report unavailable.'}
if([double]$taskSetup.Groups[1].Value -lt 0 -or [double]$taskHold.Groups[1].Value -lt 0){throw 'Timing failed. No bitstream copied.'}
foreach($taskSuffix in @('','_compress')){
    $taskSrc=Join-Path $taskPhy "${taskName}${taskSuffix}.bit"
    if(!(Test-Path -LiteralPath $taskSrc) -or (Get-Item -LiteralPath $taskSrc).LastWriteTime -lt $taskStart){throw 'No fresh bitstream.'}
    Copy-Item -LiteralPath $taskSrc -Destination (Join-Path $PSScriptRoot "TOUCH123_SEPIA${taskSuffix}.bit") -Force
}
Write-Host "PASS build: setup $($taskSetup.Groups[1].Value)ns; hold $($taskHold.Groups[1].Value)ns. Hardware validation required."
