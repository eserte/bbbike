# Configuration for bbbike.cgi
[%
    IF CGI_TYPE == "Apache::Registry";
## XXX preloading modules is a bad idea unless
## I get read of all Class::Struct usages...
#        PROCESS preload_modules;
    END
-%]

[%
    SET cgiurls = [];

    IF CGI_TYPE == "Apache::Registry";
        SET ScriptAlias = "Alias";
    ELSE;
        SET ScriptAlias = "ScriptAlias";
    END
-%]

# CGI scripts
[%
    FOR cgi = CGI_SCRIPTS.split(" +");
	SET url       = ROOT_URL _ "/cgi/" _ cgi;
        SET targetcgi = ROOT_DIR _ "/cgi/" _ cgi;
-%]
[% ScriptAlias %] [% url %] [% targetcgi %]
[%
        cgiurls.push(url);
    END
-%]

# Development versions of CGI scripts
[%
    FOR cgi = DEVEL_CGI_SCRIPTS.split(" +");
	SET url       = ROOT_URL _ "/cgi/" _ cgi;
        SET targetcgi = ROOT_DIR _ "/cgi/" _ cgi.replace('2(\.en)?\.cgi', '$1.cgi');
-%]
[% ScriptAlias %] [% url %] [% targetcgi %]
[%
        cgiurls.push(url);
    END
-%]

# HTML ... documents
Alias [% ROOT_URL %]  [% ROOT_DIR %]

# server headers have precedence over http-equiv tags, so
# force utf-8 in case DefaultCharset is active
<Location [% ROOT_URL %]/html/opensearch/opensearch.html>
    AddType "text/html; charset=utf-8" .html
</Location>

[%
    IF CGI_TYPE == "Apache::Registry";
        FOR cgiurl = cgiurls
-%]
<Location [% cgiurl %]>
    SetHandler perl-script
    PerlHandler Apache::Registry
    Options +ExecCGI
</Location>
[%
        END;
    END
-%]

<Location [% ROOT_URL %]/>
    ErrorDocument 404 [% ROOT_URL %]/html/error404.html
</Location>

[%
    BLOCK preload_modules
-%]
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
[%
    END
-%]
