# -*- perl -*-

#
# $Id: ESRI.pm,v 1.4 2003/01/08 20:14:32 eserte Exp eserte $
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
	$self->{Data} = [ split /\n/, $shapefile->as_bbd(-dbfinfo => 'NAME',
							 -autoconv => 1,
							) ];
    }

    $self;
}

1;

__END__
