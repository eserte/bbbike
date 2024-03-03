#!/usr/bin/perl -w
# -*- cperl -*-
# -*- coding: iso-8859-1 -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib $FindBin::RealBin;

use Cwd qw(realpath);
use IO::File;
use Encode qw(from_to);

BEGIN {
    if (!eval q{
	use IPC::Run qw(run binary);
	use File::Temp qw(tempfile tempdir);
	use Test::More;
	1;
    }) {
	print "1..0 # skip no IPC::Run, File::Temp and/or Test::More modules\n";
	exit;
    }
}

use BBBikeTest 'eq_or_diff';

plan 'no_plan';

sub run_grepstrassen ($$);

my $grepstrassen = realpath "$FindBin::RealBin/../miscsrc/grepstrassen";
ok $grepstrassen, 'Found grepstrassen';
ok -f $grepstrassen, 'Really found grepstrassen';

{
    my $out = run_grepstrassen "", [];
    is $out, '', 'empty file';
}

my $sample_bbd = <<'EOF';
#: global_directive: 4711
#:
#: local_directive: 12
Samplestreet	X1 100,100 200,200
#: local_directive: 24
Beispielstrasse	X2 200,200 300,300
Primjerulica	X3 300,300 400,400
EOF

######################################################################
# match category
{
    my $out = run_grepstrassen $sample_bbd, ["-cat", "X1", "-preserveglobaldirectives"];
    is $out, <<'EOF';
#: global_directive: 4711
#:
#: local_directive: 12
Samplestreet	X1 100,100 200,200
EOF
}

{
    my $out = run_grepstrassen $sample_bbd, ["-v", "-cat", "X1"];
    is $out, <<'EOF';
#:
#: local_directive: 24
Beispielstrasse	X2 200,200 300,300
Primjerulica	X3 300,300 400,400
EOF
}

{
    my $out = run_grepstrassen $sample_bbd, ["-catrx", "^X[12]"];
    is $out, <<'EOF';
#:
#: local_directive: 12
Samplestreet	X1 100,100 200,200
#: local_directive: 24
Beispielstrasse	X2 200,200 300,300
EOF
}

{
    my $out = run_grepstrassen $sample_bbd, ["-v", "-catrx", "^X[12]"];
    is $out, <<'EOF';
Primjerulica	X3 300,300 400,400
EOF
}

{
    my $out = run_grepstrassen $sample_bbd, ["-i", "-catrx", '^x3$'];
    is $out, <<'EOF';
Primjerulica	X3 300,300 400,400
EOF
}

######################################################################
# match name
{
    my $out = run_grepstrassen $sample_bbd, ["-name", "Samplestreet"];
    is $out, <<'EOF';
#:
#: local_directive: 12
Samplestreet	X1 100,100 200,200
EOF
}

{
    my $out = run_grepstrassen $sample_bbd, ["-v", "-name", "Samplestreet"];
    is $out, <<'EOF';
#:
#: local_directive: 24
Beispielstrasse	X2 200,200 300,300
Primjerulica	X3 300,300 400,400
EOF
}

{
    my $out = run_grepstrassen $sample_bbd, ["-namerx", "^(Sample|Beispiel)"];
    is $out, <<'EOF';
#:
#: local_directive: 12
Samplestreet	X1 100,100 200,200
#: local_directive: 24
Beispielstrasse	X2 200,200 300,300
EOF
}

{
    my $out = run_grepstrassen $sample_bbd, ["-v", "-namerx", "^(Sample|Beispiel)"];
    is $out, <<'EOF';
Primjerulica	X3 300,300 400,400
EOF
}

{
    my $out = run_grepstrassen $sample_bbd, ["-i", "-namerx", 'primjer'];
    is $out, <<'EOF';
Primjerulica	X3 300,300 400,400
EOF
}

######################################################################
# match code
{
    my $out = run_grepstrassen $sample_bbd, ["-code", '0'];
    is $out, '';
}

{
    my $out = run_grepstrassen $sample_bbd, ["-code", '1', '-v'];
    is $out, '';
}

{
    my $out = run_grepstrassen $sample_bbd, ["-code", '$r->[0] eq "Samplestreet"'];
    is $out, <<'EOF';
#:
#: local_directive: 12
Samplestreet	X1 100,100 200,200
EOF
}

{
    my $out = run_grepstrassen $sample_bbd, ["-code", '($dir->{local_directive}[0]||"") eq 12'];
    is $out, <<'EOF';
#:
#: local_directive: 12
Samplestreet	X1 100,100 200,200
EOF
}

######################################################################
# match directive
{
    my $out = run_grepstrassen $sample_bbd, ["-directive", "local_directive=12"];
    is $out, <<'EOF';
#:
#: local_directive: 12
Samplestreet	X1 100,100 200,200
EOF
}

{
    my $out = run_grepstrassen $sample_bbd, ["-v", "-directive", "local_directive=12"];
    is $out, <<'EOF';
#:
#: local_directive: 24
Beispielstrasse	X2 200,200 300,300
Primjerulica	X3 300,300 400,400
EOF
}

{
    my $out = run_grepstrassen $sample_bbd, ["-directive", "local_directive~."];
    is $out, <<'EOF';
#:
#: local_directive: 12
Samplestreet	X1 100,100 200,200
#: local_directive: 24
Beispielstrasse	X2 200,200 300,300
EOF
}

{
    my $out = run_grepstrassen $sample_bbd, ["-v", "-directive", "local_directive~."];
    is $out, <<'EOF';
Primjerulica	X3 300,300 400,400
EOF
}

######################################################################
# Sample with "valid"

my $sample_valid_bbd = <<'EOF';
#:
#: valid: -20120101
Samplestreet	X1 100,100 200,200
#: valid: 20120301-
Beispielstrasse	X2 200,200 300,300
#: valid: 20120201-20120401
Primjerulica	X3 300,300 400,400
Alwaysvalidalley	X4 400,400 500,500
EOF

{
    my $out = run_grepstrassen $sample_valid_bbd, [];
    is $out, $sample_valid_bbd;
}

{
    my $expected = <<'EOF';
Samplestreet	X1 100,100 200,200
Alwaysvalidalley	X4 400,400 500,500
EOF
    is run_grepstrassen($sample_valid_bbd, ["-valid", "20111231"]), $expected;
    is run_grepstrassen($sample_valid_bbd, ["-valid", "20120101"]), $expected;
}

{
    my $expected = <<'EOF';
Alwaysvalidalley	X4 400,400 500,500
EOF
    is run_grepstrassen($sample_valid_bbd, ["-valid", "20120102"]), $expected;
}

{
    my $expected = <<'EOF';
Primjerulica	X3 300,300 400,400
Alwaysvalidalley	X4 400,400 500,500
EOF
    is run_grepstrassen($sample_valid_bbd, ["-valid", "20120201"]), $expected;
}

{
    my $expected = <<'EOF';
Beispielstrasse	X2 200,200 300,300
Primjerulica	X3 300,300 400,400
Alwaysvalidalley	X4 400,400 500,500
EOF
    is run_grepstrassen($sample_valid_bbd, ["-valid", "20120301"]), $expected;
    is run_grepstrassen($sample_valid_bbd, ["-valid", "20120401"]), $expected;
}

{
    my $expected = <<'EOF';
Beispielstrasse	X2 200,200 300,300
Alwaysvalidalley	X4 400,400 500,500
EOF
    is run_grepstrassen($sample_valid_bbd, ["-valid", "20120402"]), $expected;
}

{
    my $sample_valid2_bbd = <<'EOF';
#:
#: another_directive: 21
#: valid: -2012-01-01
Samplestreet	X1 100,100 200,200
#: valid: 2012-03-01-
#: another_directive: 42
Beispielstrasse	X2 200,200 300,300
#: valid: 2012-02-01-2012-04-01
Primjerulica	X3 300,300 400,400
Alwaysvalidalley	X4 400,400 500,500
EOF
    my $expected = <<'EOF';
#:
#: another_directive: 42
Beispielstrasse	X2 200,200 300,300
Primjerulica	X3 300,300 400,400
Alwaysvalidalley	X4 400,400 500,500
EOF
    is run_grepstrassen($sample_valid2_bbd, ["-valid", "2012-03-01"]), $expected;
    is run_grepstrassen($sample_valid2_bbd, ["-valid", "2012-04-01"]), $expected;
}

{
    my $sample_inverted_valid_bbd = <<'EOF';
#: 
#: valid: 20140224-20170601
Bergiusstr.	H 14106,6663 14193,6556 14366,6337
#: valid: !20140224-20170601
Bergiusstr.	N 14106,6663 14193,6556 14366,6337
EOF
    my $expected_without_period = <<'EOF';
Bergiusstr.	N 14106,6663 14193,6556 14366,6337
EOF
    my $expected_within_period = <<'EOF';
Bergiusstr.	H 14106,6663 14193,6556 14366,6337
EOF
    is run_grepstrassen($sample_inverted_valid_bbd, ["-valid", "20140223"]), $expected_without_period;
    is run_grepstrassen($sample_inverted_valid_bbd, ["-valid", "20140224"]), $expected_within_period;
    is run_grepstrassen($sample_inverted_valid_bbd, ["-valid", "20170601"]), $expected_within_period;
    is run_grepstrassen($sample_inverted_valid_bbd, ["-valid", "20170602"]), $expected_without_period;
}

######################################################################
# the obscure -adddirectives switch
{
    my $directive_bbd = <<'EOF';
#:
#: XXX a directive with a	tab
Foo street	X 1,2 3,4
EOF
    my $expected_bbd = <<'EOF';
Foo street (a directive with a tab)	? 1,2 3,4
EOF
    run_grepstrassen($directive_bbd, ['-adddirectives', 'XXX']);
    # side effect (the basename "-" is used because we feed the bbd
    # data through stdin)
    my $generated_file = "/tmp/XXX_-.bbd";
    ok -f $generated_file;
    my $generated_contents = join '', IO::File->new($generated_file)->getlines;
    is $generated_contents, $expected_bbd, 'XXX added, tab removed, category changed';
    unlink $generated_file;
}

######################################################################
# -inner -onlyenclosed
{
    my($tmpfh,$tmpfile) = tempfile(UNLINK => 1, SUFFIX => ".bbd");
    print $tmpfh <<'EOF';
	X 8932,12076 8833,12064 8879,11946 8969,11958 9022,11775 8948,11760 9034,11493 9134,11513 9227,11227 9153,11221 9209,11007 9333,11027 9016,12088
EOF
    close $tmpfh or die $!;

    my $wilhelmstr_bbd = <<'EOF';
#: global: dir
#:
#: local: dir
Wilhelmstr.	H 8861,12125 8901,12008 8965,11825 8969,11814 9000,11727 9058,11564 9155,11283 9196,11165 9234,11056 9275,10932 9323,10791 9368,10641 9375,10616 9384,10536 9388,10393 9404,10250
EOF
    my $segs_bbd = run_grepstrassen($wilhelmstr_bbd, ['-inner', $tmpfile, '-onlyenclosed', '-preserveglobaldirectives']);
    eq_or_diff $segs_bbd, <<'EOF';
#: global: dir
#:
#: local: dir vvv
Wilhelmstr.	H 9000,11727 9058,11564
Wilhelmstr.	H 9196,11165 9234,11056
#: local: ^^^
EOF
}

######################################################################
# -innerbbox
{
    my $in_bbd = <<'EOF';
#: map: polar
#:
inner	X 13.5,52.5
outer1	X 10.5,52.5
outer2	X 13.5,50.5
outer2	X 16.5,52.5
EOF

    my $err;
    ok !run [$^X, $grepstrassen, '-innerbbox', '1,2,3'], '<', \$in_bbd, '2>', \$err;
    like $err, qr/-innerbox should consist of four comma-separated values, but got less/;
    ok !run [$^X, $grepstrassen, '-innerbbox', '1,2,3,4,5'], '<', \$in_bbd, '2>', \$err;
    like $err, qr/-innerbox should consist of four comma-separated values, but got more/;

    my $filtered_bbd = run_grepstrassen($in_bbd, ['-innerbbox', '13.0,52.0,14.0,53.0', '-preserveglobaldirectives']);
    eq_or_diff $filtered_bbd, <<'EOF';
#: map: polar
#:
inner	X 13.5,52.5
EOF
}

######################################################################
# -special
{
    my($tmpdir) = tempdir(CLEANUP => 1, TMPDIR => 1);
    my $test_strassen = "$tmpdir/teststrassen_$$";
    open my $ofh, ">", $test_strassen
	or die "Error while writing to $test_strassen: $!";
    binmode $ofh;
    print $ofh <<'EOF';
#: 
#: add_fragezeichen: Wurde die Umbenennung zu "Cornelius-Fredericks-Str." schon durchgef�hrt? H�ngen schon die neuen Stra�enschilder?
#: next_check: 2999-04-01
L�deritzstr.	N 6661,15921 6484,16085 6349,16213 6211,16343 6106,16433 6003,16521
EOF
    close $ofh or die $!;

    my $fragezeichen_result_bbd = "/tmp/fragezeichen_teststrassen_$$.bbd";

    {
	ok run [$^X, $grepstrassen, $test_strassen, '-special', 'fragezeichen'];
	ok -e $fragezeichen_result_bbd;
	my $fragezeichen_bbd = join '', IO::File->new($fragezeichen_result_bbd)->getlines;
	eq_or_diff $fragezeichen_bbd, <<'EOF', '-special fragezeichen result';
L�deritzstr. (Wurde die Umbenennung zu "Cornelius-Fredericks-Str." schon durchgef�hrt? H�ngen schon die neuen Stra�enschilder?)	? 6661,15921 6484,16085 6349,16213 6211,16343 6106,16433 6003,16521
EOF
	unlink $fragezeichen_result_bbd;
    }

    {
	ok run [$^X, $grepstrassen, $test_strassen, '-special', 'filternextcheck', '-special', 'fragezeichen'];
	ok -e $fragezeichen_result_bbd;
	my $fragezeichen_bbd = join '', IO::File->new($fragezeichen_result_bbd)->getlines;
	eq_or_diff $fragezeichen_bbd, '', '-special fragezeichen + filternextcheck result is empty';
	unlink $fragezeichen_result_bbd;
    }
}

######################################################################
# encoding tests
{
    my $sample_latin1_bbd = <<'EOF';
#: #: -*- coding: iso-8859-1 -*-
#: encoding: iso-8859-1
#:
�schelbrunner Weg	X1 100,100 200,200
EOF

    (my $sample_no_encoding_directive_bbd = $sample_latin1_bbd) =~ s{#: encoding.*\n}{};

    my $sample_utf8_bbd = $sample_latin1_bbd;
    from_to($sample_utf8_bbd, 'iso-8859-1', 'utf-8');
    $sample_utf8_bbd =~ s{iso-8859-1}{utf-8}g;	    

    for my $def (
		 [$sample_latin1_bbd,                'latin1 encoding'],
		 [$sample_no_encoding_directive_bbd, 'no encoding directive'],
		 [$sample_utf8_bbd,                  'utf-8 encoding'],
		) {
	my($bbd, $test_label) = @$def;

	{
	    my $out = run_grepstrassen $bbd, [];
	    eq_or_diff $out, $bbd, "bbd file with $test_label - roundtrip with no grepstrassen arguments";
	}

	{
	    my $out = run_grepstrassen $bbd, ['-preserveglobaldirectives'];
	    eq_or_diff $out, $bbd, "bbd file with $test_label - roundtrip with -preserveglobaldirectives";
	}
    }
}

######################################################################

sub run_grepstrassen ($$) {
    my($in_data, $args) = @_;
    my($out_data, $err);
    # "binary" is for Windows
    my $res = run [$^X, $grepstrassen, @$args], "<", binary, \$in_data, ">", binary, \$out_data, "2>", \$err;
    ok $res, "No error running grepstrassen @$args";
    {
	local $TODO;
	if ($Devel::Cover::VERSION && $Devel::Cover::VERSION <= 1.36) {
	    $TODO = "stderr unclean because of https://github.com/pjcj/Devel--Cover/issues/141";
	}
	is $err, '', 'Nothing in stderr';
    }
    $out_data;
}
__END__
