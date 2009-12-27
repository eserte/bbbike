# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (de): Kauperts Straßenführer durch Berlin
package KaupertsPlugin;

use strict;
use vars qw($VERSION @ISA);
$VERSION = sprintf("%d.%02d", q$Revision: 1.30 $ =~ /(\d+)\.(\d+)/);

BEGIN {
    if (!caller(2)) {
	eval <<'EOF';
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
EOF
    die $@ if $@;
    }
}

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use CGI qw();
use Encode;

use PLZ;
use Strassen::Strasse;
use WWWBrowser;

use vars qw($DEBUG);
$DEBUG = 1;

use vars qw($icon);

sub register {
    _create_image();
    $main::info_plugins{__PACKAGE__ . ""} =
	{ name => "Kauperts Straßenführer",
	  callback => sub { launch_street_url(@_) },
	  icon => $icon,
	};
    main::status_message("Das Kauperts-Plugin wurde registriert. Der Link erscheint im Info-Fenster.", "info")
	    if !$main::booting;
}

sub _create_image {
    if (!defined $icon) {
	# Created using:
	#   wget http://berlin.kauperts.de/favicon.ico
	#   convert favicon.ico favicon.gif
	#   mmencode -b favicon.gif 
	$icon = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAPeFAAAAKQADKw4WOxQaOQAMQgAORgAOSAAPTAMQQgIQRAURRAEQTAAQTQES
TgoYSAsaTxMdQhQfQxYfQxEfTgIUUAUVUAYYUwcYUwgZUwoaVAscVw4eWR8mQBgiRhciSBgj
ShMgURcjUx0pUhsoVhAhWhEhWhIiWhIiWxIjWxMjWxQjWxEiXBMiXBMjXBMjXRMkXBMkXRQk
XBUlXBQlXRYlXRYmXRQlXhQlXxcoXhooWR0qWCcxUjI5UDY8VRUlYBUmYBoqYR0sYx4sYh8v
YyIxZSw7bDVBbztFaT5HaElWf1tjfU1Zg05Zg1FdhlRfh1VhiWdugnx/i3+Ek4OFkIiMl4GH
nIuPoISNqoWNqoqRrZaarLW2urO0vru8v7q9xMPFx8XGyMrKzMrLzM7Oz8XH0M/P09HR0tDS
1tjY2t7e39PW4d/g4OLi4eHh4+Pj5eXk5Ofo7+zs7e7u7/Dx9PDx9fLy9fLz9fHx9vf3+Pb3
+ff3+vj4+Pn5+Pj5+/r7+/n5/Pn6/Pr6/Pv8/v39/f79/f///wAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAAAAAAALAAAAAAQABAAAAjWAFMITBGDSJAW
BA3GEGhC4IsGS+yQyZEhS54qGVKYaEiwQRNAYyAUsfOmh4IYGwXGONCkjxgBVwZFAdACpQyV
LAF92SFHDQcFPwbi/OhlyqApAVq8QDgwhsc8aNzI4YEgqFCCLO0MGsQHioGFQlu0oOBEK59B
XhxsMIFyodisg6i0kYOkQVuOK5vkSTNAyyArBFpsBLvSCSAwApIMOiPiQgyUQ/mIgYBDDR8l
BpjifALoTIcKMbmE2KB5bEQuETIYOdPmiAXNKVoA0eHhw4sYIz6AeCEwIAA7
EOF
    }
}

sub find_street {
    my($strname) = @_;
    if ($strname =~ /^\(/ || $strname =~ /^\s*$/) {
	main::status_message("Die Straße <$strname> hat keinen offiziellen Namen", "err");
	return;
    }
    $strname =~ s{\[.*\]}{}g; # remove special [...] parts
    $strname =~ s{:\s+.*}{}g; # also remove everything after ":"
    my($street, @subcityparts) = Strasse::split_street_citypart($strname);
    my $plz = PLZ->new;
    my @res = $plz->look($street, (@subcityparts ? (Citypart => $subcityparts[0]) : ()));
    if (!@res) {
	main::status_message("Die Straße <$strname> konnte in der BBBike-Datenbank nicht gefunden werden.", "infodlg");
	return ($strname, undef, 'Berlin');
    }
    ($res[0]->[PLZ::LOOK_NAME], $res[0]->[PLZ::LOOK_ZIP], 'Berlin');
}

sub launch_street_url {
    my(%args) = @_;
    my($street, $zip, $city) = find_street($args{street});

    if (!defined $street) {
	return;
    }

## not working good:
#     $street =~ s{([sS])tr\.$}{$1traße};
#     $street = kill_umlauts($street);
#     $street =~ s{ }{-}g;
#     my $url = 'http://berlin.kauperts.de/Strassen/' . join('-', $street, $zip, $city);

    ## using Kauperts own search
    CGI->import('oldstyle_urls');
    my $url = 'http://berlin.kauperts.de/search?' . CGI->new({query => Encode::encode("utf-8", $street . (defined $zip ? " " . $zip : ''))})->query_string;

    start_browser($url);
}

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    WWWBrowser::start_browser($url);
}

sub kill_umlauts {
    my $s = shift;
    my $kill_umlauts = {"ä" => "ae",
			"ö" => "oe",
			"ü" => "ue",
			"ß" => "ss",
			"Ä" => "Ae",
			"Ö" => "Oe",
			"Ü" => "Ue",
			"é" => "e",
		       };
    my $left_part = join "", keys %$kill_umlauts;
    $s =~ s{([$left_part])}{$kill_umlauts->{$1}}ge;
    $s;
}

1;

__END__
