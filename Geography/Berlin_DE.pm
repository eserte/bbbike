# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2000,2006,2015,2016,2018,2020,2022,2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.bbbike.de
#

# �berarbeiten anhand http://de.wikipedia.org/wiki/Berlin!
# U.U. "Ortslagen" (subsubcityparts) einf�hren

package Geography::Berlin_DE;

use strict;
# private:
use vars qw(%subcityparts %cityparts %subcitypart_to_citypart %properties);

use base qw(Geography::Base);

# (alte) Bezirke => Bezirksteile (Ortsteile oder -lagen)
%subcityparts =
    (
     'Charlottenburg'	 => [qw/Charlottenburg Charlottenburg-Nord Pichelsberg Westend
			        Witzleben/], # "Pichelsberg" und "Witzleben" sind nur Ortslagen
     'Friedrichshain'	 => [qw/Friedrichshain/],
     'Hellersdorf'	 => [qw/Hellersdorf Kaulsdorf Mahlsdorf/],
     'Hohensch�nhausen'	 => [qw/Falkenberg Margaretenh�he Wartenberg Malchow/,
			     "Alt-Hohensch�nhausen", "Neu-Hohensch�nhausen"], # "Margaretenh�he" ist nur eine Ortslage in Malchow
     'Kreuzberg'	 => [qw/Kreuzberg/],
     # Karolinenhof ist eine Ortslage in Schm�ckwitz (siehe http://de.wikipedia.org/wiki/Berlin-Schm%C3%B6ckwitz)
     # Hessenwinkel und Wilhelmshagen sind ebenfalls nur Ortslagen
     'K�penick'		 => [qw/K�penick Friedrichshagen Gr�nau Hessenwinkel
			        Karolinenhof
			        M�ggelheim Obersch�neweide Rahnsdorf
			        Schm�ckwitz Wilhelmshagen/],
     'Lichtenberg'	 => [qw/Lichtenberg Friedrichsfelde Karlshorst Rummelsburg
				Fennpfuhl/], # auf http://www.berlin.de/ba-lichtenberg/derbezirk/zeitreise.html wird auch "Alt-Lichtenberg" statt "Lichtenberg" erw�hnt
     'Marzahn'		 => [qw/Marzahn Biesdorf/],
     'Mitte'		 => [qw/Mitte/],
     'Neuk�lln'		 => [qw/Neuk�lln Britz Buckow Rudow Gropiusstadt/],
     'Pankow'		 => [qw/Pankow Blankenfelde Buch Niedersch�nhausen
			        Rosenthal Wilhelmsruh/,
			     'Franz�sisch Buchholz',
			     'Stadtrandsiedlung Malchow',
			    ], # Buchholz hei�t heute "Franz�sisch Buchholz"
     'Prenzlauer Berg'	 => ['Prenzlauer Berg'],
     'Reinickendorf'	 => [qw/Reinickendorf Borsigwalde Frohnau Heiligensee Hermsdorf
			        Konradsh�he L�bars Tegel Waidmannslust
			        Wittenau/, 'M�rkisches Viertel'], # Borsigwalde ist seit 2012-05 ein eigener Ortsteil, vorher nur eine Ortslage in Wittenau
     'Sch�neberg'	 => [qw/Sch�neberg Friedenau Sch�neberg-Nord/], # "Sch�neberg-Nord" ist nur eine Ortslage
     'Spandau'		 => [qw/Spandau Gatow Kladow Siemensstadt Haselhorst Staaken
				Wilhelmstadt Hakenfelde/,
			     'Falkenhagener Feld'],
     'Steglitz'		 => [qw/Steglitz Lankwitz Lichterfelde/],
     'Tempelhof'	 => [qw/Tempelhof Lichtenrade Mariendorf Marienfelde/],
     'Tiergarten'	 => [qw/Tiergarten Tiergarten-S�d Hansaviertel Moabit/], # "Tiergarten-S�d" ist nur eine Ortslage
     'Treptow'		 => [qw/Adlershof Altglienicke Baumschulenweg
			        Bohnsdorf Johannisthal
			        Niedersch�neweide Pl�nterwald/, 'Alt-Treptow'],
     'Wedding'		 => [qw/Wedding Gesundbrunnen/],
     'Wei�ensee'	 => [qw/Wei�ensee Blankenburg Heinersdorf Karow/],
     'Wilmersdorf'	 => [qw/Wilmersdorf Grunewald Schmargendorf Halensee/],
     'Zehlendorf'	 => [qw/Zehlendorf Dahlem Nikolassee Schlachtensee Wannsee/],
    );

while(my($cp,$scp) = each %subcityparts) {
    foreach (@$scp) { $subcitypart_to_citypart{$_} = $cp }
}

# (neue) Bezirke => (alte) Bezirke
%cityparts =
    ('Mitte'                            => [qw/Mitte Tiergarten Wedding/],
     'Friedrichshain-Kreuzberg'         => [qw/Friedrichshain Kreuzberg/],
     # war: Pankow-Prenzlauer Berg-Wei�ensee, aber das ist nicht korrekt
     'Pankow'				=> [qw/Pankow Wei�ensee/,
					    'Prenzlauer Berg'],
     'Charlottenburg-Wilmersdorf'       => [qw/Charlottenburg Wilmersdorf/],
     'Spandau'                          => ['Spandau'],
     'Steglitz-Zehlendorf'              => [qw/Steglitz Zehlendorf/],
     'Tempelhof-Sch�neberg'             => [qw/Tempelhof Sch�neberg/],
     'Neuk�lln'                         => [qw/Neuk�lln/],
     'Treptow-K�penick'                 => [qw/Treptow K�penick/],
     'Marzahn-Hellersdorf'              => [qw/Marzahn Hellersdorf/],
     'Lichtenberg' 			=> [qw/Lichtenberg Hohensch�nhausen/],
     'Reinickendorf'                    => [qw/Reinickendorf/],
    );


# XXX Methode
%properties =
    ('has_u_bahn' => 1,
     'has_s_bahn' => 1,
     'has_r_bahn' => 1,
     'has_map'    => 1,
     # XXX etc.: z.B. Icon-Namen, weitere Feinheiten wie
     # map-Names, Zonen, overview-Karte...
    );

# cityname in native or common language
sub cityname { "Berlin" }

sub center { "8581,12243" } # Brandenburger Tor
sub center_name { "Berlin" }

sub bbox_wgs84 { [13.051179, 52.337621, 13.764158, 52.689878] }

sub supercityparts { sort keys %cityparts }
sub cityparts      { sort keys %subcityparts }
sub subcityparts   { sort keys %subcitypart_to_citypart }

sub citypart_to_subcitypart { \%subcityparts }
sub subcitypart_to_citypart { \%subcitypart_to_citypart }

sub get_supercitypart_for_citypart { 
    shift; # object
    my $given_citypart = shift;
    keys %cityparts; # reset!!!
    while(my($supercitypart, $cityparts) = each %cityparts) {
	for my $citypart (@$cityparts) {
	    if ($citypart eq $given_citypart) {
		return $supercitypart;
	    }
	}
    }
    undef;
}

sub get_supercitypart_for_any {
    my $class = shift;
    my $given_part = shift;
    my $subcitypart_to_citypart = $class->subcitypart_to_citypart;
    if (exists $subcitypart_to_citypart->{$given_part}) {
	return $class->get_supercitypart_for_citypart($subcitypart_to_citypart->{$given_part});
    } else {
	my $ret = $class->get_supercitypart_for_citypart($given_part);
	return $ret if defined $ret;
	if (exists $cityparts{$given_part}) {
	    return $given_part;
	}
	return undef;
    }
}

sub get_cityparts_for_supercitypart {
    exists $cityparts{$_[1]} ? @{ $cityparts{$_[1]} } : ()
}

sub get_all_subparts { # ... recursive
    my($class, $name) = @_;
    if (!defined $name) {
	return map { $class->get_all_subparts($_) } $class->cityparts;
    }
    my %res = ($name => undef);
    if (exists $cityparts{$name}) {
	foreach my $cp (@{ $cityparts{$name} }) {
	    my @sub_res; @sub_res = $class->get_all_subparts($cp)
		unless $cp eq $name;
	    @res{@sub_res} = undef;
	}
    }
    if (exists $subcityparts{$name}) {
	@res{ @{$subcityparts{$name}} } = undef;
    }
    sort keys %res;
}

# XXX rename directory data to data_berlin_de?
sub datadir {
    require File::Basename;
    my $pkg = __PACKAGE__;
    $pkg =~ s|::|/|g; # XXX other oses?
    $pkg .= ".pm";
    if (exists $INC{$pkg}) {
	return File::Basename::dirname(File::Basename::dirname($INC{$pkg}))
	    . "/data";
    }
    undef; # XXX better solution?
}

sub parse_street_type_nr {
    my($self, $strname) = @_;
    my $type;
    my $do_round;
    my $image;
    if ($strname =~ /berlin\s*-\s*usedom/i) {
	$type = 'BU';
	$image = "BU.gif";
    } elsif ($strname =~ /berlin\s*-\s*kopenhagen/i) {
	$type = 'BK';
	$image = "BK.gif";
    } elsif ($strname =~ /berlin\s*-\s*leipzig/i) {
	$type = 'BL';
	$image = 'BL.png';
    } elsif ($strname =~ /mauer.*weg/i) {
	$type = 'M';
	$image = 'M.png';
    } elsif ($strname =~ /havelradweg/i) {
	$type = 'H';
	$image = 'H.png';
    } elsif ($strname =~ /havellandradweg/i) {
	$type = 'HVL';
	$image = 'HVL.gif';
    } elsif ($strname =~ /spreeradweg/i) {
	$type = 'SPR';
	$image = 'SPR.gif';
    } elsif ($strname =~ /hofjagdweg/i) {
	$type = 'HOF';
    } elsif ($strname =~ /uckerm.*rkischer\s+.*rundweg/i) {
	$type = 'UMR';
	$image = 'UMR.gif';
    } elsif ($strname =~ /tour.*brandenburg/i) {
	$type = 'TB';
	$image = 'TB.gif';
    } elsif ($strname =~ /oder.*nei(?:ss|�)e/i) {
	$type = 'ON';
	$image = 'ON.gif';
    } elsif ($strname =~ /flaeming.*skate/i) {
	$type = 'FS';
	$image = 'FS.gif';
    } elsif ($strname =~ /f.*rst.*p.*ckler/i) {
	$type = 'FR';
	$image = 'FR.gif';
    } elsif ($strname =~ /l.*wenberger.*land.*radtour/i) {
	$type = "LLR";
    } elsif ($strname =~ /haff.*radfernweg/i) {
	$type = "Haff";
    } elsif ($strname =~ /ostsee.*radweg/i) {
	$type = "Ostsee";
    } elsif ($strname =~ /berlin.*barnim.*oderbruch/i) {
	$type = 'BBO';
	$image = 'BBO.gif';
    } elsif ($strname =~ /Route Potsdam Nordost/i) {
	$type = 'Blau';
	$image = 'potsdamer_radrouten_blau.png';
    } elsif ($strname =~ /Route Potsdam Nord\b/i) {
	$type = 'Rot';
	$image = 'potsdamer_radrouten_rot.png';
    } elsif ($strname =~ /Route Alter Fritz/i) {
	$type = 'AF';
	$image = 'alter_fritz.png';
    } elsif ($strname =~ /K�penick-Route/i) {
	$type = 'Koe';
	$image = 'koepenick.png';
    } elsif ($strname =~ m{^R1($|\s)}) {
	$type = 'R1';
	$image = 'R1.png';
    } elsif ($strname =~ m{dahme.*radweg}i) {
	$type = 'Dhm';
	$image = 'dahme_radweg.png';
    } elsif ($strname =~ m{Reinickendorfer Route (\d+)}) {
	$type = "Rdf$1";
    }
    if (defined $type) {
	$do_round = 1;
    }
    ($type, undef, $do_round, $image);
}

# Feststellbar mit:
#    GET 'http://localhost/bbbike/cgi/bbbike.cgi?all=1' | wc
sub cgi_list_all_size { "(ca. 280 kB)" }

1;

__END__
