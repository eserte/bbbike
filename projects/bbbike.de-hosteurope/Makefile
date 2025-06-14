# Targets:
#
#  automatic-deployment: do everything for an automatic deployment: check on
#                        local system first, then sync, then test on remote
#                        system, and do some git operations before and
#                        after
#  automatic-deployment-temp-blockings: do everything to deploy only
#					the temp-blockings-related files
#
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
#  test-pps:    Test on a pps system (bbbike-pps).
#  deploy:	Do everything from preparing to rsync'ing and testing.
#  deploy-local:	Prepare a local distribution for testing. Do not rsync.
#  deploy-pps:		Do a deployment to a pps system (bbbike-pps).
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
TARGET_LIVE=		hosteurope
HOST!=			hostname
DEPLOYMENT_HOST?=	cvrsnica.herceg.de
PERL?=			perl

EXTRA_MISCSRC_FILES=	bbd2esri \
			relevant_errorlog.pl \
			winter_optimization.pl \
			FixRemoteAddrHandler.pm \
			bbbike_cgi_clean_expired_cache.pl \
			cron-wrapper \
			update-modperl-reload-touchfile.pl \
			icao_metar.pl
EXTRA_MISC_FILES=	gpx.xsd kml21.xsd bbbikecgires.kwalify bbbikecgires.rnc kreisfahrt_anyyear/kreisfahrt_anyyear.png
EXTRA_HTML_FILES=	Makefile newstreetform.tpl.html \
			opensearch/bbbike-opensearch.tpl.src \
			opensearch/bbbike-opensearch.tpl.xml \
			opensearch/opensearch.html \
			opensearch/opensearch.js
CGI_FILES=		bbbike.cgi \
			bbbike-data.cgi \
			bbbike-snapshot.cgi \
			bbbikegooglemap.cgi \
			bbbikeleaflet.cgi \
			wapbbbike.cgi \
			mapserver_address.cgi \
			mapserver_comment.cgi \
			mapserver_setcoord.cgi \
			upload-track.cgi \
			qrcode.cgi
TESTS_ON_REMOTE?=	basic.t \
			strassen-gpx.t \
			bbbikedraw.t
TESTS_FROM_LOCAL=	\
			bbbikecgiapi.t \
			bbbikecgiapi-config.t \
			cgihead.t \
			cgi-mechanize.t \
			cgi.t \
			cgi-test.t \
			cgi-download.t \
			cgi-leaflet.t \
			wwwdata.t
TESTS_SERVER_ON_REMOTE=	
TESTS=			$(TESTS_ON_REMOTE) $(TESTS_SERVER_ON_REMOTE) $(TESTS_FROM_LOCAL)
TESTS_ADD=		BBBikeTest.pm
HTDOCS=			public

# XXX maybe use test-on-remote-and-send-mail (after tests)
DEPLOY_TARGETS=			prepare \
				rsync \
				init-environment \
				test \
				create-all-maps \
				clean-expired-cache \
				post-deploy-info

# only bbbike data, no program, no mapserver
DEPLOY_DATA_TARGETS=		prepare-bbbike-data \
				prepare-bbbike-dist \
				rsync-bbbike-data \
				test

# local deployment
DEPLOY_LOCAL_NO_TEST_TARGETS=	prepare \
				init-local-environment

DEPLOY_LOCAL_TARGETS=		${DEPLOY_LOCAL_NO_TEST_TARGETS} \
				test-local \
				post-deploy-local-info

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

XTERM_CONF_TITLE=	xterm-conf -f --title

# XXX Should be set from mapserver/brb/Makefile:
WWW_USER?=	www-data
WWW_GROUP?=	www-data

TODAY!=		date +%Y%m%d

OSNAME!=	uname
.if ${OSNAME} == "Linux"
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
# e.g. Linux
MAPSERVER_EXE?=	/usr/lib/cgi-bin/mapserv
.elif exists(/usr/local/www/cgi-bin/mapserv)
# e.g. FreeBSD
MAPSERVER_EXE?=	/usr/local/www/cgi-bin/mapserv
.else
MAPSERVER_EXE?=	$(HOME)/www/cgi/mapserv.cgi
.if !exists($(MAPSERVER_EXE))
.warning The mapserver executable $(MAPSERVER_EXE) does not exist.
.endif
.endif

## Prefer cp, so I may make changes in ~/src/bbbike and still have
## a copy on my disk similar to the server contents.
#MKDIST_STYLE=	best
MKDIST_STYLE=	cp


.ifndef TARGET
.for t in ${DEPLOY_TARGETS}
.if make($t)
TARGET=${TARGET_LIVE}
.endif
.endfor
.endif

.ifndef TARGET
.for t in ${DEPLOY_LOCAL_TARGETS}
.if make($t)
TARGET=bbbike.hosteurope.herceg.de
.endif
.endfor
.endif

.ifndef MAPSERVER_TARGET
MAPSERVER_TARGET=${TARGET}
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
      make(rsync-tests-pps)	     || \
      make(clean-cache-files-on-remote) || \
      make(diff-temp-blockings)
TARGET=${TARGET_LIVE}
.elif make(deploy-local)         || \
      make(deploy-local-data)    || \
      make(deploy-local-no-test) || \
      make(backup-local)         || \
      make(test-local)
TARGET=bbbike.hosteurope.herceg.de
.elif make(automatic-deployment) || \
      make(automatic-deployment-temp-blockings) || \
      make(automatic-deployment--check-prerequisites) || \
      make(after-deployment-set-tags) || \
      make(check-pps) || \
      make(deploy-pps) || \
      make(test-pps) || \
      make(test-on-pps-full) || \
      make(all) || \
      make(.PHONY)
# no TARGET=
.elif ${.TARGETS} == ""
# no TARGET=
.else
.error "Please set TARGET to ${TARGET_LIVE} or bbbike.hosteurope.herceg.de"
.endif
.endif

LOCAL_MAPSERVER_URL=	http://www/cgi-bin/mapserv

# The bbbike.cgi to test (stable or beta)
BBBIKECGI=		bbbike.cgi
.ifdef TEST_BETA
BBBIKECGI=		bbbike2.cgi
.endif

BBBIKE_CGI_CONFIG=PLEASE_DEFINE_bbbike.cgi.config
MAPSERVER_BRB_LOCALINC=	PLEASE_DEFINE_mapserver-brb-brb.map-localinc
.ifdef TARGET
.if ${TARGET} == bbbike-pps-jessie || ${TARGET} == hosteurope
BBBIKE_CGI_CONFIG=	bbbike-hosteurope-jessie.cgi.config
MAPSERVER_BRB_LOCALINC=	mapserver-brb-brb.map-localinc-jessie
.endif
.endif

.ifdef TARGET
.include "${BBBIKE_ROOT_DIR}/mapserver/brb/Makefile.${TARGET}.inc"
.endif

all:

######################################################################
# Top level targets
check:
	${RSYNC} -rl --dry-run --itemize-changes ${RSYNC_ARGS} ${RSYNC_SRCDEST}

clean-cache-files-on-remote:
	-${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} \
	    rm /tmp/b_de_\* /tmp/bbbike_\*.cache

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
.ifdef TARGET
.if ${TARGET} == ${TARGET_LIVE}
	-@mkdir -p .last
	-@date >> .last/start-do-rsync
.endif
.endif
	${RSYNC} ${RSYNC_ARGS} ${RSYNC_SRCDEST}
.ifdef TARGET
.if ${TARGET} == ${TARGET_LIVE}
	-@date >> .last/do-rsync
.endif
.endif

rsync-bbbike:
	@echo NYI
	false

rsync-mapserver:	check-rsync-ok check-rsync-mapserver /tmp/mapserver.rsync.exclude
	${RSYNC_PROG} ${RSYNC_ARGS_MS} ${CURDIR}/public/mapserver/ ${BBBIKE_HOSTEUROPE_USER}@${BBBIKE_HOSTEUROPE_SSH_HOST}:${BBBIKE_HOSTEUROPE_APACHE_DIR}/${HTDOCS}/mapserver/

rsync-tests:
	${RSYNC_PROG} ${RSYNC_ARGS} --exclude cover_db/ --exclude tmp/ ${BBBIKE_ROOT_DIR}/t/ ${RSYNC_DEST}/BBBike/t/

rsync-tests-pps:
	${MAKE} rsync-tests TARGET=bbbike-pps-jessie

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
.ifdef TARGET
.if ${TARGET} == ${TARGET_LIVE}
	-@mkdir -p .last
	-@date >> .last/start-do-rsync-bbbike-data
.endif
.endif
	${RSYNC} ${RSYNC_ARGS} \
	    BBBike/data/ ${RSYNC_DEST}/BBBike/data/
.ifdef TARGET
.if ${TARGET} == ${TARGET_LIVE}
	-@date >> .last/do-rsync-bbbike-data
.endif
.endif

post-rsync-bbbike:
# bbbike-snapshot expects this file, but nothing of BBBike/tmp is
# rsync'ed by .rsync_exclude file
# cgi-bin/mapserv symlink is also blacklisted (by .rsync_exclude) and
# needs to be created (hardcoded for a typical Debian system)
	-${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} \
	   "\
		touch ${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/tmp/.keep_me; \
	   	${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/miscsrc/update-modperl-reload-touchfile.pl --touch; \
		if [ ! -L ${BBBIKE_HOSTEUROPE_APACHE_DIR}/cgi-bin/mapserv ] ; then \
		    ln -s /usr/lib/cgi-bin/mapserv ${BBBIKE_HOSTEUROPE_APACHE_DIR}/cgi-bin/mapserv; \
		fi \
	   "

post-rsync-bbbike-data:
.ifdef TARGET
.if ${TARGET} == ${TARGET_LIVE}
	-@date >> .last/start-post-rsync-bbbike-data
.endif
.endif
	-${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} \
	   "rm -f ${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/tmp/winter_optimization*"
.ifdef TARGET
.if ${TARGET} == ${TARGET_LIVE}
	-@date >> .last/post-rsync-bbbike-data
.endif
.endif

rsync-temp-blockings:
.ifdef TARGET
.if ${TARGET} == ${TARGET_LIVE}
	-@mkdir -p .last
	-@date >> .last/start-post-rsync-bbbike-data
.endif
.endif
	${RSYNC} ${RSYNC_ARGS} \
	    BBBike/data/temp_blockings/ ${RSYNC_DEST}/BBBike/data/temp_blockings/
.ifdef TARGET
.if ${TARGET} == ${TARGET_LIVE}
	-@date >> .last/rsync-temp-blockings
.endif
.endif

show-rsync-message:
	-[ ! -e ${CURDIR}/.rsync_message ] && true || cat ${CURDIR}/.rsync_message

.ORDER:			${DEPLOY_TARGETS}
deploy:			${DEPLOY_TARGETS}

.ORDER:			${DEPLOY_LOCAL_TARGETS}
deploy-local:		${DEPLOY_LOCAL_TARGETS}

.ORDER:			${DEPLOY_LOCAL_NO_TEST_TARGETS}
deploy-local-no-test:	${DEPLOY_LOCAL_NO_TEST_TARGETS}

deploy-pps:
			-@mkdir -p .last
			-@date >> .last/start-deploy-pps
			${MAKE} deploy TARGET=bbbike-pps-jessie

.ORDER:			${DEPLOY_DATA_TARGETS}
deploy-data:		${DEPLOY_DATA_TARGETS}

.ORDER:			${DEPLOY_LOCAL_DATA_TARGETS}
deploy-local-data:	${DEPLOY_LOCAL_DATA_TARGETS}

deploy-temp-blockings:	check-temp-blockings-integrity-pre \
			prepare-bbbike-dist-data-temp-blockings-dir \
			check-temp-blockings-integrity \
			rsync-temp-blockings

check-pps:
			${MAKE} check TARGET=bbbike-pps-jessie

test-pps:
			${MAKE} test TARGET=bbbike-pps-jessie

test-on-pps-full:
			${MAKE} test-on-remote-full TARGET=bbbike-pps-jessie

test-makefile:
	${MAKE} -n deploy-local > /tmp/test-makefile.cmd
	perl -e 'while(<ARGV>) {print STDERR "\a$$_> "; <STDIN>; system($$_) and warn $$?}' /tmp/test-makefile.cmd

######################################################################
# Sub targets
# Reihenfolge sollte hoffentlich richtig sein

prepare:	prepare-bbbike-data \
		prepare-mapserver-data \
		prepare-bbbike-dist \
		prepare-mapserver-dist

prepare-bbbike-data:	prepare-bbbike-data-parallel

prepare-bbbike-data-serial:
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE} all PERL=${PERL}
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && ${MAKE} slow-checks PERL=${PERL}

prepare-bbbike-data-parallel:
	cd $(BBBIKE_ROOT_DIR)/${DATA_DIR} && \
		(${MAKE} -j${BUILD_JOBS} all slow-checks PERL=${PERL}; ${MAKE} all slow-checks PERL=${PERL})

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
	cd ${BBBIKE_ROOT_DIR} && ${MAKE} distcheck-fatal
	cd ${BBBIKE_ROOT_DIR} && ${MAKE} permission
	(umask 022; cd ${BBBIKE_ROOT_DIR} && perl "-MExtUtils::Manifest=manicopy,maniread" -e "manicopy(maniread(),'${CURDIR}/BBBike', '${MKDIST_STYLE}');")

prepare-bbbike-dist-prog-bbbike-cgi:
	[ -d ${CURDIR}/cgi-bin ] || mkdir ${CURDIR}/cgi-bin
	chmod 755 ${CURDIR}/cgi-bin
.for i in ${CGI_FILES}
	rm -f ${CURDIR}/cgi-bin/$(i)
	cd ${CURDIR}/cgi-bin && ln -s ../BBBike/cgi/$(i)
.endfor
# Create bbbike.cgi configuration
	cp -pf ${BBBIKE_ROOT_DIR}/cgi/${BBBIKE_CGI_CONFIG} \
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
# Create bbbike-test.cgi links
	rm -f ${CURDIR}/cgi-bin/bbbike-test.cgi
	cd ${CURDIR}/cgi-bin && ln -s bbbike.cgi bbbike-test.cgi
	rm -f ${CURDIR}/cgi-bin/bbbike2-test.cgi
	cd ${CURDIR}/cgi-bin && ln -s bbbike.cgi bbbike2-test.cgi
# Create bbbike-test.cgi configurations
	rm -f ${CURDIR}/cgi-bin/bbbike-test.cgi.config
	cd ${CURDIR}/cgi-bin && ln -s ../BBBike/cgi/bbbike-test.cgi.config
	chmod ugo+r ${CURDIR}/BBBike/cgi/bbbike-test.cgi.config
	rm -f ${CURDIR}/cgi-bin/bbbike2-test.cgi.config
	cd ${CURDIR}/cgi-bin && ln -s ../BBBike/cgi/bbbike2-test.cgi.config
	chmod ugo+r ${CURDIR}/BBBike/cgi/bbbike2-test.cgi.config
# Create links for English version
	rm -f ${CURDIR}/cgi-bin/bbbike.en.cgi
	cd ${CURDIR}/cgi-bin && ln -s bbbike.cgi bbbike.en.cgi
	rm -f ${CURDIR}/cgi-bin/bbbike2.en.cgi
	cd ${CURDIR}/cgi-bin && ln -s bbbike.cgi bbbike2.en.cgi
	rm -f ${CURDIR}/cgi-bin/bbbikeleaflet.en.cgi
	cd ${CURDIR}/cgi-bin && ln -s bbbikeleaflet.cgi bbbikeleaflet.en.cgi
	rm -f ${CURDIR}/cgi-bin/bbbike-test.en.cgi
	cd ${CURDIR}/cgi-bin && ln -s bbbike.cgi bbbike-test.en.cgi
# Fix permissions
# Make sure that /usr/lib/cgi-bin/* isn't touched, otherwise make will fail
	(cd ${CURDIR}/cgi-bin && chmod ugo+r `find . -maxdepth 1 | xargs -L1 readlink | egrep -v "(/usr/lib/cgi-bin|/usr/local/www/cgi-bin)"`)
	@echo "Maybe create bbbike2.cgi and bbbike2.cgi.config"

prepare-bbbike-dist-prog-bbbike-htdocs:
	[ -d ${CURDIR}/$(HTDOCS)  ] || mkdir ${CURDIR}/$(HTDOCS)
	chmod 755 ${CURDIR}/$(HTDOCS)
	[ -e ${CURDIR}/$(HTDOCS)/BBBike ] || \
	    ln -s ../BBBike ${CURDIR}/$(HTDOCS)/BBBike
	@echo "Do 'ln -s ../BBBike ${BBBIKE_HOSTEUROPE_APACHE_DIR}/$(HTDOCS)/BBBike' manually on server"

prepare-bbbike-dist-prog-bbbike-images:	prepare-additional-dist-images \
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
	    if echo $f | grep -sq / ; then \
		mkdir -p $$(dirname ${CURDIR}/BBBike/misc/$f); \
	    fi; \
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
	rsync -av --cvs-exclude ${BBBIKE_ROOT_DIR}/t/data-test/ ${CURDIR}/BBBike/t/data-test/
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
	    ${MAKE} bbbike-opensearch bbbike-opensearch-images bbbikeleaflet.en.html
#	Vorsichtshalber, weil ansonsten die falschen URLs enthalten sein
#	k�nnten:
	cd ${CURDIR}/BBBike/html && \
	    rm -f newstreetform.html newstreetform.utf8.html \
		fragezeichenform.html fragezeichenform.utf8.html \
		shortfragezeichenform.html shortfragezeichenform.utf8.html
	cd ${CURDIR}/BBBike/html && \
	    ${MAKE} newstreetform.html newstreetform.utf8.html \
		fragezeichenform.html fragezeichenform.utf8.html \
		shortfragezeichenform.html shortfragezeichenform.utf8.html \
		CGIDIR=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin

prepare-bbbike-dist-data:	prepare-bbbike-dist-data-datadir \
				prepare-bbbike-dist-data-datadir-additional \
				prepare-bbbike-dist-data-temp-blockings-dir \
				prepare-bbbike-dist-data-teasers \
				prepare-bbbike-dist-old-bbbike-data

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

prepare-bbbike-dist-old-bbbike-data:
	rsync -a --itemize-changes --delete ${BBBIKE_ROOT_DIR}/tmp/old-bbbike-data/ \
	    ${CURDIR}/BBBike/tmp/old-bbbike-data/

prepare-mapserver-dist:	prepare-mapserver-dist-pre \
			prepare-mapserver-dist-main \
			prepare-mapserver-dist-post

prepare-mapserver-local-dist:	prepare-mapserver-dist-pre \
				prepare-mapserver-dist-local-main \
				prepare-mapserver-dist-post

prepare-mapserver-dist-pre:
	[ -e ${CURDIR}/cgi-bin/mapserv ] || \
	    ln -snf ${MAPSERVER_EXE} ${CURDIR}/cgi-bin/mapserv
	@echo "Compile mapserv manually on ${BBBIKE_HOSTEUROPE_SSH_HOST}"
	[ -d ${CURDIR}/$(HTDOCS)/mapserver/brb ] || \
	    mkdir -p ${CURDIR}/$(HTDOCS)/mapserver/brb

# XXX rename /tmp/radzeit_mapserver_dist, here and in mapserver/brb/Makefile
prepare-mapserver-dist-main:
# XXX   Copying and removing the localinc file here is an ugly hack
	cp -pf etc/${MAPSERVER_BRB_LOCALINC} ${BBBIKE_ROOT_DIR}/mapserver/brb/brb.map-localinc
# XXX	need SERVER_NAME hack as cgi/bbbike-hosteurope-jessie.cgi.config otherwise does a fallback to the current hostname
	cd ${BBBIKE_ROOT_DIR}/mapserver/brb && \
	    env SERVER_NAME=bbbike.de ${MAKE} dist-any TARGET=${MAPSERVER_TARGET}
	rm -f ${BBBIKE_ROOT_DIR}/mapserver/brb/brb.map-localinc
	cp -Rpf /tmp/radzeit_mapserver_dist/* ${CURDIR}/$(HTDOCS)/mapserver/brb/
	rm -f ${CURDIR}/.not_rsyncable

prepare-mapserver-dist-local-main:
	touch ${CURDIR}/.not_rsyncable
# XXX   Copying and removing the localinc file here is an ugly hack
	cp -pf etc/mapserver-brb-brb.map-localinc ${BBBIKE_ROOT_DIR}/mapserver/brb/brb.map-localinc
	cd ${BBBIKE_ROOT_DIR}/mapserver/brb && \
	    ${MAKE} dist-any TARGET=bbbike.hosteurope.herceg.de
	rm -f ${BBBIKE_ROOT_DIR}/mapserver/brb/brb.map-localinc
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
.elif exists(/usr/local/lib/X11/fonts/TTF/luxisr.ttf)
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

prepare-additional-dist-images:
	cp -pf ${BBBIKE_ROOT_DIR}/images/logo-fahrradstadt_75.png \
	    ${CURDIR}/BBBike/images/
	chmod ugo+r ${CURDIR}/BBBike/images/logo-fahrradstadt_75.png

test:	test-on-remote test-from-local

test-on-remote:
.ifdef TARGET
.if ${TARGET} == ${TARGET_LIVE}
	-@mkdir -p .last
	-@date >> .last/start-test-on-remote
.endif
.endif
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} '\
	cd ${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin \
	BBBIKE_TEST_CGIURL=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin/${BBBIKECGI} \
	BBBIKE_TEST_HTMLDIR=http://${BBBIKE_HOSTEUROPE_HOST}/BBBike \
	BBBIKE_TEST_FOR_LIVE=1 \
	    perl -MTest::Harness -e "runtests(@ARGV)" \
		${TESTS_ON_REMOTE} ${TESTS_SERVER_ON_REMOTE} \
	'
.ifdef TARGET
.if ${TARGET} == ${TARGET_LIVE}
	-@date >> .last/test-on-remote
.endif
.endif

# XXX avoid duplication
test-on-remote-full:
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} '\
	cd ${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike && \
	BBBIKE_TEST_CGIDIR=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin \
	BBBIKE_TEST_CGIURL=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin/${BBBIKECGI} \
	BBBIKE_TEST_HTMLDIR=http://${BBBIKE_HOSTEUROPE_HOST}/BBBike \
	BBBIKE_TEST_FOR_LIVE=1 \
	    prove --state=hot,all,save --color --timer `find t -name '\''*.t'\'' | sort | egrep -v '\''^t/(any2bbd|bbd_splitlines|cvsdiffbbd|geocoder-addr|gps-gpsmandata-any|gps-gpsmandata-garmingpx|gps-gpsmandata|gps-symbols-garmin|grepstrassen|leaflet-static|osm2bbd|reverse-geocoding|search_inaccessible|typ2legend-xpm).t$$'\'' ` \
	'

test-from-local:
.ifdef TARGET
.if ${TARGET} == ${TARGET_LIVE}
	-@mkdir -p .last
	-@date >> .last/start-test-from-local
.endif
.endif
	cd ${.CURDIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin \
	BBBIKE_TEST_CGIURL=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin/${BBBIKECGI} \
	BBBIKE_TEST_HTMLDIR=http://${BBBIKE_HOSTEUROPE_HOST}/BBBike \
	    perl -MTest::Harness -e "runtests(@ARGV)" \
		${TESTS_FROM_LOCAL}
.ifdef TARGET
.if ${TARGET} == ${TARGET_LIVE}
	-@date >> .last/test-from-local
.endif
.endif

test-on-remote-and-send-mail:
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} '\
	cd ${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin \
	BBBIKE_TEST_CGIURL=http://${BBBIKE_HOSTEUROPE_HOST}/cgi-bin/${BBBIKECGI} \
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
	BBBIKE_TEST_MAPSERVERURL=${LOCAL_MAPSERVER_URL} \
	BBBIKE_TEST_HTMLDIR=${LOCAL_HTML_URL} \
	    perl -MTest::Harness -e 'runtests(@ARGV)' \
		${TESTS}

test-local-parallel:
	cd ${.CURDIR}/BBBike/t && \
	BBBIKE_TEST_CGIDIR=${LOCAL_CGI_URL} \
	BBBIKE_TEST_CGIURL=${LOCAL_CGI_URL}/${BBBIKECGI} \
	BBBIKE_TEST_MAPSERVERURL=${LOCAL_MAPSERVER_URL} \
	BBBIKE_TEST_HTMLDIR=${LOCAL_HTML_URL} \
	    prove -j${TEST_JOBS} ${TESTS}

compile-ext:
	${RSYNC_PROG} -Pvz ${BBBIKE_ROOT_DIR}/ext/Makefile ${RSYNC_DEST}BBBike/ext/Makefile
	${SSH_PROG_AND_ARGS} -l ${BBBIKE_HOSTEUROPE_USER} ${BBBIKE_HOSTEUROPE_SSH_HOST} '\
		cd ${BBBIKE_HOSTEUROPE_APACHE_DIR}/BBBike/ext && make ext; \
	'

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
	    tar cfpz /tmp/BBBike-${TODAY}-backup.tar.gz \
	    BBBike \
	    cgi-bin/bbbike.cgi cgi-bin/bbbike.cgi.config cgi-bin/wapbbbike.cgi \
	    $(HTDOCS)/mapserver \
	'

backup-local:
	${SSH_PROG_AND_ARGS} -l eserte localhost '\
	    cd $(.CURDIR) && \
	    tar cfpz /tmp/BBBike-${TODAY}-backup.tar.gz \
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

clean-expired-cache:
	$(BBBIKE_ROOT_DIR)/miscsrc/bbbike_cgi_clean_expired_cache.pl -host ${BBBIKE_HOSTEUROPE_HOST}

init-local-environment:
	lwp-request -m GET '${LOCAL_CGI_URL}/bbbike.cgi?init_environment=1'

post-deploy-local-info:
	@echo "**********************************************************************"
	@echo "Consider to do the following things now:"
	@echo "* Update git repo of webserver:"
	@echo "    $(HOME)/src/bbbike-aux/misc/bbbike-checkin-hosteurope.pl -update"
	@echo "* Go live:"
	@echo "    ${MAKE} deploy"

post-deploy-info:
.ifdef TARGET
.if ${TARGET} == ${TARGET_LIVE}
	@echo "**********************************************************************"
	@echo "Consider to do the following things now:"
	@echo "* Update the fragezeichen_list pages:"
	@echo "    (cd $(HOME)/src/bbbike/misc && slaymake rsync-fragezeichen-list rsync-XXX-list rsync-bbbgeojsonp rsync-geojson)"
	@echo "* Update git repo of webserver:"
	@echo "    $(HOME)/src/bbbike-aux/misc/bbbike-checkin-hosteurope.pl -after-sync"
	@echo "* Push BBBike git repo to github"
	@echo "    git push"
	@echo "* Send all messages in GNUS' drafts folder"
	@echo ""
.endif
.endif

# XXX This target only supports three tags per day...
after-deployment-set-tags:
	@[ `git tag -l deployment/bbbikede/${TODAY} | wc -l` = 0 ] && \
	    (echo "Create git tag deployment/bbbikede/${TODAY} ...";   git tag -a -m "automatic deployment" deployment/bbbikede/${TODAY}) || \
	    (echo "Create git tag deployment/bbbikede/${TODAY}_2 ..."; git tag -a -m "automatic deployment" deployment/bbbikede/${TODAY}_2) || \
	    (echo "Create git tag deployment/bbbikede/${TODAY}_3 ..."; git tag -a -m "automatic deployment" deployment/bbbikede/${TODAY}_3)
	git tag -f deployment/bbbikede/current

automatic-deployment: automatic-deployment--check-prerequisites automatic-deployment--run after-deployment-set-tags

automatic-deployment--run:
	-@${XTERM_CONF_TITLE} "BBBike pre-deployment git update"
	$(HOME)/src/bbbike-aux/misc/bbbike-checkin-hosteurope.pl -update
	-@perl -MTerm::ANSIColor=colored -e 'print colored("Automatic deployment continues...", "black on_green"), "\n"'
	-@${XTERM_CONF_TITLE} "BBBike pps deployment"
	nice ${MAKE} deploy-pps NO_PARALLEL=1
	-@${XTERM_CONF_TITLE} "BBBike post deployment stuff @ pps"
	cd ${BBBIKE_ROOT_DIR}/misc && slaymake rsync-fragezeichen-list rsync-XXX-list rsync-bbbgeojsonp rsync-geojson BBBIKE_HOSTEUROPE_HOST=bbbike-pps-jessie BBBIKE_HOSTEUROPE_USER=root
	-@${XTERM_CONF_TITLE} "BBBike deployment"
	${MAKE} deploy
	-@${XTERM_CONF_TITLE} "BBBike post deployment stuff"
	cd ${BBBIKE_ROOT_DIR}/misc && slaymake rsync-fragezeichen-list rsync-XXX-list rsync-bbbgeojsonp rsync-geojson BBBIKE_HOSTEUROPE_HOST=${BBBIKE_HOSTEUROPE_HOST} BBBIKE_HOSTEUROPE_USER=${BBBIKE_HOSTEUROPE_USER}
	-@${XTERM_CONF_TITLE} "BBBike post-deployment git update"
	$(HOME)/src/bbbike-aux/misc/bbbike-checkin-hosteurope.pl -after-sync -unconfirmed
	-@${XTERM_CONF_TITLE} "BBBike deployment finished"
	-( tkmessage -center "BBBike deployment finished" &)

automatic-deployment-temp-blockings:
	-@${XTERM_CONF_TITLE} "BBBike pre-deployment git update"
	$(HOME)/src/bbbike-aux/misc/bbbike-checkin-hosteurope.pl -update
	-@${XTERM_CONF_TITLE} "BBBike temp-blockings deployment"
	${MAKE} deploy-temp-blockings
	-@${XTERM_CONF_TITLE} "BBBike post-deployment git update"
	$(HOME)/src/bbbike-aux/misc/bbbike-checkin-hosteurope.pl -after-sync -unconfirmed
	-@${XTERM_CONF_TITLE} "BBBike temp-blockings deployment finished"

automatic-deployment--check-prerequisites:
	-@perl -MTerm::ANSIColor=colored -e 'print colored("Please stand by...", "white on_red"), "\n"'
	if [ "${HOST}" != "${DEPLOYMENT_HOST}" ] ; then \
	    echo "*** ERROR: deployment was not started on \"${DEPLOYMENT_HOST}\","; \
	    echo "but on host \"${HOST}\". If you think this is OK, then change or set"; \
	    echo "the DEPLOYMENT_HOST make variable to the current host, e.g."; \
	    echo ""; \
	    echo "    ${MAKE} ${.MAKEFLAGS} ${.TARGETS} DEPLOYMENT_HOST=\$$HOST"; \
	    false; \
	else \
	    true; \
	fi
	perl -MNet::Ping -e '@p = Net::Ping->new("tcp", 2); @p[0]->port_number(80); exit !@p[0]->ping(shift)' bbbike-pps-jessie
	perl -MNet::Ping -e '@p = Net::Ping->new("tcp", 2); @p[0]->port_number(80); exit !@p[0]->ping(shift)' bbbike.de
