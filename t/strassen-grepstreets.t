#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-grepstreets.t,v 1.1 2004/08/27 00:04:58 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data");

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

BEGIN { plan tests => 5 }

{
    my $s = Strassen->new;
    for (1..10) {
	$s->push(["Name$_", ["1,2","3,4"], "Cat".($_%2) ]);
    }
    my $new_s = $s->grepstreets(sub { $_->[Strassen::CAT] eq "Cat0" });
    is(scalar @{$new_s->{Data}}, 5);
}

{
    # check for local and global directives
    my $s = Strassen->new_from_data_string(<<EOF, UseLocalDirectives => 1);
#: global: directive
#:
#: local: directive
Street	X 1,1 2,2
Street	Y 2,2 3,3
EOF
    my $new_s = $s->grepstreets(sub { $_->[Strassen::CAT] eq 'X' });
    is(scalar @{ $new_s->{Data} }, 1, 'Only one street filtered out of two');
    is_deeply($new_s->get_directives(0), {}, 'Local directive not preserved');
    is_deeply($new_s->get_global_directive('global'), 'directive', 'Global directive was by default preserved');

    my $locprsrv_s = $s->grepstreets(sub { $_->[Strassen::CAT] eq 'X' }, -preservedir => 1);
    is_deeply($locprsrv_s->get_directives(0), $s->get_directives(0), 'Local directive was preserved');
}

__END__
