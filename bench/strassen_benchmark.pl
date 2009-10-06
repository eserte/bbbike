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
use Getopt::Long;
use strict;

my $do_check;
GetOptions("check!" => \$do_check)
    or die "usage: $0 [-check] | [count]";

my $count = $do_check ? 1 : (shift || -3);

my @check_slow;
my @check_stream;
my @check_stream_nodir;
my @check_storable;
my @check_dbfile;

cmpthese($count,
	 {'slow'         => \&read_and_loop_slow,
	  'stream'	 => \&read_and_loop_stream,
	  'stream_nodir' => \&read_and_loop_stream_nodir,
	  'storable'     => \&read_and_loop_storable,
	  'dbfile_recno' => \&read_and_loop_dbfile,
	 });

if ($do_check) {
    require Test::More;
    Test::More->import(qw(no_plan));
    Test::More::is_deeply(\@check_stream,       \@check_slow, 'Check stream result'); 
    Test::More::is_deeply(\@check_stream_nodir, \@check_slow, 'Check stream result (without local directives)'); 
    Test::More::is_deeply(\@check_storable,     \@check_slow, 'Check storable result'); 
    Test::More::is_deeply(\@check_dbfile,       \@check_slow, 'Check dbfile result'); 
}

sub read_and_loop_slow {
    @check_slow = ();
    my $s = Strassen->new("strassen");
    loop($s, \@check_slow);
}

sub read_and_loop_storable {
    @check_storable = ();
    my $s = Strassen::Storable->new("strassen.st");
    loop($s, \@check_storable);
}

sub loop {
    my($s, $check_array) = @_;
    $s->init;
    while(1) {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS] };
	push @$check_array, $r;
    }
}

sub read_and_loop_stream {
    @check_stream = ();
    my $s = Strassen->new_stream('strassen');
    $s->read_stream(sub { push @check_stream, $_[0] });
}

sub read_and_loop_stream_nodir {
    @check_stream_nodir = ();
    my $s = Strassen->new_stream('strassen');
    $s->read_stream(sub { push @check_stream_nodir, $_[0] }, UseLocalDirectives => 0);
}

sub read_and_loop_dbfile {
    @check_dbfile = ();
    tie my @s, 'DB_File', "$FindBin::RealBin/../data/strassen", O_RDONLY, 0644, $DB_RECNO
	or die $!;
    my $s = new Strassen;
    $s->{Array} = \@s;
    $s->_dbfile_init;
    while(1) {
	my $r = $s->_dbfile_next;
	last if !@{ $r->[Strassen::COORDS] };
	push @check_dbfile, $r;
    }
}

sub Strassen::_dbfile_init {
    my($s) = @_;
    $s->{Pos} = -1;
}

sub Strassen::_dbfile_next {
    my($s) = @_;
    no warnings 'uninitialized';
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

FreeBSD 7 (amd64 machine) and perl 5.8.8:

               Rate      stream stream_nodir   storable        slow dbfile_recno
               Rate dbfile_recno      stream        slow stream_nodir   storable
dbfile_recno 3.12/s           --        -50%        -53%         -61%       -74%
stream       6.31/s         102%          --         -6%         -21%       -47%
slow         6.70/s         115%          6%          --         -16%       -44%
stream_nodir 7.98/s         156%         27%         19%           --       -33%
storable     11.9/s         280%         88%         77%          49%         --

A Linux (Debian lenny) machine with perl 5.10.0:

               Rate dbfile_recno      stream        slow stream_nodir   storable
dbfile_recno 2.96/s           --        -68%        -70%         -75%       -82%
stream       9.21/s         211%          --         -8%         -22%       -44%
slow         10.0/s         239%          9%          --         -15%       -39%
stream_nodir 11.9/s         301%         29%         18%           --       -28%
storable     16.5/s         457%         79%         65%          39%         --

=cut
