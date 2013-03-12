; -- bbbike.iss --
; To get the inno setup software visit http://www.jrsoftware.org
[% IF VERSION == "";
   SET VERSION = BBBike.WINDOWS_VERSION;
   END;
-%]
[% PROCESS "../../BBBikeVar.tpl" -%]
[% SET wperl_exe = "{app}\\perl\\bin\\wperl.exe"; -%]
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
OutputDir=c:\cygwin\tmp
OutputBaseFilename=BBBike-[% VERSION %]-Windows
OutputManifestFile=SETUP-MANIFEST

[Files]
;;;
;;; This contains a MANIFEST copy of bbbike after running "make make-bbbike-dist"
Source: "C:\cygwin\home\eserte\bbbikewindist\bbbike\*"; DestDir: "{app}\bbbike"; Flags: ignoreversion recursesubdirs createallsubdirs
;;;
;;; XXX should contain an additional a notice where to get the complete distro and sources
;;; Note: in previous Strawberry versions there was a libexpat.dll in perl\bin (part of XML::Parser),
;;; but nowadays (at least since 5.14.x) it's called libexpat-1.dll
Source: "C:\cygwin\home\eserte\bbbikewindist\gpsbabel\*"; DestDir: "{app}\gpsbabel"; [% -%]
    Flags: ignoreversion recursesubdirs createallsubdirs
;;;
;;; This contains a rather minimal Strawberry,
;;; see strawberry-include-exclude.pl and create_customized_strawberry.pl
Source: "C:\cygwin\home\eserte\bbbikewindist\perl\*"; DestDir: "{app}\perl"; [% ~%]
    Flags: ignoreversion recursesubdirs createallsubdirs
;;;
;;; additional files in c\bin required by XML::LibXML and Tk
Source: "C:\cygwin\home\eserte\bbbikewindist\c\*"; DestDir: "{app}\c"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "C:\cygwin\home\eserte\bbbikewindist\portable.perl"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\cygwin\home\eserte\bbbikewindist\portableshell.bat"; DestDir: "{app}"; Flags: ignoreversion

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
Root: HKCR; Subkey: "BBBike.Route\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """[% wperl_exe %]"" ""{app}\bbbike\bbbike"" ""%1"""

[InstallDelete]
Type: filesandordirs; Name: "{app}\perl"
Type: filesandordirs; Name: "{app}\c"
