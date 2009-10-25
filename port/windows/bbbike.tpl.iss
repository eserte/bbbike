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
;;;
;;; This contains a MANIFEST copy of bbbike after running "make make-bbbike-dist"
Source: "C:\cygwin\home\eserte\bbbikewindist\bbbike\*"; DestDir: "{app}\bbbike"; Flags: ignoreversion recursesubdirs createallsubdirs
;;;
;;; XXX should contain an additional a notice where to get the complete distro and sources
;;; Note: libexpat.dll also exists in perl\bin (part of XML::Parser), so no
;;; duplication necessary
Source: "C:\cygwin\home\eserte\bbbikewindist\gpsbabel\*"; DestDir: "{app}\gpsbabel"; [% -%]
    Excludes: "gpsbabel.html,libexpat.dll"; Flags: ignoreversion recursesubdirs createallsubdirs
;;;
;;; XXX should contain a rather minimal strawberry. maybe strip some default modules there, but add essential like Tk and some nice-to-haves
Source: "C:\cygwin\home\eserte\bbbikewindist\perl\*"; DestDir: "{app}\perl"; [% ~%]
    Excludes: "[% ~%]
         .packlist				[%~ # packlists are not needed ~%]
        ,*.pod					[%~ # no need for documentation  ~%]
        ,\lib\auto\Encode\JP\*			[%~ # no need for east asian encodings ~%]
        ,\lib\Encode\JP\*			[%~ ~%]
        ,\lib\Encode\JP.pm			[%~ ~%]
        ,\lib\auto\Encode\KR\*			[%~ ~%]
        ,\lib\Encode\KR\*			[%~ ~%]
        ,\lib\Encode\KR.pm			[%~ ~%]
        ,\lib\auto\Encode\TW\*			[%~ ~%]
        ,\lib\Encode\TW\*			[%~ ~%]
        ,\lib\Encode\TW.pm			[%~ ~%]
        ,\lib\auto\Encode\CN\*			[%~ ~%]
        ,\lib\Encode\CN\*			[%~ ~%]
        ,\lib\Encode\CN.pm			[%~ ~%]
        ,\lib\auto\Encode\EBCDIC\*		[%~ ~%]
        ,\lib\Encode\EBCDIC.pm			[%~ ~%]
        ,\lib\unicore\*.txt			[%~ # the .txt files seem to be there for reference only ~%]
        ,\lib\Unicode\Collate\*			[%~ ~%]
        ,\lib\auto\Storable\Storable.dll.AAA[%~ # this looks like an packing accident in strawberry ~%]
        ,\lib\auto\Devel\*			[%~ # no need for development stuff ~%]
        ,\lib\CORE\*.a				[%~ ~%]
        ,\lib\CORE\*.h				[%~ ~%]
        ,\lib\CPANPLUS\*			[%~ ~%]
        ,\lib\CPAN\*				[%~ ~%]
        ,\lib\ExtUtils\*			[%~ ~%]
        ,\lib\Module\Build\*			[%~ ~%]
        ,\lib\Module\Build.pm			[%~ ~%]
        ,\lib\TAP\*				[%~ ~%]
        ,\lib\Test\*				[%~ ~%]
	,\lib\App\Prove.pm			[%~ ~%]
	,\lib\App\Prove\*			[%~ ~%]
	,\site\lib\auto\DBD\*			[%~ # currently no database-like things are needed ~%]
	,\site\lib\DBD\*			[%~ ~%]
	,\site\lib\DBI.pm			[%~ ~%]
	,\site\lib\DBI\*			[%~ ~%]
	,\site\lib\Bundle\*			[%~ ~%]
	,\site\lib\auto\Math\Pari\*		[%~ # large and unused ~%]
	,\site\lib\Math\Pari.pm			[%~ ~%]
	,\site\lib\XML\Twig.pm			[%~ # XML::LibXML is enough ~%]
	,\site\lib\XML\Twig\*			[%~ ~%]
	,\site\lib\PAR\*			[%~ ~%]
	,\site\lib\PAR.pm			[%~ ~%]
	,\site\lib\CPAN\*			[%~ ~%]
	,\site\lib\Tk\demos\*			[%~ ~%]
	,\site\lib\Tk\*.h			[%~ ~%]
	,\site\lib\Tk\*.m			[%~ ~%]
	,\site\lib\Tk\*.t			[%~ ~%]
	,\bin\a2p.exe				[%~ ~%]
	,\bin\h2xs.bat				[%~ ~%]
	,\bin\cpan				[%~ ~%]
	,\bin\cpan.bat				[%~ ~%]
	,\bin\cpan2dist.bat			[%~ ~%]
	,\bin\dprofpp.bat			[%~ ~%]
    "; Flags: ignoreversion recursesubdirs createallsubdirs
;;;
;;; additional files in c\bin required by XML::LibXML
;;; currently not in bbbikewindist, only in strawberry directory
Source: "C:\cygwin\home\eserte\strawberry\c\bin\libxml2.dll"; DestDir: "{app}\c\bin"; Flags: ignoreversion
Source: "C:\cygwin\home\eserte\strawberry\c\bin\iconv.dll"; DestDir: "{app}\c\bin"; Flags: ignoreversion
Source: "C:\cygwin\home\eserte\strawberry\c\bin\zlib1.dll"; DestDir: "{app}\c\bin"; Flags: ignoreversion
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
