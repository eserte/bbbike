#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: Waitproc.pm,v 1.5 2000/11/30 15:10:03 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

=head1 NAME

Waitproc - a wait process

=head1 SYNOPSIS

    use Waitproc;
    waitproc();      # start rotor
    sleep 10;        # do something ...
    stop_waitproc(); # stop rotor

=cut

package Waitproc;
require Exporter;
@ISA = qw(Exporter);
@EXPORT    = qw(waitproc stop_waitproc);
@EXPORT_OK = qw(progress);

use vars qw($waitproc_pid $rotor $rotor_delay_time);

=head1 FUNCTIONS

=head2 waitproc()

Start a wait processs. The wait process will display a rotating line.

=cut

$rotor            = '\|/-' unless defined $rotor;
$rotor_delay_time = 0.07   unless defined $rotor_delay_time;

sub waitproc {
    eval {
	$waitproc_pid = fork;
	if ($waitproc_pid == 0) {
	    my $rotor_i = 0;
	    my $check_counter = 0;
	    $| = 1;
	    while (1) {
		print substr($rotor, $rotor_i, 1) . "\r";
		if (++$rotor_i >= length($rotor)) {
		    $rotor_i = 0;
		}
		select(undef, undef, undef, $rotor_delay_time);
		if ($rotor_delay_time &&
		    ++$check_counter > 1/$rotor_delay_time) {
		    $check_counter=0;
		    if (!kill 0 => getppid()) {
			warn "Parent process stopped, quiting waitprocess\n";
			CORE::exit();
		    }
		}
	    }
	    CORE::exit();
	}
	$waitproc_pid;
    };
}

=head2 stop_waitproc

Stop the wait process. It is strongly advised to put the code between
the waitproc/stop_waitproc pair in a eval block. Otherwise, if an
exception occurs in the code between, the parent process will stop but
the wait process will continue.

=cut

sub stop_waitproc {
    if (defined $waitproc_pid) {
	kill 9 => $waitproc_pid;
	undef $waitproc_pid;
    }
}

=head2 progress

Usage:

    use Waitproc;
    $i = Waitproc::progress(0, 10000);
    for ($$i = 0; $$i < 1000000; $$i++) { ... }

Es gibt noch Bugs, z.B. werden Shared Memory und Semaphoren nicht
richtig gelöscht und verhindern so einen erneuten Start. (Ich glaube nur bei
Abbruch mit Signalen).

=cut

sub progress {
    my($from, $to) = @_;
    my $iter;
    eval {
	require IPC::Shareable;

	$waitproc_pid = fork;

	if ($waitproc_pid) { # Server
	    my %options = (
			   'key' => 'paint',
			   'create' => 'yes',
			   'exclusive' => 'no',
			   'mode' => 0644,
			   'destroy' => 'yes',
			  );
	    tie $iter, 'IPC::Shareable', 'prgrs', \%options;
	    $iter = $from;

	} else {

	    %options = (
			'key' => 'paint',
			'create' => 'no',
			'exclusive' => 'no',
			'mode' => 0644,
			'destroy' => 'no',
		       );

	    my $i;
	    tie $i, IPC::Shareable, 'prgrs', \%options;

	    $| = 1;
	    while (1) {
		printf "%d%% ...   \r", 100*($i-$from)/($to-$from);
		select(undef, undef, undef, 0.1);
		last if ($i >= $to);
	    }
	    CORE::exit();
	}
    };
    \$iter;
}

=head2 set([$rotor],[$rotor_delay])

Set the rotor string and/or the rotor delay time (currently 0.07
seconss). The default rotor string is '\|/-', but you can change it
to, say, '.oOo'.

=cut

sub set {
    my($in_rotor, $in_rotor_delay_time) = @_;
    if (defined $in_rotor) {
	$rotor = $in_rotor;
    }
    if (defined $in_rotor_delay_time) {
	$rotor_delay_time = $in_rotor_delay_time;
    }
}

1;

__END__
