#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: Makefile.PL,v 1.8 2003/01/08 20:58:32 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

use Inline::MakeMaker;

use Config;
use Cwd;

my $thisdir = getcwd();
chdir("../..");
my $root = getcwd();
chdir($thisdir);

WriteInlineMakefile
  (

   'NAME'	   => 'Strassen::Inline2',
   'VERSION_FROM'  => 'Inline2.pm',
   #'OBJECT'        => '../Strassen-Inline/heap$(OBJ_EXT)',

   'AUTHOR'        => 'Slaven Rezic (slaven@rezic.de)',

   'CCFLAGS'       => "$Config{ccflags} -ffast-math -fomit-frame-pointer",
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

__END__
