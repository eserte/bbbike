# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2023,2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (de): Eine OePNV-Routensuche mit Fahrinfo vornehmen
# Description (en): Do a public transport route search using Fahrinfo
package FahrinfoQuery;

use strict;
use vars qw($VERSION @ISA);
$VERSION = '2024.06';

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use constant PLUGIN_DISABLED => 0;

use vars qw($icon %city_border_points $menu);

use File::Basename qw(basename);

use BBBikeUtil qw(bbbike_root m2km kmh2ms s2ms uri_with_query);
use Strassen::Core;
use Strassen::MultiStrassen;
use Strassen::Util;
use Strassen::StrassenNetz;

sub _provide_vbb_stops ();
sub _prereq_check_vbb_stops ();
sub _download_vbb_stops ();
sub _extract_vbb_stops ();
sub _convert_vbb_stops ();

# XXX use Msg.pm some day
sub M ($) { $_[0] } # XXX
sub Mfmt { sprintf M(shift), @_ } # XXX

use vars qw($LIMIT_LB %MIN_STATIONS);
$LIMIT_LB = 15;
%MIN_STATIONS = ('u' => 2, 's' => 2); # sum here should be smaller than $LIMIT_LB

use vars qw($PEDES_MS);
$PEDES_MS = kmh2ms(5);

use vars qw($data_source);
$data_source = "vbb";

use vars qw($use_search);
$use_search = 1 if !defined $use_search;

my $bbbike_root = bbbike_root;

######################################################################
# configurable
my $openvbb_download_size = '67MB';
my $openvbb_year = 2024;
my $openvbb_index = 1;
my $openvbb_data_url = 'https://www.vbb.de/vbbgtfs';
######################################################################

my $openvbb_archive_file = "$bbbike_root/tmp/vbb_${openvbb_year}_${openvbb_index}.zip";
my $openvbb_local_file = "$bbbike_root/tmp/vbb_${openvbb_year}_${openvbb_index}_stops.txt";
my $openvbb_bbd_file = "$bbbike_root/tmp/vbb_${openvbb_year}_${openvbb_index}.bbd";

my $search_net;

sub register {
    # XXX (noch) keine Pr�fung auf city==Berlin, da die Daten auch mit
    # anderen Orten im VBB-Bereich funktionieren k�nnten, z.B.
    # Frankfurt/Oder

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
    undef $search_net;
}

sub _create_image {
    if (!defined $icon) {
	# Generated with:
	#     curl -s https://www.vbb.de/typo3conf/ext/epx_vbb/Resources/Public/Icons/Favicon/favicon-16x16.png | base64
	$icon = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAALGPC/xhBQAAAAFzUkdC
AK7OHOkAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAadQTFRF
AAAA4Qoc4Aoc4Qsd4wwf3QYc4Asc4gsd4Asd4Aod3wob4goe4Qod4gse5Qwf4g0e5A8h4hAh2QYX
4Q4e4g8h4Qod4Qsc4Qoc4Aoc4Aoc4Qsd4Aoc4Aoc4Aoc4Qoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc
4Aoc4Aoc4Qoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Qoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc
4Aoc4Aoc4Aoc4Aoc4Asd4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc
4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Asd4Qsd4Aoc4Aoc4Aoc4Aoc
4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Qwe4Qse4Qsd
4Asd4Aoc4Qsd4Qsd4Aod4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc4Aoc
4Aoc4Aod4Qsc4Aoc4Aoc4Aoc4Asc////P7UhhQAAAIx0Uk5TAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AgcEIRcDHY6EFr3VlzsHLjHTnBN78e13CUjfTwwIPbr4eRZsKBm3PgITBg8bEjJkMA2mRo+1u2qW
nwsIsIylbrxnyo0EAqHcUYm2xHPHuH5yEaqAWZo3L2UrAwEICwMECwbrHCdvGHX3Px5MS3Ts8r8U
AzmVgQK0UqUcAAAAAWJLR0SMbAvSQwAAAAlwSFlzAAAASAAAAEgARslrPgAAAPNJREFUGNNjYAAC
RlExcQlJKSYGKGCSlpGVk1dQVJJiBHOVVVTV1DU05bW0dXSBipiZ9PQNpA1ZWI2MTUzNpNiAAuYW
lkzsDAzsTFbW2jZAJRy2dvYOdlaO9k6Ozi6uQAEmN3cPTzMvbx9faz9/TpChAYFBwSEKoWHh8hGR
IAHmqOiY2Lj4hMSk5BQubqAAD1eqYppsekZmYFY2Ey9QR05uXn5BYVFxSWkZFx/ICKVy7womfgYG
AabKqmomQQaeqJpa+TpdIWHD+gb9RiYRkC1NzS2tKW1ZCs4qAWD/sbV3dKq1SnZ51sO9yylqLiEu
1g3mAwAsZS7KyiMWcgAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAyMS0wMi0xNVQxNzozMzoyNiswMDow
MCGjGv0AAAAldEVYdGRhdGU6bW9kaWZ5ADIwMjEtMDItMTVUMTc6MzM6MjYrMDA6MDBQ/qJBAAAA
RnRFWHRzb2Z0d2FyZQBJbWFnZU1hZ2ljayA2LjcuOC05IDIwMTQtMDUtMTIgUTE2IGh0dHA6Ly93
d3cuaW1hZ2VtYWdpY2sub3Jn3IbtAAAAABh0RVh0VGh1bWI6OkRvY3VtZW50OjpQYWdlcwAxp/+7
LwAAABh0RVh0VGh1bWI6OkltYWdlOjpoZWlnaHQAMTkyDwByhQAAABd0RVh0VGh1bWI6OkltYWdl
OjpXaWR0aAAxOTLTrCEIAAAAGXRFWHRUaHVtYjo6TWltZXR5cGUAaW1hZ2UvcG5nP7JWTgAAABd0
RVh0VGh1bWI6Ok1UaW1lADE2MTM0MTA0MDa31gMvAAAAD3RFWHRUaHVtYjo6U2l6ZQAwQkKUoj7s
AAAAVnRFWHRUaHVtYjo6VVJJAGZpbGU6Ly8vbW50bG9nL2Zhdmljb25zLzIwMjEtMDItMTUvNDFi
ZGNkM2MzN2Y1ZjI1ZTQ4ZjEzYmQ0NmI0MGY1NDAuaWNvLnBuZ+LPUhwAAAAASUVORK5CYII=
EOF
    }
}

sub add_button {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $mmf = $main::top->Subwidget("ModeMenuPluginFrame");
    return unless defined $mf;

    my $button = $mf->Button(main::image_or_text($icon, 'Fahrinfo'),
			     -command => sub { choose() },
			    );
    BBBikePlugin::replace_plugin_widget($mf, $button,
					__PACKAGE__ . '_action');
#     BBBikePlugin::add_to_global_plugins_menu
# 	    (-title   => M("K�rzeste Rundreise"),
# 	     -topmenu => [Radiobutton => M('K�rzester Rundreisen-Modus'),
# 			  %radio_args,
# 			 ],
# 	    );
    $main::balloon->attach($button, -msg => M"Fahrinfo")
	if $main::balloon;

    BBBikePlugin::place_menu_button
	    ($mmf,
	     [
	      [Button => 'Datenquelle',
	       -state => 'disabled',
	       -font => $main::font{'bold'},
	      ],
	      [Radiobutton => "VBB-Daten von $openvbb_year verwenden",
	       -variable => \$data_source,
	       -value => "vbb",
	      ],
	      [Radiobutton => "OSM-Daten verwenden",
	       -variable => \$data_source,
	       -value => "osm",
	      ],
	      "-",
	      [Checkbutton => "Exaktes Routing des Fu�wegs",
	       -variable => \$use_search,
	       -onvalue => 1,
	       -offvalue => 0,
	      ],
	      [Button => 'Info',
	       -command => sub { fahrinfoquery_info() },
	      ],
	      "-",
	      [Button => "Dieses Men� l�schen",
	       -command => sub {
		   $mmf->afterIdle(sub {
				       unregister();
				   });
	       }],
	     ],
	     $button,
	     __PACKAGE__."_menu",
	     -title => M"FahrinfoQuery",
	    );

    $menu = $mmf->Subwidget(__PACKAGE__."_menu")->menu;
}

sub choose {
    if (PLUGIN_DISABLED) {
	main::status_message("Das Fahrinfo-Plugin funktioniert nicht mehr.", "error");
	return;
    }
    if (@main::search_route_points < 2) {
	main::status_message(M"Es existiert keine Route", "error");
	return;
    }
    my $start = $main::search_route_points[0]->[main::SRP_COORD()];
    # XXX no support for via
    my $goal  = $main::search_route_points[-1]->[main::SRP_COORD()];

    my $ms = get_data_object();
    return if !$ms;

    my $t = $main::top->Toplevel(-title => 'Fahrinfo');
    $t->transient($main::top) if $main::transient;
    my($start_lb, $goal_lb);
    {
	my $col = 0;
	my $f = $t->Frame->pack(qw(-fill both -expand 1));
	$f->Label(-text => M("Start"))->grid(-column => $col, -row => 0, -sticky => 'ew');
	$start_lb = $f->Scrolled('Listbox',
				 -scrollbars => 'osoe',
				 -exportselection => 0,
				 -width => 50,
				 -height => $LIMIT_LB,
				)->grid(-column => $col, -row => 1, -sticky => 'news');
	$col++;
	$f->Label(-text => M("Ziel"))->grid(-column => $col, -row => 0, -sticky => 'ew');
	$goal_lb  = $f->Scrolled('Listbox',
				 -scrollbars => 'osoe',
				 -exportselection => 0,
				 -width => 50,
				 -height => $LIMIT_LB,
				)->grid(-column => $col, -row => 1, -sticky => 'news');
    }
    my $expected_foottime;
    my $b;
    {
	my $f = $t->Frame->pack(qw(-fill x -expand 1));
	$b = $f->Button(
			-text => 'Search',
			-font => $main::font{'bold'},
		       )->pack(qw(-fill both -expand 1 -side left));
	$f->Label(-textvariable => \$expected_foottime, -justify => 'left')->pack(qw(-side left));
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
		$name =~ s{([sS])tra�e}{$1tr.}; # short form preferred by Fahrinfo
		if (inside_berlin($r->[Strassen::COORDS()]->[0])) {
		    $name .= " (Berlin)";
		} elsif (inside_potsdam($r->[Strassen::COORDS()]->[0])) {
		    $name .= " (Potsdam)";
		}
		$name .= " [";
		if ($cat !~ m{^[US]$} && $cat ne 'X') {
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
	$expected_foottime .= "\nVBB pays off if not slower than:";
	for my $def (
		     ['',      do { no warnings 'once'; \@main::speed_txt }],
		     ['Power', do { no warnings 'once'; \@main::power_txt }],
		    ) {
	    my($type, $txtref) = @$def;
	    my $key = $type . 'TimeSeconds';
	    for my $index (0 .. $#{ $main::act_value{$key} }) {
		$expected_foottime .= "\n\@ $txtref->[$index]: ";
		my $time_to_beat = $main::act_value{$key}->[$index] - $total_time;
		if ($time_to_beat < 0) {
		    $expected_foottime .= 'never (foot time exceeds cycle time)';
		} else {
		    $expected_foottime .= s2ms($time_to_beat) . ' min';
		}
	    }
	}
    };
    $t->afterIdle($adjust_expected_foottime);

    for my $def ([$start_lb, \@start_stops],
		 [$goal_lb,  \@goal_stops],
		) {
	my($lb, $stops) = @$def;
	$lb->bind('<Double-1>' => sub {
		      my($cursel) = $lb->curselection;
		      my $conv = $ms->get_conversion(-tomap => $main::coord_system);
		      my $info = $stops->[$cursel];
		      if ($info->{Path}) {
			  my $path = [[ map { [main::transpose(@$_)] } @{ $info->{Path} } ]];
			  main::mark_street(-coords => $path, -clever_center => 1);
		      } else {
			  my $coord = $info->{StreetObj}->[Strassen::COORDS()]->[0];
			  $coord = $conv->($coord) if $conv;
			  main::mark_point(-coords => [[[ main::transpose(split /,/, $coord) ]]],
					   -clever_center => 1,
					  );
		      }
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
    my $url = uri_with_query
	(
	 "https://www.vbb.de/fahrinfo",
	 [
	  start    => 'yes',
	  S        => $start_name,
	  Z        => $goal_name,
	  language => $Msg::lang eq 'de' ? 'de_DE' : 'en_GB',
	 ],
	 encoding => 'utf-8',
	);
    start_browser($url);
}

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    require WWWBrowser;
    WWWBrowser::start_browser($url);
}

sub fahrinfoquery_info {
    main::status_message(<<EOF, 'infodlg');
Die VBB-Haltestellendaten werden vom
VBB Verkehrsverbund Berlin-Brandenburg GmbH
bereitgestellt und werden von www.vbb.de heruntergeladen.

Siehe auch: http://daten.berlin.de/kategorie/verkehr
EOF
}

# Partially taken from Strassen::Core::nearest_point, but with
# AllReturn really working
sub get_nearest {
    my($s, $xy) = @_;
    my($x,$y) = split /,/, $xy;
    $s->make_grid(UseCache => 1, Exact => 1, -tomap => $main::coord_system) unless $s->{Grid};
    my $conv = $s->get_conversion(-tomap => $main::coord_system);

    # for the search
    my($search_net, $search_net_strassen, $nxy);
    if ($use_search) {
	$search_net = _get_search_net();
	($search_net_strassen) = $search_net->sourceobjects;
	($nxy) = $search_net_strassen->nearest_point("$x,$y");
    }

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
		    my $p0 = $r->[Strassen::COORDS]->[0];
		    $p0 = $conv->($p0) if $conv;
		    my($px,$py) = split /,/, $p0;
		    my $as_the_bird_flies_dist = Strassen::Util::strecke([$x,$y], [$px,$py]);
		    my $npxy = $search_net_strassen ? $search_net_strassen->nearest_point("$px,$py") : undef;
		    my $search_res = $nxy && $npxy && $search_net ? $search_net->search($nxy, $npxy, AsObj => 1) : undef;
		    if ($search_res) {
			# add the difference from the nearest net
			# point and the actual station point
			if ($npxy ne "$px,$py") {
			    $search_res->add($px,$py);
			}
			if ($nxy ne "$x,$y") {
			    $search_res->prepend($x,$y);
			}
		    }
		    my $line = {StreetObj => $r,
				Dist      => $search_res ? $search_res->len : $as_the_bird_flies_dist,
				Path      => $search_res ? $search_res->path : undef,
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
    if (@res >= $LIMIT_LB) {
	# We need to limit the count. But also make sure that the
	# %MIN_STATIONS constraint is satisfied.

	# Return "u", "s", or undef
	my $get_station_type = sub {
	    my($line) = @_;
	    my $name = $line->{StreetObj}->[Strassen::NAME];
	    if ($name =~ m{^([US])(?:\s|-)}i) {
		lc $1;
	    } else {
		undef;
	    }
	};

	my %count_stations;
	for my $line_i (0 .. $LIMIT_LB-1) {
	    my $line = $res[$line_i];
	    my $station_type = $get_station_type->($line);
	    if (defined $station_type) {
		$count_stations{$station_type}++;
	    }
	}
	my %need_stations; # $station_type -> $need_count
	for my $station_type (keys %MIN_STATIONS) {
	    my $count_stations = $count_stations{$station_type} || 0;
	    my $need_stations;
	    if ($count_stations < $MIN_STATIONS{$station_type}) {
		$need_stations{$station_type} = $MIN_STATIONS{$station_type} - $count_stations;
	    }
	}

	my @add_stations;
	for my $line_i ($LIMIT_LB .. $#res) {
	    my $line = $res[$line_i];
	    my $station_type = $get_station_type->($line);
	    no warnings 'uninitialized'; # $need_stations{$station_type} may yet be empty
	    if (defined $station_type && $need_stations{$station_type} > 0) {
		push @add_stations, $line;
		$need_stations{$station_type}--;
	    }
	}

	# limit
	splice @res, $LIMIT_LB;

	if (@add_stations) {
	    # remove non-stations from the end
	    my $remove_count = scalar @add_stations;
	    for(my $line_i=$#res; $line_i>=0; $line_i--) {
		my $line = $res[$line_i];
		if (!defined $get_station_type->($line)) {
		    splice @res, $line_i, 1;
		    $remove_count--;
		    last if ($remove_count <= 0);
		}
	    }
	}

	# Replace tail
	push @res, @add_stations;
    }

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

sub get_data_object {
    my $obj;

    if      ($data_source eq 'osm') {
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
	    main::status_message(M"Es konnte keines der folgenden Verzeichnisse im BBBike-Wurzelverzeichnis gefunden werden: " . join(" ", @try_dirs) . ". Keine Haltestellensuche m�glich mit der Datenquelle 'osm'.", "die");
	}

	$obj = MultiStrassen->new("$osm_data_dir/_oepnv",
				  "$osm_data_dir/ubahnhof",
				  "$osm_data_dir/sbahnhof",
				 );
    } elsif ($data_source eq 'vbb') {
	if (!_provide_vbb_stops) {
	    return;
	}
	$obj = Strassen->new($openvbb_bbd_file);
    } else {
	main::status_message("Unhandled data source '$data_source'", 'die');
    }

    $obj;
}

######################################################################

sub _provide_vbb_stops () {
    if (-s $openvbb_bbd_file) {
	return 1;
    }

    if (!eval { _prereq_check_vbb_stops }) {
	main::status_message("Prerequisites missing. Error message is: $@. Maybe you should install these perl modules?", "error");
	return;
    }

    # Large download, so check and ask.
    if (!-s $openvbb_archive_file) {
	if ($main::top->messageBox(
				   -icon => "question",
				   -message => "Download $openvbb_data_url (about $openvbb_download_size)?", # XXX Msg!
				   -type => "YesNo"
				  ) !~ /yes/i) {
	    main::status_message("Not possible to use FahrinfoQuery with this data source", "error"); # XXX Msg!
	    return;
	}

	if (!eval { _download_vbb_stops }) {
	    main::status_message("Downloading failed. Error message is: $@", "error");
	    return;
	}
    }

    if (!eval { _extract_vbb_stops }) {
	main::status_message("Extraction failed. Error message is: $@", "error");
	return;
    }

    if (!eval { _convert_vbb_stops }) {
	main::status_message("Conversion failed. Error message is: $@", "error");
	return;
    }

    1;
}

sub _prereq_check_vbb_stops () {
    require LWP::UserAgent; # for download
    require Text::CSV_XS; # for conversion, see vbb-stops-to-bbd.pl
    require Archive::Zip; # extract stops.txt
    1;
}

sub _download_vbb_stops () {
    require LWP::UserAgent;
    require BBBikeHeavy;
    my $ua = BBBikeHeavy::get_uncached_user_agent();
    die "Can't get default user agent" if !$ua;
    my $resp = $ua->get($openvbb_data_url, ':content_file' => "$openvbb_archive_file~");
    if (!$resp->is_success || !-s "$openvbb_archive_file~") {
	die "Failed to download $openvbb_data_url: " . $resp->status_line;
    }
    rename "$openvbb_archive_file~", $openvbb_archive_file
	or die "Failed to rename $openvbb_archive_file~ to $openvbb_archive_file: $!";
    1;
}

sub _extract_vbb_stops () {
    require Archive::Zip;
    if (!-e $openvbb_archive_file) {
	die "The file $openvbb_archive_file does not exist";
    }
    my $zip = Archive::Zip->new($openvbb_archive_file)
	or die "Can't read zip file $openvbb_archive_file";
    $zip->extractMember('stops.txt', $openvbb_local_file) == Archive::Zip::AZ_OK()
	or die "Failure while extracting 'stops.txt' from '$openvbb_archive_file'";
}

sub _convert_vbb_stops () {
    my $script = bbbike_root . '/miscsrc/vbb-stops-to-bbd.pl';
    system("$^X $script $openvbb_local_file > $openvbb_bbd_file~");
    if ($? || !-s "$openvbb_bbd_file~") {
	die "Failure to convert $openvbb_local_file to $openvbb_bbd_file~";
    }
    rename "$openvbb_bbd_file~", $openvbb_bbd_file
	or die "Failed to rename $openvbb_bbd_file~ to $openvbb_bbd_file: $!";
    1;
}

# May be called from cmdline:
#
#    (cd $HOME/src/bbbike && perl -Ilib -Iplugins -MFahrinfoQuery -e 'FahrinfoQuery::_check_download_url()')
#
sub _check_download_url () {
    require BBBikeHeavy;
    my $ua = BBBikeHeavy::get_uncached_user_agent();
    my $resp = $ua->head($openvbb_data_url);
    if (!$resp->is_success) {
	die "HEAD on $openvbb_data_url failed: " . $resp->dump;
    } else {
	my $content_length = $resp->content_length;
	if (!$content_length) {
	    warn "WARNING: Did not get Content-Length, cannot check length...\n";
	} else {
	    my($openvbb_download_size_in_megabytes) = $openvbb_download_size =~ m{(\d+)MB};
	    if (!$openvbb_download_size_in_megabytes) {
		die "Cannot parse download size '$openvbb_download_size'";
	    }
	    my $content_length_in_megabytes = $content_length / (1024**2);
	    my $diff = abs($content_length_in_megabytes - $openvbb_download_size_in_megabytes);
	    if ($diff > 1) {
		die "Expected Content-Length does not match real ($content_length_in_megabytes vs. $openvbb_download_size_in_megabytes).\nFetched URL: $openvbb_data_url\nComplete response headers:\n" . $resp->dump;
	    }
	    print STDERR "All checks OK.\n";
	}
    }
}

######################################################################

sub _get_search_net {
    if (!$search_net) {
	my $s = MultiStrassen->new('strassen', 'landstrassen', 'landstrassen2'); # all ov VBB
	$search_net = StrassenNetz->new($s);
	# XXX what about gesperrt? do I know about gesperrt for cyclists vs. pedes?
	$search_net->make_net(UseCache => 1);
    }
    $search_net;
}

1;

__END__
