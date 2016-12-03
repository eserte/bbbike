######################################################################
# Rules for Strawberry dist
#
# HOWTO
#
# Prerequistites:
# - a standard strawberry perl installation (which is just used for the
#   build process, not for packaging)
# - a suitable strawberry _portable_ zipfile,
#   e.g. strawberry-perl-5.24.0.1-32bit-portable.zip, 
#   downloaded to c:\Users\$USERNAME\Downloads
#   (if another version is chosen, then create_bbbike_dist.pl must be given
#   the --strawberry-version option)
# - Inno Setup (e.g. version 5.5.9)
# - a git-clone of bbbike in the user's directory as %HOMEDRIVE%HOMEPATH/bbbike
# - create a directory c:\Users\$USERNAME\bbbikewindist (XXX why not automatically done?)
#
# Creating the dist:
# - run in a windows shell:
#     cd C:\Users\$USERNAME\bbbike && perl port\windows\create_bbbike_dist.pl
#   or for a snapshot version:
#     cd C:\Users\$USERNAME\bbbike && perl port\windows\create_bbbike_dist.pl -snapshot

# This makefile works only with GNU make

all:
	@echo "Please read this file for the new strawberry rules"
	@false

make-BBBikeVar.tpl:
	cd ../.. && $(MAKE) BBBikeVar.tpl

bbbike-strawberry-dist: make-BBBikeVar.tpl
	perl Makefile_PL bbbike-strawberry-dist

bbbike-strawberry-snapshot-dist: make-BBBikeVar.tpl
	perl Makefile_PL bbbike-strawberry-snapshot-dist

# XXX TODOs:
# - all InlineDist.pm are missing in git --- should I include it? Or generate it, how? Or should I switch to Inline::C2XS as fast as possible?
# - data/.modified is missing, but may be created using miscsrc/create_modified.pl
make-bbbike-dist:
	perl Makefile_PL make-bbbike-dist

#GPSBABEL_SRC=$(shell cygpath "$$PROGRAMFILES")/GPSBabel
#GPSBABEL_DEST=../../../../bbbikewindist/gpsbabel
#
## Assumes that gpsbabel (e.g. 1.4.2) is normally installed
## Does not work for later gpsbabel versions,
## as libexpat.dll is gone and other .dlls are used instead.
#make-gpsbabel-dist:
#	[ -d ../../../../bbbikewindist ]
#	[ -d "${GPSBABEL_SRC}" ]
#	mkdir -p ${GPSBABEL_DEST}
#	cp --preserve=mode,timestamps -n "${GPSBABEL_SRC}/gpsbabel.exe" ${GPSBABEL_DEST}
#	cp --preserve=mode,timestamps -n "${GPSBABEL_SRC}/libexpat.dll" ${GPSBABEL_DEST}
#	cp --preserve=mode,timestamps -n "${GPSBABEL_SRC}/COPYING" ${GPSBABEL_DEST}
