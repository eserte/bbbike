# -*- perl -*-

#
# $Id: DirectEdit.pm,v 1.6 2008/12/29 19:44:36 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::GpsmanData::DirectEdit;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

use Tie::File;

sub new {
    my($class, $gpsman_data) = @_;
    tie my @lines, 'Tie::File', $gpsman_data->File
	or die "Cannot tie " . $gpsman_data->File . ": $!";
    bless { GpsmanData => $gpsman_data,
	    Lines      => \@lines,
	  }, $class;
}

sub show_raw_line {
    my($self, $line) = @_;
    $self->{Lines}->[$line];
}

sub split_track {
    my($self, $first_i, $name, $track_attrs) = @_;
    die "Name is missing" if !$name;
    die "Track attributes are missing" if !$track_attrs;
    my $lines = $self->{Lines};
    my $new_line = "!T:\t$name";
    for my $key (sort keys %$track_attrs) { # XXX preserve sorting, Tie::IxHash in the caller!
	$new_line .= "\t$key=$track_attrs->{$key}";
    }
    splice @$lines, $first_i, 0, $new_line;
    $self->{GpsmanData}->{LineInfo}->line_inserted($first_i);
}

sub split_trackseg {
    my($self, $first_i) = @_;
    my $lines = $self->{Lines};
    my $new_line = "!TS:";
    splice @$lines, $first_i, 0, $new_line;
    $self->{GpsmanData}->{LineInfo}->line_inserted($first_i);
}

sub change_track_attributes {
    my($self, $line, $name, $track_attrs) = @_;
    die "Name is missing" if !$name;
    die "Track attributes are missing" if !$track_attrs;
    my $lines = $self->{Lines};
    my $new_line = "!T:\t$name";
    for my $key (keys %$track_attrs) {
	$new_line .= "\t$key=$track_attrs->{$key}";
    }
    $lines->[$line] = $new_line;
}

sub set_accuracy {
    my($self, $line, $acc_level) = @_; # $acc_level=0: accurate; $acc_level=2: highly inaccurate
    my @f = split /\t/, $self->{Lines}->[$line];
    my $acc = "~" x $acc_level;
    # borrowed from BBBikeEdit, $set_accuracy
    $f[4] =~ s/^(~*\|?)/$acc/;
    my $new_line = join("\t", @f);
    $self->{Lines}->[$line] = $new_line;
}

sub set_accuracies {
    my($self, $lines, $acc_level) = @_;
    for my $line (@$lines) {
	$self->set_accuracy($line, $acc_level);
    }
}

sub remove_empty_track_segments {
    my($self, %args) = @_;
    my $dry_run = delete $args{'-dryrun'};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    my @operations;
    for my $i (reverse(1 .. $#{$self->{Lines}})) {
	if ($self->{Lines}->[$i-1] eq '!TS:' &&
	    $self->{Lines}->[$i] =~ m{^!TS?:}) {
	    push @operations, ["remove", $i-1, $self->{Lines}->[$i-1]];
	} elsif ($self->{Lines}->[$i-1] =~ m{^!T:} &&
		 $self->{Lines}->[$i] eq '!TS:') {
	    push @operations, ["remove", $i, $self->{Lines}->[$i]];
	}
    }

    if ($dry_run) {
	@operations;
    } else {
	$self->run_operations(\@operations);
    }
}

sub remove_lines {
    my($self, $lines_ref, %args) = @_;
    my $dry_run = delete $args{'-dryrun'};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    my @operations = map { ["remove", $_, $self->{Lines}->[$_]] } sort { $b <=> $a } @$lines_ref;

    if ($dry_run) {
	@operations;
    } else {
	$self->run_operations(\@operations);
    }
}

sub run_operations {
    my($self, $operations_ref) = @_;
    for my $operation_def (@$operations_ref) {
	my($operation, $line) = @$operation_def;
	if ($operation eq 'remove') {
	    splice @{ $self->{Lines} }, $line, 1;
	} else {
	    die "Unhandled operation $operation";
	}
    }
    $self->{GpsmanData}->{LineInfo} = undef; # invalidate it XXX better to recalculate!
    $self->flush;
}

sub flush {
    (tied @{ shift->{Lines} })->flush;
}

{
    package GPS::GpsmanData::LineInfo;
    sub new { bless {}, shift }
    sub add_wpt_lineinfo {
	my($self, $wpt, $line) = @_;
	$self->{WptToLine}->{$wpt} = $line;
	$self->{LineToWpt}->{$line} = $wpt;
    }
    sub add_chunk_lineinfo {
	my($self, $chunk, $line) = @_;
	$self->{ChunkToLine}->{$chunk} = $line;
	# XXX LineToChunk not yet
    }
    sub get_line_by_wpt {
	my($self, $wpt) = @_;
	$self->{WptToLine}->{$wpt};
    }
    sub get_line_by_chunk {
	my($self, $chunk) = @_;
	$self->{ChunkToLine}->{$chunk};
    }
    sub get_wpt_by_line {
	my($self, $line) = @_;
	$self->{LineToWpt}->{$line};
    }
    sub line_inserted { # XXX not really tested!
	my($self, $new_line) = @_;
	for my $wpt (keys %{$self->{WptToLine}}) {
	    if ($self->{WptToLine}->{$wpt} >= $new_line) {
		$self->{WptToLine}->{$wpt}++;
	    }
	}
	my %new_line_to_wpt;
	for my $line (keys %{$self->{LineToWpt}}) {
	    if ($line >= $new_line) {
		$new_line_to_wpt{$line+1} = $self->{LineToWpt}->{$line};
	    } else {
		$new_line_to_wpt{$line} = $self->{LineToWpt}->{$line};
	    }
	}
	$self->{LineToWpt} = \%new_line_to_wpt;
    }
}

1;

__END__

=head1 NAME

GPS::GpsmanData::DirectEdit - direct editing of gpsman files

=head1 SYNOPSIS

Remove empty track segments:

    perl -MData::Dumper -MGPS::GpsmanData -e '$gps=GPS::GpsmanMultiData->new(-editable => 1);$gps->load(shift);$edit=GPS::GpsmanData::DirectEdit->new($gps); warn Dumper($edit->remove_empty_track_segments(-dryrun => 1))' ...

=cut
