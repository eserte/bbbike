#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: plz2.t,v 1.3 2009/06/30 21:03:24 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../data", "$FindBin::RealBin/../lib");
use PLZ;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

BEGIN { plan tests => 6 }

my $plz = PLZ->new;

{
    my $nok = 0;
    my @nok;
    my $h = $plz->street_words_hash;
    open(D, $plz->{File}) or die $!;

    if (1) {
	my $pos = 0;
	my $seen = {};
	while(<D>) {
	    /^(.+?)\|/;
	    my $s = $1;
	    if (!exists $seen->{$s}) {
		my @s = split /\s+/, $s;
		my $hh = $h->{$s[0]};
		for my $i (1 .. $#s) {
		    $hh = $hh->{$s[$i]};
		}
		if (ref $hh eq 'HASH') {
		    $hh = $hh->{""};
		}
		if ($pos != $hh) {
		    $nok++;
		    push @nok, "@s";
		}
		$seen->{$s} = undef;
	    }
	    $pos = tell D;
	}
	ok($nok, 0, join(", ", @nok));
    }

    {
	seek D, 0, 0;
	local $/ = undef;
	my $buf = <D>;
	$buf =~ s/[\|\n]/ /g;
	#open(XXX, ">/tmp/Berlin.coords.data.oneline")or die $!; print XXX $buf; close XXX;
	my $res = $plz->find_streets_in_text($buf, $h);
	ok(@$res > 0);
    }

    close D;

    if (0 && open(B, "$ENV{HOME}/bflnote")) {
	local $/ = undef;
	my $buf = <B>;
	require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$plz->find_streets_in_text($buf, $h)],[])->Indent(1)->Useqq(1)->Dump; # XXX

	close B;
    }
}

{
    my $h = $plz->streets_hash;
    ok(exists $h->{"Dudenstr."});
    ok(!exists $h->{"non-existing street"});
    open(D, $plz->{File}) or die $!;
    ok(exists $h->{'Heerstr.'});
    seek(D, $h->{"Heerstr."}, 0);
    my $s = <D>;
    ok($s =~ /^Heerstr/);
    close D;
}

__END__
