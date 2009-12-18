#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-coreheavy.t,v 1.2 2006/09/30 13:30:49 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin",
	);

use Strassen::Core;
use Strassen::MultiStrassen;

use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test::More;
	use File::Temp qw(tempdir);
	use Tie::File;
	1;
    }) {
	print "1..0 # skip no Test::More and/or FIle::Temp module\n";
	exit;
    }
}

my $v;
GetOptions("v" => \$v)
    or die "usage: $0 [-v]";

plan tests => 52;

use_ok("Strassen::CoreHeavy");

my $tempdatadir = tempdir(CLEANUP => 1);
die if !$tempdatadir;

my $bbd1 = "$tempdatadir/onlytest_1.bbd";

# for Multi testing
my @multibbd = ("$tempdatadir/onlytest_2.bbd",
		"$tempdatadir/onlytest_3.bbd");

{
    open my $ofh, "> $bbd1"
	or die "Can't write $bbd1: $!";
    print $ofh <<EOF;
test1	X 1000,1000 1100,1100
EOF
    close $ofh
	or die $!;
}

my $s1 = Strassen->new($bbd1);

{
    isa_ok($s1, "Strassen");
    tests_without_changing($s1);
}


{
    diag "Sleep 1s so we have really a later modtime..."
	if $v;
    sleep 1;
    open my $ofh, ">> $bbd1"
	or die $!;
    print $ofh <<EOF;
Addition	X 2000,2000 2100,2100
EOF
    close $ofh
	or die $!;
}

{
    cmp_ok($s1->{Modtime}, "<", ((stat($s1->dependent_files))[9]));
    ok(!$s1->is_current, "Not anymore current");
    $s1->reload;
    is($s1->count, 2, "Two records now");
}

my $s2 = Strassen->new($bbd1);

{
    isa_ok($s2, "Strassen");

    {
	my($diff, $delref, $indexmappingref) = $s2->diff_orig;
	isa_ok($diff, "Strassen");
	is($diff->count, 1, "One record added");
	like($diff->data->[0], qr{^Addition});
	is(scalar(@$delref), 0, "Nothing to delete");
    }
}

$s2->copy_orig;

{
    diag "Sleep 1s so we have really a later modtime..."
	if $v;
    sleep 1;
    tie my @lines, "Tie::File", $bbd1
	or die $!;
    pop @lines;
}

my $s3 = Strassen->new($bbd1);

{
    isa_ok($s3, "Strassen");
    is($s3->count, 1);
    my($diff, $delref, $indexmappingref) = $s3->diff_orig;
    isa_ok($diff, "Strassen");
    is($diff->count, 0, "Nothing added");
    is(scalar(@$delref), 1, "One record deleted");
    is($delref->[0], 1, "Index of deleted record");
}

######################################################################
# MultiStrassen

{
    my $i = 0;
    for my $multibbd (@multibbd) {
	open my $ofh, "> $multibbd"
	    or die "Can't write $multibbd: $!";
	print $ofh <<EOF;
multi$i	X $i,$i
EOF
	close $ofh
	    or die $!;
    }
}

my $ms = MultiStrassen->new(@multibbd);

{
    isa_ok($ms, "Strassen");
    isa_ok($ms, "MultiStrassen");

    tests_without_changing($ms);
}

{
    diag "Sleep 1s so we have really a later modtime..."
	if $v;
    sleep 1;
    open my $ofh, ">> $multibbd[0]"
	or die $!;
    print $ofh <<EOF;
Addition	X 2000,2000 2100,2100
EOF
    close $ofh
	or die $!;
}

{

    my @dependent_files = $ms->dependent_files;
    is(scalar(@dependent_files), 2);
    cmp_ok($ms->{SubObj}->[0]->{Modtime}, "<", ((stat($dependent_files[0]))[9]));
    cmp_ok($ms->{SubObj}->[1]->{Modtime}, "==", ((stat($dependent_files[1]))[9]));
    ok(!$ms->is_current, "Not anymore current");
    $ms->reload;
    is($ms->count, 3, "Two records now");
}

my $ms2 = MultiStrassen->new(@multibbd);

{
    isa_ok($ms2, "MultiStrassen");

    {
	my($diff, $delref, $indexmappingref) = $ms2->diff_orig;
	isa_ok($diff, "Strassen");
	is($diff->count, 1, "One record added");
	like($diff->data->[0], qr{^Addition});
	is(scalar(@$delref), 0, "Nothing to delete");
    }
}

$ms2->copy_orig;

{
    diag "Sleep 1s so we have really a later modtime..."
	if $v;
    sleep 1;
    tie my @lines, "Tie::File", $multibbd[0]
	or die $!;
    pop @lines;
}

my $ms3 = MultiStrassen->new(@multibbd);

{
    isa_ok($ms3, "MultiStrassen");
    is($ms3->count, 2);
    my($diff, $delref, $indexmappingref) = $ms3->diff_orig;
    isa_ok($diff, "Strassen");
    is($diff->count, 0, "Nothing added");
    is(scalar(@$delref), 1, "One record deleted");
    is($delref->[0], 1, "Index of deleted record");
}

{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };

    my $s1 = Strassen->new;
    $s1->push(["Name1", ["1,2"], "X"]);
    $s1->set_global_directives({ map => ["polar"] });
    my $s2 = Strassen->new;
    $s2->push(["Name2", ["1,2"], "X"]);
    $s2->set_global_directives({ map => ["bbbike"] });
    my $ms = MultiStrassen->new($s1, $s2);

    like("@warnings", qr{Mismatching coord systems.*polar.*bbbike}, "Check for mismatched coord systems");
}

{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };

    my $s1 = Strassen->new;
    # empty data
    $s1->set_global_directives({ map => ["polar"] });
    my $s2 = Strassen->new;
    $s2->push(["Name2", ["1,2"], "X"]);
    $s2->set_global_directives({ map => ["bbbike"] });
    my $ms = MultiStrassen->new($s1, $s2);

    unlike("@warnings", qr{Mismatching coord systems.*polar.*bbbike}, "No warning for mismatched coord systems");
}


######################################################################
# Helpers
sub tests_without_changing {
    my($s1) = @_;

    ok($s1->is_current);

    {
	my $copy_res = $s1->copy_orig;
	ok($copy_res, "Copying of original");
    }

    
    {
	my $diff_orig_dir = $s1->get_diff_orig_dir;
	ok($diff_orig_dir);
	ok(-d $diff_orig_dir, "Diff orig directory existance");
	my $diff_orig_file = $s1->get_diff_file_name;
	ok(-f $diff_orig_file, "Diff orig file existance");
    }

    {
	my($diff, $delref, $indexmappingref) = $s1->diff_orig;
	isa_ok($diff, "Strassen");
	is($diff->count, 0, "Nothing new");
	is(scalar(@$delref), 0, "Nothing to delete");
    }
}


__END__
