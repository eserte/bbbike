; -- bbbike.iss --
; To get the inno setup software visit http://www.jrsoftware.org
[% IF VERSION == "";
   SET VERSION = BBBike.WINDOWS_VERSION;
   END;
-%]
[% PROCESS "../../BBBikeVar.tpl" -%]
[% IF use_strawberry;
     SET wperl_exe = "{app}\\perl\\bin\\wperl.exe";
   ELSE;
     PROCESS "BBBikeWinDistFiles.tpl";
     SET wperl_exe = "{app}\\windows\\5.6.1\\bin\\MSWin32-x86\\wperl.exe";
   END;
-%]
[% USE date %]

[Setup]
AppName=BBBike
AppVerName=BBBike version [% VERSION %]
AppVersion=[% VERSION %]
AppPublisherURL=http://bbbike.sourceforge.net
AppCopyright=Copyright (c) 1995-[% date.format(date.now, "%Y")%] Slaven Rezic
AppPublisher=Slaven Rezic
ChangesAssociations=yes
DefaultDirName={pf}\BBBike
DefaultGroupName=BBBike
UninstallDisplayIcon={app}\bbbike\images\srtbike.ico
Compression=lzma
SolidCompression=yes
[% IF use_strawberry -%]
OutputDir=c:\cygwin\tmp
[% ELSE -%]
OutputDir=..\BBBike-Setup-Files
[% END -%]
OutputBaseFilename=BBBike-[% VERSION %]-Windows
OutputManifestFile=SETUP-MANIFEST

[Files]
[% IF use_strawberry -%]
;;; XXX should contain only a MANIFEST copy of bbbike
Source: "C:\cygwin\home\eserte\bbbikewindist\bbbike\*"; DestDir: "{app}\bbbike"; Flags: ignoreversion recursesubdirs createallsubdirs
;;; XXX should contain a minimal set of gpsbabel, i.e. without doc, and maybe additional a notice where to get the complete distro and sources
Source: "C:\cygwin\home\eserte\bbbikewindist\gpsbabel\*"; DestDir: "{app}\gpsbabel"; Flags: ignoreversion recursesubdirs createallsubdirs
;;; XXX should contain a rather minimal strawberry. maybe strip some default modules there, but add essential like Tk and some nice-to-haves
Source: "C:\cygwin\home\eserte\bbbikewindist\perl\*"; DestDir: "{app}\perl"; Flags: ignoreversion recursesubdirs createallsubdirs
[% ELSE -%]
[%
	FOR f = files
-%]
Source: "[% f.src %]"; DestDir: "{app}\[% f.dest %]"[% -%]
[% IF 0 %][%# not yet XXX %][% IF f.is_readme %]; Flags: isreadme[% END -%][% END -%]

[%
	END
-%]
[% END -%]

[Icons]
Name: "{group}\BBBike"; Filename: "[% wperl_exe %]"; Parameters: """{app}\bbbike\bbbike"""; WorkingDir: "{app}\bbbike"; IconFilename: "{app}\bbbike\images\srtbike.ico"; Comment: "BBBike - ein Routenplaner für Radfahrer in Berlin und Brandenburg"
Name: "{userdesktop}\BBBike"; Filename: "[% wperl_exe %]"; Parameters: """{app}\bbbike\bbbike"""; WorkingDir: "{app}\bbbike"; IconFilename: "{app}\bbbike\images\srtbike.ico"; Comment: "BBBike - ein Routenplaner für Radfahrer in Berlin und Brandenburg"
Name: "{group}\BBBike im WWW"; Filename: "[% BBBike.BBBIKE_DIRECT_WWW %]"; IconFilename: "{app}\bbbike\images\srtbike_www.ico"
Name: "{group}\BBBike-Dokumentation"; Filename: "{app}\bbbike\doc\bbbike.html"
Name: "{group}\BBBike Chooser"; Filename: "[% wperl_exe %]"; Parameters: """{app}\bbbike\miscsrc\bbbike_chooser.pl"""; WorkingDir: "{app}\bbbike"; IconFilename: "{app}\bbbike\images\srtbike.ico"

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"
Name: "en"; MessagesFile: "compiler:Default.isl" 

[Registry]
; .bbr
Root: HKCR; Subkey: ".bbr"; ValueType: string; ValueName: ""; ValueData: "BBBike.Route"; Flags: uninsdeletevalue
Root: HKCR; Subkey: "BBBike.Route"; ValueType: string; ValueName: ""; ValueData: "BBBike-Route"; Flags: uninsdeletekey
Root: HKCR; Subkey: "BBBike.Route\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\bbbike\images\srtbike.ico"
Root: HKCR; Subkey: "BBBike.Route\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\bbbike\bbbike"" ""%1"""
