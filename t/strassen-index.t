#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use File::Temp qw(tempdir);
use Test::More;

use Strassen::Index ();

plan tests => 8;

my $tmpdir = tempdir("strassenindexXXXX", TMPDIR => 1, CLEANUP => 1)
    or die $!;

my $s_file = "$tmpdir/strassen";
open my $ofh, ">", $s_file or die $!;
print $ofh <<EOF;
Avenue Paris	X 10,10 20,20
EOF
close $ofh
    or die $!;

{
    my $si = Strassen::Index->new($s_file);
    isa_ok $si, 'Strassen::Index';

    ok $si->needs_update, 'index file does not exist yet';

    $si->create_index;

    ok !$si->needs_update, 'now the index is up-to-date';

    ok $si->point_exists('10,10'), 'point exists';
    ok !$si->point_exists('11,11'), 'point does not exist';

    $si->add_point('12,12');
    ok $si->point_exists('12,12'), 'added point exists';

    $si->close_index;
}

{
    my $si = Strassen::Index->new($s_file);
    ok !$si->needs_update, 'after reopening index';
    $si->open_index;
    ok $si->point_exists('12,12'), 'added point still exists';
}

__END__
