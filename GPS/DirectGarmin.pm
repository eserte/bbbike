# -*- perl -*-

#
# $Id: DirectGarmin.pm,v 1.41 2009/02/12 00:51:09 eserte Exp $
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

sub has_gps_settings { 1 }

sub ok_label      { M("Upload zum Garmin") }
sub ok_test_label { M("Upload zum Garmin simulieren") }

sub transfer {
    my($self, %args) = @_;
    my $res = $args{-res} or die "-res argument is missing";

    my($gps, $data) = @$res;

    my %maxdist_ret;
    if ($DEBUG && $self->{'debugdata'}) {
	%maxdist_ret = $self->dump;
    }

    if ($main::devel_host) {
	require File::Temp;
	require Storable;
	my($fh,$file) = File::Temp::tempfile(SUFFIX => "_gpsupload.gps");
	warn "Writing data to $file, suitable for upload using examples/upload-test.pl in perl-GPS...\n";
	Storable::nstore($data, $file);
    }

    if ($args{-test}) {
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
	$gps->upload_data($data, $cb);
	if ($gps->{serial}) {
	    # XXX Shouldn't be necessary, but it seems it is...
	    $gps->{serial}->close;
	}
	# If we got here, then everything went OK, so waypoint cache
	# may be updated
	if ($self->{'used_idents'}) {
	    while(my($key,$val) = each %{ $self->{'used_idents'} }) {
		$waypoints{$key}++;
	    }
	} else {
	    warn "What? No used idents here?";
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

sub tk_interface {
    my($self, %args) = @_;
    require BBBikeGPS;
    BBBikeGPS::tk_interface($self, %args);
}

sub reset_waypoint_cache {
    my($self) = @_;
    %waypoints = ();
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

sub simplify_route {
    my($self, $route, %args) = @_;

    require Route::Simplify;

    my $simplified_route = $route->simplify_for_gps(%args, waypointscache => \%waypoints);

    $self->{'origpath'} = $route->path;
    $self->{'used_idents'} = $simplified_route->{'idents'};

    #use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([\@d],[]); # XXX

    $simplified_route;
}

sub convert_from_route {
    my($self, $route, %args) = @_;

    my $gps_device = $args{-gpsdevice} || "/dev/cuaa0";
    my $waypointsymbol = my $waypointsymbol_unimportant = my $waypointsymbol_important = $args{-waypointsymbol};
    if (!$waypointsymbol || $waypointsymbol !~ m{^\d+$}) {
	$waypointsymbol = 8246; # default: summit symbol
	$waypointsymbol_unimportant = 18; # waypoint dot XXX or 8198 (small city)?
	$waypointsymbol_important = $waypointsymbol;
    }

    # Not yet in use...
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
	$gps->{handler} = eval { GPS::Garmin::Handler::EtrexVistaHCx->new($gps) } || # newer perl-GPS
	                  eval { GPS::Garmin::Handler::Generic->new($gps) }; # older
	if (!$gps->{handler}) {
	    die "Cannot setup handler for GPS::Garmin::Dummy object. Maybe a newer perl-GPS is needed?";
	}
	{
	    package GPS::Garmin::Dummy;
	    use base qw(GPS::Garmin);
	}
    }

    my $simplified_route = $self->simplify_route($route,
						 -showcrossings => 0,
						 %args);

    $self->{'debugdata'} = []; # create always as additional return value

    my @d;

    my $handler = $gps->handler;
    push @d,
	[$gps->GRMN_RTE_HDR, $handler->pack_Rte_hdr({nmbr => make_bytes($simplified_route->{routenumber}),
						     cmnt => make_bytes($simplified_route->{routename})})];
    {
	my $n = -1;
	for my $wpt (@{ $simplified_route->{wpt} }) {
	    $n++;
	    if ($n > 0) {
		push @d, [$gps->GRMN_RTE_LINK_DATA, $handler->pack_Rte_link_data];
	    }
	    my $use_waypointsymbol = ($wpt->{importance} > 0 ? $waypointsymbol_important :
				      $wpt->{importance} < 0 ? $waypointsymbol_unimportant :
				      $waypointsymbol
				     );
	    my $wptdata = {lat       => $wpt->{lat},
			   lon       => $wpt->{lon},
			   ident     => make_bytes($wpt->{ident}),
			   smbl      => $use_waypointsymbol, # not really used with wpt_class=0x80
			   wpt_class => 0x80, # this is a routepoint
			  };
	    push @d, [$gps->GRMN_RTE_WPT_DATA, $handler->pack_Rte_wpt_data($wptdata)];
	    push @{$self->{'debugdata'}}, $wpt;
	}
    }

    return [$gps, \@d];
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
