# Copyright (c) 1999-2000 João Pedro Gonçalves <joaop@sl.pt>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#XXX should be incorporated into the real GPS::Serial!!!
# Changed to use stty(1) by Slaven Rezic

package GPS::SerialStty;

use strict;
use vars qw($VERSION @ISA);
$VERSION = '0.01';

$|++;

sub serial { shift->{Fh} }

sub _read {
	#$self->_read(length)
	#reads packets from whatever you're listening from.
	#length defaults to 1

	my ($self,$len) = @_;
	$len ||=1;

	$self->serial or die "Read from an uninitialized handle";

	my $buf;
	sysread($self->serial,$buf,$len);

	if($self->{verbose} && $buf) {
		print "R:(",join(" ", map {$self->Pid_Byte($_)}unpack("C*",$buf)),")\n";
	}

	return $buf;
}

sub _readline {
	#$self->_readline()
	#reads until $/ is found
	#NMEA-aware - only lines beginning with $ count
	#if NMEA is the chosen protocol

	my ($self) = @_;
	my $line;
	$self->serial or warn "Read from an uninitialized handle";

	local $SIG{ALRM} = sub {die "GPS Device has timed out\n"};
	eval { alarm($self->{timeout}) };

	while(1) {

		$self->usleep(1) unless (length($line) % 32);
		my $buf .= $self->_read;
		$line .= $buf;
		if ($buf eq $/) {
			eval {alarm(0) };
			return ( ($self->{protocol} eq 'NMEA' && substr($line,0,1) ne '$') #'
				? $self->_readline
				: $line )
		}
	}
}

sub safe_read {
    #Reads one byte, escapes DLE bytes
	#Used by the GRMN Protocol
    my $self = shift;
    my $buf = $self->_read;
    $buf eq "\x10" ? $self->_read : $buf;
}

sub _write {
	#$self->_write(buffer,length)
	#syswrite wrapper for the serial device
	#length defaults to buffer length

	my ($self,$buf,$len,$offset) = @_;
	$self->connect() or die "Write to an uninitialized handle";

	$len ||= length($buf);

	if($self->{verbose}) {
#		print "W:(",join(" ", map {$self->Pid_Byte($_)}unpack("C*",$buf)),")\n";
		print "W:(",join(" ", unpack("C*",$buf)),")\n";
	}

    $self->serial or die "Write to an uninitialized handle";

	syswrite($self->serial,$buf,$len,$offset||0);
}

sub connect {
	my $self = shift;
	return $self->serial if $self->serial;

	$self->{serial} = $self->stty_connect;
	print "Using $$self{serialtype}\n" if $self->verbose;
}

sub stty_connect {
	#This was adapted from a script on connecting to a sony DSS, credits to its author (lost his email)
	my $self = shift;
	my $port = $self->{'port'};
	my $baud = $self->{'baud'};
	my($termios,$cflag,$lflag,$iflag,$oflag,$voice);

	if ($^O eq 'freebsd') {
		my $cc = join(" ", map { "$_ undef" } qw(eof eol eol2 erase erase2 werase kill quit susp dsusp lnext reprint status));
		system("stty <$port cs8 cread clocal ignbrk ignpar ospeed $baud ispeed $baud $cc");
		warn "stty failed" if $?;
		system("stty <$port -e");
	} else { # linux
		my $cc = join(" ", map { "$_ undef" } qw(eof eol eol2 erase werase kill intr quit susp start stop lnext rprnt flush));
		system("stty <$port cs8 clocal -hupcl ignbrk ignpar ispeed $baud ospeed $baud $cc");
		die "stty failed" if $?;
		system("stty <$port -a");
	}

	open(FH, "+>$port") or die "Could not open $port: $!\n";
	$self->{serialtype} = 'FileHandle';
	\*FH;
}

sub usleep {
    my $l = shift;
    $l = ref($l) && shift;
    select( undef,undef,undef,($l/1000));
}

sub serial { shift->{serial} }

sub verbose { shift->{verbose} }

1;
__END__
