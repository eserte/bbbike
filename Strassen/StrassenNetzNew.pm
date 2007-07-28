# -*- perl -*-

#
# $Id: StrassenNetzNew.pm,v 1.3 2007/07/28 20:50:34 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# XXX do not used yet...

package StrassenNetz;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use Strassen::Core;
use BBBikeCalc qw();

# XXX This should replace the part in bbbike.cgi
sub extended_route_info {
    my($self, %args) = @_;

    my $r = delete $args{Route} || die "Route missing";
    my $city = delete $args{City} || die "City missing";
    my $goalname = delete $args{GoalName} || die "GoalName missing";

    my $bp_obj = delete $args{BikePower};

    my @weather_res;
    if ($args{WeatherRes}) {
	@weather_res = @{ delete $args{WeatherRes} };
    }

    my @power;
    if ($args{Power}) {
	@power = @{ delete $args{Power} };
    }
    my @speed;
    if ($args{Speed}) {
	@speed = @{ delete $args{Speed} };
    }
    my $pref_speed = delete $args{PrefSpeed};

    my $handicap_net     = delete $args{HandicapNet};
    my $comments_net     = delete $args{CommentsNet};
    my $comments_points  = delete $args{CommentsPoints};
    my $fragezeichen_net = delete $args{FragezeichenNet};

    my $trafficlights = delete $args{Trafficlights};

    if (keys %args) {
	die "Unhandled arguments: " . join(" ", %args);
    }

    my @out_route;
    my %speed_map;
    my %power_map;

    if (!$r->path_list) {
	goto CLEANUP;
    }

    my @strnames = $self->route_to_name($r->path);
    my @path = $r->path_list;

    if (@power) {
	my @bikepwr_time = (0) x scalar @power;
	use vars qw($wind_dir $wind_v %wind_dir $wind); # XXX oben definieren
	if ($bp_obj && @weather_res && exists $wind_dir{lc($weather_res[4])}) {
	    analyze_wind_dir($weather_res[4]);
	    $wind = 1;
	    $wind_v = $weather_res[7];
	    my(@path) = $r->path_list;
	    for(my $i = 0; $i < $#path; $i++) {
		my($x1, $y1) = @{$path[$i]};
		my($x2, $y2) = @{$path[$i+1]};
		my($deltax, $deltay) = ($x1-$x2, $y1-$y2);
		my $etappe = sqrt(sqr($deltax) + sqr($deltay));
		next if $etappe == 0;
# XXX feststellen, warum hier ein Minus stehen muß...
		my $hw = -head_wind($deltax, $deltay);
		# XXX Doppelung mit bbbike-Code vermeiden
		my $wind; # Berechnung des Gegenwindes
		if ($hw >= 2) {
		    $wind = -$wind_v;
		} elsif ($hw > 0) { # unsicher beim Crosswind
		    $wind = -$wind_v*0.7;
		} elsif ($hw > -2) {
		    $wind = $wind_v*0.7;
		} else {
		    $wind = $wind_v;
		}
		for my $i (0 .. 2) {
		    # XXX Höhenberechnung nicht vergessen
		    # XXX Doppelung mit bbbike-Code vermeiden
		    my $bikepwr_time_etappe =
		      ( $etappe / bikepwr_get_v($wind, $power[$i]));
		    $bikepwr_time[$i] += $bikepwr_time_etappe;
		}
	    }
	}

	if ($bp_obj and $bikepwr_time[0]) {
	    for my $i (0 .. $#power) {
		$power_map{$power[$i]} = {Time => $bikepwr_time[$i]};
	    }
	}
    }

    foreach my $speed (@speed) {
	my $def = {};
	$def->{Pref} = (defined $pref_speed && $speed == $pref_speed);
	my $time;
	if ($handicap_net) {
	    my %handicap_speed = ("q4" => 5); # hardcoded für Fußgängerzonen
	    $time = 0;
	    my @realcoords = @{ $r->path };
	    for(my $ii=0; $ii<$#realcoords; $ii++) {
		my $s = Strassen::Util::strecke($realcoords[$ii],$realcoords[$ii+1]);
		my @etappe_speeds = $speed;
#		    if ($qualitaet_net && (my $cat = $qualitaet_net->{Net}{join(",",@{$realcoords[$ii]})}{join(",",@{$realcoords[$ii+1]})})) {
#		    push @etappe_speeds, $qualitaet_s_speed{$cat}
#			if defined $qualitaet_s_speed{$cat};
#		}
		if ($handicap_net && (my $cat = $handicap_net->{Net}{join(",",@{$realcoords[$ii]})}{join(",",@{$realcoords[$ii+1]})})) {
		    push @etappe_speeds, $handicap_speed{$cat}
			if defined $handicap_speed{$cat};
		}
		$time += ($s/1000)/min(@etappe_speeds);
	    }
	} else {
	    $time = $r->len/1000/$speed;
	}
	$def->{Time} = $time;
	$speed_map{$speed} = $def;
    }

    if (!defined $r->trafficlights && $trafficlights) {
	$r->add_trafficlights($trafficlights);
    }

    my($next_entf, $ges_entf_s, $next_winkel, $next_richtung);
    ($next_entf, $ges_entf_s, $next_winkel, $next_richtung)
	= (0, "", undef, "");

    my $ges_entf = 0;
    for(my $i = 0; $i <= $#strnames; $i++) {
	my $strname;
	my $etappe_comment = '';
	my $fragezeichen_comment = '';
	my $entf_s;
	my $raw_direction;
	my $route_inx;
	my($entf, $winkel, $richtung)
	    = ($next_entf, $next_winkel, $next_richtung);
	($strname, $next_entf, $next_winkel, $next_richtung,
	 $route_inx) = @{$strnames[$i]};
	$strname = Strasse::strip_bezirk_perfect($strname, $city);
	if ($i > 0) {
	    if (!$winkel) { $winkel = 0 }
	    $winkel = int($winkel/10)*10;
	    if ($winkel < 30) {
		$richtung = "";
		$raw_direction = "";
	    } else {
		$raw_direction =
		    ($winkel <= 45 ? 'h' : '') .
			($richtung eq 'l' ? 'l' : 'r');
		$richtung =
		    ($winkel <= 45 ? 'halb' : '') .
			($richtung eq 'l' ? 'links ' : 'rechts ') .
			    "($winkel°) " . Strasse::de_artikel($strname);
	    }
	    $ges_entf += $entf;
	    $ges_entf_s = sprintf "%.1f km", $ges_entf/1000;
	    $entf_s = sprintf "nach %.2f km", $entf/1000;
	} elsif ($#{ $r->path } > 1) {
	    my($x1,$y1) = @{ $r->path->[0] };
	    my($x2,$y2) = @{ $r->path->[1] };
	    $raw_direction =
		uc(BBBikeCalc::line_to_canvas_direction
		   ($x1,$y1,$x2,$y2));
	    $richtung = "nach " . BBBikeCalc::localize_direction($raw_direction, "de");
	}

	if ($comments_net) {
	    my @comments;
	    my %seen_comments_in_this_etappe;
	    for my $i ($strnames[$i]->[4][0] .. $strnames[$i]->[4][1]) {
		my @etappe_comments = $comments_net->get_point_comment(\@path, $i, undef);
		foreach my $etappe_comment (@etappe_comments) {
		    $etappe_comment =~ s/^.+?:\s+//; # strip street
		    if (!exists $seen_comments_in_this_etappe{$etappe_comment}) {
			push @comments, $etappe_comment;
			$seen_comments_in_this_etappe{$etappe_comment}++;
		    }
		}
	    }
	    for my $i ($strnames[$i]->[4][0] .. $strnames[$i]->[4][1]) {
		my $point = join ",", @{ $path[$i] };
		if (exists $comments_points->{$point}) {
		    my $etappe_comment = $comments_points->{$point};
		    # XXX not yet: problems with ... Sekunden Zeitverlust
		    #if (!exists $seen_comments_in_this_etappe{$etappe_comment}) {
		    push @comments, $etappe_comment;
		    #} else {
		    #} # XXX better solution for multiple point comments: use (2x), (3x) ...
		}
	    }
	    $etappe_comment = join("; ", @comments) if @comments;
	}

	if ($fragezeichen_net) {
	    my @comments;
	    my %seen_comments_in_this_etappe;
	    for my $i ($strnames[$i]->[4][0] .. $strnames[$i]->[4][1]) {
		my($from, $to) = (join(",", @{$path[$i]}),
				  join(",", @{$path[$i+1]}));
		if (exists $fragezeichen_net->{Net}{$from}{$to}) {
		    my($etappe_comment) = $fragezeichen_net->get_street_record($from, $to)->[Strassen::NAME()];
		    if (!exists $seen_comments_in_this_etappe{$etappe_comment}) {
			push @comments, $etappe_comment;
			$seen_comments_in_this_etappe{$etappe_comment} = 1;
		    }
		}
	    }
	    $fragezeichen_comment = join("; ", @comments) if @comments;
	}

	push @out_route, {
			  Dist => $entf,
			  DistString => $entf_s,
			  TotalDist => $ges_entf,
			  TotalDistString => $ges_entf_s,
			  Direction => $raw_direction,
			  DirectionString => $richtung,
			  Angle => $winkel,
			  Strname => $strname,
			  ($comments_net ?
			   (Comment => $etappe_comment) : ()
			  ),
			  ($fragezeichen_net ?
			   (FragezeichenComment => $fragezeichen_comment) : () # XXX key label may change!
			  ),
			  Coord => join(",", @{$r->path->[$route_inx->[0]]}),
			  PathIndex => $route_inx->[0],
			 };
    }
    $ges_entf += $next_entf;
    $ges_entf_s = sprintf "%.1f km", $ges_entf/1000;
    my $entf_s = sprintf "nach %.2f km", $next_entf/1000;
    push @out_route, {
		      Dist => $next_entf,
		      DistString => $entf_s,
		      TotalDist => $ges_entf,
		      TotalDistString => $ges_entf_s,
		      DirectionString => "angekommen!",
		      Strname => $goalname,
		      Coord => join(",", @{$r->path->[-1]}),
		      PathIndex => $#{$r->path},
		     };

 CLEANUP:
    +{
      Route => \@out_route,
      Len   => $r->len,
      Trafficlights => $r->trafficlights,
      Speed => \%speed_map,
      Power => \%power_map,
      Path => [ map { join ",", @$_ } @{ $r->path }],
#       LongLatPath => [ map {
# 	  join ",", $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map(@$_))
#       } @{ $r->path }],
     };
}

sub make_comments_net {
    my($self, %args) = @_;
    my $comments_net;

    my $scope = delete $args{Scope};
    my @custom;
    if ($args{Custom}) {
	@custom = @{ delete $args{Custom} };
    }
    my $custom_s;
    if ($args{CustomS}) {
	$custom_s = delete $args{CustomS};
    }

    die "Unhandled arguments: " . join(" ", %args)
	if keys %args;

    my @s;
    my @comment_files = qw(comments qualitaet_s);
    if ($scope eq 'region' || $scope eq 'wideregion') {
	push @comment_files, "qualitaet_l";
    }
    if (@custom && grep { $_ =~ /^temp-blocking-/ } @custom &&
	$custom_s->{"handicap"}) {
	push @s, $custom_s->{"handicap"};
    } else {
	push @comment_files, "handicap_s";
	if ($scope eq 'region' || $scope eq 'wideregion') {
	    push @comment_files, "handicap_l";
	}
    }
    
    for my $s (@comment_files) {
	eval {
	    if ($s eq 'comments') {
		push @s, MultiStrassen->new
		    (map { "comments_$_" } grep { $_ ne "kfzverkehr" } @Strassen::Dataset::comments_types);
	    } elsif ($s =~ /^(qualitaet|handicap)/) {
		my $old_s = Strassen->new($s);
		my $new_s = $old_s->grepstreets
		    (sub { $_->[Strassen::CAT] !~ /^[qQ]0/ },
		     -idadd => "q1234");
		push @s, $new_s;
	    } else {
		push @s, Strassen->new($s);
	    }
	};
	warn "$s: $@" if $@;
    }

    if (@s) {
	$comments_net = StrassenNetz->new(MultiStrassen->new(@s));
	$comments_net->make_net_cat(-obeydir => 1,
				    -net2name => 1,
				    -multiple => 1);
    }

    $comments_net;
}

sub make_comments_points {
    my($self, %args) = @_;

    my $comments_points = {};

    eval {
	my $s = Strassen->new("gesperrt");
	$s->init;
	while(1) {
	    my $r = $s->next;
	    last if !@{ $r->[Strassen::COORDS] };
	    if ($r->[Strassen::CAT] =~ /^0(?::(\d+))?/) {
		my $name = $r->[Strassen::NAME];
		if (defined $1) {
		    $name .= " (ca. $1 Sekunden Zeitverlust)";
		}
		$comments_points->{$r->[Strassen::COORDS][0]} = $name;
	    }
	}
    };
    warn $@ if $@;

    $comments_points;
}

1;

__END__
