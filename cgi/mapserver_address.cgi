#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: mapserver_address.cgi,v 1.8 2003/05/19 20:21:11 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use vars qw($BBBIKE_ROOT);
BEGIN {
    if ($ENV{SERVER_NAME} eq 'radzeit.herceg.de') {
	$BBBIKE_ROOT = "/home/e/eserte/www/www.radzeit.de/BBBike";
	@Strassen::datadirs = "$BBBIKE_ROOT/data";
    } else {
	$BBBIKE_ROOT = "/usr/local/apache/radzeit/BBBike";
	#$BBBIKE_ROOT = "/usr/local/apache/radzeit/BBBike2";
    }
}
use strict;
use FindBin;
use CGI qw(:standard);
use lib ("$BBBIKE_ROOT",
	 "$BBBIKE_ROOT/lib",
	 "$BBBIKE_ROOT/data",
	 "/home/e/eserte/src/bbbike",
	 "/home/e/eserte/src/bbbike/lib",
	 "/home/e/eserte/src/bbbike/data",
	); # XXX do not hardcode
use PLZ;

if (defined param("mapserver")) {
    redirect_to_ms();
} elsif (defined param("street") && param("street") !~ /^\s*$/) {
    resolve_street();
} elsif (defined param("coords") && param("coords") !~ /^\s*$/) {
    redirect_to_ms(param("coords"));
} elsif (defined param("city") && param("city") !~ /^\s*$/) {
    resolve_city();
} elsif (defined param("searchterm") && param("searchterm") !~ /^\s*$/) {
    resolve_fulltext();
} elsif (defined param("lat") && defined param("long") &&
	 param("lat") !~ /^\s*$/ && param("long") !~ /^\s*$/) {
    resolve_latlong(param("lat"), param("long"));
} else {
    print header,
	  start_html("Auswahl nach Straﬂen und Orten"),
	  h1("Auswahl nach Straﬂen und Orten");
    show_form();
    print end_html;
}

sub show_form {
    print h2("Berlin"), start_form;
    print table({-border=>0},
		Tr(
		   [
		    td(['Straﬂe' , textfield('street'), submit(-value => "Zeigen")]),
		    td(['Bezirk' , textfield('citypart'), "(optional)"]),
		   ]
                  )
	       );
    print end_form, hr;

    print h2("Brandenburg"), start_form;
    print table({-border=>0},
		Tr(
		   [
		    td(['Ort' , textfield('city'), submit(-value => "Zeigen")]),
		   ]
                  )
	       );
    print end_form, hr;

    print h2("Volltextsuche"), start_form;
    print table({-border=>0},
		Tr(
		   [
		    td(['Begriff' , textfield('searchterm'), submit(-value => "Zeigen")]),
		   ]
                  )
	       );
    print end_form, hr;

    print h2("Breite/L‰nge"), start_form;
    print table({-border=>0},
		Tr(
		   [
		    td(['(Angaben als DDD)']),
		    td(['Breite' , textfield('lat')]),
		    td(['L‰nge' , textfield('long'), submit(-value => "Zeigen")]),
		   ]
                  )
	       );
    print end_form, hr;

    print start_form, submit("mapserver", "Zur¸ck zum Mapserver"), end_form;
}

sub resolve_street {
    my $plz = PLZ->new;
    my @args;
    if (defined param("citypart") && param("citypart") !~ /^\s*$/) {
	push @args, Citypart => param("citypart");
    }
    push @args, Agrep => "default";
    my($res_ref, $errors) = $plz->look_loop(PLZ::split_street(param("street")), @args);
    if (!@$res_ref) {
	print header, start_html("Auswahl nach Straﬂen und Orten"), h1("Auswahl nach Straﬂen und Orten");
	print "Nichs gefunden!<br>";
	show_form();
	print end_html;
    } elsif (@$res_ref > 1) {
	splice @$res_ref, 20 if @$res_ref > 20;
	print header, start_html("Auswahl nach Straﬂen und Orten"), h1("Auswahl nach Straﬂen und Orten");
	print start_form;
	print h2("Mehrere Straﬂen gefunden");
	print radio_group
	    (-name=>"coords",
	     -values => [map { $_->[PLZ::LOOK_COORD] } @$res_ref],
	     -labels => {map { ($_->[PLZ::LOOK_COORD] =>
				$_->[PLZ::LOOK_NAME] . " (" . $_->[PLZ::LOOK_CITYPART] . ", " . $_->[PLZ::LOOK_ZIP] . ")" ) } @$res_ref},
	     -linebreak => "true",
	    ), br;
	print submit(-value => "Zeigen");
	print end_form, hr;
	show_form();
	print end_html;
    } else {
	my $xy = $res_ref->[0][PLZ::LOOK_COORD];
	redirect_to_ms($xy);
    }
}

sub resolve_city {
    my $norm = sub {
	my $s = shift;
	$s =~ s/([ƒ÷‹])/{"ƒ"=>"‰","÷"=>"ˆ","‹"=>"¸"}->{$1}/ge;
	lc $s;
    };

    my $city = $norm->(param("city"));
    require Strassen::Core;
    require Strassen::MultiStrassen;
    my $s = MultiStrassen->new("orte", "orte2");
    my @res;
    for my $stage (0 .. 1) {
	$s->init;
	while(1) {
	    my $ret = $s->next;
	    last if !@{ $ret->[Strassen::COORDS()] };
	    my $norm_name = $norm->($ret->[Strassen::NAME()]);
	    if ($stage == 0 && ($norm_name eq $city ||
				$norm_name =~ /^\Q$city\E\|/)) {
		push @res, $ret;
	    } elsif ($stage == 1 && $norm_name =~ /^\Q$city/) {
		push @res, $ret;
	    } else {
		# XXX String::Approx
	    }
	}
	if (@res) {
	    last;
	}
    }
    if (!@res) {
	print header, start_html("Auswahl nach Straﬂen und Orten"), h1("Auswahl nach Straﬂen und Orten");
	print "Nichs gefunden!<br>";
	show_form();
	print end_html;
    } elsif (@res == 1) {
	my $xy = $res[0]->[Strassen::COORDS()]->[0];
	redirect_to_ms($xy);
    } else {
	splice @res, 20 if @res > 20;
	print header, start_html("Auswahl nach Straﬂen und Orten"), h1("Auswahl nach Straﬂen und Orten");
	print h2("Mehrere Orte gefunden");
	print start_form;
	print radio_group
	    (-name=>"coords",
	     -values => [map { $_->[Strassen::COORDS()]->[0] } @res],
	     -labels => {map { my $n = $_->[Strassen::NAME()];
			       $n =~ s/\|/ /;
			       ($_->[Strassen::COORDS()]->[0] => $n)
			   } @res},
	     -linebreak => "true",
	    ), br;
	print submit(-value => "Zeigen");
	print end_form, hr;
	show_form();
	print end_html;
    }
}

sub resolve_fulltext {
    require Strassen::Core;
    require File::Basename;

    my $STRASSEN_FILE   = Strassen::LAST() + 1;
    my $STRASSEN_CENTER = Strassen::LAST() + 2;
    my $STRASSEN_LABEL  = Strassen::LAST() + 3;

    # heurstic to find data directory
    my $dir;
    for my $try_dir (@INC) {
	if (-e "$try_dir/strassen") {
	    $dir = $try_dir;
	    last;
	}
    }
    if (!defined $dir) {
	die "Cannot find data directory in @INC";
    }

    my @res;
    my @files = grep { !/(relation_gps|coords\.data|ampelschaltung|-orig|-info|~|\.st|\.desc|RCS|CVS)$/ } glob("$dir/*");
    die "No files in directory $dir" if !@files; # should not happen
    my @cmd = ("fgrep", "-i", "--", param("searchterm"), @files);
    #warn "Cmd: @cmd\n";
    open(GREP, "-|") or do {
	exec @cmd;
	die $!;
    };
    while(<GREP>) {
	my($file, $line) = split /:/, $_, 2;
	my($ret) = Strassen::parse($line);
	if ($ret->[Strassen::COORDS()] && @{$ret->[Strassen::COORDS()]}) {
	    $ret->[$STRASSEN_FILE] = File::Basename::basename($file);
	    $ret->[$STRASSEN_CENTER] = $ret->[Strassen::COORDS()]->[$#{$ret->[Strassen::COORDS()]}/2];
	    $ret->[$STRASSEN_LABEL] = file_to_label($ret->[$STRASSEN_FILE]);
	    push @res, $ret;
	}
    }
    close GREP;
    if (!@res) {
	print header, start_html("Auswahl nach Straﬂen und Orten"), h1("Auswahl nach Straﬂen und Orten");
	print "Nichs gefunden!<br>";
	show_form();
	print end_html;
    } elsif (@res == 1) {
	my $xy = $res[0]->[Strassen::COORDS()]->[0];
	redirect_to_ms($xy);
    } else {
	splice @res, 40 if @res > 40;
	my @new_res;
	my %seen;
	for my $element (@res) {
	    if (!$seen{$element->[$STRASSEN_CENTER]}) {
		push @new_res, $element;
		$seen{$element->[$STRASSEN_CENTER]}++;
	    }
	}
	@res = @new_res;

	print header, start_html("Auswahl nach Straﬂen und Orten"), h1("Auswahl nach Straﬂen und Orten");
	print h2("Mehrere Treffer");
	print start_form;
	print radio_group
	    (-name=>"coords",
	     -values => [map { $_->[$STRASSEN_CENTER] }
			 sort { lc $a->[Strassen::NAME()] cmp lc $b->[Strassen::NAME()]}
			 @res],
	     -labels => {map { my $n = $_->[Strassen::NAME()];
			       $n =~ s/\|/ /;
			       $n .= " (" . $_->[$STRASSEN_LABEL] . ")";
			       ($_->[$STRASSEN_CENTER] => $n)
			   } @res},
	     -linebreak => "true",
	    ), br;
	print submit(-value => "Zeigen");
	print end_form, hr;
	show_form();
	print end_html;
    }
}

sub resolve_latlong {
    my($lat, $long) = @_;
    require Karte;
    $Karte::Polar::obj = $Karte::Polar::obj; # cease -w
    Karte::preload("Standard", "Polar");
    my($x, $y) = map { int } $Karte::Polar::obj->map2standard($long, $lat);
    redirect_to_ms("$x,$y");
}

sub redirect_to_ms {
    my($coord, %args) = @_;
    if (!$args{-scope}) {
	$args{-scope} = scope(split /,/, $coord);
    }
    $args{-scope} = "all," . $args{-scope};

    if ($args{-scope} eq 'city') {
	@args{qw(-width -height)} = (2000, 2000);
    } elsif ($args{-scope} eq 'region') {
	@args{qw(-width -height)} = (5000, 5000);
    } else {
	@args{qw(-width -height)} = (8000, 8000);
    }
    $args{-layers} = [qw(bahn flaechen gewaesser
			 faehren route grenzen orte)] if !$args{-layers};
    require BBBikeMapserver;
    my $ms = BBBikeMapserver->new;
    if (0 && $ENV{SERVER_NAME} =~ /radzeit\.de/) { # XXX !!!
	$ms->read_config("$FindBin::RealBin/bbbike2.cgi.config"); # XXX do not hardcode
    } else {
	$ms->read_config("$FindBin::RealBin/bbbike.cgi.config"); # XXX do not hardcode
    }
    $ms->{Coords} = [$coord] if $coord;
    $ms->{CGI} = CGI->new;
    $ms->start_mapserver(%args);
}

# values from ..../data/Makefile
sub scope {
    my($x,$y) = @_;
    my @scopes = ([-15700,31300,37300,-8800],
		  [-80800,81600,108200,-86200],
		 );
    for my $i (0 .. $#scopes) {
	if ($x > $scopes[$i]->[0] &&
	    $x < $scopes[$i]->[2] &&
	    $y > $scopes[$i]->[3] &&
	    $y < $scopes[$i]->[1]) {
	    if ($i == 0) {
		return "city";
	    } else {
		return "region";
	    }
	}
    }
    "wideregion";
}

sub file_to_label {
    my $file = shift;
    my %map =
	(
	 'Berlin.coords.data' => 'Berliner Koordinaten',
	 'Berlin_and_Potsdam.coords.data' => 'Berliner und Potsdamer Koordinaten',
	 'Potsdam.coords.data' => 'Potsdamer Koordinaten',
	 ampeln => 'Ampeln',
	 ampelschaltung => 'Ampelschaltungen',
	 berlin => 'Grenzen von Berlin',
	 comments => 'Kommentare',
	 deutschland => 'Grenzen von Deutschland',
	 faehren => 'F‰hren',
	 flaechen => 'Fl‰chen (Parks, W‰lder, Flugh‰fen ...)',
	 gesperrt => 'Gesperrte und Einbahnstraﬂen',
	 gesperrt_car => 'Gesperrte Straﬂen f¸r motorisierten Verkehr',
	 green => 'Gr¸ne Wege',
	 handicap_l => 'Sonstige Behinderungen (Landstraﬂen)',
	 handicap_s => 'Sonstige Behinderungen (Stadtstraﬂen)',
	 hoehe => 'Hˆhenpunkte',
	 housenumbers => 'Hausnummern',
	 innerberliner_grenze => 'Innerberliner Grenze',
	 kinos => 'Kinos',
	 kneipen => 'Kneipen',
	 label => 'Labels',	# XXX
	 nolighting => 'Stadtstraﬂen ohne Beleuchtung',
	 orte => 'Orte',
	 orte2 => 'Orte (jwd)',
	 orte_city => 'Besondere Bezirke in Berlin',
	 plaetze => 'Pl‰tze',
	 plz => 'Postleitzahlgebiete',
	 potsdam => 'Grenzen von Potsdam',
	 qualitaet_l => 'Straﬂenqualit‰t (Landstraﬂen)',
	 qualitaet_s => 'Straﬂenqualit‰t (Stadtstraﬂen)',
	 radwege => 'Radwege, Busspuren, verkehrsberuhigte Bereiche',
	 radwege_exact => 'Radwege (exakte Koordinaten)',
	 rbahn => 'Regionalbahnlinien',
	 rbahnhof => 'Regionalbahnhˆfe',
	 relation_gps => 'Relationen zu GPS-Punkten',
	 sbahn => 'S-Bahnlinie',
	 sbahnhof => 'S-Bahnhof',
	 sbahnhof_bg => 'behindertenfreundliche Zug‰nge an S-Bahnhˆfen',
	 sehenswuerdigkeit => 'Sehensw¸rdigkeiten, ˆffentliche Geb‰ude',
	 strassen => 'Stadtstraﬂen',
	 strassen_b_and_p => 'Stadtstraﬂen in Berlin und Potsdam',
	 ubahn => 'U-Bahnlinien',
	 ubahnhof => 'U-Bahnhˆfe',
	 ubahnhof_bg => 'behindertenfreundliche Zug‰nge an U-Bahnhˆfen',
	 vorfahrt => 'abknickende Vorfahrtsstraﬂen',
	 wasserstrassen => 'Gew‰sser in Berlin',
	 wasserumland => 'Gew‰sser im Umland',
	 wasserumland2 => 'Gew‰sser jwd',
	);
    exists $map{$file} ? $map{$file} : $file;
}

__END__
