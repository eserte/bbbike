# Configuration for bbbike.cgi
[% FOR cgi = CGI_SCRIPTS.split(" ") -%]
ScriptAlias [% ROOT_URL %]/cgi/[% cgi %] [% ROOT_DIR %]/cgi/[% cgi %]
[% END -%]
Alias [% ROOT_URL %]  [% ROOT_DIR %]
