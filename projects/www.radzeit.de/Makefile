#
# $Id: Makefile,v 1.62 2005/06/19 19:01:40 eserte Exp $
#

# Targets:
#  check:	Show what would be rsync'ed from the current directory
#  rsync:	Do the rsync. This will not be permitted if the make system
#		detects that the contents are prepared for the local server.
#  rsync-bbbike-data: Do the rsync of only the data directory. This is
#		also allowed if prepared for the local server.
#  rsync-temp-blockings: Do the rsync of just the "temp-blockings" part of
#		the data. Also allowed if prepared for the local server.
#  tkrsync:	Execute the "tkrsync" for manually syncing parts of the tree.
#  test:	Test the remote server from the local host.
#  test-on-remote:	Test the remote server from the remote host.
#  deploy:	Do everything from preparing to rsync'ing and testing.
#  deploy-local:	Prepare a local distribution for testing. Do not rsync.
#  test-makefile:	Same as deploy-local, but each make command has to
#			be confirmed.
#
# It is required that the target web server has "FollowSymLinks" on.

# The local service is available on
#   ${LOCAL_URL}/cgi-bin/bbbike.cgi

#BBBIKE_ROOT_DIR?=	$(HOME)/src/bbbike
BBBIKE_ROOT_DIR?=	${.CURDIR}/../..
CURDIR=			${.CURDIR}
LOCAL_URL?=		http://radzeit.herceg.de
LOCAL_CGI_URL?=		${LOCAL_URL}/cgi-bin
LOCAL_HTML_URL?=	${LOCAL_URL}/BBBike
#XXXDATA_DIR=		data_corrected
DATA_DIR=		data
TEMP_BLOCKINGS_DIR=	data/temp_blockings

EXTRA_MISCSRC_FILES=	bbd2esri winter_optimization.pl
EXTRA_HTML_FILES=	Makefile newstreetform.tpl.html
CGI_FILES=		bbbike.cgi \
			bbbike-data.cgi \
			wapbbbike.cgi \
			mapserver_address.cgi \
			mapserver_comment.cgi \
			mapserver_setcoord.cgi
TESTS=			basic.t \
			cgihead.t \
			cgi-mechanize.t \
			cgi.t \
			wapcgi.t
TESTS_ADD=		BBBikeTest.pm
HTDOCS=			public


# XXX maybe use test-on-remote-and-send-mail (after tests)
DEPLOY_TARGETS=			prepare-bbbike-data \
				prepare-mapserver-data \
				prepare-bbbike-dist \
				prepare-mapserver-dist \
				prepare-touren-dist \
				rsync \
				test-on-remote

# only bbbike data, no program, no mapserver
DEPLOY_DATA_TARGETS=		prepare-bbbike-data \
				prepare-bbbike-dist \
				rsync-bbbike-data \
				test-on-remote

# local deployment
DEPLOY_LOCAL_TARGETS=		prepare-bbbike-data \
				prepare-mapserver-data \
				prepare-bbbike-dist \
				prepare-mapserver-local-dist \
				prepare-touren-dist \
				test-local

DEPLOY_LOCAL_DATA_TARGETS=	prepare-bbbike-data \
				prepare-bbbike-dist \
				test-local

SSH_PROG_AND_ARGS?=	ssh -2
RSYNC_PROG?=	rsync
RSYNC_ARGS=	-e "${SSH_PROG_AND_ARGS}" -Pvz -r -t --links --copy-unsafe-links --exclude-from .rsync.exclude
RSYNC_DEST?=	${BBBIKE_RADZEIT_USER}@${BBBIKE_RADZEIT_HOST}:${BBBIKE_RADZEIT_APACHE_DIR}
RSYNC_SRCDEST?=	. ${RSYNC_DEST}

# XXX Should be set from mapserver/brb/Makefile:
WWW_USER?=	www
WWW_GROUP?=	www

.if ${OSTYPE} == "linux"
XARGS_REPL?=	xargs --replace=%
.else
XARGS_REPL?=	xargs -J %
.endif

MAPSERVER_EXE?=	$(HOME)/www/cgi/mapserv.cgi

.ifndef TARGET
.if ${CURDIR:T} == "www.radzeit-old.de"
TARGET=radzeit-old
.endif
.endif

.ifndef TARGET
.for t in ${DEPLOY_TARGETS}
.if make($t)
TARGET=radzeit
.endif
.endfor
.endif

.ifndef TARGET
.for t in ${DEPLOY_LOCAL_TARGETS}
.if make($t)
.if ${HOST} == "devpc01.iconmobile.de"
TARGET=devpc01
.else
TARGET=radzeit.herceg.de
.endif
.endif
.endfor
.endif

.ifndef TARGET
.if   make(deploy)                   || \
      make(deploy-data)		     || \
      make(tkrsync)		     || \
      make(check)		     || \
      make(backup) 		     || \
      make(test)		     || \
      make(prepare-bbbike-dist-data) || \
      make(rsync)		     || \
      make(rsync-bbbike-data)	     || \
      make(rsync-temp-blockings)     || \
      make(rsync-routopedia)	     || \
      make(clean-cache-files-on-remote)
TARGET=radzeit
.elif make(deploy-local)      || \
      make(deploy-local-data) || \
      make(backup-local)      || \
      make(test-local)
.if ${HOST} == "devpc01.iconmobile.de"
TARGET=devpc01
.else
TARGET=radzeit.herceg.de
.endif
.else
.error "Please set TARGET to radzeit or radzeit.herceg.de"
.endif
.endif

.if ${TARGET} == "devpc01"
MAPSERVER_EXE=	$(HOME)/work2/mapserver/mapserv.cgi
LOCAL_URL=	http://localhost:8080/bbbike
LOCAL_CGI_URL=	http://localhost:8080/bbbike/cgi
LOCAL_HTML_URL=	http://localhost:8080/bbbike
DATA_DIR=	data
.endif

RADZEIT_OLD_URL=	http://www.radzeit.de
.if ${TARGET} == "radzeit-old"
SSH_PROG_AND_ARGS=	ssh
HTDOCS=			htdocs
LOCAL_URL=		http://radzeit-old.herceg.de
.endif

.include "${BBBIKE_ROOT_DIR}/mapserver/brb/Makefile.${TARGET}.inc"

all:

######################################################################
# Top level targets
check:
	${RSYNC} --dry-run ${RSYNC_ARGS} ${RSYNC_SRCDEST}

clean-cache-files-on-remote:
	-${SSH_PROG_AND_ARGS} -l ${BBBIKE_RADZEIT_USER} ${BBBIKE_RADZEIT_HOST} \
	    rm /tmp/b_de_\*

rsync:			check-rsync-ok \
			clean-cache-files-on-remote \
			do-rsync \
			show-rsync-message \
			post-rsync-bbbike-data

check-rsync-ok:
	#perl -nle '/^(.*)www.radzeit.de/ && $$1 !~ /\#/ && print "Using new radzeit server"' /etc/hosts
	[ ! -e ${CURDIR}/.not_rsyncable ] || ( echo "Not rsyncable!"; false )
	[ ! -e ${CURDIR}/.rsync_block ] || ( echo "Not rsyncable because:"; cat ${CURDIR}/.rsync_block; false )

do-rsync:
	${RSYNC} ${RSYNC_ARGS} ${RSYNC_SRCDEST}

rsync-bbbike:
	@echo NYI
	false

rsync-mapserver:
	@echo NYI
	false

rsync-routopedia:	do-rsync-routopedia \
			show-rsync-message

do-rsync-routopedia:
	${RSYNC} ${RSYNC_ARGS} \
	    --exclude data/ \
	    routopedia/ ${RSYNC_DEST}/routopedia/

check-rsync-data-ok:
	true

rsync-bbbike-data:	check-rsync-data-ok \
			clean-cache-files-on-remote \
			do-rsync-bbbike-data \
			show-rsync-message \
			post-rsync-bbbike-data

do-rsync-bbbike-data:
	${RSYNC} ${RSYNC_ARGS} \
	    BBBike/data/ ${RSYNC_DEST}/BBBike/data/

post-rsync-bbbike-data:
# No winter optimization needed anymore...
.if 0
	-${SSH_PROG_AND_ARGS} -l ${BBBIKE_RADZEIT_USER} ${BBBIKE_RADZEIT_HOST} \
	   "${BBBIKE_RADZEIT_APACHE_DIR}/BBBike/miscsrc/winter_optimization.pl -one-instance &"
.endif

rsync-temp-blockings:
	${RSYNC} ${RSYNC_ARGS} \
	    BBBike/data/temp_blockings/ ${RSYNC_DEST}/BBBike/data/temp_blockings/

show-rsync-message:
	-[ ! -e ${CURDIR}/.rsync_message ] && true || cat ${CURDIR}/.rsync_message

# use -t in rsync?
tkrsync:
	tkrsync -showchanges -rsync="-zrt --cvs-exclude --exclude-from .rsync.exclude" ${RSYNC_SRCDEST}

deploy:			${DEPLOY_TARGETS}

deploy-local:		${DEPLOY_LOCAL_TARGETS}

deploy-data:		${DEPLOY_DATA_TARGETS}

deploy-local-data:	${DEPLOY_LOCAL_DATA_TARGETS}

test-makefile:
	${MAKE} -n deploy-local > /tmp/test-makefile.cmd
	perl -e 'while(<ARGV>) {print STDERR "\a$$_> "; <STDIN>; system($$_) and warn $$?}' /tmp/test-makefile.cmd

#XXX .NOTPARALLEL: rsync

######################################################################
# Sub targets
# Reihenfolge sollte hoffentlich richtig sein

prepare-bbbike-data:
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE} all
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE} slow-checks

prepare-mapserver-data:
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE} mapfiles

prepare-bbbike-dist:	prepare-bbbike-dist-prog prepare-bbbike-dist-data

prepare-bbbike-dist-prog: 	prepare-bbbike-dist-prog-bbbike \
				prepare-bbbike-dist-prog-stadtplan

prepare-bbbike-dist-prog-bbbike:	\
				prepare-bbbike-dist-prog-bbbike-copy \
				prepare-bbbike-dist-prog-bbbike-cgi \
				prepare-bbbike-dist-prog-bbbike-htdocs \
				prepare-bbbike-dist-prog-bbbike-tmp \
				prepare-bbbike-dist-prog-bbbike-t \
				prepare-bbbike-dist-prog-bbbike-miscsrc \
				prepare-bbbike-dist-prog-bbbike-html \
				prepare-bbbike-dist-prog-bbbike-images

prepare-bbbike-dist-prog-bbbike-copy:
	cd ${BBBIKE_ROOT_DIR} && ${MAKE} distcheck
	(umask 022; cd ${BBBIKE_ROOT_DIR} && perl "-MExtUtils::Manifest=manicopy,maniread" -e "manicopy(maniread(),'${CURDIR}/BBBike', 'best');")

prepare-bbbike-dist-prog-bbbike-cgi:
	[ -d ${CURDIR}/cgi-bin ] || mkdir ${CURDIR}/cgi-bin
	chmod 755 ${CURDIR}/cgi-bin
.for i in ${CGI_FILES}
	rm -f ${CURDIR}/cgi-bin/$(i)
	cd ${CURDIR}/cgi-bin && ln -s ../BBBike/cgi/$(i)
.endfor
	cp -pf ${BBBIKE_ROOT_DIR}/cgi/bbbike-radzeit.cgi.config \
	       ${CURDIR}/BBBike/cgi/bbbike.cgi.config
	rm -f ${CURDIR}/cgi-bin/bbbike.cgi.config
	cd ${CURDIR}/cgi-bin && ln -s ../BBBike/cgi/bbbike.cgi.config
	chmod ugo+r ${CURDIR}/BBBike/cgi/bbbike.cgi.config
	chmod ugo+r ${CURDIR}/cgi-bin/*
	@echo "Maybe create bbbike2.cgi and bbbike2.cgi.config"

prepare-bbbike-dist-prog-bbbike-htdocs:
	[ -d ${CURDIR}/$(HTDOCS)  ] || mkdir ${CURDIR}/$(HTDOCS)
	chmod 755 ${CURDIR}/$(HTDOCS)
	[ -e ${CURDIR}/$(HTDOCS)/BBBike ] || \
	    ln -s ../BBBike ${CURDIR}/$(HTDOCS)/BBBike
	@echo "Do 'ln -s ../BBBike ${BBBIKE_RADZEIT_APACHE_DIR}/$(HTDOCS)/BBBike' manually on server"

prepare-bbbike-dist-prog-bbbike-images:
	cp -pf ${BBBIKE_ROOT_DIR}/images/stern2005_titel.jpg \
	       ${CURDIR}/BBBike/images/
	chmod ugo+r ${CURDIR}/BBBike/images/stern2005_titel.jpg

prepare-bbbike-dist-prog-bbbike-tmp:
	chmod 777 ${CURDIR}/BBBike/tmp
	@echo "Maybe chown ${BBBIKE_RADZEIT_APACHE_DIR}/BBBike/tmp on ${BBBIKE_RADZEIT_HOST} to www"

prepare-bbbike-dist-prog-bbbike-miscsrc:
	[ -d ${CURDIR}/BBBike/miscsrc ] || \
	    mkdir ${CURDIR}/BBBike/miscsrc
.for f in ${EXTRA_MISCSRC_FILES}
	if [ ! -e ${CURDIR}/BBBike/miscsrc/$f -o ${BBBIKE_ROOT_DIR}/miscsrc/$f -nt ${CURDIR}/BBBike/miscsrc/$f ] ; then \
	    cp -pf ${BBBIKE_ROOT_DIR}/miscsrc/$f ${CURDIR}/BBBike/miscsrc/$f; \
	fi
.endfor

prepare-bbbike-dist-prog-bbbike-t:
	[ -d ${CURDIR}/BBBike/t ] || \
	    mkdir ${CURDIR}/BBBike/t
.for f in ${TESTS} ${TESTS_ADD}
	if [ ! -e ${CURDIR}/BBBike/t/$f -o ${BBBIKE_ROOT_DIR}/t/$f -nt ${CURDIR}/BBBike/t/$f ] ; then \
	    cp -pf ${BBBIKE_ROOT_DIR}/t/$f ${CURDIR}/BBBike/t/$f; \
	fi
.endfor

prepare-bbbike-dist-prog-bbbike-html:
.for f in ${EXTRA_HTML_FILES}
	if [ ! -e ${CURDIR}/BBBike/html/$f -o ${BBBIKE_ROOT_DIR}/html/$f -nt ${CURDIR}/BBBike/html/$f ] ; then \
	    cp -pf ${BBBIKE_ROOT_DIR}/html/$f ${CURDIR}/BBBike/html/$f; \
	fi
.endfor
	# Vorsichtshalber, weil ansonsten die falschen URLs enthalten sein
	# könnten:
	cd ${CURDIR}/BBBike/html && \
	    rm -f newstreetform.html fragezeichenform.html
	cd ${CURDIR}/BBBike/html && \
	    ${MAKE} newstreetform.html fragezeichenform.html \
		CGIDIR=http://${BBBIKE_RADZEIT_HOST}/cgi-bin

prepare-bbbike-dist-prog-stadtplan:
	[ ! -e ${BBBIKE_ROOT_DIR}/projects/www.berliner-stadtplan.com ] && \
	    echo Skip berliner-stadtplan.com deployment || \
	    (cp -pf ${BBBIKE_ROOT_DIR}/projects/www.berliner-stadtplan.com/lib/BBBikeDraw/BerlinerStadtplan.pm ${CURDIR}/BBBike/BBBikeDraw/)

prepare-bbbike-dist-data:	prepare-bbbike-dist-data-datadir \
				prepare-bbbike-dist-data-datadir-additional \
				prepare-bbbike-dist-data-temp-blockings-dir \
				prepare-bbbike-dist-data-teasers

# Usually data/* is already hardlinked against the originals, so
# no additional copying for data/* is necessary
prepare-bbbike-dist-data-datadir:

prepare-bbbike-dist-data-datadir-additional:
	cp -pf ${BBBIKE_ROOT_DIR}/data/*-cooked \
	    ${CURDIR}/BBBike/data/

# temp_blockings is not yet in MANIFEST, so copy is necessary
prepare-bbbike-dist-data-temp-blockings-dir:
	[ -d ${CURDIR}/BBBike/${TEMP_BLOCKINGS_DIR} ] || \
	    mkdir -p ${CURDIR}/BBBike/${TEMP_BLOCKINGS_DIR}
	find ${BBBIKE_ROOT_DIR}/${TEMP_BLOCKINGS_DIR}/ -maxdepth 1 -type f ! -name "*~" -a ! -name "*.st" -a ! -name "*.core" -a ! -name "#*#" | ${XARGS_REPL} cp -pf % ${CURDIR}/BBBike/${TEMP_BLOCKINGS_DIR}/
	-cp -pf ${BBBIKE_ROOT_DIR}/${TEMP_BLOCKINGS_DIR}/* \
	    ${CURDIR}/BBBike/${TEMP_BLOCKINGS_DIR}/

# Teasers for bbbike.cgi
prepare-bbbike-dist-data-teasers:
	rm -f ${CURDIR}/cgi-bin/bbbike-teaser.pl
	cd ${CURDIR}/cgi-bin && ln -s ../BBBike/cgi/bbbike-teaser.pl

prepare-mapserver-dist:	prepare-mapserver-dist-pre \
			prepare-mapserver-dist-main \
			prepare-mapserver-dist-post

prepare-mapserver-local-dist:	prepare-mapserver-dist-pre \
				prepare-mapserver-dist-local-main \
				prepare-mapserver-dist-post

prepare-mapserver-dist-pre:
	[ -e ${CURDIR}/cgi-bin/mapserv ] || \
	    ln -s ${MAPSERVER_EXE} ${CURDIR}/cgi-bin/mapserv
	@echo "Compile mapserv manually on ${BBBIKE_RADZEIT_HOST}"
	[ -d ${CURDIR}/$(HTDOCS)/mapserver/brb ] || \
	    mkdir -p ${CURDIR}/$(HTDOCS)/mapserver/brb

prepare-mapserver-dist-main:
	cd ${BBBIKE_ROOT_DIR}/mapserver/brb && \
	    ${MAKE} dist-any TARGET=${TARGET}
	cp -Rpf /tmp/radzeit_mapserver_dist/* ${CURDIR}/$(HTDOCS)/mapserver/brb/
	rm -f ${CURDIR}/.not_rsyncable

prepare-mapserver-dist-local-main:
	touch ${CURDIR}/.not_rsyncable
	cd ${BBBIKE_ROOT_DIR}/mapserver/brb && \
	    ${MAKE} dist-any TARGET=radzeit.herceg.de
	cp -Rpf /tmp/radzeit_mapserver_dist/* ${CURDIR}/$(HTDOCS)/mapserver/brb/
	chmod 777 ${CURDIR}/$(HTDOCS)/mapserver/brb
	chmod 777 ${CURDIR}/$(HTDOCS)/mapserver/brb/tmp

prepare-mapserver-dist-post:
	@echo "XXX Check permissions of $(HTDOCS)/mapserver/brb and maybe WWWUSER in bbbike/mapserver/brb/Makefile"
	[ -d ${CURDIR}/$(HTDOCS)/mapserver/brb/fonts ] || \
	    mkdir ${CURDIR}/$(HTDOCS)/mapserver/brb/fonts
	cp -pf /usr/X11R6/lib/X11/fonts/ttf/LucidaSansRegular.ttf \
	    ${CURDIR}/$(HTDOCS)/mapserver/brb/fonts

prepare-touren-dist:
	[ -d ${CURDIR}/$(HTDOCS)/mapserver/touren ] || \
	    mkdir -p ${CURDIR}/$(HTDOCS)/mapserver/touren
	chmod 755 ${CURDIR}/$(HTDOCS)/mapserver/touren
	cp -pf ${BBBIKE_ROOT_DIR}/mapserver/touren/*.trk \
	    ${CURDIR}/$(HTDOCS)/mapserver/touren

prepare-routopedia-dist:
	cd ${BBBIKE_ROOT_DIR}/routopedia && ${MAKE} distcheck
	(umask 022; cd ${BBBIKE_ROOT_DIR}/routopedia && perl "-MExtUtils::Manifest=manicopy,maniread" -e "manicopy(maniread(),'${CURDIR}/routopedia', 'best');")

test:
	cd ${.CURDIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=http://${BBBIKE_RADZEIT_HOST}/cgi-bin \
	BBBIKE_TEST_CGIURL=http://${BBBIKE_RADZEIT_HOST}/cgi-bin/bbbike.cgi \
	BBBIKE_TEST_WAPURL=http://${BBBIKE_RADZEIT_HOST}/cgi-bin/wapbbbike.cgi \
	BBBIKE_TEST_HTMLDIR=http://${BBBIKE_RADZEIT_HOST}/BBBike \
	    perl -MTest::Harness -e 'runtests(@ARGV)' \
		${TESTS}

test-on-remote:
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_RADZEIT_USER} ${BBBIKE_RADZEIT_HOST} '\
	cd ${BBBIKE_RADZEIT_APACHE_DIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=http://${BBBIKE_RADZEIT_HOST}/cgi-bin \
	BBBIKE_TEST_CGIURL=http://${BBBIKE_RADZEIT_HOST}/cgi-bin/bbbike.cgi \
	BBBIKE_TEST_WAPURL=http://${BBBIKE_RADZEIT_HOST}/cgi-bin/wapbbbike.cgi \
	BBBIKE_TEST_HTMLDIR=http://${BBBIKE_RADZEIT_HOST}/BBBike \
	    perl -MTest::Harness -e "runtests(@ARGV)" \
		${TESTS} \
	'

test-on-remote-and-send-mail:
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_RADZEIT_USER} ${BBBIKE_RADZEIT_HOST} '\
	cd ${BBBIKE_RADZEIT_APACHE_DIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=http://${BBBIKE_RADZEIT_HOST}/cgi-bin \
	BBBIKE_TEST_CGIURL=http://${BBBIKE_RADZEIT_HOST}/cgi-bin/bbbike.cgi \
	BBBIKE_TEST_WAPURL=http://${BBBIKE_RADZEIT_HOST}/cgi-bin/wapbbbike.cgi \
	BBBIKE_TEST_HTMLDIR=http://${BBBIKE_RADZEIT_HOST}/BBBike \
	    (perl -MTest::Harness -e "runtests(@ARGV)" \
		${TESTS} | mail slaven@rezic.de ) & \
	'

test-local:
	cd ${.CURDIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=${LOCAL_CGI_URL} \
	BBBIKE_TEST_CGIURL=${LOCAL_CGI_URL}/bbbike.cgi \
	BBBIKE_TEST_WAPURL=${LOCAL_CGI_URL}/wapbbbike.cgi \
	BBBIKE_TEST_MAPSERVERURL=http://localhost/~eserte/cgi/mapserv.cgi \
	BBBIKE_TEST_HTMLDIR=${LOCAL_HTML_URL} \
	    perl -MTest::Harness -e 'runtests(@ARGV)' \
		${TESTS}

test-radzeit-old:
	cd ${.CURDIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=${RADZEIT_OLD_URL}/cgi-bin \
	BBBIKE_TEST_CGIURL=${RADZEIT_OLD_URL}/cgi-bin/bbbike.cgi \
	BBBIKE_TEST_WAPURL=${RADZEIT_OLD_URL}/cgi-bin/wapbbbike.cgi \
	BBBIKE_TEST_HTMLDIR=${RADZEIT_OLD_URL}/BBBike \
	    perl -MTest::Harness -e "runtests(@ARGV)" \
		${TESTS}

server-permissions:
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_RADZEIT_USER} ${BBBIKE_RADZEIT_HOST} '\
		chown ${WWW_USER} "${BBBIKE_RADZEIT_APACHE_DIR}/BBBike/tmp/berlin_map*"; \
		chown 644 "${BBBIKE_RADZEIT_APACHE_DIR}/BBBike/tmp/berlin_map*"; \
		chmod 777 "${BBBIKE_RADZEIT_APACHE_DIR}/BBBike/tmp"; \
		chown ${WWW_USER} "${BBBIKE_RADZEIT_APACHE_DIR}/$(HTDOCS)/mapserver/brb"; \
		chown ${WWW_USER} "${BBBIKE_RADZEIT_APACHE_DIR}/$(HTDOCS)/mapserver/brb/tmp"; \
	'

backup:
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_RADZEIT_USER} ${BBBIKE_RADZEIT_HOST} '\
	    cd ${BBBIKE_RADZEIT_APACHE_DIR} && \
	    tar cfpz /tmp/BBBike-`date +%Y%m%d`-backup.tar.gz \
	    BBBike \
	    cgi-bin/bbbike.cgi cgi-bin/bbbike.cgi.config cgi-bin/wapbbbike.cgi \
	    $(HTDOCS)/mapserver \
	'

backup-local:
	${SSH_PROG_AND_ARGS} -l eserte localhost '\
	    cd $(.CURDIR) && \
	    tar cfpz /tmp/BBBike-`date +%Y%m%d`-backup.tar.gz \
	    BBBike \
	    cgi-bin/bbbike.cgi cgi-bin/bbbike.cgi.config cgi-bin/wapbbbike.cgi \
	    $(HTDOCS)/mapserver \
	'

remote-cleanup:
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_RADZEIT_USER} ${BBBIKE_RADZEIT_HOST} '\
	    cd ${BBBIKE_RADZEIT_APACHE_DIR}/$(HTDOCS)/mapserver/brb && \
	    ./cleanup -f -agehours 24 \
	'
