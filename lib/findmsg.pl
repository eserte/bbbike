#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: findmsg.pl,v 1.1 2008/01/05 20:44:56 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

$perlfile = shift || die "Perl script?";
system("$^X -Mblib=$ENV{HOME}/src/perl/Msg -MO=FindMsg $perlfile");

__END__
