# -*- perl -*-

#
# $Id: Descr.pm,v 1.2 2003/01/08 20:13:17 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Route::Descr;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use Strassen::Strasse;

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
    if (keys %args) {
	die "Invalid argument to outout method";
    }
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
	my @str = "Route von";
	push @str, $startname;
	push @str, $starthnr if defined $starthnr;
	if (defined $vianame) {
	    push @str, "über", $vianame;
	    push @str, $viahnr if defined $viahnr;
	}
	push @str, "bis", $zielname;
	push @str, $zielhnr if defined $zielhnr;
	$ret{Start} = $startname;
	$ret{Goal}  = $zielname;
	$ret{Title} = join(" ", @str);
    }

    my @lines;
    my($next_entf, $ges_entf_s, $next_winkel, $next_richtung);
    my $ges_entf = 0;
    for(my $i = 0; $i <= $#strnames; $i++) {
	my $strname;
	my $etappe_comment = '';
	my($entf, $winkel, $richtung)
	    = ($next_entf, $next_winkel, $next_richtung);
	($strname, $next_entf, $next_winkel, $next_richtung)
	    = @{$strnames[$i]};
	if ($i > 0) {
	    if (!$winkel) { $winkel = 0 }
	    $winkel = int($winkel/10)*10;
	    if ($winkel < 30) {
		$richtung = "";
	    } else {
		$richtung =
		    ($winkel <= 45 ? 'halb' : '') .
			($richtung eq 'l' ? 'links ' : 'rechts ') .
			    "($winkel°) " . Strasse::de_artikel($strname);
	    }
	    $ges_entf += $entf;
	    $ges_entf_s = sprintf "%.1f km", $ges_entf/1000;
	    $entf = sprintf "nach %.2f km", $entf/1000;

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
	my $entf = sprintf "nach %.2f km", $next_entf/1000;
	$ret{Footer} = [$entf, "", "angekommen!", $ges_entf_s];
    }

    \%ret;
}

1;

__END__
