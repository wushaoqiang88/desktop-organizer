; ══════════════════════════════════════════════════════════════
; 桌面自动归类工具 - Inno Setup 安装脚本
; 编译方法: 在 Windows 上安装 Inno Setup 6.x，打开此文件点击编译
; 下载: https://jrsoftware.org/isdl.php
; ══════════════════════════════════════════════════════════════

#define MyAppName "桌面自动归类"
#define MyAppNameEn "DeskTidy AutoOrganize"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "DeskTidy"
#define MyAppURL "https://github.com/sqmw/desk_tidy"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppNameEn}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputBaseFilename=DeskTidy_AutoOrganize_Setup_v{#MyAppVersion}
Compression=lzma2/ultra
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\app_icon.ico

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "AutoOrganize.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Install-Service.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "config.json"; DestDir: "{app}"; Flags: ignoreversion onlyifdoesntexist
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\windows\runner\resources\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName} - 启动"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\AutoOrganize.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\app_icon.ico"
Name: "{group}\{#MyAppName} - 配置"; Filename: "notepad.exe"; Parameters: """{app}\config.json"""; IconFilename: "{app}\app_icon.ico"
Name: "{group}\{#MyAppName} - 卸载"; Filename: "{uninstallexe}"

[Run]
; 安装后注册计划任务
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Install-Service.ps1"" -Action Install"; WorkingDir: "{app}"; Flags: runhidden waituntilterminated; StatusMsg: "正在注册自动启动服务..."
; 安装后立即启动
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Install-Service.ps1"" -Action Run"; WorkingDir: "{app}"; Flags: runhidden nowait; StatusMsg: "正在启动归类服务..."

[UninstallRun]
; 卸载时停止并移除计划任务
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Install-Service.ps1"" -Action Stop"; WorkingDir: "{app}"; Flags: runhidden waituntilterminated
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Install-Service.ps1"" -Action Uninstall"; WorkingDir: "{app}"; Flags: runhidden waituntilterminated

[Messages]
chinesesimplified.WelcomeLabel2=这将安装 [name] 到您的电脑。%n%n功能：%n• 实时监控桌面新文件%n• 按后缀自动移动到分类文件夹%n• 每5分钟定时扫描兜底%n• 开机自动启动，后台运行%n%n建议关闭其他正在使用桌面的程序后继续。

[Code]
// 安装完成后提示用户
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    MsgBox('✅ 安装完成！' + #13#10 + #13#10 +
           '桌面自动归类已在后台运行。' + #13#10 +
           '新文件会在3秒后自动移动到对应分类文件夹。' + #13#10 + #13#10 +
           '配置文件位置: ' + ExpandConstant('{app}\config.json') + #13#10 +
           '可随时编辑分类规则。',
           mbInformation, MB_OK);
  end;
end;
