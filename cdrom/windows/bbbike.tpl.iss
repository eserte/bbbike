; -- bbbike.iss --
; To get the inno setup software visit http://www.jrsoftware.org
[% PROCESS "../../BBBikeVar.tpl" -%]
[% PROCESS "BBBikeWinDistFiles.tpl" -%]
[% SET wperl_exe = "{app}\\windows\\5.6.1\\bin\\MSWin32-x86\\wperl.exe" -%]

[Setup]
AppName=BBBike
AppVerName=BBBike version [% BBBike.VERSION %]
AppVersion=[% BBBike.VERSION %]
AppPublisherURL=http://bbbike.sourceforge.net
DefaultDirName={pf}\BBBike
DefaultGroupName=BBBike
UninstallDisplayIcon={app}\bbbike\images\srtbike.ico
Compression=lzma
SolidCompression=yes
OutputDir=..\BBBike-Setup-Files
OutputBaseFilename=BBBike-[% BBBike.VERSION %]-Windows
OutputManifestFile=SETUP-MANIFEST

[Files]
[%
	FOR f = files
-%]
Source: "[% f.src %]"; DestDir: "{app}\[% f.dest %]"[% -%]
[% IF 0 %][%# not yet XXX %][% IF f.is_readme %]; Flags: isreadme[% END -%][% END -%]

[%
	END
-%]

[Icons]
Name: "{group}\BBBike"; Filename: "[% wperl_exe %]"; Parameters: """{app}\bbbike\bbbike"""; WorkingDir: "{app}\bbbike"; IconFilename: "{app}\bbbike\images\srtbike.ico"; Comment: "BBBike - ein Routenplaner für Radfahrer in Berlin und Brandenburg"
Name: "{userdesktop}\BBBike"; Filename: "[% wperl_exe %]"; Parameters: """{app}\bbbike\bbbike"""; WorkingDir: "{app}\bbbike"; IconFilename: "{app}\bbbike\images\srtbike.ico"; Comment: "BBBike - ein Routenplaner für Radfahrer in Berlin und Brandenburg"
Name: "{group}\BBBike im WWW"; Filename: "[% BBBike.BBBIKE_DIRECT_WWW %]"; IconFilename: "{app}\bbbike\images\srtbike_www.ico"
Name: "{group}\BBBike-Dokumentation"; Filename: "{app}\bbbike\bbbike.html"

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"
Name: "en"; MessagesFile: "compiler:Default.isl" 
