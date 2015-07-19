# -*- perl -*-

#
# $Id: BBBikeGPSDialog.pm,v 1.15 2008/07/05 17:24:50 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002, 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

package BBBikeGPSDialog;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);

use base qw(Tk::Toplevel);
Construct Tk::Widget 'BBBikeGPSDialog';

use vars qw($trkdir);
if (eval { require File::Spec; 1 }) {
    $trkdir = File::Spec->tmpdir . "/gpstracks";
} else {
    $trkdir = "/tmp/gpstracks";
}

if (eval { require File::Glob; 1 }) {
    *my_glob = \&File::Glob::bsd_glob;
} else {
    *my_glob = sub { glob(@_) };
}

if (!caller) {
    require FindBin;
    unshift @INC, "$FindBin::RealBin/../",
                  "$FindBin::RealBin/../..",
                  $FindBin::RealBin;
}

require GPS::GpsmanConn; # Can't use
use File::Basename;

sub Populate {
    my($w, $args) = @_;
    $w->title("GPS");
    Tk::grid(my $d_trk = $w->Button(-text => "Download trk",
				    -command => [$w, 'download_trk']
				   ),
	     my $d_wpt = $w->Button(-text => "Download wpt",
				    -command => [$w, 'download_wpt']
				   ));
    Tk::grid(my $lb = $w->Scrolled("Listbox", -selectmode => "multiple",
				   -scrollbars => "oe"),
	     -sticky => "news", -columnspan => 2);

    Tk::grid(my $display_sel = $w->Button(-text => "Display selected",
					  -state => "disabled",
					  -command => [$w, 'display_selected'],
					 ),
	     -columnspan => 2, -sticky => "ew");
    $w->{CenterOn} = "none";
    my($rb_no, $rb_begin, $rb_end);
    {
	my $center_f;
	Tk::grid($center_f = $w->Frame,
		 -columnspan => 2, -sticky => "ew");
	$center_f->Label(-text => "Center:")->pack(-side => "left");
	$rb_no =
	    $center_f->Radiobutton(-variable => \$w->{CenterOn},
				   -value => "none",
				   -state => "disabled",
				   -text => "No")->pack(-side => "left");
	$rb_begin =
	    $center_f->Radiobutton(-variable => \$w->{CenterOn},
				   -value => "begin",
				   -state => "disabled",
				   -text => "Begin")->pack(-side => "left");
	$rb_end =
	    $center_f->Radiobutton(-variable => \$w->{CenterOn},
				   -value => "end",
				   -state => "disabled",
				   -text => "End")->pack(-side => "left");
    }
    my $close_cmd = sub {
	my $cb = $w->cget(-closecommand);
	$cb->Call() if $cb;
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

    $w->Advertise(DownloadTrk => $d_trk);
    $w->Advertise(DownloadWpt => $d_wpt);
    $w->Advertise(Listbox => $lb);
    $w->Advertise(DisplaySelected => $display_sel);
    $w->Advertise(RBNo    => $rb_no);
    $w->Advertise(RBBegin => $rb_begin);
    $w->Advertise(RBEnd   => $rb_end);

    $w->afterIdle([$w, 'update_track_listing']);

    $w->ConfigSpecs
	(
	 # XXX -title => ['SELF', undef, undef, 'GPS'],
	 -canvas       => ['METHOD'],
	 -transpose    => ['PASSIVE'],
	 -closecommand => ['CALLBACK',undef,undef,undef],
	 -postdrawcommand => ['CALLBACK'],
	 -fork         => ['PASSIVE'],
	);
}

sub canvas {
    my $w = shift;
    if (@_) {
	my $val = shift;
	$w->{Configure}{-canvas} = $val;
	if ($val) {
	    for my $sw (qw(RBNo RBBegin RBEnd DisplaySelected)) {
		$w->Subwidget($sw)->configure(-state => $val ? "normal" : "disabled");
	    }
	}
    }
    $w->{Configure}{-canvas};
}

sub update_track_listing {
    my $w = shift;
    my @files = sort { $a cmp $b } my_glob("$trkdir/*.trk", "$trkdir/*.wpt");
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
    my $do_fork = $w->cget("-fork");
    if ($do_fork) {
	$w->button_status(0);
	$SIG{CHLD} = 'IGNORE';
	if (fork == 0) {
	    my $ret = $w->do_download_trk;
	    CORE::exit(!$ret);
	} else {
	    $SIG{CHLD} = sub {
		waitpid(-1,1);
		if ($? != 0) {
		    $w->gps_advice("");
		} else {
		    $w->update_track_listing;
		}
		$w->button_status(1);
	    };
	}
    } else {
	my $ret = $w->do_download_trk;
	if (!$ret) {
	    $w->gps_advice($@);
	} else {
	    $w->update_track_listing;
	}
    }
}

sub do_download_trk {
    my $w = shift;
    eval {
	my $gpsconn = gpsconn();
	my @t;
	{
	    local $^W;
	    @t = $gpsconn->get_tracks;
	}
	die "No tracks" if (!@t);
	$gpsconn->write_tracks(\@t, $trkdir, -filefmt => "%Y%M%D.trk");
    };
    if ($@) {
	warn $@;
	return 0;
    }
    warn "OK, tracks downloaded\n";
    return 1;
}

sub download_wpt {
    my $w = shift;
    my $do_fork = $w->cget("-fork");
    if ($do_fork) {
	$w->button_status(0);
	$SIG{CHLD} = 'IGNORE';
	if (fork == 0) {
	    my $ret = $w->do_download_wpt;
	    CORE::exit(!$ret);
	} else {
	    $SIG{CHLD} = sub {
		waitpid(-1,1);
		if ($? != 0) {
		    $w->gps_advice("");
		} else {
		    $w->update_track_listing;
		}
		$w->button_status(1);
	    };
	}
    } else {
	my $ret = $w->do_download_wpt;
	if (!$ret) {
	    $w->gps_advice($@);
	} else {
	    $w->update_track_listing;
	}
    }
}

sub do_download_wpt {
    my $w = shift;
	eval {
	    my $gpsconn = gpsconn();
	    my $w;
	    {
		local $^W;
		$w = $gpsconn->get_waypoints;
	    }
	    die "No waypoints" if (!$w);
	    $gpsconn->write_waypoints($w, "$trkdir/waypoints.wpt");
	};
    if ($@) {
	warn $@;
	return 0;
    }
    warn "OK, waypoints downloaded\n";
    return 1;
}

sub gpsconn {
    my $dev = $main::gps_device || undef;
    my $gpsconn = GPS::GpsmanConn->new(Verbose => 1, Port => $dev);
    $gpsconn;
}

sub button_status {
    my($w, $val) = @_;
    for my $sw (qw(DownloadTrk DownloadWpt)) {
	$w->Subwidget($sw)->configure(-state => $val ? "normal" : "disabled");
    }
}

# XXX change tagging to support "browse additional layers" in tkbabybike
sub display_selected {
    my $w = shift;
    require GPS::GpsmanData;
    require Karte;
    require Karte::Standard;
    require Karte::Polar;
    my $c = $w->cget("-canvas") or die "-canvas option is missing";
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
		    my $time = $wpt->Comment_to_unixtime($gps);
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
		    require Tk::CanvasUtil; # for "see"
		    my ($cx,$cy) = ($gps->Points->[$inx]->Longitude,
				    $gps->Points->[$inx]->Latitude);
		    $c->see($transpose->(map { int } $Karte::Polar::obj->map2standard($cx, $cy)));
		}
	    }
	}

	my $cb = $w->cget(-postdrawcommand);
	$cb->Call() if $cb;
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
$mw->optionAdd("*font", "5x7"); # XXX for handhelds, do not hardcode!
my($canvas, $transpose, $postdrawcommand);
if (0) {
    $mw->withdraw;
} else {
    require EmptyCanvasMap;
    $canvas = $mw->EmptyCanvasMap->pack(-fill => "both", -expand => 1);
    $transpose = $canvas->get_transpose;
    $postdrawcommand = sub { $canvas->adjust_scrollregion };
}
$mw->BBBikeGPSDialog(-fork => ($^O ne 'MSWin32'),
		     -canvas => $canvas,
		     -transpose => $transpose,
		     -postdrawcommand => $postdrawcommand,
		     -closecommand => sub { $mw->destroy },
		    );
#$mw->WidgetDump;
Tk::MainLoop;

__END__
