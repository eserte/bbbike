#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-dbfile.t,v 1.5 2004/08/30 17:55:30 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data");

BEGIN {
    if (!eval q{
	use Test::More;
	use Strassen::DB_File;
	1;
    }) {
	print "1..0 # skip: no DB_File and/or Test::More modules\n";
	exit;
    }
}

#use Strassen::Core; # should be loaded with Strassen::DB_File
use Benchmark;

BEGIN { plan tests => 3 }

# memory benchmarks (as early as possible)

SKIP: {
    my(@s) = currmem();
    my $s = Strassen->new("strassen");
    my(@s1) = currmem();
    my $s2;
    eval { $s2 = Strassen::DB_File->new("strassen"); };
    skip "strassen not available or you have a buggy Berkeley DB", 3 if $@;

    my(@s2) = currmem();
    print "# Memory consumption\nStrassen:          @{[ $s1[1]-$s[1] ]} bytes\nStrassen::DB_File: @{[ $s2[1]-$s1[1] ]} bytes\n";

    is(ref $s2, 'Strassen::DB_File');
    ok($s2->isa('Strassen'));

 CHECK: {
	$s->init;
	$s2->init;
	while(1) {
	    my $r = $s->next;
	    my $r2 = $s2->next;
	    if (!@{ $r->[Strassen::COORDS] }) {
		ok(!@{ $r2->[Strassen::COORDS] });
		last CHECK;
	    }
	    if ($r->[Strassen::NAME] ne $r2->[Strassen::NAME]) {
		ok(0);
		last CHECK;
	    }
	    if ($r->[Strassen::CAT] ne $r2->[Strassen::CAT]) {
		ok(0);
		last CHECK;
	    }
	    if (@{$r->[Strassen::COORDS]} != @{$r2->[Strassen::COORDS]}) {
		ok(0);
		last CHECK;
	    }
	    for my $i (0 .. $#{$r->[Strassen::COORDS]}) {
		if ($r->[Strassen::COORDS][$i] ne $r2->[Strassen::COORDS][$i]) {
		    ok(0);
		    last CHECK;
		}
	    }
	}
    }

    # CPU benchmarks

    timethese(-1,
	      {'strassen'        => sub { Strassen->new("strassen") },
	       'strassen-dbfile' => sub { Strassen::DB_File->new("strassen") },
	      }
	     );

    timethese(-1,
	      {'strassen-get'        => sub { $s->get(1000); },
	       'strassen-dbfile-get' => sub { $s2->get(1000); },
	      }
	     );
}

# REPO BEGIN
# REPO NAME currmem /home/e/eserte/src/repository 
# REPO MD5 2ce7ad760d9fade2a34b7925df59759f

=item currmem([$pid])

=for category System

Return ($mem, $realmem) of the current process or process $pid, if $pid
is given.

=cut

sub currmem {
    my $pid = shift || $$;
    if (open(MAP, "/proc/$pid/map")) { # FreeBSD
	my $mem = 0;
	my $realmem = 0;
	while(<MAP>) {
	    my(@l) = split /\s+/;
	    my $delta = (hex($l[1])-hex($l[0]));
	    $mem += $delta;
	    if ($l[11] ne 'vnode') {
		$realmem += $delta;
	    }
	}
	close MAP;
	($mem, $realmem);
    } elsif (open(MAP, "/proc/$pid/maps")) { # Linux
	my $mem = 0;
	my $realmem = 0;
	while(<MAP>) {
	    my(@l) = split /\s+/;
	    my($start,$end) = split /-/, $l[0];
	    my $delta = (hex($end)-hex($start));
	    $mem += $delta;
	    if (!defined $l[5] || $l[5] eq '') {
		$realmem += $delta;
	    }
	}
	close MAP;
	($mem, $realmem);
    } else {
	undef;
    }
}
# REPO END


__END__
