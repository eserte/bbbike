CGI_SCRIPTS=	bbbike.cgi mapserver_address.cgi mapserver_comment.cgi wapbbbike.cgi
ROOT_URL?=	/bbbike
# Set this to "cgi" or "Apache::Registry"
CGI_TYPE?=	cgi
# BSD MAKE
# XXX better to use CURDIR with substitution:
ROOT_DIR!=	perl -MFindBin=$$RealBin -MCwd=cwd -le 'chdir("$RealBin/..") or die; print cwd'
# GNU MAKE
#.CURDIR?=	${CURDIR}
#ROOT_DIR=	$(shell perl -MFindBin -MCwd -le 'chdir("$$FindBin::RealBin/..") or die; print cwd')
# ALL MAKE

all:

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

GNUmakefile:	Makefile
	perl -nle 'if (/^# GNU MAKE/) { $$stage = "gnu" } elsif (/^# BSD MAKE/) { $$stage = "bsd" } elsif (/^# ALL MAKE/) { undef $$stage } elsif ($$stage eq "gnu") { s/^#//; } elsif ($$stage eq "bsd") { s/^/#/; } print' Makefile > GNUmakefile

