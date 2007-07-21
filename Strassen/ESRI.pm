# -*- perl -*-

#
# $Id: ESRI.pm,v 1.7 2007/07/20 19:33:49 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (c) 2001 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::ESRI;

use strict;
use vars qw(@ISA);

use BBBikeESRI;

@ISA = 'Strassen';

sub new {
    my($class, $filename, %arg) = @_;
    my $self = {};
    bless $self, $class;

    if ($filename) {
	my $shapefile = new ESRI::Shapefile;
	$shapefile->set_file($filename);
	$self->{Data} = [ map { "$_\n" }
			  split /\n/, $shapefile->as_bbd(-dbfinfo => 'NAME',
							 -autoconv => 0,
							)
			];
    }

    $self;
}

1;

__END__
