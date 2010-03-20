BBBIKEVER!=		perl -I../.. -MBBBikeVar -e 'print $$BBBike::WINDOWS_VERSION'
BBBIKEDEVELVER!=	perl -I../.. -MBBBikeVar -e 'print $$BBBike::VERSION'

#all: setup.exe
#all: show-instructions make-windows-installer
all:
	@echo "Please read this file for the new strawberry rules"
	@false

show-instructions:
	-@if [ "$(BBBIKEVER)" != $(BBBIKEDEVELVER) ] ; then \
	    echo "The version is set to the current official BBBike version" ; \
	    echo "You can force the installer to use the new version by calling"; \
	    echo "the makefile with"; \
	    echo; \
	    echo "    make BBBIKEVER=$(BBBIKEDEVELVER)"; \
	    echo; \
	fi
	@echo "Note that an existing distribution directory from"
	@echo "a previous run of this Makefile is not removed or"
	@echo "remade. To do so, use"
	@echo
	@echo "    make BBBIKEVER=$(BBBIKEVER) BBBIKEDEVELVER=$(BBBIKEDEVELVER) winbindist-clean"
	@echo

make-BBBikeVar.tpl:
	cd ../.. && $(MAKE) BBBikeVar.tpl

winbindist-clean:
	-cd ../.. && $(MAKE) winbindist-clean

make-winbindist:
	-cd ../.. && $(MAKE) winbindist-copy BBBIKE_WINDOWS_VERSION=$(BBBIKEVER)
# This is useful for testing directly on the /tmp directory
	-mkdir -p /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/tmp
	chmod 777 /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/tmp
	-mkdir -p /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/cache
	chmod 777 /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/cache

patch-winbindist:
	-@if [ "$(BBBIKEVER)" = "3.16" ] ; then \
	    cp -p patches/3.16/bbbike_0.config /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/bbbike_0.config; \
	    chmod 644 /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/bbbike_0.config; \
	fi

bbbike.iss: make-BBBikeVar.tpl make-winbindist patch-winbindist bbbike.tpl.iss
	tpage --debug=undef --define use_strawberry=1 --define VERSION=$(BBBIKEVER) --eval_perl bbbike.tpl.iss > bbbike.iss~
	mv bbbike.iss~ bbbike.iss

make-windows-installer: bbbike.iss
	cp bbbike.iss /tmp/BBBike-$(BBBIKEVER)-Windows/
	chmod ugo+r /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike.iss
	chmod ugo+w /tmp/BBBike-$(BBBIKEVER)-Windows
	@echo "Now start the Inno Setup Compiler with the bbbike.iss file"
	@echo "on T:\\BBBike-$(BBBIKEVER)-Windows (or Z:\\BBBike-$(BBBIKEVER)-Windows)"

devel:
	$(MAKE) make-windows-installer BBBIKEVER=$(BBBIKEDEVELVER)

######################################################################
# new rules for strawberry dist
#
# HOWTO use this rules
# - install a portable strawberry into \cygwin\home\eserte\strawberry
# - create \cygwin\home\eserte\bbbikewindist
# - copy ...\strawberry\perl into \cygwin\home\eserte\bbbikewindist\perl
# - copy (stripped down) gpsbabel distro into \cygwin\home\eserte\bbbikewindist\gpsbabel
# - open a cygwin shell
# - run in bbbike directory
#    perl Makefile.PL
# - then run these rules
#    cd port/windows
#    make bbbike-strawberry-dist make-bbbike-dist
#   (use bbbike-strawberry-snapshot-dist instead to create a snapshot)
# - run
#    /cygdrive/c/WINDOWS/system32/cmd.exe /c bbbike-snapshot-20091228.iss

bbbike-strawberry-dist: make-BBBikeVar.tpl
	tpage --debug=undef --define use_strawberry=1 --define VERSION=3.17 --eval_perl bbbike.tpl.iss > bbbike.iss~
	mv bbbike.iss~ bbbike.iss

bbbike-strawberry-snapshot-dist: make-BBBikeVar.tpl
	env SNAPSHOTDATE=`perl -MPOSIX=strftime -e 'print strftime "%Y%m%d", localtime'` sh -c 'tpage --debug=undef --define use_strawberry=1 --define VERSION=snapshot-$$SNAPSHOTDATE --eval_perl bbbike.tpl.iss > bbbike-snapshot-$$SNAPSHOTDATE.iss && chmod 755 bbbike-snapshot-$$SNAPSHOTDATE.iss'

# XXX TODOs:
# - all InlineDist.pm are missing in git --- should I include it? Or generate it, how? Or should I switch to Inline::C2XS as fast as possible?
# - data/.modified is missing, but may be created using miscsrc/create_modified.pl
make-bbbike-dist:
	[ -d ../../../../bbbikewindist ]
	-rm -rf ../../../../bbbikewindist/bbbike.old
	-mv ../../../../bbbikewindist/bbbike ../../../../bbbikewindist/bbbike.old
	perl "-MExtUtils::Manifest=manicopy,maniread" -e "chdir q{../..} or die; manicopy(maniread(q{MANIFEST}),q{../../bbbikewindist/bbbike}, 'cp');"

# XXX more rules missing:
#
# make-gpsbabel-dist:
# would grab a complete gpsbabel, strip everything but gpsbabel.exe,
# AUTHORS and COPYING and add a README where the rest may be found
# it would be especially nice if I could reuse the libexpat.dll from strawberry/perl/bin
#
# make-small-strawberry-dist:
# would grab a complete strawberry, remove unused parts and add (via CPAN?)
# essential modules to strawberry. Essential at least: Tk, but maybe
# everything listed in Bundle::windist

