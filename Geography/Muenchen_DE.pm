# -*- perl -*-

#
# $Id: Muenchen_DE.pm,v 1.5 2003/01/08 20:12:45 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Geography::Muenchen_DE;

use strict;
# private:
use vars qw(%subcityparts %subcitypart_to_citypart %properties);

## Wie sieht's in München damit aus?
#  %subcityparts =
#      (
#      );

#  while(my($cp,$scp) = each %subcityparts) {
#      $subcitypart_to_citypart{$cp} = $cp; # self-reference
#      foreach (@$scp) { $subcitypart_to_citypart{$_} = $cp }
#  }

# XXX Methode
%properties =
    ('has_u_bahn' => 1,
     'has_s_bahn' => 1,
     'has_r_bahn' => 1,
     'has_map'    => 0,
     # XXX etc.: z.B. Icon-Namen, weitere Feinheiten wie 
     # map-Names, Zonen, overview-Karte...
    );

sub new {
    my($class) = @_;
    bless {}, $class;
}

# cityname in native or common language
sub cityname { "München" }

sub citypart_to_subcitypart { \%subcityparts }
sub subcitypart_to_citypart { \%subcitypart_to_citypart }

sub datadir {
    require File::Basename;
    my $pkg = __PACKAGE__;
    $pkg =~ s|::|/|g; # XXX other oses?
    $pkg .= ".pm";
    if (exists $INC{$pkg}) {
	$Strassen::Util::cacheprefix = "m_de";
	$main::center_on_coord = "1831,768"; # Marienplatz
	return File::Basename::dirname(File::Basename::dirname($INC{$pkg}))
	    . "/projects/radlstadtplan_muenchen/data_Muenchen_DE";
    }

    undef; # XXX better solution?
}

sub search_args {
#XXX     (WideSearch => 1);
    (Algorithm => "C-A*-2");
}

1;

__END__
