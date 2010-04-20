#
# $Id: Makefile,v 1.112 2008/10/06 22:00:01 eserte Exp $
#

# Targets:
#  check:	Show what would be rsync'ed from the current directory
#  rsync:	Do the rsync. This will not be permitted if the make system
#		detects that the contents are prepared for the local server.
#  rsync-bbbike-data: Do the rsync of only the data directory. This is
#		also allowed if prepared for the local server.
#  rsync-temp-blockings: Do the rsync of just the "temp-blockings" part of
#		the data. Also allowed if prepared for the local server.
#  test:	Test the remote server from the local host (and one test on
#		the remote server).
#  test-local:	Run all tests locally.
#  deploy:	Do everything from preparing to rsync'ing and testing.
#  deploy-local:	Prepare a local distribution for testing. Do not rsync.
#  test-makefile:	Same as deploy-local, but each make command has to
#			be confirmed.
#
# Make variables:
#  NO_PARALLEL=1  Do not build and test in parallel.
# 
# It is required that the target web server has "FollowSymLinks" on.

# The local service is available on
#   ${LOCAL_URL}/cgi-bin/bbbike.cgi

#BBBIKE_ROOT_DIR?=	$(HOME)/src/bbbike
BBBIKE_ROOT_DIR?=	${.CURDIR}/../..
CURDIR=			${.CURDIR}
LOCAL_URL?=		http://bbbike.hosteurope.herceg.de
LOCAL_CGI_URL?=		${LOCAL_URL}/cgi-bin
LOCAL_HTML_URL?=	${LOCAL_URL}/BBBike
DATA_DIR=		data
TEMP_BLOCKINGS_DIR=	data/temp_blockings
BBBIKE_HOSTEUROPE_SSH_HOST?=	${BBBIKE_HOSTEUROPE_HOST}
STERNFAHRT_YEAR?=	2007
KREISFAHRT_YEAR?=	2007

EXTRA_MISCSRC_FILES=	bbd2esri winter_optimization.pl
EXTRA_MISC_FILES=	gpx.xsd
EXTRA_HTML_FILES=	Makefile newstreetform.tpl.html \
			opensearch/bbbike-opensearch.tpl.src \
			opensearch/bbbike-opensearch.tpl.xml \
			opensearch/opensearch.html \
			opensearch/opensearch.js
CGI_FILES=		bbbike.cgi \
			bbbike-data.cgi \
			bbbike-snapshot.cgi \
			bbbikegooglemap.cgi \
			wapbbbike.cgi \
			mapserver_address.cgi \
			mapserver_comment.cgi \
			mapserver_setcoord.cgi
TESTS_ON_REMOTE?=	basic.t \
			strassen-gpx.t \
			bbbikedraw.t
TESTS_FROM_LOCAL=	cgihead.t \
			cgi-mechanize.t \
			cgi.t \
			cgi-test.t \
			bbbikegooglemap.t \
			radzeit.t \
			wapcgi.t \
			wwwdata.t
TESTS_SERVER_ON_REMOTE=	
TESTS=			$(TESTS_ON_REMOTE) $(TESTS_SERVER_ON_REMOTE) $(TESTS_FROM_LOCAL)
TESTS_ADD=		BBBikeTest.pm bbbikedraw.t
HTDOCS=			public

# XXX maybe use test-on-remote-and-send-mail (after tests)
DEPLOY_TARGETS=			prepare-bbbike-data \
				prepare-mapserver-data \
				prepare-bbbike-dist \
				prepare-mapserver-dist \
				rsync \
				init-environment \
				test \
				create-all-maps \
				post-deploy-info

# only bbbike data, no program, no mapserver
DEPLOY_DATA_TARGETS=		prepare-bbbike-data \
				prepare-bbbike-dist \
				rsync-bbbike-data \
				test

# local deployment
DEPLOY_LOCAL_NO_TEST_TARGETS=	prepare-bbbike-data \
				prepare-mapserver-data \
				prepare-bbbike-dist \
				prepare-mapserver-local-dist \
				init-local-environment

DEPLOY_LOCAL_TARGETS=		${DEPLOY_LOCAL_NO_TEST_TARGETS} \
				test-local

DEPLOY_LOCAL_DATA_TARGETS=	prepare-bbbike-data \
				prepare-bbbike-dist \
				test-local

SSH_PROG_AND_ARGS?=	ssh
RSYNC_PROG?=	rsync
RSYNC_ARGS=	-e "${SSH_PROG_AND_ARGS}" -Pvz -r -t --links --copy-unsafe-links --delay-updates --exclude-from .rsync.exclude
#RSYNC_ARGS=	-e "${SSH_PROG_AND_ARGS}" -Pvz -r -t --links --copy-unsafe-links --exclude-from .rsync.exclude
RSYNC_ARGS_MS=	${RSYNC_ARGS:S/.rsync.exclude/\/tmp\/mapserver.rsync.exclude/}
RSYNC_DEST?=	${BBBIKE_HOSTEUROPE_USER}@${BBBIKE_HOSTEUROPE_SSH_HOST}:${BBBIKE_HOSTEUROPE_APACHE_DIR}
RSYNC_SRCDEST?=	. ${RSYNC_DEST}

# XXX Should be set from mapserver/brb/Makefile:
WWW_USER?=	www-data
WWW_GROUP?=	www-data

OSNAME!=	uname
.if ${OSNAME} == "linux"
OS_LINUX=	yes
.else
OS_LINUX=
.endif

.if ${OS_LINUX}
XARGS_REPL?=	xargs --replace=%
.else
XARGS_REPL?=	xargs -J %
.endif

.ifdef NO_PARALLEL
BUILD_JOBS=1
TEST_JOBS=1
.else
BUILD_JOBS=4
TEST_JOBS=3
.endif

.if exists(/usr/lib/cgi-bin/mapserv)
MAPSERVER_EXE?=	/usr/lib/cgi-bin/mapserv
.else
MAPSERVER_EXE?=	$(HOME)/www/cgi/mapserv.cgi
.endif

## Prefer cp, so I may make changes in ~/src/bbbike and still have
## a copy on my disk similar to the server contents.
#MKDIST_STYLE=	best
MKDIST_STYLE=	cp


.ifndef TARGET
.for t in ${DEPLOY_TARGETS}
.if make($t)
TARGET=hosteurope
.endif
.endfor
.endif

.ifndef TARGET
.for t in ${DEPLOY_LOCAL_TARGETS}
.if make($t)
.if ${HOST} == "devpc01.iconmobile.de"
TARGET=devpc01
.else
TARGET=bbbike.hosteurope.herceg.de
.endif
.endif
.endfor
.endif

.ifndef TARGET
.if   make(deploy)                   || \
      make(deploy-data)		     || \
      make(deploy-temp-blockings)    || \
      make(check)		     || \
      make(backup) 		     || \
      make(test)		     || \
      make(test-on-remote)	     || \
      make(test-on-remote-full)	     || \
      make(prepare-bbbike-dist-data) || \
      make(rsync)		     || \
      make(rsync-bbbike-data)	     || \
      make(rsync-mapserver)	     || \
      make(rsync-temp-blockings)     || \
      make(rsync-tests)		     || \
      make(clean-cache-files-on-remote) || \
      make(diff-temp-blockings)      || \
      make(prepare-kreisfahrt-dist)
TARGET=hosteurope
.elif make(deploy-local)         || \
      make(deploy-local-data)    || \
      make(deploy-local-no-test) || \
      make(backup-local)         || \
      make(test-local)
.if ${HOST} == "devpc01.iconmobile.de"
TARGET=devpc01
.else
TARGET=bbbike.hosteurope.herceg.de
.endif
.else
.error "Please set TARGET to hosteurope or bbbike.hosteurope.herceg.de"
.endif
.endif

.if ${TARGET} == "devpc01"
MAPSERVER_EXE=	$(HOME)/work2/mapserver/mapserv.cgi
LOCAL_URL=	http://localhost:8080/bbbike
LOCAL_CGI_URL=	http://localhost:8080/bbbike/cgi
LOCAL_HTML_URL=	http://localhost:8080/bbbike
DATA_DIR=	data
.endif

LOCAL_MAPSERVER_URL=	http://www/cgi-bin/mapserv

# The bbbike.cgi to test (stable or beta)
BBBIKECGI=		bbbike.cgi
.ifdef TEST_BETA
BBBIKECGI=		bbbike2.cgi
.endif

.ifndef TARGET_OS_DIST
TARGET_OS_DIST=		unknown
.endif

.include "${BBBIKE_ROOT_DIR}/mapserver/brb/Makefile.${TARGET}.inc"

all:

######################################################################
# Top level targets
check:
	${RSYNC} --dry-run ${RSYNC_ARGS} ${RSYNC_SRCDEST}

clean-cache-files-on-remote:
	-${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} \
	    rm /tmp/b_de_\*

RSYNC_RULES=		check-rsync-ok \
			do-rsync \
			clean-cache-files-on-remote \
			show-rsync-message \
			post-rsync-bbbike \
			post-rsync-bbbike-data
.ORDER:	$(RSYNC_RULES)	
rsync:	$(RSYNC_RULES)	

check-rsync-ok:
.ifndef RSYNC_FORCE
	[ ! -e ${CURDIR}/.not_rsyncable ] || ( echo "Not rsyncable! (force with RSYNC_FORCE)"; false )
	[ ! -e ${CURDIR}/.rsync_block ] || ( echo "Not rsyncable because:"; cat ${CURDIR}/.rsync_block; false )
.endif

do-rsync:
	-@mkdir -p .last
	-@date >> .last/start-do-rsync
	${RSYNC} ${RSYNC_ARGS} ${RSYNC_SRCDEST}
	-@date >> .last/do-rsync

rsync-bbbike:
	@echo NYI
	false

rsync-mapserver:	check-rsync-ok check-rsync-mapserver /tmp/mapserver.rsync.exclude
	${RSYNC_PROG} ${RSYNC_ARGS_MS} ${CURDIR}/public/mapserver/ ${BBBIKE_HOSTEUROPE_USER}@${BBBIKE_HOSTEUROPE_SSH_HOST}:${BBBIKE_HOSTEUROPE_APACHE_DIR}/${HTDOCS}/mapserver/

rsync-tests:
	${RSYNC_PROG} ${RSYNC_ARGS} --exclude tmp/ ${BBBIKE_ROOT_DIR}/t/ ${RSYNC_DEST}/BBBike/t/

/tmp/mapserver.rsync.exclude: .rsync.exclude
	perl -pe 's{^public/mapserver/}{}' $> > $@

check-rsync-mapserver:
	fgrep -q -s 'SHAPEPATH "${BBBIKE_HOSTEUROPE_APACHE_DIR}public/mapserver/brb/data"' ${CURDIR}/$(HTDOCS)/mapserver/brb/brb.map

check-rsync-data-ok:
	true

RSYNC_BBBIKE_DATA_RULES=check-rsync-data-ok \
			do-rsync-bbbike-data \
			clean-cache-files-on-remote \
			show-rsync-message \
			post-rsync-bbbike-data
.ORDER:			$(RSYNC_BBBIKE_DATA_RULES)
rsync-bbbike-data:	$(RSYNC_BBBIKE_DATA_RULES)

do-rsync-bbbike-data:
	-@mkdir -p .last
	-@date >> .last/start-do-rsync-bbbike-data
	${RSYNC} ${RSYNC_ARGS} \
	    BBBike/data/ ${RSYNC_DEST}/BBBike/data/
	-@date >> .last/do-rsync-bbbike-data

post-rsync-bbbike:
# bbbike-snapshot expects this file, but nothing of BBBike/tmp is
# rsync'ed by .rsync_exclude file
	-${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} \
	   "touch ${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/tmp/.keep_me"

post-rsync-bbbike-data:
	-@date >> .last/start-post-rsync-bbbike-data
	-${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} \
	   "rm -f ${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/tmp/winter_optimization*"
	-@date >> .last/post-rsync-bbbike-data

rsync-temp-blockings:
	-@mkdir -p .last
	-@date >> .last/start-post-rsync-bbbike-data
	${RSYNC} ${RSYNC_ARGS} \
	    BBBike/data/temp_blockings/ ${RSYNC_DEST}/BBBike/data/temp_blockings/
	-@date >> .last/rsync-temp-blockings

show-rsync-message:
	-[ ! -e ${CURDIR}/.rsync_message ] && true || cat ${CURDIR}/.rsync_message

.ORDER:			${DEPLOY_TARGETS}
deploy:			${DEPLOY_TARGETS}

.ORDER:			${DEPLOY_LOCAL_TARGETS}
deploy-local:		${DEPLOY_LOCAL_TARGETS}

.ORDER:			${DEPLOY_LOCAL_NO_TEST_TARGETS}
deploy-local-no-test:	${DEPLOY_LOCAL_NO_TEST_TARGETS}

.ORDER:			${DEPLOY_DATA_TARGETS}
deploy-data:		${DEPLOY_DATA_TARGETS}

.ORDER:			${DEPLOY_LOCAL_DATA_TARGETS}
deploy-local-data:	${DEPLOY_LOCAL_DATA_TARGETS}

deploy-temp-blockings:	check-temp-blockings-integrity-pre \
			prepare-bbbike-dist-data-temp-blockings-dir \
			check-temp-blockings-integrity \
			rsync-temp-blockings

test-makefile:
	${MAKE} -n deploy-local > /tmp/test-makefile.cmd
	perl -e 'while(<ARGV>) {print STDERR "\a$$_> "; <STDIN>; system($$_) and warn $$?}' /tmp/test-makefile.cmd

######################################################################
# Sub targets
# Reihenfolge sollte hoffentlich richtig sein

prepare-bbbike-data:	prepare-bbbike-data-parallel

prepare-bbbike-data-serial:
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE} all
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE} slow-checks

prepare-bbbike-data-parallel:
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && \
		(${MAKE} -j${BUILD_JOBS} all slow-checks; ${MAKE} all slow-checks)

# I used "mapfiles-without-reference-maps" instead of "mapfiles" here
# This was because the "mapfiles-reference-maps" rule took a lot of time
# (5 - 10 minutes), but visually it changed very little.
# But now it's not really slow anymore.
prepare-mapserver-data:
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE} mapfiles

prepare-bbbike-dist:	prepare-bbbike-dist-prog prepare-bbbike-dist-data

prepare-bbbike-dist-prog: 	prepare-bbbike-dist-prog-bbbike

prepare-bbbike-dist-prog-bbbike:	\
				prepare-bbbike-dist-prog-bbbike-copy \
				prepare-bbbike-dist-prog-bbbike-cgi \
				prepare-bbbike-dist-prog-bbbike-htdocs \
				prepare-bbbike-dist-prog-bbbike-tmp \
				prepare-bbbike-dist-prog-bbbike-t \
				prepare-bbbike-dist-prog-bbbike-miscsrc \
				prepare-bbbike-dist-prog-bbbike-misc \
				prepare-bbbike-dist-prog-bbbike-html \
				prepare-bbbike-dist-prog-bbbike-images

prepare-bbbike-dist-prog-bbbike-copy:
	cd ${BBBIKE_ROOT_DIR} && ${MAKE} distcheck
	(umask 022; cd ${BBBIKE_ROOT_DIR} && perl "-MExtUtils::Manifest=manicopy,maniread" -e "manicopy(maniread(),'${CURDIR}/BBBike', '${MKDIST_STYLE}');")

prepare-bbbike-dist-prog-bbbike-cgi:
	[ -d ${CURDIR}/cgi-bin ] || mkdir ${CURDIR}/cgi-bin
	chmod 755 ${CURDIR}/cgi-bin
.for i in ${CGI_FILES}
	rm -f ${CURDIR}/cgi-bin/$(i)
	cd ${CURDIR}/cgi-bin && ln -s ../BBBike/cgi/$(i)
.endfor
# Create bbbike.cgi configuration
	cp -pf ${BBBIKE_ROOT_DIR}/cgi/bbbike-hosteurope.cgi.config \
	       ${CURDIR}/BBBike/cgi/bbbike.cgi.config
	rm -f ${CURDIR}/cgi-bin/bbbike.cgi.config
	cd ${CURDIR}/cgi-bin && ln -s ../BBBike/cgi/bbbike.cgi.config
	chmod ugo+r ${CURDIR}/BBBike/cgi/bbbike.cgi.config
# Create bbbike2.cgi link
	rm -f ${CURDIR}/cgi-bin/bbbike2.cgi
	cd ${CURDIR}/cgi-bin && ln -s bbbike.cgi bbbike2.cgi
# Create bbbike2.cgi configuration
	cp -pf ${BBBIKE_ROOT_DIR}/cgi/bbbike2-hosteurope.cgi.config \
	       ${CURDIR}/BBBike/cgi/bbbike2.cgi.config
	rm -f ${CURDIR}/cgi-bin/bbbike2.cgi.config
	cd ${CURDIR}/cgi-bin && ln -s ../BBBike/cgi/bbbike2.cgi.config
	chmod ugo+r ${CURDIR}/BBBike/cgi/bbbike2.cgi.config
# Create bbbikegooglemap2.cgi link
	rm -f ${CURDIR}/cgi-bin/bbbikegooglemap2.cgi
	cd ${CURDIR}/cgi-bin && ln -s bbbikegooglemap.cgi bbbikegooglemap2.cgi
# Create bbbike-test.cgi link
	rm -f ${CURDIR}/cgi-bin/bbbike-test.cgi
	cd ${CURDIR}/cgi-bin && ln -s bbbike.cgi bbbike-test.cgi
# Create bbbike-test.cgi configuration
	rm -f ${CURDIR}/cgi-bin/bbbike-test.cgi.config
	cd ${CURDIR}/cgi-bin && ln -s ../BBBike/cgi/bbbike-test.cgi.config
	chmod ugo+r ${CURDIR}/BBBike/cgi/bbbike-test.cgi.config
# Create links for English version
	rm -f ${CURDIR}/cgi-bin/bbbike.en.cgi
	cd ${CURDIR}/cgi-bin && ln -s bbbike.cgi bbbike.en.cgi
	rm -f ${CURDIR}/cgi-bin/bbbike2.en.cgi
	cd ${CURDIR}/cgi-bin && ln -s bbbike.cgi bbbike2.en.cgi
# Fix permissions
# Make sure that /usr/lib/cgi-bin/* isn't touched, otherwise make will fail
	(cd ${CURDIR}/cgi-bin && chmod ugo+r `find . -maxdepth 1 | xargs -L1 readlink | grep -v /usr/lib/cgi-bin`)
	@echo "Maybe create bbbike2.cgi and bbbike2.cgi.config"

prepare-bbbike-dist-prog-bbbike-htdocs:
	[ -d ${CURDIR}/$(HTDOCS)  ] || mkdir ${CURDIR}/$(HTDOCS)
	chmod 755 ${CURDIR}/$(HTDOCS)
	[ -e ${CURDIR}/$(HTDOCS)/BBBike ] || \
	    ln -s ../BBBike ${CURDIR}/$(HTDOCS)/BBBike
	@echo "Do 'ln -s ../BBBike ${BBBIKE_HOSTEUROPE_APACHE_DIR}/$(HTDOCS)/BBBike' manually on server"

prepare-bbbike-dist-prog-bbbike-images:	prepare-sternfahrt2005-dist-images \
					prepare-sternfahrt${STERNFAHRT_YEAR}-dist-images \
					prepare-additional-dist-images \
					prepare-favicon

prepare-favicon:
	cd ${CURDIR}/${HTDOCS} && \
	    ( [ -e favicon.ico ] || ln -s BBBike/images/favicon.ico )
	cd ${CURDIR}/${HTDOCS} && \
	    ( [ -e apple-touch-icon.png ] || ln -s BBBike/images/srtbike57.png apple-touch-icon.png )

prepare-bbbike-dist-prog-bbbike-tmp:
	chmod 777 ${CURDIR}/BBBike/tmp
	@echo "Maybe chown ${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/tmp on ${BBBIKE_HOSTEUROPE_SSH_HOST} to www"

prepare-bbbike-dist-prog-bbbike-miscsrc:
	[ -d ${CURDIR}/BBBike/miscsrc ] || \
	    mkdir ${CURDIR}/BBBike/miscsrc
.for f in ${EXTRA_MISCSRC_FILES}
	if [ ! -e ${CURDIR}/BBBike/miscsrc/$f -o ${BBBIKE_ROOT_DIR}/miscsrc/$f -nt ${CURDIR}/BBBike/miscsrc/$f ] ; then \
	    cp -pf ${BBBIKE_ROOT_DIR}/miscsrc/$f ${CURDIR}/BBBike/miscsrc/$f; \
	fi
.endfor

prepare-bbbike-dist-prog-bbbike-misc:
	[ -d ${CURDIR}/BBBike/misc ] || \
	    mkdir ${CURDIR}/BBBike/misc
.for f in ${EXTRA_MISC_FILES}
	if [ ! -e ${CURDIR}/BBBike/misc/$f -o ${BBBIKE_ROOT_DIR}/misc/$f -nt ${CURDIR}/BBBike/misc/$f ] ; then \
	    cp -pf ${BBBIKE_ROOT_DIR}/misc/$f ${CURDIR}/BBBike/misc/$f; \
	fi
.endfor

prepare-bbbike-dist-prog-bbbike-t:
	[ -d ${CURDIR}/BBBike/t ] || \
	    mkdir ${CURDIR}/BBBike/t
.for f in ${TESTS_ON_REMOTE} ${TESTS_FROM_LOCAL} ${TESTS_ADD}
	if [ ! -e ${CURDIR}/BBBike/t/$f -o ${BBBIKE_ROOT_DIR}/t/$f -nt ${CURDIR}/BBBike/t/$f ] ; then \
	    cp -pf ${BBBIKE_ROOT_DIR}/t/$f ${CURDIR}/BBBike/t/$f; \
	fi
.endfor
	rsync -av --cvs-exclude ${BBBIKE_ROOT_DIR}/t/data/ ${CURDIR}/BBBike/t/data/
.for f in ${TESTS_SERVER_ON_REMOTE}
	if [ ! -e ${CURDIR}/BBBike/t/$f -o ${CURDIR}/t/$f -nt ${CURDIR}/BBBike/t/$f ] ; then \
	    cp -pf ${CURDIR}/t/$f ${CURDIR}/BBBike/t/$f; \
	fi
.endfor

prepare-bbbike-dist-prog-bbbike-html:
	mkdir -p ${CURDIR}/BBBike/html/opensearch
.for f in ${EXTRA_HTML_FILES}
	if [ ! -e ${CURDIR}/BBBike/html/$f -o ${BBBIKE_ROOT_DIR}/html/$f -nt ${CURDIR}/BBBike/html/$f ] ; then \
	    cp -pf ${BBBIKE_ROOT_DIR}/html/$f ${CURDIR}/BBBike/html/$f; \
	fi
.endfor
	cd ${CURDIR}/BBBike/html && \
	    ${MAKE} bbbike-opensearch bbbike-opensearch-images
#	Vorsichtshalber, weil ansonsten die falschen URLs enthalten sein
#	könnten:
	cd ${CURDIR}/BBBike/html && \
	    rm -f newstreetform.html newstreetform.utf8.html fragezeichenform.html fragezeichenform.utf8.html
	cd ${CURDIR}/BBBike/html && \
	    ${MAKE} newstreetform.html newstreetform.utf8.html fragezeichenform.html fragezeichenform.utf8.html \
		CGIDIR=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin

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

# Most of temp_blockings is not yet in MANIFEST, so copy is necessary
# bbbike-temp-blockings-optimized.pl *is* in MANIFEST, but is also
# needed in deploy-temp-blockings rule, which does not use the normal
# MANIFEST copy.
prepare-bbbike-dist-data-temp-blockings-dir:
	[ -d ${CURDIR}/BBBike/${TEMP_BLOCKINGS_DIR} ] || \
	    mkdir -p ${CURDIR}/BBBike/${TEMP_BLOCKINGS_DIR}
	find ${BBBIKE_ROOT_DIR}/${TEMP_BLOCKINGS_DIR}/ -maxdepth 1 -type f ! -name "*~" -a ! -name "*.st" -a ! -name "*.core" -a ! -name "#*#" | ${XARGS_REPL} cp -pf % ${CURDIR}/BBBike/${TEMP_BLOCKINGS_DIR}/

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
	@echo "Compile mapserv manually on ${BBBIKE_HOSTEUROPE_SSH_HOST}"
	[ -d ${CURDIR}/$(HTDOCS)/mapserver/brb ] || \
	    mkdir -p ${CURDIR}/$(HTDOCS)/mapserver/brb

# XXX rename /tmp/radzeit_mapserver_dist, here and in mapserver/brb/Makefile
prepare-mapserver-dist-main:
	cd ${BBBIKE_ROOT_DIR}/mapserver/brb && \
	    ${MAKE} dist-any TARGET=${TARGET}
.if ${TARGET_OS_DIST} == "linux-debian"
	perl -i -pe 's{^(\S+\s+)(.*)}{$$1/usr/share/fonts/truetype/ttf-bitstream-vera/Vera.ttf}' \
	    /tmp/radzeit_mapserver_dist/fonts-radzeit.list
.endif
	cp -Rpf /tmp/radzeit_mapserver_dist/* ${CURDIR}/$(HTDOCS)/mapserver/brb/
	rm -f ${CURDIR}/.not_rsyncable

prepare-mapserver-dist-local-main:
	touch ${CURDIR}/.not_rsyncable
	cd ${BBBIKE_ROOT_DIR}/mapserver/brb && \
	    ${MAKE} dist-any TARGET=bbbike.hosteurope.herceg.de
	cp -Rpf /tmp/radzeit_mapserver_dist/* ${CURDIR}/$(HTDOCS)/mapserver/brb/
	chmod 777 ${CURDIR}/$(HTDOCS)/mapserver/brb
	chmod 777 ${CURDIR}/$(HTDOCS)/mapserver/brb/tmp

prepare-mapserver-dist-post:
	@echo "XXX Check permissions of $(HTDOCS)/mapserver/brb and maybe WWWUSER in bbbike/mapserver/brb/Makefile"
	[ -d ${CURDIR}/$(HTDOCS)/mapserver/brb/fonts ] || \
	    mkdir ${CURDIR}/$(HTDOCS)/mapserver/brb/fonts
.if exists(/usr/share/fonts/truetype/ttf-xfree86-nonfree/luxisr.ttf)
	cp -pf /usr/share/fonts/truetype/ttf-xfree86-nonfree/luxisr.ttf \
	    ${CURDIR}/$(HTDOCS)/mapserver/brb/fonts
.else
	cp -pf /usr/local/lib/X11/fonts/TTF/luxisr.ttf \
	    ${CURDIR}/$(HTDOCS)/mapserver/brb/fonts
.endif

# Not run anymore per default --- what was the intention of this
# directory, anyway?
prepare-touren-dist:
	[ -d ${CURDIR}/$(HTDOCS)/mapserver/touren ] || \
	    mkdir -p ${CURDIR}/$(HTDOCS)/mapserver/touren
	chmod 755 ${CURDIR}/$(HTDOCS)/mapserver/touren
	cp -pf ${BBBIKE_ROOT_DIR}/mapserver/touren/*.trk \
	    ${CURDIR}/$(HTDOCS)/mapserver/touren

# Call once sternfahrt files have changed:
prepare-sternfahrt-dist:	prepare-sternfahrt${STERNFAHRT_YEAR}-dist

prepare-sternfahrt${STERNFAHRT_YEAR}-dist:	prepare-sternfahrt${STERNFAHRT_YEAR}-dist-data \
						prepare-sternfahrt${STERNFAHRT_YEAR}-dist-images

prepare-sternfahrt2005-dist-images:
	cp -pf ${BBBIKE_ROOT_DIR}/images/stern2005_titel.jpg \
	       ${CURDIR}/BBBike/images/
	chmod ugo+r ${CURDIR}/BBBike/images/stern2005_titel.jpg

prepare-sternfahrt${STERNFAHRT_YEAR}-dist-images:
	cp -pf ${BBBIKE_ROOT_DIR}/images/stern${STERNFAHRT_YEAR}_titel.jpg \
	       ${CURDIR}/BBBike/images/
	chmod ugo+r ${CURDIR}/BBBike/images/stern${STERNFAHRT_YEAR}_titel.jpg

prepare-sternfahrt${STERNFAHRT_YEAR}-dist-data:
	mkdir -p ${CURDIR}/BBBike/misc/sternfahrt_${STERNFAHRT_YEAR}
	cp -pf ${BBBIKE_ROOT_DIR}/misc/sternfahrt_${STERNFAHRT_YEAR}/treffpunkte.cgi \
	       ${CURDIR}/BBBike/misc/sternfahrt_${STERNFAHRT_YEAR}/
	chmod ugo+r,ugo+x ${CURDIR}/BBBike/misc/sternfahrt_${STERNFAHRT_YEAR}/treffpunkte.cgi
	cp -pf ${BBBIKE_ROOT_DIR}/misc/sternfahrt_${STERNFAHRT_YEAR}/treffpunkte${STERNFAHRT_YEAR}.bbd \
	       ${CURDIR}/BBBike/misc/sternfahrt_${STERNFAHRT_YEAR}/
	chmod ugo+r,ugo+x ${CURDIR}/BBBike/misc/sternfahrt_${STERNFAHRT_YEAR}/treffpunkte${STERNFAHRT_YEAR}.bbd
	[ -e ${CURDIR}/cgi-bin/sternfahrt${STERNFAHRT_YEAR}-treffpunkte.cgi ] || \
		ln -s ../BBBike/misc/sternfahrt_${STERNFAHRT_YEAR}/treffpunkte.cgi \
		      ${CURDIR}/cgi-bin/sternfahrt${STERNFAHRT_YEAR}-treffpunkte.cgi

# Call once kreisfahrt files have changed:
prepare-kreisfahrt-dist:
	rsync --cvs-exclude -a ${BBBIKE_ROOT_DIR}/misc/kreisfahrt_${KREISFAHRT_YEAR}/ ${CURDIR}/BBBike/misc/kreisfahrt_${KREISFAHRT_YEAR}/

prepare-additional-dist-images:
	cp -pf ${BBBIKE_ROOT_DIR}/images/logo-fahrradstadt_75.png \
	    ${CURDIR}/BBBike/images/
	chmod ugo+r ${CURDIR}/BBBike/images/logo-fahrradstadt_75.png

test:	test-on-remote test-from-local

test-on-remote:
	-@mkdir -p .last
	-@date >> .last/start-test-on-remote
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} '\
	cd ${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin \
	BBBIKE_TEST_CGIURL=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin/${BBBIKECGI} \
	BBBIKE_TEST_WAPURL=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin/wapbbbike.cgi \
	BBBIKE_TEST_HTMLDIR=http://${BBBIKE_HOSTEUROPE_HOST}/BBBike \
	    perl -MTest::Harness -e "runtests(@ARGV)" \
		${TESTS_ON_REMOTE} ${TESTS_SERVER_ON_REMOTE} \
	'
	-@date >> .last/test-on-remote

test-on-remote-full:
	$(MAKE) test-on-remote TESTS_ON_REMOTE="$(TESTS)"

test-from-local:
	-@mkdir -p .last
	-@date >> .last/start-test-from-local
	cd ${.CURDIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin \
	BBBIKE_TEST_CGIURL=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin/${BBBIKECGI} \
	BBBIKE_TEST_WAPURL=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin/wapbbbike.cgi \
	BBBIKE_TEST_HTMLDIR=http://${BBBIKE_HOSTEUROPE_HOST}/BBBike \
	    perl -MTest::Harness -e "runtests(@ARGV)" \
		${TESTS_FROM_LOCAL}
	-@date >> .last/test-from-local

test-on-remote-and-send-mail:
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} '\
	cd ${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin \
	BBBIKE_TEST_CGIURL=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin/${BBBIKECGI} \
	BBBIKE_TEST_WAPURL=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin/wapbbbike.cgi \
	BBBIKE_TEST_HTMLDIR=http://${BBBIKE_HOSTEUROPE_HOST}/BBBike \
	    (perl -MTest::Harness -e "runtests(@ARGV)" \
		${TESTS} | mail slaven@rezic.de ) & \
	'

test-local: test-local-parallel
#test-local: test-local-serial

test-local-serial:
	cd ${.CURDIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=${LOCAL_CGI_URL} \
	BBBIKE_TEST_CGIURL=${LOCAL_CGI_URL}/${BBBIKECGI} \
	BBBIKE_TEST_WAPURL=${LOCAL_CGI_URL}/wapbbbike.cgi \
	BBBIKE_TEST_MAPSERVERURL=${LOCAL_MAPSERVER_URL} \
	BBBIKE_TEST_HTMLDIR=${LOCAL_HTML_URL} \
	    perl -MTest::Harness -e 'runtests(@ARGV)' \
		${TESTS}

test-local-parallel:
	cd ${.CURDIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=${LOCAL_CGI_URL} \
	BBBIKE_TEST_CGIURL=${LOCAL_CGI_URL}/${BBBIKECGI} \
	BBBIKE_TEST_WAPURL=${LOCAL_CGI_URL}/wapbbbike.cgi \
	BBBIKE_TEST_MAPSERVERURL=${LOCAL_MAPSERVER_URL} \
	BBBIKE_TEST_HTMLDIR=${LOCAL_HTML_URL} \
	    prove -j${TEST_JOBS} ${TESTS}

server-permissions:
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} '\
		chown ${WWW_USER} "${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/tmp/berlin_map*"; \
		chown 644 "${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/tmp/berlin_map*"; \
		chmod 777 "${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/tmp"; \
		chown ${WWW_USER} "${BBBIKE_HOSTEUROPE_APACHE_DIR}/$(HTDOCS)/mapserver/brb"; \
		chown ${WWW_USER} "${BBBIKE_HOSTEUROPE_APACHE_DIR}/$(HTDOCS)/mapserver/brb/tmp"; \
	'

backup:
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} '\
	    cd ${BBBIKE_HOSTEUROPE_APACHE_DIR} && \
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
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} '\
	    cd ${BBBIKE_HOSTEUROPE_APACHE_DIR}/$(HTDOCS)/mapserver/brb && \
	    ./cleanup -f -agehours 24 \
	'

# For quick deployment only:
fast-rsync-googlemaps:
	rsync -e "${SSH_PROG_AND_ARGS}" -av $(BBBIKE_ROOT_DIR)/cgi/bbbikegooglemap.cgi ${BBBIKE_HOSTEUROPE_USER}@${BBBIKE_HOSTEUROPE_SSH_HOST}:${BBBIKE_HOSTEUROPE_APACHE_DIR}/cgi-bin/

# Do I need an rsync for temp-blockings?
diff-temp-blockings:
	${SSH_PROG_AND_ARGS} -C ${BBBIKE_HOSTEUROPE_USER}@${BBBIKE_HOSTEUROPE_SSH_HOST} \
	    cat ${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/data/temp_blockings/bbbike-temp-blockings.pl | diff -u - ${BBBIKE_ROOT_DIR}/${TEMP_BLOCKINGS_DIR}/bbbike-temp-blockings.pl

check-temp-blockings-integrity-pre:
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE} temp_blockings/bbbike-temp-blockings-optimized.pl
	$(BBBIKE_ROOT_DIR)/miscsrc/check_bbbike_temp_blockings -datadir $(BBBIKE_ROOT_DIR)/data -action none

check-temp-blockings-integrity:
	$(BBBIKE_ROOT_DIR)/miscsrc/check_bbbike_temp_blockings -datadir $(CURDIR)/BBBike/data -action none

create-all-maps:
	lwp-request -m GET 'http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin/bbbike.cgi?create_all_maps=1'

init-environment:
	lwp-request -m GET 'http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin/bbbike.cgi?init_environment=1'

init-local-environment:
	lwp-request -m GET '${LOCAL_CGI_URL}/bbbike.cgi?init_environment=1'

post-deploy-info:
	@echo "**********************************************************************"
	@echo "Consider to do the following things now:"
	@echo "* Update git repo of webserver:"
	@echo "    $(HOME)/src/bbbike-aux/misc/bbbike-checkin-hosteurope.pl -after-sync"
	@echo "* Send all messages in GNUS' drafts folder"
	@echo "* Update the fragezeichen_list pages:"
	@echo "    cd $(HOME)/src/bbbike/misc && slaymake rsync-fragezeichen-list"
	@echo ""
