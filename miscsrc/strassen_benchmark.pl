#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen_benchmark.pl,v 1.2 2004/08/27 00:20:08 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
use Strassen::Storable;
use Strassen;
use Benchmark qw(cmpthese);
use DB_File;
use strict;

my $count = shift || -3;

cmpthese($count,
	 {'slow'         => \&read_and_loop_slow,
	  'stream'	 => \&read_and_loop_stream,
	  'stream_nodir' => \&read_and_loop_stream_nodir,
	  'storable'     => \&read_and_loop_storable,
	  'dbfile_recno' => \&read_and_loop_dbfile,
	 });

sub read_and_loop_slow {
    my $s = Strassen->new("strassen");
    loop($s);
}

sub read_and_loop_storable {
    my $s = Strassen::Storable->new("strassen.st");
    loop($s);
}

sub loop {
    my $s = shift;
    $s->init;
    while(1) {
	my $r = $s->next;
	last if @{ $r->[Strassen::COORDS] };
    }
}

sub read_and_loop_stream {
    my $s = Strassen->new_stream('strassen');
    $s->read_stream(sub { });
}

sub read_and_loop_stream_nodir {
    my $s = Strassen->new_stream('strassen');
    $s->read_stream(sub { }, UseLocalDirectives => 0);
}

sub read_and_loop_dbfile {
    tie my @s, 'DB_File', "$FindBin::RealBin/../data/strassen", O_RDONLY, 0644, $DB_RECNO
	or die $!;
    my $s = new Strassen;
    $s->{Array} = \@s;
    $s->_dbfile_init;
    while(1) {
	my $r = $s->_dbfile_next;
	last if @{ $r->[Strassen::COORDS] };
    }
}

sub Strassen::_dbfile_init {
    my($s) = @_;
    $s->{Pos} = -1;
}

sub Strassen::_dbfile_next {
    my($s) = @_;
    while ($s->{Array}[++($s->{Pos})] =~ m{^#}) {}
    $s->_dbfile_get($s->{Pos});
}

sub Strassen::_dbfile_get {
    my($s, $pos) = @_;
    Strassen::parse($s->{Array}[$pos]);
}

__END__

=pod

Results:

$ perl5.00503 ./strassen_benchmark.pl
Benchmark: running dbfile_recno, slow, storable, each for at least 3 CPU seconds...
dbfile_recno:  4 wallclock secs ( 2.09 usr +  1.14 sys =  3.23 CPU) @ 43.70/s (n=141)
        slow:  3 wallclock secs ( 3.31 usr +  0.16 sys =  3.47 CPU) @ 26.52/s (n=92)
    storable:  4 wallclock secs ( 3.51 usr +  0.34 sys =  3.85 CPU) @ 10.65/s (n=41)

$ perl5.7.2 ./strassen_benchmark.pl
Benchmark: running dbfile_recno, slow, storable, each for at least 3 CPU seconds...
dbfile_recno:  3 wallclock secs ( 1.85 usr +  1.24 sys =  3.09 CPU) @ 44.28/s (n=137)
        slow:  3 wallclock secs ( 2.89 usr +  0.25 sys =  3.14 CPU) @ 31.84/s (n=100)
    storable:  2 wallclock secs ( 2.75 usr +  0.34 sys =  3.09 CPU) @ 10.05/s (n=31)

$ perl5.8.0 miscsrc/strassen_benchmark.pl
Benchmark: running dbfile_recno, slow, storable for at least 3 CPU seconds...
dbfile_recno:  4 wallclock secs ( 1.73 usr +  1.37 sys =  3.09 CPU) @ 29.74/s (n=92)
        slow:  3 wallclock secs ( 2.94 usr +  0.14 sys =  3.08 CPU) @ 13.32/s (n=41)
    storable:  3 wallclock secs ( 2.86 usr +  0.27 sys =  3.12 CPU) @  7.04/s (n=22)

With a much newer machine (FreeBSD 7) and perl 5.8.8:

               Rate      stream stream_nodir   storable        slow dbfile_recno
stream       6.65/s          --         -21%       -73%        -76%         -92%
stream_nodir 8.45/s         27%           --       -66%        -69%         -90%
storable     24.8/s        273%         194%         --         -9%         -70%
slow         27.3/s        311%         224%        10%          --         -67%
dbfile_recno 82.9/s       1146%         881%       234%        203%           --

A Linux (Debian lenny) machine with perl 5.10.0:

               Rate      stream stream_nodir   storable dbfile_recno        slow
stream       11.4/s          --         -20%       -61%         -71%        -76%
stream_nodir 14.3/s         25%           --       -51%         -64%        -70%
storable     29.2/s        155%         104%         --         -26%        -39%
dbfile_recno 39.4/s        245%         176%        35%           --        -18%
slow         48.2/s        322%         237%        65%          22%          --

=cut
