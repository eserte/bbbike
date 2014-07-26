#!/usr/bin/perl -w
# -*- perl -*-

use strict;

use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin",
	);

use Strassen::Core;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use BBBikeTest qw(eq_or_diff);

plan 'no_plan';

my $test_bbd = <<'EOF';
#: encoding: utf-8
#:
#: local_directive: val1
#: local_directive: val2
Alexanderstr.	H 20,20 30,30 40,40
Bleibtreustr.	N 50,50 60,60 70,70 80,80
#: local_directive: val3
Zobtener Str.	NN 100,100 200,200 300,300
EOF

{
    my $s = Strassen->new_from_data_string($test_bbd, UseLocalDirectives => 1);
    eval { $s->split_line(0, 0) };
    like $@, qr{Cannot split record .* at index 0};
    eval { $s->split_line(0, 2) };
    like $@, qr{Cannot split record .* at index 2};
    eval { $s->split_line(3, 1) };
    like $@, qr{No record at index 3};
}

{
    my $s = Strassen->new_from_data_string($test_bbd, UseLocalDirectives => 1);
    $s->split_line(0, 1);
    eq_or_diff $s->as_string, <<'EOF', 'splitting a line at the beginning with multiple local directives';
#: encoding: utf-8
#:
#: local_directive: val1 vvv
#: local_directive: val2 vvv
Alexanderstr.	H 20,20 30,30
Alexanderstr.	H 30,30 40,40
#: local_directive: ^^^
#: local_directive: ^^^
Bleibtreustr.	N 50,50 60,60 70,70 80,80
#: local_directive: val3
Zobtener Str.	NN 100,100 200,200 300,300
EOF
}

{
    my $s = Strassen->new_from_data_string($test_bbd, UseLocalDirectives => 1);
    $s->split_line(1, 2);
    eq_or_diff $s->as_string, <<'EOF', 'splitting a line in the middle without local directives';
#: encoding: utf-8
#:
#: local_directive: val1
#: local_directive: val2
Alexanderstr.	H 20,20 30,30 40,40
Bleibtreustr.	N 50,50 60,60 70,70
Bleibtreustr.	N 70,70 80,80
#: local_directive: val3
Zobtener Str.	NN 100,100 200,200 300,300
EOF
}

{
    my $s = Strassen->new_from_data_string($test_bbd, UseLocalDirectives => 1);
    $s->split_line(2, 1);
    eq_or_diff $s->as_string, <<'EOF', 'splitting a line at the end with a single local directive';
#: encoding: utf-8
#:
#: local_directive: val1
#: local_directive: val2
Alexanderstr.	H 20,20 30,30 40,40
Bleibtreustr.	N 50,50 60,60 70,70 80,80
#: local_directive: val3 vvv
Zobtener Str.	NN 100,100 200,200
Zobtener Str.	NN 200,200 300,300
#: local_directive: ^^^
EOF
}

{
    my $s = Strassen->new_from_data_string($test_bbd, UseLocalDirectives => 1);
    $s->multiple_split_line([[0,1], [2,1], [1,2]]);
    eq_or_diff $s->as_string, <<'EOF', 'multiple_split_line';
#: encoding: utf-8
#:
#: local_directive: val1 vvv
#: local_directive: val2 vvv
Alexanderstr.	H 20,20 30,30
Alexanderstr.	H 30,30 40,40
#: local_directive: ^^^
#: local_directive: ^^^
Bleibtreustr.	N 50,50 60,60 70,70
Bleibtreustr.	N 70,70 80,80
#: local_directive: val3 vvv
Zobtener Str.	NN 100,100 200,200
Zobtener Str.	NN 200,200 300,300
#: local_directive: ^^^
EOF
}

__END__
