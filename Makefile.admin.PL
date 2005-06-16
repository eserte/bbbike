# -*- perl -*-

#
# $Id: Makefile.admin.PL,v 1.33 2005/06/16 22:38:25 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

######################################################################
# POD files
#
# grab a good pod2html XXX this is somewhat hacky
my $bbbike_html_rule;
$ENV{PATH} .= ":/usr/local/src/CPAN/new.build/new.MarekPodHtml-0.43/scripts";
my $pod2html = is_in_path("mpod2html");
#if (defined $pod2html) {
#    $pod2html = "$^X -Mblib=/usr/local/src/CPAN/new.build/new.MarekPodHtml-0.43/ $pod2html";
#}
#XXX check new pod2html: undef $pod2html;
#XXX $pod2html = 'perl -Mblib=/usr/local/src/CPAN/new.build/new.MarekPodHtml-0.43 /usr/local/src/CPAN/new.build/new.MarekPodHtml-0.43/blib/script/mpod2html -css html/bbbikepod.css';
my $htmlroot = "--htmlroot http://www.perldoc.com/cpan";

use constant POD_POD   => 0;
use constant POD_HTML  => 1;
use constant POD_TITLE => 2; # XXX do not put double quotes into title
#        podfile         htmlfile             title
my @pods = 
    (
     [qw(bbbike.pod      bbbike.html),        "Dokumentation für BBBike"],
     [qw(README          README.html),        "README für BBBike"],
     [qw(README.english  README.english.html),"README for BBBike"],
     [qw(HOWTO_edit_bbbike_data.pod
			 HOWTO_edit_bbbike_data.html),
					      "HOWTO - Daten in BBBike editieren"],
     [qw(bbd.pod         bbd.html),           "BBD file format"],
     [qw(bbbike_internals.pod      bbbike_internals.html),        "BBBike Internals"],
     );
my $all_pods = join " ", map { $_->[POD_POD] } @pods;
my $all_html = join " ", map { $_->[POD_HTML] } @pods;
if (defined $pod2html) {
    # XXX here no $htmlroot
    $bbbike_html_rule = <<EOF;
$all_html:	$all_pods
	$pod2html -stylesheet html/bbbikepod.css -tocname http://bbbike.sourceforge.net/index -notoc $all_pods
	\$(CLEAN_POD2HTML)
	chmod ugo+r $all_html podindex.html
EOF
} else {
    my $pod2html;
    if (-e "/usr/perl5.8.1/bin/pod2html") {
	$pod2html = "perl5.8.1 /usr/perl5.8.1/bin/pod2html";
    } elsif (-x "/usr/perl5.7.2/bin/pod2html") {
	# XXX --htmlroot with bugs: one level module names are not linked
	$pod2html = "/usr/perl5.7.2/bin/pod2html $htmlroot -css html/bbbikepod.css --header";
    } elsif (-x "/usr/perl5.6.0/bin/pod2html") {
	$pod2html = "/usr/perl5.6.0/bin/pod2html $htmlroot";
    } else {
	$pod2html = "pod2html";
    }
    $bbbike_html_rule = "";
    for my $poddef (@pods) {
	$bbbike_html_rule .= <<EOF
$poddef->[POD_HTML]: $poddef->[POD_POD]
	$pod2html --title "$poddef->[POD_TITLE]" $poddef->[POD_POD] > $poddef->[POD_HTML]
	\$(CLEAN_POD2HTML)

EOF
    }
}

my(@bundled_perl_module_dists) =
    qw(Tk-ContextHelp Tk-Enscript Tk-Getopt Tk-Autoscroll Tk-PathEntry
       Tk-CanvasFig BikePower savevars GD-Convert Tk-Splash
       Http Msg
       Tk-SREZIC Tk-CanvasBalloon Tk-CanvasUtil Tk-LogScale
       Tk-ColorFlowChooser Tk-LayerEditor Tk-Placement
       Tk-StippleLine Tk-WidgetDump Win32Util WWWBrowser
      );
my $EXTMODCPANTOP = "$ENV{HOME}/src/CPAN";
if (!-e $EXTMODCPANTOP) {
    $EXTMODCPANTOP = "$ENV{HOME}/work2";
}
my $EXTMODPERLTOP = "$ENV{HOME}/src/perl";
if (!-e $EXTMODPERLTOP) {
    $EXTMODPERLTOP = "$ENV{HOME}/work2";
}
my(@EXTMODCPAN, @EXTMODPERL);
for my $module_dist (@bundled_perl_module_dists) {
    if (-e "$EXTMODCPANTOP/$module_dist") {
	push @EXTMODCPAN, $module_dist;
    } elsif (-e "$EXTMODPERLTOP/$module_dist") {
	push @EXTMODPERL, $module_dist;
    } else {
	if (defined $ENV{USER} && $ENV{USER} eq 'eserte') {
	    warn "Can't find $module_dist neither in $EXTMODCPANTOP nor in $EXTMODPERLTOP\n";
	}
    }
}
my $EXTMODCPAN = join(" ", @EXTMODCPAN);
my $EXTMODPERL = join(" ", @EXTMODPERL);

$bbbike_makefile_admin = <<'EOF'
#### RSYNCS ###############################################################

BBBIKE_CS_DEST=user.cs.tu-berlin.de:www/bbbike
BBBIKE_CS_TEST_DEST=user.cs.tu-berlin.de:www/BBBike
BBBIKE_SF_DEST=bbbike.sourceforge.net:/home/groups/b/bb/bbbike
BBBIKE_SF_DIR=$(HOME)/www/bbbike.sourceforge.net

BBBIKE_RADZEIT_USER=		root
BBBIKE_RADZEIT_HOST=		www.radzeit.de
BBBIKE_RADZEIT_OLD_APACHE_DIR=	/usr/local/apache/radzeit
BBBIKE_RADZEIT_APACHE_DIR=	/var/www/domains/radzeit.de/www/
BBBIKE_RADZEIT_CGI_DIR=		$(BBBIKE_RADZEIT_APACHE_DIR)/cgi-bin
BBBIKE_RADZEIT_HTDOCS_DIR=      $(BBBIKE_RADZEIT_APACHE_DIR)/public
BBBIKE_RADZEIT_DIR=		$(BBBIKE_RADZEIT_APACHE_DIR)/BBBike
BBBIKE_RADZEIT_DIR2=		$(BBBIKE_RADZEIT_APACHE_DIR)/BBBike2
BBBIKE_RADZEIT_DEST=		$(BBBIKE_RADZEIT_USER)@$(BBBIKE_RADZEIT_HOST):$(BBBIKE_RADZEIT_DIR)
BBBIKE_RADZEIT_DEST2=		$(BBBIKE_RADZEIT_USER)@$(BBBIKE_RADZEIT_HOST):$(BBBIKE_RADZEIT_DIR2)

RSYNC=rsync
RSYNC_DATA_CMD=cd data && \
	    $(RSYNC) --verbose --progress --compress --backup --perms --times \
		--exclude "*~" --exclude "RCS/" --exclude "*.st" \
		--exclude "*-orig" --exclude ".*" --exclude "Makefile*" \
		*
RSYNC_RADZEIT_DATA=cd data_berlin_and_potsdam && $(RSYNC) -Pvzr . $(BBBIKE_RADZEIT_DEST)/data/
RSYNC_RADZEIT_TEST_DATA=cd data_berlin_and_potsdam && $(RSYNC) -Pvzr . $(BBBIKE_RADZEIT_DEST2)/data/

rsync-cs-data:
	$(RSYNC_DATA_CMD) $(BBBIKE_CS_DEST)/data

rsync-cs-test:
	cd $(BBBIKE_TMP)/BBBike && $(RSYNC) -Pvzr . $(BBBIKE_CS_TEST_DEST)/

rsync-sf-data:
	$(RSYNC_DATA_CMD) $(BBBIKE_SF_DEST)/cgi-bin/BBBike/data

######################################################################
#

#rsync-rezic-data:
#	$(RSYNC_DATA_CMD) www.rezic.de:/home/srezic

rsync-sf-all:
	cd $(BBBIKE_SF_DIR) && \
	    env BBBIKE_SRC_DIR=${.CURDIR} \
	        BBBIKE_SF_DEST=$(BBBIKE_SF_DEST) \
	        $(MAKE) update rsync

rsync-vran-spiff-hermes:
	[ "$(HOST)" = "vran.herceg.de" ]
	[ "$(LOGNAME)" = "eserte" ]
	rsync -Pvzrl \
	     --exclude misc/download/ \
	     --exclude i386-linux/ \
	     --exclude i586-linux/ \
	     --exclude i686-linux/ \
	     --exclude i686-linux-64int-ld/ \
	     --cvs-exclude \
	     ${.CURDIR}/ hermes@spiff:/home/hermes/src/bbbike/

######################################################################
#

CVS_DIR=${HOME}/work/bbbike

# XXX create or copy .cvsignore with ext/*/*Dist.pm files
copy-to-cvs:	ask-copy-to-cvs do-copy-to-cvs

ask-copy-to-cvs:
	@echo "Really copy to ${CVS_DIR}? (Hit Ctrl-C otherwise) "
	@read dummy

do-copy-to-cvs:	MANIFEST.withcvs
	perl "-MExtUtils::Manifest=manicopy,maniread" -e '$$fs=maniread(q{MANIFEST.withcvs}); while($$f=each %$$fs) { if (-e qq{${CVS_DIR}/$$f} && -M $$f >= -M qq{${CVS_DIR}/$$f}) { delete $$fs->{$$f} } } manicopy($$fs,q{${CVS_DIR}}, q{cp}); utime time,time,map { qq{${CVS_DIR}/$$_} } keys %$$fs'

# Slow, aber gruendlich!
do-copy-to-cvs-slow: MANIFEST.withcvs
	perl "-MExtUtils::Manifest=manicopy,maniread" -e "manicopy(maniread('MANIFEST.withcvs'),'${CVS_DIR}', 'cp');"


diff-with-cvs:	MANIFEST.withcvs
	makepatch --verbose \
	    -oldmanifest MANIFEST.withcvs -newmanifest MANIFEST.withcvs \
	    -exclude lib/enum.pm \
	    -diff "diff -up -I '\$$Id.*\$$' -I '\$$Revision.*\$$'" \
	    -descr "" \
	    ${CVS_DIR} ${.CURDIR}
	@echo "Use"
	@echo "    make cvs-add-missing"
	@echo "for missing files in CVS"

cvs-add-missing-disconnected:
	@echo Do not use this command without doing cvs update -ko
	@sleep 5
	cd ${CVS_DIR} && cvsu | grep '^[\?D]' | cut -c2- | xargs cvsdo add

cvs-add-missing:
	cd ${CVS_DIR} && cvsu | grep '^[\?D]' | cut -c2- | xargs cvs add -ko

cvs-standard-commit:
	cd ${CVS_DIR} && cvs -q -z9 commit -m ""

cvs-everything:	copy-to-cvs cvs-add-missing cvs-standard-commit

MANIFEST.withcvs:	MANIFEST MANIFEST.addtocvs
	echo "# DO NOT EDIT. Generated by Makefile" > MANIFEST.withcvs
	cat MANIFEST | grep -v -f MANIFEST.delfromcvs >> MANIFEST.withcvs
	perl -nle 'print join("\n", glob("$$_"))' MANIFEST.addtocvs >> MANIFEST.withcvs

# Manifest.addtocvs is *not* constant, so arrange that MANIFEST.withcvs
# is always fired.
.PHONY: MANIFEST.withcvs

# XXX It would be nicer to use "cp" instead of "ln", but ExtUtils::Manifest is buggy
full-cvs-dist:	MANIFEST.withcvs
	perl -MExtUtils::Manifest=manicopy,maniread -e 'manicopy(maniread("MANIFEST.withcvs"), "/tmp/BBBike-CVS", "ln")'

# DISTRIBUTIONS ##########################################################

TMPDIR?=	/tmp
BBBIKE_TMP=     $(TMPDIR)/$(DISTNAME)

EOF
.
    "DEVEL_ARCH=       \$(TMPDIR)/\$(DISTVNAME)-" .
                        sprintf("%04d%02d%02d",
                               sub { $_[5]+1900, $_[4]+1, $_[3] }->(localtime)
                              ) . "-devel.zip\n\n" .

    <<'EOF'
#### development + distribution ##########################################

dist-to-tmp:
	$(PERL) -MExtUtils::Manifest=manicopy,maniread -e "manicopy(maniread(),'$(TMPDIR)/$(DISTVNAME)','best')"
	find $(TMPDIR)/$(DISTVNAME) -type d -exec chmod ugo+rx {} \;
	find $(TMPDIR)/$(DISTVNAME) -type f -exec chmod ugo+r {} \;


# bbbike.cgi #####################

CGI_ARCH=	$(TMPDIR)/bbbikecgi.zip
CGI2_ARCH_PROG= $(TMPDIR)/bbbikecgi_prog.zip
CGI2_ARCH_WEB=  $(TMPDIR)/bbbikecgi_web.zip

# CGI-Distribution: alle Dateien in einer Hierarchie
cgidist: cgidistdir
	$(RM_F) $(CGI_ARCH)
	cd $(BBBIKE_TMP) && $(ZIP) $(ZIPFLAGS) $(CGI_ARCH) $(DISTNAME)

cgidistdir:   MANIFEST.bbbikecgi
	$(RM_RF) $(BBBIKE_TMP)
	$(MKPATH) $(BBBIKE_TMP)
	$(PERL) -I$(PERL_ARCHLIB) -I$(PERL_LIB) \
		-MExtUtils::Manifest=manicopy,maniread \
                -e "manicopy(maniread(q{MANIFEST.bbbikecgi}),q{$(BBBIKE_TMP)/$(DISTNAME)}, q{$(DIST_CP)});"

cgidistdir-berlin-potsdam:   MANIFEST.bbbikecgi
	$(RM_RF) $(BBBIKE_TMP)
	$(MKPATH) $(BBBIKE_TMP)
	$(PERL) -I$(PERL_ARCHLIB) -I$(PERL_LIB) \
		-MExtUtils::Manifest=manicopy,maniread \
                -e '$$files = maniread(q{MANIFEST.bbbikecgi}); \
		    for (keys %$$files) { \
		      if (m|^data/(.*)|) { $$data->{$$1}=""; delete $$files->{$$_} } \
		    } \
		    manicopy($$files,q{$(BBBIKE_TMP)/$(DISTNAME)}, q{$(DIST_CP)}); \
		    chdir "data_berlin_and_potsdam" or die; \
		    manicopy($$data,q{$(BBBIKE_TMP)/$(DISTNAME)/data}, q{$(DIST_CP)}); \
'

# Alternative: Programme unter cgi-bin, Rest in ein BBBike-Verzeichnis
cgidist2:
	$(RM_F) $(CGI2_ARCH_PROG) $(CGI2_ARCH_WEB)
	$(RM_RF) $(BBBIKE_TMP)
	$(MKPATH) $(BBBIKE_TMP)
	$(PERL) -I$(PERL_ARCHLIB) -I$(PERL_LIB) \
		-MExtUtils::Manifest=manicopy,maniread \
                -e "manicopy(maniread(q{MANIFEST.bbbikecgi.prog}),q{$(BBBIKE_TMP)/$(DISTNAME)}, q{$(DIST_CP)});"
	$(MV) $(BBBIKE_TMP)/$(DISTNAME)/cgi/* $(BBBIKE_TMP)
	cd $(BBBIKE_TMP) && $(ZIP) $(ZIPFLAGS) $(CGI2_ARCH_PROG) .
	$(RM_RF) $(BBBIKE_TMP)
	$(MKPATH) $(BBBIKE_TMP)
	$(PERL) -I$(PERL_ARCHLIB) -I$(PERL_LIB) \
		-MExtUtils::Manifest=manicopy,maniread \
                -e "manicopy(maniread(q{MANIFEST.bbbikecgi.web}),q{$(BBBIKE_TMP)/$(DISTNAME)}, q{$(DIST_CP)});"
	cd $(BBBIKE_TMP) && $(ZIP) $(ZIPFLAGS) $(CGI2_ARCH_WEB) $(DISTNAME)

# In beiden MANIFEST-Dateien sind images enthalten, weil images sowohl vom
# Browser aus, als auch bei der PNG/GIF-Erstellung verwendet werden.
MANIFEST.bbbikecgi:	MANIFEST.bbbikecgi.prog MANIFEST.bbbikecgi.web
	echo "# DO NOT EDIT! Generated by Makefile" > MANIFEST.bbbikecgi
	cat MANIFEST.bbbikecgi.prog MANIFEST.bbbikecgi.web >> MANIFEST.bbbikecgi

cgidist-cs:	cgidistdir-berlin-potsdam
	cp -fp cgi/bbbike-cs.cgi.config $(BBBIKE_TMP)/$(DISTNAME)/cgi/bbbike.cgi.config

# cbbbike #####################

CBBBIKE_ARCH=      $(TMPDIR)/cbbbike.zip
CBBBIKE_DOS_ARCH=  $(TMPDIR)/cbbbike_dos.zip
RECODE=            recode

.PHONY: ChangeLog develdist makepatch cbbbikedist cbbbikedistdit
.PHONY: cbbbikedosdist cbbbikedosdistdir cgidist cgidistdir
.PHONY: ext distdir2

cbbbikedist: cbbbikedistdir
	$(RM_F) $(CBBBIKE_ARCH)
	cd $(TMPDIR) && $(ZIP) $(ZIPFLAGS) $(CBBBIKE_ARCH) $(DISTNAME)

cbbbikedistdir:
	$(RM_RF) $(BBBIKE_TMP)
	$(PERL) -I$(PERL_ARCHLIB) -I$(PERL_LIB) -MExtUtils::Manifest=manicopy,maniread \
                -e "manicopy(maniread(\'MANIFEST.cbbbike\'),\'$(BBBIKE_TMP)\', \'$(DIST_CP)\');"

# cbbbikedosdist: wie cbbbikedist, nur wird noch zusätzlich mit recode
# nach cp850 (besser als cp437) konvertiert
cbbbikedosdist: cbbbikedosdistdir
	$(RM_F) $(CBBBIKE_DOS_ARCH)
	cd $(TMPDIR) && $(ZIP) $(ZIPFLAGS) $(CBBBIKE_DOS_ARCH) $(DISTNAME)

cbbbikedosdistdir: cbbbikedistdir
	cd $(BBBIKE_TMP) && chmod u+w *; $(RECODE) latin1:cp850 *.pm cbbbike; chmod 755 cbbbike
	cd $(BBBIKE_TMP)/data && chmod u+w *; $(RECODE) latin1:cp850 *

distdir2:
	umask 022 && $(MAKE) $(MAKEFLAGS) distdir
	# for testing with extension based systems like Windows
	cd $(DISTVNAME) && ln -s bbbike bbbike.pl
	-rm -fr /tmp/$(DISTVNAME)
	ln -s `pwd`/$(DISTVNAME) /tmp/$(DISTVNAME)

develdist:
	rm -rf $(DEVEL_ARCH)
	cd .. && $(ZIP) $(ZIPFLAGS) $(DEVEL_ARCH) bbbike \
	    -x \*.tar.gz \
	    -x \*/old/\* \
	    -x \*/cache/\* \
	    -x \*/tmp/\* \
	    -x \*/vbbdata/\* \
	    -x \*/c/minibbbike \
	    -x \*/datagdf_berlin/\* \
	    -x \*/datagdf_brandenburg/\* \
	    -x \*/datagdf_mitte/\* \
	    -x \*/datagdf_*/\* \
	    -x \*/datagdf/\* \
	    -x \*/diplom/\* \
	    -x \*/CRASH/\* \
	    -x \*/distfiles/\* \
	    -x \*/i386-freebsd/\* \
            -x \*/i386-freebsd-64int/\* \
            -x \*/i386-freebsd-thread/\* \
	    -x \*/i586-linux/\* \
	    -x \*/blib \
	    -x \*/blib/\* \
	    -x \*/pm_to_blib \
 	    -x \*/.xvpics/\* \
	    -x \*/misc/adressen/\* \
	    -x \*/misc/Berlin_Mitte.gdf \
	    -x \*/palm/test/\* \
	    -x \*/palm/test2/\* \
	    -x \*/projects/\* \
	    -x \*/vbbbike/vbbbike \
	    -x \*.o \
	    -x \*.so \
	    -x \*.bs \
	    -x \*.old \
	    -x \*.core \
	    -x \*.out \
	    -x \*.grc \
	    -x \*.bin \
	    -x \*/#*# \
	    -x \*.gdbinit \
	    -x \*.bak \
	    -x \*~

predist:
	cd data && ${MAKE}
	${MAKE} generatemods
	${MAKE} extmod
	${MAKE} linkextmod
	${MAKE} bbbikedoc
	${MAKE} distcheck
	${MAKE} distdir
	${MAKE} bundles
	@echo check bbbike in BBBike-$(VERSION) directory

# DOCUMENTATION ##########################################################

CLEAN_POD2HTML=$(RM_F) pod2html-*cache pod2htm?.?~~

STRPP=	strpp

README README.english:	README.spp BBBikeVar.pm
	${STRPP} --dir=. README.spp

EOF
. $bbbike_html_rule . <<'EOF'

clean_pod2html:

EOF
. "bbbikedoc:	README README.english $all_html\n" . <<'EOF'

# XXX this will fail if there is no symlink to the original libexec position
ChangeLog:
	rcs2log `find . -name "*,v" -a ! -path "./projects/*" -a ! -path "./misc/gps_data/*" -a ! -path "./Attic/*"` > ChangeLog

clean_cache:
	echo rm -rf cache/*

# PORTS, BINDISTS...####################################################

fbsdport:
	cd port/freebsd && env TMPDIR=$(TMPDIR) ./mkport.pl

#XXX -useversion devel NYI
#fbsdport-devel:
#	cd port/freebsd && env TMPDIR=$(TMPDIR) ./mkport.pl -useversion devel

fbsdport-distfiles-link:
	[ -d /usr/ports/distfiles ] && \
	[ -w /usr/ports/distfiles ] && \
	[ ! -e /usr/ports/distfiles/BBBike-$(VERSION).tar.gz ] && \
	ln -s ${.CURDIR}/distfiles/BBBike-$(VERSION).tar.gz /usr/ports/distfiles || \
	exit 0

fbsdportdiff: fbsdport do-fbsdportdiff

fbsdportdiff-devel: fbsdport-devel do-fbsdportdiff

do-fbsdportdiff:
	makepatch /usr/ports/german/BBBike $(TMPDIR)/BBBike > $(TMPDIR)/bbbike-freebsdport.diff
#	-cd $(TMPDIR) && diff --new-file -u /usr/ports/german/BBBike BBBike > $(TMPDIR)/bbbike-freebsdport.diff

VARPORTDIR=/var/tmp/BBBike
TMPPORTDIR=$(TMPDIR)/BBBike

# Taken form porters handbook, Automated package list creation
fbsdport-pkg-plist-check: fbsdport
	perl -le 'exit !(shift =~ m{^/var/tmp/})' ${VARPORTDIR}
	rm -rf ${VARPORTDIR}
	mkdir ${VARPORTDIR}
	mtree -U -f /etc/mtree/BSD.local.dist -d -e -p ${VARPORTDIR}
	cd ${TMPPORTDIR} && make clean depends PREFIX=${VARPORTDIR}
	(cd ${VARPORTDIR} && find -d * -type d) > ${TMPDIR}/OLD-DIRS
	cd ${TMPPORTDIR} && make install PREFIX=${VARPORTDIR}
	(cd ${VARPORTDIR} && find -d * \! -type d) | sort > ${TMPDIR}/pkg-plist
	(cd ${VARPORTDIR} && find -d * -type d) | comm -13 ${TMPDIR}/OLD-DIRS - | sed -e 's#^#@dirrm #' | perl -le 'print join "", sort { (length($$b) <=> length($$a)) || ($$b cmp $$a) } <>' >> ${TMPDIR}/pkg-plist
	diff -u ${TMPPORTDIR}/pkg-plist ${TMPDIR}/pkg-plist

WINBINDISTDIR=$(TMPDIR)/BBBike-$(VERSION)-Windows
# XXX use another bbbike.bat/setup.bat if activeperl-613 would be used...
WINPERLBIN=$(HOME)/src/binperl/sieperl-5.6.1
WINBINDIST=$(WINBINDISTDIR).zip

winbindist-pre:	winbindist-clean winbindist-copy

winbindist-clean:
	rm -rf $(WINBINDISTDIR)

winbindist-copy:
	[ ! -d $(WINBINDISTDIR) ]
	@echo "Make sure that the distfile is uptodate"
	umask 022; mkdir $(WINBINDISTDIR)
	umask 022; cp -Rp $(WINPERLBIN) $(WINBINDISTDIR)
	mv $(WINBINDISTDIR)/`basename $(WINPERLBIN)` $(WINBINDISTDIR)/windows
	umask 022; if [ -r distfiles/BBBike-$(VERSION).tar.gz ] ; then \
	    cat distfiles/BBBike-$(VERSION).tar.gz | (cd $(WINBINDISTDIR) && tar xfvz - ); \
	elif [ -r BBBike-$(VERSION).tar.gz ]; then \
	    cat BBBike-$(VERSION).tar.gz | (cd $(WINBINDISTDIR) && tar xfvz - ); \
	else \
	    $(MAKE) distdir; \
	    cp -Rp BBBike-$(VERSION) $(WINBINDISTDIR); \
	    chmod ugo+rx $(WINBINDISTDIR)/BBBike-$(VERSION); \
	fi
	mv $(WINBINDISTDIR)/BBBike-$(VERSION) $(WINBINDISTDIR)/bbbike
	umask 022; cp -p cdrom/windows/autorun.inf \
	      cdrom/windows/bbbike.bat \
	      cdrom/windows/setup.bat \
	      cdrom/windows/setup.pl \
	    $(WINBINDISTDIR)
# put this again to the distribution if it really works!
#	      cdrom/windows/setup.exe

winbindist: winbindist-pre
	cd $(WINBINDISTDIR)/.. && umask 022; zip -r $(WINBINDIST) `basename $(WINBINDISTDIR)`
	chmod 644 $(WINBINDIST)

#XXX	[ -d /usr/ports/distfiles -a ! -l /usr/ports/distfiles/BBBike-$(VERSION)-Windows.zip ] && ln -s 

########################################################################

Makefile : Makefile.admin.PL

alldist: bbbikedoc dist dist_mv makepatch fbsdport fbsdport-distfiles-link \
	 winbindist ChangeLog

dist_mv:
	[ -d distfiles ] && true || mkdir distfiles
	mv -i BBBike-$(VERSION).tar.gz distfiles/

BACKUP_FILE=	/home5/bak/bbbike-devel.tar.gz

backup:
	-[ -f ${BACKUP_FILE} ] && mv -f ${BACKUP_FILE} ${BACKUP_FILE}~
	cd .. && tar -c -v -z -f ${BACKUP_FILE} --exclude "*.tar.gz" --exclude "*patch.gz" --exclude "*~" bbbike

# XXX Problem: binary files (xdelta? uuencode? nix?)
makepatch:
#	./miscsrc/mymakepatch.pl $(NAME)

rcslabel:
	$(PERL) -I$(PERL_ARCHLIB) -I$(PERL_LIB) -MExtUtils::Manifest=maniread \
		-e "@all = keys %{ maniread() };" \
		-e 'print("Executing $(RCS_LABEL) ...\n"); system("$(RCS_LABEL) @all");'

autoload:
	./miscsrc/make_autoload.pl -dd -f \
	    Strassen/Core.pm Strassen/Fast.pm Strassen/Kreuzungen.pm \
	    Strassen/MultiBezStr.pm Strassen/MultiStrassen.pm \
	    Strassen/Strasse.pm Strassen/StrassenNetz.pm Strassen/Util.pm

# Pfad zum mymake-Skript, das Makefile.PL's für ~/lib/perl erzeugt
# Da vieler meiner Skripte Test.pm verwenden, wird das nicht mit 5.004 gehen
# XXX mymake ist nur auf meiner Platte vorhanden!
EOF
		    . "MYEXTMODMAKE=	\$(HOME)/src/mymake -perl $^X\n"
		    . <<EOF
# normales Erzeugen mit: \$(FULLPERL) Makefile.PL
# "offizielle" Module
EXTMODCPANTOP=	$EXTMODCPANTOP
EXTMODCPAN=	$EXTMODCPAN
# "experimentelle" Module
EXTMODPERLTOP=	$EXTMODPERLTOP
EXTMODPERL=	$EXTMODPERL

EOF
		    . <<'EOF'

echoextmodcpantop:
	@echo $(EXTMODCPANTOP)

echoextmodcpan:
	@echo $(EXTMODCPAN)

echoextmodperltop:
	@echo $(EXTMODPERLTOP)

echoextmodperl:
	@echo $(EXTMODPERL)

# baut und installiert die externen Module wie BikePower etc.
# verwendet Xfvb oder Xnest
# XXX testen, ob man überhaupt einen X-Server hat
#	alternative: Xnest -ac -geometry 640x400 :121 &
extmod:
	Xvfb -ac :121 & \
	_XVFB_PID=$$!; \
	DISPLAY=:121; \
	for i in $(EXTMODCPAN); do \
	    echo $$i; \
	    cd $(EXTMODCPANTOP)/$$i; \
		$(MYEXTMODMAKE) && \
		make && \
		BATCH=yes make test && \
		make install; \
	done; \
	for i in $(EXTMODPERL); do \
	    echo $$i; \
	    cd $(EXTMODPERLTOP)/$$i; \
		$(MYEXTMODMAKE) && \
		make && \
		BATCH=yes make test && \
		make install; \
	done; \
	echo Kill process $$_XVFB_PID; \
	kill -TERM $$_XVFB_PID
EOF
. <<EOF

linkextmod:
	$^X ./miscsrc/link_ext_mod.pl -v
EOF
. <<'EOF'

generatemods: Strassen/Generated.pm

bundles:
	if [ ! -h Bundle/make_bundle ] ; then \
	    ln -s ../Makefile.PL Bundle/make_bundle; \
	fi
	if [ ! -h Bundle/make_small_bundle ] ; then \
	    ln -s ../Makefile.PL Bundle/make_small_bundle; \
	fi
	cd Bundle; $(FULLPERL) make_bundle; $(FULLPERL) make_small_bundle

# OSD bundles are not supported anymore
bundles-osd:
	if [ ! -h Bundle/make_pi_osd ] ; then \
	    ln -s ../Makefile.PL Bundle/make_pi_osd; \
	fi
	if [ ! -h Bundle/make_small_pi_osd ] ; then \
	    ln -s ../Makefile.PL Bundle/make_small_pi_osd; \
	fi
	cd Bundle && $(FULLPERL) make_pi_osd unix; \
		     $(FULLPERL) make_pi_osd win; \
		     $(FULLPERL) make_small_pi_osd unix; \
		     $(FULLPERL) make_small_pi_osd win

Strassen/Generated.pm: Strassen/Generated_src.pm Strassen.pm
	-rm -f Strassen/Generated.pm
	echo "1;" > Strassen/Generated.pm
	cd Strassen && perl5.00503 Generated_src.pm
	perl5.00503 -c Strassen/Generated_src.pm
	chmod ugo+r,-w Strassen/Generated.pm

echoversion:
	@echo 1>&2 This rule is obsolete ... use BBBikeVar.pm
	@echo $(VERSION)

# find perl scripts and modules
FIND_PERL_SCRIPTS=-type f -a \( -name "*.pm" -o -name "*.pl" -o -name "*.cgi" -o -name "bbbike" -o -name "cbbbike" \)

# Create a crypted perl distribution. The generated scripts should be called
# using ~/private/src/decrypt/perl.
encrypt:
	cd $(TMPDIR) && tar xfvz ${.CURDIR}/distfiles/$(DISTVNAME).tar.gz
	cd $(HOME)/private/src/decrypt && find $(TMPDIR)/$(DISTVNAME) $(FIND_PERL_SCRIPTS)  -print -exec ./encrypt {} \;

# Create a mangled, comment-less, pod-less minimal version of the script
# and modules. Savings are minimal: about 10% space for the distribution,
# about 1s for startup and nearly no RAM benefits.
mangle:
	cd $(TMPDIR) && tar xfvz ${.CURDIR}/distfiles/$(DISTVNAME).tar.gz
	cd $(TMPDIR)/$(DISTVNAME) && \
	    find . $(FIND_PERL_SCRIPTS) -print \
		-exec mv {} {}~ \; \
		-exec perltidy -t -mangle -dac -dp {}~ -o {} \; \
		-exec rm -f {}~ \;

permission:
	perl -MExtUtils::Manifest=maniread -le 'print join "\n", sort keys %{ maniread("MANIFEST") }' | xargs chmod ugo+r
	chmod ugo+rx bbbike cgi/*.cgi
	chmod ugo+r cgi/*.config
	chmod ugo+rx data/temp_blockings
	chmod ugo+r  data/temp_blockings/*

.PHONY: data

data:
	cd data && ${MAKE}

BBBikeVar.tpl: BBBikeVar.pm
	./miscsrc/ttdump --package BBBike --prefix BBBike BBBikeVar.pm > BBBikeVar.tpl

EOF
;

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 1b42243230d92021e6c361e37c9771d1

=head2 is_in_path($prog)

=for category File

Return the pathname of $prog, if the program is in the PATH, or undef
otherwise.

DEPENDENCY: file_name_is_absolute

=cut

sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -f $prog and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    return "$_\\$prog"
		if (-x "$_\\$prog.bat" ||
		    -x "$_\\$prog.com" ||
		    -x "$_\\$prog.exe");
	} else {
	    return "$_/$prog" if (-x "$_/$prog");
	}
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 a77759517bc00f13c52bb91d861d07d0

=head2 file_name_is_absolute($file)

=for category File

Return true, if supplied file name is absolute. This is only necessary
for older perls where File::Spec is not part of the system.

=cut

sub file_name_is_absolute {
    my $file = shift;
    my $r;
    eval {
        require File::Spec;
        $r = File::Spec->file_name_is_absolute($file);
    };
    if ($@) {
	if ($^O eq 'MSWin32') {
	    $r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	} else {
	    $r = ($file =~ m|^/|);
	}
    }
    $r;
}
# REPO END

1;

__END__

Installation notes for www.radzeit.de: see ~/www/www.radzeit.de/Makefile

OLD NOTES:

Installation notes for www.radzeit.de

- There are two bbbike installations: /usr/local/apache/radzeit/BBBike{,2}.
  The cgi programs are in /usr/local/apache/radzeit/cgi-bin.
  The plan is to make the config files relocatable and switch easily between
  BBBike and BBBike2 --- or to make either BBBike or BBBike2 the default
  installation by adding "ScriptAlias /cgi-bin/bbbike.cgi ..." and some
  hand-editing of the config files etc.

- Steps for an data/prog update on www.radzeit.de

  # This may take a long time
  cd data_berlin_and_potsdam && make
  # This one takes not so long
  cd data_corrected && make mapfiles
  cd .. && make rsync-radzeit-test-prog-quick

- Steps for an data update only
  # This may take a long time
  cd data_berlin_and_potsdam && make
  # This one takes not so long
  cd data_corrected && make mapfiles
  cd .. && make rsync-radzeit-test-data
  cd mapserver/brb && make dist-radzeit rsync-radzeit

Installation notes for user.cs.tu-berlin.de

- install redirect script unless gd runs again
