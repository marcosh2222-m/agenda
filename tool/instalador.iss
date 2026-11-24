; Instalador de Windows (Inno Setup 6), solo para el usuario: no pide administrador. Lo compila tool\empaquetar.ps1.
; Al desinstalar quedan los datos (%APPDATA%\Agenda) y el dictado (%LOCALAPPDATA%\Agenda).
[Setup]
AppId={{6E0C9D0B-4B1E-4C55-9B5F-2B0A7B7C1A52}
AppName=Agenda
AppVersion={#Version}
AppPublisher=Agenda
DefaultDirName={autopf}\Agenda
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Cerrar la ventana solo la manda a la bandeja; para actualizar hay que cerrarla de verdad.
CloseApplications=force
RestartApplications=no
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\agenda.exe
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
OutputDir=..\dist
OutputBaseFilename=Agenda-instalador-{#Version}

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "escritorio"; Description: "{cm:CreateDesktopIcon}"
Name: "arranque"; Description: "Abrir con Windows, en la bandeja"

[InstallDelete]
; Lo de la versión anterior que la nueva ya no usa.
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "..\dist\Agenda\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Agenda"; Filename: "{app}\agenda.exe"; AppUserModelID: "com.agenda.agenda"
Name: "{autodesktop}\Agenda"; Filename: "{app}\agenda.exe"; AppUserModelID: "com.agenda.agenda"; Tasks: escritorio

[Registry]
; El mismo valor que escribe la app en Ajustes.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "Agenda"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Agenda"; ValueData: """{app}\agenda.exe"" --minimized"; Tasks: arranque

[Run]
Filename: "{app}\agenda.exe"; Description: "{cm:LaunchProgram,Agenda}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Cierra solo la instalada, no una portable que esté abierta.
Filename: "powershell.exe"; Parameters: "-NoProfile -Command ""Get-Process agenda -ErrorAction SilentlyContinue | Where-Object Path -eq '{app}\agenda.exe' | Stop-Process -Force -PassThru | Wait-Process"""; Flags: runhidden; RunOnceId: "cerrar"
