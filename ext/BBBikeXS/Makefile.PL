#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: Makefile.PL,v 1.8 2003/02/20 14:10:50 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998-2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

use ExtUtils::MakeMaker;
use Config;
use Cwd;

my $thisdir = getcwd();
chdir("../..");
my $root = getcwd();
chdir($thisdir);

WriteMakefile
  (
   'NAME'	     => 'BBBikeXS',
   'VERSION_FROM'    => 'BBBikeXS.pm',
   'OBJECT'          => 'sqrt$(OBJ_EXT) $(BASEEXT)$(OBJ_EXT)',
   'LIBS'	     => [''],
   'DEFINE'          => "-DMAYBE_INT_SQRT", # Primarily for non-FPU machines, but seems to be faster on FPU machines, too. But: this is restricted to approx. 100 km distances, so do not use it everywhere!
   'INC'	     => '',
);

sub MY::install {
    if ($] >= 5.006) {
	"install:	all
	@\$(MOD_INSTALL) \\
		\$(INST_LIB) $root/lib \\
		\$(INST_ARCHLIB) $root/lib/$Config{'version'}/$Config{'archname'} \\

";
    } else {
	"install:	all
	@\$(MOD_INSTALL) \\
		\$(INST_LIB) $root/lib \\
		\$(INST_ARCHLIB) $root/lib/$Config{'archname'} \\

";
    }
}
