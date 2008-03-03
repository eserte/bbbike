# Configuration for bbbike.cgi
[% FOR cgi = CGI_SCRIPTS.split(" ") -%]
[% IF CGI_TYPE == "Apache::Registry" -%]
<IfModule mod_perl.c>
[% PROCESS preload_modules -%]
  Alias [% ROOT_URL%]/cgi/[% cgi %] [% ROOT_DIR %]/cgi/[% cgi %]
  <Location [% ROOT_URL%]/cgi/[% cgi %]>
    SetHandler perl-script
    PerlHandler Apache::Registry
    Options +ExecCGI
  </Location>
</IfModule>
[% ELSE -%]
ScriptAlias [% ROOT_URL %]/cgi/[% cgi %] [% ROOT_DIR %]/cgi/[% cgi %]
[% END -%]
[% END -%]
# The development versions:
ScriptAlias [% ROOT_URL %]/cgi/bbbike2.cgi [% ROOT_DIR %]/cgi/bbbike2.cgi
ScriptAlias [% ROOT_URL %]/cgi/bbbikegoolemap2.cgi [% ROOT_DIR %]/cgi/bbbikegooglemap2.cgi
Alias [% ROOT_URL %]  [% ROOT_DIR %]
[%
	BLOCK preload_modules
-%]
<IfModule mod_perl.c>
  <Perl>
    use lib "[% ROOT_DIR %]";
    use lib "[% ROOT_DIR %]/lib";
  </Perl>
  PerlModule BBBikeCalc
  PerlModule BBBikeUtil
  PerlModule BBBikeVar
  PerlModule BBBikeXS
  PerlModule BikePower
  PerlModule BikePower::HTML
  PerlModule BrowserInfo
  PerlModule CGI
  PerlModule CGI::Carp
  PerlModule CGI::Cookie
  PerlModule CGI::Util
  PerlModule Strassen
  PerlModule Strassen::Core
  PerlModule Strassen::Dataset
  PerlModule Strassen::Fast
  PerlModule Strassen::Generated
  PerlModule Strassen::Heavy
  PerlModule Strassen::Kreuzungen
  PerlModule Strassen::MultiBezStr
  PerlModule Strassen::MultiStrassen
  PerlModule Strassen::Strasse
  PerlModule Strassen::StrassenNetz
  PerlModule Strassen::Util
</IfModule>
[%
	END
-%]

[%# not tested yet! XXX %]
<Location [% ROOT_URL %]/>
  ErrorDocument 404 [% ROOT_URL %]/html/error404.html
</Location>
