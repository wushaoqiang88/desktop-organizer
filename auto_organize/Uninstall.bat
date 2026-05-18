@echo off
chcp 65001 >nul
title 桌面自动归类 - 卸载

echo ╔═══════════════════════════════════════════════╗
echo ║       桌面自动归类工具 - 卸载                 ║
echo ╚═══════════════════════════════════════════════╝
echo.

set "INSTALL_DIR=%LOCALAPPDATA%\DeskTidy_AutoOrganize"

:: 停止服务
echo [1/3] 停止归类服务...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%INSTALL_DIR%\Install-Service.ps1' -Action Stop" 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%INSTALL_DIR%\Install-Service.ps1' -Action Uninstall" 2>nul

:: 询问是否删除配置
echo.
set /p "DEL_CONFIG=是否删除配置文件和日志？(y/N): "
if /i "%DEL_CONFIG%"=="y" (
    echo [2/3] 删除安装目录...
    rmdir /s /q "%INSTALL_DIR%" 2>nul
    echo        已删除: %INSTALL_DIR%
) else (
    echo [2/3] 保留配置文件: %INSTALL_DIR%\config.json
    del /q "%INSTALL_DIR%\AutoOrganize.ps1" 2>nul
    del /q "%INSTALL_DIR%\Install-Service.ps1" 2>nul
    del /q "%INSTALL_DIR%\README.md" 2>nul
)

echo [3/3] 完成
echo.
echo ╔═══════════════════════════════════════════════╗
echo ║  ✅ 卸载完成                                  ║
echo ╚═══════════════════════════════════════════════╝
echo.
pause
