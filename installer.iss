; ------------------------------------------------------------
; WhatsApp Bulk Sender - Working Installer Script
; ------------------------------------------------------------

[Setup]
AppName=WhatsApp Bulk Sender
AppVersion=1.0.0
AppPublisher=Prakash PS
DefaultDirName={pf}\WhatsApp Bulk Sender
DefaultGroupName=WhatsApp Bulk Sender
OutputDir=.
OutputBaseFilename=WhatsAppBulkSenderInstaller
Compression=lzma
SolidCompression=yes
DisableProgramGroupPage=yes
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\wa_spammer.exe
SetupIconFile=wa_sender_icon.ico

[Files]
; Main EXE
Source: "build\windows\x64\runner\Release\wa_spammer.exe"; \
    DestDir: "{app}"; Flags: ignoreversion

; Flutter runtime (exclude python, sender.py, exe, and icon)
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; \
    Excludes: "python_portable;sender.py;wa_spammer.exe;wa_sender_icon.ico"

; Python portable
Source: "build\windows\x64\runner\Release\python_portable\*"; \
    DestDir: "{app}\python_portable"; Flags: ignoreversion recursesubdirs createallsubdirs

; sender.py
Source: "build\windows\x64\runner\Release\sender.py"; DestDir: "{app}"; Flags: ignoreversion

; icon
Source: "wa_sender_icon.ico"; DestDir: "{app}"; Flags: ignoreversion


[Icons]
Name: "{userdesktop}\WhatsApp Bulk Sender"; \
    Filename: "{app}\wa_spammer.exe"; \
    IconFilename: "{app}\wa_sender_icon.ico"

Name: "{group}\WhatsApp Bulk Sender"; \
    Filename: "{app}\wa_spammer.exe"; \
    IconFilename: "{app}\wa_sender_icon.ico"

[Run]
Filename: "{app}\wa_spammer.exe"; Description: "Run WhatsApp Bulk Sender"; \
    Flags: nowait postinstall skipifsilent
