param([string]$TdHome='C:/Anlogic/TD_6.2.1_Engineer_6.2.168.116',[string]$LicenseFile='')
$ErrorActionPreference='Stop'
if($LicenseFile){
    if(!(Test-Path -LiteralPath $LicenseFile)){throw 'License file not found.'}
    $env:TD_LICENSE=(Resolve-Path -LiteralPath $LicenseFile).Path
}
$taskName='lab_touch_style_balanced'
$taskExe=Join-Path $TdHome 'bin/td_commands_prompt.exe'
$taskFlow=(Join-Path $TdHome 'doc/scripts/DefaultFlow.tcl').Replace('\','/')
if(!(Test-Path -LiteralPath $taskExe)){throw 'Set -TdHome to the TD 6.2.1 directory.'}
$taskStart=Get-Date
$taskBuildRoot=Join-Path $env:TEMP ('style_balanced_'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $taskBuildRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'TIMING_RECOVERY.tcl') -Destination $taskBuildRoot
foreach($taskSource in @('user_source','enhance_extension')){
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $taskSource) -Destination $taskBuildRoot -Recurse
}
$taskProjectSource=Join-Path $PSScriptRoot 'enhance_project'
foreach($taskFile in (Get-ChildItem -LiteralPath $taskProjectSource -File -Recurse)){
    if($taskFile.Extension -notin @('.al','.sdc','.prj','.cfg')){continue}
    $taskRelative=$taskFile.FullName.Substring($taskProjectSource.Length+1)
    if($taskRelative -match '_Runs' -and $taskFile.Extension -notin @('.prj','.cfg')){continue}
    $taskDestination=Join-Path (Join-Path $taskBuildRoot 'enhance_project') $taskRelative
    New-Item -ItemType Directory -Path (Split-Path $taskDestination) -Force | Out-Null
    Copy-Item -LiteralPath $taskFile.FullName -Destination $taskDestination
}
# TD expands relative IP paths before normalizing '..'. Use a short fresh
# workspace so a long extraction path cannot turn a valid IP into a black box.
foreach($taskRun in @('syn_1','phy_1')){
    $taskDir=Join-Path $taskBuildRoot "enhance_project/${taskName}_Runs/$taskRun"
    $taskExtra=''
    $taskOverrides=''
    if($taskRun -eq 'phy_1'){$taskOverrides='set phyWildParams {place pr_strategy 3 place opt_timing high place post_place_opt high}'}
    if($taskRun -eq 'phy_1'){$taskExtra="source ../../../TIMING_RECOVERY.tcl`nset_param bitgen compress on`nbitgen -bit ${taskName}.bit"}
    @"
 $taskOverrides
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
$taskPhy=Join-Path $taskBuildRoot "enhance_project/${taskName}_Runs/phy_1"
$taskTiming=Get-Content -LiteralPath (Join-Path $taskPhy "${taskName}_pr.timing") -Raw
$taskSetup=[regex]::Match($taskTiming,'SWNS:\s*(-?[0-9.]+)ns')
$taskHold=[regex]::Match($taskTiming,'HWNS:\s*(-?[0-9.]+)ns')
if(!$taskSetup.Success -or !$taskHold.Success){throw 'Timing report unavailable.'}
if([double]$taskSetup.Groups[1].Value -lt 0 -or [double]$taskHold.Groups[1].Value -lt 0){throw 'Timing failed. No bitstream copied.'}
foreach($taskRun in @('syn_1','phy_1')){
    $taskFrom=Join-Path $taskBuildRoot "enhance_project/${taskName}_Runs/$taskRun"
    $taskTo=Join-Path $PSScriptRoot "enhance_project/${taskName}_Runs/$taskRun"
    foreach($taskReport in (Get-ChildItem -LiteralPath $taskFrom -File)){
        if($taskReport.Extension -in @('.txt','.area','.timing','.rpt','.bit','.cfg','.prj','.tcl')){
            Copy-Item -LiteralPath $taskReport.FullName -Destination $taskTo -Force
        }
    }
}
foreach($taskSuffix in @('','_compress')){
    $taskSrc=Join-Path $taskPhy "${taskName}${taskSuffix}.bit"
    if(!(Test-Path -LiteralPath $taskSrc) -or (Get-Item -LiteralPath $taskSrc).LastWriteTime -lt $taskStart){throw 'No fresh bitstream.'}
    Copy-Item -LiteralPath $taskSrc -Destination (Join-Path $PSScriptRoot "TOUCH_STYLE_BALANCED${taskSuffix}.bit") -Force
}
Write-Host "PASS build: setup $($taskSetup.Groups[1].Value)ns; hold $($taskHold.Groups[1].Value)ns. Hardware validation required."
