CGI_SCRIPTS=	bbbike.cgi mapserver_address.cgi mapserver_comment.cgi wapbbbike.cgi
ROOT_URL?=	/bbbike
#ROOT_DIR!=	perl -MFindBin=RealBin -MCwd=cwd -le 'chdir("$RealBin/..") or die; print cwd'
# XXX use CURDIR with subst on BSD make
ROOT_DIR=	$(shell perl -MFindBin -MCwd -le 'chdir("$$FindBin::RealBin/..") or die; print cwd')
.CURDIR=	$(shell pwd)

all:

httpd.conf: httpd.conf.tpl Makefile
	tpage --define ROOT_URL=$(ROOT_URL) \
	      --define ROOT_DIR=$(ROOT_DIR) \
	      --define CGI_SCRIPTS="$(CGI_SCRIPTS)" \
	      httpd.conf.tpl > httpd.conf
	chmod 644 httpd.conf
	@echo
	@echo Please add
	@echo "    Include ${.CURDIR}/httpd.conf"
	@echo to your Apache\'s httpd.conf
