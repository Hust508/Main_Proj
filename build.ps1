param([string]$TdHome = 'C:\APP2\ALTD')

$ErrorActionPreference = 'Stop'

$taskProjectName = 'wb_ui_dsi'

$taskTdExe = Join-Path $TdHome 'bin/td_commands_prompt.exe'

$taskFlow = (Join-Path $TdHome 'doc/scripts/DefaultFlow.tcl').Replace('\', '/')

if (!(Test-Path -LiteralPath $taskTdExe) -or !(Test-Path -LiteralPath $taskFlow)) {

    throw '请用 -TdHome 指定 TD 6.2.1 安装目录。'

}

$taskBuildStart = Get-Date

foreach ($taskRun in @('syn_1', 'phy_1')) {

    $taskRunDir = Join-Path $PSScriptRoot "td_project/${taskProjectName}_Runs/$taskRun"

    $taskExtra = ''

    if ($taskRun -eq 'phy_1') {

        $taskExtra = "set_param bitgen compress on`nbitgen -bit ${taskProjectName}.bit"

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

$taskPhysical = Join-Path $PSScriptRoot "td_project/${taskProjectName}_Runs/phy_1"

$taskTiming = Join-Path $taskPhysical "${taskProjectName}_pr.timing"

$taskTimingText = Get-Content -LiteralPath $taskTiming -Raw

$taskSetup = [regex]::Match($taskTimingText, 'SWNS:\s*(-?[0-9.]+)ns')

$taskHold = [regex]::Match($taskTimingText, 'HWNS:\s*(-?[0-9.]+)ns')

if (!$taskSetup.Success -or !$taskHold.Success) { throw '无法读取最终时序结论。' }

if ([double]$taskSetup.Groups[1].Value -lt 0 -or [double]$taskHold.Groups[1].Value -lt 0) {

    throw '本次构建仍有时序违例。镜像保留在 phy_1，未复制为可上板调试镜像。'

}

foreach ($taskSuffix in @('', '_compress')) {

    $taskSource = Join-Path $taskPhysical "${taskProjectName}${taskSuffix}.bit"

    if (!(Test-Path -LiteralPath $taskSource) -or (Get-Item -LiteralPath $taskSource).LastWriteTime -lt $taskBuildStart) {

        throw '没有本次构建的新镜像，停止复制。'

    }

    Copy-Item -LiteralPath $taskSource -Destination (Join-Path $PSScriptRoot "DSI_WB_FIX_SC500_7inch${taskSuffix}.bit") -Force

}

Write-Host '综合、布局布线及最终时序检查完成；新镜像已复制到工程根目录。尚需实际开发板验证。'

Write-Host '随包 BUILD_REPORT/BUILD_MANIFEST 对应原交付构建；再次编译后请以本次 TD 报告为准。'

