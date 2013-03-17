#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: Makefile.PL,v 1.4 2004/12/12 20:32:55 eserte Exp $
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

my $inlinedistpm = "CNetFileDist.pm";
my $inlinepm     = "CNetFile.pm";

if (! -e $inlinedistpm) {
    open(FH, ">> $inlinedistpm") or die $!;
    close FH;
    utime 0,0, $inlinedistpm;
}

WriteInlineMakefile
  (
   'NAME'	   => 'StrassenNetz::CNetFile',
   'VERSION_FROM'  => 'CNetFile.pm',
   'AUTHOR'        => 'Slaven Rezic (slaven@rezic.de)',
  );

sub MY::install {
    my $rule = "";
    if ($] >= 5.006) {
	$rule .= <<EOF;
install:	all
	@\$(MOD_INSTALL) \\
		\$(INST_LIB) $root/lib \\
		\$(INST_ARCHLIB) $root/lib/$Config{'version'}/$Config{'archname'} \\

EOF
    } else {
	$rule .= <<EOF;
install:	all
	@\$(MOD_INSTALL) \\
		\$(INST_LIB) $root/lib \\
		\$(INST_ARCHLIB) $root/lib/$Config{'archname'} \\

EOF
    }

    $rule .= <<EOF;
$inlinedistpm:	$inlinepm
	\$(PERL) ../inline2dist.pl \$(NAME)

EOF

    $rule;
}

__END__
