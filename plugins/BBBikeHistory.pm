# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): History of BBBike locations
# Description (de): Historie der BBBike-Positionen

package BBBikeHistory;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use BBBikeUtil qw(bbbike_root);

# XXX make repeat time configurable
my $interval = 60*1000;
# XXX make configurable?
my $max_hist_entries = 100;

# elements of {lon, lat, desc}
our @history;
our $remember_first;
my $timer;
my $hist_file = $main::bbbike_configdir . '/bbbike_location_hist'; $main::bbbike_configdir=$main::bbbike_configdir if 0;
my $rev_geocoding;

sub register {
    my $pkg = __PACKAGE__;
    $BBBikePlugin::plugins{$pkg} = $pkg;
    load_history();
    add_button();
    start_timer();
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};
    remove_timer();
    remove_button();
    delete $BBBikePlugin::plugins{$pkg};
}

sub add_button {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $mmf = $main::top->Subwidget("ModeMenuPluginFrame");
    return unless defined $mf;

    my $b;
    $b = $mf->Label
        (-text => "Hist",
        );
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_but');
    $main::balloon->attach($b, -msg => 'History')
        if $main::balloon;

    BBBikePlugin::place_menu_button
            ($mmf,
             [
	      [Button => 'Show history',
	       -command => sub {
		   show_history_box();
	       },
	      ],
	      '-',
              [Button => "Delete this menu",
               -command => sub {
                   $mmf->after(100, sub {
                                   unregister();
                               });
               }],
             ],
             $b,
	     __PACKAGE__."_menu",
	     -title => 'History',
            );
}

sub remove_button {
    my $pkg = __PACKAGE__;
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $subw = $mf->Subwidget($pkg . '_but');
    if (Tk::Exists($subw)) { $subw->destroy }
    BBBikePlugin::remove_menu_button(__PACKAGE__."_menu");
}

sub maybe_push_current_location {
    my($lon, $lat) = main::get_current_center_as_wgs84();
    my $lon_lat = join(",",$lon,$lat);
    if (!$remember_first) {
	$remember_first = $lon_lat;
    } elsif ($remember_first eq $lon_lat) {
	if (!@history || join(",",@{$history[-1]}{qw(lon lat)}) ne $lon_lat) { # XXX do inexact match --- delta up to 50/100/200m (?) won't create a new history entry
	    $rev_geocoding ||= do {
		local @INC = (@INC, bbbike_root."/miscsrc");
		require ReverseGeocoding;
		ReverseGeocoding->new;
	    };
	    my $road = $rev_geocoding->find_closest("$lon,$lat", "road");
	    my $area = $rev_geocoding->find_closest("$lon,$lat", "area");
	    my $desc = join(", ", grep { defined } $road, $area);
	    $desc =~ s{\t}{ }g; # should not happen, but play safe
	    undef $desc if $desc eq '';
	    # XXX for non-Berlin datadirs that information should also be added
	    push @history, {lon => $lon, lat => $lat, desc => $desc};
	    dump_history();
	    refresh_history_box();
	}
    } else {
	$remember_first = $lon_lat; # for next check
    }
}

sub start_timer {
    $timer = $main::top->repeat
	($interval, sub { maybe_push_current_location() });
}

sub remove_timer {
    $timer->cancel;
    undef $timer;
}

sub load_history {
    if (open my $fh, '<', $hist_file) {
	my @new_history;
	while(<$fh>) {
	    chomp;
	    my($lon, $lat, $desc) = split /\t/, $_;
	    push @new_history, {lon => $lon, lat => $lat, desc => $desc};
	}
	@history = @new_history;
    } else {
	main::status_message("Cannot open $hist_file: $!", 'info');
    }
}

sub dump_history {
    if (@history > $max_hist_entries) {
	@history = @history[-$max_hist_entries..-1];
    }
    open my $ofh, '>', "$hist_file~"
	or main::status_message("Cannot write to $hist_file~: $!", 'die');
    for (@history) {
	print $ofh join("\t", @{$_}{qw(lon lat desc)}), "\n";
    }
    close $ofh
	or main::status_message("Error while writing $hist_file~: $!", 'die');
    rename "$hist_file~", $hist_file
	or main::status_message("Error while renaming $hist_file~ to $hist_file: $!", 'die');
    # XXX maybe count errors, and if there are too many, stop
    # automatic dumping
}

{
    my $lb;
    my @inx2pos;

    sub refresh_history_box {
	return if !$lb || !Tk::Exists($lb);

	$lb->delete(0,'end');
	@inx2pos = ();
	for (reverse @history) {
	    my($lon,$lat,$desc) = @{$_}{qw(lon lat desc)};
	    my $title = defined $desc ? $desc : "$lon/$lat";
	    $lb->insert('end', $title);
	    push @inx2pos, {lon=>$lon, lat=>$lat};
	}
    }

    sub show_history_box {
	my $t = main::redisplay_top($main::top, __PACKAGE__.'_lb', -title => 'History');
	if ($t) {
	    $lb = $t->Scrolled('Listbox', -width => 40, -height => 20)->pack(qw(-fill both -expand 1));
	    $lb->bind('<1>' => sub {
			  my($inx) = $lb->curselection;
			  if (defined $inx) {
			      my $lon_lat = $inx2pos[$inx];
			      require Karte::Polar;
			      my($sx,$sy) = $Karte::Polar::obj->map2standard(@$lon_lat{qw(lon lat)}); $Karte::Polar::obj=$Karte::Polar::obj if 0;
			      my($x,$y) = main::transpose($sx,$sy);
			      main::mark_point(-dont_mark => 1, -x => $x, -y => $y);
			  }
		      });
	    $t->Advertise(Listbox => $lb);
	    $t->Button(-text => 'Close', -command => sub { $t->destroy })->pack(qw(-fill x));
	} else {
	    $lb = $main::toplevel{__PACKAGE__.'_lb'}->Subwidget('Listbox'); %main::toplevel = $main::toplevel if 0;
	}
	refresh_history_box();
    }
}

1;

__END__
