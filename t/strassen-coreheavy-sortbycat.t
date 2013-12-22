#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin",
	);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More and/or File::Temp module\n";
	exit;
    }
}

use Strassen::Core;

plan 'no_plan';

{
    my $bbd = <<'EOF';
AStreet	A 1,1 2,2
BStreet	B 3,3 4,4
CStreet	C 5,5 6,6
EOF

    {
	my $s = Strassen->new_from_data_string($bbd);
	my %cat_mapping = (A => 1, B => 2, C => 3);
	$s->sort_by_cat(\%cat_mapping);
	is $s->as_string, $bbd, 'unchanged';
    }

    {
	my $s = Strassen->new_from_data_string($bbd);
	my %cat_mapping = (A => 3, B => 2, C => 1);
	$s->sort_by_cat(\%cat_mapping);
	is $s->as_string, join("\n", reverse split /\n/, $bbd) . "\n", 'reversed';
    }

    {
	my $s = Strassen->new_from_data_string($bbd);
	$s->sort_by_cat(['C', 'B', 'A']);
	is $s->as_string, join("\n", reverse split /\n/, $bbd) . "\n", 'reversed, using an array cat mapping';
    }
}

{
    my $bbd = <<'EOF';
#: global_directive: yes
#:
#: directive_for: AStreet
AStreet	A 1,1 2,2
#: directive_for: BStreet
BStreet	B 3,3 4,4
#: directive_for: CStreet
CStreet	C 5,5 6,6
EOF

    my $s = Strassen->new_from_data_string($bbd, UseLocalDirectives => 1);
    my %cat_mapping = (A => 1, B => 2, C => 3);
    $s->sort_by_cat(\%cat_mapping);
    is $s->as_string, $bbd, 'unchanged, with directives'
	or diag "This test may fail if Tie::IxHash is not installed";
}

{
    local $TODO = "The logic behing -ignore seems to screw up sorting, because the comparison function is not transitive anymore";

    my $bbd = <<'EOF';
Unwichtiges Gewaesser	F:W0 1,1 2,2 3,3 1,1
Insel A im unwichtigen Gewaesser	F:I 1,1 2,2
Insel B im unwichtigen Gewaesser	F:I 3,3 1,1
Gewaesser	F:W1 11,11 21,12 31,13 11,11
Insel C im Gewaesser	F:I 11,11 21,12
Insel D im Gewaesser	F:I 31,13 11,11
Wichtiges Gewaesser	F:W2 111,111 211,112 311,113 111,111
Insel E im wichtigen Gewaesser	F:I 111,111 211,112
Insel F im wichtigen Gewaesser	F:I 311,113 111,111
EOF

    my $s = Strassen->new_from_data_string($bbd);
    $s->sort_by_cat(['F:W2', 'F:W1', 'F:W0'], -ignore => ['F:I']);
    is $s->as_string, <<'EOF', 'unchanged, with -ignore switch';
Wichtiges Gewaesser	F:W2 111,111 211,112 311,113 111,111
Insel E im wichtigen Gewaesser	F:I 111,111 211,112
Insel F im wichtigen Gewaesser	F:I 311,113 111,111
Gewaesser	F:W1 11,11 21,12 31,13 11,11
Insel C im Gewaesser	F:I 11,11 21,12
Insel D im Gewaesser	F:I 31,13 11,11
Unwichtiges Gewaesser	F:W0 1,1 2,2 3,3 1,1
Insel A im unwichtigen Gewaesser	F:I 1,1 2,2
Insel B im unwichtigen Gewaesser	F:I 3,3 1,1
EOF
}

__END__
