#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: Makefile.PL,v 1.7 2003/01/08 20:58:10 eserte Exp $
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
   'DEFINE'          => '-DINT_SQRT', # XXX only for ipaqs
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
