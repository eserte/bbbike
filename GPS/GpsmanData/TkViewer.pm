# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2015,2016,2017,2019,2023,2025 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

package GPS::GpsmanData::TkViewer;
use strict;
use vars qw($VERSION);
$VERSION = '1.10';

use FindBin;

use File::Basename qw(dirname);
use File::Glob qw(bsd_glob);

use BBBikeEdit;
use BBBikeUtil;
use GPS::GpsmanData::Any;
use GPS::GpsmanData::Tk;
use Karte::Polar;
use Tk::PathEntry;

# These are global and intentionally shared within a process.
our($gps_data_viewer_file, $last_loaded_gps_data_viewer_file, $gps_data_dir, $include_associated_wpt_file, $tk_stats);

sub gps_data_viewer {
    my($class, $parent, %opts) = @_;

    my $gps_file = delete $opts{-gpsfile};
    my $title    = delete $opts{-title} || 'GPS data viewer';
    my $geometry = delete $opts{-geometry} || '1065x400';
    my $stats_args_cb = delete $opts{-statsargscb};

    die "Unhandled arguments: " . join(" ", %opts) if %opts;

    my $t = $parent->Toplevel(-title => $title);
    $t->geometry($geometry);

    my $gps_view;
    my $gps;

    $gps_data_dir = "$FindBin::RealBin/misc/gps_data" if !defined $gps_data_dir;
    $gps_data_viewer_file = $gps_data_dir             if !defined $gps_data_viewer_file;
    $gps_data_viewer_file = $FindBin::RealBin         if !defined $gps_data_viewer_file;

    my $show_file = sub {
	if (defined $gps_data_viewer_file) {
	    #XXX do it as late as possible, before the first edit operation: BBBikeEdit::ask_for_co($main::top, $gps_data_viewer_file);
	    $gps = GPS::GpsmanData::Any->load($gps_data_viewer_file, -editable => 1);
	    my $wpt_gps;
	    if ($include_associated_wpt_file && $gps_data_viewer_file =~ m{\.trk$}) { # XXX what about .gpx files?
		(my $wpt_file = $gps_data_viewer_file) =~ s{\.trk$}{\.wpt}; # XXX what about .gpx waypoint files?
		if (-r $wpt_file) {
		    $wpt_gps = GPS::GpsmanData->new;
		    $wpt_gps->load($wpt_file);
		}
	    }
	    my $keep_list_position = defined $last_loaded_gps_data_viewer_file && $last_loaded_gps_data_viewer_file eq $gps_data_viewer_file;
	    $gps_view->associate_object($gps, $wpt_gps, -keeplistposition => $keep_list_position);
	    $last_loaded_gps_data_viewer_file = $gps_data_viewer_file;
	}
    };
    my $unplot_file = sub {
	if ($BBBikeEdit::recent_gps_point_layer) {
	    main::delete_layer($BBBikeEdit::recent_gps_point_layer);
	    undef $BBBikeEdit::recent_gps_point_layer;
	}
	if ($BBBikeEdit::recent_gps_street_layer) {
	    main::delete_layer($BBBikeEdit::recent_gps_street_layer);
	    undef $BBBikeEdit::recent_gps_street_layer;
	}
    };
    my $maybe_update_stats = sub {
	if ($tk_stats && Tk::Exists($tk_stats)) {
	    $tk_stats->update($gps, $stats_args_cb);
	}
    };
    my $show_and_plot_file = sub {
	if (defined $gps_data_viewer_file) {
	    $show_file->();
	    $unplot_file->();
	    BBBikeEdit::edit_gps_track($gps_data_viewer_file);
	    if (defined $BBBikeEdit::recent_gps_street_layer) {
		main::mark_layer($BBBikeEdit::recent_gps_street_layer);
	    }
	    $maybe_update_stats->();
	}
    };
    my $prev_or_next_file = sub ($) {
	my $inc = shift;
	return if !defined $gps_data_viewer_file;

	if (-d $gps_data_viewer_file) {
	    # special handling for directories: "<" shows first file, ">" last file in directory
	    my $use_inx = $inc < 0 ? 0 : -1;
	    my $file = (bsd_glob "$gps_data_viewer_file/*.trk")[$use_inx];
	    if (defined $file) {
		$gps_data_viewer_file = $file;
		$show_and_plot_file->();
	    }
	    return;
	}

	my $dir = dirname $gps_data_viewer_file;
	my @files = grep { /\.trk$/ } bsd_glob "$dir/*"; # XXX what about .gpx files?
	return if !@files;
	for(my $i = 0; $i<=$#files; $i++) {
	    if ($gps_data_viewer_file eq $files[$i]) {
		if ($i+$inc >= 0 && $i+$inc <= $#files) {
		    $gps_data_viewer_file = $files[$i+$inc];
		    $show_and_plot_file->();
		} # else first or last file
		return;
	    }
	}
    };
    
    {
	my $f = $t->Frame->pack(qw(-fill x));
	$f->Label(-text => "File:")->pack(qw(-side left));
	my $pe =
	    $f->PathEntry
		(-textvariable => \$gps_data_viewer_file,
		 -width => BBBikeUtil::max(length($gps_data_viewer_file), 40),
		 -height => 20,
		)->pack(-fill => "x", -expand => 1, -side => "left");
	$pe->focus;
	$f->Button(-text => '<',
		   -padx => 0, -pady => 0,
		   -command => sub {
		       $prev_or_next_file->(-1);
		   })->pack(-side => 'left');
	$f->Button(-text => '>',
		   -padx => 0, -pady => 0,
		   -command => sub {
		       $prev_or_next_file->(+1);
		   })->pack(-side => 'left');
	$f->Checkbutton(-text => 'Inc .wpt',
			-variable => \$include_associated_wpt_file,
		       )->pack(-side => 'left');
	my $showb = 
	    $f->Button(-text => "Show",
		       -command => sub {
			   $show_file->();
		       }
		      )->pack(-side => "left");
	my $plotandshowb =
	    $f->Button(-text => "Show & Plot",
		       -command => sub {
			   $show_and_plot_file->();
		       }
		      )->pack(-side => "left");
	$f->Button(-text => 'Unplot',
		   -command => sub {
		       $unplot_file->();
		   }
		  )->pack(-side => 'left');
	$pe->configure(-selectcmd => sub {
			   $plotandshowb->focus;
		       });
    }

    my $user_trkattrs;
    my $vehicles_to_brands;
    my $gps_devices;
    if (-r "$gps_data_dir/trkattrs.yml" && eval { require BBBikeYAML; 1 }) {
	$user_trkattrs = BBBikeYAML::LoadFile("$gps_data_dir/trkattrs.yml");
	{
	    my $items = $user_trkattrs->{'srt:brand'} || {};
	    for my $vehicle (keys %$items) {
		my @brands = sort { $items->{$vehicle}->{$b} <=> $items->{$vehicle}->{$a} } keys %{ $items->{$vehicle} };
		$vehicles_to_brands->{$vehicle} = \@brands;
	    }
	}
	{
	    my $items = $user_trkattrs->{'srt:device'} || {};
	    $gps_devices = [ sort { $items->{$b} <=> $items->{$a} } keys %$items ];
	}
    } else {
	if (-r "$gps_data_dir/vehicles_brands.yml" && eval { require BBBikeYAML; 1 }) {
	    $vehicles_to_brands = BBBikeYAML::LoadFile("$gps_data_dir/vehicles_brands.yml");
	}
	if (-r "$gps_data_dir/gps_devices.yml" && eval { require BBBikeYAML; 1 }) {
	    $gps_devices = BBBikeYAML::LoadFile("$gps_data_dir/gps_devices.yml");
	}
    }

    $gps_view = $t->GpsmanData(-command => sub {
				   my(%args) = @_;
				   my $wpt = $args{-wpt};
				   if ($wpt) {
				       my($x,$y) = $Karte::Polar::obj->map2standard($wpt->Longitude, $wpt->Latitude);
				       main::mark_point(-coords => [[[ main::transpose($x,$y) ]]],
							-clever_center => 1,
							-inactive => 1,
						       );
				   }
			       },
			       -selectforeground => 'black',
			       -selectbackground => 'green',
			       -velocity => 'per_vehicle',
			       -vehiclestobrands => $vehicles_to_brands,
			       -gpsdevices => $gps_devices,
			      )->pack(qw(-fill both -expand 1));

    {
	my $f = $t->Frame->pack(qw(-fill x));
	if (0) {
	$f->Button(-text => "Select premature points",
		   -command => sub {
		       require GPS::GpsmanData::Analyzer;
		       my $anlzr = GPS::GpsmanData::Analyzer->new($gps);
		       my @wpts = $anlzr->find_premature_samples;
		       if (@wpts) {
			   $gps_view->select_items(grep { defined $_ } $gps_view->find_items_by_wpts(@wpts));
			   # XXX this is bad: dialog is modal and it's not possible to view all the selection
			   # XXX also, at least LongDialog should be used here
			   my $yn = $t->messageBox(-message => "Remove selected " . scalar(@wpts) . " item(s)?",
						   -type => "YesNo");
			   if (lc $yn eq 'yes') {
			       my $edit = GPS::GpsmanData::DirectEdit->new($gps);
			       my @lines = grep { defined $_ } map { $gps->LineInfo->get_line_by_wpt($_) } @wpts;
			       my @operations = $edit->remove_lines(\@lines, -dryrun => 1);
			       # XXX very bad formatting, maybe use a custom DialogBox here?
			       my $yn = $t->messageBox(-message => "Are you sure?\n" . join("\n", map { join " ", @$_ } @operations),
						       -type => "YesNo");
			       if (lc $yn eq 'yes') {
				   $edit->run_operations(\@operations);
				   $gps_view->reload;
				   my @operations = $edit->remove_empty_track_segments(-dryrun => 1);
				   if (@operations) {
				       my $yn = $t->messageBox(-message => "Remove empty track segments?\n" . join("\n", map { join " ", @$_ } @operations),
							       -type => "YesNo");
				       if (lc $yn eq 'yes') {
					   $edit->run_operations(\@operations);
					   $gps_view->reload;
				       }
				   }
			       }
			   }
		       }
		   })->pack(-side => "left");
        }
	$f->Button(-text => 'Select max. velocity',
		   -command => sub {
		       my $item = $gps_view->find_item_with_max_velocity;
		       if (defined $item) {
			   $gps_view->show_item($item);
		       } else {
			   $t->messageBox(-message => 'No item with maximum velocity found', -type => 'Ok');
		       }
		   })->pack(-side => 'left');
	$f->Button(-text => "Set accuracy for selection",
		   -command => sub {
		       my @sel_items = $gps_view->get_selected_items;
		       my @wpts = grep { defined } map { $gps_view->wpt_by_item($_) } @sel_items;
		       my $last_accuracy;
		       for (@wpts) {
			   if (!defined $last_accuracy) {
			       $last_accuracy = $_->Accuracy;
			   } elsif ($last_accuracy != $_->Accuracy) {
			       my $yn = $t->messageBox(-message => "Differing accuracies in selected waypoints. Proceed nevertheless?",
						       -type => "YesNo");
			       return if (lc $yn ne 'yes');
			   }
		       }
		       require Tk::DialogBox;
		       my $dlg = $t->DialogBox(-title => "Accuracy", -buttons => ["OK", "Cancel"]);
		       $dlg->add("Label", -text => "Set accuracy to:")->pack;
		       my $new_accuracy = $last_accuracy;
		       $dlg->add("Radiobutton", -value => 0, -text => "!", -variable => \$new_accuracy)->pack;
		       $dlg->add("Radiobutton", -value => 1, -text => "~", -variable => \$new_accuracy)->pack;
		       $dlg->add("Radiobutton", -value => 2, -text => "~~", -variable => \$new_accuracy)->pack;
		       my $answer = $dlg->Show;
		       return if ($answer ne 'OK');
		       return if $new_accuracy == $last_accuracy;
		       my $edit = GPS::GpsmanData::DirectEdit->new($gps);
		       my @lines = grep { defined $_ } map { $gps->LineInfo->get_line_by_wpt($_) } @wpts;
		       $edit->set_accuracies(\@lines, $new_accuracy);
		       $gps_view->reload;
		   })->pack(-side => "left");
	$f->Button(-text => 'Mark velocity jumps',
		   -command => sub {
		       require GPS::GpsmanData::Analyzer;
		       my $anlzr = GPS::GpsmanData::Analyzer->new($gps);
		       my @wpt_defs = $anlzr->find_velocity_jumps;
		       if (@wpt_defs) {
			   $gps_view->mark_items('bg_palered', grep { defined $_ } $gps_view->find_items_by_wpts(map { $_->{wpt} } @wpt_defs));
		       }
		   })->pack(-side => 'left');
	$f->Button(-text => 'Statistics',
		   -command => sub {
		       if (!$tk_stats || !Tk::Exists($tk_stats)) {
			   $tk_stats = $t->GpsmanDataStats;
		       }
		       $maybe_update_stats->();
		       $tk_stats->raise;
		   })->pack(-side => 'right');
    }

    if (defined $gps_file) {
	$gps_data_viewer_file = $gps_file;
	$show_and_plot_file->();
    }

    $t;
}

{
    package GPS::GpsmanData::TkViewer::Stats;
    use base qw(Tk::Toplevel);
    Construct Tk::Widget 'GpsmanDataStats';

    sub Populate {
	my($w, $args) = @_;
	$args->{'-title'} = 'GPS data statistics' if !exists $args->{'-title'};
	$w->SUPER::Populate($args);
	# width: should be enough for indentation + "max_datetime" + iso date
	# YAML is easier to read with fixed font
	my $txt = $w->Scrolled('ROText', -width => 42, -font => 'courier 10', -scrollbars => 'osoe')->pack(qw(-fill both -expand 1));
	$w->Advertise(Txt => $txt);
	$w->{Accepted_Accuracy} = 0;
	{
	    my $f = $w->Frame->pack;
	    $f->Label(-text => 'Accept. Acc')->pack(qw(-side left));
	    for my $def (['!', 0], ['~', 1], ['~~', 2]) {
		my($label, $val) = @$def;
		$f->Radiobutton(-value => $val, -text => $label, -variable => \$w->{Accepted_Accuracy}, -command => sub { $w->update_existing })->pack(qw(-side left));
	    }
	}
	$w->Button(-text => 'Close', -command => sub { $w->destroy })->pack;
    }

    sub update {
	my($w, $gps, $stats_args_cb) = @_;

	$w->{Last_GPS} = $gps;
	$w->{Last_Stats_Args_Cb} = $stats_args_cb;

	require GPS::GpsmanData::Stats;
	require BBBikeYAML;
	require Encode;
	my %stats_args;
	if ($stats_args_cb) {
	    %stats_args = $stats_args_cb->();
	}
	$stats_args{accuracy} = $w->{Accepted_Accuracy};
	my $stats = GPS::GpsmanData::Stats->new($gps, %stats_args);
	$stats->run_stats;
	my $txt = $w->Subwidget('Txt');
	$txt->delete('1.0', 'end');
	my $yaml = BBBikeYAML::Dump($stats->human_readable); # YAML::XS is documented to emit utf8 *octets*
	$yaml = Encode::decode_utf8($yaml);
	$txt->insert('end', $yaml);
    }

    sub update_existing {
	my($w) = @_;
	my $last_gps = $w->{Last_GPS};
	if (!$last_gps) {
	    $w->messageBox(-message => "Unexpected: no previous gps object stored", -type => 'OK');
	    return;
	}
	my $last_stats_args_cb = $w->{Last_Stats_Args_Cb}; # may be missing
	$w->update($last_gps, $last_stats_args_cb);
    }
}

1;

__END__

=head1 NAME

GPS::GpsmanData::TkViewer - toplevel around GPS::GpsmanData::Tk

=head1 SYNOPSIS

Used preferably within the BBBike Perl/Tk program:

    use GPS::GpsmanData::TkViewer;
    my $t = GPS::GpsmanData::TkViewer->gps_data_viewer($mw, -gpsfile => $gps_file);

Limited support for direct cmdline access (but expect warnings in
STDERR!):

   perl -Ilib -MTk -MGPS::GpsmanData::TkViewer -e 'GPS::GpsmanData::TkViewer->gps_data_viewer(tkinit); MainLoop'

=head1 DESCRIPTION

A toplevel widget which includes the L<GPS::GpsmanData::Tk> widget for
display per-waypoint information from a GPS track, as well as
additional widgets for entering the GPS file name, load buttons etc.

A GPS track may be associated with a waypoint-only file (usually using
the same filename, only the suffix C<.trk> is replaced by C<.wpt>).

A number of variables are intentionally global and thus shared within
a process: the recently used gps file, the main gps data directory,
and the check for using associated waypoint files.

=head2 CONSTRUCTOR OPTIONS

=over

=item C<-gpsfile> => I<filename>

A gpsman file (or any other GPS file format supported by
L<GPS::GpsmanData::Any> to be displayed.

=item C<-title> => I<string>

Title of the toplevel. By default, this is I<GPS data viewer>.

=item C<-geometry> => I<x11-geom-string>

Geometry of the toplevel.

=item C<-statsargscb> => I<callback>

A code reference which is supposed to return a hash with options for
L<GPS::GpsmanData::Stats/new>. Typically one would set the C<areas>
and C<places> options here. See L<SRTShortcuts/gps_data_viewer> for
example code.

=back

=head1 TODO

Associating waypoint files works only for gpsman files, not for GPX
files. For GPX file the association would be done by replacing C<.gpx>
by C<_wpt.gpx>.

The code below works only within the bbbike process. "main::" is used
throughout the code and refers here to the BBBike Perl/Tk program
namespace. In future, this should be OO-ified.

Also, the code below will be either OO-ified or Tk-widgetified.

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<GPS::GpsmanData::Tk>.

=cut
