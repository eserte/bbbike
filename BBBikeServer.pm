# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1999,2001,2007,2019,2021,2023,2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

# XXX ~/devel/Tk-OneInstance-code verwenden...
package BBBikeServer;
use IO::Socket;
use IO::Handle;
use Net::hostent;
use Data::Dumper;
use strict;
use vars qw($name $args $VERBOSE $VERSION);
use Safe;

$VERSION = '1.24';

#$VERBOSE = 1 if !defined $VERBOSE;

my $bbbike_configdir = "$ENV{HOME}/.bbbike";
my $bbbike_port = 2453; # Vanity f�r "BIKE"
my $bbbike_server_pid;

my $use_inet = 0; #($^O eq 'MSWin32');

sub name {
    return $name if defined $name;
    $name = $ENV{DISPLAY};
    if ($name =~ /^:/) {
	require Sys::Hostname;
	my $hostname = Sys::Hostname::hostname();
	$name = $hostname . $name;
    }
    if ($name =~ /:\d+$/) {
	# canonify DISPLAY
	$name .= ".0";
    }
    $name;
}

sub pid {
    my $pid_filename = pid_filename();
    for (1..5) { # allow symlink to symlink to ...
	if (-l $pid_filename) {
	    $pid_filename = readlink $pid_filename;
	    if (!-l $pid_filename) {
		return $pid_filename;
	    }
	}
    }
    undef;
}

sub pid_filename {
    $bbbike_configdir . "/serverpid-" . name();
}

sub pipe_filename {
    $bbbike_configdir . "/server-" . name();
}

*unix_filename = \&pipe_filename;

# Process is running and has a writable socket
sub running {
    my $pid = pid();
    if (!defined $pid) {
	if ($VERBOSE) {
	    print STDERR "Cannot find pidfile from " . pid_filename() . "\n";
	}
	return undef;
    }
    if (!(kill 0 => $pid)) {
	if ($VERBOSE) {
	    print STDERR "Process $pid not running\n";
	}
	return undef;
    }
    # check zombie status (Linux only)
    if (open my $stat_file, "/proc/$pid/stat") {
	my $stat_line = <$stat_file>;
	my @stat_fields = split / /, $stat_line;
	my $process_state = $stat_fields[2];
	if ($process_state eq 'Z') {
	    if ($VERBOSE) {
		print STDERR "Process $pid is a zombie.\n";
	    }
	    return undef;
	}
    }
    if ($use_inet) {
	# wie testen? XXX
    } else {
	my $unix_filename = unix_filename();
	if (!-S $unix_filename || !-w $unix_filename) {
	    if ($VERBOSE) {
		print STDERR "Socket/pipe '$unix_filename' does not exist or is not writable\n";
	    }
	    return undef;
	}
    }
    1;
}

sub send_to_server {
    my(%args) = @_;
    send_to_socket_server(%args);
}

sub send_to_socket_server {
    my(%args) = @_;
    my($socket_name, $h);

    if ($use_inet) {
	$h = new IO::Socket::INET
	  Proto    => "tcp",
	  PeerAddr => "localhost",
	  PeerPort => $bbbike_port;
	return if !$h;
    } else {
	$socket_name = unix_filename();
	if (!-w $socket_name) {
	    die "Can't write to $socket_name";
	}
	if (!-S $socket_name) {
	    die "$socket_name is no socket";
	}
	$h = new IO::Socket::UNIX
	  Type => SOCK_STREAM,
	  Peer => $socket_name;
	return if !$h;
    }
    $Data::Dumper::Indent = 0;
    my $bbbike_args = Data::Dumper->Dump([$args{-argv}], ['args']);
    $bbbike_args =~ s/[\r\n]/ /sg;
    $h->print("$bbbike_args\n");
    $h->close;
    1;
}

sub create_pid {
    my $pidfile = pid_filename();
    unlink $pidfile;
    symlink $$, $pidfile;
}

sub create_server {
    my $top = shift;
    create_socket_server($top);
}

sub create_socket_server {
    my $top = shift;

    # Should work, as @INC within BBBike should be adjusted, but play safe...
    eval { require BBBikeUtil }; warn $@ if $@;

    pipe(PARENT_RDR, CHILD_WTR);
    pipe(CHILD_RDR,  PARENT_WTR);
    CHILD_WTR->autoflush(1);
    PARENT_WTR->autoflush(1);

    my $check_parent_interval = 60; # seconds

    my $parent_pid = $$;
    my $pid = fork;
    if (!$pid) { # child
	# XXX with this the child process dumps core on exit (as of Tk 800.017)
	#$SIG{INT} = sub { CORE::exit(0) };
	die "Can't fork: $!" if !defined $pid;
	close CHILD_RDR;
	close CHILD_WTR;
	{
	    local $^W;
	    $SIG{$_} = 'IGNORE' for @main::SIGTRAP_SIGNALS; @main::SIGTRAP_SIGNALS=@main::SIGTRAP_SIGNALS if 0;
	}
	my($socket_name, $h);
	if ($use_inet) {
	    $h = new IO::Socket::INET
	      Proto     => "tcp",
	      LocalPort => $bbbike_port,
	      Listen    => 1,
	      Reuse     => 1;
	} else {
	    $socket_name = unix_filename();
	    unlink $socket_name;
	    $h = new IO::Socket::UNIX
	      Type => SOCK_STREAM,
	      Local => $socket_name,
	      Listen => 1;
	    die "No socket in $socket_name created" if !-S $socket_name;
	    chmod 0700 => $socket_name;
	}
	die "Couldn't create server socket" if !$h;

	create_pid();

	alarm($check_parent_interval);
	local $SIG{ALRM} = sub {
	    if (!(kill 0 => $parent_pid)) {
		warn "ERROR: the bbbike parent process (pid=$parent_pid) does not seem to run anymore, stop the bbbike server process (pid=$$) too...\n";
		require POSIX;
		POSIX::_exit(1);
	    }
	    alarm($check_parent_interval);
	};
	while() { # SIGALRM would cause an EINTR, retry again...
	    my $client;
	    while($client = $h->accept()) {
		# XXX evtl. Zugangssperre (auf localhost �berpr�fen...)
		if ($use_inet) {
		    use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([gethostbyaddr($client->peeraddr)],[]); # XXX
		}
		my($str) = scalar <$client>;
		print PARENT_WTR $str;
		close $client;
	    }
	}
	require POSIX;
	POSIX::_exit(0); # never reached
    } else {
	close PARENT_RDR;
	close PARENT_WTR;

	$bbbike_server_pid = $pid; # if $use_inet;

	my $compartment = new Safe;
	$compartment->share('$args');

	$top->fileevent
	    (\*CHILD_RDR, "readable",
	     sub {
		 if (!(kill 0 => $pid)) {
		     warn "Server isn't running (anymore)...";
		     # unfortunetaly, the documentation is not true,
		     # so we have to do this manually:
		     $top->fileevent(\*CHILD_RDR, "readable", '');
		     return;
		 }
		 my($rin, $win, $ein) = ('','','');
		 vec($rin, fileno(CHILD_RDR),1) = 1;
		 $ein = $rin | $win;
		 my $nfound = select($rin, $win, $ein, 1);
		 if (!$nfound) {
		     warn "Timeout!\n";
		     return;
		 }

		 my $f = scalar <CHILD_RDR>;
		 if (!defined $f) { # eof?
		     close CHILD_RDR;
		     return;
		 }
		 $compartment->reval($f);
		 if ($@ || ref $args ne 'ARRAY') {
		     warn $@;
		     return;
		 }

		 eval {
		     my %args = @$args;
		     my $mark = $args{-mark};
		     if (exists $args{-center}) {
			 main::choose_from_plz(-str => $args{-center});
		     }
		     if (exists $args{-centerc}) {
			 main::choose_from_plz(-coord => $args{-centerc}, -mark => $mark);
		     }
		     if (exists $args{-from}) {
			 main::set_route_start_street($args{-from});
		     }
		     if (exists $args{-to}) {
			 main::set_route_ziel_street($args{-to});
		     }
		     if (exists $args{-routefile} &&
			 -r $args{-routefile}) {
			 # This used to check for .bbd explicitely and everything
			 # else is treated as a route, but it seems that
			 # plot_additional_layer accepts more formats
			 # automatically, including gpsman tracks
			 if ($args{-routefile} =~ m{\.bbr$}) {
			     warn "Read <$args{-routefile}> ...\n";
			     $main::center_loaded_route = $main::center_loaded_route if 0; # cease -w
			     local $main::center_loaded_route = 1;
			     main::load_save_route(0, $args{-routefile});
			 } else {
			     warn "Read <$args{-routefile}> as bbd ...\n";
			     my $type = 'str';
			     my $abk = main::plot_additional_layer($type, $args{-routefile});
			     if ($args{-strlist}) {
				 main::choose_ort($type, $abk, -rebuild => 1);
			     }
			 }
		     }
		 };
		 if ($@) {
		     main::status_message("A bbbikeclient command caused a failure:\n$@\nUsed bbbikeclient args: @$args", "err");
		 }
		 $top->deiconify;
		 $top->raise;
		 if (defined &BBBikeUtil::is_in_path && BBBikeUtil::is_in_path('wmctrl')) {
		     my @cmd = (qw(wmctrl -i -a), ($top->wrapper)[0]);
		     if ($VERBOSE) {
			 warn "Bring desktop to front using: @cmd\n";
		     }
		     system(@cmd);
		     if ($? != 0) {
			 warn "WARNING: running '@cmd' failed";
		     }
		 }
	     });
    }
}

sub server_cleanup {
    if (defined $bbbike_server_pid) {
	# ein CTRL-C bekommt auch der Server-Proze� ab, ansonsten
	# mu� manuell abgeschossen werden
	# INT geht nicht, muss mindestens TERM sein
	kill 'TERM' => $bbbike_server_pid;
    }

    if ($use_inet) {
	# do nothing (server process already killed)
    } else {
	unlink unix_filename();
    }
    unlink pid_filename();
}

1;

__END__
