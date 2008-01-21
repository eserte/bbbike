CGI_SCRIPTS=	bbbike.cgi bbbikegooglemap.cgi mapserver_address.cgi mapserver_comment.cgi mapserver_setcoord.cgi wapbbbike.cgi
ROOT_URL?=	/bbbike
# Set this to "cgi" or "Apache::Registry"
CGI_TYPE?=	cgi
ROOT_DIR!=	perl -MFindBin='$$RealBin' -MCwd=cwd -le 'chdir("$$RealBin/..") or die; print cwd'

all:	httpd.conf rights

httpd.conf: httpd.conf.tpl Makefile
	tpage --define ROOT_URL=$(ROOT_URL) \
	      --define ROOT_DIR=$(ROOT_DIR) \
	      --define CGI_SCRIPTS="$(CGI_SCRIPTS)" \
	      --define CGI_TYPE="$(CGI_TYPE)" \
	      httpd.conf.tpl > httpd.conf
	chmod 644 httpd.conf
	@echo
	@echo Please add
	@echo "    Include ${.CURDIR}/httpd.conf"
	@echo to your Apache\'s httpd.conf
	@echo

alt-httpd.conf:	httpd.conf.st
	@perl -I../lib -MText::ScriptTemplate -MCwd -MFile::Spec -e '$$st=Text::ScriptTemplate->new;$$st->load("httpd.conf.st"); chdir ".." or die; $$st->setq(rootdir=>File::Spec->rel2abs(cwd));print $$st->fill'

GNUmakefile:	Makefile ../miscsrc/b2gmake
	../miscsrc/b2gmake < Makefile > GNUmakefile
	chmod ugo+r GNUmakefile

rights:
	chmod ugo+rx *.cgi
	chmod ugo+r,ugo-x *.cgi.config
