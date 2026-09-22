; Inno Setup script for the Asasfans Next Windows installer.
;
; Built by the CI workflow after `flutter build windows --release`. AppVersion
; and the source directory are passed in with /D so the version is never
; duplicated here and cannot drift from pubspec.yaml.
;
; The installer is unsigned: no Authenticode certificate exists for this
; project, so SmartScreen will warn on first run. That is a distribution gap,
; not something the script can work around.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

#define AppName "Asasfans Next"
#define AppExeName "asasfans_next.exe"

[Setup]
AppId={{8F3C21A6-5E4B-4C7D-9A18-2B6D0E7F4C33}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=LEN5010
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
; Per-user install by default, so no administrator prompt is needed.
PrivilegesRequiredOverridesAllowed=dialog
PrivilegesRequired=lowest
OutputDir=..\..\build\windows
OutputBaseFilename=asasfans-next-{#AppVersion}-windows-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; The app itself requires 64-bit Windows 10 or newer, matching what Flutter
; supports; saying so here beats failing at launch.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Default.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"; Flags: unchecked

[Files]
; The whole release folder: the exe alone will not run without the Flutter
; DLLs and the data directory beside it.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\卸载 {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "立即运行 {#AppName}"; Flags: nowait postinstall skipifsilent
