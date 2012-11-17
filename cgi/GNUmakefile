.CURDIR?=	${CURDIR}
CGI_SCRIPTS=		bbbike.cgi bbbike.en.cgi bbbikegooglemap.cgi bbbikeleaflet.cgi bbbikeleaflet.en.cgi \
			mapserver_address.cgi mapserver_comment.cgi mapserver_setcoord.cgi \
			wapbbbike.cgi bbbiketile.cgi bbbike-data.cgi bbbike-snapshot.cgi
DEVEL_CGI_SCRIPTS=	bbbike2.cgi bbbike2.en.cgi bbbikegooglemap2.cgi bbbike-test.cgi bbbike-test.en.cgi bbbike-osm.cgi
ROOT_URL?=		/bbbike
# Set this to "cgi" or "ModPerl::Registry" or "Apache::Registry"
# NOTE: currently everything else than "cgi" is not recommended and
#       unlikely to run stable.
CGI_TYPE?=		cgi
REALPATH_CMD=		perl -MCwd=realpath -le 'print realpath shift'
ifndef ROOT_DIR
ROOT_DIR=		$(shell $(REALPATH_CMD) ..)
endif
HTTPD_CONF?=		httpd.conf

all:	rights symlinks
	@echo "You may run $(MAKE) httpd.conf to create a default apache configuration for inclusion"

symlinks:
	[ -e bbbike.en.cgi   ] || ln -s bbbike.cgi bbbike.en.cgi
	[ -e bbbike2.cgi     ] || ln -s bbbike.cgi bbbike2.cgi
	[ -e bbbike2.en.cgi  ] || ln -s bbbike.cgi bbbike2.en.cgi
	[ -e bbbike-test.cgi ] || ln -s bbbike.cgi bbbike-test.cgi
	[ -e bbbike-test.en.cgi ] || ln -s bbbike.cgi bbbike-test.en.cgi
	[ -e bbbikeleaflet.en.cgi ] || ln -s bbbikeleaflet.cgi bbbikeleaflet.en.cgi

biokovo.conf:
	$(MAKE) \
		ROOT_DIR=/home/e/eserte/src/bbbike \
		CGI_TYPE=Apache::Registry \
	    httpd.conf

$(HTTPD_CONF): httpd.conf.tpl Makefile
	@[ -e bbbike2.cgi ] || echo 'Please run "make symlinks" first, or create a symlink to bbbike2.cgi manually'
	tpage --define ROOT_URL=$(ROOT_URL) \
	      --define ROOT_DIR=$(ROOT_DIR) \
	      --define CGI_SCRIPTS="$(CGI_SCRIPTS)" \
	      --define DEVEL_CGI_SCRIPTS="$(DEVEL_CGI_SCRIPTS)" \
	      --define CGI_TYPE="$(CGI_TYPE)" \
	      httpd.conf.tpl > $(HTTPD_CONF)~
	chmod 644 $(HTTPD_CONF)~
	mv $(HTTPD_CONF)~ $(HTTPD_CONF)
	@echo
	@echo "**********************************************************************"
	@echo "* CONFIGURATION INSTRUCTIONS"
	@echo "*"
	@if [ -d /usr/local/etc/apache22/Includes ] ; \
	then \
	    echo Please create a symlink; \
	    echo; \
	    echo "    ln -s `$(REALPATH_CMD) $(HTTPD_CONF)` /usr/local/etc/apache22/Includes/bbbike.conf"; \
	    echo; \
	    echo "and restart the Apache."; \
	elif [ -d /etc/apache2/sites-enabled ] ; \
	then \
	    echo Please create a symlink; \
	    echo; \
	    echo "    ln -s `$(REALPATH_CMD) $(HTTPD_CONF)` /etc/apache2/sites-enabled/bbbike.conf"; \
	    echo; \
	    echo "and restart the Apache."; \
	else \
	    echo Please add; \
	    echo; \
	    echo "    Include `$(REALPATH_CMD) $(HTTPD_CONF)`"; \
	    echo; \
	    echo "to your Apache\'s httpd.conf and restart the Apache."; \
	fi
	@echo

alt-httpd.conf:	httpd.conf.st
	@perl -I../lib -MText::ScriptTemplate -MCwd -MFile::Spec -e '$$st=Text::ScriptTemplate->new;$$st->load("httpd.conf.st"); chdir ".." or die; $$st->setq(rootdir=>File::Spec->rel2abs(cwd));print $$st->fill'

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
