# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (de): Eine Routensuche bei Fahrinfo vornehmen
package FahrinfoQuery;

use strict;
use vars qw($VERSION @ISA);
$VERSION = '0.01';

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use vars qw($icon %city_border_points);

use CGI qw();
use Encode qw(encode);

use BBBikeUtil qw(bbbike_root m2km kmh2ms s2ms);
use Strassen::MultiStrassen;
use Strassen::Util;

# XXX use Msg.pm some day
sub M ($) { $_[0] } # XXX
sub Mfmt { sprintf M(shift), @_ } # XXX

use vars qw($LIMIT_LB);
$LIMIT_LB = 12;

use vars qw($PEDES_MS);
$PEDES_MS = kmh2ms(5);

sub register {
    my $pkg = __PACKAGE__;
    $BBBikePlugin::plugins{$pkg} = $pkg;
    _create_image();
    add_button();
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $subw = $mf->Subwidget($pkg . '_action');
    if (Tk::Exists($subw)) { $subw->destroy }
    delete $BBBikePlugin::plugins{$pkg};
}

sub _create_image {
    if (!defined $icon) {
	# Got from: http://www.bvg.de/images/favicon.ico
	# and scaled to 16x16 using ImageMagick/convert
	$icon = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAPcAAB8cByclCCkkByklByglCCklCS4rBy0pCSwoCi0qCC8sCTEtCDAtCjMu
DD05CTw5DEE+C0E/DEZADEhCDElCDUxFDUxHDU5GDEVCEEtIEFFLDlVSEFlWEVxWEV1YEWRf
D2BZE2FYE2JbEWBcE2JgEGdiE2ZgFWlhEm5mFG5pFXZuF3lvFYV7F4iAF4qEGY+HGZKKHJWK
GJeLGZeLGpmPG5WRHZyUGqCVHaOXHKKYG6OaH6idHqSaIKegHKmhH6yjHbClHrCnH7OpHraw
H6+oIbCkILSpILSrIbmwIsS5IsW9I8i6IMi8I8/DJM3GItDCJNDGJdTIJtXKJdbIKNfMKdjI
JNjMI9rPJd7PJ9jNKNrRJtvRKODTJ+TTJubWJebYKuTdKu/fLO/iKPPiK/HiLPLlK/XjLfTl
LPXkLPXmLPfnLfrpLPvrLv3rKfzrK/3qK/3rKv3rK/7qKv7qK/7rKv7rK//qK//rKv/rK/zq
LPzrLf3qLP3rLP3rLv7qLP7qLf7rLP7rLf/qLP/rLP7qLv7rLv3sKf3sK/7tKf7sKv7tK//u
Kv/uK//vKv7sLP7tLP7tLf/sLP7tLv7uLP/uLf/vLP/vLf/uLv/uL//vLv/wLf/wLszMzAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAJwALAAAAAAQABAAAAj4AAcJHEiwoMGD
BO3gsaNwEJ6HDhc29ONHkMU5gyzasUhxkJ04cerU+QMIkJ85gP78ARlSjhw/K/nwiQOnDh+T
cgC9kUOH0aJEgSTB4QOJjyNGiNoQojOmyhQyZrrkQeNFT5gnWNYAurTDgIMSRS58EfIhSwgG
FJpQqgQjgg8EPA4kYSHCBQQnUsQUyiQjAQkNWizUMNHiBAomOrhE0jSjgAcJW1SAqEBkxIof
AXBoyhRjghIBQ3oMWEAlRQcwGGxUakSDwIYHVqIAyFDGiAIODY5gUnQlxw0obNIAWaJIDZIX
Qc7c2XOo0qZHbgxVgvQGziRLlQz1CQgAOw==
EOF
    }
}

sub add_button {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    return unless defined $mf;

    my $button = $mf->Button(main::image_or_text($icon, 'Fahrinfo'),
			     -command => sub { choose() },
			    );
    BBBikePlugin::replace_plugin_widget($mf, $button,
					__PACKAGE__ . '_action');
#     BBBikePlugin::add_to_global_plugins_menu
# 	    (-title   => M("Kürzeste Rundreise"),
# 	     -topmenu => [Radiobutton => M('Kürzester Rundreisen-Modus'),
# 			  %radio_args,
# 			 ],
# 	    );
    $main::balloon->attach($button, -msg => M"Fahrinfo")
	if $main::balloon;
}

sub choose {
    if (@main::search_route_points < 2) {
	main::status_message(M"Es existiert keine Route", "error");
	return;
    }
    my $start = $main::search_route_points[0]->[main::SRP_COORD()];
    # XXX no support for via
    my $goal  = $main::search_route_points[-1]->[main::SRP_COORD()];

    my $osm_data_dir;
 TRY_OSM_DATA_DIR: {
	my @try_dirs = ('data_berlin_brandenburg_osm_bbbike',
			'data_berlin_osm_bbbike',
		       );
	for my $try_dir (map { bbbike_root . '/' . $_ } @try_dirs) {
	    if (-d $try_dir) {
		$osm_data_dir = $try_dir;
		last TRY_OSM_DATA_DIR;
	    }
	}
	main::status_message(M"Es konnte keines der folgenden Verzeichnisse im BBBike-Wurzelverzeichnis gefunden werden: " . join(" ", @try_dirs) . ". Keine Haltestellensuche möglich.", "error");
	return;
    }

    my $ms = MultiStrassen->new("$osm_data_dir/_oepnv",
				"$osm_data_dir/ubahnhof",
				"$osm_data_dir/sbahnhof",
			       );

    my $t = $main::top->Toplevel(-title => 'Fahrinfo');
    $t->transient($main::top) if $main::transient;
    my $f = $t->Frame->pack(qw(-fill both -expand 1));
    my $start_lb = $f->Scrolled('Listbox',
				-scrollbars => 'osoe',
				-exportselection => 0,
				-width => 50,
				-height => $LIMIT_LB,
			       )->pack(qw(-side left -fill both -expand 1));
    my $goal_lb  = $f->Scrolled('Listbox',
				-scrollbars => 'osoe',
				-exportselection => 0,
				-width => 50,
				-height => $LIMIT_LB,
			       )->pack(qw(-side left -fill both -expand 1));
    my $expected_foottime;
    my $b;
    {
	my $f = $t->Frame->pack(qw(-fill x -expand 1));
	$b = $f->Button(-text => 'Search',
		       )->pack(qw(-fill x -expand 1 -side left));
	$f->Label(-textvariable => \$expected_foottime)->pack(qw(-side left));
    }

    my(@start_stops, @goal_stops);
    for my $def ([\@start_stops, $start, $start_lb],
		 [\@goal_stops,  $goal,  $goal_lb],
		) {
	my($stops, $coord, $lb) = @$def;
	#@$stops = @{ $ms->nearest_point($coord, FullReturn => 1, AllReturn => 1) };
	@$stops = get_nearest($ms, $coord);
	if (!@$stops) {
	    $lb->insert("end", "Nothing found!");
	} else {
	    for my $stop (@$stops) {
		my $r = $stop->{StreetObj};

		my $cat = $r->[Strassen::CAT()];
		$cat =~ s{^([US])[ABC]}{$1}; # remove VBB zone

		my $name;
		if ($cat =~ m{^[US]$}) {
		    $name .= "$cat ";
		}
		$name .= $r->[Strassen::NAME()];
		$name =~ s{([sS])traße}{$1tr.}; # short form preferred by Fahrinfo
		if (inside_berlin($r->[Strassen::COORDS()]->[0])) {
		    $name .= " (Berlin)";
		} elsif (inside_potsdam($r->[Strassen::COORDS()]->[0])) {
		    $name .= " (Potsdam)";
		}
		$name .= " [";
		if ($cat !~ m{^[US]$}) {
		    $name .= "$cat; ";
		}
		$name .= m2km($stop->{Dist}, 1);
		my $time = $stop->{Dist} / $PEDES_MS;
		$stop->{Time} = $time;
		$name .= ", ";
		$name .= s2ms($time) . " min";
		$name .= "]";
		$lb->insert('end', $name); # XXX show maybe on map, somehow?
	    }
	    $lb->selectionSet(0);
	}
    }

    my $adjust_expected_foottime = sub {
	my $total_time = 0;
	for my $def ([$start_lb, \@start_stops],
		     [$goal_lb,  \@goal_stops],
		    ) {
	    my($lb, $stops) = @$def;
	    my($cursel) = $lb->curselection;
	    $total_time += $stops->[$cursel]->{Time};
	}
	$expected_foottime = 'Expected foot time: ' . s2ms($total_time) . ' min';
    };
    $t->afterIdle($adjust_expected_foottime);

    for my $def ([$start_lb, \@start_stops],
		 [$goal_lb,  \@goal_stops],
		) {
	my($lb, $stops) = @$def;
	$lb->bind('<Double-1>' => sub {
		      my($cursel) = $lb->curselection;
		      my $coord = $stops->[$cursel]->{StreetObj}->[Strassen::COORDS()]->[0];
		      main::mark_point(-coords => [[[ main::transpose(split /,/, $coord) ]]],
				       -clever_center => 1,
				      );
		  });
	$lb->bind('<<ListboxSelect>>' => $adjust_expected_foottime);
    }

    $b->configure(-command => sub {
		      my($start_name) = $start_lb->get($start_lb->curselection);
		      my($goal_name)  = $goal_lb->get($goal_lb->curselection);
		      $_ =~ s{\s+\[.*\]$}{} for ($start_name, $goal_name);
		      search($start_name, $goal_name);
		  });
}

sub search {
    my($start_name, $goal_name) = @_;
    CGI->import('-oldstyle_urls');
    $_ = encode("iso-8859-1", $_) for ($start_name, $goal_name); # XXX utf8 or latin1?
    my $qs = CGI->new({from => $start_name, # XXX add " (Berlin)"? # XXX add !
		       to   => $goal_name,  # XXX "
		       REQ0JourneyStopsSA1 => 1,
		       REQ0JourneyStopsZA1 => 1
		      })->query_string;
    start_browser("http://mobil.bvg.de/Fahrinfo/bin/query.bin/dox?" . $qs);
}

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    require WWWBrowser;
    WWWBrowser::start_browser($url);
}

# Partially taken from Strassen::Core::nearest_point, but with
# AllReturn really working
sub get_nearest {
    my($s, $xy) = @_;
    my($x,$y) = split /,/, $xy;
    $s->make_grid(UseCache => 1, Exact => 1) unless $s->{Grid};
    my @res;
    {
	my %seen;
	my($grx,$gry) = $s->grid($x,$y);
	for my $xx ($grx-1 .. $grx+1) {
	    for my $yy ($gry-1 .. $gry+1) {
		# prevent autovivify (bad for CDB_File)
		next unless (exists $s->{Grid}{"$xx,$yy"});
		foreach my $n (@{ $s->{Grid}{"$xx,$yy"} }) {
		    next if $seen{$n};
		    $seen{$n}++;
		    my $r = $s->get($n);
		    next if $r->[Strassen::NAME] =~ m{^\s*$}; # no name -> no use!
		    my($px,$py) = split /,/, $r->[Strassen::COORDS]->[0];
		    my $this_mindist = Strassen::Util::strecke([$px,$py], [$x,$y]);
		    my $line = {StreetObj  => $r,
				Dist       => $this_mindist,
			       };
		    push @res, $line;
		}
	    }
	}
    }
    @res = sort { $a->{Dist} <=> $b->{Dist} } @res;
    {
	my %seen;
	@res = grep { !$seen{$_->{StreetObj}->[Strassen::NAME()]}++ } @res;
    }
    @res = @res[0..$LIMIT_LB-1] if @res >= $LIMIT_LB;
    @res;
}

sub _inside_any {
    my($c, $city) = @_;
    require VectorUtil;
    if (!$city_border_points{$city}) {
	my $s = Strassen->new($city);
	$s->init;
	$city_border_points{$city} = [ map { [split /,/] } @{ $s->next->[Strassen::COORDS()] } ];
    }
    return 1 if VectorUtil::point_in_polygon([split /,/, $c], $city_border_points{$city});
}

sub inside_berlin  { _inside_any($_[0], 'berlin') }
sub inside_potsdam { _inside_any($_[0], 'potsdam') }

1;

__END__
