#!/usr/bin/env perl
#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2003,2014,2016,2017 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
BEGIN {
    $BBBike::PLACK_TESTING = $BBBike::PLACK_TESTING if 0; # cease -w
    if (!$BBBike::PLACK_TESTING) {
	delete $INC{"FindBin.pm"}
    }
}

use FindBin;
use vars qw($BBBIKE_ROOT $BBBIKE_URL);
BEGIN { # XXX do not hardcode
    $ENV{SERVER_NAME} ||= "";
    if ($ENV{SERVER_NAME} eq 'bbbike.hosteurope.herceg.de') {
	$BBBIKE_ROOT = "/home/e/eserte/src/bbbike/projects/bbbike.de-hosteurope/BBBike";
	$BBBIKE_URL = "/BBBike";
	@Strassen::datadirs = "$BBBIKE_ROOT/data";
    } elsif ($ENV{SERVER_NAME} =~ m{(
					bbbike\.de$
				    |   bbbike-pps
				    |   lvps\d+-\d+-\d+-\d+\.dedicated\.hosteurope\.de$
				    )
			           }xi
	    ) {
	$BBBIKE_URL = "/BBBike";
    } else {
	$BBBIKE_URL = "/bbbike";
    }
    $BBBIKE_ROOT = "$FindBin::RealBin/.." if !defined $BBBIKE_ROOT;
    $BBBIKE_URL  = "/bbbike" if !defined $BBBIKE_URL;
}
use CGI qw(:standard *table);
use CGI::Carp;
use lib (defined $BBBIKE_ROOT ? ("$BBBIKE_ROOT",
				 "$BBBIKE_ROOT/lib",
				 "$BBBIKE_ROOT/data",
				 "$BBBIKE_ROOT/miscsrc",
				) : (),
	 "/home/e/eserte/src/bbbike",
	 "/home/e/eserte/src/bbbike/lib",
	 "/home/e/eserte/src/bbbike/data",
	 "/home/e/eserte/src/bbbike/miscsrc",
	); # XXX do not hardcode
use BBBikeCGI::Util ();

pathinfo_to_param();

if (!param("usemap")) {
    param("usemap", "mapserver");
}
if (defined param("mapserver")) {
    redirect_to_map();
} elsif (defined param("street") && param("street") !~ /^\s*$/) {
    resolve_street();
} elsif (defined param("coords") && param("coords") !~ /^\s*$/) {
    redirect_to_map(scalar param("coords"));
} elsif (defined param("city") && param("city") !~ /^\s*$/) {
    resolve_city();
} elsif (defined param("searchterm") && param("searchterm") !~ /^\s*$/) {
    resolve_fulltext();
} elsif (defined param("latD") && param("latD") !~ /^\s*$/ &&
	 defined param("latM") && param("latM") !~ /^\s*$/ &&
	 defined param("longD") && param("longD") !~ /^\s*$/ &&
	 defined param("longM") && param("longM") !~ /^\s*$/
	) {
    my $latS  = param("latS")||0;
    my $longS = param("longS")||0;
    require Scalar::Util;
    if (
	!Scalar::Util::looks_like_number(scalar param("latD")) ||
	!Scalar::Util::looks_like_number(scalar param("latM")) ||
	!Scalar::Util::looks_like_number(scalar param("longD")) ||
	!Scalar::Util::looks_like_number(scalar param("longM"))
       ) {
	show_html(error_dms => 1);
    } else {
	my $lat  = param("latD")  + param("latM")/60  + $latS/3600;
	my $long = param("longD") + param("longM")/60 + $longS/3600;
	resolve_latlong($lat, $long);
    }
} elsif (defined param("lat") && defined param("long") &&
	 param("lat") !~ /^\s*$/ && param("long") !~ /^\s*$/) {
    require Scalar::Util;
    if (
	!Scalar::Util::looks_like_number(scalar param("lat")) ||
	!Scalar::Util::looks_like_number(scalar param("long"))
       ) {
	show_html(error_ddd => 1);
    } else {
	resolve_latlong(scalar param("lat"), scalar param("long"));
    }
} else {
    show_html();
}

1; # for CGI::Compile - see https://github.com/miyagawa/CGI-Compile/issues/18

sub show_html {
    my(%args) = @_;
    my $css = <<'EOF';
.error { color:red; font-weightbold; }
EOF
    print header,
	  start_html(
		     -title => "Auswahl nach Stra�en und Orten",
		     -style => {-code => $css},
		    ),
	  h1("Auswahl nach Stra�en und Orten");
    show_form(%args);
    print end_html;
}

sub _form {
    print start_form(-action => url(-relative=>1)); # url -relative is safe, no my_url necessary
    print hidden("layer", BBBikeCGI::Util::my_multi_param("layer")) if param("layer");
    print hidden("mapext", BBBikeCGI::Util::my_multi_param("mapext")) if param("mapext");
    print hidden("usemap", BBBikeCGI::Util::my_multi_param("usemap"));
}

sub show_form {
    my(%args) = @_;
    my $error_dms = delete $args{error_dms};
    my $error_ddd = delete $args{error_ddd};
    warn "WARN: Unhandled argumets: " . join(" ", %args) if %args;

    print h2("Berlin");
    _form;
    print table({-border=>0},
		Tr(
		   [
		    td(['Stra�e' , textfield('street'), submit(-value => "Zeigen")]),
		    td(['Bezirk' , textfield('citypart'), "(optional)"]),
		   ]
                  )
	       );
    print end_form, hr;

    print h2("Brandenburg");
    _form;
    print table({-border=>0},
		Tr(
		   [
		    td(['Ort' , textfield('city'), submit(-value => "Zeigen")]),
		   ]
                  )
	       );
    print end_form, hr;

    print h2("Volltextsuche");
    _form;
    print table({-border=>0},
		Tr(
		   [
		    td(['Begriff' , textfield('searchterm'), submit(-value => "Zeigen")]),
		   ]
                  )
	       );
    print end_form, hr;

    print h2("Breite/L�nge");
    _form;
    print table({-border=>0},
		Tr(
		   [
		    td(['(Angaben als DDD)']),
		    ($error_ddd ? td({colspan=>9}, [span({-class=>'error'}, "Falsche Werte f�r DDD-Koordinaten, bitte nur Zahlen verwenden!")]) : ()),
		    td(['Breite' , textfield('lat')]),
		    td(['L�nge' , textfield('long'), submit(-value => "Zeigen")]),
		   ]
                  )
	       );
    print end_form;
    _form;
    # Check -size and -maxlength, N and E if porting to other world regions.
    print table({-border=>0},
		Tr(
		   [
		    td(['(Angaben als DMS)']),
		    ($error_dms ? td({colspan=>9}, [span({-class=>'error'}, "Falsche Werte f�r DMS-Koordinaten, bitte nur Zahlen verwenden!")]) : ()),
		    td(['Breite' ,
			'N', textfield(-name => 'latD', -size => 2, -maxlength => 2), '�',
			textfield(-name => 'latM', -size => 2, -maxlength => 2),"'",
			textfield(-name => 'latS', -size => 4, -maxlength => 2), "''"]),
		    td(['L�nge' ,
			'E', textfield(-name => 'longD', -size => 2, -maxlength => 2), '�',
			textfield(-name => 'longM', -size => 2, -maxlength => 2),"'",
			textfield(-name => 'longS', -size => 4, -maxlength => 2), "''",
			submit(-value => "Zeigen")]),
		   ]
                  )
	       );
    print end_form, hr;

    if (param("usemap") ne "googlemaps") {
	print start_form, submit("mapserver", "Zur�ck zum Mapserver"), end_form;
    }
}

sub resolve_street {
    require BBBikeRouting;
    my $br = BBBikeRouting->new;
    $br->init_context;
    ## XXX not enabled by default, because there is no db
    ## on radzeit for example
    #$br->Context->UseTelbuchDBApprox(1); # XXX experimental!!!
    my $start = $br->Start;
    $start->Street(scalar param("street"));
    $start->Citypart(scalar(param("citypart")) || undef);
    my $coord = $br->get_start_position(fixposition => 0);

    if (!defined $coord) {
	if (!$br->StartChoices || !@{$br->StartChoices}) {
	    print header, start_html("Auswahl nach Stra�en und Orten"), h1("Auswahl nach Stra�en und Orten");
	    print "Nichts gefunden!<br>";
	    show_form();
	    print end_html;
	    return;
	}

	splice @{$br->StartChoices}, 20 if @{$br->StartChoices} > 20;
	my $start_choices = combine_same_streets($br->StartChoices);
	print header, start_html("Auswahl nach Stra�en und Orten"), h1("Auswahl nach Stra�en und Orten");
	#print start_form;
	_form;
	print h2("Mehrere Stra�en gefunden");
	print radio_group
	    (-name=>"coords",
	     -values => [map { $_->{Coord} } values %$start_choices],
	     -labels => {map { ($_->{Coord} =>
				$_->{Street} . " (" . $_->{Citypart} . (defined $_->{ZIP} ? "; " . $_->{ZIP} : "") . ")" ) } values %$start_choices},
	     -linebreak => "true",
	    ), br;
	print submit(-value => "Zeigen");
	print end_form, hr;
	show_form();
	print end_html;
	return;
    }

    my $xy = $start->Coord;
    redirect_to_map($xy);
}

sub combine_same_streets {
    my $choices = shift;
    my %tmp;
    for my $choice (@$choices) {
	my $street = $choice->Street;
	my $coord = $choice->Coord;
	my $key = "$street $coord";
	if (!exists $tmp{$key}) { $tmp{$key} = [] }
	push @{ $tmp{$key} }, $choice;
    }

    my %res;
    for my $key (keys %tmp) {
	my %cityparts = map {($_->Citypart,1) } @{ $tmp{$key} };
	my %zip       = map { defined $_->ZIP ? ($_->ZIP, 1) : () } @{ $tmp{$key} };
	my $first = $tmp{$key}->[0];
	$res{$first->Coord} = { Coord => $first->Coord,
				Street => $first->Street,
				Citypart => join(", ", sort keys %cityparts),
				ZIP => join(", ", sort keys %zip),
			      };
    }

    \%res;
}

sub resolve_city {
    my $norm = sub {
	my $s = shift;
	$s =~ s/([���])/{"�"=>"�","�"=>"�","�"=>"�"}->{$1}/ge;
	lc $s;
    };

    my $city = $norm->(scalar param("city"));
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
	print header, start_html("Auswahl nach Stra�en und Orten"), h1("Auswahl nach Stra�en und Orten");
	print "Nichts gefunden!<br>";
	show_form();
	print end_html;
    } elsif (@res == 1) {
	my $xy = $res[0]->[Strassen::COORDS()]->[0];
	redirect_to_map($xy);
    } else {
	splice @res, 20 if @res > 20;
	print header, start_html("Auswahl nach Stra�en und Orten"), h1("Auswahl nach Stra�en und Orten");
	print h2("Mehrere Orte gefunden");
	_form;
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
    my $STRASSEN_ICON   = Strassen::LAST() + 4;
    my $STRASSEN_ICONS  = Strassen::LAST() + 5;

    # heurstic to find data directory
    my $dir;
    for my $try_dir (@Strassen::datadirs, @INC) {
	if (-e "$try_dir/strassen") {
	    $dir = $try_dir;
	    last;
	}
    }
    if (!defined $dir) {
	die "Cannot find data directory in @INC";
    }

    my @res;
    my @files = grep { -f $_ } map { "$dir/$_" }
	qw(
	      brunnels faehren flaechen fragezeichen landstrassen landstrassen2 orte orte2 plaetze
	      rbahn rbahnhof sbahn sbahnhof ubahn ubahnhof
	      sehenswuerdigkeit strassen wasserstrassen wasserumland wasserumland2
	 );
    die "No files in directory $dir" if !@files; # should not happen
    my @cmd = ("fgrep", "-i", "--", scalar(param("searchterm")), @files);
    #warn "Cmd: @cmd\n";
    open(GREP, "-|") or do {
	require File::Spec;
	open(STDERR, ">" . File::Spec->devnull)
	    or warn "Can't redirect stderr to /dev/null: $!";
	exec @cmd or die $!; # XXX actually not visible because of redirect
    };
    while(<GREP>) {
	my($file, $line) = split /:/, $_, 2;
	my($ret) = Strassen::parse($line);
	if ($ret->[Strassen::COORDS()] && @{$ret->[Strassen::COORDS()]}) {
	    $ret->[$STRASSEN_FILE] = File::Basename::basename($file);
	    $ret->[$STRASSEN_CENTER] = $ret->[Strassen::COORDS()]->[$#{$ret->[Strassen::COORDS()]}/2];
	    $ret->[$STRASSEN_LABEL] = file_to_label($ret->[$STRASSEN_FILE]);
	    $ret->[$STRASSEN_ICON] = file_to_icon($ret->[$STRASSEN_FILE]);
	    push @res, $ret;
	}
    }
    close GREP;
    if (!@res) {
	print header, start_html("Auswahl nach Stra�en und Orten"), h1("Auswahl nach Stra�en und Orten");
	print "Nichts gefunden!<br>";
	show_form();
	print end_html;
    } elsif (@res > 1) {
	my @new_res;
	my %seen;
	for my $element (@res) {
	    my $e = $element;
	    if (!exists $seen{$e->[$STRASSEN_CENTER]}) {
		push @new_res, $e;
		$seen{$e->[$STRASSEN_CENTER]} = $#new_res;
		$e->[$STRASSEN_ICONS] = [];
	    } else {
		$e = $new_res[$seen{$element->[$STRASSEN_CENTER]}];
	    }
	    if (defined $element->[$STRASSEN_ICON]) {
		push @{ $e->[$STRASSEN_ICONS] }, $element->[$STRASSEN_ICON];
	    }
	    last if @new_res > 40;
	}

	@res = @new_res;

	if (@res > 1) {
	    print header, start_html("Auswahl nach Stra�en und Orten"), h1("Auswahl nach Stra�en und Orten");
	    print h2("Mehrere Treffer");
	    _form;

	    {
		my $use_icons = 1;
		my $values = [map { $_->[$STRASSEN_CENTER] }
			      sort { lc $a->[Strassen::NAME()] cmp lc $b->[Strassen::NAME()]}
			      @res];
		my $labels = {map { my $n = $_->[Strassen::NAME()];
				    $n =~ s/\|/ /;
				    $n .= " (" . $_->[$STRASSEN_LABEL] . ")";
				    ($_->[$STRASSEN_CENTER] => $n)
				} @res};
		my $icons = {map {  my $n = "";
				    my @icons = @{ $_->[$STRASSEN_ICONS] };
				    if (@icons && $use_icons) {
					for my $icon (@icons) {
					    $n .= qq( <img src="$BBBIKE_URL/images/$icon">);
					}
				    }
				    ($_->[$STRASSEN_CENTER] => $n)
				} @res};

		my $name = "coords";
		if (!$use_icons) {
		    print radio_group
			(-name=>$name,
			 -values => $values,
			 -labels => $labels,
			 -linebreak => "true",
			), br;
		} else {
		    print start_table;
		    for my $value (@$values) {
			print qq(<tr><td><input type="radio" name="$name" value="$value"></td><td>$labels->{$value}</td><td>$icons->{$value}</td></tr>);
		    }
		    print end_table;
		}
	    }
	    print submit(-value => "Zeigen");
	    print end_form, hr;
	    show_form();
	    print end_html;
	}
    }
    if (@res == 1) {
	my $xy = $res[0]->[Strassen::COORDS()]->[0];
	redirect_to_map($xy);
    }
}

sub resolve_latlong {
    my($lat, $long) = @_;
    require Karte;
    $Karte::Polar::obj = $Karte::Polar::obj; # cease -w
    Karte::preload("Standard", "Polar");
    my($x, $y) = map { int } $Karte::Polar::obj->map2standard($long, $lat);
    redirect_to_map("$x,$y");
}

sub redirect_to_map {
    my($coord, %args) = @_;
    my $usemap = param("usemap") || "mapserver";
    if ($usemap eq 'googlemaps') {
	redirect_to_googlemaps($coord, %args);
    } else {
	redirect_to_ms($coord, %args);
    }
}

sub redirect_to_googlemaps {
    my($coord, %args) = @_;
    my $q2 = CGI->new({wpt_or_trk => "!$coord"});
    # XXX do not hardcode
    print redirect("http://bbbike.de/cgi-bin/bbbikegooglemap.cgi?" . $q2->query_string);
    return;
}

sub redirect_to_ms {
    my($coord, %args) = @_;
    if (!$args{-scope}) {
	if ($coord) {
	    $args{-scope} = scope(split /,/, $coord);
	} else {
	    $args{-scope} = "city";
	}
    }
    $args{-scope} = "all," . $args{-scope};

    if (param("mapext")) {
	my($x1,$y1,$x2,$y2) = split /\s+|,/, param("mapext");
	$args{-width} = $x2-$x1;
	$args{-height} = $y2-$y1;
    } elsif (param("width")) {
	$args{-width} = param("width");
	$args{-height} = (param("height") ? param("height") : $args{-width});
    } else {
	if ($args{-scope} eq 'city') {
	    @args{qw(-width -height)} = (2000, 2000);
	} elsif ($args{-scope} eq 'region') {
	    @args{qw(-width -height)} = (5000, 5000);
	} else {
	    @args{qw(-width -height)} = (8000, 8000);
	}
    }

    if (param("layer")) {
	$args{-layers} = [BBBikeCGI::Util::my_multi_param("layer")];
    } else {
	$args{-layers} = [qw(bahn flaechen gewaesser
			     faehren route grenzen orte)] if !$args{-layers};
    }
    require File::Basename;
    $args{-bbbikeurl} = File::Basename::dirname(url) . "/bbbike.cgi";
    if (param("msmap")) {
	$args{-mapname} = File::Basename::basename(scalar param("msmap"));
    }

    require BBBikeMapserver;
    my $ms = BBBikeMapserver->new;
    $ms->read_config("$FindBin::RealBin/bbbike.cgi.config");
    $ms->set_coords($coord) if $coord;
    $ms->{CGI} = CGI->new;
    $ms->start_mapserver(%args);
}

sub scope {
    my($x,$y) = @_;
    require BBBikeMapserver;
    BBBikeMapserver->narrowest_scope($x,$y);
}

sub file_to_label {
    my $file = shift;
    # XXX do not hardcode
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
	 faehren => 'F�hren',
	 flaechen => 'Fl�chen (Parks, W�lder, Flugh�fen ...)',
	 gesperrt => 'Gesperrte und Einbahnstra�en',
	 gesperrt_car => 'Gesperrte Stra�en f�r motorisierten Verkehr',
	 green => 'Gr�ne Wege',
	 handicap_l => 'Sonstige Behinderungen (Landstra�en)',
	 handicap_s => 'Sonstige Behinderungen (Stadtstra�en)',
	 hoehe => 'H�henpunkte',
	 housenumbers => 'Hausnummern',
	 innerberliner_grenze => 'Innerberliner Grenze',
	 kinos => 'Kinos',
	 kneipen => 'Kneipen',
	 label => 'Labels',	# XXX
	 landstrassen => 'Landstra�en',
	 landstrassen2 => 'Landstra�en (jwd)',
	 nolighting => 'Stadtstra�en ohne Beleuchtung',
	 orte => 'Orte',
	 orte2 => 'Orte (jwd)',
	 orte_city => 'Besondere Bezirke in Berlin',
	 plaetze => 'Pl�tze',
	 plz => 'Postleitzahlgebiete',
	 potsdam => 'Grenzen von Potsdam',
	 qualitaet_l => 'Stra�enqualit�t (Landstra�en)',
	 qualitaet_s => 'Stra�enqualit�t (Stadtstra�en)',
	 radwege => 'Radwege, Busspuren, verkehrsberuhigte Bereiche',
	 radwege_exact => 'Radwege (exakte Koordinaten)',
	 rbahn => 'Regionalbahnlinien',
	 rbahnhof => 'Regionalbahnh�fe',
	 relation_gps => 'Relationen zu GPS-Punkten',
	 sbahn => 'S-Bahnlinie',
	 sbahnhof => 'S-Bahnhof',
	 sbahnhof_bg => 'behindertenfreundliche Zug�nge an S-Bahnh�fen',
	 sehenswuerdigkeit => 'Sehensw�rdigkeiten, �ffentliche Geb�ude',
	 strassen => 'Stadtstra�en',
	 strassen_b_and_p => 'Stadtstra�en in Berlin und Potsdam',
	 ubahn => 'U-Bahnlinien',
	 ubahnhof => 'U-Bahnh�fe',
	 ubahnhof_bg => 'behindertenfreundliche Zug�nge an U-Bahnh�fen',
	 vorfahrt => 'abknickende Vorfahrtsstra�en',
	 wasserstrassen => 'Gew�sser in Berlin',
	 wasserumland => 'Gew�sser im Umland',
	 wasserumland2 => 'Gew�sser jwd',
	);
    exists $map{$file} ? $map{$file} : $file;
}

sub file_to_icon {
    my $file = shift;
    # XXX do not hardcode
    my %map =
	(
	 ampeln => 'ampel',
	 ampelschaltung => 'ampel',
	 berlin => 'berlin_overview_small',
	 faehren => 'ferry',
	 flaechen => 'flaechen',
	 gesperrt => 'legend_blocked',
	 gesperrt_car => 'legend_blocked',
	 kinos => 'kino_klein',
	 kneipen => 'glas',
	 landstrassen => 'landstrasse',
	 landstrassen2 => 'landstrasse',
	 orte => 'ort',
	 orte2 => 'ort',
	 qualitaet_l => 'kopfstein_klein',
	 qualitaet_s => 'kopfstein_klein',
	 rbahn => 'rbahn',
	 rbahnhof => 'rbahn',
	 sbahn => 'sbahn',
	 sbahnhof => 'sbahn',
	 sbahnhof_bg => 'behindertenfreundlich',
	 sehenswuerdigkeit => 'star',
	 strassen => 'strasse',
	 strassen_b_and_p => 'strasse',
	 ubahn => 'ubahn',
	 ubahnhof => 'ubahn',
	 ubahnhof_bg => 'behindertenfreundlich',
	 vorfahrt => 'vorfahrt',
	 wasserstrassen => 'wasser',
	 wasserumland => 'wasser',
	 wasserumland2 => 'wasser',
	);
    # XXX cache results?
    if (exists $map{$file}) {
	my $png = $map{$file} . ".png";
	return $png if -r "$BBBIKE_ROOT/images/$png";
	my $gif = $map{$file} . ".gif";
	return $gif if -r "$BBBIKE_ROOT/images/$gif";
    }
    return undef;
}

sub pathinfo_to_param {
    if (path_info() ne "") {
	for my $pathcomp (split '/', substr(path_info(), 1)) {
	    my($key,$val) = split /=/, $pathcomp, 2;
	    param($key, BBBikeCGI::Util::my_multi_param($key), $val); # couldn't get CGI::append in functional mode working
	}
    }
}

# No __END__ !

=comment

Calling example:

http://<path to mapserver_address.cgi>?coords=5775,11631;layer=bahn;layer=flaechen;layer=route;layer=gewaesser;layer=sehenswuerdigkeit;width=2000

=cut
