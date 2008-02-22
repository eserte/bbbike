#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbike-snapshot.cgi,v 1.2 2008/02/22 21:56:08 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Do not use FindBin, because it does not work with Apache::Registry
(my $target = $0) =~ s{bbbike-snapshot.cgi}{bbbike-data.cgi};
do $target;

# no __END__ for Apache::Registry
