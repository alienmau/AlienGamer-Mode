#define MyAppName "AlienGamer Mode"
#define MyAppVersion "1.5.1"
#define MyAppPublisher "Alienmau"

[Setup]
AppId={{A8A4BE0B-3D0E-47DA-83C1-7A927B141E58}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
CreateAppDir=no
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\installer
OutputBaseFilename=AlienGamerMode-Setup-1.5.1
SetupIconFile=..\assets\AlienGamerMode.ico
WizardStyle=modern
ShowLanguageDialog=yes
Compression=lzma2
SolidCompression=yes
Uninstallable=no
VersionInfoVersion=1.5.1.0
VersionInfoProductVersion=1.5.1.0
VersionInfoProductName={#MyAppName}
VersionInfoDescription=Instalador adaptable del monitor AlienGamer Mode
VersionInfoCompany={#MyAppPublisher}
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[CustomMessages]
english.Configuring=Configuring AlienGamer Mode...
spanish.Configuring=Configurando AlienGamer Mode...

[Files]
Source: "..\assets\*"; DestDir: "{tmp}\AlienGamerMode\assets"; Flags: ignoreversion recursesubdirs createallsubdirs deleteafterinstall
Source: "..\config\*"; DestDir: "{tmp}\AlienGamerMode\config"; Flags: ignoreversion recursesubdirs createallsubdirs deleteafterinstall
Source: "..\docs\*"; DestDir: "{tmp}\AlienGamerMode\docs"; Excludes: "images\concepts\*,RELEASE-*.md"; Flags: ignoreversion recursesubdirs createallsubdirs deleteafterinstall
Source: "..\README.md"; DestDir: "{tmp}\AlienGamerMode"; Flags: ignoreversion deleteafterinstall
Source: "..\README.en.md"; DestDir: "{tmp}\AlienGamerMode"; Flags: ignoreversion deleteafterinstall
Source: "..\src\*"; DestDir: "{tmp}\AlienGamerMode\src"; Flags: ignoreversion recursesubdirs createallsubdirs deleteafterinstall
Source: "Install-AlienGamerMode.ps1"; DestDir: "{tmp}\AlienGamerMode\installer"; Flags: ignoreversion deleteafterinstall

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""{tmp}\AlienGamerMode\installer\Install-AlienGamerMode.ps1"" -Language ""{language}"""; StatusMsg: "{cm:Configuring}"; Flags: waituntilterminated
