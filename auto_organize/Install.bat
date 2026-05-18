@echo off
chcp 65001 >nul
title 桌面自动归类 - 快速安装

echo ╔═══════════════════════════════════════════════╗
echo ║       桌面自动归类工具 - 快速安装             ║
echo ╚═══════════════════════════════════════════════╝
echo.

:: 检查 PowerShell
where powershell >nul 2>nul
if errorlevel 1 (
    echo [错误] 未找到 PowerShell，无法安装。
    pause
    exit /b 1
)

:: 创建安装目录
set "INSTALL_DIR=%LOCALAPPDATA%\DeskTidy_AutoOrganize"
echo [1/4] 创建安装目录: %INSTALL_DIR%
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: 复制文件
echo [2/4] 复制文件...
copy /Y "%~dp0AutoOrganize.ps1" "%INSTALL_DIR%\" >nul
copy /Y "%~dp0Install-Service.ps1" "%INSTALL_DIR%\" >nul
if not exist "%INSTALL_DIR%\config.json" (
    copy /Y "%~dp0config.json" "%INSTALL_DIR%\" >nul
) else (
    echo        配置文件已存在，跳过（保留用户自定义）
)
copy /Y "%~dp0README.md" "%INSTALL_DIR%\" >nul

:: 注册计划任务
echo [3/4] 注册开机自启计划任务...
powershell -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%\Install-Service.ps1" -Action Install

:: 启动服务
echo [4/4] 启动归类服务...
powershell -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%\Install-Service.ps1" -Action Run

echo.
echo ╔═══════════════════════════════════════════════╗
echo ║  ✅ 安装完成！已在后台运行                    ║
echo ║                                               ║
echo ║  配置文件: %INSTALL_DIR%\config.json          ║
echo ║  编辑配置可自定义分类规则                     ║
echo ║                                               ║
echo ║  卸载方法: 运行 Uninstall.bat                 ║
echo ╚═══════════════════════════════════════════════╝
echo.
pause
