# Configuration for bbbike.cgi
[%
    IF CGI_TYPE == "ModPerl::Registry" || CGI_TYPE == "Apache::Registry";
        PROCESS preload_modules;
    END
-%]

[%
    SET cgiurls = [];

    IF CGI_TYPE == "ModPerl::Registry" || CGI_TYPE == "Apache::Registry";
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
	SET targetcgi = ROOT_DIR _ "/cgi/" _ cgi;
	TRY;
	    # Probably a symlink to the ...2.cgi version exists; use this
	    # as we can make use of a separate config file.
	    USE File(targetcgi);
	CATCH File;
            SET targetcgi = targetcgi.replace('2(\.en)?\.cgi', '$1.cgi');
	END;
-%]
[% ScriptAlias %] [% url %] [% targetcgi %]
[%
        cgiurls.push(url);
    END
-%]

# Special development CGI
[%# without modperl support, just a cgi -%]
ScriptAlias [% ROOT_URL %]/cgi/browserinfo.cgi [% ROOT_DIR %]/lib/BrowserInfo.pm

# HTML ... documents
Alias [% ROOT_URL %]  [% ROOT_DIR %]

# Redirect for root URL
RedirectMatch ^[% ROOT_URL %]/?$ [% ROOT_URL %]/cgi/bbbike.cgi

# server headers have precedence over http-equiv tags, so
# force utf-8 in case DefaultCharset is active
<Location [% ROOT_URL %]/html/opensearch/opensearch.html>
    AddType "text/html; charset=utf-8" .html
</Location>

<IfModule mod_deflate.c>
    <Location [% ROOT_URL %]>
	AddOutputFilterByType DEFLATE application/vnd.google-earth.kml+xml image/svg+xml application/xml
	AddOutputFilterByType DEFLATE application/json
	# no need to compress .wml ...
	#
	# The following is standard in Debian/squeeze's
	# apache2/mods-enabled/deflate.conf, but may be missing in
	# other installations:
	AddOutputFilterByType DEFLATE text/html text/plain text/xml
	AddOutputFilterByType DEFLATE text/css
	AddOutputFilterByType DEFLATE application/x-javascript application/javascript application/ecmascript
	AddOutputFilterByType DEFLATE application/rss+xml
    </Location>
</IfModule>

<IfModule mod_headers.c>
    <LocationMatch "^\Q[% ROOT_URL %]\E/data/[^/]+$">
        # This is needed to get the data files compressed.
        # The Content-Type is also text/plain if this is not set,
        # but somehow mod_deflate does not work otherwise...
        Header Set Content-Type text/plain
    </LocationMatch>
</IfModule>

[% IF 0 -%]
[%# compression by AddOutputFilterByType is smarter ... -%]
<IfModule deflate_module>
    <LocationMatch "^\Q[% ROOT_URL %]\E/(data|mapserver/brb)">
        SetOutputFilter DEFLATE
	# old browsers with problems
	BrowserMatch ^Mozilla/4 gzip-only-text/html
	BrowserMatch ^Mozilla/4\.0[678] no-gzip
	BrowserMatch \bMSI[E] !no-gzip !gzip-only-text/html
	# don't compress images (i.e. sehenswuerdigkeit...)
	SetEnvIfNoCase Request_URI \.(?:gif|jpe?g|png)$ no-gzip dont-vary
    </LocationMatch>
</IfModule>
[% END -%]

<IfModule perl_module>
    <Perl>
        use lib "[% ROOT_DIR %]";
    </Perl>

    PerlModule BBBikeDataDownloadCompat
    <LocationMatch "^\Q[% ROOT_URL %]/data/\E(strassen|landstrassen|landstrassen2)$">
        SetHandler perl-script
        PerlResponseHandler BBBikeDataDownloadCompat->handler
    </LocationMatch>

    PerlModule BBBikeApacheSessionCountedHandler
    <Location [% ROOT_URL %]/cgi/asch>
        SetHandler perl-script
        PerlResponseHandler BBBikeApacheSessionCountedHandler->handler
    </Location>
</IfModule>

[%
    IF CGI_TYPE == "ModPerl::Registry";
-%]
PerlModule ModPerl::Registry
[%
        FOR cgiurl = cgiurls
-%]
<Location [% cgiurl %]>
    SetHandler perl-script
    PerlResponseHandler ModPerl::Registry
    Options +ExecCGI
</Location>
[%
        END;
    ELSIF CGI_TYPE == "Apache::Registry";
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
PerlModule Apache::Session::Counted
PerlModule BBBikeApacheSessionCountedHandler
PerlModule BBBikeCalc
PerlModule BBBikeCGIAPI
PerlModule BBBikeCGICache
PerlModule BBBikeCGIUtil
PerlModule BBBikeDraw
PerlModule BBBikeDraw::GD
PerlModule BBBikeDraw::PDFCairo
PerlModule BBBikeMapserver
PerlModule BBBikeUtil
PerlModule BBBikeVar
PerlModule BBBikeXS
PerlModule BBBikeYAML
PerlModule BikePower
PerlModule BikePower::HTML
PerlModule BrowserInfo
PerlModule CGI
PerlModule CGI::Carp
PerlModule CGI::Cookie
PerlModule CGI::Util
PerlModule Data::Dumper
PerlModule File::Basename
PerlModule File::Spec
PerlModule JSON::XS
PerlModule Karte::Standard
PerlModule Karte::Polar
PerlModule Met::Wind
PerlModule PLZ
PerlModule PLZ::Multi
PerlModule PLZ::Result
PerlModule POSIX
PerlModule Route
PerlModule Storable
PerlModule Strassen
PerlModule Strassen::Core
PerlModule Strassen::Dataset
PerlModule Strassen::Fast
PerlModule Strassen::Generated
PerlModule Strassen::GPX
PerlModule Strassen::Heavy
PerlModule Strassen::KML
PerlModule Strassen::Kreuzungen
PerlModule Strassen::MultiStrassen
PerlModule Strassen::Strasse
PerlModule Strassen::StrassenNetz
PerlModule Strassen::Util
PerlModule Text::ParseWords
PerlModule VectorUtil
[%
    END
-%]

<IfDefine BBBIKE_NYTPROF>
    <Location [% ROOT_URL _ "/cgi" %]>
	SetEnv NYTPROF "file=/tmp/nytprof.out:addpid=1"
	SetEnv PERL5OPT "-d:NYTProf"
    </Location>
</IfDefine>

