# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012,2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package StrassenNextCheck;

use strict;
use vars qw($VERSION);
$VERSION = '0.02';

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
	     my($r, $dir) = @_;

	     $self->process_nextcheck_record($r, $dir, check_frequency_days => $check_frequency_days);

	     if ($passthru_without_nextcheck || ($dir->{_nextcheck_date} && $dir->{_nextcheck_date}[0])) {
		 return $cb->($r, $dir);
	     }
	 }, %args
	);
}

sub process_nextcheck_record {
    my($self, $r, $dir, %args) = @_;

    my($y,$m,$d);
    my $label;

    if (exists $dir->{next_check}) {
	($y,$m,$d) = $dir->{next_check}[0] =~ m{(\d{4})-(\d{2})-(\d{2})};
	if (!$y) {
	    ($y,$m) = $dir->{next_check}[0] =~ m{(\d{4})-(\d{2})};
	    $d=1;
	}
	if (!$y) {
	    warn "*** WARN: Malformed next_check directive '$dir->{next_check}[0]' in '" . $self->file . "', ignoring...\n";
	} else {
	    my $date = sprintf "%04d-%02d-%02d", $y,$m,$d;
	    $label = "next check: $date";
	}
    } elsif (exists $dir->{last_checked}) {
	($y,$m,$d) = $dir->{last_checked}[0] =~ m{(\d{4})-(\d{2})-(\d{2})};
	if (!$y) {
	    ($y,$m) = $dir->{last_checked}[0] =~ m{(\d{4})-(\d{2})};
	    $d=1;
	}
	if (!$y) {
	    warn "*** WARN: Malformed last_checked directive '$dir->{next_check}[0]' in '" . $self->file . "', ignoring...\n";
	} else {
	    my $check_frequency_days = _get_check_frequency_days($dir) || $args{check_frequency_days};
	    my $last_checked_date = sprintf "%04d-%02d-%02d", $y,$m,$d;
	    ($y,$m,$d) = Add_Delta_Days($y,$m,$d, $check_frequency_days);
	    $label = "last checked: $last_checked_date";
	}
    } elsif ($r->[Strassen::NAME] =~ m{(\d{4})-(\d{2})-(\d{2})}) {
	($y,$m,$d) = ($1,$2,$3);
    }

    if ($y) {
	if (defined $label) {
	    $dir->{_nextcheck_label}[0] = $label;
	}
	my $date = sprintf "%04d-%02d-%02d", $y,$m,$d;
	$dir->{_nextcheck_date}[0] = $date;
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
