[% IF VIRTUAL_HOST;
       IF !VIRTUAL_PORT;
           SET VIRTUAL_PORT = 80;
       END;
   END;
-%]
[% IF VIRTUAL_HOST -%]
<VirtualHost *:[% VIRTUAL_PORT %]>
ServerName [% VIRTUAL_HOST %]
[%  IF SERVER_ALIAS -%]
ServerAlias [% SERVER_ALIAS %]
[%  END -%]
[% END -%]
[%  IF ALLOW_UNSAFE_HTTP && APACHE_VERSION >= 2.4 -%]
    # XXX needed because of Http.pm < 4.06, which may still access the webserver
    HttpProtocolOptions Unsafe

[%  END -%]
[% IF USE_PLACK_PROXY -%]
    Define BBBIKE_USE_PLACK_PROXY 1
[% ELSIF USE_PLACK_MODPERL -%]
    Define BBBIKE_USE_PLACK_MODPERL 1
[% END -%]
[%  IF !PLACK_PORT;
     SET PLACK_PORT = 5000;
    END;
-%]

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
[%      IF SERVER_ADMIN -%]
    ServerAdmin [% SERVER_ADMIN %]
[%      END -%]
    DocumentRoot [% DOCUMENT_ROOT %]

    ErrorLog  [% ERROR_LOG %]
    CustomLog [% ACCESS_LOG %] srt

[%      IF MAPSERV_FILE -%]
    ScriptAlias [% CGI_ROOT_URL %]/mapserv [% MAPSERV_FILE %]

[%      END -%]
    ScriptAlias [% CGI_ROOT_URL %]/ [% CGI_ROOT_DIR %]/
[%  END -%]

[% IF LOCATION_STYLE == "vhost" && APACHE_VERSION >= 2.4 -%]
    <Location />
       Require all granted
    </Location>
[% END -%]

    # HTML ... documents
    Alias [% ROOT_URL %] [% BBBIKE_ROOT_DIR %]
    <Location [% ROOT_URL %]>
        Options -Indexes
[% IF LOCATION_STYLE != "vhost" && APACHE_VERSION >= 2.4 -%]
        Require all granted
[% END -%]
    </Location>

[% IF LOCATION_STYLE == "bbbike" -%]
    # Redirects for root URL
    RedirectMatch ^[% ROOT_URL %]/?$ [% CGI_ROOT_URL %]/bbbike.cgi
    RedirectMatch ^[% ROOT_URL %]/wap(/index.wml)?$  [% CGI_ROOT_URL %]/wapbbbike.cgi
    RedirectMatch ^[% ROOT_URL %]/beta/?$    [% CGI_ROOT_URL %]/bbbike2.cgi
    RedirectMatch ^[% ROOT_URL %]/en/?$      [% CGI_ROOT_URL %]/bbbike.en.cgi
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
    <Location [% ROOT_URL %]>
        AddType "application/geo+json" .geojson
    </Location>

    # note: compression is disabled for old Http.pm versions (<= 4.07) on darwin because of zcat/gzcat problems
    <IfModule mod_deflate.c>
[% IF LOCATION_STYLE == "bbbike" -%]
        <Location [% ROOT_URL %]>
[% ELSIF LOCATION_STYLE == "vhost" -%]
        <Location />
[% END -%]
	    AddOutputFilterByType DEFLATE application/vnd.google-earth.kml+xml application/gpx+xml image/svg+xml application/xml
	    AddOutputFilterByType DEFLATE application/json application/geo+json
	    # no need to compress .wml ...
	    #
	    # The following is standard in Debian/squeeze's
	    # apache2/mods-enabled/deflate.conf, but may be missing in
	    # other installations:
	    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/x-perl
	    AddOutputFilterByType DEFLATE text/css
	    AddOutputFilterByType DEFLATE application/x-javascript application/javascript application/ecmascript
	    AddOutputFilterByType DEFLATE application/rss+xml

	    SetEnvIf User-Agent "bbbike/.*\(Http/[1-3]\.[0-9]+\)" no-gzip
	    SetEnvIf User-Agent "bbbike/.*\(Http/4\.0[1-7]\) \(darwin\)" no-gzip
        </Location>

        <LocationMatch "^\Q[% ROOT_URL %]\E/data/[^/]+$">
	    SetOutputFilter DEFLATE
	    SetEnvIf User-Agent "bbbike/.*\(Http/[1-3]\.[0-9]+\)" no-gzip
	    SetEnvIf User-Agent "bbbike/.*\(Http/4\.0[1-7]\) \(darwin\)" no-gzip
        </LocationMatch>
    </IfModule>

    <IfDefine BBBIKE_USE_PLACK_PROXY>
	ProxyPreserveHost On
	ProxyPass        /BBBike/data http://localhost:[% PLACK_PORT %]/BBBike/data
	ProxyPassReverse /BBBike/data http://localhost:[% PLACK_PORT %]/BBBike/data
    </IfDefine>
    <IfDefine !BBBIKE_USE_PLACK_PROXY>
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

        <IfDefine BBBIKE_USE_PLACK_MODPERL>
            <Location [% ROOT_URL %]/data>
                SetHandler perl-script
                PerlResponseHandler Plack::Handler::Apache2
                PerlSetVar psgi_app [% BBBIKE_ROOT_DIR %]/cgi/bbbike-data-download.psgi
            </Location>
        </IfDefine>
        <IfDefine !BBBIKE_USE_PLACK_MODPERL>
            PerlModule BBBikeDataDownloadCompat
            <LocationMatch "^\Q[% ROOT_URL %]/data/\E(strassen|landstrassen|landstrassen2|label|multi_bez_str)$">
                SetHandler perl-script
                PerlResponseHandler BBBikeDataDownloadCompat->handler
            </LocationMatch>
        </IfDefine>

        PerlModule BBBikeApacheSessionCountedHandler
        <Location [% CGI_ROOT_URL %]/asch>
            SetHandler perl-script
            PerlResponseHandler BBBikeApacheSessionCountedHandler->handler
        </Location>
    </IfModule>
    </IfDefine>

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

[% IF VIRTUAL_HOST -%]
</VirtualHost>
[% END -%]
