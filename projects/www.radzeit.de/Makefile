#
# $Id: Makefile,v 1.29 2003/12/05 23:27:28 eserte Exp eserte $
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

# The local service is available on
#   ${LOCAL_URL}/cgi-bin/bbbike.cgi

#BBBIKE_ROOT_DIR?=	$(HOME)/src/bbbike
BBBIKE_ROOT_DIR?=	${.CURDIR}/../..
CURDIR=			${.CURDIR}
LOCAL_URL?=		http://radzeit.herceg.de
DATA_DIR=		data_corrected

DEPLOY_TARGETS=		prepare-bbbike-data \
			prepare-bbbike-dist \
			prepare-mapserver-dist \
			prepare-touren-dist \
			rsync \
			test-on-remote
DEPLOY_LOCAL_TARGETS=	${DEPLOY_TARGETS:S/prepare-mapserver-dist/prepare-mapserver-local-dist/:S/rsync//:S/test$/test-local/:S/test-on-remote/test-local/}

RSYNC_PROG?=	rsync
RSYNC_ARGS=	-e ssh -Pvz -r -t --links --cvs-exclude --exclude-from .rsync.exclude
RSYNC_DEST?=	${BBBIKE_RADZEIT_USER}@${BBBIKE_RADZEIT_HOST}:${BBBIKE_RADZEIT_APACHE_DIR}
RSYNC_SRCDEST?=	. ${RSYNC_DEST}

# XXX Should be set from mapserver/brb/Makefile:
WWW_USER=	www

.if ${OSTYPE} == "linux"
XARGS_REPL?=	xargs --replace=%
.else
XARGS_REPL?=	xargs -J %
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
TARGET=radzeit.herceg.de
.endif
.endfor
.endif

.ifndef TARGET
.if make(deploy) || make(tkrsync) || make(backup) || make(test) || make(prepare-bbbike-dist-data) || make(rsync) || make(rsync-bbbike-data)
TARGET=radzeit
.elif make(deploy-local) || make(backup-local)
.if ${HOST} == "devpc01.iconmobile.de"
TARGET=devpc01
.else
TARGET=radzeit.herceg.de
.endif
.else
.error "Please set TARGET to radzeit or radzeit.herceg.de"
.endif
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

rsync-bbbike-data:
	${RSYNC} ${RSYNC_ARGS} \
	    BBBike/misc/temp_blockings/ ${RSYNC_DEST}/BBBike/misc/temp_blockings/
	${RSYNC} ${RSYNC_ARGS} \
	    BBBike/data/ ${RSYNC_DEST}/BBBike/data/

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
	cd $(BBBIKE_ROOT_DIR)/data && ${MAKE} all slow-checks
	cd $(BBBIKE_ROOT_DIR)/data_corrected && ${MAKE} init all mapfiles
#XXX .if "${DATA_DIR}" != "data" && "${DATA_DIR}" != "data_corrected"
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE}
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
	cp -pf ${BBBIKE_ROOT_DIR}/t/cgihead.t \
	       ${BBBIKE_ROOT_DIR}/t/cgi.t     \
	       ${BBBIKE_ROOT_DIR}/t/wapcgi.t  ${CURDIR}/BBBike/t

prepare-bbbike-dist-prog-stadtplan:
	cp -pf ${BBBIKE_ROOT_DIR}/projects/www.berliner-stadtplan.com/lib/BBBikeDraw/BerlinerStadtplan.pm ${CURDIR}/BBBike/BBBikeDraw/

prepare-bbbike-dist-data:
	@echo "XXX The following command will fail because 'RCS' cannot be copied"
	# XXX only copy the stuff which is also specified in MANIFEST
	# then the "-" can also go
	-cp -pf ${BBBIKE_ROOT_DIR}/${DATA_DIR}/* \
	    ${CURDIR}/BBBike/data/
	-rm -f ${CURDIR}/BBBike/data/conv.db*
	[ -d ${CURDIR}/BBBike/misc/temp_blockings ] || \
	    mkdir -p ${CURDIR}/BBBike/misc/temp_blockings
	find ${BBBIKE_ROOT_DIR}/misc/temp_blockings/ -maxdepth 1 -type f ! -name "*~" | ${XARGS_REPL} cp -pf % ${CURDIR}/BBBike/misc/temp_blockings/
	-cp -pf ${BBBIKE_ROOT_DIR}/misc/temp_blockings/* \
	    ${CURDIR}/BBBike/misc/temp_blockings/
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
	    ln -s $(HOME)/www/cgi/mapserv.cgi ${CURDIR}/cgi-bin/mapserv
	@echo "Compile mapserv manually on ${BBBIKE_RADZEIT_HOST}"
	[ -d ${CURDIR}/htdocs/mapserver/brb ] || \
	    mkdir -p ${CURDIR}/htdocs/mapserver/brb

prepare-mapserver-dist-main:
	cd ${BBBIKE_ROOT_DIR}/mapserver/brb && \
	    ${MAKE} dist-radzeit
	cp -Rpf /tmp/radzeit_mapserver_dist/* ${CURDIR}/htdocs/mapserver/brb/
	rm -f ${CURDIR}/.not_rsyncable

prepare-mapserver-dist-local-main:
	touch ${CURDIR}/.not_rsyncable
	cd ${BBBIKE_ROOT_DIR}/mapserver/brb && \
	    ${MAKE} dist-radzeit.herceg.de
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
	    perl -MTest::Harness -e "runtests(@ARGV)" \
		cgihead.t \
		cgi.t \
		wapcgi.t \
	'

test-local:
	cd ${.CURDIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=${LOCAL_URL}/cgi-bin \
	BBBIKE_TEST_CGIURL=${LOCAL_URL}/cgi-bin/bbbike.cgi \
	BBBIKE_TEST_WAPURL=${LOCAL_URL}/cgi-bin/wapbbbike.cgi \
	BBBIKE_TEST_MAPSERVERURL=http://localhost/~eserte/cgi/mapserv.cgi \
	    perl -MTest::Harness -e 'runtests(@ARGV)' \
		cgihead.t \
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
