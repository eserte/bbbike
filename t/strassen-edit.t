#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-edit.t,v 1.4 2005/07/26 19:30:43 eserte Exp $
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
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan tests => 5;

{
    my $s = get_streets();
    $s->next;
    is($s->as_string, <<EOF, "Blocks are blocks again");
#:
#: XXX: block directive vvv
First street\tX 1,2 3,4 5,6
Second street\tX 1,2 3,4 5,6
#: XXX: ^^^
#: XXX: line directive
Third street\tX 1,2 3,4 5,6
Fourth street\tX 1,2 3,4 5,6
EOF

    $s->delete_current;
    is($s->as_string, <<EOF, "Delete at beginning");
#:
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
#:
#: XXX: block directive vvv
First street\tX 1,2 3,4 5,6
Second street\tX 1,2 3,4 5,6
#: XXX: ^^^
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
#:
#: XXX: block directive vvv
First street\tX 1,2 3,4 5,6
Second street\tX 1,2 3,4 5,6
#: XXX: ^^^
Fourth street\tX 1,2 3,4 5,6
EOF
}

{
    my $s = Strassen->new_from_data_string(<<EOF, UseLocalDirectives => 1);
#:
#: XXX line directive
First street	X 1,2 3,4
Second street	X 3,4 1,2
#: XXX block directive vvv
Third street	X 3,4 4,5
Not deleted 1	X 1,2 4,5
Not deleted 2	X 3,4 5,6
#: XXX ^^^
Not deleted 3	X 1,2 4,5
EOF
    $s->edit_all_delete_2_coord_lines("1,2", "3,4", "4,5");
    is($s->as_string, <<EOF, "edit_all_delete_2_coord_lines");
#:
#: XXX: block directive vvv
Not deleted 1	X 1,2 4,5
Not deleted 2	X 3,4 5,6
#: XXX: ^^^
Not deleted 3	X 1,2 4,5
EOF
}

######################################################################

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


