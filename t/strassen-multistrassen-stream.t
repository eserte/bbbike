#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Strassen::Core;
use Strassen::MultiStrassen;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan 'no_plan';

{
    my $s = MultiStrassen->new_stream(
	Strassen->new_data_string_stream(<<'EOF'),
Street A	A 10,10
EOF
	Strassen->new_data_string_stream(<<'EOF'),
Street B	B 20,20
EOF
    );
    isa_ok $s, 'MultiStrassen';

    my @recs;
    $s->read_stream(
	sub {
	    my($r) = @_;
	    push @recs, $r;
	});
    is_deeply \@recs, [['Street A', ['10,10'], 'A'], ['Street B', ['20,20'], 'B']]
	or diag explain \@recs;
}

__END__
