# -*- perl -*-

#
# $Id: MacOSXUtil.pm,v 1.2 2007/02/26 00:53:32 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2007 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package MacOSXUtil;

=head1 NAME

MacOSXUtil - a collection of MacOSX related functions

=head1 SYNOPSIS

    use MacOSXUtil;

=cut

use strict;
use vars qw($DEBUG $VERSION);

$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
$DEBUG=0 unless defined $DEBUG;

sub client_window_region {
    my($top) = @_;

    my @extends;
    if (eval { require CamelBones; import CamelBones; 1 }) {
	my $rect = NSScreen->mainScreen()->visibleFrame();
	# guess titlebar height
	@extends = (0, 0, $rect->getWidth, $rect->getHeight-25);
    } else {
	# guess titlebar+menubar+dock height
	@extends = (0, 0, $top->screenwidth-20, $top->screenheight-100);
    }
    @extends;
}

sub maximize {
    my($top) = @_;
    my @extends = client_window_region($top);
    $top->geometry("$extends[2]x$extends[3]+$extends[0]+$extends[1]");
}

1;

