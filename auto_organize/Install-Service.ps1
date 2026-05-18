<#
.SYNOPSIS
    安装/卸载桌面自动归类工具为 Windows 计划任务（开机自启、后台运行）
.DESCRIPTION
    - Install: 注册为计划任务，开机自动运行，后台无窗口
    - Uninstall: 移除计划任务
    - Status: 查看运行状态
.EXAMPLE
    .\Install-Service.ps1 -Action Install
    .\Install-Service.ps1 -Action Uninstall
    .\Install-Service.ps1 -Action Status
#>

param(
    [ValidateSet("Install", "Uninstall", "Status", "Run", "Stop")]
    [string]$Action = "Install"
)

$TaskName = "DeskTidy_AutoOrganize"
$ScriptPath = Join-Path $PSScriptRoot "AutoOrganize.ps1"
$Description = "桌面文件自动归类工具 - 按后缀移动到分类收纳盒"

function Install-Task {
    # 检查脚本存在
    if (-not (Test-Path $ScriptPath)) {
        Write-Error "找不到主脚本: $ScriptPath"
        return
    }

    # 移除已有任务
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "已移除旧的计划任务" -ForegroundColor Yellow
    }

    # 创建任务
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`"" `
        -WorkingDirectory $PSScriptRoot

    # 触发器：用户登录时
    $trigger = New-ScheduledTaskTrigger -AtLogOn

    # 设置
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartInterval (New-TimeSpan -Minutes 5) `
        -RestartCount 3 `
        -ExecutionTimeLimit (New-TimeSpan -Days 365)

    # 当前用户
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Limited

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description $Description `
        -Force

    Write-Host "✅ 计划任务已创建: $TaskName" -ForegroundColor Green
    Write-Host "   触发: 用户登录时自动启动" -ForegroundColor Cyan
    Write-Host "   运行: 后台无窗口模式" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "立即启动? 运行: .\Install-Service.ps1 -Action Run" -ForegroundColor Yellow
}

function Uninstall-Task {
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "✅ 计划任务已移除: $TaskName" -ForegroundColor Green
    } else {
        Write-Host "计划任务不存在: $TaskName" -ForegroundColor Yellow
    }
}

function Get-TaskStatus {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Host "❌ 计划任务未安装" -ForegroundColor Red
        return
    }

    $info = Get-ScheduledTaskInfo -TaskName $TaskName
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "任务名称: $TaskName" -ForegroundColor White
    Write-Host "状态: $($task.State)" -ForegroundColor $(if ($task.State -eq "Running") { "Green" } else { "Yellow" })
    Write-Host "上次运行: $($info.LastRunTime)" -ForegroundColor Gray
    Write-Host "下次运行: $($info.NextRunTime)" -ForegroundColor Gray
    Write-Host "上次结果: $($info.LastTaskResult)" -ForegroundColor Gray
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
}

function Start-Task {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Host "❌ 请先安装: .\Install-Service.ps1 -Action Install" -ForegroundColor Red
        return
    }
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "✅ 已启动: $TaskName" -ForegroundColor Green
}

function Stop-Task {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Host "计划任务不存在" -ForegroundColor Yellow
        return
    }
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    # 也杀掉可能残留的进程
    Get-Process -Name "powershell" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*AutoOrganize*" } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "✅ 已停止" -ForegroundColor Green
}

switch ($Action) {
    "Install"   { Install-Task }
    "Uninstall" { Uninstall-Task }
    "Status"    { Get-TaskStatus }
    "Run"       { Start-Task }
    "Stop"      { Stop-Task }
}
