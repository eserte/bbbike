# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012,2013,2016,2019,2021 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package StrassenNextCheck;

use strict;
use vars qw($VERSION);
$VERSION = '0.11';

use Strassen::Core;
use vars qw(@ISA);
@ISA = 'Strassen';

use Date::Calc qw(Add_Delta_Days);

sub read_stream_nextcheck_records {
    my($self, $cb, %args) = @_;

    my $glob_dir = $self->get_global_directives;
    my $check_frequency_days = _get_check_frequency_days($glob_dir) || $args{check_frequency_days_fallback} || 30;

    my $passthru_without_nextcheck = delete $args{passthru_without_nextcheck};

    $self->read_stream
	(sub {
	     my($r, $dir, $linenumber) = @_;

	     $self->process_nextcheck_record($r, $dir, check_frequency_days => $check_frequency_days);

	     if ($passthru_without_nextcheck || ($dir->{_nextcheck_date} && $dir->{_nextcheck_date}[0])) {
		 return $cb->($r, $dir, $linenumber);
	     }
	 }, %args
	);
}

# Calculate a next_check date+label and put it in pseudo-directives
# _nextcheck_label and _nextcheck_date. Use the source directives
# next_check, last_checked and check_frequency in the following way
#
# * if next_check is defined and last_checked is not, then use next_check
# * if next_check, last_checked and check_frequency is defined, then
#   use the smaller of next_check and last_checked+check_frequency
# * if last_checked is defined, then use either
#   * last_checked+check_frequency (if the latter is defined) or
#   * last_checked+$args{check_frequency_days} (the latter defaults to 30 days)
sub process_nextcheck_record {
    my($self, $r, $dir, %args) = @_;

    my $get_date = sub {
	my($directive) = @_;
	my $directive_val = $dir->{$directive}[0];
	my($y,$m,$d) = $directive_val =~ m{(\d{4})-(\d{2})-(\d{2})};
	if (!$y) {
	    ($y,$m) = $directive_val =~ m{(\d{4})-(\d{2})};
	    $d=1;
	}
	if (!$y) {
	    warn "*** WARN: Malformed $directive directive '$directive_val' in '" . $self->file . "', ignoring...\n";
	    return;
	}
	sprintf "%04d-%02d-%02d", $y,$m,$d;
    };

    my $next_check_info;
    if (exists $dir->{next_check}) {
	my $date = $get_date->('next_check');
	if ($date) {
	    my $label = "next check: $date";
	    $next_check_info = { date => $date, label => $label };
	}
    }
    if (exists $dir->{last_checked} && (!$next_check_info || exists $dir->{check_frequency})) {
	my $last_checked_date = $get_date->('last_checked');
	if ($last_checked_date) {
	    my $check_frequency_days = _get_check_frequency_days($dir) || $args{check_frequency_days};
	    my($y,$m,$d) = split /-/, $last_checked_date;
	    ($y,$m,$d) = Add_Delta_Days($y,$m,$d, $check_frequency_days);
	    my $date = sprintf "%04d-%02d-%02d", $y,$m,$d;
	    if (!$next_check_info || $next_check_info->{date} gt $date) {
		my $label = "last checked: $last_checked_date";
		$next_check_info = { date => $date, label => $label };
	    }
	}
    }

    {
	# Set a pseudo directive _begincheck_date, currently used for
	# the Mapillary dateFrom filter. The rationale here:
	# * if last_checked is set, then use the day after this day
	#   (no need to see older Mapillary sequences)
	# * elsif begin_check is set (XXX not yet documented in bbd.pod),
	#   then use this day for filtering
	# * elsif next_check is set, then use this day for filtering
	my $begin_check_date;
	if (exists $dir->{last_checked}) {
	    $begin_check_date = $get_date->('last_checked');
	    my($y,$m,$d) = split /-/, $begin_check_date;
	    ($y,$m,$d) = Add_Delta_Days($y,$m,$d, 1); # with last_checked, use the next day for the begin_check filter
	    $begin_check_date = sprintf "%04d-%02d-%02d", $y,$m,$d;
	}
	if (!$begin_check_date) {
	    if (exists $dir->{begin_check}) {
		$begin_check_date = $get_date->('begin_check');
	    }
	}
	if (!$begin_check_date) {
	    if (exists $dir->{next_check}) {
		$begin_check_date = $get_date->('next_check');
	    }
	}
	if ($begin_check_date) {
	    $dir->{_begincheck_date}[0] = $begin_check_date;
	}
    }

    if ($next_check_info) {
	$dir->{_nextcheck_label}[0] = $next_check_info->{label};
	$dir->{_nextcheck_date}[0]  = $next_check_info->{date};
    }
}

sub _get_check_frequency_days {
    my $dir = shift;
    if ($dir && $dir->{check_frequency}) {
	my($check_frequency_days) = $dir->{check_frequency}[0] =~ m{^(\d+)d$};
	if (!$check_frequency_days) {
	    die "ERROR: Invalid specification for check_frequency: '$dir->{check_frequency}[0]', should be <days>d.\n";
	}
	$check_frequency_days;
    } else {
	undef;
    }    
}

1;

__END__
