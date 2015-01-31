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
# - agrep:                  needed as String::Approx alternative
# - libgd2-xpm-dev:         prerequisite for GD
# - ttf-bitstream-vera + ttf-dejavu: fonts e.g. for BBBikeDraw::GD
# - xvfb + twm:             some optional tests require an X server
# - rhino:                  javascript tests
# - imagemagick:            typ2legend test
install_non_perl_dependencies() {
    sudo apt-get install -qq freebsd-buildutils libproj-dev proj-bin libdb-dev agrep libgd2-xpm-dev ttf-bitstream-vera ttf-dejavu gpsbabel xvfb twm rhino imagemagick
}

# Some CPAN modules not mentioned in Makefile.PL, usually for testing only
install_perl_testonly_dependencies() {
    if [ "$USE_SYSTEM_PERL" = "1" ]
    then
	sudo apt-get install -qq libemail-mime-perl libhtml-treebuilder-xpath-perl
    else
	cpanm --quiet --notest Email::MIME HTML::TreeBuilder::XPath
    fi
}

# perl 5.8 specialities
install_perl_58_dependencies() {
    if [ "$PERLBREW_PERL" = "5.8" -a ! "$USE_SYSTEM_PERL" = "1" ]
    then
	# DBD::XBase versions between 1.00..1.05 explicitely want Perl 5.10.0 as a minimum. See https://rt.cpan.org/Ticket/Display.html?id=88873
	cpanm --quiet --notest DBD::XBase~"!=1.00, !=1.01, !=1.02, !=1.03, !=1.04, !=1.05"
	# Perl 5.8.9's File::Path has a version with underscores, and this is causing warnings and failures in the test suite
	cpanm --quiet --notest File::Path
	# Wrong version specification in DB_File's Makefile.PL, see https://rt.cpan.org/Ticket/Display.html?id=100844
	cpanm --quiet --notest DB_File~"!=1.833"
    fi
}

install_cpan_hacks() {
    if [ ! "$USE_SYSTEM_PERL" = "1" ]
    then
	# Tk + EUMM 7.00 problems, use the current development version (https://rt.cpan.org/Ticket/Display.html?id=100044)
	cpanm --quiet --notest SREZIC/Tk-804.032_501.tar.gz
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
	sudo apt-get install -qq libapache-session-counted-perl libarchive-zip-perl libgd-gd2-perl libsvg-perl libobject-realize-later-perl libdb-file-lock-perl libpdf-create-perl libtext-csv-xs-perl libdbi-perl libdate-calc-perl libobject-iterate-perl libgeo-metar-perl libimage-exiftool-perl libdbd-xbase-perl libxml-libxml-perl libxml-twig-perl libgeo-distance-xs-perl libimage-info-perl libinline-perl libtemplate-perl libyaml-libyaml-perl libclass-accessor-perl libdatetime-perl libstring-approx-perl libtext-unidecode-perl libipc-run-perl libjson-xs-perl libcairo-perl libpango-perl libmime-lite-perl libpalm-palmdoc-perl libcdb-file-perl libmldbm-perl
    else
	cpanm --quiet --installdeps --notest .
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
	(cd cgi && make httpd.conf)
	if [ ! -e /etc/apache2/sites-available/bbbike.conf -a ! -h /etc/apache2/sites-available/bbbike.conf ]
	then
	    sudo ln -s $TRAVIS_BUILD_DIR/cgi/httpd.conf /etc/apache2/sites-available/bbbike.conf
	fi
	sudo a2ensite bbbike.conf
	sudo a2enmod headers
    fi
}

start_webserver() {
    if [ "$USE_MODPERL" = "1" ]
    then
	sudo service apache2 restart
    else
	sudo -E $(which plackup) --server=Starman --user=$(id -u) --group=$(id -g) --env=test --port=80 cgi/bbbike.psgi &
    fi
}

init_webserver_environment() {
    (sleep 5; lwp-request -m GET "http://localhost/bbbike/cgi/bbbike.cgi?init_environment=1")
}

start_xserver() {
    export DISPLAY=:123
    Xvfb $DISPLAY &
    (sleep 10; twm) &
}

init_data() {
    (cd data && $(perl -I.. -MBBBikeBuildUtil=get_pmake -e 'print get_pmake') -j4 live-deployment-targets)
}

######################################################################
