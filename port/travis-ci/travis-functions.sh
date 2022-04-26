# Please source this file:
#
#    . .../bbbike/port/travis-ci/travis-functions.sh
#

apt_quiet=-q
#apt_quiet=-qq

######################################################################
# Utilities
init_travis() {
    set -e
}

wrapper() {
    set -x
    $*
    set +x
}

######################################################################
# Functions for the before-install phase:

init_env_vars() {
    : ${BBBIKE_LONG_TESTS=1}
    : ${BBBIKE_TEST_SKIP_MAPSERVER=1}
    export BBBIKE_LONG_TESTS BBBIKE_TEST_SKIP_MAPSERVER
    # The default www.cpan.org may not be the fastest one, and may
    # even cause problems if an IPv6 address is chosen...
    export PERL_CPANM_OPT="$PERL_CPANM_OPT --mirror https://cpan.metacpan.org --mirror http://cpan.cpantesters.org"
    CODENAME=$(lsb_release -c -s || perl -nle '/^VERSION_CODENAME="?([^"]+)/ and $codename=$1; /^VERSION="\d+ \((.*)\)/ and $maybe_codename=$1; END { print $codename // $maybe_codename }' /etc/os-release)
    if [ "$CODENAME" = "" ]
    then
	if grep -q "Ubuntu 12.04" /etc/issue
	then
	    CODENAME=precise
	else
	    echo "WARNING: don't know what linux distribution is running. Possible failures are possible"
	fi
    fi
    export CODENAME
}

init_perl() {
    if [ "$USE_SYSTEM_PERL" = "1" ]
    then
	if which perlbrew >/dev/null 2>&1
	then
	    perlbrew off
	fi
    fi
}

init_apt() {
    # broken on (since?) 2019-08-21 on precise:
    # E: Failed to fetch http://downloads-distro.mongodb.org/repo/debian-sysvinit/dists/dist/InRelease  Clearsigned file isn't valid, got 'NOSPLIT' (does the network require authentication?)
    # Since 2020-02-16 more repositories (chrome, cassandra, git-lfs, couchdb) are broken on trusty.
    # Since 2021-05-07 the postgresql repo (pgdg) is broken on trusty.
    # Remove also additional mongodb-org repo.
    (cd /etc/apt/sources.list.d && sudo rm -f mongodb.list mongodb-org-4.0.list google-chrome.list cassandra.list github_git-lfs.list couchdb.list pgdg.list)

    if [ "$USE_SYSTEM_PERL" = "1" ]
    then
	if [ "$USE_BBBIKE_PPA" = "1" ]
	then
	    if ! which add-apt-repository >/dev/null 2>&1
	    then
	        sudo apt-get install -y $apt_quiet --no-install-recommends software-properties-common
	    fi
	    sudo add-apt-repository ppa:eserte/bbbike
	else
	    if [ ! -e /etc/apt/sources.list.d/mydebs.bbbike.list ]
	    then
	        wget --connect-timeout=10 --tries=5 -O- http://mydebs.bbbike.de/key/mydebs.bbbike.key | sudo apt-key add -
	        sudo sh -c "echo deb http://mydebs.bbbike.de ${CODENAME} main > /etc/apt/sources.list.d/mydebs.bbbike.list~"
	        sudo mv /etc/apt/sources.list.d/mydebs.bbbike.list~ /etc/apt/sources.list.d/mydebs.bbbike.list
	    fi
	fi
    fi
    sudo apt-get update $apt_quiet
}

# Reasons for the following dependencies
# - freebsd-buildutils or bmake: provides freebsd-make resp. fmake resp. pmake
# - libproj-dev + proj-bin: prerequisites for Geo::Proj4
# - libdb-dev:              prerequisite for DB_File
# - agrep + tre-agrep:      needed as String::Approx alternative
# - libgd2-xpm-dev or libgd-dev: prerequisite for GD
# - ttf-bitstream-vera + fonts-dejavu: fonts e.g. for BBBikeDraw::GD
# - xvfb + fvwm:            some optional tests require an X server
# - libmozjs-24-bin or rhino: javascript tests
# - imagemagick:            typ2legend test
# - libpango1.0-dev:        prerequisite for Pango
# - libxml2-utils:          xmllint
# - libzbar-dev:            prerequisite for Barcode::ZBar
# - pdftk:                  compression in BBBikeDraw::PDFUtil (for non-cairo)
# - poppler-utils:          provides pdfinfo for testing
# - tzdata:                 t/geocode_images.t needs to set TZ
install_non_perl_dependencies() {
    if [ "$CODENAME" = "precise" -o "$CODENAME" = "bionic" -o "$CODENAME" = "focal" -o "$CODENAME" = "jammy" -o "$CODENAME" = "buster" -o "$CODENAME" = "bullseye" ]
    then
	javascript_package=rhino
    else
	javascript_package=libmozjs-24-bin
    fi
    # debian/stretch and ubuntu/xenial have both rhino and libmozjs-24-bin

    if [ "$CODENAME" = "stretch" -o "$CODENAME" = "buster" -o "$CODENAME" = "xenial" -o "$CODENAME" = "bionic" -o "$CODENAME" = "focal" -o "$CODENAME" = "jammy" -o "$CODENAME" = "bullseye" ]
    then
	libgd_dev_package=libgd-dev
    else
	libgd_dev_package=libgd2-xpm-dev
    fi

    if [ "$CODENAME" = "bionic" ]
    then
	# Not available anymore, see
	# https://askubuntu.com/q/1028522
	pdftk_package=
    elif [ "$CODENAME" = "buster" -o "$CODENAME" = "focal" -o "$CODENAME" = "jammy" -o "$CODENAME" = "bullseye" ]
    then
	pdftk_package=pdftk-java
    else
	pdftk_package=pdftk
    fi

    if [ "$CODENAME" = "precise" -o "$CODENAME" = "focal" -o "$CODENAME" = "jammy" -o "$CODENAME" = "bullseye" ]
    then
	# Since about 2018-06 not installable anymore on the
	# travis instances
	#
	# Also not needed on Ubuntu 20.04, Alien::Proj4 is used for Geo::Proj4 (see below)
	libproj_packages=
    else
	libproj_packages="libproj-dev proj-bin"
    fi

    if [ "$GITHUB_WORKFLOW" != "" -a "$USE_SYSTEM_PERL" = "" ]
    then
	cpanminus_package=cpanminus
    else
	cpanminus_package=
    fi

    if [ "$CODENAME" = "trusty" -o "$CODENAME" = "precise" ]
    then
	freebsdmake_package=freebsd-buildutils
    else
        freebsdmake_package=bmake
    fi

    if [ "$CODENAME" = "trusty" -o "$CODENAME" = "precise" ]
    then
	dejavu_package=ttf-dejavu
    else
        dejavu_package=fonts-dejavu
    fi

    sudo -E apt-get install -y $apt_quiet --no-install-recommends $freebsdmake_package $libproj_packages libdb-dev agrep tre-agrep $libgd_dev_package ttf-bitstream-vera $dejavu_package gpsbabel xvfb fvwm $javascript_package imagemagick libpango1.0-dev libxml2-utils libzbar-dev $pdftk_package poppler-utils tzdata gcc $cpanminus_package
    if [ "$BBBIKE_TEST_SKIP_MAPSERVER" != "1" ]
    then
	sudo apt-get install -y $apt_quiet --no-install-recommends mapserver-bin cgi-mapserver
    fi

    # Hack to run libqt5core (needed by gpsbabel) in a debian:buster
    # or newer container on an older container host (i.e. debian:jessie)
    qt5sofile=/usr/lib/x86_64-linux-gnu/libQt5Core.so.5
    if [ -e $qt5sofile ]
    then
        case "$(uname -r)" in
	    3.16.*)
		if ldconfig -p | perl -Mversion -nle 'if (/libQt5Core.so.*OS ABI: Linux (\d+\.\d+)/) { exit($1 > 3.16 ? 0 : 1) }'
		then
		    echo "Need to remove ABI specification of $qt5sofile"
		    sudo apt-get install -y $apt_quiet --no-install-recommends binutils
		    sudo strip --remove-section=.note.ABI-tag $qt5sofile
		fi
		;;
	esac
    fi
}

# Some CPAN modules not mentioned in Makefile.PL, usually for testing only
install_perl_testonly_dependencies() {
    if [ "$USE_SYSTEM_PERL" = "1" ]
    then
	sudo apt-get install -y $apt_quiet --no-install-recommends libemail-mime-perl libhtml-treebuilder-xpath-perl libbarcode-zbar-perl libwww-mechanize-formfiller-perl
    else
	if [ "$CODENAME" = "buster" -o "$CODENAME" = "focal" -o "$CODENAME" = "jammy" -o "$CODENAME" = "bullseye" ]
	then
	    barcode_zbar_module="Barcode::ZBar"
	else
	    # Does not compile on older Linux distributions,
	    barcode_zbar_module="Barcode::ZBar~<0.10"
	fi
	cpanm --quiet --notest Email::MIME HTML::TreeBuilder::XPath $barcode_zbar_module
    fi
}

install_old_perl_dependencies() {
    if [ "$PERLBREW_PERL" = "5.8" -a ! "$USE_SYSTEM_PERL" = "1" ]
    then
	# DBD::XBase versions between 1.00..1.05 explicitely want Perl 5.10.0 as a minimum. See https://rt.cpan.org/Ticket/Display.html?id=88873
	#
	# Until cpanminus 1.7032 (approx.) it was possible to specify
	# DBD::XBase~"!=1.00, !=1.01, !=1.02, !=1.03, !=1.04, !=1.05"
	# but now one has to use exact version matches to load something from BackPAN
	#
	# Perl 5.8.9's File::Path has a version with underscores, and this is causing warnings and failures in the test suite
	#
	# Wrong version specification in DB_File's Makefile.PL, see https://rt.cpan.org/Ticket/Display.html?id=100844
	#
        # Pegex 0.62 and newer runs only on perl 5.10.0 and newer.
	#
	# Inline::C 0.77 (and probably newer) runs only on perl 5.10.0 and newer.
	#
        # Geo::Proj4 1.11 increased perl minimum version to 5.10.0 (and is now deprecated anyway).
	cpanm --quiet --notest DBD::XBase~"==0.234" File::Path DB_File~"!=1.833" Pegex~"==0.61" Inline::C~"==0.76" Geo::Proj4~"==1.09"
    fi
    if [ ! "$USE_SYSTEM_PERL" = "1" ]
    then
        case "$PERLBREW_PERL" in
	    5.8|5.10|5.12|5.14|5.16|5.18)
		# Object::Iterate 1.143 runs only with perl 5.20+
		cpanm --quiet --notest Object::Iterate~"<1.143"
		;;
	esac
    fi
}

install_webserver_dependencies() {
    if [ "$USE_MODPERL" = "1" ]
    then
	# install mod_perl
	# probably valid also for all newer debians and ubuntus after jessie
	if [ "$CODENAME" = "stretch" -o "$CODENAME" = "buster" -o "$CODENAME" = "xenial" -o "$CODENAME" = "bionic" -o "$CODENAME" = "focal" -o "$CODENAME" = "jammy" -o "$CODENAME" = "bullseye" ]
	then
	    sudo apt-get install -y $apt_quiet --no-install-recommends apache2
	else
	    sudo apt-get install -y $apt_quiet --no-install-recommends apache2-mpm-prefork
	fi
	# XXX trying to workaround frequent internal server errors
	#sudo a2dismod cgid && sudo a2dismod mpm_event && sudo a2enmod mpm_prefork && sudo a2enmod cgi
	sudo a2dismod mpm_event && sudo a2enmod mpm_prefork
	# Installation of modperl will trigger a restart, so no separate one needed
	if [ "$USE_SYSTEM_PERL" = "1" ]
	then
	    sudo apt-get install -y $apt_quiet --no-install-recommends libapache2-mod-perl2 libapache2-reload-perl
	else
	    if [ "$CODENAME" = "trusty" -o "$CODENAME" = "precise" ]
	    then
		sudo apt-get install -y $apt_quiet --no-install-recommends apache2-prefork-dev
	    else
		sudo apt-get install -y $apt_quiet --no-install-recommends apache2-dev
	    fi
	    cpanm --quiet --notest mod_perl2 --configure-args="MP_APXS=/usr/bin/apxs2 MP_AP_DESTDIR=$PERLBREW_ROOT/perls/$PERLBREW_PERL/"
	    sudo sh -c "echo LoadModule perl_module $PERLBREW_ROOT/perls/$PERLBREW_PERL/usr/lib/apache2/modules/mod_perl.so > /etc/apache2/mods-enabled/perl.load"
	fi
    else
	if [ "$USE_SYSTEM_PERL" = "1" ]
	then
	    sudo apt-get install -y $apt_quiet --no-install-recommends starman libcgi-emulate-psgi-perl libcgi-compile-perl libplack-middleware-rewrite-perl
	# else: plack dependencies are already handled in Makefile.PL's PREREQ_PM
	fi
    fi
}

######################################################################
# Functions for the install phase:
install_perl_dependencies() {
    if [ "$USE_SYSTEM_PERL" = "1" ]
    then
	if [ "$CODENAME" = "precise" -o "$CODENAME" = "trusty" ]
	then
	    libinline_c_perl_package=
	else
	    # jessie and later
	    libinline_c_perl_package=libinline-c-perl
	fi
	sudo apt-get install -y $apt_quiet --no-install-recommends libapache-session-counted-perl libarchive-zip-perl libgd-gd2-perl libsvg-perl libobject-realize-later-perl libdb-file-lock-perl libpdf-create-perl libtext-csv-xs-perl libdbi-perl libdate-calc-perl libobject-iterate-perl libgeo-metar-perl libgeo-spacemanager-perl libimage-exiftool-perl libdbd-xbase-perl libxml-libxml-perl libxml2-utils libxml-twig-perl libxml-simple-perl libgeo-distance-xs-perl libimage-info-perl libinline-perl $libinline_c_perl_package libtemplate-perl libyaml-libyaml-perl libclass-accessor-perl libdatetime-perl libstring-approx-perl libtext-unidecode-perl libipc-run-perl libjson-xs-perl libcairo-perl libpango-perl libmime-lite-perl libcdb-file-perl libmldbm-perl libpalm-palmdoc-perl libimager-qrcode-perl libtie-ixhash-perl libwww-mechanize-perl libhtml-format-perl libhtml-form-perl libwww-perl liblwp-protocol-https-perl
	if [ "$CODENAME" = "precise" ]
	then
	    # upgrade Archive::Zip (precise comes with 1.30) because
	    # of mysterious problems with cgi-download.t
	    cpanm --sudo --quiet --notest Archive::Zip
	fi
	if [ "$BBBIKE_TEST_GUI" = "1" ]
	then
	    sudo apt-get install -y $apt_quiet --no-install-recommends perl-tk
	fi
    else
	# XXX Tk::ExecuteCommand does not specify Tk as a prereq,
	# so make sure to install Tk early. See
	# https://rt.cpan.org/Ticket/Display.html?id=102434
	cpanm --quiet --notest Tk

	# Upgrade CGI.pm to avoid "CGI will be removed from the Perl core distribution" warnings
	case "$PERLBREW_PERL" in
	    5.20*)
		cpanm --quiet --notest CGI
		;;
	esac

	# Geo::Distance 0.21 and 0.22 calculates wrong
	# distances (this is causing strassen-util.t to fail).
	# https://github.com/bluefeet/Geo-Distance/issues/15
	cpanm --quiet --notest 'Geo::Distance~!=0.21,!=0.22'

	# Geo::Distance::XS is not available anymore on CPAN
	# and must now be installed by specifying an exact version
	cpanm --quiet --notest 'Geo::Distance::XS@0.13'

	# Geo::Proj4 does not compile anymore with newer proj4 versions
	# https://rt.cpan.org/Ticket/Display.html?id=129389
	if [ "$CODENAME" = "focal" -o "$CODENAME" = "jammy" -o "$CODENAME" = "bullseye" ]
	then
	    cpanm --quiet --notest Alien::Base::Wrapper Alien::Proj4
	    cpanm --quiet https://github.com/eserte/perl5-Geo-Proj4.git@use-alien
	fi

	if [ "$CPAN_INSTALLER" = "cpanm" ]
	then
	    cpanm --quiet --installdeps --notest .
	else
	    # install cpm; and install also https support for LWP because of
	    # https://github.com/miyagawa/cpanminus/issues/519
	    #
	    # 0.293 needed for
	    # * better diagnostics
	    # * https://github.com/skaji/cpm/issues/42 (optional core modules)
	    #
	    # In the process EUMM would be upgraded, but the current latest stable
	    # is broken (see https://rt.cpan.org/Ticket/Display.html?id=121924), so
	    # use another one.
	    #
	    # PERL_CPM_OPT can be defined, for example to set --sudo if needed
	    cpanm --quiet --notest 'ExtUtils::MakeMaker~!=7.26' 'App::cpm~>=0.293' LWP::Protocol::https
	    perl Makefile.PL
	    mymeta-cpanfile > cpanfile~ && mv cpanfile~ cpanfile
	    # implement suggestion for more diagnostics in case of failures
	    # https://github.com/skaji/cpm/issues/51#issuecomment-261754382
	    if ! cpm $PERL_CPM_OPT install -g -v; then cat ~/.perl-cpm/build.log; false; fi
	    rm cpanfile
	fi
    fi
}

######################################################################
# Functions for the before-script phase:

init_cgi_config() {
    if [ "$BBBIKE_TEST_SKIP_MAPSERVER" = "1" ]
    then
	(cd cgi && ln -snf bbbike-debian-no-mapserver.cgi.config bbbike.cgi.config)
    else
	(cd cgi && ln -snf bbbike-debian.cgi.config bbbike.cgi.config)
	## Additional Mapserver config+data stuff required
	# Makefile needed by mapserver/brb/Makefile
	perl Makefile.PL
	# -j does not work here
	(cd data && $(perl -I.. -MBBBikeBuildUtil=get_pmake -e 'print get_pmake') mapfiles)
	# -j not tested here
	(cd mapserver/brb && touch -t 197001010000 Makefile.local.inc && $(perl -I../.. -MBBBikeBuildUtil=get_pmake -e 'print get_pmake'))
    fi
    (cd cgi && ln -snf bbbike2-travis.cgi.config bbbike2.cgi.config)
}

fix_cgis() {
    (cd cgi && make symlinks fix-permissions)
    if [ "$USE_SYSTEM_PERL" = "" ]
    then
	(cd cgi && make fixin-shebangs)
    fi
}

init_webserver_config() {
    if [ "$USE_MODPERL" = "1" ]
    then
	chmod 755 $HOME
	(cd cgi && make httpd.conf)
	if [ ! -e /etc/apache2/sites-available/bbbike.conf -a ! -h /etc/apache2/sites-available/bbbike.conf ]
	then
	    sudo ln -s $TRAVIS_BUILD_DIR/cgi/httpd.conf /etc/apache2/sites-available/bbbike.conf
	fi
	sudo a2ensite bbbike.conf
	if [ "$CODENAME" != "precise" ]
	then
	    sudo a2enmod remoteip
	fi
	sudo a2enmod headers cgi
    fi
}

start_webserver() {
    if [ "$USE_MODPERL" = "1" ]
    then
	sudo service apache2 restart
	sudo chmod 755 /var/log/apache2
	sudo chmod 644 /var/log/apache2/*.log
    else
	sudo -E $(which plackup) --server=Starman --user=$(id -u) --group=$(id -g) --env=test --port=80 cgi/bbbike.psgi &
    fi
}

init_webserver_environment() {
    (sleep 5; lwp-request -m GET "http://localhost/bbbike/cgi/bbbike.cgi?init_environment=1" || \
	(grep --with-filename . /etc/apache2/sites-enabled/*; false)
    )
}

start_xserver() {
    export DISPLAY=:123
    Xvfb $DISPLAY &
    (sleep 10; fvwm) &
}

init_data() {
    (cd data && $(perl -I.. -MBBBikeBuildUtil=get_pmake -e 'print get_pmake') -j4 live-deployment-targets)
}

install_selenium() {
    if [ "$BBBIKE_TEST_WITH_SELENIUM" = "1" ]
    then
	# download selenium
	wget -O /tmp/selenium-server-standalone-2.53.1.jar https://selenium-release.storage.googleapis.com/2.53/selenium-server-standalone-2.53.1.jar

	# firefox package
	if [ "$CODENAME" = "jessie" -o "$CODENAME" = "stretch" ]
	then
	    apt_packages=firefox-esr
	else
	    apt_packages=firefox
	fi

	# java package (if not yet installed)
	if ! which java >/dev/null 2>&1
	then
	    if [ "$CODENAME" = "precise" -o "$CODENAME" = "trusty" -o "$CODENAME" = "jessie" ]
	    then
		apt_packages+=" openjdk-7-jre-headless"
	    elif [ "$CODENAME" = "stretch" ]
	    then
	        apt_packages+=" openjdk-8-jre-headless"
	    else
	        apt_packages+=" openjdk-11-jre-headless"
	    fi
	fi

	# Test::WWW::Selenium
	if [ "$USE_SYSTEM_PERL" = "1" ]
	   apt_packages+=" libtest-www-selenium-perl"
	then
	    cpanm --quiet --notest Test::WWW::Selenium
	fi

	# outstanding installs
	sudo apt-get install -y $apt_quiet --no-install-recommends $apt_packages

    fi
}

start_selenium() {
    if [ "$BBBIKE_TEST_WITH_SELENIUM" = "1" ]
    then
	MOZ_HEADLESS=1 java -jar /tmp/selenium-server-standalone-2.53.1.jar &
    fi
}

######################################################################
# Functions for the after_script phase:

used_config() {
    cat <<EOF
======================================================================
USED CONFIG
======================================================================
CODENAME:                   $CODENAME
USE_SYSTEM_PERL:            $USE_SYSTEM_PERL
USE_BBBIKE_PPA:             $USE_BBBIKE_PPA
USE_MODPERL:                $USE_MODPERL
CPAN_INSTALLER:             $CPAN_INSTALLER
PERL_CPANM_OPT:             $PERL_CPANM_OPT
BBBIKE_LONG_TESTS:          $BBBIKE_LONG_TESTS
BBBIKE_TEST_GUI:            $BBBIKE_TEST_GUI
BBBIKE_TEST_SKIP_MODPERL:   $BBBIKE_TEST_SKIP_MODPERL
BBBIKE_TEST_SKIP_MAPSERVER: $BBBIKE_TEST_SKIP_MAPSERVER
BBBIKE_TEST_WITH_SELENIUM:  $BBBIKE_TEST_WITH_SELENIUM
BBBIKE_TEST_NO_NETWORK:     $BBBIKE_TEST_NO_NETWORK
BBBIKE_TEST_NO_CGI_TESTS:   $BBBIKE_TEST_NO_CGI_TESTS
======================================================================
EOF
}

######################################################################
