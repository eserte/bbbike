# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2005,2008,2011,2016 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (de): Bezirkslexikon des Luisenst‰dtischen Bildungsvereins (Luise-Berlin.de)
package LuiseBerlin;

# Das Straﬂenlexikon ist mittlerweile bei Kauperts ->
# plugins/KaupertsPlugin.pm

use strict;
use vars qw($VERSION @ISA);
$VERSION = 2.00;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use PLZ;
use Strassen::Strasse;
use WWWBrowser;

use vars qw($DEBUG);
$DEBUG = 1;

use vars qw($icon);

sub register {
    my $is_berlin = $main::city_obj && $main::city_obj->cityname eq 'Berlin';
    if ($is_berlin) {
	_create_image();
	$main::info_plugins{__PACKAGE__ . "_bezlex"} =
	    { name => "Luise-Berlin, Bexirkslexikon",
	      callback => sub { launch_bezlex_url(@_) },
	      callback_3_std => sub { show_bezlex_url(@_) },
	      icon => $icon,
	    };
	main::status_message("Das Luise-Berlin-Plugin wurde registriert. Der Link erscheint im Info-Fenster.", "info")
		if !$main::booting;
    } else {
	main::status_message("Das Luise-Berlin-Plugin ist nur f¸r Berlin verf¸gbar.", "err")
		if !$main::booting;
    }
}

sub _create_image {
    if (!defined $icon) {
	# Got from: http://www.luise-berlin.de/petschaft.gif
	# and used white background and scaled to 16x16
	$icon = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAOe2AEREgkxMeU1NdkxMhVFReVJShFJSiFRUf1dXeldXillZeltbfFtbiltb
i1tbjVxci1tblF5efWBgbmBggl9flGFhkGFhlWJilWJilmNjkmNjlGNjlmZmf2Vll2ZmkmZm
lGZmmmZmnGhojWdnmWpqhmlplmtriGtriWpqlWpqlmpql2trm2xslW1tmm9vkm9vmm9vnG9v
nnBwl3BwmHBwmXJyl3NzmXNzn3NzoHR0n3V1n3V1oXd3kXZ2mnV1o3d3oXh4m3l5oXt7knp6
nnt7nHt7pXt7qXx8qn19pX19qH5+oX9/oH9/qH9/qYKCoIGBqYGBqoGBroKCqoODpIODrYSE
p4SEqYSEq4WFpoaGqIiInYeHqoeHr4eHsYiIsImJs4yMtIyMto6OrY+Pt5GRtJOTspOTs5OT
tZOTtpSUtJSUtZaWtpeXsZeXtpiYuZmZuJmZupqaspubt5ubvJubvpycup2dsp+fvKCgvqOj
xaWlv6enwaioxaqqxqurx6uryK2txq2tx66uxq+vxa+vya+vzLCwxrCwx7CwybCwyrOzyLa2
zra20L6+0r+/08DA0cPD18TE1snJ2MvL3M3N2M3N3M7O5c/P4tLS4tPT3dPT39PT4djY6dnZ
49/f5uDg5uPj7uXl7unp8Onp8+zs8+3t8+3t9e/v9fDw9fHx9fLy9fPz+PT09vT0+PT0+fb2
+vf3+vf3+/r6/Pz8/f39/v///wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEKAP8ALAAAAAAQABAAAAj+AGsJrIXpy4os
V6DQCTVwYKsuRxyIQfEiRgkQf2YNhBWCSw8DMN6kYdLigRRFA8PcKJBh0qpVrmp1qmKliaZa
lyAYQKFnyhoSg2S9YsWGgRpVY5B8qGRKkCUhtQ5xoPRJho5IUc6oqNX06SgnErTUynEATqNN
arg6PeGCgIAttdpsgiSJ0x21lkwAUSACUy0ytBg9CSCHKyBLPGDFKRQhVocfYBylWOLJlB/E
AusgSBQoD59SWLzY2YMEzQRDSmwssFCGgqhamWiw+LGI1KlToOYMILKjz8BHGABc2FDER4IK
NUbgaVjLkZEZOIYEaeBBAyLmAlMBomLGTRJCqBoCBgQAOw==
EOF
    }
}

sub find_street {
    my($strname) = @_;
    if ($strname =~ /^\(/ || $strname =~ /^\s*$/) {
	main::status_message("Die Straﬂe <$strname> hat keinen offiziellen Namen", "err");
	return;
    }
    $strname =~ s{\[.*\]}{}g; # remove special [...] parts
    $strname =~ s{:\s+.*}{}g; # also remove everything after ":"
    my($street, @subcityparts) = Strasse::split_street_citypart($strname);
    if (!@subcityparts) {
	my $plz = PLZ->new;
	my @res = $plz->look($street);
	@subcityparts = map { $_->[PLZ::LOOK_CITYPART] } @res;
    }
    if (!@subcityparts) {
	main::status_message("Die Straﬂe <$strname> konnte in der BBBike-Datenbank nicht gefunden werden.", "err");
	return;
    }

    require Geography::Berlin_DE;
    my %cityparts = map { (Geography::Berlin_DE->subcitypart_to_citypart->{$_},1) } @subcityparts;

    ($street, [ keys %cityparts ]);
}

sub show_bezlex_url {
    my(%args) = @_;
    my($street, $cityparts) = find_street($args{street});
    if (!defined $street) {
	return;
    }

    require Geography::Berlin_DE;
    my %supercityparts = map { (Geography::Berlin_DE->get_supercitypart_for_citypart($_),1) } @$cityparts;

    my($supercitypart) = (keys %supercityparts)[0]; # use the first only
    warn "Translated @$cityparts -> $supercitypart ...\n" if $DEBUG;

    my $short = {"Friedrichshain-Kreuzberg" => "FrKr",
		 'Charlottenburg-Wilmersdorf' => "Chawi",
		 'Mitte' => 'Mitte',
		}->{$supercitypart};
    if (!$short) {
	main::status_message("F¸r den Bezirk $supercitypart existieren noch keine Eintr‰ge im Bezirkslexikon", "err");
	return;
    }

    $street =~ s{(s)tr\.}{$1traﬂe}i;
    # Cannot use BBBikeUtil::umlauts_* here, because of special rules
    # used in the LuiseBerlin html filename generation
    my $kill_umlauts = {"‰" => "ae",
			"ˆ" => "oe",
			"¸" => "ue",
			"ﬂ" => "ss",
			"ƒ" => "Ae",
			"÷" => "Oe",
			"‹" => "Ue",
			"È" => "_",
			"Ë" => "_",
			"Î" => "_",
			"·" => "_",
			" " => "_",
		       };
    my $left_part = join "", keys %$kill_umlauts;
    $street =~ s{([$left_part])}{$kill_umlauts->{$1}}ge;
    my $url = "http://www.luise-berlin.de/lexikon/" . $short .
	"/" . lc(substr($street,0,1)) .
	    "/" . $street . ".htm";
    $url;
}

sub launch_bezlex_url {
    my $url = show_bezlex_url(@_);
    start_browser($url);
}

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    WWWBrowser::start_browser($url);
}

1;

__END__
