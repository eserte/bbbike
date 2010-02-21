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

# TODO:
# * all dies in gui mode -> status_message(die)
# * maybe as emacs function: combine times for same point (red/green) and if there are three times, the Zyklus may be calculated

package TrafficLightCircuitGPSTracking;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use constant TAGNAME     => 'tlcgpst';
use constant TAGNAME_WPT => TAGNAME . '-wpt';

our $CURRENT_FILENAME;
our @CURRENT_DATA;

use File::Basename qw(basename);
use Text::Tabs qw(expand);
use Tie::File;

sub gpsman2ampelschaltung_string {
    my($gps, $info) = @_;
    my $res;
    $res .= "#WPTFILE: " . $gps->File . "\n";

    $res .= <<EOF;
# Punkt       Kreuzung                           Dir    Zyk grün      rot
# ----------------------------------------------------------------------------
EOF

    my @sorted_waypoints = map { $_->[1] }
	sort { $a->[0] <=> $b->[0] }
	    map {
		my $wpt = $_;
		my $epoch = $wpt->Comment_to_unixtime($gps);
		[$epoch, $wpt];
	    } @{ $gps->Waypoints };

    my $date = $sorted_waypoints[0]->Comment_to_unixtime($gps);
    my(undef,undef,undef,$day,$month,$year,$wkday) = localtime $date;
    $month++;
    $year+=1900;
    my $wkday_german = wkday_to_german($wkday);
    my $formatted_date = sprintf "%s, %02d.%02d.%04d", $wkday_german, $day, $month, $year;
    $info->{formatted_date} = $formatted_date if $info;
    $res .= $formatted_date . "\n";

    for my $wpt (@sorted_waypoints) {
	$res .= "#WPT: " . join("\t", $wpt->Ident, $wpt->Comment, $wpt->Latitude, $wpt->Longitude, $wpt->Symbol) . "\n";
    }
    $res;
}

# Returns filehandle with file offset set to line after date, or undef
# Dies if ampelschaltung-orig.txt cannot be found.
sub find_date_in_ampelschaltung {
    my $date = shift;
    my $file = ampelschaltung_filename();
    open my $fh, $file
	or die "Can't open $file: $!";
    while(<$fh>) {
	chomp;
	if ($_ eq $date) {
	    return $fh;
	}
    }
    undef;
}

sub inject {
    my($res) = @_;
    my $file = ampelschaltung_filename();
    tie my @lines, 'Tie::File', $file
	or die "Can't tie $file: $!";
    for(my $line_i = $#lines; $line_i >= 0; $line_i--) {
	if ($lines[$line_i] =~ m{^# Anmerkungen:$}) {
	    splice @lines, $line_i, 0, $res, "\n";
	    return 1;
	}
    }
    die "Can't find 'Anmerkungen' marker in " . $file;
}

sub find_mappings_in_ampelschaltung {
    my $file = ampelschaltung_filename();
    open my $fh, $file or die $!;
    my @res;
    while(<$fh>) {
	chomp;
	if (/^#WPTFILE:\s+(.*)/) {
	    push @res, $1;
	}
    }
    @res;
}

sub tk_gui {
    my $mw = shift;
    my $t = $mw->Toplevel(-title => 'Mappings');
    my $lb = $t->Scrolled('Listbox', -scrollbars => 'osoe')->pack(qw(-expand 1 -fill both));
    my @mappings = find_mappings_in_ampelschaltung();
    $lb->insert('end', @mappings);
    $lb->bind('<Double-1>' => sub {
		  my(@cursel) = $lb->curselection;
		  my $filename = $lb->get($cursel[0]);
		  tk_show_mapping($t, $filename);
	      });
    $t->Button(-text => 'Delete on canvas',
	       -command => sub {
		   $main::c->delete(TAGNAME);
	       })->pack;
}

sub tk_show_mapping {
    my($t, $filename) = @_;

    require BBBikeCalc;
    BBBikeCalc::init_wind();
    require Karte::Polar;
    require Karte::Standard;
    require VectorUtil;

    $CURRENT_FILENAME = $filename;

    my $ampelschaltung_file = ampelschaltung_filename();
    open my $fh, $ampelschaltung_file or die $!;
    my @res;
    my $state = 'find_start';
    while(<$fh>) {
	chomp;
	if ($state eq 'find_start') {
	    if (m{^#WPTFILE:\s+\Q$filename}) {
		$state = 'find_wpt';
	    }
	} elsif ($state eq 'find_wpt') {
	    if (m{^(# Anmerkungen:$|#WPTFILE:\s+)}) {
		last;
	    } elsif (my($ident, $date, $time, $lat, $lon, $symbol) = $_ =~ m{^#WPT:\s+([^\t]+)\t(\S+)\s+(\S+)\t(\S+)\t(\S+)\t(\S+)}) {
		my($x,$y) = $Karte::Polar::obj->map2standard($lon, $lat);
		my($tx,$ty) = main::transpose($x,$y);
		my $color = $symbol =~ m{green} ? 'green' : $symbol =~ m{red} ? 'red' : 'brown';
		if (length $time < 8) {
		    $time = '0' . $time; # leading zero is missing
		}
		push @res, { ident   => $ident,
			     date    => $date,
			     time    => $time,
			     wpt_lat => $lat,
			     wpt_lon => $lon,
			     symbol  => $symbol,
			     color   => $color,
			     wpt_xy  => [$x,$y],
			     wpt_txy => [$tx,$ty],
			   };
	    } elsif (m{^(-?[0-9.]+,-?[0-9.]+)}) {
		my($tl_x,$tl_y) = split /,/, $1;
		my $expanded_line = expand $_;
		my($dir_from,$dir_to) = length $expanded_line > 49 ? (substr($expanded_line, 49) =~ m{^([A-Z]{1,2})->([A-Z]{1,2})}) : ();
		my($tl_tx,$tl_ty) = main::transpose($tl_x,$tl_y);
		$res[-1]->{tl_txy} = [$tl_tx,$tl_ty];
		$res[-1]->{tl_dirfrom} = $dir_from;
		$res[-1]->{tl_dirto}   = $dir_to;
	    }
	}
    }
    if (!@res) {
	die "Could not find start of '$filename' or empty data?!";
    }

    $main::c->delete(TAGNAME);
    main::add_to_stack(TAGNAME, 'topmost');
    # $main::str_obj{TAGNAME()} = Strassen::Dummy->new; # XXX
    $main::layer_name{TAGNAME()} = "TrafficLightCircuitGPSTracking";

    $main::map_mode_callback{'BBBikeTrafficLightCircuitGPSTracking'} = sub {
	$main::c->Tk::bind($main::c, '<Motion>', [\&BBBikeTrafficLightCircuitGPSTracking::motion, $main::c]);
    };
    main::set_map_mode('BBBikeTrafficLightCircuitGPSTracking');
    $main::map_mode_deactivate = sub {
	$main::c->Tk::bind($main::c, '<Motion>', '');
    };
    $BBBikeTrafficLightCircuitGPSTracking::STATE = undef;

    for my $i (0 .. $#res) {
	my @dir;
	if ($i == 0) {
	    @dir = (@{ $res[$i]->{wpt_txy} }, @{ $res[$i+1]->{wpt_txy} });
	    eval { main::line_shorten_end(\@dir) }; # XXX be smarter if both points are the same!!!
	    @dir = () if $@;
	} elsif ($i == $#res) {
	    @dir = (@{ $res[$i-1]->{wpt_txy} }, @{ $res[$i]->{wpt_txy} });
	    eval { main::line_shorten_begin(\@dir) }; # XXX be smarter if both points are the same!!!
	    @dir = () if $@;
	} else {
	    @dir = (@{ $res[$i-1]->{wpt_txy} },
		    @{ $res[$i  ]->{wpt_txy} },
		    @{ $res[$i+1]->{wpt_txy} },
		   );
	    eval { main::line_shorten(\@dir) }; # XXX be smarter if some points are the same!!!
	    @dir = () if $@;
	}
	if (@dir) {
	    my($dir_right) = VectorUtil::offset_line(\@dir, 5, 1, 0);
	    @dir = @$dir_right;
	}

	$main::c->createLine(@{ $res[$i]->{wpt_txy} }, @{ $res[$i]->{wpt_txy} },
			     -fill => $res[$i]->{color},
			     -width => 10, # XXX skalieren?
			     -capstyle => $main::capstyle_round,
			     -tags => [TAGNAME, TAGNAME_WPT, TAGNAME_WPT . '-' . $res[$i]->{ident}],
			    );
	$main::c->createText(@{ $res[$i]->{wpt_txy} },
			     -anchor => 'w',
			     -text => ' '.$res[$i]->{ident},
			     -font => $main::font{'tiny'},
			     -tags => TAGNAME,
			    );
	if (@dir) {
	    $main::c->createLine(@dir,
				 -fill => '#606060',
				 -width => 2,
				 -arrow => 'last',
				 -arrowshape => [4,6,3],
				 -smooth => 1,
				 -tags => TAGNAME,
				);
	}

	if ($res[$i]->{tl_txy}) {
	    my($tl_tx,$tl_ty) = @{ $res[$i]->{tl_txy} };
	    $main::c->createLine(@{ $res[$i]->{wpt_txy} },
				 $tl_tx, $tl_ty,
				 -fill => 'black',
				 -dash => '.-',
				 -width => 2,
				 -tags => TAGNAME,
				);
	    my($dirfrom, $dirto) = @{$res[$i]}{qw(tl_dirfrom tl_dirto)};
	    if ($dirfrom && $dirto) {
		s{O}{E}g for ($dirfrom, $dirto);
		my $deltafrom = $BBBikeCalc::wind_dir{BBBikeCalc::canvas_translation(lc($dirfrom))};
		my $deltato   = $BBBikeCalc::wind_dir{BBBikeCalc::canvas_translation(lc($dirto))};
		my $arrowlen  = 20;
		if ($deltafrom) {
		    $main::c->createLine($tl_tx + $deltafrom->[1]*$arrowlen,
					 $tl_ty + $deltafrom->[0]*$arrowlen,
					 $tl_tx, $tl_ty,
					 -tags => TAGNAME,
					);
		}
		if ($deltato) {
		    $main::c->createLine($tl_tx, $tl_ty,
					 $tl_tx + $deltato->[1]*$arrowlen,
					 $tl_ty + $deltato->[0]*$arrowlen,
					 -width => 2,
					 -arrow => 'last',
					 -arrowshape => [4,6,3],
					 -tags => TAGNAME,
					);
		}
	    }
	}
    }

    @CURRENT_DATA = @res;
}

sub tk_link_traffic_light {
    my($wpt, $coords) = @_;
    $CURRENT_FILENAME or die "Missing CURRENT_FILENAME?!";
    @CURRENT_DATA or die "Missing CURRENT_DATA?!";
    tie my @lines, 'Tie::File', ampelschaltung_filename()
	or die "Can't tie: $!";
    my $line_i;
    for($line_i = $#lines; $line_i >= 0; $line_i--) {
	if ($lines[$line_i] =~ m{^#WPTFILE:\s+\Q$CURRENT_FILENAME}) {
	    last;
	}
    }
    if ($line_i == 0) {
	die "Cannot find $CURRENT_FILENAME?!";
    }
    $line_i++;
    for(; $line_i <= $#lines; $line_i++) {
	if ($lines[$line_i] =~ m{^(# Anmerkungen:$|#WPTFILE:\s+)}) {
	    die "Cannot find wpt $wpt?!";
	} elsif ($lines[$line_i] =~ m{^#WPT:\s+\Q$wpt}) {
	    # XXX should use our toplevel!
	    if ($main::top->messageBox(-icon => "question",
				       -title => 'Link?',
				       -message => "Link traffic light $wpt <-> $coords?",
				       -type => "YesNo") =~ /yes/i) {
		link_traffic_light($wpt, $coords);
	    }
	    last;
	}
    }
}

# XXX duplication of code!!!
# XXX vielleicht kann ich mit waitVariable arbeiten? oder irgendwie die Position rüberretten?
sub link_traffic_light {
    my($wpt, $coords) = @_;

    require BBBikeCalc;
    require Strassen::Strasse;

    $CURRENT_FILENAME or die "Missing CURRENT_FILENAME?!";
    @CURRENT_DATA or die "Missing CURRENT_DATA?!";
    my $current_record;
    for (@CURRENT_DATA) {
	if ($_->{ident} eq $wpt) {
	    $current_record = $_;
	    last;
	}
    }
    $current_record or die "Cannot find record for $wpt?!";
    tie my @lines, 'Tie::File', ampelschaltung_filename()
	or die "Can't tie: $!";
    my $line_i;
    for($line_i = $#lines; $line_i >= 0; $line_i--) {
	if ($lines[$line_i] =~ m{^#WPTFILE:\s+\Q$CURRENT_FILENAME}) {
	    last;
	}
    }
    if ($line_i == 0) {
	die "Cannot find $CURRENT_FILENAME?!";
    }
    $line_i++;
    my $crossings = main::all_crossings();
    for(; $line_i <= $#lines; $line_i++) {
	if ($lines[$line_i] =~ m{^(# Anmerkungen:$|#WPTFILE:\s+)}) {
	    die "Cannot find wpt $wpt?!";
	} elsif ($lines[$line_i] =~ m{^#WPT:\s+\Q$wpt}) {
	    my $line = $coords;

	    # color
	    if ($current_record->{color} eq 'green') {
		$line .= ' 'x(60-length($line)) . $current_record->{time};
	    } elsif ($current_record->{color} eq 'red') {
		$line .= ' 'x(70-length($line)) . $current_record->{time};
	    } else {
		die "Unexpected color $current_record->{color}?!";
	    }

	    # crossingname
	    # XXX [#C] Für Fußgängerampeln sollte vielleicht die nächste
	    #          Kreuzung verwendet werden
	    my $crossingname = join("/", map { Strasse::strip_bezirk($_) } @{ $crossings->{$coords} || [] });
	    $crossingname = substr($crossingname, 0, 47-14) if length($crossingname) > 47-14;
	    substr($line, 14, length($crossingname)) = $crossingname;

	    # direction
	    # XXX this is complete madness... everything here is wrong way:
	    # tl_txy and wpt_txy swapped, unexpected usage of canvas_translation,
	    # combination of $direction -> opposite_direction alswo swapped
	    my $direction = BBBikeCalc::canvas_translation(BBBikeCalc::line_to_canvas_direction(@{ $current_record->{tl_txy} },
												@{ $current_record->{wpt_txy} }));
	    $direction = uc($direction) . '->' . uc(BBBikeCalc::opposite_direction($direction));
	    $direction =~ s{E}{O}g; # we're using german directions here
	    substr($line, 49, length($direction)) = $direction;

	    splice @lines, $line_i+1, 0, $line;
	    last;
	}
    }
}

sub ampelschaltung_filename {
    require BBBikeUtil;
    BBBikeUtil::bbbike_root() . "/misc/ampelschaltung-orig.txt";
}

sub wkday_to_german {
    my($wkday_num) = @_;
    [qw(So Mo Di Mi Do Fr Sa)]->[$wkday_num];
}

{
    package BBBikeTrafficLightCircuitGPSTracking;
    use constant TAGNAME        => TrafficLightCircuitGPSTracking::TAGNAME();
    use constant TAGNAME_MOTION => TrafficLightCircuitGPSTracking::TAGNAME() . '-motion';
    use constant TAGNAME_WPT    => TrafficLightCircuitGPSTracking::TAGNAME_WPT();
    our $STATE; # XXX reset if set_map_mode changes!
    our $WPT;

    sub button {
	my($c, $e) = @_;
	my($x, $y) = ($c->canvasx($e->x), $c->canvasy($e->y));
	if ($STATE && $STATE eq 'motion') {
	    my($item, @tags) = main::find_below_rx($c, ['^lsa'], [0]);
	    if ($item) {
		$STATE = undef;
		my $coords = $tags[1];
		TrafficLightCircuitGPSTracking::tk_link_traffic_light($WPT, $coords);
	    }
	} else {
	    my($item, @tags) = main::find_below_rx($c, [TAGNAME_WPT], [1]);
	    if ($item) {
		my @coords = $c->coords($item);
		@coords = (@coords[0,1], $coords[0]+1, $coords[1]+1);
		$c->delete(TAGNAME_MOTION);
		$c->createLine(@coords,-tags => [TAGNAME, TAGNAME_MOTION]);
		$STATE = 'motion';
		$WPT = substr($tags[2], length(TAGNAME_WPT)+1);
	    }
	}
    }
    sub motion {
	my($c) = @_;
	return if !$STATE || $STATE ne 'motion';
	if ($main::escape) {
	    $main::escape = 0;
	    $c->delete(TAGNAME_MOTION);
	    $STATE = undef;
	    return;
	}
	my $e = $c->XEvent;
	my($x, $y) = ($c->canvasx($e->x), $c->canvasy($e->y));
	my($item) = $c->find(withtag => TAGNAME_MOTION);
	if ($item) {
	    my @coords = $c->coords($item);
	    $coords[2] = $x;
	    $coords[3] = $y;
	    $c->coords($item, @coords);
	}
    }
}

return 1 if caller;

######################################################################
# Script usage
require FindBin;
require Getopt::Long;
push @INC, "$FindBin::RealBin/..";
push @INC, "$FindBin::RealBin/../lib";
require GPS::GpsmanData;

sub usage (;$) {
    my $msg = shift;
    warn $msg, "\n" if $msg;
    die <<EOF;
usage: $^X $0 [-force] dump|inject gpsfile
       $^X $0 show_all
EOF
}

my $force;
Getopt::Long::GetOptions("force" => \$force)
    or usage;
my $action = shift or usage "Please specify action: dump or inject";
if ($action eq 'show_all') {
    print join("\n", find_mappings_in_ampelschaltung()), "\n";
} elsif ($action eq 'tk') {
    require Tk;
    my $mw = MainWindow->new;
    tk_gui($mw);
    Tk::MainLoop();
} else {
    my $file   = shift or usage "Please specify gpsmap waypoint file";
    my $gps = GPS::GpsmanData->new;
    $gps->load($file);
    my $info = {};
    my $res = gpsman2ampelschaltung_string($gps, $info);
    if ($action eq 'dump') {
	print $res;
    } elsif ($action eq 'inject') {
	$info->{formatted_date} or die "Strange: did not get formatted date?!";
	if (!$force && find_date_in_ampelschaltung($info->{formatted_date})) {
	    die "Data for date '$info->{formatted_date}' seems to exist already. Force operation with --force.\n";
	}
	inject($res);
    } else {
	usage "Invalid action '$action', please specify either dump or inject";
    }
}

1;

__END__

=head1 NAME

TrafficLightCircuitGPSTracking - handle ampelschaltung.txt data

=head1 SYNOPSIS

=head2 From commandline

Check if everything looks right before importing:

    perl miscsrc/TrafficLightCircuitGPSTracking.pm dump ~/src/bbbike/misc/gps_data/ampelschaltung/...wpt

Do the import:

    perl miscsrc/TrafficLightCircuitGPSTracking.pm inject ~/src/bbbike/misc/gps_data/ampelschaltung/...wpt

=head2 From bbbike

Open ptksh.

    require "miscsrc/TrafficLightCircuitGPSTracking.pm"
    TrafficLightCircuitGPSTracking::tk_gui($top)

=cut
