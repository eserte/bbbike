#
# $Id: Makefile,v 1.38 2004/08/21 23:11:30 eserte Exp eserte $
#

# Targets:
#  check:	Show what would be rsync'ed from the current directory
#  rsync:	Do the rsync. This will not be permitted if the make system
#		detects that the contents are prepared for the local server.
#  tkrsync:	Execute the "tkrsync" for manually syncing parts of the tree.
#  test:	Test the remote server from the local host.
#  test-on-remote:	Test the remote server from the remote host.
#  deploy:	Do everything from preparing to rsync'ing.
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

DEPLOY_TARGETS=		prepare-bbbike-data \
			prepare-bbbike-dist \
			prepare-mapserver-dist \
			prepare-touren-dist \
			rsync \
			test-on-remote
# XXX test-on-remote-and-send-mail
DEPLOY_LOCAL_TARGETS=	${DEPLOY_TARGETS:S/prepare-mapserver-dist/prepare-mapserver-local-dist/:S/rsync//:S/test$/test-local/:S/test-on-remote/test-local/}

RSYNC_PROG?=	rsync
RSYNC_ARGS=	-e ssh -Pvz -r -t --links --copy-unsafe-links --exclude-from .rsync.exclude
RSYNC_DEST?=	${BBBIKE_RADZEIT_USER}@${BBBIKE_RADZEIT_HOST}:${BBBIKE_RADZEIT_APACHE_DIR}
RSYNC_SRCDEST?=	. ${RSYNC_DEST}

# XXX Should be set from mapserver/brb/Makefile:
WWW_USER=	www

.if ${OSTYPE} == "linux"
XARGS_REPL?=	xargs --replace=%
.else
XARGS_REPL?=	xargs -J %
.endif

MAPSERVER_EXE?=	$(HOME)/www/cgi/mapserv.cgi

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
.if make(deploy) || make(tkrsync) || make(backup) || make(test) || make(prepare-bbbike-dist-data) || make(rsync) || make(rsync-bbbike-data) || make(clean-cache-files-on-remote)
TARGET=radzeit
.elif make(deploy-local) || make(backup-local) || make(test-local)
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
NO_BERLINER_STADTPLAN=	yes
.endif

.include "${BBBIKE_ROOT_DIR}/mapserver/brb/Makefile.${TARGET}.inc"

all:

######################################################################
# Top level targets
check:
	${RSYNC} --dry-run ${RSYNC_ARGS} ${RSYNC_SRCDEST}

rsync:
	[ ! -e ${CURDIR}/.not_rsyncable ] || ( echo "Not rsyncable!"; false )
	[ ! -e ${CURDIR}/.rsync_block ] || ( echo "Not rsyncable because:"; cat ${CURDIR}/.rsync_block; false )
	${RSYNC} ${RSYNC_ARGS} ${RSYNC_SRCDEST}

rsync-bbbike:
	@echo NYI
	false

rsync-mapserver:
	@echo NYI
	false

rsync-bbbike-data:	clean-cache-files-on-remote
	${RSYNC} ${RSYNC_ARGS} \
	    BBBike/data/ ${RSYNC_DEST}/BBBike/data/

clean-cache-files-on-remote:
	ssh -l ${BBBIKE_RADZEIT_USER} ${BBBIKE_RADZEIT_HOST} \
	    rm /tmp/b_de_\*

# use -t in rsync?
tkrsync:
	tkrsync -showchanges -rsync="-zrt --cvs-exclude --exclude-from .rsync.exclude" ${RSYNC_SRCDEST}

deploy:	${DEPLOY_TARGETS}

deploy-local: ${DEPLOY_LOCAL_TARGETS}

test-makefile:
	${MAKE} -n deploy-local > /tmp/test-makefile.cmd
	perl -e 'while(<ARGV>) {print STDERR "\a$$_> "; <STDIN>; system($$_) and warn $$?}' /tmp/test-makefile.cmd

#XXX .NOTPARALLEL: rsync

######################################################################
# Sub targets
# Reihenfolge sollte hoffentlich richtig sein
prepare-bbbike-data:
	$(BBBIKE_ROOT_DIR)/miscsrc/check_bbbike_temp_blockings
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE} all
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE} slow-checks
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE} mapfiles
#XXX .if "${DATA_DIR}" != "data" && "${DATA_DIR}" != "data_corrected"
#XXX	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE}
#XXX .endif

prepare-bbbike-dist:	prepare-bbbike-dist-prog prepare-bbbike-dist-data

prepare-bbbike-dist-prog: 	prepare-bbbike-dist-prog-bbbike \
				prepare-bbbike-dist-prog-stadtplan

prepare-bbbike-dist-prog-bbbike:
	cd ${BBBIKE_ROOT_DIR} && ${MAKE} distcheck
	(umask 022; cd ${BBBIKE_ROOT_DIR} && perl "-MExtUtils::Manifest=manicopy,maniread" -e "manicopy(maniread(),'${CURDIR}/BBBike', 'best');")
	[ -d ${CURDIR}/cgi-bin ] || mkdir ${CURDIR}/cgi-bin
	[ -d ${CURDIR}/htdocs  ] || mkdir ${CURDIR}/htdocs
	chmod 755 ${CURDIR}/cgi-bin ${CURDIR}/htdocs
.for i in \
	  bbbike.cgi wapbbbike.cgi \
	  mapserver_address.cgi mapserver_comment.cgi mapserver_setcoord.cgi
	rm -f ${CURDIR}/cgi-bin/$(i)
	cd ${CURDIR}/cgi-bin && ln -s ../BBBike/cgi/$(i)
.endfor
	cp -pf ${BBBIKE_ROOT_DIR}/cgi/bbbike-radzeit.cgi.config \
	       ${CURDIR}/BBBike/cgi/bbbike.cgi.config
	rm -f ${CURDIR}/cgi-bin/bbbike.cgi.config
	cd ${CURDIR}/cgi-bin && ln -s ../BBBike/cgi/bbbike.cgi.config
	chmod ugo+r ${CURDIR}/BBBike/cgi/bbbike.cgi.config
	@echo "Maybe create bbbike2.cgi and bbbike2.cgi.config"
	[ -e ${CURDIR}/htdocs/BBBike ] || \
	    ln -s ../BBBike ${CURDIR}/htdocs/BBBike
	@echo "Do 'ln -s ../BBBike ${BBBIKE_RADZEIT_APACHE_DIR}/htdocs/BBBike' manually on server"
	chmod 777 ${CURDIR}/BBBike/tmp
	@echo "Maybe chown ${BBBIKE_RADZEIT_APACHE_DIR}/BBBike/tmp on ${BBBIKE_RADZEIT_HOST} to www"
	chmod ugo+r ${CURDIR}/cgi-bin/*
	[ -d ${CURDIR}/BBBike/miscsrc ] || \
	    mkdir ${CURDIR}/BBBike/miscsrc
	cp -pf ${BBBIKE_ROOT_DIR}/miscsrc/bbd2esri \
	    ${CURDIR}/BBBike/miscsrc/
	[ -d ${CURDIR}/BBBike/t ] || \
	    mkdir ${CURDIR}/BBBike/t
	cp -pf ${BBBIKE_ROOT_DIR}/t/cgihead.t 		\
	       ${BBBIKE_ROOT_DIR}/t/cgi-mechanize.t	\
	       ${BBBIKE_ROOT_DIR}/t/cgi.t     		\
	       ${BBBIKE_ROOT_DIR}/t/wapcgi.t  ${CURDIR}/BBBike/t
	cp -pf ${BBBIKE_ROOT_DIR}/html/Makefile		\
	       ${BBBIKE_ROOT_DIR}/html/newstreetform.tpl.html	\
	    ${CURDIR}/BBBike/html
	cd ${CURDIR}/BBBike/html && \
	    ${MAKE} newstreetform.html CGIDIR=http://${BBBIKE_RADZEIT_HOST}/cgi-bin

prepare-bbbike-dist-prog-stadtplan:
	[ "${NO_BERLINER_STADTPLAN}" = "yes" ] && true || (cp -pf ${BBBIKE_ROOT_DIR}/projects/www.berliner-stadtplan.com/lib/BBBikeDraw/BerlinerStadtplan.pm ${CURDIR}/BBBike/BBBikeDraw/)

prepare-bbbike-dist-data:	prepare-bbbike-dist-data-datadir \
				prepare-bbbike-dist-data-temp-blockings-dir \
				prepare-bbbike-dist-data-teasers

# Usually data/* is already hardlinkes against the originals, so
# no additional copying for data/* is necessary
prepare-bbbike-dist-data-datadir:

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
	[ -d ${CURDIR}/htdocs/mapserver/brb ] || \
	    mkdir -p ${CURDIR}/htdocs/mapserver/brb

prepare-mapserver-dist-main:
	cd ${BBBIKE_ROOT_DIR}/mapserver/brb && \
	    ${MAKE} dist-any TARGET=radzeit
	cp -Rpf /tmp/radzeit_mapserver_dist/* ${CURDIR}/htdocs/mapserver/brb/
	rm -f ${CURDIR}/.not_rsyncable

prepare-mapserver-dist-local-main:
	touch ${CURDIR}/.not_rsyncable
	cd ${BBBIKE_ROOT_DIR}/mapserver/brb && \
	    ${MAKE} dist-any TARGET=radzeit.herceg.de
	cp -Rpf /tmp/radzeit_mapserver_dist/* ${CURDIR}/htdocs/mapserver/brb/
	chmod 777 ${CURDIR}/htdocs/mapserver/brb
	chmod 777 ${CURDIR}/htdocs/mapserver/brb/tmp

prepare-mapserver-dist-post:
	@echo "XXX Check permissions of htdocs/mapserver/brb and maybe WWWUSER in bbbike/mapserver/brb/Makefile"
	[ -d ${CURDIR}/htdocs/mapserver/brb/fonts ] || \
	    mkdir ${CURDIR}/htdocs/mapserver/brb/fonts
	cp -pf /usr/X11R6/lib/X11/fonts/ttf/LucidaSansRegular.ttf \
	    ${CURDIR}/htdocs/mapserver/brb/fonts

prepare-touren-dist:
	[ -d ${CURDIR}/htdocs/mapserver/touren ] || \
	    mkdir -p ${CURDIR}/htdocs/mapserver/touren
	chmod 755 ${CURDIR}/htdocs/mapserver/touren
	cp -pf ${BBBIKE_ROOT_DIR}/mapserver/touren/*.trk \
	    ${CURDIR}/htdocs/mapserver/touren

test:
	cd ${.CURDIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=http://${BBBIKE_RADZEIT_HOST}/cgi-bin \
	BBBIKE_TEST_CGIURL=http://${BBBIKE_RADZEIT_HOST}/cgi-bin/bbbike.cgi \
	BBBIKE_TEST_WAPURL=http://${BBBIKE_RADZEIT_HOST}/cgi-bin/wapbbbike.cgi \
	BBBIKE_TEST_HTMLDIR=http://${BBBIKE_RADZEIT_HOST}/BBBike \
	    perl -MTest::Harness -e 'runtests(@ARGV)' \
		cgihead.t \
		cgi.t \
		wapcgi.t

test-on-remote:
	ssh -l ${BBBIKE_RADZEIT_USER} ${BBBIKE_RADZEIT_HOST} '\
	cd ${BBBIKE_RADZEIT_APACHE_DIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=http://${BBBIKE_RADZEIT_HOST}/cgi-bin \
	BBBIKE_TEST_CGIURL=http://${BBBIKE_RADZEIT_HOST}/cgi-bin/bbbike.cgi \
	BBBIKE_TEST_WAPURL=http://${BBBIKE_RADZEIT_HOST}/cgi-bin/wapbbbike.cgi \
	BBBIKE_TEST_HTMLDIR=http://${BBBIKE_RADZEIT_HOST}/BBBike \
	    perl -MTest::Harness -e "runtests(@ARGV)" \
		cgihead.t \
		cgi-mechanize.t \
		cgi.t \
		wapcgi.t \
	'

test-on-remote-and-send-mail:
	ssh -l ${BBBIKE_RADZEIT_USER} ${BBBIKE_RADZEIT_HOST} '\
	cd ${BBBIKE_RADZEIT_APACHE_DIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=http://${BBBIKE_RADZEIT_HOST}/cgi-bin \
	BBBIKE_TEST_CGIURL=http://${BBBIKE_RADZEIT_HOST}/cgi-bin/bbbike.cgi \
	BBBIKE_TEST_WAPURL=http://${BBBIKE_RADZEIT_HOST}/cgi-bin/wapbbbike.cgi \
	BBBIKE_TEST_HTMLDIR=http://${BBBIKE_RADZEIT_HOST}/BBBike \
	    (perl -MTest::Harness -e "runtests(@ARGV)" \
		cgihead.t \
		cgi-mechanize.t \
		cgi.t \
		wapcgi.t | mail slaven@rezic.de ) & \
	'

test-local:
	cd ${.CURDIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=${LOCAL_CGI_URL} \
	BBBIKE_TEST_CGIURL=${LOCAL_CGI_URL}/bbbike.cgi \
	BBBIKE_TEST_WAPURL=${LOCAL_CGI_URL}/wapbbbike.cgi \
	BBBIKE_TEST_MAPSERVERURL=http://localhost/~eserte/cgi/mapserv.cgi \
	BBBIKE_TEST_HTMLDIR=${LOCAL_HTML_URL} \
	    perl -MTest::Harness -e 'runtests(@ARGV)' \
		cgihead.t \
		cgi-mechanize.t \
		cgi.t \
		wapcgi.t

server-permissions:
	ssh -l ${BBBIKE_RADZEIT_USER} ${BBBIKE_RADZEIT_HOST} '\
		chown ${WWW_USER} "${BBBIKE_RADZEIT_APACHE_DIR}/htdocs/BBBike/tmp/berlin_map*"; \
		chown 644 "${BBBIKE_RADZEIT_APACHE_DIR}/htdocs/BBBike/tmp/berlin_map*"; \
		chmod 777 "${BBBIKE_RADZEIT_APACHE_DIR}/htdocs/BBBike/tmp"; \
	'

backup:
	ssh -l ${BBBIKE_RADZEIT_USER} ${BBBIKE_RADZEIT_HOST} '\
	    cd ${BBBIKE_RADZEIT_APACHE_DIR} && \
	    tar cfpz /tmp/BBBike-`date +%Y%m%d`-backup.tar.gz \
	    BBBike \
	    cgi-bin/bbbike.cgi cgi-bin/bbbike.cgi.config cgi-bin/wapbbbike.cgi \
	    htdocs/mapserver \
	'

backup-local:
	ssh -l eserte localhost '\
	    cd $(.CURDIR) && \
	    tar cfpz /tmp/BBBike-`date +%Y%m%d`-backup.tar.gz \
	    BBBike \
	    cgi-bin/bbbike.cgi cgi-bin/bbbike.cgi.config cgi-bin/wapbbbike.cgi \
	    htdocs/mapserver \
	'

remote-cleanup:
	ssh -l ${BBBIKE_RADZEIT_USER} ${BBBIKE_RADZEIT_HOST} '\
	    cd ${BBBIKE_RADZEIT_APACHE_DIR}/htdocs/mapserver/brb && \
	    ./cleanup -f -agehours 24 \
	'
