# -*- perl -*-

#
# $Id: BBBikeGPSDialog.pm,v 1.10 2003/06/20 20:42:54 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002, 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeGPSDialog;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

use base qw(Tk::Toplevel);
Construct Tk::Widget 'BBBikeGPSDialog';

use vars qw($trkdir);
$trkdir = "/tmp/gpstracks";

if (!caller) {
    require FindBin;
    unshift @INC, "$FindBin::RealBin/../";
}

require GPS::GpsmanConn; # Can't use
use File::Basename;

sub Populate {
    my($w, $args) = @_;
    $w->title("GPS");
    Tk::grid($w->Button(-text => "Download trk",
			-command => [$w, 'download_trk']
		       ),
	     $w->Button(-text => "Download wpt",
			-command => [$w, 'download_wpt']
		       ));
    Tk::grid(my $lb = $w->Scrolled("Listbox", -selectmode => "multiple",
				   -scrollbars => "oe"),
	     -sticky => "news", -columnspan => 2);
    $w->Advertise(Listbox => $lb);
    Tk::grid($w->Button(-text => "Display selected",
			-command => [$w, 'display_selected'],
		       ),
	     -columnspan => 2, -sticky => "ew");
    $w->{CenterOn} = "none";
    {
	my $center_f;
	Tk::grid($center_f = $w->Frame,
		 -columnspan => 2, -sticky => "ew");
	$center_f->Label(-text => "Center:")->pack(-side => "left");
	$center_f->Radiobutton(-variable => \$w->{CenterOn},
			       -value => "none",
			       -text => "No")->pack(-side => "left");
	$center_f->Radiobutton(-variable => \$w->{CenterOn},
			       -value => "begin",
			       -text => "Begin")->pack(-side => "left");
	$center_f->Radiobutton(-variable => \$w->{CenterOn},
			       -value => "end",
			       -text => "End")->pack(-side => "left");
    }
    my $close_cmd = sub {
	my $cb = $w->cget(-closecommand);
	$cb->Call();
	$w->destroy if Tk::Exists($w);
    };
    Tk::grid($w->Button(-text => "Close",
			-command => $close_cmd,
		       ),
	     -columnspan => 2, -sticky => "ew");
    $w->protocol(WM_DELETE_WINDOW => $close_cmd);

    if (!-d $trkdir) {
	mkdir $trkdir, 0755;
	if (!-d $trkdir) {
	    die "Can't create $trkdir: $!";
	}
    }

    $w->afterIdle([$w, 'update_track_listing']);

    $w->ConfigSpecs
	(
	 # XXX -title => ['SELF', undef, undef, 'GPS'],
	 -canvas => ['PASSIVE'],
	 -transpose => ['PASSIVE'],
	 -closecommand => ['CALLBACK',undef,undef,undef],
	);
}

sub update_track_listing {
    my $w = shift;
    my @files = sort glob("$trkdir/*.trk $trkdir/*.wpt");
    my $lb = $w->Subwidget("Listbox");
    my %sel = map { ($lb->get($_) => 1) } $lb->curselection;
    $lb->delete(0, "end");
    $lb->insert("end", map { basename $_ } @files);
    for my $i (0 .. $#files) {
	if ($sel{$files[$i]}) {
	    $lb->selectionSet($i);
	}
    }
}

sub download_trk {
    my $w = shift;
#    $SIG{CHLD} = 'IGNORE';
#    if (fork == 0) {
	eval {
	    my $gpsconn = GPS::GpsmanConn->new(Verbose => 1);
	    my @t;
	    {
		local $^W;
		@t = $gpsconn->get_tracks;
	    }
	    die "No tracks" if (!@t);
	    $gpsconn->write_tracks(\@t, $trkdir, -filefmt => "%Y%M%D.trk");
	};
	if ($@) {
	    $w->gps_advice($@);
	    return;
#	    CORE::exit(1);
	}
	warn "OK, tracks downloaded\n";
#	CORE::exit(0);
#    } else {
#	$SIG{CHLD} = sub {
#	    waitpid(-1,1);
	    $w->update_track_listing;
#	};
#    }
}

sub download_wpt {
    my $w = shift;
#    $SIG{CHLD} = 'IGNORE';
#    if (fork == 0) {
	eval {
	    my $gpsconn = GPS::GpsmanConn->new(Verbose => 1);
	    my $w;
	    {
		local $^W;
		$w = $gpsconn->get_waypoints;
	    }
	    die "No waypoints" if (!$w);
	    $gpsconn->write_waypoints($w, "$trkdir/waypoints.wpt");
	};
	if ($@) {
	    $w->gps_advice($@);
	    return;
#	    CORE::exit(1);
	}
	warn "OK, waypoints downloaded\n";
#	CORE::exit(0);
#    } else {
#	$SIG{CHLD} = sub {
#	    waitpid(-1,1);
	    $w->update_track_listing;
#	};
#    }
}

# XXX change tagging to support "browse additional layers" in tkbabybike
sub display_selected {
    my $w = shift;
    require GPS::GpsmanData;
    require Karte;
    require Karte::Standard;
    require Karte::Polar;
    my $c = $w->cget(-canvas) or die "-canvas option is missing";
    my $transpose = $w->cget(-transpose) or die "-transpose option is missing";
    $c->delete("gps");
    my $lb = $w->Subwidget("Listbox");
    $c->MainWindow->Busy(-recurse => 1);
    eval {
	my $is_first = 1;
	for my $base (map { $lb->get($_) } $lb->curselection) {
	    my $file = $trkdir . "/" . $base;
	    my $gps = GPS::GpsmanData->new;
	    $gps->load($file);
	    $gps->convert_all("DDD");
	    if ($gps->Type eq GPS::GpsmanData::TYPE_WAYPOINT()) {
		foreach my $wpt (@{ $gps->Points }) {
		    my($cx,$cy) = $transpose->(map { int } $Karte::Polar::obj->map2standard($wpt->Longitude, $wpt->Latitude));
		    $c->createLine($cx,$cy,-width=>2, -fill => "blue",
				   -capstyle => "round", -tags => ["gps"]);
		}
	    } else {
		my @p = [];
		my $last_time;
		foreach my $wpt (@{ $gps->Points }) {
		    my($cx,$cy) = $transpose->(map { int } $Karte::Polar::obj->map2standard($wpt->Longitude, $wpt->Latitude));
		    my $time = $wpt->Comment_to_unixtime;
		    if (defined $last_time && $time-$last_time > 60) {
			push @p, [];
		    }
		    push @{$p[-1]}, $cx, $cy;
		    $last_time = $time;
		}
		foreach (@p) {
		    $c->createLine(@$_, -width => 2,
				   -fill => "black", -tags => ["gps"]);
		}
	    }

	    if ($is_first) {
		$is_first = 0;
		my $inx;
		if ($w->{CenterOn} eq 'begin') {
		    $inx = 0;
		} elsif ($w->{CenterOn} eq 'end') {
		    $inx = -1;
		}
		if (defined $inx) {
		    my ($cx,$cy) = ($gps->Points->[$inx]->Longitude,
				    $gps->Points->[$inx]->Latitude);
		    $c->see($transpose->(map { int } $Karte::Polar::obj->map2standard($cx, $cy)));
		}
	    }
	}
    };
    my $err = $@;
    $c->MainWindow->Unbusy;
    if ($err) {
	warn $err;
	$c->messageBox(-icon => "error", -message => $err);
    }
}

sub gps_advice {
    my($w, $err) = @_;
    $err .= <<EOF;

Check if
* The PDA is running runlevel 4 (System module)
* The GPS device is set to Garmin/9600 bps
* There is a cable between PDA and GPS device
* Maybe you have to wait a little
EOF
    warn $err;
    $w->messageBox(-icon => "error", -message => $err);
}

return 1 if caller;

require Tk;
my $mw = MainWindow->new;
$mw->withdraw;
$mw->BBBikeGPSDialog(-closecommand => sub { $mw->destroy });
Tk::MainLoop;

__END__
