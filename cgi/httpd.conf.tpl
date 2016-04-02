[%  IF    LOCATION_STYLE == "bbbike";
        SET CGI_ROOT_URL = ROOT_URL _ "/cgi";
    ELSIF LOCATION_STYLE == "vhost";
        SET ROOT_URL = "/BBBike";
        SET CGI_ROOT_URL = "/cgi-bin";
	IF OS_STYLE == "freebsd";
	    SET ERROR_LOG = "/var/log/httpd-bbbike.de_error.log";
	    SET ACCESS_LOG = "/var/log/httpd-bbbike.de_access.log";
	    SET MAPSERV_FILE = "/usr/local/www/cgi-bin/mapserv";
	ELSIF OS_STYLE == "debian";
	    SET ERROR_LOG = "/var/log/apache2/bbbike.de_error.log";
	    SET ACCESS_LOG = "/var/log/apache2/bbbike.de_access.log";
	ELSE;
	    THROW vars "Please specify OS_STYLE (freebsd or debian)";
	END;
    ELSE;
        THROW vars "Unknown LOCATION_STYLE " _ LOCATION_STYLE;
    END;
    IF FS_STYLE == "live";
        SET CGI_ROOT_DIR = ROOT_DIR _ "/cgi-bin";
	SET DOCUMENT_ROOT = ROOT_DIR _ "/public";
	SET BBBIKE_ROOT_DIR = ROOT_DIR _ "/BBBike";
    ELSE;
        SET CGI_ROOT_DIR = ROOT_DIR _ "/cgi";
	SET DOCUMENT_ROOT = ROOT_DIR _ "/html";
	SET BBBIKE_ROOT_DIR = ROOT_DIR;
    END;
-%]
[%
    IF CGI_TYPE == "ModPerl::Registry" || CGI_TYPE == "Apache::Registry";
        PROCESS preload_modules;
    END
-%]
[%  IF LOCATION_STYLE == "bbbike" -%]
    # Configuration for bbbike.cgi
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
	SET url       = CGI_ROOT_URL _ "/" _ cgi;
        SET targetcgi = CGI_ROOT_DIR _ "/" _ cgi;
-%]
    [% ScriptAlias %] [% url %] [% targetcgi %]
[%
        cgiurls.push(url);
    END
-%]

    # Development versions of CGI scripts
[%
    FOR cgi = DEVEL_CGI_SCRIPTS.split(" +");
	SET url       = CGI_ROOT_URL _ "/" _ cgi;
	SET targetcgi = CGI_ROOT_DIR _ "/" _ cgi;
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
    ScriptAlias [% CGI_ROOT_URL %]/browserinfo.cgi [% BBBIKE_ROOT_DIR %]/lib/BrowserInfo.pm

[%  ELSIF LOCATION_STYLE == "vhost" -%]
    DocumentRoot [% DOCUMENT_ROOT %]

    ErrorLog  [% ERROR_LOG %]
    CustomLog [% ACCESS_LOG %] srt

[%      IF MAPSERV_FILE -%]
    ScriptAlias [% CGI_ROOT_URL %]/mapserv [% MAPSERV_FILE %]

[%      END -%]
    ScriptAlias [% CGI_ROOT_URL %]/ [% CGI_ROOT_DIR %]/
[%  END -%]

    # HTML ... documents
    Alias [% ROOT_URL %] [% BBBIKE_ROOT_DIR %]
    <Location [% ROOT_URL %]>
        Options -Indexes
    </Location>
[% IF APACHE_VERSION >= 2.4 -%]
    <Location [% ROOT_URL %]>
        Require all granted
    </Location>
[% END -%]

[% IF LOCATION_STYLE == "bbbike" -%]
    # Redirect for root URL
    RedirectMatch ^[% ROOT_URL %]/?$ [% CGI_ROOT_URL %]/bbbike.cgi
[% ELSIF LOCATION_STYLE == "vhost" -%]
    RedirectMatch ^/$  [% CGI_ROOT_URL %]/bbbike.cgi
    RedirectMatch ^/wap(/index.wml)?$  [% CGI_ROOT_URL %]/wapbbbike.cgi
    RedirectMatch ^/beta/?$    [% CGI_ROOT_URL %]/bbbike2.cgi
    RedirectMatch ^/en/?$      [% CGI_ROOT_URL %]/bbbike.en.cgi
[% END -%]

    # server headers have precedence over http-equiv tags, so
    # force utf-8 in case DefaultCharset is active
    <Location [% ROOT_URL %]/html/opensearch/opensearch.html>
        AddType "text/html; charset=utf-8" .html
    </Location>

    <IfModule mod_deflate.c>
[% IF LOCATION_STYLE == "bbbike" -%]
        <Location [% ROOT_URL %]>
[% ELSIF LOCATION_STYLE == "vhost" -%]
        <Location />
[% END -%]
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
            use lib "[% BBBIKE_ROOT_DIR %]";
        </Perl>

        PerlModule Apache2::Reload
        PerlInitHandler Apache2::Reload
        PerlSetVar ReloadDirectories "[% BBBIKE_ROOT_DIR %]"
        ## Apache2::Reload's module_to_package translation is suboptimal
        ## and leads to strange prototype errors, so it's best to turn
        ## the following switch on
        PerlSetVar ReloadByModuleName On
        ## very verbose, reports on every mtime check of the touch file
        #PerlSetVar ReloadDebug On
        PerlSetVar ReloadTouchFile "[% BBBIKE_ROOT_DIR %]/tmp/reload_modules"

        PerlModule BBBikeDataDownloadCompat
        <LocationMatch "^\Q[% ROOT_URL %]/data/\E(strassen|landstrassen|landstrassen2|label)$">
            SetHandler perl-script
            PerlResponseHandler BBBikeDataDownloadCompat->handler
        </LocationMatch>

        PerlModule BBBikeApacheSessionCountedHandler
        <Location [% CGI_ROOT_URL %]/asch>
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

[% IF LOCATION_STYLE == "bbbike" -%]
    <Location [% ROOT_URL %]/>
        ErrorDocument 404 [% ROOT_URL %]/html/error404.html
    </Location>
[% ELSIF LOCATION_STYLE == "vhost" -%]
    ErrorDocument 404 [% ROOT_URL %]/html/error404.html
[% END -%]

[%
    BLOCK preload_modules
-%]
    <Perl>
        use lib "[% BBBIKE_ROOT_DIR %]";
        use lib "[% BBBIKE_ROOT_DIR %]/lib";
    </Perl>
    PerlModule Apache::Session::Counted
    PerlModule BBBikeApacheSessionCountedHandler
    PerlModule BBBikeCalc
    PerlModule BBBikeCGI::API
    PerlModule BBBikeCGI::Cache
    PerlModule BBBikeCGI::Util
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
        <Location [% CGI_ROOT_URL %]>
    	SetEnv NYTPROF "file=/tmp/nytprof.out:addpid=1"
    	SetEnv PERL5OPT "-d:NYTProf"
        </Location>
    </IfDefine>

