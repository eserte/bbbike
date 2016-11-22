#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;

use Cwd qw(realpath);
use IO::File;

BEGIN {
    if (!eval q{
	use IPC::Run qw(run binary);
	use Test::More;
	1;
    }) {
	print "1..0 # skip no IPC::Run and/or Test::More modules\n";
	exit;
    }
}

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

sub run_grepstrassen ($$) {
    my($in_data, $args) = @_;
    my($out_data, $err);
    # "binary" is for Windows
    my $res = run [$^X, $grepstrassen, @$args], "<", binary, \$in_data, ">", binary, \$out_data, "2>", \$err;
    ok $res, "No error running grepstrassen @$args";
    is $err, '', 'Nothing is stderr';
    $out_data;
}
__END__
