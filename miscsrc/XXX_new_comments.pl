#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use lib ("/home/e/eserte/src/bbbike/lib",
	 "/home/e/eserte/src/bbbike",
	 "/home/e/eserte/src/bbbike/data",
	);
use Strassen;
use Strassen::Kreuzungen;
use Strassen::Dataset;
use BBBikeUtil qw(m2km);
use YAML;
use Getopt::Long;

my $skip_lines;
GetOptions("skiplines=i" => \$skip_lines) or die "usage!";

# base net
my $s = Strassen->new("strassen");
my $net = StrassenNetz->new($s);
$net->make_net(UseCache => 1);

my $kr = Kreuzungen->new(Strassen => $s, UseCache => 1);

# attrib net
my $qs = MultiStrassen->new
    ("qualitaet_s", "handicap_s", map { "comments_$_" } grep { $_ ne "kfzverkehr" } @Strassen::Dataset::comments_types);
my $qs_net = StrassenNetz->new($qs);
$qs_net->make_net_cat(-usecache => 1, -net2name => 1, -multiple => 1);

my $cgi = "/home/e/eserte/src/bbbike/cgi/bbbike.cgi";
my @logfiles = ("/home/e/eserte/www/log/radzeit.combined_log",
		"/home/e/eserte/www/log/radzeit.combined_log.0",
	       );

sub len_fmt ($) {
    my $len = shift;
    m2km($len);
}

use CGI;
use URI::Escape;

for my $logfile (@logfiles) {
    open(LOG, "tail -r $logfile | ") or die $!;
    while(<LOG>) {
	if ($skip_lines > 0) {
	    $skip_lines--;
	    next;
	}
	my $d = parse_line($_);
	next if !$d;
	process_data($d);
	output_data($d);
    }
}

sub parse_line {
    my $line = shift;
    my $lastcoords;
    if ($line =~ m{GET\s+
		   (?:
		    /~eserte/bbbike/cgi/bbbike\.cgi |
		    /cgi-bin/bbbike\.cgi            |
		    /bbbike/cgi/bbbike\.cgi
		   )\?(.*)\s+HTTP[^"]+"\s(\d+)}x
       ) {
	my $query_string = $1;
	my $status_code = $2;
	if ($status_code =~ /^[45]/) {
	    return;
	}

	my %has;
	for my $type (qw(start via ziel)) {
	    if ($query_string =~ /${type}c=([^&; ]+)/) {
		my $coords = uri_unescape(uri_unescape($1));
		next if $coords =~ /^\s*$/;
		my $name = "$coords";
		if ($type =~ /(?:start|ziel)/) {
		    $has{$type}++;
		}
		if ($line =~ /${type}name=([^&; ]+)/) {
		    $name = uri_unescape(uri_unescape($1));
		}
		my $date = "???";
		if ($line =~ m{(\d+/[a-z]+/\d+:\d+:\d+:\d+)}i) {
		    $date = $1;
		}
	    }
	}
	if ($has{start} && $has{ziel}) {
	    my $q = CGI->new($query_string);
	    $q->param("output_as", "yaml");

	    $ENV{QUERY_STRING} = $q->query_string;
	    $ENV{REQUEST_METHOD} = "GET";

	    my $yaml = `$cgi`;

	    my $d = YAML::Load($yaml);
	    return $d;
        }
    }
}

sub process_data {
    my $d = shift;

    my $path_i = 0;

    my $get_hop_coords = sub {
	my($hop_i) = @_;
	my $end_coord = $d->{Route}[$hop_i+1]{Coord};
	my @coords;
	while(1) {
	    last if $path_i > $#{ $d->{Path} };
	    my $coord = $d->{Path}[$path_i];
	    push @coords, $coord;
	    last if $coord eq $end_coord;
	    $path_i++;
	}
	@coords;
    };

    for my $hop_i (0 .. $#{ $d->{Route} } - 1) {
	my @hop_coords = $get_hop_coords->($hop_i);

	my $process = sub {
	    my($k, $v) = @_;

	    my $begin_coord = $hop_coords[$v->[0]];
	    my $end_coord   = $hop_coords[$v->[1]];

	    $k =~ s/^.*?:\s*//;
	    my $main_street = $d->{Route}[$hop_i]{Strname};
	    #print $main_street . "\t";

	    my $ret;
	    if ($v->[0] == 0 && $v->[1] == $#hop_coords) {
		$ret = "$k (*)"; # XXX "(*)" only for debugging
	    } else {
		my $prev_street = $hop_i >= 0 ? $d->{Route}[$hop_i-1]{Strname} : undef;

		my $begin_crossing = eval { $kr->get($begin_coord) };
		$begin_crossing = [ map { Strasse::strip_bezirk($_) } @$begin_crossing ];
		$begin_crossing = [ Strasse::get_crossing_streets($main_street, $prev_street, $begin_crossing) ];
		if (@$begin_crossing == 0) {
		    undef $begin_crossing;
		} else {
		    $begin_crossing = $begin_crossing->[0];
		    $begin_crossing =~ s/^\(//;
		    $begin_crossing =~ s/\)$//;
		}
		
		my $end_crossing   = eval { $kr->get($end_coord)   };
		$end_crossing = [ map { Strasse::strip_bezirk($_) } @$end_crossing ];
		$end_crossing = [ Strasse::get_crossing_streets($main_street, $prev_street, $end_crossing) ];
		if (@$end_crossing == 0) {
		    undef $end_crossing;
		} else {
		    $end_crossing = $end_crossing->[0];
		    $end_crossing =~ s/^\(//;
		    $end_crossing =~ s/\)$//;
		}

		if ($v->[0] == 0 && defined $end_crossing) {
		    $ret = "bis $end_crossing: $k";
		} elsif (defined $begin_crossing && $v->[1] == $#hop_coords) {
		    $ret = "ab $begin_crossing: $k";
		} elsif (defined $begin_crossing && defined $end_crossing) {
		    $ret = "zwischen $begin_crossing und $end_crossing: $k";
		    # alternativ: ab ... bis ...
		} elsif (!defined $begin_crossing && !defined $end_crossing) {
		    my $len1 = len_fmt get_path_part_len(\@hop_coords, 0, $v->[0]);
		    my $len2 = len_fmt get_path_part_len(\@hop_coords, $v->[0], $v->[1]);
		    $ret = "nach $len1 f¸r $len2: $k";
		} elsif (defined $begin_crossing && !defined $end_crossing) {
		    my $len = len_fmt get_path_part_len(\@hop_coords, $v->[0], $v->[1]);
		    $ret = "ab $begin_crossing f¸r $len: $k";
		} elsif (!defined $begin_crossing && defined $end_crossing) {
		    my $len = len_fmt get_path_part_len(\@hop_coords, 0, $v->[0]);
		    $ret = "nach $len bis $end_crossing: $k";
		} elsif (!defined $begin_crossing && $v->[1] == $#hop_coords) {
		    my $len = len_fmt get_path_part_len(\@hop_coords, 0, $v->[0]);
		    $ret = "nach $len: $k";
		} elsif ($v->[0] == 0 && !defined $end_crossing) {
		    my $len = len_fmt get_path_part_len(\@hop_coords, 0, $v->[1]);
		    $ret = "f¸r $len: $k";
		} else {
		    die "Should never happen!";
		    $ret = "$begin_crossing $end_crossing";
		}
	    }
	    $ret;
	};

	my %last_attribs;
	my @new_comments;
	for my $hop_coord_i (1 .. $#hop_coords) {
	    my $is = $qs_net->{Net2Name}{$hop_coords[$hop_coord_i-1]}{$hop_coords[$hop_coord_i]};
	    my %next_last_attribs;
	    if (defined $is) {
		for my $i (@$is) {
		    my($r) = $qs->get($i);
		    my($name) = $r->[Strassen::NAME];
		    if (exists $last_attribs{$name}) {
			$next_last_attribs{$name} = [$last_attribs{$name}[0],
						     $hop_coord_i];
		    } else {
			$next_last_attribs{$name} = [$hop_coord_i-1];
		    }
		}
	    }
	    while(my($k,$v) = each %last_attribs) {
		if (!exists $next_last_attribs{$k}) {
		    $v->[1] = $hop_coord_i - 1; # XXX off by one?
		    push @new_comments, $process->($k, $v);
		    delete $last_attribs{$k};
		}
	    }
	    %last_attribs = %next_last_attribs;
	}

	while(my($k,$v) = each %last_attribs) {
	    if (!defined $v->[1]) {
		$v->[1] = $#hop_coords;
	    }

	    push @new_comments, $process->($k, $v);
	}

	if (@new_comments) {
	    $d->{Route}[$hop_i]{Comment} = join("; ", @new_comments);
	}
    }
}

sub output_data {
    my $d = shift;

    use Text::Table;
    use Text::Wrap;
    my $tb = Text::Table->new("Etappe", "Richtung", "Straﬂe", \"|", "Gesamt", \"|", "Bemerkungen");

    $tb->load(
	      map {
		  local $Text::Wrap::columns = 30;
		  my $strname = wrap("", "", $_->{Strname});
		  local $Text::Wrap::columns = 55;
		  my $comment = wrap("", "", $_->{Comment});
		  [$_->{DistString},
		   $_->{DirectionString},
		   $strname,
		   $_->{TotalDistString},
		   $comment,
		  ]
	      } @{ $d->{Route} }
	     );

    print $tb->title,
	  $tb->rule( '-', '+'),
	  $tb->body;
}

sub get_path_part_len {
    my($path_ref, $from_i, $to_i) = @_;
    my $len = 0;
    for my $i ($from_i + 1 .. $to_i) {
	$len += Strassen::Util::strecke_s($path_ref->[$i-1],
					  $path_ref->[$i]);
    }
    $len;
}

sub get_internal_test_data {

my $yaml =<<'EOF';
--- #YAML:1.0
Len: 5993
LongLatPath:
  - 13.413655,52.488360
  - 13.413992,52.488311
  - 13.413921,52.487512
  - 13.416331,52.480445
  - 13.417909,52.480122
  - 13.417843,52.478595
  - 13.418617,52.476662
  - 13.419668,52.472497
  - 13.419787,52.472100
  - 13.420115,52.470900
  - 13.420374,52.469863
  - 13.420955,52.467465
  - 13.421095,52.466807
  - 13.421206,52.466186
  - 13.421425,52.465257
  - 13.421834,52.462546
  - 13.417839,52.460522
  - 13.424916,52.457945
  - 13.427275,52.456355
  - 13.432911,52.452472
  - 13.436206,52.448974
  - 13.437584,52.448384
  - 13.438741,52.448228
  - 13.440141,52.447880
  - 13.440936,52.447457
  - 13.443971,52.445851
  - 13.441486,52.445419
Path:
  - 11108,9194
  - 11131,9189
  - 11128,9100
  - 11308,8317
  - 11416,8283
  - 11415,8113
  - 11472,7899
  - 11553,7437
  - 11562,7393
  - 11587,7260
  - 11607,7145
  - 11652,6879
  - 11663,6806
  - 11672,6737
  - 11689,6634
  - 11723,6333
  - 11456,6103
  - 11943,5825
  - 12107,5651
  - 12499,5226
  - 12731,4841
  - 12826,4777
  - 12905,4761
  - 13001,4724
  - 13056,4678
  - 13266,4503
  - 13098,4452
Power: {}
Route:
  - Angle: ~
    Comment: ''
    Coord: 11108,9194
    Direction: W
    DirectionString: nach W
    Dist: 0
    DistString: ~
    Strname: Hasenheide
    TotalDist: 0
    TotalDistString: ''
  - Angle: 70
    Comment: Parkweg
    Coord: 11131,9189
    Direction: r
    DirectionString: rechts (70∞) =>
    Dist: 23
    DistString: nach 0.02 km
    Strname: '(Hasenheide)'
    TotalDist: 23
    TotalDistString: 0.0 km
  - Angle: 50
    Comment: ''
    Coord: 11308,8317
    Direction: l
    DirectionString: links (50∞) in den
    Dist: 892
    DistString: nach 0.89 km
    Strname: Columbiadamm
    TotalDist: 915
    TotalDistString: 0.9 km
  - Angle: 70
    Comment: ''
    Coord: 11416,8283
    Direction: r
    DirectionString: rechts (70∞) in die
    Dist: 113
    DistString: nach 0.11 km
    Strname: Straﬂe 645
    TotalDist: 1028
    TotalDistString: 1.0 km
  - Angle: 0
    Comment: Kopfsteinpflaster
    Coord: 11472,7899
    Direction: ''
    DirectionString: ''
    Dist: 391
    DistString: nach 0.39 km
    Strname: Oderstr.
    TotalDist: 1419
    TotalDistString: 1.4 km
  - Angle: 0
    Comment: ''
    Coord: 11672,6737
    Direction: ''
    DirectionString: ''
    Dist: 1175
    DistString: nach 1.18 km
    Strname: Eschersheimer Str.
    TotalDist: 2594
    TotalDistString: 2.6 km
  - Angle: 50
    Comment: ''
    Coord: 11723,6333
    Direction: r
    DirectionString: rechts (50∞) in die
    Dist: 406
    DistString: nach 0.41 km
    Strname: Gottlieb-Dunkel-Str.
    TotalDist: 3000
    TotalDistString: 3.0 km
  - Angle: 100
    Comment: ''
    Coord: 11456,6103
    Direction: l
    DirectionString: links (100∞) in den
    Dist: 352
    DistString: nach 0.35 km
    Strname: Tempelhofer Weg
    TotalDist: 3352
    TotalDistString: 3.4 km
  - Angle: 20
    Comment: ''
    Coord: 12731,4841
    Direction: ''
    DirectionString: ''
    Dist: 1826
    DistString: nach 1.83 km
    Strname: Fulhamer Allee
    TotalDist: 5178
    TotalDistString: 5.2 km
  - Angle: 120
    Comment: ''
    Coord: 13266,4503
    Direction: r
    DirectionString: rechts (120∞) in die
    Dist: 640
    DistString: nach 0.64 km
    Strname: Parchimer Allee
    TotalDist: 5818
    TotalDistString: 5.8 km
  - Coord: 13098,4452
    DirectionString: angekommen!
    Dist: 175
    DistString: nach 0.17 km
    Strname: Parchimer Allee
    TotalDist: 5993
    TotalDistString: 6.0 km
Speed:
  10:
    Pref: ''
    Time: 0.600582223743283
  15:
    Pref: ''
    Time: 0.400388149162189
  20:
    Pref: 1
    Time: 0.300291111871641
  25:
    Pref: ''
    Time: 0.240232889497313
Trafficlights: 5

EOF

$yaml =<<'EOF';
--- #YAML:1.0
Len: 5993
LongLatPath:
  - 13.441486,52.445419
  - 13.443971,52.445851
  - 13.440936,52.447457
  - 13.440141,52.447880
  - 13.438741,52.448228
  - 13.437584,52.448384
  - 13.436206,52.448974
  - 13.432911,52.452472
  - 13.427275,52.456355
  - 13.424916,52.457945
  - 13.417839,52.460522
  - 13.421834,52.462546
  - 13.421425,52.465257
  - 13.421206,52.466186
  - 13.421095,52.466807
  - 13.420955,52.467465
  - 13.420374,52.469863
  - 13.420115,52.470900
  - 13.419787,52.472100
  - 13.419668,52.472497
  - 13.418617,52.476662
  - 13.417843,52.478595
  - 13.417909,52.480122
  - 13.416331,52.480445
  - 13.413921,52.487512
  - 13.413992,52.488311
  - 13.413655,52.488360
Path:
  - 13098,4452
  - 13266,4503
  - 13056,4678
  - 13001,4724
  - 12905,4761
  - 12826,4777
  - 12731,4841
  - 12499,5226
  - 12107,5651
  - 11943,5825
  - 11456,6103
  - 11723,6333
  - 11689,6634
  - 11672,6737
  - 11663,6806
  - 11652,6879
  - 11607,7145
  - 11587,7260
  - 11562,7393
  - 11553,7437
  - 11472,7899
  - 11415,8113
  - 11416,8283
  - 11308,8317
  - 11128,9100
  - 11131,9189
  - 11108,9194
Power: {}
Route:
  - Angle: ~
    Comment: ''
    Coord: 13098,4452
    Direction: W
    DirectionString: nach W
    Dist: 0
    DistString: ~
    Strname: Parchimer Allee
    TotalDist: 0
    TotalDistString: ''
  - Angle: 120
    Comment: ''
    Coord: 13266,4503
    Direction: l
    DirectionString: links (120∞) in die
    Dist: 175
    DistString: nach 0.17 km
    Strname: Fulhamer Allee
    TotalDist: 175
    TotalDistString: 0.2 km
  - Angle: 20
    Comment: ''
    Coord: 12731,4841
    Direction: ''
    DirectionString: ''
    Dist: 640
    DistString: nach 0.64 km
    Strname: Tempelhofer Weg
    TotalDist: 815
    TotalDistString: 0.8 km
  - Angle: 100
    Comment: ''
    Coord: 11456,6103
    Direction: r
    DirectionString: rechts (100∞) in die
    Dist: 1826
    DistString: nach 1.83 km
    Strname: Gottlieb-Dunkel-Str.
    TotalDist: 2641
    TotalDistString: 2.6 km
  - Angle: 50
    Comment: ''
    Coord: 11723,6333
    Direction: l
    DirectionString: links (50∞) in die
    Dist: 352
    DistString: nach 0.35 km
    Strname: Eschersheimer Str.
    TotalDist: 2993
    TotalDistString: 3.0 km
  - Angle: 0
    Comment: Kopfsteinpflaster
    Coord: 11672,6737
    Direction: ''
    DirectionString: ''
    Dist: 406
    DistString: nach 0.41 km
    Strname: Oderstr.
    TotalDist: 3399
    TotalDistString: 3.4 km
  - Angle: 0
    Comment: ''
    Coord: 11472,7899
    Direction: ''
    DirectionString: ''
    Dist: 1175
    DistString: nach 1.18 km
    Strname: Straﬂe 645
    TotalDist: 4574
    TotalDistString: 4.6 km
  - Angle: 70
    Comment: ''
    Coord: 11416,8283
    Direction: l
    DirectionString: links (70∞) in den
    Dist: 391
    DistString: nach 0.39 km
    Strname: Columbiadamm
    TotalDist: 4965
    TotalDistString: 5.0 km
  - Angle: 50
    Comment: Parkweg
    Coord: 11308,8317
    Direction: r
    DirectionString: rechts (50∞) =>
    Dist: 113
    DistString: nach 0.11 km
    Strname: '(Hasenheide)'
    TotalDist: 5078
    TotalDistString: 5.1 km
  - Angle: 70
    Comment: ''
    Coord: 11131,9189
    Direction: l
    DirectionString: links (70∞) =>
    Dist: 892
    DistString: nach 0.89 km
    Strname: Hasenheide
    TotalDist: 5970
    TotalDistString: 6.0 km
  - Coord: 11108,9194
    DirectionString: angekommen!
    Dist: 23
    DistString: nach 0.02 km
    Strname: Fichtestr. (Kreuzberg)
    TotalDist: 5993
    TotalDistString: 6.0 km
Speed:
  10:
    Pref: ''
    Time: 0.600582223743283
  15:
    Pref: ''
    Time: 0.400388149162189
  20:
    Pref: 1
    Time: 0.300291111871642
  25:
    Pref: ''
    Time: 0.240232889497313
Trafficlights: 5

EOF

my $d = YAML::Load($yaml);

$d;
}
__END__

XXX Weitere Verbesserungen:

"ab Treskowallee f¸r 2.2 km: Parkweg, OK; R1 (*); ab (Wuhlheide/FEZ):
Fuﬂg‰nger " => sortieren, und zwar: Gesamtstrecken zuerst, und dann
nach Startpunkt sortiert

"bis (Wuhlewanderweg, ˆstliches Ufer): bereits an der Ampel Kˆpenicker
Allee die Straﬂenseite wechseln (Straﬂenbahn auf Mittelstreifen); R1
(*); ab (Wuhlewanderweg, ˆstliches Ufer): zun‰chst linken Gehweg
benutzen" => f¸r PI und ‰hnliches keine Start/Endpunkte verwenden,
Sortierung siehe oben

"bis Schreiberhauer Str.: sehr guter Asphalt; ab Schreiberhauer Str.:
m‰ﬂiges Kopfsteinpflaster": wie bislang Q0 und q0 ignorieren

"zwischen Sonnenallee und Weigandufer" (Innstr) => was ist hier
passiert? (verbessert!)

"nach 0.1 km bis Tempelhofer Ufer: reger Fuﬂg‰ngerverkehr"
(Bl¸cherplatz) => besser w‰re es hier, wenn man den Gehwegbereich
explizit angeben w¸rde. Oder das Kaufhaus an der Stelle

"ab Hallesches Ufer f¸r 0.0 km: reger Fuﬂg‰ngerverkehr" => hmmm, hier
vielleicht die Meterangaben anzeigen oder "f¸r kurze Strecke"?

"ab Goethestr.: gutes Kopfsteinpflaster; ab Goethestr.: Mi und Sa
Wochenmarkt, Behinderungen mˆglich" => kann das hier zusammengefasst
werden?

ab Prinzregentenstr. f¸r 0.4 km: zum ‹berqueren der Bundesallee Ampel
an der Hildegarstr. (links) benutzen => "f¸r 0.4 km" ist hier albern

Hauptstr | bis (Am Rummelsburger See): wegen Straﬂenbahn so fr¸h wie
mˆglich auf die linke Gehwegseite wechseln; ab (Am Rummelsburger See)
f¸r 0.2 km: wegen Straﬂenbahn zun‰chst auf der linken Gehwegseite
weiterfahren => ups... solche Kommentare (PI;) nur anzeigen, wenn die
kompletter Strecke befahren wird!!!

Mangerstr. | Kopfsteinpflaster; Kopfsteinpflaster, Ausweichen auf
Uferweg mˆglich => geht es hier (landstrassen) mit der
Kreuzungserkennung nicht? (wahrscheinlich, siehe Sourcecode)

nach 0.0 km f¸r 0.1 km => optimieren: "nach 0.0 km" weglassen, "f¸r
0.0 km" in "f¸r eine kurze Strecke" ¸bersetzen

nach 0.0 km f¸r 0.0 km: rechts des Neuen Sees halten => jaja...

Gleimstr. | ab Swinem¸nder Str. f¸r 0.2 km: Kopfsteinpflaster (noch);
nach 0.2 km bis Schwedter Str.: Kopfsteinpflaster (noch) => hier hat
die Zusammenfassung nicht funktioniert, da einmal "Gleimtunnel" und
einmal "Gleimstr." vor dem Doppelpunkt in qualitaet_s-orig steht.
Ergo: zuerst abschneiden, dann zusammenfassen

ab Oberwallstr. f¸r 0.2 km: m‰ﬂiger Asphalt => statt "0.2 km" kˆnnte
man vielleicht "200 m" schreiben, ist k¸rzer und weniger pseudo-genau
(evtl. vielleicht auf 50er-Meter runden, um nicht ganz so ungenau zu
sein...) (lieber nicht, da ich in der Etappenbeschreibung auf 10 Meter
genau bin)

Klemkestr. | zwischen (An der Nordbahn) und (An der Nordbahn):
Berliner Mauer-Radweg => obskur, aber so ist meine Benamung der
Querstraﬂen...


DONE:

"ab (Lichtensteinallee - Tiergartenufer) Parkweg, Fuﬂg‰nger" => Klammern weg? ja! DONE
"nach 657 m f¸r 43 m Fuﬂg‰nger" => gruselig! DONE: Doppelpunkt, ungenauere Meterangaben
"ab Luckauer Str. Berliner Mauer-Radweg" => hier w‰re ein Doppelpunkt besser DONE
"bis Dorotheenstr. R1" => hier auch DONE
