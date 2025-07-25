.CURDIR?=	${CURDIR}
CGI_SCRIPTS=		bbbike.cgi bbbike.en.cgi bbbikegooglemap.cgi bbbikeleaflet.cgi bbbikeleaflet.en.cgi \
			mapserver_address.cgi mapserver_comment.cgi mapserver_setcoord.cgi \
			wapbbbike.cgi bbbiketile.cgi bbbike-data.cgi bbbike-snapshot.cgi \
			upload-track.cgi qrcode.cgi
DEVEL_CGI_SCRIPTS=	bbbike2.cgi bbbike2.en.cgi bbbikegooglemap2.cgi bbbike-test.cgi bbbike-test.en.cgi bbbike2-test.cgi bbbike-osm.cgi
ROOT_URL?=		/bbbike
# Set this to "cgi" or "ModPerl::Registry" or "Apache::Registry"
# NOTE: currently everything else than "cgi" is not recommended and
#       unlikely to run stable.
CGI_TYPE?=		cgi
USE_PLACK_MODPERL=	$(shell perl -le 'print eval { require Plack::Handler::Apache2; 1 } ? 1 : 0')
LOCATION_STYLE?=	bbbike
REALPATH_CMD=		perl -MCwd=realpath -le 'print realpath shift'
ifndef ROOT_DIR
ROOT_DIR=		$(shell $(REALPATH_CMD) ..)
endif
HTTPD_CONF?=		httpd.conf
ifndef APACHE_VERSION
APACHE_VERSION=	$(shell perl -e '$$apache = $$^O eq "freebsd" ? "httpd" : "apache2"; if (qx{$$apache -v} =~ m{Apache/(\d+\.\d+)}) { print $$1 } else { print "???" }')
endif
# May be set to 0 if the "HttpProtocolOptions Unsafe" setting is done in a different Apache config file.
ALLOW_UNSAFE_HTTP?=	1

all:	rights symlinks
	@echo "You may run $(MAKE) httpd.conf to create a default apache configuration for inclusion"

symlinks:
	[ -e bbbike.en.cgi   ] || ln -s bbbike.cgi bbbike.en.cgi
	[ -e bbbike2.cgi     ] || ln -s bbbike.cgi bbbike2.cgi
	[ -e bbbike2.en.cgi  ] || ln -s bbbike.cgi bbbike2.en.cgi
	[ -e bbbike-test.cgi ] || ln -s bbbike.cgi bbbike-test.cgi
	[ -e bbbike-test.en.cgi ] || ln -s bbbike.cgi bbbike-test.en.cgi
	[ -e bbbike2-test.cgi ] || ln -s bbbike.cgi bbbike2-test.cgi
	[ -e bbbikeleaflet.en.cgi ] || ln -s bbbikeleaflet.cgi bbbikeleaflet.en.cgi
	[ -e bbbikegooglemap2.cgi ] || ln -s bbbikegooglemap.cgi bbbikegooglemap2.cgi

biokovo.conf:
	$(MAKE) \
		ROOT_DIR=/home/e/eserte/src/bbbike \
		CGI_TYPE=Apache::Registry \
	    httpd.conf

# Create a httpd.conf suitable for inclusion in apache2
#
# Per default a virtualhost-less entry is created, which may be included
# into an existing site configuration:
#
#    make httpd.conf
#
# To use a virtualhost, maybe together with some aliases, use
# something like this:
#
#    make httpd.conf VIRTUAL_HOST=localhost SERVER_ALIAS="myhost myhost.mydomain"
#
# The created file is usually symlinked into a sites-enabled or sites-available
# directory --- please see the instructions after running the make command.
# 
# In all cases, bbbike is accessible using http://$HOSTNAME/bbbike
$(HTTPD_CONF): httpd.conf.tpl Makefile
	@[ -e bbbike2.cgi ] || echo 'Please run "make symlinks" first, or create a symlink to bbbike2.cgi manually'
	tpage --define ROOT_URL=$(ROOT_URL) \
	      --define ROOT_DIR=$(ROOT_DIR) \
	      --define CGI_SCRIPTS="$(CGI_SCRIPTS)" \
	      --define DEVEL_CGI_SCRIPTS="$(DEVEL_CGI_SCRIPTS)" \
	      --define CGI_TYPE="$(CGI_TYPE)" \
	      --define USE_PLACK_MODPERL="$(USE_PLACK_MODPERL)" \
	      --define USE_PLACK_PROXY="$(USE_PLACK_PROXY)" \
	      --define PLACK_PORT="$(PLACK_PORT)" \
	      --define LOCATION_STYLE="$(LOCATION_STYLE)" \
	      --define OS_STYLE="$(OS_STYLE)" \
	      --define FS_STYLE="$(FS_STYLE)" \
	      --define APACHE_VERSION="$(APACHE_VERSION)" \
	      --define VIRTUAL_HOST="$(VIRTUAL_HOST)" \
	      --define SERVER_ALIAS="$(SERVER_ALIAS)" \
	      --define ALLOW_UNSAFE_HTTP=$(ALLOW_UNSAFE_HTTP) \
	      --define SERVER_ADMIN=$(SERVER_ADMIN) \
	      httpd.conf.tpl > $(HTTPD_CONF)~
	chmod 644 $(HTTPD_CONF)~
	mv $(HTTPD_CONF)~ $(HTTPD_CONF)
	@echo
	@echo "**********************************************************************"
	@echo "* CONFIGURATION INSTRUCTIONS"
	@echo "*"
	@if [ -d /usr/local/etc/apache22/Includes ] ; \
	then \
	    echo Please either create a symlink; \
	    echo; \
	    echo "    ln -s `$(REALPATH_CMD) $(HTTPD_CONF)` /usr/local/etc/apache22/Includes/bbbike.conf"; \
	    echo; \
	    echo or add the following command to a suitable site configuration file:; \
	    echo; \
	    echo "    Include `$(REALPATH_CMD) $(HTTPD_CONF)`"; \
	    echo; \
	    echo "and restart or reload the Apache."; \
	elif [ -d /etc/apache2/sites-enabled ] ; \
	then \
	    echo Please either create a symlink; \
	    echo; \
	    echo "    ln -s `$(REALPATH_CMD) $(HTTPD_CONF)` /etc/apache2/sites-enabled/bbbike.conf"; \
	    echo; \
	    echo or add the following command to a suitable site configuration file:; \
	    echo; \
	    echo "    Include `$(REALPATH_CMD) $(HTTPD_CONF)`"; \
	    echo; \
	    echo "and restart or reload the Apache."; \
	else \
	    echo Please add the following command to your Apache\'s httpd.conf:; \
	    echo; \
	    echo "    Include `$(REALPATH_CMD) $(HTTPD_CONF)`"; \
	    echo; \
	    echo "and restart or reload the Apache."; \
	fi
	@echo

# Create a stub suitable for VirtualHost operation --- missing are the
# VirtualHost element itself, the ServerName/ServerAlias/ServerAdmin
# definitions. Need to be called with OS_STYLE,
# or maybe also with FS_STYLE and ROOT_DIR:
#
#    make vhost-httpd.conf OS_STYLE=freebsd
#    make vhost-httpd.conf OS_STYLE=debian ROOT_DIR=/srv/www/bbbike-webserver FS_STYLE=live
#
.PHONY: vhost-httpd.conf
vhost-httpd.conf:
	${MAKE} /tmp/bbbike-like-live.conf HTTPD_CONF=/tmp/bbbike-like-live.conf LOCATION_STYLE=vhost

alt-httpd.conf:	httpd.conf.st
	@perl -I../lib -MText::ScriptTemplate -MCwd -MFile::Spec -e '$$st=Text::ScriptTemplate->new;$$st->load("httpd.conf.st"); chdir ".." or die; $$st->setq(rootdir=>File::Spec->rel2abs(getcwd));print $$st->fill'

GNUmakefile:	Makefile ../miscsrc/b2gmake
	../miscsrc/b2gmake < Makefile > GNUmakefile~
	mv GNUmakefile~ GNUmakefile
	chmod ugo+r GNUmakefile

permissions: rights
fix-permissions: rights

rights:
	chmod ugo+rx *.cgi
	chmod ugo+r *.cgi.config
	[ ! -e ../tmp/www ] || chmod 777 ../tmp/www
	chmod ugo-x *.psgi

# Assuming all .cgi files are perl
fixin-shebangs:
	for i in ${CGI_SCRIPTS} ${DEVEL_CGI_SCRIPTS}; do \
	    export PERL=`which perl`; \
	    if [ -f $$i -a ! -L $$i ] ; then \
		perl -pi -e 'print "#!$$ENV{PERL}\n" if $$. == 1' -- $$i; \
	    fi \
	done
