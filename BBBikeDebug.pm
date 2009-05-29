# -*- perl -*-

#
# $Id: BBBikeDebug.pm,v 1.5 2007/03/31 20:01:21 eserte Exp $
#
# This is the Debug example from perlfilter.pod
# Modified by Slaven Rezic
#

package BBBikeDebug;

BEGIN {
    die "Dumps core with 5.6.1" if $] == 5.006001;
    die "Does not work with older perls" if $] < 5.005;
}

use strict;
use Filter::Util::Call;

use constant TRUE => 1;
use constant FALSE => 0;

sub import {
    my($type) = @_ ;
    my(%context) =
	(
	 Enabled => defined $ENV{BBBIKE_DEBUG},
	 InTraceBlock => FALSE,
	 Filename => (caller)[1],
	 LineNo => 0,
	 LastBegin => 0,
	);
    filter_add(bless \%context);
}

sub Die {
    my($self) = shift;
    my($message) = shift;
    my($line_no) = shift || $self->{LastBegin};
    die "$message at $self->{Filename} line $line_no.\n"
}

sub filter {
    my($self) = @_;
    my($status);
    $status = filter_read() ;
    ++ $self->{LineNo};
    # deal with EOF/error first
    if ($status <= 0) {
	$self->Die("DEBUG_BEGIN has no DEBUG_END")
	    if $self->{InTraceBlock};
	return $status;
    }
    if ($self->{InTraceBlock}) {
	if      ( /^\s*\#\#\s*DEBUG_BEGIN/ ) {
	    $self->Die("Nested DEBUG_BEGIN", $self->{LineNo})
	} elsif ( /^\s*\#\#\s*DEBUG_END/ ) {
	    $self->{InTraceBlock} = FALSE;
	}
	# remove comment from the debug lines when the filter is enabled
	s/^\#// if $self->{Enabled};
    } elsif ( /^\s*\#\#\s*DEBUG_BEGIN/ ) {
	$self->{InTraceBlock} = TRUE ;
	$self->{LastBegin} = $self->{LineNo} ;
    } elsif ( /^\s*\#\#\s*DEBUG_END/ ) {
	$self->Die("DEBUG_END has no DEBUG_BEGIN", $self->{LineNo});
    }
    return $status;
}

package main;

use Config;

$BBBikeDebug::start = time;
if ($ENV{BBBIKE_DEBUG} =~ /devel::size/i &&
	 eval { require Devel::Size; 1 }) {
    *mymstat = sub {
	my $time = defined &Tk::timeofday ? Tk::timeofday() : time;
	printf STDERR "%-30s: %.2f  %.2f\n", "@_", $time-$BBBikeDebug::start, (defined $BBBikeDebug::last ? $time-$BBBikeDebug::last : 0);
	print "size=".Devel::Size::total_size(\%main::) . " (@_)\n";
	$BBBikeDebug::last = $time;
    }
} elsif ($Config{'optimize'} =~ /PERL_DEBUGGING_MSTATS/ &&
    eval { require Devel::Peek; 1 }) {
    *mymstat = sub {
	my $time = defined &Tk::timeofday ? Tk::timeofday() : time;
	printf STDERR "%-30s: %.2f  %.2f\n", "@_", $time-$BBBikeDebug::start, (defined $BBBikeDebug::last ? $time-$BBBikeDebug::last : 0);
	Devel::Peek::mstat();
	$BBBikeDebug::last = $time;
    }
} else { 
    *mymstat = sub {
	my $time = defined &Tk::timeofday ? Tk::timeofday() : time;
	printf STDERR "%-30s: %.2f  %.2f\n", "@_", $time-$BBBikeDebug::start, (defined $BBBikeDebug::last ? $time-$BBBikeDebug::last : 0);
	$BBBikeDebug::last = $time;
    }
}
mymstat("Begin");

if (eval { require Time::HiRes; 1 }) {
    my @bench_stack;
    *benchbegin = sub {
	my $sub = shift || (caller(1))[3];
	my $t0 = [ Time::HiRes::gettimeofday() ];
	printf STDERR " " x @bench_stack;
	printf STDERR "%s ...\n", $sub;
	push @bench_stack, { Time => $t0,
			     Sub  => $sub,
			   };
    };
    *benchend = sub {
	my $t1 = [ Time::HiRes::gettimeofday() ];
	my $bench_data = pop @bench_stack;
	my $elapsed = Time::HiRes::tv_interval($bench_data->{Time}, $t1);
	printf STDERR " " x @bench_stack;
	printf STDERR "%-30s: %.4f\n", $bench_data->{Sub}, $elapsed;
    };
} else {
    *benchbegin = *benchend = sub { };
}

1;

__END__

