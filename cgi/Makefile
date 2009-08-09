CGI_SCRIPTS=		bbbike.cgi bbbikegooglemap.cgi mapserver_address.cgi \
			mapserver_comment.cgi mapserver_setcoord.cgi \
			wapbbbike.cgi bbbiketile.cgi
DEVEL_CGI_SCRIPTS=	bbbike2.cgi bbbikegooglemap2.cgi
ROOT_URL?=		/bbbike
# Set this to "cgi" or "Apache::Registry"
CGI_TYPE?=		cgi
.ifndef ROOT_DIR
ROOT_DIR!=		perl -MFindBin='$$RealBin' -MCwd=realpath -le 'print realpath("$$RealBin/..")'
.endif

all:	rights symlinks
	@echo "You may run $(MAKE) httpd.conf to create a default apache configuration for inclusion"

symlinks:
	[ -e bbbike.en.cgi   ] || ln -s bbbike.cgi  bbbike.en.cgi
	[ -e bbbike2.cgi     ] || ln -s bbbike.cgi  bbbike2.cgi
	[ -e bbbike2.en.cgi  ] || ln -s bbbike2.cgi bbbike2.en.cgi
	[ -e bbbike-test.cgi ] || ln -s bbbike.cgi  bbbike-test.cgi

biokovo.conf:
	$(MAKE) \
		ROOT_DIR=/home/e/eserte/src/bbbike \
		CGI_TYPE=Apache::Registry \
	    httpd.conf

httpd.conf: httpd.conf.tpl Makefile
	tpage --define ROOT_URL=$(ROOT_URL) \
	      --define ROOT_DIR=$(ROOT_DIR) \
	      --define CGI_SCRIPTS="$(CGI_SCRIPTS)" \
	      --define DEVEL_CGI_SCRIPTS="$(DEVEL_CGI_SCRIPTS)" \
	      --define CGI_TYPE="$(CGI_TYPE)" \
	      httpd.conf.tpl > httpd.conf~
	chmod 644 httpd.conf~
	mv httpd.conf~ httpd.conf
	@echo
	@echo Please add
	@echo "    Include ${.CURDIR}/httpd.conf"
	@echo to your Apache\'s httpd.conf
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
	chmod ugo+r,ugo-x *.cgi.config
# The next line is silly, but unfortunately the file is checked into
# the sf CVS without x bit, and this causes problems when using git-cvs
	chmod ugo-x bbbikesoapserver.cgi
	[ ! -e ../tmp/www ] || chmod 777 ../tmp/www
