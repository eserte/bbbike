# -*- perl -*-

#
# $Id: BBBikeStats.pm,v 1.7 2003/05/10 19:31:24 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# XXX schön, aber ein großes Problem gibt es noch: wenn ein neuer Punkt
# in das Netz eingefügt wird, dann wird er in den neuen Nets *nicht*
# berücksichtigt. Lösung? Evtl. AddNet in get_net analysieren und
# die zusätzlichen Punkte bei Bedarf einfügen. Sollte eigentlich gehen.

package BBBikeStats;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use Strassen::Util;
use BBBikeUtil;

BEGIN {
    if (!eval '
use Msg;
1;
') {
	warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

sub calculate {
    my($route, $dataset, %args) = @_;
    my $res = {};
    $res->{Length} = $route->len;
    my(@path) = $route->path_s_list;

    my(%net, %len, %coords);

    $net{Quality}    = $dataset->get_net("str","q","all",-nettype => "cat");
    $net{Handicap}   = $dataset->get_net("str","h","all",-nettype => "cat");
    $net{Cyclepaths} = $dataset->get_net("str","rw","all",-nettype => "cat",
					 -makenetargs => [-obeydir => 1]);
    $net{Category}   = $dataset->get_net("str","s","all",-nettype => "cat");

    for my $i (0 .. $#path-1) {
	my $hop_len = Strassen::Util::strecke_s($path[$i], $path[$i+1]);

	for my $def ([Quality => "Q0"],
		     [Handicap => "q0"],
		     [Cyclepaths => "RW0"],
		     [Category => "N"],#XXX better solution? use unknown category?
		    ) {
	    my($member, $fallback) = @$def;

	    my $cat = $net{$member}{Net}{$path[$i]}{$path[$i+1]} || $fallback;
	    $len{$member}->{$cat} += $hop_len;
	    push @{ $coords{$member}->{$cat} }, [$path[$i], $path[$i+1]];
	}
    }

    # XXX more: ampeln, tragen, steigungen, höhen etc.

    foreach my $member (qw(Quality Handicap Cyclepaths Category)) {
	$res->{$member} = $len{$member};
	while(my($k,$v) = each %{ $res->{$member} }) {
	    $res->{$member . "%"}{$k} = (($v||0)/$res->{Length})*100;
	}
	$res->{$member . "Coords"} = $coords{$member};
    }

    $res;
}

# XXX split into widget creation and update data subroutine
#XXX maybe use a Scrolled Pane?
sub tk_display_result {
    my($top, $res, %args) = @_;
    if (!$args{-markcommand}) {
	$args{-markcommand} = sub {
	    $top->messageBox(-message => "No mark command defined");
	};
    }
    if (!defined $args{-chart}) {
	$args{-chart} = 1;
    }

    my $t;
    if ($args{-reusewindow} &&
	Tk::Exists($t = $top->Subwidget("Statistics"))) {
	$_->destroy for ($t->children);
    } else {
	$t = $top->Toplevel(-title => M("Statistik"));
	$top->Advertise("Statistics" => $t);
	# make transient?

	$t->OnDestroy(sub {
			  if ($t->{Photos}) {
			      foreach (@{ $t->{Photos} }) {
				  $_->delete;
			      }
			  }
			  delete $t->{Photos};
		      });

	(my $path = $t->PathName) =~ s/^.//;
	$t->optionAdd("*$path*Button*Pad", 0);
	$t->optionAdd("*$path*Button*anchor", "w"); # for the text labels
	$t->optionAdd("*$path*Label*anchor", "e"); # for the numbers
    }

    # XXX!!!
    my $category_attrib = \%main::category_attrib;
    my %font = %main::font;
    my %category_color = %main::category_color;

    my %grid_row;

    Tk::grid($t->Label(-text => M("Länge").":", -font => $font{"bold"}),
	     $t->Label(-text => sprintf "%.1f km", $res->{Length}/1000),
	     -sticky => "w");

    Tk::grid($t->Frame(-height => 1, -background => "black"),
	     -sticky => "ew", -columnspan => 10);

    Tk::grid($t->Label(-text => M("Straßenqualität"), -font => $font{"bold"}),
	     -sticky => "w", -columnspan => 3);
    $grid_row{"Quality1"} = ($t->gridSize)[1]-1;
    for my $cat (sort grep { /^Q\d$/ } keys %$category_attrib) {
	Tk::grid($t->Button(-text => $category_attrib->{$cat}[0],
			    -bg => $category_color{$cat}||"white",
			    -fg => _readable_fg($t,$category_color{$cat}),
			    -command => [$args{-markcommand}, $res->{QualityCoords}{$cat}]),
		 $t->Label(-text => sprintf "%.1f km", ($res->{Quality}{$cat}||0)/1000),
		 $t->Label(-text => sprintf "%d%%", ($res->{"Quality%"}{$cat}||0)),
		 -sticky => "we");
    }
    $grid_row{"Quality2"} = ($t->gridSize)[1]-1;

    Tk::grid($t->Frame(-height => 1, -background => "black"),
	     -sticky => "ew", -columnspan => 10);

    Tk::grid($t->Label(-text => M("Sonstige Behinderungen"), -font => $font{"bold"}),
	     -sticky => "w", -columnspan => 3);
    $grid_row{"Handicap1"} = ($t->gridSize)[1]-1;
    for my $cat (sort grep { /^q\d$/ } keys %$category_attrib) {
	Tk::grid($t->Button(-text => $category_attrib->{$cat}[0],
			    -bg => $category_color{$cat}||"white",
			    -fg => _readable_fg($t,$category_color{$cat}),
			    -command => [$args{-markcommand}, $res->{HandicapCoords}{$cat}]),
		 $t->Label(-text => sprintf "%.1f km", ($res->{Handicap}{$cat}||0)/1000),
		 $t->Label(-text => sprintf "%d%%", ($res->{"Handicap%"}{$cat}||0)),
		 -sticky => "we");
    }
    $grid_row{"Handicap2"} = ($t->gridSize)[1]-1;

    Tk::grid($t->Frame(-height => 1, -background => "black"),
	     -sticky => "ew", -columnspan => 10);

    Tk::grid($t->Label(-text => M("Radwege"), -font => $font{"bold"}),
	     -sticky => "w", -columnspan => 3);
    $grid_row{"Cyclepaths1"} = ($t->gridSize)[1]-1;
    for my $cat (sort grep { /^RW\d$/ } keys %$category_attrib) {
	Tk::grid($t->Button(-text => $category_attrib->{$cat}[0],
			    -bg => $category_color{$cat}||"white",
			    -fg => _readable_fg($t,$category_color{$cat}),
			    -command => [$args{-markcommand}, $res->{CyclepathsCoords}{$cat}]),
		 $t->Label(-text => sprintf "%.1f km", ($res->{Cyclepaths}{$cat}||0)/1000),
		 $t->Label(-text => sprintf "%d%%", ($res->{"Cyclepaths%"}{$cat}||0)),
		 -sticky => "we");
    }
    $grid_row{"Cyclepaths2"} = ($t->gridSize)[1]-1;

    Tk::grid($t->Frame(-height => 1, -background => "black"),
	     -sticky => "ew", -columnspan => 10);

    Tk::grid($t->Label(-text => M("Straßenkategorien"), -font => $font{"bold"}),
	     -sticky => "w", -columnspan => 3);
    $grid_row{"Category1"} = ($t->gridSize)[1]-1;
    for my $cat (@main::strcat_order) {
	Tk::grid($t->Button(-text => $category_attrib->{$cat}[0],
			    -bg => $category_color{$cat}||"white",
			    -fg => _readable_fg($t,$category_color{$cat}),
			    -command => [$args{-markcommand}, $res->{CategoryCoords}{$cat}]),
		 $t->Label(-text => sprintf "%.1f km", ($res->{Category}{$cat}||0)/1000),
		 $t->Label(-text => sprintf "%d%%", ($res->{"Category%"}{$cat}||0)),
		 -sticky => "we");
    }
    $grid_row{"Category2"} = ($t->gridSize)[1]-1;

    if ($args{-updatecommand}) {
	Tk::grid($t->Frame(-height => 1, -background => "black"),
		 -sticky => "ew", -columnspan => 10);
	Tk::grid($t->Button(-text => M("Update"),
			    -anchor => "c",
			    -font => $font{"bold"},
			    -command => $args{-updatecommand},
			   ), -sticky => "ew", -columnspan => 10);
    }

    $t->update;

    if ($args{-chart} &&
	eval { require Chart::ThreeD::Pie;
	       require GD::Convert;
	       1;
	   }) {
	for my $member (qw(Cyclepaths Handicap Quality Category)) {
	    my $pie_width = 300; # XXX don't hardcode
	    my $pie_height;
	    my(@bbox, $pie);
	    @bbox = $t->gridBbox(0, $grid_row{$member."1"},
				 0, $grid_row{$member."2"});
	    $pie_height = $bbox[3];
	    $pie = Chart::ThreeD::Pie->new($pie_width,$pie_height,"");
	    $pie->transparent(1);
	    $pie->fgcolor('#000000');
	    $pie->bgcolor(_rgb($t,$t->cget('-background')));
	    $pie->thickness(20);
	    # XXX maximum radius is 100, otherwise: core dumps!
	    $pie->radius(min($pie_width-50, $pie_height-$pie->thickness-40, 100));

	    while(my($cat,$v) = each %{ $res->{$member} }) {
		$pie->add($v, _rgb($t,$category_color{$cat}) || "#ff0000", $category_attrib->{$cat}[0]);
	    }
	    my $xpm_data = $pie->plot->xpm;
#open(PNG,">/tmp/bla.png")or die;print PNG $pie->plot->png;close PNG;#XXX
	    my $xpm = $t->Pixmap(-data => $xpm_data);
	    push @{ $t->{Photos} }, $xpm;
	    $t->Label(-image => $xpm)->grid
		(-row => $grid_row{$member."1"}, -column => 3,
		 -rowspan => $grid_row{$member."2"}-$grid_row{$member."1"}+1);
	}
    } else {
	warn $@;
    }
}

sub _rgb {
    my($t,$color) = @_;
    sprintf("#%02x%02x%02x", map { $_/0x100 } $t->rgb($color||"white"));
}

sub _readable_fg {
    my($t,$color) = @_;
    my($r,$g,$b) = $t->rgb($color||"white");
    max($r,$g,$b)>0xa000 ? "black" : "white"; # XXX better formula???
}

1;

__END__

Gesamtlänge des Straßennetzes:

perl -Ilib -MStrassen::Util -MStrassen -MObject::Iterate=iterate -e '$s=Strassen->new("strassen");iterate { for $i (0 .. $#{$_->[Strassen::COORDS]}-1) { $len += Strassen::Util::strecke_s($_->[Strassen::COORDS][$i], $_->[Strassen::COORDS][$i+1])} } $s; warn $len/1000'
