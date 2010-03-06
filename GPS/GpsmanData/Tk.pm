# -*- perl -*-

#
# $Id: Tk.pm,v 1.19 2009/01/25 15:36:09 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::GpsmanData::Tk;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.19 $ =~ /(\d+)\.(\d+)/);

use base qw(Tk::Frame);
Construct Tk::Widget 'GpsmanData';

use Tk::Balloon;
use Tk::BrowseEntry;
use Tk::HList;
use Tk::ItemStyle;

use BBBikeUtil qw(ms2kmh);
use GPS::GpsmanData;

my @wpt_cols = qw(Ident Comment Latitude Longitude Altitude Symbol Accuracy Velocity VelocityGraph);

{
    package GPS::GpsmanData::Tk::HList;
    use base 'Tk::HList';
    Construct Tk::Widget 'GpsmanDataHList';

    sub BalloonInfo
    {
     my ($hlist,$balloon,$X,$Y,@opt) = @_;
     my $wy = $Y - $hlist->rooty;
     my $entry = $hlist->nearest($wy);
     foreach my $opt (@opt)
      {
       my $info = $balloon->GetOption($opt,$hlist);
       if ($opt =~ /^-(statusmsg|balloonmsg)$/ && UNIVERSAL::isa($info,'HASH'))
        {
         $balloon->Subclient($entry);
	 return $info->{$entry} if defined $entry && exists $info->{$entry};
         return '';
        }
       return $info;
      }
    }
}

my %vehicle_to_color = (
			# get all vehicles with:
			# cd .../misc/gps_data
			# perl -nle 'm{srt:vehicle=(\S+)} and print $1' *.trk | sort | uniq -c
			'bike'   => 'darkblue',
			'bus'    => 'violet',
			'car'    => 'darkgrey',
			'ferry'  => 'lightblue',
			'funicular' => 'red',
			'pedes'  => 'orange',
			'plane'  => 'black',
			's-bahn' => 'green',
			'ship'   => 'lightblue',
			'train'  => 'darkgreen',
			'tram'   => 'red',
			'u-bahn' => 'blue',
		       );

sub Populate {
    my($w, $args) = @_;
    $w->SUPER::Populate($args);

    my $dvf = $w->Frame->pack(qw(-fill both -expand 1));

    my $real_dv;
    {
	my $dv = $dvf->Scrolled("GpsmanDataHList",
				-exportselection => 1,
				#XXX which one?
				-selectmode => "extended",
				-scrollbars => "se", # XXX no "ose" for easier handling of overview canvas
				-header => 1,
				-columns => scalar(@wpt_cols),
			       )->pack(qw(-side left -fill both -expand 1));
	{
	    my $col = 0;
	    for my $def (@wpt_cols) {
		$dv->header('create', $col++, -text => $def);
	    }
	}

	$real_dv = $dv->Subwidget('scrolled');
	$w->Advertise(data => $real_dv);
	$real_dv->bind("<1>" => sub {
			   my $cmd = $w->cget('-command');
			   return if !$cmd;
			   
			   my $cw = shift;
			   my $e = $cw->XEvent;
			   my $entry = $real_dv->nearest($e->y);
			   if (defined $entry) {
			       my $wpt = $w->wpt_by_item($entry);
			       my $chunk = $w->chunk_by_item($entry);
			       $cmd->Call(-entry => $entry, -wpt => $wpt, -chunk => $chunk);
			       
			   }
		       });

	if ($real_dv->can("menu") &&
	    $real_dv->can("PostPopupMenu") && $Tk::VERSION >= 800) {

	    my $popup_menu = $real_dv->Menu(-tearoff => 0);
	    $popup_menu->command(-label => "Split track",
				 -command => [$w, '_split_track'] # XXX should be only visible for waypoint lines
				);
	    $popup_menu->command(-label => "Set accuracy",
				 -command => [$w, '_set_accuracy'] # XXX should be only visible for waypoint lines
				);
	    $popup_menu->command(-label => "Edit track attributes",
				 -command => [$w, '_edit_track_attributes'] # XXX should be only visible for track lines
				);
	    $real_dv->menu($popup_menu);
	    $real_dv->Tk::bind('<3>' => sub {
				   my $cw = $_[0];
				   my $e = $cw->XEvent;
				   $w->{_current_popup_entry} = $cw->GetNearest($e->y, 0);
				   return unless defined $w->{_current_popup_entry};
				   $real_dv->anchorSet($w->{_current_popup_entry});
				   $real_dv->PostPopupMenu($e->X, $e->Y);
			       });
	}

	{
	    my $style = $real_dv->ItemStyle('window');
	    $style->configure(-pady => 1, -padx => 2, -anchor => "nw");
	    $w->{hlist_window_style} = $style;
	}
    }

    {
	my $c = $dvf->Canvas(-width => 3)->pack(qw(-side left -fill y));
	$c->Tk::bind("<Configure>" => [$w, '_adjust_overview']);
	$w->Advertise(overview => $c);
    }

    $w->Advertise(balloon => $w->Balloon);

    $w->ConfigSpecs
      (
       -command => ['CALLBACK', undef, undef, undef],
       -selectbackground => [$real_dv],
       -selectforeground => [$real_dv],
       -velocity => ['PASSIVE', undef, undef, 'absolute'],
      );
}

sub OnDestroy {
    my $w = shift;
    $w->_destroy_velocity_frames;
}

sub associate_object {
    my($w, $gpsman_obj) = @_;
    $w->{GpsmanData} = $gpsman_obj;
    $w->_clear_data_view;
    $w->_fill_data_view;
}

sub get_associated_object {
    shift->{GpsmanData};
}

sub reload {
    my($w) = @_;
    if (!$w->{GpsmanData}) {
	die "Cannot reload, no associated GpsmanData object available";
    }
    $w->{GpsmanData}->reload;
    $w->_clear_data_view;
    $w->_fill_data_view;
}

sub _clear_data_view {
    my $w = shift;
    my $dv = $w->Subwidget("data");
    $dv->delete("all");
    my $bln = $w->Subwidget("balloon");
    $bln->attach($dv, -msg => {});
}

sub _destroy_velocity_frames {
    my $w = shift;
    if ($w->{_velocity_frames}) {
	for (values %{ $w->{_velocity_frames} }) {
	    $_->destroy;
	}
    }
    delete $w->{_velocity_frames};
}

sub _fill_data_view {
    my $w = shift;
    my $dv = $w->Subwidget("data");
    my $bln = $w->Subwidget("balloon");

    # We have to store the velocity bar canvases and
    # explicitely destroy on every re-fill, to avoid
    # memory leaks. Now there's still a leak of about
    # 10k per reload, but previously it was somewhere
    # near megabytes.
    $w->_destroy_velocity_frames;

    my $velocity_per_vehicle = $w->cget('-velocity') eq 'per_vehicle';

    my $dump_attrs = (eval { require JSON::XS; 1 }
		      ? sub {
			  JSON::XS::encode_json(shift);
		      }
		      : do {
			  require Data::Dumper;
			  sub {
			      Data::Dumper->new([shift],[])->Indent(0)->Dump;
			  }
		      }
		     );
    my $i = -1;
    my $chunk_i = -1;
    my %bln_info;
    my %velocity_frame;
    my @chunk_to_i;
    my %max_ms;
    my $last_vehicle;
    for my $chunk (@{ $w->{GpsmanData}->Chunks }) {
	$chunk_i++;
	my $supported = $chunk->Type eq $chunk->TYPE_TRACK;
	my $track_attrs = $chunk->TrackAttrs || {};
	my $vehicle = $track_attrs->{'srt:vehicle'} || $last_vehicle;
	$last_vehicle = $vehicle;
	my $max_v_vehicle = $velocity_per_vehicle ? ($vehicle||'unknown') : 'total';
	my $label = $vehicle ? $vehicle : "-----";
	$dv->add(++$i, -text => $label, -data => {Chunk => $chunk_i});
	$bln_info{$i} = "Type " . $chunk->Type . (!$supported ? " (unsupported, skipping)" : "") . ", Attrs: " . $dump_attrs->($track_attrs);
	push @chunk_to_i, [$chunk, $i] if $vehicle;
	if (!$supported) {
	    warn "Only type TRACK supported";
	} else {
	    my $wpt_i = -1;
	    my $last_wpt;
	    for my $wpt (@{ $chunk->Track }) {
		$wpt_i++;
		my $data = {Chunk => $chunk_i, Wpt => $wpt_i};
		$dv->add(++$i, -text => "", -data => $data);
		my $col_i = -1;
		for my $def (@wpt_cols) {
		    if ($def eq 'VelocityGraph') {
			my $f = $velocity_frame{$i} = $dv->Canvas(-width => 100, -height => 10);
			$dv->itemCreate($i, ++$col_i,
					-itemtype => 'window',
					-style => $w->{hlist_window_style},
					-widget => $f,
				       );
		    } else {
			my $val;
			if ($def eq 'Velocity') {
			    if (defined $last_wpt) {
				my $ms = $chunk->wpt_velocity($wpt, $last_wpt);
				$val = sprintf "%.1f km/h", ms2kmh($ms);
				$data->{Velocity} = $ms;
				$data->{_Max_V_Vehicle} = $max_v_vehicle;
				if ($wpt->Accuracy != 0 || $last_wpt->Accuracy != 0) {
				    $val .= " (inacc.)";
				    $data->{VelocityInaccurate} = 1;
				} else {
				    if (!defined $max_ms{$max_v_vehicle} || $max_ms{$max_v_vehicle} < $ms) {
					$max_ms{$max_v_vehicle} = $ms;
				    }
				}
			    } else {
				$val = "N/A";
			    }
			} else {
			    $val = $wpt->$def;
			}
			$dv->itemCreate($i, ++$col_i, -text => $val);
		    }
		}
		$last_wpt = $wpt;
	    }
	}
    }

    # align VelocityGraph
    if (keys %max_ms) { # there is a maximum velocity
	for my $item ($dv->info('children')) {
	    my $data = $dv->info('data', $item);
	    my $ms = $data->{Velocity};
	    next if !defined $ms;
	    my $max_v_vehicle = $data->{_Max_V_Vehicle};
	    next if !defined $max_v_vehicle;
	    my $max_ms_per_vehicle = $max_ms{$max_v_vehicle};
	    next if !$max_ms_per_vehicle;
	    my $f = $velocity_frame{$item};
	    my($w,$h) = ($f->reqwidth,$f->reqheight);
	    my $this_w = int($w*$ms/$max_ms_per_vehicle);
	    $this_w = $w if $this_w > $w; # may happen for inaccurate points
	    # simulated alpha 0.2 vs. 0.8 for inaccurate bar color:
	    #  perl -e 'warn sprintf "%x", (0xcf*0.8 + 0xff*0.2)' -> d8
	    #  perl -e 'warn sprintf "%x", (0xcf*0.8 + 0x00*0.2)' -> a5
	    my $color = $data->{VelocityInaccurate} ? '#d8a5a5' : 'red';
	    $f->createRectangle(0,0,$this_w,$h, -fill => $color, -outline => $color);
	}
    }

    $bln->attach($dv, -msg => \%bln_info, -balloonposition => 'mouse');

    $w->{_velocity_frames} = \%velocity_frame;
    $w->{_chunk_to_i} = \@chunk_to_i;
    $w->{_max_i} = $i;
    $w->_adjust_overview;
}

sub _adjust_overview {
    my $w = shift;
    my $c = $w->Subwidget('overview');
    $c->delete("all");
    return if !$w->{_max_i}; # no data yet?
    my @chunk_to_i = @{ $w->{_chunk_to_i} || [] };
    use constant SCROLLBAR_TOP => 14; # arrow
    use constant SCROLLBAR_BOTTOM => 33; # arrow and extra square
    my $transpose = sub {
	my $this_i = shift;
	($c->Height - SCROLLBAR_TOP - SCROLLBAR_BOTTOM) * $this_i / $w->{_max_i} + SCROLLBAR_TOP;
    };
    my $last_y = $transpose->(0);
    my %blnmsg;
    my $last_vehicle;
    for my $chunk_def_i (0 .. $#chunk_to_i) {
	my($this_chunk, $this_i) = @{$chunk_to_i[$chunk_def_i]};
	my($next_chunk, $next_i) = $chunk_def_i+1 <= $#chunk_to_i ? @{$chunk_to_i[$chunk_def_i+1]} : (undef,undef);
	my $track_attrs = $this_chunk->TrackAttrs || {};
	my $vehicle = $track_attrs->{'srt:vehicle'} || $last_vehicle;
	$last_vehicle = $vehicle;
	if (!$vehicle) {
	    #warn "No vehicle found in chunk";
	} else {
	    my $color = $vehicle_to_color{$vehicle} || '#ffdead';
	    if (!defined $next_i) {
		$next_i = $w->{_max_i};
	    }
	    my $item = $c->createRectangle(0, $last_y, 1, $transpose->($next_i), -outline => $color, -fill => $color);
	    $blnmsg{$item} = $vehicle;
	    $last_y = $transpose->($next_i)+1;
	}
    }

    my @bbox = $c->bbox("all");
    if (@bbox) {
	$bbox[1] = 0;
	$c->configure(-scrollregion => [@bbox]);
	$c->yviewMoveto(0);
    }

    my $bln = $w->Subwidget("balloon");
    $bln->attach($c, -msg => \%blnmsg, -balloonposition => 'mouse');
}

sub _edit_preparations {
    my($self, %args) = @_;
    my $expect = delete $args{-expect};
    die "What do you -expect?" if !$expect;
    die "Unhandled arguments: " . join(" ", %args) if %args;

    return if !defined $self->{_current_popup_entry};

    my $gps = $self->get_associated_object;
    my $lineinfo = $gps->{LineInfo};
    if (!$lineinfo) {
	die "Please construct the " . ref($gps) . " object with -editable => 1";
    }

    require GPS::GpsmanData::DirectEdit;
    my $direct_edit = GPS::GpsmanData::DirectEdit->new($gps);

    my $wpt;
    my $chunk;
    my $line;
    if ($expect eq 'wpt') {
	$wpt = $self->wpt_by_item($self->{_current_popup_entry});
	if (!$wpt) {
	    die "Cannot find waypoint object for current item";
	}
	$line = $lineinfo->get_line_by_wpt($wpt);
	if (!defined $line) {
	    require Data::Dumper;
	    die "Cannot find line for wpt " . Data::Dumper::Dumper($wpt);
	}
    } elsif ($expect eq 'chunk') {
	$chunk = $self->chunk_by_item($self->{_current_popup_entry});
	if (!$chunk) {
	    die "Cannot find chunk object for current item";
	}
	$line = $lineinfo->get_line_by_chunk($chunk);
	if (!defined $line) {
	    die "Cannot find line for chunk";
	}
    } else {
	die "Unhandled -expect value $expect";
    }

    my $line_content = $direct_edit->show_raw_line($line);

    (line         => $line,
     line_content => $line_content,
     direct_edit  => $direct_edit,
     wpt          => $wpt,
     chunk        => $chunk,
    );
}

# common stuff for _split_track and _edit_track_attributes
sub _track_attributes_editor {
    my($self, $t, $line_content, $track_name_ref, $track_attrs_ref) = @_;

    Tk::grid($t->Label(-text => "Line"),
	     $t->Label(-text => $line_content));
    Tk::grid($t->Label(-text => "Name"),
	     $t->Entry(-textvariable => $track_name_ref));
    Tk::grid($t->Label(-text => "Vehicle"),
	     $t->BrowseEntry(-textvariable => \$track_attrs_ref->{'srt:vehicle'},
			     -autolimitheight => 1,
			     -autolistwidth => 1,
			     -listheight => 12, # hmmm, -autolimitheight does not work? or do i misunderstand this option?
			     -choices => [sort keys %vehicle_to_color],
			    ));
    Tk::grid($t->Label(-text => "Brand"),
	     $t->Entry(-textvariable => \$track_attrs_ref->{'srt:brand'}));
    Tk::grid($t->Label(-text => "Comment"),
	     $t->Entry(-textvariable => \$track_attrs_ref->{'srt:comment'}));
    Tk::grid($t->Label(-text => "Event"),
	     $t->Entry(-textvariable => \$track_attrs_ref->{'srt:event'}));
    Tk::grid($t->Label(-text => "Frequency"),
	     $t->Entry(-textvariable => \$track_attrs_ref->{'srt:frequency'}));
    my $weiter;
    Tk::grid($t->Button(-text => 'Ok', -command => sub { $weiter = +1 }),
	     $t->Button(-text => 'Cancel', -command => sub { $weiter = -1 }));
    $t->waitVariable(\$weiter);
    $weiter;
}

sub _split_track {
    my($self) = @_;
    my %ret = $self->_edit_preparations(-expect => "wpt");
    my($line, $line_content, $direct_edit) = @ret{qw(line line_content direct_edit)};

    my $track_name = "ACTIVE LOG $line";
    my %track_attrs;
    my $t = $self->Toplevel(-title => "Track attributes");
    my $weiter = $self->_track_attributes_editor($t, $line_content, \$track_name, \%track_attrs);
    if ($weiter == +1) {
	for (keys %track_attrs) {
	    delete $track_attrs{$_} if !defined $track_attrs{$_} || $track_attrs{$_} =~ m{^\s*$};
	}
	$direct_edit->split_track($line, $track_name, \%track_attrs);
	$direct_edit->flush;
	$self->reload;
    }
    $t->destroy;
}

sub _edit_track_attributes {
    my($self) = @_;
    my %ret = $self->_edit_preparations(-expect => "chunk");
    my($line, $line_content, $direct_edit, $chunk) = @ret{qw(line line_content direct_edit chunk)};

    my $track_name = $chunk->Name;
    my $track_attrs_ref = $chunk->TrackAttrs;
    my $t = $self->Toplevel(-title => "Track attributes");
    my $weiter = $self->_track_attributes_editor($t, $line_content, \$track_name, $track_attrs_ref);
    if ($weiter == +1) {
	for (keys %$track_attrs_ref) {
	    delete $track_attrs_ref->{$_} if !defined $track_attrs_ref->{$_} || $track_attrs_ref->{$_} =~ m{^\s*$};
	}
	$direct_edit->change_track_attributes($line, $track_name, $track_attrs_ref);
	$direct_edit->flush;
	$self->reload;
    }
    $t->destroy;
}

sub _set_accuracy {
    my($self) = @_;
    my %ret = $self->_edit_preparations(-expect => "wpt");
    my($line, $line_content, $direct_edit, $wpt) = @ret{qw(line line_content direct_edit wpt)};

    my $accuracy_level = $wpt->Accuracy;

    my $t = $self->Toplevel(-title => "Set accuracy");
    Tk::grid($t->Label(-text => "Line"),
	     $t->Label(-text => $line_content));
    Tk::grid($t->Label(-text => "Accuracy"),
	     $t->Radiobutton(-text => "!",
			     -value => 0,
			     -variable => \$accuracy_level));
    Tk::grid($t->Label,
	     $t->Radiobutton(-text => "~",
			     -value => 1,
			     -variable => \$accuracy_level));
    Tk::grid($t->Label,
	     $t->Radiobutton(-text => "~~",
			     -value => 2,
			     -variable => \$accuracy_level));

    my $weiter;
    Tk::grid($t->Button(-text => 'Ok', -command => sub { $weiter = +1 }),
	     $t->Button(-text => 'Cancel', -command => sub { $weiter = -1 }));
    $t->waitVariable(\$weiter);
    if ($weiter == +1) {
	$direct_edit->set_accuracy($line, $accuracy_level);
	$direct_edit->flush;
	$self->reload;
    }
    $t->destroy;
}

sub find_items_by_lat_lon {
    my($self, $latitude, $longitude, %args) = @_;
    my $dv = $self->Subwidget("data");
    my $gpsmandata = $self->{GpsmanData};
    my $around = delete $args{-around};
    die "Unhandled parameters: " . join(" ", keys %args) if %args;
    my $center_wpt = GPS::Gpsman::Waypoint->new;
    $center_wpt->Longitude($longitude);
    $center_wpt->Latitude($latitude);
    my @res;
    for my $item ($dv->info('children')) {
	my $data = $dv->info('data', $item);
	next if !exists $data->{Wpt};
	my $wpt = $gpsmandata->Chunks->[$data->{Chunk}]->Track->[$data->{Wpt}];
	if ($wpt->Latitude == $latitude &&
	    $wpt->Longitude == $longitude) { # XXX inexact search
	    push @res, $item;
	} elsif ($around) {
	    my $dist = $gpsmandata->wpt_dist($center_wpt, $wpt);
	    if ($dist <= $around) {
		push @res, $item;
	    }
	}
    }
    @res;
}

sub find_items_by_wpts {
    my($self, @wpts) = @_;

    my %wpt_to_item;
    my $dv = $self->Subwidget("data");
    my $gpsmandata = $self->{GpsmanData};
    for my $item ($dv->info('children')) {
	my $wpt = $self->wpt_by_item($item);
	if ($wpt) {
	    $wpt_to_item{$wpt} = $item;
	}
    }

    my @res;
    for my $wpt (@wpts) {
	if (exists $wpt_to_item{$wpt}) {
	    push @res, $wpt_to_item{$wpt};
	} else {
	    push @res, undef;
	}
    }
    @res;
}

sub wpt_by_item {
    my($self, $item) = @_;
    my $dv = $self->Subwidget("data");
    my $data = $dv->info('data', $item);
    return undef if !exists $data->{Wpt};
    $self->{GpsmanData}->Chunks->[$data->{Chunk}]->Track->[$data->{Wpt}];
}

sub chunk_by_item {
    my($self, $item) = @_;
    my $dv = $self->Subwidget("data");
    my $data = $dv->info('data', $item);
    return undef if !exists $data->{Chunk};
    $self->{GpsmanData}->Chunks->[$data->{Chunk}];
}

sub select_items {
    my($self, @items) = @_;
    my $dv = $self->Subwidget("data");
    $dv->selectionClear;
    for my $item (@items) {
	$dv->selectionSet($item);
    }
}

sub get_selected_items {
    my($self) = @_;
    my $dv = $self->Subwidget("data");
    my @items = $dv->info('selection');
    @items;
}

1;

__END__

=head1 NAME

GPS::GpsmanData::Tk - make gpsman data visible in a Tk widget

=head1 SYNOPSIS

    cd .../bbbike
    perl -MTk -MGPS::GpsmanData -MGPS::GpsmanData::Tk -e '$w=tkinit->GpsmanData->pack(qw(-fill both -expand 1));$gps=GPS::GpsmanMultiData->new;$gps->load(shift);$w->associate_object($gps);MainLoop' ...

=head1 DESCRIPTION

A Tk viewer for GPS data. In future, this widget will be extended for
some data manipulation features. It can be used stand-alone or in
conjunction with bbbike.

=head1 OPTIONS

=over

=item -command => I<$CODE>

A callback which is fired if an list item is clicked on. The callback
gets a named parameter list:

=over

=item -entry

The internal item number of the clicked item.

=item -wpt

The L<GPS::Gpsman::Waypoint> object of the associated clicked item, if
any.

=item -chunk

The L<GPS::GpsmanData> object of the associated clicked item, if any.

=back

=back

=head1 METHODS

=over

=item $w->associate_object($gpsmandata)

Associate a L<GPS::GpsmanMultiData> object with the widget. This will
also cause to fill the gps data into the widget.

=item $w->reload

Cause a reload of the associated GPS object and re-fill the gps data
into the widget.

=item $w->get_associated_object

Return the associated GPS object. See L</associate_object>.

=item $w->find_items_by_lat_lon($lat, $lon, -around => $dist)

Return a list of all (internal) items which are at most I<$dist>
meters far from the point I<$lat>,I<$lon>. Note that C<-around> is
optional, but because of floating point inaccuracies it is recommended
to use it with a small values (a meter or less).

=item $w->wpt_by_item($item)

For a given (internal) I<$item> (for example, the result from the
L</find_items_by_lat_lon> call), return the associated
L<GPS::Gpsman::Waypoint> object, or undef.

=item $w->chunk_by_item($item)

For a given (internal) I<$item> (for example, the result from the
L</find_items_by_lat_lon> call), return the associated
L<GPS::GpsmanData> object, or undef.

=item $w->select_items($item, ...)

Select the given (internal) items.

=item $w->get_selected_items

Get a list of (internal) items which are selected.

=item $w->find_items_by_wpts(@wpts)

For a list of L<GPS::Gpsman::Waypoint> objects, return a list of
corresponding (internal) items. Note: comparison is done by identity
check, so make sure that the same waypoint objects are used as input
parameters as are associated with the GpsmanData widget.

=back

=head1 FEATURES

=over

=item *

May display any data for which a L<GPS::GpsmanData>-compatible
interface exists (currently, there's support for GPS and MPS files
available in L<GPS::GpsmanData::Any>. Note that editing and writing
back data will first only be supported for gpsman data, only later for
other data files.

=item *

Shows the velocity in the next point's Velocity cell, together with a
simple graphical (bar) representation. Velocities for inaccurate
points are made visible distinct by color.

=item *

Shows an per-vehicle overview bar next to the scrollbar. For this, the
extension attribute C<srt:vehicle> is used. 

=item *

Subtracks (track chunks) may be created, with values for the extension
attributes C<srt:vehicle>, C<srt:brand>, C<srt:comment>, and
C<srt:frequency>.

=item *

Track attributes may be modified.

=item *

Some additional features are implemented in L<SRTShortcuts> (detecting
ranges with premature points and automatically deleting them, setting
accuracy in selected ranges)

=back

=head1 TODO

=head2 Low priority

  * Callbacks, so dass BBBike auf Änderungen reagieren kann

  * BBBike integration: Möglichkeit eines Callbacks für eine Selektion
    von Punkten (BBBike: call mark_street or mark_points)

  * Nice to have: Scrollbereich im GPS Viewer und im BBBike-Canvas
    können sich gegenseitig setzen, so dass immer der
    korrespondierende Bereich zu sehen ist

  * Edit-Operationen sollten einen unendlichen Log haben, mit
    unendlichen Undo

  * Support for other data types like routes, waypoint files etc.

=head2 GPX support

  * Better support for GPX and other data types
 
  * GPX-Äquivalent für ~/~~ erfinden.

  * GPX-Äquivalent für srt:... erfinden.

=cut
