@echo off
chcp 65001 >nul
title 编译安装包

echo ╔═══════════════════════════════════════════════╗
echo ║  编译 .exe 安装包（需要 Inno Setup 6.x）     ║
echo ╚═══════════════════════════════════════════════╝
echo.

:: 查找 Inno Setup 编译器
set "ISCC="
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"
) else (
    :: 尝试从 PATH 找
    where iscc >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%i in ('where iscc') do set "ISCC=%%i"
    )
)

if "%ISCC%"=="" (
    echo [错误] 未找到 Inno Setup 编译器 (ISCC.exe)
    echo.
    echo 请先安装 Inno Setup 6:
    echo   https://jrsoftware.org/isdl.php
    echo.
    echo 或者直接使用 Install.bat 进行免编译安装。
    pause
    exit /b 1
)

echo 找到编译器: %ISCC%
echo.
echo 开始编译...
echo.

"%ISCC%" "%~dp0installer.iss"

if errorlevel 1 (
    echo.
    echo [错误] 编译失败，请检查 installer.iss 配置
    pause
    exit /b 1
)

echo.
echo ╔═══════════════════════════════════════════════╗
echo ║  ✅ 编译完成！                                ║
echo ║  输出: Output\DeskTidy_AutoOrganize_Setup_*.exe ║
echo ╚═══════════════════════════════════════════════╝
echo.
pause
