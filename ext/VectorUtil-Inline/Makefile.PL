#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: Makefile.PL,v 1.3 2004/01/17 23:26:31 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2004 Slaven Rezic. All rights reserved.
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
   'NAME'	   => 'VectorUtil::Inline',
   'VERSION_FROM'  => 'Inline.pm',
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
