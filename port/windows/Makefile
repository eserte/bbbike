######################################################################
# Rules for Strawberry dist
#
# HOWTO use this rules (work in progress!!!)
#
# Prerequistites:
# - cygwin
# - cygwin packages: perl, make (GNU make), maybe others?
# - Template-Toolkit for cygwin perl, maybe manually installed using CPAN.pm
# - a suitable strawberry portable zipfile,
#   e.g. strawberry-perl-5.14.2.1-32bit-portable.zip, 
#   downloaded to c:\Dokumente und Einstellungen\eserte\Eigene Dateien\Downloads
#   (if another version is chosen, then create_bbbike_dist.pl must be changed)
#
# Creating the dist:
# - run in a windows shell:
#     cd C:\cygwin\home\eserte\work\bbbike && perl port\windows\create_bbbike_dist.pl
#   or for a snapshot version:
#     cd C:\cygwin\home\eserte\work\bbbike && perl port\windows\create_bbbike_dist.pl -snapshot

# This makefile works only with GNU make

BBBIKEVER=	$(shell perl -I../.. -MBBBikeVar -e 'print $$BBBike::WINDOWS_VERSION')

all:
	@echo "Please read this file for the new strawberry rules"
	@false

make-BBBikeVar.tpl:
	cd ../.. && $(MAKE) BBBikeVar.tpl

bbbike-strawberry-dist: make-BBBikeVar.tpl
	tpage --debug=undef --define VERSION=$(BBBIKEVER) --eval_perl bbbike.tpl.iss > bbbike.iss~
	chmod ugo+x bbbike.iss~
	mv bbbike.iss~ bbbike.iss

bbbike-strawberry-snapshot-dist: make-BBBikeVar.tpl
	env SNAPSHOTDATE=`perl -MPOSIX=strftime -e 'print strftime "%Y%m%d", localtime'` sh -c 'tpage --debug=undef --define VERSION=snapshot-$$SNAPSHOTDATE --eval_perl bbbike.tpl.iss > bbbike-snapshot-$$SNAPSHOTDATE.iss && chmod 755 bbbike-snapshot-$$SNAPSHOTDATE.iss'

# XXX TODOs:
# - all InlineDist.pm are missing in git --- should I include it? Or generate it, how? Or should I switch to Inline::C2XS as fast as possible?
# - data/.modified is missing, but may be created using miscsrc/create_modified.pl
make-bbbike-dist:
	[ -d ../../../../bbbikewindist ]
	-rm -rf ../../../../bbbikewindist/bbbike.old
	-mv ../../../../bbbikewindist/bbbike ../../../../bbbikewindist/bbbike.old
	perl "-MExtUtils::Manifest=manicopy,maniread" -e "chdir q{../..} or die; manicopy(maniread(q{MANIFEST}),q{../../bbbikewindist/bbbike}, 'cp');"

GPSBABEL_SRC=/cygdrive/c/Programme/GPSBabel
GPSBABEL_DEST=../../../../bbbikewindist/gpsbabel

# Assumes that gpsbabel (e.g. 1.4.2) is normally installed
# XXX hardcoded for german installations (C:\Programme)
make-gpsbabel-dist:
	[ -d ../../../../bbbikewindist ]
	[ -d ${GPSBABEL_SRC} ]
	mkdir -p ${GPSBABEL_DEST}
	cp -pn ${GPSBABEL_SRC}/gpsbabel.exe ${GPSBABEL_DEST}
	cp -pn ${GPSBABEL_SRC}/libexpat.dll ${GPSBABEL_DEST}
	cp -pn ${GPSBABEL_SRC}/COPYING ${GPSBABEL_DEST}
