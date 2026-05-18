!include "MUI2.nsh"

; ══════════════════════════════════════════════════════════════
; 桌面自动归类 - NSIS 安装脚本 (原生 .exe 版)
; 编译: makensis installer.nsi
; ══════════════════════════════════════════════════════════════

!define APP_NAME "桌面自动归类"
!define APP_NAME_EN "DeskTidy_AutoOrganize"
!define APP_VERSION "1.0.0"
!define APP_PUBLISHER "DeskTidy"
!define APP_EXE "DeskTidy_AutoOrganize.exe"

Name "${APP_NAME}"
OutFile "DeskTidy_AutoOrganize_Setup_v${APP_VERSION}.exe"
InstallDir "$LOCALAPPDATA\${APP_NAME_EN}"
RequestExecutionLevel user

; ─── UI 配置 ───
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "欢迎安装 ${APP_NAME}"
!define MUI_WELCOMEPAGE_TEXT "本程序将安装桌面自动归类工具到您的电脑。$\r$\n$\r$\n功能：$\r$\n• 实时监控桌面新文件$\r$\n• 按后缀自动移动到分类文件夹$\r$\n• 每5分钟定时扫描兜底$\r$\n• 开机自动启动，后台无窗口运行$\r$\n$\r$\n无需额外依赖，即装即用。$\r$\n$\r$\n点击「下一步」继续安装。"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "立即启动归类服务"

; ─── 页面 ───
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "SimpChinese"

; ══════════════════════════════════════════════════════════════
; 安装段
; ══════════════════════════════════════════════════════════════
Section "Install"
  SetOutPath "$INSTDIR"

  ; 复制主程序
  File "${APP_EXE}"
  File "README.md"

  ; 配置文件：仅在不存在时安装（保留用户自定义）
  IfFileExists "$INSTDIR\config.json" +2
    File "config.json"

  ; 创建卸载程序
  WriteUninstaller "$INSTDIR\uninstall.exe"

  ; 创建开始菜单
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\编辑配置.lnk" "notepad.exe" "$INSTDIR\config.json"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\卸载.lnk" "$INSTDIR\uninstall.exe"

  ; 添加开机自启（注册表 Run 键）
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" \
    "${APP_NAME_EN}" "$INSTDIR\${APP_EXE}"

  ; 注册卸载信息（控制面板）
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_EN}" \
    "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_EN}" \
    "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_EN}" \
    "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_EN}" \
    "Publisher" "${APP_PUBLISHER}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_EN}" \
    "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_EN}" \
    "DisplayIcon" "$INSTDIR\${APP_EXE}"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_EN}" \
    "EstimatedSize" 2600
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_EN}" \
    "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_EN}" \
    "NoRepair" 1

SectionEnd

; ══════════════════════════════════════════════════════════════
; 卸载段
; ══════════════════════════════════════════════════════════════
Section "Uninstall"
  ; 停止运行中的进程
  nsExec::ExecToLog 'taskkill /F /IM "${APP_EXE}"'

  ; 移除开机自启
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${APP_NAME_EN}"

  ; 删除文件
  Delete "$INSTDIR\${APP_EXE}"
  Delete "$INSTDIR\config.json"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\auto_organize.log"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"

  ; 删除开始菜单
  RMDir /r "$SMPROGRAMS\${APP_NAME}"

  ; 删除注册表
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_EN}"

SectionEnd
