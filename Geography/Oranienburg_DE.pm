# -*- perl -*-

#
# $Id: Oranienburg_DE.pm,v 1.1 2007/07/18 20:49:00 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2007 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.bbbike.de
#

package Geography::Oranienburg_DE;

use strict;
# private:
use vars qw(%subcityparts %cityparts %subcitypart_to_citypart %properties);

use base qw(Geography::Base);

# XXX missing
%cityparts =
    (
     #'Mitte'                            => [qw/Mitte Tiergarten Wedding/],
    );


# XXX Methode
%properties =
    ('has_u_bahn' => 0,
     'has_s_bahn' => 1,
     'has_r_bahn' => 1,
     'has_map'    => 1,
     # XXX etc.: z.B. Icon-Namen, weitere Feinheiten wie
     # map-Names, Zonen, overview-Karte...
    );

# cityname in native or common language
sub cityname { "Oranienburg" }

sub center { "-1547,38500" }
sub center_name { "Oranienburg" }

sub supercityparts { () }
sub cityparts      { sort keys %subcityparts }
sub subcityparts   { () }

sub citypart_to_subcitypart { +{} }
sub subcitypart_to_citypart { +{} }

# reuse data from Berlin_DE
sub datadir {
    require Geography::Berlin_DE;
    shift;
    Geography::Berlin_DE->datadir(@_);
}

sub parse_street_type_nr {
    require Geography::Berlin_DE;
    shift;
    Geography::Berlin_DE->parse_street_type_nr(@_);
}

1;

__END__
