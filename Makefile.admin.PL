# -*- perl -*-

#
# $Id: Makefile.admin.PL,v 1.10 2003/09/02 21:45:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

$bbbike_makefile_admin = <<'EOF';
#### RSYNCS ###############################################################

BBBIKE_CS_DEST=user.cs.tu-berlin.de:www/bbbike
BBBIKE_CS_TEST_DEST=user.cs.tu-berlin.de:www/BBBike
BBBIKE_SF_DEST=bbbike.sourceforge.net:/home/groups/b/bb/bbbike
BBBIKE_SF_DIR=$(HOME)/www/bbbike.sourceforge.net

BBBIKE_RADZEIT_USER=		root
BBBIKE_RADZEIT_HOST=		www.radzeit.de
BBBIKE_RADZEIT_APACHE_DIR=	/usr/local/apache/radzeit
BBBIKE_RADZEIT_CGI_DIR=		$(BBBIKE_RADZEIT_APACHE_DIR)/cgi-bin
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

#  ######################################################################
#  # radzeit.de rules

#  rsync-radzeit-data:
#  	$(RSYNC_RADZEIT_DATA)
#  #	$(RSYNC_DATA_CMD) $(BBBIKE_RADZEIT_DEST)/data

#  rsync-radzeit-test-data:
#  	$(RSYNC_RADZEIT_TEST_DATA)

#  rsync-radzeit-prog-fresh:	do-rsync-radzeit-prog \
#  				do-ssh-radzeit

#  rsync-radzeit-test-prog-fresh:	prepare-rsync-radzeit-test-prog \
#  				do-rsync-radzeit-test-prog \
#  				do-ssh-radzeit-test

#  rsync-radzeit-prog-quick:	do-rsync-radzeit-prog \
#  				do-ssh-radzeit

#  rsync-radzeit-test-prog-quick:	do-rsync-radzeit-test-prog \
#  				do-ssh-radzeit-test

#  prepare-rsync-radzeit-test-prog:
#  	ssh -l $(BBBIKE_RADZEIT_USER) $(BBBIKE_RADZEIT_HOST) sh -c 'test -d $(BBBIKE_RADZEIT_DIR2) && echo rm -rf $(BBBIKE_RADZEIT_DIR2); cp -Rp $(BBBIKE_RADZEIT_DIR) $(BBBIKE_RADZEIT_DIR2)'

#  do-rsync-radzeit-prog:	distdir
#  	cd $(DISTVNAME) && $(RSYNC) -Pvzr --exclude "data/**" . $(BBBIKE_RADZEIT_DEST)
#  	$(RSYNC_RADZEIT_DATA)
#  	ssh -l $(BBBIKE_RADZEIT_USER) $(BBBIKE_RADZEIT_HOST) sh -c 'test -d $(BBBIKE_RADZEIT_DIR)/miscsrc || mkdir $(BBBIKE_RADZEIT_DIR)/miscsrc; true'
#  	cd miscsrc && $(RSYNC) -Pvzr bbd2esri $(BBBIKE_RADZEIT_DEST)/miscsrc/
#  	cd cgi && $(RSYNC) -Pvzr bbbike-radzeit.cgi.config $(BBBIKE_RADZEIT_USER)@$(BBBIKE_RADZEIT_HOST):$(BBBIKE_RADZEIT_CGI_DIR)/bbbike.cgi.config

#  do-rsync-radzeit-test-prog:	distdir
#  	cd $(DISTVNAME) && $(RSYNC) -Pvzr --exclude "data/**" . $(BBBIKE_RADZEIT_DEST2)
#  	$(RSYNC_RADZEIT_TEST_DATA)
#  	cd miscsrc && $(RSYNC) -Pvzr bbd2esri $(BBBIKE_RADZEIT_DEST2)/miscsrc/
#  	cd cgi && $(RSYNC) -Pvzr bbbike-radzeit.cgi.config $(BBBIKE_RADZEIT_USER)@$(BBBIKE_RADZEIT_HOST):$(BBBIKE_RADZEIT_CGI_DIR)/bbbike2.cgi.config

#  do-ssh-radzeit:
#  	ssh -l $(BBBIKE_RADZEIT_USER) $(BBBIKE_RADZEIT_HOST) \
#  	    sh -c 'cp -p $(BBBIKE_RADZEIT_DIR)/cgi/bbbike.cgi \
#  	          	 $(BBBIKE_RADZEIT_CGI_DIR)/bbbike.cgi;
#  	    	   cp -p $(BBBIKE_RADZEIT_DIR)/cgi/mapserver_comment.cgi \
#  	          	 $(BBBIKE_RADZEIT_CGI_DIR)/mapserver_comment.cgi;
#  	    	   cp -p $(BBBIKE_RADZEIT_DIR)/cgi/mapserver_address.cgi \
#  	          	 $(BBBIKE_RADZEIT_CGI_DIR)/mapserver_address.cgi;
#  	    	   cp -p $(BBBIKE_RADZEIT_DIR)/cgi/wapbbbike.cgi \
#  	          	 $(BBBIKE_RADZEIT_CGI_DIR)/wapbbbike.cgi;
#  		  '

#  do-ssh-radzeit-test:
#  	ssh -l $(BBBIKE_RADZEIT_USER) $(BBBIKE_RADZEIT_HOST) \
#  	    cp -p $(BBBIKE_RADZEIT_DIR2)/cgi/bbbike.cgi \
#  	          $(BBBIKE_RADZEIT_APACHE_DIR)/cgi-bin/bbbike2.cgi
#  	ssh -l $(BBBIKE_RADZEIT_USER) $(BBBIKE_RADZEIT_HOST) \
#  	    cp -p $(BBBIKE_RADZEIT_DIR2)/cgi/mapserver_comment.cgi \
#  	          $(BBBIKE_RADZEIT_APACHE_DIR)/cgi-bin/mapserver_comment.cgi
#  	ssh -l $(BBBIKE_RADZEIT_USER) $(BBBIKE_RADZEIT_HOST) \
#  	    cp -p $(BBBIKE_RADZEIT_DIR2)/cgi/mapserver_address.cgi \
#  	          $(BBBIKE_RADZEIT_APACHE_DIR)/cgi-bin/mapserver_address.cgi

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

CVS_DIR=/home/e/eserte/work/bbbike

# XXX create or copy .cvsignore with ext/*/*Dist.pm files
copy-to-cvs:	MANIFEST.withcvs
	@echo "Really copy to ${CVS_DIR}? (Hit Ctrl-C otherwise) "
	@read dummy
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
	cd ${CVS_DIR} && cvsu | grep '^\?' | cut -c2- | xargs cvsdo add

cvs-add-missing:
	cd ${CVS_DIR} && cvsu | grep '^\?' | cut -c2- | xargs cvs add -ko

cvs-standard-commit:
	cd ${CVS_DIR} && cvs -z9 commit -m ""

cvs-everything:	copy-to-cvs cvs-add-missing cvs-standard-commit

MANIFEST.withcvs:	MANIFEST MANIFEST.addtocvs
	echo "# DO NOT EDIT. Generated by Makefile" > MANIFEST.withcvs
	cat MANIFEST >> MANIFEST.withcvs
	perl -nle 'print join("\n", glob("$$_"))' MANIFEST.addtocvs >> MANIFEST.withcvs

# Manifest.addtocvs is *not* constant, so arrange that MANIFEST.withcvs
# is always fired.
.PHONY: MANIFEST.withcvs

EOF

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
