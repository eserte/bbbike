# Configuration for bbbike.cgi
[% FOR cgi = CGI_SCRIPTS.split(" ") -%]
[% IF CGI_TYPE == "Apache::Registry" -%]
Alias [% ROOT_URL%]/cgi/[% cgi %] [% ROOT_DIR %]/cgi/[% cgi %]
<Location [% ROOT_URL%]/cgi/[% cgi %]>
  SetHandler perl-script
  PerlHandler Apache::Registry
  Options +ExecCGI
</Location>
[% ELSE -%]
ScriptAlias [% ROOT_URL %]/cgi/[% cgi %] [% ROOT_DIR %]/cgi/[% cgi %]
[% END -%]
[% END -%]
Alias [% ROOT_URL %]  [% ROOT_DIR %]
