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

my $test_longline_bbd = <<'EOF';
A track	X 10,10 20,20 30,30 40,40 50,50 60,60
EOF

my $test_cb = sub {
    my($side, $r) = @_;
    if ($side eq 'left') {
	push @{ $r->[Strassen::COORDS] }, '3,141';
    } elsif ($side eq 'right') {
	unshift @{ $r->[Strassen::COORDS] }, '2,718';
    } else {
	die "Should never happen: side='$side'";
    }
};

######################################################################
# split_line

{
    my $s = Strassen->new_from_data_string($test_bbd, UseLocalDirectives => 1);
    eval { $s->split_line(0, 3) };
    like $@, qr{Cannot split record .* at index 3};
    eval { $s->split_line(3, 1) };
    like $@, qr{No record at index 3};
    eval { $s->split_line(0, 0, unhandled_argument => 1) };
    like $@, qr{Unhandled options: unhandled_argument 1};
}

{
    my $s = Strassen->new_from_data_string($test_bbd, UseLocalDirectives => 1);
    $s->split_line(0, 0);
    eq_or_diff $s->as_string, $test_bbd, 'No-op: splitting on first coordinate in record';
}

{
    my $s = Strassen->new_from_data_string($test_bbd, UseLocalDirectives => 1);
    $s->split_line(0, 2);
    eq_or_diff $s->as_string, $test_bbd, 'No-op: splitting on last coordinate in record';
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

######################################################################
# split_line and callbacks

{
    my $s = Strassen->new_from_data_string($test_longline_bbd);
    $s->split_line(0, 0, cb => $test_cb);
    eq_or_diff $s->as_string, <<'EOF', 'callback action at beginning of record';
A track	X 2,718 10,10 20,20 30,30 40,40 50,50 60,60
EOF
}

{
    my $s = Strassen->new_from_data_string($test_longline_bbd);
    $s->split_line(0, 2, cb => $test_cb);
    eq_or_diff $s->as_string, <<'EOF', 'callback action in the middle of record';
A track	X 10,10 20,20 30,30 3,141
A track	X 2,718 30,30 40,40 50,50 60,60
EOF
}

{
    my $s = Strassen->new_from_data_string($test_longline_bbd);
    $s->split_line(0, 5, cb => $test_cb);
    eq_or_diff $s->as_string, <<'EOF', 'callback action at end of record';
A track	X 10,10 20,20 30,30 40,40 50,50 60,60 3,141
EOF
}

{
    my $s = Strassen->new_from_data_string($test_longline_bbd);
    $s->split_line(0, 2, insert_point => '30,35');
    eq_or_diff $s->as_string, <<'EOF', 'insert_point shortcut';
A track	X 10,10 20,20 30,30 30,35
A track	X 30,35 30,30 40,40 50,50 60,60
EOF
}

######################################################################
# multiple_split_line

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

{
    my $s = Strassen->new_from_data_string($test_longline_bbd);
    $s->multiple_split_line([[0,1], [0,3], [0,2]]);
    eq_or_diff $s->as_string, <<'EOF', 'multiple_split_line on one record';
A track	X 10,10 20,20
A track	X 20,20 30,30
A track	X 30,30 40,40
A track	X 40,40 50,50 60,60
EOF
}

__END__
