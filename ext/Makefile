#
# $Id: Makefile,v 1.15 2003/12/22 19:51:16 eserte Exp $
#

# XXX Installieren immer über *dieses* Makefile (wegen INLINE2DIST)!!!
# (in Zukunft INLINE2DIST besser in den einzelnen makefiles vor install aufrufen)

# cygwin: failures while building in some directories. Solution:
# build with "make -k" and try again

PERL?=perl
INLINE2DIST=$(PERL) ../inline2dist.pl

all:

ext:	ext-bbbikexs \
	ext-virtarray \
	ext-strassennetz-cnetfile \
	ext-strassen-inline \
	ext-strassen-inline2 \
	ext-vectorutil-inline

ext-bbbikexs: ext-bbbikexs-clean ext-bbbikexs-build ext-bbbikexs-install
ext-virtarray: ext-virtarray-clean ext-virtarray-build  ext-virtarray-install
ext-strassennetz-cnetfile: ext-strassennetz-cnetfile-clean ext-strassennetz-cnetfile-build  ext-strassennetz-cnetfile-install
ext-strassen-inline: ext-strassen-inline-clean ext-strassen-inline-build  ext-strassen-inline-install
ext-strassen-inline2: ext-strassen-inline2-clean ext-strassen-inline2-build  ext-strassen-inline2-install
ext-vectorutil-inline: ext-vectorutil-inline-clean ext-vectorutil-inline-build  ext-vectorutil-inline-install

ext-bbbikexs-clean:
	-cd BBBikeXS && $(PERL) Makefile.PL && ${MAKE} clean

ext-bbbikexs-build:
	cd BBBikeXS && $(PERL) Makefile.PL && ${MAKE} ${.MAKEFLAGS}

ext-bbbikexs-test:
	cd BBBikeXS && ${MAKE} ${.MAKEFLAGS} test

ext-bbbikexs-install:
	cd BBBikeXS && ${MAKE} ${.MAKEFLAGS} install


ext-virtarray-clean:
	-cd VirtArray && $(PERL) Makefile.PL && ${MAKE} clean

ext-virtarray-build:
	cd VirtArray && $(PERL) Makefile.PL && ${MAKE} ${.MAKEFLAGS}

ext-virtarray-test:
	cd VirtArray && ${MAKE} ${.MAKEFLAGS} test

ext-virtarray-install:
	cd VirtArray && ${MAKE} ${.MAKEFLAGS} install


ext-strassennetz-cnetfile-clean:
	-cd StrassenNetz-CNetFile && $(PERL) Makefile.PL && ${MAKE} clean

ext-strassennetz-cnetfile-build:
	cd StrassenNetz-CNetFile && $(INLINE2DIST) StrassenNetz::CNetFile && $(PERL) Makefile.PL && rm -f Inline.inl && env PERL5LIB=../..:../../lib:$$PERL5LIB ${MAKE} ${.MAKEFLAGS}

ext-strassennetz-cnetfile-test:
	cd StrassenNetz-CNetFile && env PER5LLIB=../..:../../lib:$$PERL5LIB ${MAKE} ${.MAKEFLAGS} test

ext-strassennetz-cnetfile-install:
	cd StrassenNetz-CNetFile && ${MAKE} ${.MAKEFLAGS} install


ext-strassen-inline-clean:
	-cd Strassen-Inline && $(PERL) Makefile.PL && ${MAKE} clean

ext-strassen-inline-build:
	cd Strassen-Inline && $(INLINE2DIST) Strassen::Inline && $(PERL) Makefile.PL && rm -f Inline.inl && ${MAKE} ${.MAKEFLAGS}

ext-strassen-inline-test:
	cd Strassen-Inline && ${MAKE} ${.MAKEFLAGS} test

ext-strassen-inline-install:
	cd Strassen-Inline && ${MAKE} ${.MAKEFLAGS} install


ext-strassen-inline2-clean:
	-cd Strassen-Inline2 && $(PERL) Makefile.PL && ${MAKE} clean

ext-strassen-inline2-build:
	cd Strassen-Inline2 && $(INLINE2DIST) Strassen::Inline2 && $(PERL) Makefile.PL && rm -f Inline.inl && ${MAKE} ${.MAKEFLAGS}

ext-strassen-inline2-test:
	cd Strassen-Inline2 && env PERL5OPT=-Mblib=../StrassenNetz-CNetFile ${MAKE} ${.MAKEFLAGS} test

ext-strassen-inline2-install:
	cd Strassen-Inline2 && ${MAKE} ${.MAKEFLAGS} install


ext-vectorutil-inline-clean:
	-cd VectorUtil-Inline && $(PERL) Makefile.PL && ${MAKE} clean

ext-vectorutil-inline-build:
	cd VectorUtil-Inline && $(INLINE2DIST) VectorUtil::Inline && $(PERL) Makefile.PL && rm -f Inline.inl && ${MAKE} ${.MAKEFLAGS}

ext-vectorutil-inline-test:
	cd VectorUtil-Inline && ${MAKE} ${.MAKEFLAGS} test

ext-vectorutil-inline-install:
	cd VectorUtil-Inline && ${MAKE} ${.MAKEFLAGS} install


strassen-inline2:
	rm -rf Strassen-Inline2
	$(PERL) ../miscsrc/filter_version.pl -prefix FILTER -version 2 Strassen-Inline Strassen-Inline2
	-rm -f Strassen-Inline2/InlineDist.pm
	-rm -f Strassen-Inline2/heap.*
	mv Strassen-Inline2/Inline.pm Strassen-Inline2/Inline2.pm

# only update
strassen-inline2-update:
	$(PERL) ../miscsrc/filter_version.pl -force -update -prefix FILTER -version 2 Strassen-Inline Strassen-Inline2
	-rm -f Strassen-Inline2/InlineDist.pm
	-rm -f Strassen-Inline2/heap.*
	-rm -f Strassen-Inline2/Inline2.pm
	mv Strassen-Inline2/Inline.pm Strassen-Inline2/Inline2.pm

clean:	ext-bbbikexs-clean \
	ext-virtarray-clean \
	ext-strassennetz-cnetfile-clean \
	ext-strassen-inline-clean \
	ext-strassen-inline2-clean \
	ext-vectorutil-inline-clean

build:	ext-bbbikexs-build \
	ext-virtarray-build \
	ext-strassennetz-cnetfile-build \
	ext-strassen-inline-build \
	ext-strassen-inline2-build \
	ext-vectorutil-inline-build

test:	ext-bbbikexs-test \
	ext-virtarray-test \
	ext-strassennetz-cnetfile-test \
	ext-strassen-inline-test \
	ext-strassen-inline2-test \
	ext-vectorutil-inline-test

install:ext-bbbikexs-install \
	ext-virtarray-install \
	ext-strassennetz-cnetfile-install \
	ext-strassen-inline-install \
	ext-strassen-inline2-install \
	ext-vectorutil-inline-install

GNUmakefile: Makefile
	../miscsrc/b2gmake < Makefile > GNUmakefile
	chmod ugo+r GNUmakefile
