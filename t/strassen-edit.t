#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-edit.t,v 1.1 2005/05/23 22:02:42 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Strassen::Core;
use Strassen::Edit;
use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

plan tests => 1;

{
    my $s = get_streets();
    $s->next;
    is($s->as_string, <<EOF, "well, blocks should be blocks again...");
#: XXX: block directive
First street\tX 1,2 3,4 5,6
#: XXX: block directive
Second street\tX 1,2 3,4 5,6
#: XXX: line directive
Third street\tX 1,2 3,4 5,6
Fourth street\tX 1,2 3,4 5,6
EOF

    $s->delete_current;
    is($s->as_string, <<EOF, "Delete at beginning");
#: XXX: block directive
Second street\tX 1,2 3,4 5,6
#: XXX: line directive
Third street\tX 1,2 3,4 5,6
Fourth street\tX 1,2 3,4 5,6
EOF
}

{
    my $s = get_streets();
    $s->set_last;
    $s->delete_current;
    is($s->as_string, <<EOF, "Delete last");
#: XXX: block directive
First street\tX 1,2 3,4 5,6
#: XXX: block directive
Second street\tX 1,2 3,4 5,6
#: XXX: line directive
Third street\tX 1,2 3,4 5,6
EOF
}

{
    my $s = get_streets();
    $s->set_index(2);
    $s->next;
    $s->delete_current;
    is($s->as_string, <<EOF, "Delete third street");
#: XXX: block directive
First street\tX 1,2 3,4 5,6
#: XXX: block directive
Second street\tX 1,2 3,4 5,6
Fourth street\tX 1,2 3,4 5,6
EOF
}

sub get_streets {
    my $s = Strassen->new_from_data_string(<<EOF, UseLocalDirectives => 1);
#:
#: XXX block directive vvv
First street	X 1,2 3,4 5,6
Second street	X 1,2 3,4 5,6
#: XXX ^^^
#: XXX line directive
Third street	X 1,2 3,4 5,6
Fourth street	X 1,2 3,4 5,6
EOF
    $s->init;
    $s;
}


