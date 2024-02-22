#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use File::Temp qw(tempdir);

use Strassen::MultiStrassen;

sub tie_ixhash_hidden ();

plan 'no_plan';

my $tempdir = tempdir("strassen-multistrassen-globdirs-XXXXXXXX", TMPDIR => 1, CLEANUP => 1);

{
    open my $ofh, ">", "$tempdir/0.bbd";
    binmode $ofh;
    print $ofh <<EOF;
XYZ	X -1,-1 -2,-2
EOF
    close $ofh or die $!;
}

{
    open my $ofh, ">", "$tempdir/1.bbd";
    binmode $ofh;
    print $ofh <<EOF;
#: encoding: utf-8
#: map: polar
#: globdir1: A
#: globdir2: B
#:
ABC	X 1,1 2,2
EOF
    close $ofh or die $!;
}

{
    open my $ofh, ">", "$tempdir/2.bbd";
    binmode $ofh;
    print $ofh <<EOF;
#: encoding: utf-8
#: map: bbbike
#:
DEF	X 2,2 3,3
EOF
    close $ofh or die $!;
}

{
    open my $ofh, ">", "$tempdir/3.bbd";
    binmode $ofh;
    print $ofh <<EOF;
#: encoding: utf-8
#: map: polar
#: globdir1: A
#: globdir2: DIFF
#: globdir3: C
#:
GHI	X 4,4 5,5
EOF
    close $ofh or die $!;
}

{
    my $ms = eval { MultiStrassen->new({unknown_option=>1}, "$tempdir/0.bbd") };
    like $@, qr{Unhandled options: unknown_option 1}, 'unknown option error message';
}

{
    my $ms = eval { MultiStrassen->new({on_globdir_mismatches=>"unknown_value"}, "$tempdir/0.bbd") };
    like $@, qr{on_globdir_mismatches can be only 'silent' \(default\), 'warn' or 'die'}, 'invalid value error message';
}

{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my $ms = MultiStrassen->new("$tempdir/0.bbd", "$tempdir/0.bbd");
    is "@warnings", "", 'no warnings';
    is_deeply $ms->get_global_directives, {}, 'no global directives generated';
    is $ms->global_directives_as_string, '', 'empty global directives string';
}

{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my $ms = MultiStrassen->new("$tempdir/1.bbd", "$tempdir/2.bbd");
    like "@warnings", qr/WARN: Mismatching coord systems. First was 'polar', this one \(.*.bbd\) is 'bbbike'/, 'expected coord warning';
    is $ms->get_global_directive('map'), 'polar', 'first map directive won';
    is $ms->get_global_directive('encoding'), 'utf-8', 'expected encoding directive';
    is $ms->get_global_directive('globdir1'), 'A', 'expected other directive';
 SKIP: {
	skip "Known to fail without Tie::IxHash (unexpected ordering)", 1 if tie_ixhash_hidden;
	is $ms->global_directives_as_string, <<EOF, 'ordered string';
#: encoding: utf-8
#: map: polar
#: globdir1: A
#: globdir2: B
#:
EOF
    }
}

{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my $ms = MultiStrassen->new("$tempdir/1.bbd", "$tempdir/3.bbd");
    is "@warnings", "", 'no warnings';
    is $ms->get_global_directive('globdir1'), 'A', 'common directive value';
    is $ms->get_global_directive('globdir2'), 'B', 'first one won';
    is $ms->get_global_directive('globdir3'), 'C', 'found in 2nd one only';
 SKIP: {
	skip "Known to fail without Tie::IxHash (unexpected ordering)", 1 if tie_ixhash_hidden;
	is $ms->global_directives_as_string, <<EOF, 'ordered string';
#: encoding: utf-8
#: map: polar
#: globdir1: A
#: globdir2: B
#: globdir3: C
#:
EOF
    }
}

{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my $ms = MultiStrassen->new({ on_globdir_mismatches => 'warn' }, "$tempdir/1.bbd", "$tempdir/3.bbd");
    like "@warnings", qr/WARN: Global directive globdir2 with differing values \('B' vs 'DIFF'\), use the first one\./, 'expected mismatch warning';
    is $ms->get_global_directive('globdir1'), 'A', 'common directive value';
    is $ms->get_global_directive('globdir2'), 'B', 'first one won';
    is $ms->get_global_directive('globdir3'), 'C', 'found in 2nd one only';
}

{
    my $ms = eval { MultiStrassen->new({ on_globdir_mismatches => 'die' }, "$tempdir/1.bbd", "$tempdir/3.bbd") };
    like $@, qr{ERROR: Global directive globdir2 with differing values \('B' vs 'DIFF'\)\.}, 'expected exception message';
    ok !$ms, 'no object created';
}

# Note: this test script will fail if Tie::IxHash is not installed,
# after all, it's a prereq. However, when called with Devel::Hide it
# should still pass.
sub tie_ixhash_hidden () {
    return 1 if defined &Devel::Hide::_is_hidden && Devel::Hide::_is_hidden("Tie/IxHash.pm");
}

__END__
