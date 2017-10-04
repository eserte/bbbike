# Please source this file:
#
#    . .../bbbike/port/travis-ci/travis-functions.sh
#

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
    export BBBIKE_LONG_TESTS=1 BBBIKE_TEST_SKIP_MAPSERVER=1
    # The default www.cpan.org may not be the fastest one, and may
    # even cause problems if an IPv6 address is chosen...
    export PERL_CPANM_OPT="--mirror https://cpan.metacpan.org --mirror http://cpan.cpantesters.org"
}

init_perl() {
    if [ "$USE_SYSTEM_PERL" = "1" ]
    then
        perlbrew off
    fi
}

init_apt() {
    if [ "$USE_SYSTEM_PERL" = "1" ]
    then
	if [ ! -e /etc/apt/sources.list.d/mydebs.bbbike.list ]
	then
	    CODENAME=$(lsb_release -c -s)
	    wget -O- http://mydebs.bbbike.de/key/mydebs.bbbike.key | sudo apt-key add -
	    sudo sh -c "echo deb http://mydebs.bbbike.de ${CODENAME} main > /etc/apt/sources.list.d/mydebs.bbbike.list~"
	    sudo mv /etc/apt/sources.list.d/mydebs.bbbike.list~ /etc/apt/sources.list.d/mydebs.bbbike.list
	fi
    fi
    sudo apt-get update -qq
}

# Reasons for the following dependencies
# - freebsd-buildutils:     provides freebsd-make resp. fmake
# - libproj-dev + proj-bin: prerequisites for Geo::Proj4
# - libdb-dev:              prerequisite for DB_File
# - agrep + tre-agrep:      needed as String::Approx alternative
# - libgd2-xpm-dev:         prerequisite for GD
# - ttf-bitstream-vera + ttf-dejavu: fonts e.g. for BBBikeDraw::GD
# - xvfb + fvwm:            some optional tests require an X server
# - libmozjs-24-bin or rhino: javascript tests
# - imagemagick:            typ2legend test
# - libpango1.0-dev:        prerequisite for Pango
# - libxml2-utils:          xmllint
# - libzbar-dev:            prerequisite for Barcode::ZBar
# - pdftk:                  compression in BBBikeDraw::PDFUtil (for non-cairo)
# - poppler-utils:          provides pdfinfo for testing
install_non_perl_dependencies() {
    if [ "$(lsb_release -c -s)" = "precise" ]
    then
	javascript_package=rhino
    else
	javascript_package=libmozjs-24-bin
    fi
    sudo apt-get install -qq freebsd-buildutils libproj-dev proj-bin libdb-dev agrep tre-agrep libgd2-xpm-dev ttf-bitstream-vera ttf-dejavu gpsbabel xvfb fvwm $javascript_package imagemagick libpango1.0-dev libxml2-utils libzbar-dev pdftk poppler-utils
}

# Some CPAN modules not mentioned in Makefile.PL, usually for testing only
install_perl_testonly_dependencies() {
    if [ "$USE_SYSTEM_PERL" = "1" ]
    then
	sudo apt-get install -qq libemail-mime-perl libhtml-treebuilder-xpath-perl libbarcode-zbar-perl
    else
	cpanm --quiet --notest Email::MIME HTML::TreeBuilder::XPath Barcode::ZBar
    fi
}

# perl 5.8 specialities
install_perl_58_dependencies() {
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
	#cpanm --quiet --notest DBD::XBase~"==0.234" File::Path DB_File~"!=1.833" Pegex~"==0.61" Inline::C~"==0.76"
	# XXX Currently it's not possible to fetch old backpan versions
        # XXX with cpanm using the version number. See
        # XXX https://github.com/miyagawa/cpanminus/issues/538
	cpanm --quiet --notest http://backpan.perl.org/authors/id/J/JA/JANPAZ/DBD-XBase-0.234.tar.gz File::Path DB_File~"!=1.833" Pegex~"==0.61" Inline::C~"==0.76"
    fi
}

install_cpan_hacks() {
    if [ ! "$USE_SYSTEM_PERL" = "1" ]
    then
	# -> Currently empty, no hacks required. Was:
	## Tk + EUMM 7.00 problems, use the current development version (https://rt.cpan.org/Ticket/Display.html?id=100044)
	#cpanm --quiet --notest SREZIC/Tk-804.032_501.tar.gz
	## And this is for linux sh/bash braindeadness (empty then not allowed, it seems):
	:
    fi
}

install_webserver_dependencies() {
    if [ "$USE_MODPERL" = "1" ]
    then
	# install mod_perl
	sudo apt-get install -qq apache2-mpm-prefork
	if [ "$USE_SYSTEM_PERL" = "1" ]
	then
	    sudo apt-get install -qq libapache2-mod-perl2
	else
	    sudo apt-get install -qq apache2-prefork-dev
	    cpanm --quiet --notest mod_perl2 --configure-args="MP_APXS=/usr/bin/apxs2 MP_AP_DESTDIR=$PERLBREW_ROOT/perls/$PERLBREW_PERL/"
	    sudo sh -c "echo LoadModule perl_module $PERLBREW_ROOT/perls/$PERLBREW_PERL/usr/lib/apache2/modules/mod_perl.so > /etc/apache2/mods-enabled/perl.load"
	fi
    fi
    # plack dependencies are already handled in Makefile.PL's PREREQ_PM
}

######################################################################
# Functions for the install phase:
install_perl_dependencies() {
    if [ "$USE_SYSTEM_PERL" = "1" ]
    then
	sudo apt-get install -qq libapache-session-counted-perl libarchive-zip-perl libgd-gd2-perl libsvg-perl libobject-realize-later-perl libdb-file-lock-perl libpdf-create-perl libtext-csv-xs-perl libdbi-perl libdate-calc-perl libobject-iterate-perl libgeo-metar-perl libimage-exiftool-perl libdbd-xbase-perl libxml-libxml-perl libxml2-utils libxml-twig-perl libxml-simple-perl libgeo-distance-xs-perl libimage-info-perl libinline-perl libtemplate-perl libyaml-libyaml-perl libclass-accessor-perl libdatetime-perl libstring-approx-perl libtext-unidecode-perl libipc-run-perl libjson-xs-perl libcairo-perl libpango-perl libmime-lite-perl libcdb-file-perl libmldbm-perl libpalm-palmdoc-perl libimager-qrcode-perl
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
	    cpanm --quiet --notest 'ExtUtils::MakeMaker~!=7.26' 'App::cpm~>=0.293' LWP::Protocol::https
	    perl Makefile.PL
	    mymeta-cpanfile > cpanfile~ && mv cpanfile~ cpanfile
	    # implement suggestion for more diagnostics in case of failures
	    # https://github.com/skaji/cpm/issues/51#issuecomment-261754382
	    if ! cpm install -g -v; then cat ~/.perl-cpm/build.log; false; fi
	fi
    fi
}

######################################################################
# Functions for the before-script phase:

init_cgi_config() {
    (cd cgi && ln -snf bbbike-debian-no-mapserver.cgi.config bbbike.cgi.config)
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
	if "$(lsb_release -c -s)" != "precise"
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

######################################################################
