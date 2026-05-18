!include "MUI2.nsh"

; ══════════════════════════════════════════════════════════════
; desk_tidy 主程序 - NSIS 安装脚本
; 在 CI 中使用，打包 flutter build windows 的输出
; ══════════════════════════════════════════════════════════════

!define APP_NAME "桌面整理"
!define APP_NAME_EN "DesktopOrganizer"
!define APP_VERSION "1.2.12"
!define APP_PUBLISHER "DeskTidy"
!define APP_EXE "desk_tidy.exe"
!define BUILD_DIR "build\windows\x64\runner\Release"

Name "${APP_NAME} v${APP_VERSION}"
OutFile "DesktopOrganizer_Setup_v${APP_VERSION}.exe"
InstallDir "$LOCALAPPDATA\${APP_NAME_EN}"
RequestExecutionLevel user

; ─── UI ───
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "欢迎安装 ${APP_NAME}"
!define MUI_WELCOMEPAGE_TEXT "本程序将安装桌面整理工具到您的电脑。$\r$\n$\r$\n功能：$\r$\n• 桌面快捷方式分类管理$\r$\n• 文件自动归类（按后缀移动到分类文件夹）$\r$\n• 全局搜索快速启动$\r$\n• 桌面收纳盒$\r$\n$\r$\n点击「下一步」继续安装。"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "立即启动"
!define MUI_FINISHPAGE_SHOWREADME ""
!define MUI_FINISHPAGE_SHOWREADME_TEXT "创建桌面快捷方式"
!define MUI_FINISHPAGE_SHOWREADME_FUNCTION CreateDesktopShortcut

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

  ; 复制 Flutter build 输出的所有文件
  File "${BUILD_DIR}\${APP_EXE}"
  File "${BUILD_DIR}\flutter_windows.dll"
  File /nonfatal "${BUILD_DIR}\*.dll"

  ; data 目录
  SetOutPath "$INSTDIR\data"
  File /r "${BUILD_DIR}\data\*.*"

  SetOutPath "$INSTDIR"

  ; 创建卸载程序
  WriteUninstaller "$INSTDIR\uninstall.exe"

  ; 开始菜单
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\卸载.lnk" "$INSTDIR\uninstall.exe"

  ; 开机自启（注册表）
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" \
    "${APP_NAME_EN}" "$INSTDIR\${APP_EXE}"

  ; 卸载信息
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
    "EstimatedSize" 35000
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_EN}" \
    "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_EN}" \
    "NoRepair" 1

SectionEnd

; ══════════════════════════════════════════════════════════════
; 卸载段
; ══════════════════════════════════════════════════════════════
Section "Uninstall"
  ; 杀进程
  nsExec::ExecToLog 'taskkill /F /IM "${APP_EXE}"'

  ; 删除开机自启
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${APP_NAME_EN}"

  ; 删除文件
  RMDir /r "$INSTDIR\data"
  Delete "$INSTDIR\*.dll"
  Delete "$INSTDIR\${APP_EXE}"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"

  ; 删除快捷方式
  Delete "$DESKTOP\${APP_NAME}.lnk"
  RMDir /r "$SMPROGRAMS\${APP_NAME}"

  ; 删除注册表
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_EN}"

SectionEnd

; ══════════════════════════════════════════════════════════════
; 函数
; ══════════════════════════════════════════════════════════════
Function CreateDesktopShortcut
  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
FunctionEnd
