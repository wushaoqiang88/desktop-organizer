<#
.SYNOPSIS
    桌面文件自动归类工具 - 按文件后缀自动移动到分类收纳盒文件夹
.DESCRIPTION
    功能：
    1. FileSystemWatcher 实时监控桌面新文件（无感触发）
    2. 每5分钟定时全量扫描兜底
    3. 按后缀名规则自动移动到对应分类文件夹
    4. 支持自定义规则（文件名模式匹配）
    5. 支持手动添加规则（编辑 config.json）
    6. 日志记录所有操作
.NOTES
    运行方式：
    - 前台运行: .\AutoOrganize.ps1
    - 后台运行: .\Install-Service.ps1 (注册为计划任务)
    - 停止: 按 Ctrl+C 或关闭窗口
#>

param(
    [string]$ConfigPath = "$PSScriptRoot\config.json",
    [switch]$DryRun,
    [switch]$OneShot
)

# ══════════════════════════════════════════════════════════════
# 配置加载
# ══════════════════════════════════════════════════════════════

function Load-Config {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Error "配置文件不存在: $Path"
        exit 1
    }
    $json = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    return $json
}

$Config = Load-Config -Path $ConfigPath

# 确定桌面路径
$DesktopPath = if ($Config.desktop_path -and $Config.desktop_path -ne "") {
    $Config.desktop_path
} else {
    [Environment]::GetFolderPath("Desktop")
}

# 确定目标基础路径（分类文件夹创建在哪里）
$TargetBasePath = if ($Config.target_base_path -and $Config.target_base_path -ne "") {
    $Config.target_base_path
} else {
    $DesktopPath  # 默认在桌面下创建分类文件夹
}

$LogFile = Join-Path $PSScriptRoot $Config.log_file
$ScanInterval = [int]$Config.scan_interval_minutes
$MoveDelay = [int]$Config.move_delay_seconds
$WatchRealtime = [bool]$Config.watch_realtime

# ══════════════════════════════════════════════════════════════
# 日志
# ══════════════════════════════════════════════════════════════

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    if ($Level -eq "ERROR") {
        Write-Host $line -ForegroundColor Red
    } elseif ($Level -eq "WARN") {
        Write-Host $line -ForegroundColor Yellow
    } else {
        Write-Host $line -ForegroundColor Gray
    }

    # 日志文件大小检查
    if (Test-Path $LogFile) {
        $size = (Get-Item $LogFile).Length / 1MB
        if ($size -gt $Config.max_log_size_mb) {
            $content = Get-Content $LogFile -Tail 500
            Set-Content $LogFile -Value $content -Encoding UTF8
        }
    }
}

# ══════════════════════════════════════════════════════════════
# 扩展名 → 分类映射（从配置构建）
# ══════════════════════════════════════════════════════════════

$ExtensionMap = @{}
foreach ($catName in $Config.categories.PSObject.Properties.Name) {
    $cat = $Config.categories.$catName
    if (-not $cat.enabled) { continue }
    foreach ($ext in $cat.extensions) {
        $ExtensionMap[$ext.ToLower()] = $cat.folder_name
    }
}

# 自定义规则（文件名模式）
$CustomRules = @()
foreach ($rule in $Config.custom_rules) {
    if ($rule.enabled) {
        $CustomRules += @{
            Name = $rule.name
            Pattern = $rule.match_pattern
            Folder = $rule.target_folder
        }
    }
}

# 忽略模式
$IgnorePatterns = $Config.ignore_patterns

# ══════════════════════════════════════════════════════════════
# 核心：判断文件应该移动到哪个文件夹
# ══════════════════════════════════════════════════════════════

function Get-TargetFolder {
    param([string]$FilePath)

    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()

    # 检查忽略模式
    foreach ($pattern in $IgnorePatterns) {
        if ($fileName -like $pattern) { return $null }
    }

    # 不处理文件夹
    if (Test-Path $FilePath -PathType Container) { return $null }

    # 检查自定义规则（优先级最高）
    foreach ($rule in $CustomRules) {
        if ($fileName -like $rule.Pattern) {
            return $rule.Folder
        }
    }

    # 按扩展名匹配
    if ($ExtensionMap.ContainsKey($extension)) {
        return $ExtensionMap[$extension]
    }

    # 未匹配的文件不移动
    return $null
}

# ══════════════════════════════════════════════════════════════
# 核心：移动文件到目标文件夹
# ══════════════════════════════════════════════════════════════

function Move-FileToCategory {
    param(
        [string]$FilePath,
        [string]$TargetFolderName
    )

    if (-not (Test-Path $FilePath)) { return $false }

    $fileName = [System.IO.Path]::GetFileName($FilePath)

    # 构建目标路径
    $targetDir = Join-Path $TargetBasePath $TargetFolderName

    # 确保目标目录存在
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Write-Log "创建分类文件夹: $targetDir"
    }

    $targetPath = Join-Path $targetDir $fileName

    # 处理同名文件
    if (Test-Path $targetPath) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $ext = [System.IO.Path]::GetExtension($fileName)
        $counter = 1
        do {
            $newName = "${baseName}_($counter)${ext}"
            $targetPath = Join-Path $targetDir $newName
            $counter++
        } while (Test-Path $targetPath)
    }

    # 执行移动
    if ($DryRun) {
        Write-Log "[DRY-RUN] 将移动: $fileName → $TargetFolderName" "INFO"
        return $true
    }

    try {
        Move-Item -Path $FilePath -Destination $targetPath -Force -ErrorAction Stop
        Write-Log "✅ 移动: $fileName → $TargetFolderName"

        # 桌面通知
        if ($Config.notify_on_move) {
            # 简单的通知（不阻塞）
            # [System.Windows.Forms.MessageBox]  # 太重了，不用
        }
        return $true
    } catch {
        Write-Log "❌ 移动失败: $fileName - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ══════════════════════════════════════════════════════════════
# 全量扫描桌面
# ══════════════════════════════════════════════════════════════

function Invoke-FullScan {
    Write-Log "开始全量扫描桌面: $DesktopPath"
    $moveCount = 0
    $skipCount = 0

    $files = Get-ChildItem -Path $DesktopPath -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        # 跳过分类文件夹内的文件（避免递归移动）
        $relativePath = $file.DirectoryName
        if ($relativePath -ne $DesktopPath) { continue }

        $targetFolder = Get-TargetFolder -FilePath $file.FullName
        if ($targetFolder) {
            $result = Move-FileToCategory -FilePath $file.FullName -TargetFolderName $targetFolder
            if ($result) { $moveCount++ }
        } else {
            $skipCount++
        }
    }

    Write-Log "扫描完成: 移动 $moveCount 个, 跳过 $skipCount 个"
}

# ══════════════════════════════════════════════════════════════
# FileSystemWatcher 实时监控
# ══════════════════════════════════════════════════════════════

function Start-Watcher {
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $DesktopPath
    $watcher.Filter = "*.*"
    $watcher.IncludeSubdirectories = $false
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor
                            [System.IO.NotifyFilters]::LastWrite
    $watcher.EnableRaisingEvents = $true

    # 文件创建事件
    $onCreated = Register-ObjectEvent -InputObject $watcher -EventName "Created" -Action {
        $path = $Event.SourceEventArgs.FullPath
        $name = $Event.SourceEventArgs.Name

        # 延迟处理（等文件写入完成）
        Start-Sleep -Seconds $using:MoveDelay

        # 再次检查文件是否存在（可能已被用户移走）
        if (-not (Test-Path $path)) { return }

        $targetFolder = Get-TargetFolder -FilePath $path
        if ($targetFolder) {
            Move-FileToCategory -FilePath $path -TargetFolderName $targetFolder
        }
    }

    # 文件重命名事件（有时下载完成会重命名）
    $onRenamed = Register-ObjectEvent -InputObject $watcher -EventName "Renamed" -Action {
        $path = $Event.SourceEventArgs.FullPath
        $name = $Event.SourceEventArgs.Name

        Start-Sleep -Seconds $using:MoveDelay

        if (-not (Test-Path $path)) { return }

        $targetFolder = Get-TargetFolder -FilePath $path
        if ($targetFolder) {
            Move-FileToCategory -FilePath $path -TargetFolderName $targetFolder
        }
    }

    Write-Log "🔍 FileSystemWatcher 已启动，监控: $DesktopPath"
    return @{
        Watcher = $watcher
        CreatedEvent = $onCreated
        RenamedEvent = $onRenamed
    }
}

# ══════════════════════════════════════════════════════════════
# 主循环
# ══════════════════════════════════════════════════════════════

Write-Log "═══════════════════════════════════════════"
Write-Log "桌面自动归类工具启动"
Write-Log "桌面路径: $DesktopPath"
Write-Log "目标路径: $TargetBasePath"
Write-Log "扫描间隔: ${ScanInterval}分钟"
Write-Log "实时监控: $WatchRealtime"
Write-Log "分类数量: $($ExtensionMap.Count) 种扩展名"
Write-Log "自定义规则: $($CustomRules.Count) 条"
if ($DryRun) { Write-Log "⚠️ DRY-RUN 模式 - 不会实际移动文件" "WARN" }
Write-Log "═══════════════════════════════════════════"

# 首次全量扫描
Invoke-FullScan

if ($OneShot) {
    Write-Log "OneShot 模式，扫描完成退出"
    exit 0
}

# 启动实时监控
$watcherInfo = $null
if ($WatchRealtime) {
    $watcherInfo = Start-Watcher
}

# 定时扫描循环
$lastScan = Get-Date
try {
    while ($true) {
        Start-Sleep -Seconds 10

        $elapsed = (Get-Date) - $lastScan
        if ($elapsed.TotalMinutes -ge $ScanInterval) {
            Invoke-FullScan
            $lastScan = Get-Date
        }
    }
} finally {
    # 清理
    if ($watcherInfo) {
        $watcherInfo.Watcher.EnableRaisingEvents = $false
        $watcherInfo.Watcher.Dispose()
        Unregister-Event -SourceIdentifier $watcherInfo.CreatedEvent.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $watcherInfo.RenamedEvent.Name -ErrorAction SilentlyContinue
        Write-Log "FileSystemWatcher 已停止"
    }
    Write-Log "桌面自动归类工具已退出"
}
