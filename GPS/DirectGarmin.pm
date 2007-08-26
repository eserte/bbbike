# -*- perl -*-

#
# $Id: DirectGarmin.pm,v 1.32 2007/05/24 22:39:41 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003,2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

package GPS::DirectGarmin;
require GPS;
push @ISA, 'GPS';

BEGIN {
    eval 'use GPS::Garmin 0.13'; die $@ if $@;
}

use GPS::Util qw(eliminate_umlauts);

BEGIN {
    if (!eval '
use Msg qw(frommain);
1;
') {
	warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

use strict;
use vars qw($DEBUG %waypoints);
$DEBUG = 1 if !defined $DEBUG;

sub transfer_to_file { 0 }

sub transfer {
    my($self, %args) = @_;
    my $res = $args{-res} or die "-res argument is missing";

    my($gps, $data) = @$res;

    my %maxdist_ret;
    if ($DEBUG && $self->{'debugdata'}) {
	%maxdist_ret = $self->dump;
    }

    if ($args{-test}) {
	require Data::Dumper;
	print STDERR Data::Dumper->new([$data],["gps_data"])->Useqq(1)->Dump . "\n";
	my $wpt = 0;
	foreach (@$data) {
	    $wpt++ if ($_->[0] eq $gps->GRMN_RTE_WPT_DATA);
	}
	my $mess = Mfmt("%s Waypoints in der Route.\n", $wpt);
	if ($maxdist_ret{'maxdist_mess'}) {
	    $mess .= $maxdist_ret{'maxdist_mess'};
	}
	if ($args{-top}) {
	    my $can_plot = $maxdist_ret{'streets_bbd'} &&
		           defined &main::next_free_layer &&
			   defined &main::plot;
	    require Tk::Dialog;
	    my $d = $args{-top}->Dialog
		(-title => 'Simulate transfer',
		 -bitmap => 'info',
		 -text => $mess,
		 -default_button => 'OK',
		 -buttons => ["OK", ($can_plot ? 'Plot' : ())],
		);
	    my $ans = $d->Show;
	    if ($ans =~ /plot/i) {
		my $abk = main::next_free_layer();
		$main::str_file{$abk} = $maxdist_ret{'streets_bbd'};
		$main::str_draw{$abk} = 1;
		main::plot('str',$abk);

		my $abk_p = main::next_free_layer();
		$main::p_file{$abk_p} = $maxdist_ret{'points_bbd'};
		$main::p_draw{$abk_p} = 1;
		main::plot('p',$abk_p);

		# XXX the delay is hackish
		$main::c->after(1000, sub {
				    $main::c->raise($abk);
				    $main::c->raise($abk_p."-fg");
				});
	    }
	} else {
	    print STDERR $mess;
	}
    } else {
	my $cb;
	if ($DEBUG && $DEBUG == 2) {
	    $cb = sub {
		my $i = shift;
		printf STDERR "%3d%%\r", 100*$i/scalar @$data;
	    };
	    warn "About to start upload...\n";
	}
	if (1) {
	    require File::Temp;
	    require Storable;
	    my($fh,$file) = File::Temp::tempfile(SUFFIX => "_gpsupload.gps");
	    warn "Writing data to $file...\n";
	    Storable::nstore($data, $file);
	}
	$gps->upload_data($data, $cb);
	if ($gps->{serial}) {
	    # XXX Shouldn't be necessary, but it seems it is...
	    $gps->{serial}->close;
	}
    }
}

# XXX die Berechnung der Maximalabweichung sollte nicht hier passieren...
sub dump {
    my($self) = @_;
    my $debugdata = $self->{'debugdata'};
    my $tmpdir = $main::tmpdir || "/tmp";
    my $destfile_p = "$tmpdir/gpsdump-points.bbd";
    my $destfile_s = "$tmpdir/gpsdump-streets.bbd";
    require Karte;
    Karte::preload(qw(Polar Standard));

    warn "Writing waypoint data to $destfile_p\n";
    open(DEST, ">$destfile_p") or die $!;
    my @points;
    foreach (@$debugdata) {
	my $ident = $_->{'ident'};
	my($x,$y) = map { int } $Karte::map{'polar'}->map2standard(@$_{qw(lon lat)});
	push @points, "$x,$y";
	print DEST "$ident\t#00b000 $x,$y\n";
    }
    close DEST;

    require VectorUtil;
    my $maxdist = 0;
    my $maxdist_i = 0;
    my $data_i = 0;
    my $path_i = 0;
    foreach my $xy (@{ $self->{'origpath'} }) {
	my($x,$y) = @$xy;
	my($origx1,$origy1) = @{$debugdata->[$data_i]}{qw(origlon origlat)};
	my($origx2,$origy2) = @{$debugdata->[$data_i+1]}{qw(origlon origlat)};
	my $dist = VectorUtil::distance_point_line($x,$y,$origx1,$origy1,$origx2,$origy2);
#warn "$dist: ($x,$y,$origx1,$origy1,$origx2,$origy2)";
	if ($dist > $maxdist) {
	    $maxdist = $dist;
	    $maxdist_i = $data_i;
	}
	if ($origx2 == $x && $origy2 == $y) {
	    $data_i++;
	}
    } continue { $path_i++ }
    my $maxdist_ident = $debugdata->[$maxdist_i]{'ident'};
    my $maxdist_mess  = Mfmt("Maximalabweichung: %d m an GPS-Routenpunkt <%s>\n", $maxdist, $maxdist_ident);
    my %ret = (maxdist       => $maxdist,
	       maxdist_ident => $maxdist_ident,
	       maxdist_mess  => $maxdist_mess,
	       streets_bbd   => $destfile_s,
	       points_bbd    => $destfile_p,
	      );
    warn $maxdist_mess;

    warn Mfmt("Schreibe Routendaten in die Datei %s\n", $destfile_s);
    open(DEST2, ">$destfile_s") or die $!;
    print DEST2 "GPS route\t#000080 " . join(" ", @points) . "\n";
    close DEST2;

    %ret;
}

use vars qw($old_route_info_name $old_route_info_number $old_route_info_wpt_suffix $old_route_info_wpt_suffix_existing);
$old_route_info_wpt_suffix_existing=1;

sub tk_interface {
    my($self, %args) = @_;
#XXX    return 1 if $args{-test}; # comment out if also testing wptsuffix
    my $top = $args{-top} or die "-top arg is missing";
    my $gps_route_info = $args{-gpsrouteinfo} or die "-gpsrouteinfo arg is missing";
    $gps_route_info->{Name} ||= $old_route_info_name if defined $old_route_info_name;
    $gps_route_info->{Number} ||= $old_route_info_number if defined $old_route_info_number;
    $gps_route_info->{WptSuffix} ||= $old_route_info_wpt_suffix if defined $old_route_info_wpt_suffix;
    $gps_route_info->{WptSuffixExisting} ||= $old_route_info_wpt_suffix_existing if defined $old_route_info_wpt_suffix_existing;
    my $t = $top->Toplevel(-title => "GPS");
    $t->transient($top) if $main::transient;
    Tk::grid($t->Label(-text => M"Name der Route"),
	     my $e = $t->Entry(-textvariable => \$gps_route_info->{Name},
			       -validate => 'all',
			       -vcmd => sub { length $_[0] <= 13 }),
	     -sticky => "w");
    $e->focus;
    my $NumEntry = 'Entry';
    my @NumEntryArgs = ();
    if (eval { require Tk::NumEntry }) {
	$NumEntry = "NumEntry";
	@NumEntryArgs = (-minvalue => 1, -maxvalue => 20);
    }
    Tk::grid($t->Label(-text => M"Routennummer"),
	     $t->$NumEntry(-textvariable => \$gps_route_info->{Number},
			   @NumEntryArgs,
			   -validate => 'all',
			   -vcmd => sub { $_[0] =~ /^\d*$/ }),
	     -sticky => "w");
    Tk::grid($t->Label(-text => M"Waypoint-Suffix"),
	     $t->Entry(-textvariable => \$gps_route_info->{WptSuffix}),
	     -sticky => "w");
    Tk::grid($t->Checkbutton(-text => M"Suffix nur bei vorhandenen Waypoints verwenden",
			     -variable => \$gps_route_info->{WptSuffixExisting}),
	     -sticky => "w", -columnspan => 2);
    Tk::grid($t->Button(-text => M"Waypoints-Cache zurücksetzen",
			-command => sub {
			    %waypoints = ();
			}),
	     -sticky => "w", -columnspan => 2);
    if (defined &main::optedit) {
	Tk::grid($t->Button(-text => M"GPS-Einstellungen",
			    -command => sub {
				main::optedit(-page => M"GPS");
			    }),
		 -sticky => "w", -columnspan => 2);
    }
    my $weiter = 0;
    {
	my $f = $t->Frame->grid(-columnspan => 2, -sticky => "ew");
	Tk::grid($f->Button(-text => ($args{-test} ?
				      M("Upload zum Garmin simulieren") :
				      M("Upload zum Garmin")),
			    -command => sub { $weiter = 1 }),
		 $f->Button(Name => "cancel",
			    -text => M"Abbruch",
			    -command => sub { $weiter = -1 }),
		);
    }
    $t->gridColumnconfigure($_, -weight => 1) for (0..1);
    $t->OnDestroy(sub { $weiter = -1 });
    $t->waitVariable(\$weiter);
    $t->afterIdle(sub { if (Tk::Exists($t)) { $t->destroy } });

    if ($weiter == 1) {
	$old_route_info_name = $gps_route_info->{Name};
	$old_route_info_number = $gps_route_info->{Number};
	$old_route_info_wpt_suffix = $gps_route_info->{WptSuffix};
	$old_route_info_wpt_suffix_existing = $gps_route_info->{WptSuffixExisting};
    }

    return undef if $weiter == -1;
    1;
}

### this should load a route or track from the GPS device and
### convert it to bbd/bbr
#  sub convert_to_route {
#      my($self, $file, %args) = @_;

#      my($fh, $lines_ref) = $self->overread_trash($file, %args);
#      die "File $file does not match" unless $fh;

#      require Karte::Polar;
#      my $obj = $Karte::Polar::obj;

#      my @res;
#      my $check = sub {
#  	my $line = shift;
#  	chomp;
#  	if (m|^W\s+(?:\w+)\s+([NS])(\d+)\s+([\d.]+)\s+([EW])(\d+)\s+([\d.]+)|) {
#  	    my $breite = $2;
#  	    my $laenge = $5;

#  	    my $breite_min = $3/60;
#  	    my $laenge_min = $6/60;

#  	    $breite += $breite_min;
#  	    $laenge += $laenge_min;

#  	    if ($1 eq 'S') { $breite = -$breite }
#  	    if ($3 eq 'W') { $laenge = -$laenge }
#  	    my($x,$y) = $obj->map2standard($laenge, $breite);
#  	    if (!@res || ($x != $res[-1]->[0] ||
#  			  $y != $res[-1]->[1])) {
#  		push @res, [$x, $y];
#  	    }
#  	}
#      };

#      $check->($_) foreach @$lines_ref;
#      while(<$fh>) {
#  	$check->($_);
#      }

#      close $fh;

#      @res;
#  }

# der eTrex kann 50 Punkte pro Route aufzeichnen
# XXX
# ideas:
#  wichtigkeitspunkte für jeden (möglichen) punkt vergeben:
#  - viele punkte für große winkel
#  - punkte für straßennamenswechsel
#  - evtl. minuspunkte für kleine entfernungen vom vorherigen+nächsten punkt
#XXX mit GpsmanData und den anderen Modulen mergen!!!
sub convert_from_route {
    my($self, $route, %args) = @_;

    no locale; # for scalar localtime

    require Karte::Polar;
    require Strassen;

    my $obj = $Karte::Polar::obj;

    my $routename = sprintf("%-8s", $args{-routename} || "TRACBACK");
    my $routenumber = $args{-routenumber} || 1;
    my $str       = $args{-streetobj};
    my $net       = $args{-netobj};
    my $wptsuffix = $args{-wptsuffix} || "";
    my $wptsuffixexisting = $args{-wptsuffixexisting} || 0;
    my $convmeth  = $args{-convmeth} || sub {
	$obj->standard2map(@_);
    };
    my $waypointlength = $args{-waypointlength} || 10;
    my $waypointsymbol = $args{-waypointsymbol};
    if (!$waypointsymbol || $waypointsymbol !~ m{^\d+$}) {
	$waypointsymbol = 8246; # default: summit symbol
    }

    my $gps_device = $args{-gpsdevice} || "/dev/cuaa0";
    my %crossings;
    if ($str) {
	%crossings = %{ $str->all_crossings(RetType => 'hash',
					    UseCache => 1) };
    }

    my $now = scalar localtime;
    my $ident_counter = 0;
    my %idents;
    use constant MAX_COMMENT => 45;

    use constant DISPLAY_SYMBOL_BIG => 8196; # zwei kleine Füße (sym_trcbck)
    use constant DISPLAY_SYMBOL_SMALL => 18; # viereckiger Punkt, also allgemeiner Wegepunkt (waypoint dot)
    use constant SHOW_SYMBOL => 1;
    use constant SHOW_SYMBOL_AND_NAME => 4; # XXX ? ja ?
    use constant SHOW_SYMBOL_AND_COMMENT => 5;

    my $gps;
    if (!$args{-test}) {
	$gps = new GPS::Garmin(  'Port'      => $gps_device,
				 'Baud'      => 9600, # XXX don't hardcode
				 ($DEBUG >= 2 ? (verbose => 1) : ()),
			      ) or
				  die Mfmt("Verbindung zum GPS-Gerät <%s> fehlgeschlagen", $gps_device);
    } else {
	$gps = bless {}, 'GPS::Garmin::Dummy';
	{
	    package GPS::Garmin::Dummy;
	    *handler      = sub { bless {}, 'GPS::Garmin::Dummy' };
	    sub dummy { 0 }
	    sub AUTOLOAD { goto &dummy }
	    # more dummy definition
	    sub GRMN_RTE_LINK_DATA { 1 }
	    sub GRMN_RTE_WPT_DATA  { 2 }
	}
    }

    my @d;

    my $handler = $gps->handler;
    push @d,
	[$gps->GRMN_RTE_HDR, $handler->pack_Rte_hdr({nmbr => make_bytes($routenumber),
						     cmnt => make_bytes($routename)})];
    $self->{'debugdata'} = []; # create always as additional return value

    my @path;
    my $obj_type;
    if ($args{-routetoname}) {
	@path = map {
	    $route->path->[$_->[&StrassenNetz::ROUTE_ARRAYINX][0]]
	} @{$args{-routetoname}};
	push @path, $route->path->[-1]; # add goal node
	$obj_type = 'routetoname';
    } else {
	if ($net && $args{-simplify}) {
	    my $max_waypoints = $args{-maxwaypoints} || 50;
	    @path = $route->path_list_max($net, $max_waypoints);
	} else {
	    @path = $route->path_list;
	}
	$obj_type = 'route';
    }

    my $n = 0;
    foreach my $xy (@path) {
	my $xy_string = join ",", @$xy;
	my($lon, $lat) = $convmeth->(@$xy); # XXX del: $obj->standard2map(@$xy);

	#warn "lon=$lon lat=$lat\n";

	# create comment and point number
	my $comment = "";
	my $ident;
	my @cross_streets;
	if ($str && exists $crossings{$xy_string}) {

	    @cross_streets = @{ $crossings{$xy_string} };
	}

	if ($obj_type eq 'routetoname') {
	    my $main_street = $args{-routetoname}->[$n][&StrassenNetz::ROUTE_NAME];
	    my $prev_street = $args{-routetoname}->[$n-1][&StrassenNetz::ROUTE_NAME] if $n > 0;

	    # test for simplify_route_to_name output:
	    if (ref $main_street eq 'ARRAY') {
		$main_street = $main_street->[0];
	    }
	    if (ref $prev_street eq 'ARRAY') {
		$prev_street = $prev_street->[-1];
	    }

	    # This condition is hacky: because landstrassen may or may not be
	    # transformed from "A - B" to "(A -) B" or "(B -) A" the
	    # $prev_street vs. $main_street comparison below does not
	    # work. The workaround is to remove the (A -) part. This
	    # would be removed anyway in the short_landstrasse function.
	    if (defined $main_street && $main_street =~ m/\s*\([^\)]+-\)\s*/) { # XXX (... -) ...
		@cross_streets = $main_street;
	    }

	    # no crossing => use at least the current street
	    if (!@cross_streets) {
		@cross_streets = $main_street;
	    }
	    # if the main street is still the same, then use the
	    # "+crossingstreet" syntax
	    # XXX theoretisch kann "+crossingstreet+mainstreet" passieren,
	    # was nicht so schön wäre ... aber dazu müsste crossingstreet
	    # superkurz oder $waypointlength superlang sein
	    # XXX die Abfrage im map scheint teilweise überflüssig zu sein
	    # (main_street eq prev_street!)
	    elsif (defined $prev_street && $prev_street eq $main_street &&
		   @cross_streets > 1) {
		@cross_streets =
		    ("",
		     map  { $_->[0] }
		     sort { $b->[1] <=> $a->[1] }
		     map  { [$_, $_ eq $main_street ? -99 : (defined $prev_street && $_ eq $prev_street ? -100 : 0) ] }
		     @cross_streets);
	    }
	    # Sort the crossing streets so, that the current street
	    # is first and the previous street (if any) is last.
	    else {
		if (defined $prev_street && $prev_street eq $main_street) {
		    undef $prev_street;
		}
		@cross_streets =
		    (map  { $_->[0] }
		     sort { $b->[1] <=> $a->[1] }
		     map  { [$_, $_ eq $main_street ? 100 : (defined $prev_street && $_ eq $prev_street ? -100 : 0) ] }
		     @cross_streets);
	    }
	}

	if (@cross_streets) {
	    # try to shorten street names
            if ($n < $#path) {
	        $cross_streets[0] = short_landstrasse($cross_streets[0], $net, $xy_string, join(",",@{ $path[$n+1] }));
	    }
	    my $short_crossing;
	    my $level = 0;
	    while($level <= 3) {
		# XXX the "+" character is not supported by all Garmin devices
		$short_crossing = join("+", map { s/\s+\(.*\)\s*$//; Strasse::short($_, $level, "nodot") } grep { defined } @cross_streets);
		$short_crossing = _eliminate_umlauts($short_crossing);
		last
#		    if (length($short_crossing) + length($comment) <= MAX_COMMENT);
		    if (length($short_crossing) + length($comment) <= $waypointlength);
		$level++;
	    }

	    $comment .= $short_crossing;

	    my $short_name;
	    my $suffix_in_use = 0;
	    my $create_short_name = sub {
		my($suffix,$name) = @_;
		$name = substr($name.(" "x $waypointlength), 0, $waypointlength);
		if ($suffix ne "") {
		    substr($name, $waypointlength-length($suffix), length($suffix), $suffix);
		    $suffix_in_use = $suffix;
		} else {
		    $suffix_in_use = "";
		}
		uc($name); # Garmin etrex venture supports only uppercase chars
	    };
	TRY: {
		if ($wptsuffix ne "" && $wptsuffixexisting) {
		    $short_name = $create_short_name->("",$short_crossing);
		    last TRY if (!exists $waypoints{$short_name});
		}
		$short_name = $create_short_name->($wptsuffix,$short_crossing);
	    }

	    $ident = $short_name;
	    my $local_ident_counter = ord("0")-1;
	    while (exists $idents{$ident}) { # ||
#		   ($wptsuffixexisting && $wptsuffix ne "" && exists $waypoints{$ident})) {
		$local_ident_counter++;
		if ($local_ident_counter > ord("Z")) {
		    last; # give up
		} elsif ($local_ident_counter > ord("9") &&
			 $local_ident_counter < ord("A")) {
		    $local_ident_counter = ord("A");
		}
		substr($ident,$waypointlength-1-length($suffix_in_use),1) = chr($local_ident_counter);
	    }

	    if (length($comment) > MAX_COMMENT) {
		$comment = substr($comment, 0, MAX_COMMENT);
	    }
	}

	if (!defined $ident || $ident =~ /^\s*$/) {
	    if ($n == 0) {
		$ident = "START $routenumber"; # no $wptsuffix needed
	    } elsif ($n == $#path) {
		$ident = "GOAL $routenumber";
	    } else {
		$ident = $wptsuffix."T". ($ident_counter++); # don't bother with wptsuffixexisting here, and with suffix used as a prefix here
	    }
	}

	print STDERR $ident, "\n";
	$idents{$ident}++;
	$waypoints{$ident}++;

	if ($n > 0) {
	    push @d, [$gps->GRMN_RTE_LINK_DATA, $handler->pack_Rte_link_data];
	}
	my $wptdata = {lat => $lat, lon => $lon, ident => make_bytes($ident), smbl => $waypointsymbol};
	push @d, [$gps->GRMN_RTE_WPT_DATA, $handler->pack_Rte_wpt_data($wptdata)];
	push @{$self->{'debugdata'}}, {%$wptdata, origlon => $xy->[0], origlat => $xy->[1]};
    } continue {
	$n++;
    }

    $self->{'origpath'} = $route->path;

#use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([\@d],[]); # XXX

    return [$gps, \@d];

}

# ... and more
sub _eliminate_umlauts {
    my $s = shift;
    $s = GPS::Util::eliminate_umlauts($s);
    # And more shortenings:
    $s =~ s/[\(\)]//g;
    $s =~ s/str\./str/g;
    $s =~ s/\./ /g;
    $s;
}

sub short_landstrasse {
    my($s, $net, $xy1, $xy2) = @_;
    $s = Strasse::beautify_landstrasse($s, $net->street_is_backwards($xy1, $xy2));
    $s =~ s/:\s+/ /g;
    $s =~ s/\s*\([^\)]+-\)\s*/-/g;
    $s;
}

sub make_bytes {
    my $s = shift;
    if (eval { require Encode; 1 }) {
	$s = Encode::encode("iso-8859-1", $s);
    }
    $s;
}

1;

__END__
