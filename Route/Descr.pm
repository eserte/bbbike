# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2002,2012 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Route::Descr;

use strict;
use vars qw($VERSION);
$VERSION = '1.05';

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use Strassen::Strasse;

my $VERBOSE = 1;
my $msg;

#
# poor man's msg framework
#
# Currently it is using the message file living under cgi/msg
#
sub M ($) {
    my $phrase = shift;

    #  config error?
    if (!$msg) {
        warn "Msg not configured\n" if $VERBOSE >= 2;
        return $phrase; 
    }

    # well done
    return $msg->{$phrase} if exists $msg->{$phrase};

    # nothing found, orginal phrase used
    warn "Unknown translation: $phrase\n" if $VERBOSE;
    return $phrase;  
}

sub init_msg {
    my $lang = shift;

    undef $msg;
    return if !$lang;

    my @candidates = (dirname(abs_path(__FILE__))."/../cgi/msg/$lang",
		      do {
			  # This only works if called from bbbike.cgi:
			  require FindBin;
			  "$FindBin::RealBin/msg/$lang"
		      }
		     );
    for my $candidate (@candidates) {
	if (-r $candidate && do {
	    $msg = eval { do $candidate };
	    if ($msg && ref $msg ne 'HASH') {
		undef $msg;
	    }
	    $msg
	}) {
	    last;
	}
    }
}

sub convert {
    my(%args) = @_;

    my $net   = delete $args{-net}   || die "-net is missing";
    my $r = delete $args{-route} || die "-route is missing";
    my $comments_net = delete $args{-commentsnet};
    my $startname = delete $args{-startname};
    my $starthnr  = delete $args{-starthnr};
    my $vianame = delete $args{-vianame};
    my $viahnr  = delete $args{-viahnr};
    my $zielname = delete $args{-zielname};
    my $zielhnr  = delete $args{-zielhnr};
    my $verbose  = delete $args{-verbose};
    my $lang  = delete $args{-lang};
    my $city = delete $args{-city} || 'Berlin_DE';

    if (keys %args) {
	die "Invalid argument to outout method";
    }
    $VERBOSE = $verbose if defined $verbose;
    init_msg($lang);

    my(@strnames) = $net->route_to_name($r->path);
    if (!defined $startname) {
	$startname = $strnames[0]->[0];
    }
    if (!defined $zielname) {
	$zielname = $strnames[-1]->[0];
    }
    my @path = $r->path_list;

    my %ret;

    {
	my @str = M("Route von");
	push @str, $startname;
	push @str, $starthnr if defined $starthnr;
	if (defined $vianame) {
	    push @str, M("über"), $vianame;
	    push @str, $viahnr if defined $viahnr;
	}
	push @str, M("bis"), $zielname;
	push @str, $zielhnr if defined $zielhnr;
	$ret{Start} = $startname;
	$ret{Goal}  = $zielname;
	$ret{Title} = join(" ", @str);
    }

    # Note: taken from display_route() in bbbike.cgi
    my @lines;
    my($next_entf, $ges_entf_s, $next_winkel, $next_richtung, $next_extra);
    my $ges_entf = 0;
    for(my $i = 0; $i <= $#strnames; $i++) {
	my $strname;
	my $etappe_comment = '';
	my $route_inx;
	my $important_angle_crossing_name;
	my($entf, $winkel, $richtung, $extra)
	    = ($next_entf, $next_winkel, $next_richtung, $next_extra);
	($strname, $next_entf, $next_winkel, $next_richtung,
	 $route_inx, $next_extra) = @{$strnames[$i]};
	$strname = Strasse::strip_bezirk_perfect($strname, $city);
	if ($i > 0) {
	    if (!$winkel) { $winkel = 0 }
	    $winkel = int($winkel/10)*10;
	    my $same_streetname_important_angle =
		@lines && $lines[-1]->[2] eq $strname && $extra && $extra->{ImportantAngleCrossingName};
	    if ($winkel < 30 && (!$extra || !$extra->{ImportantAngle})) {
		$richtung = "";
	    } elsif ($winkel >= 160 && $winkel <= 200) { # +/- 20° from 180°
		$richtung = M('umdrehen');
	    } else {
		$richtung =
		    ($winkel <= 45 ? M('halb') : '') .
			($richtung eq 'l' ? M('links') : M('rechts')) . ' ' .
			    "($winkel°) ";
		if (($lang||'') eq 'en') {
		    $richtung .= '->';
		} else {
		    if ($same_streetname_important_angle) {
			$richtung .= 'weiter ' . Strasse::de_artikel_dativ($strname);
		    } else {
			$richtung .= Strasse::de_artikel($strname);
		    }
		}
	    }
	    if ($same_streetname_important_angle) {
		$important_angle_crossing_name = Strasse::strip_bezirk($extra->{ImportantAngleCrossingName});
	    }
	    $ges_entf += $entf;
	    $ges_entf_s = sprintf "%.1f km", $ges_entf/1000;
	    $entf = sprintf "%s %.2f km", M("nach"), $entf/1000;

	} elsif ($#{ $r->path } > 1) {
	    #XXX aktivieren, wenn BBBikeCalc ein "richtiges" Modul ist
#  	    # XXX main:: ist haesslich
#  	    $richtung = "nach " .
#  		uc(#main::opposite_direction #XXX why???
#  		   (main::line_to_canvas_direction
#  		    (@{ $r->path->[0] },
#  		     @{ $r->path->[1] })));
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
	    $etappe_comment = join("; ", @comments) if @comments;
	}

	push @lines, [$entf, $richtung, $strname, $ges_entf_s];
        if ( $comments_net) {
	    push @{$lines[-1]}, $etappe_comment;
	}
    }
    $ret{Lines} = \@lines;

    {
	$ges_entf_s = sprintf "%.1f km", ($ges_entf+$next_entf)/1000;
	my $entf = sprintf "%s %.2f km", M("nach"), $next_entf/1000;
	$ret{Footer} = [$entf, "", M("angekommen")."!", $ges_entf_s];
    }

    \%ret;
}

1;

__END__
