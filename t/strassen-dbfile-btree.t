#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-dbfile-btree.t,v 1.2 2003/06/23 22:04:48 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data");

BEGIN {
    if (!eval q{
	use Test;
	use Strassen::DB_File_Btree;
	1;
    }) {
	print "1..0 # skip: no Test/DB_File modules\n";
	exit;
    }
}

BEGIN { plan tests => 12 }

my $tmpfile = "/tmp/test-dbfile-btree.db";

my $s = Strassen->new("strassen");
Strassen::DB_File_Btree::convert($s, $tmpfile);
ok(-e $tmpfile);

my $s2 = Strassen::DB_File_Btree->new($tmpfile);
ok(ref $s2, "Strassen::DB_File_Btree");

my $r = $s2->get_by_name("Dudenstr.");
ok($r);
ok($r->[Strassen::NAME], "Dudenstr.");
ok($r->[Strassen::CAT], "H");
ok(ref $r->[Strassen::COORDS], "ARRAY");
ok(@{$r->[Strassen::COORDS]} > 1);

my @r = $s2->get_all_by_name("Baruther Str.");
ok(scalar @r, 3);
ok($r[0]->[Strassen::NAME], "Baruther Str.");
ok($r[1]->[Strassen::CAT], "NN");
ok(ref $r[2]->[Strassen::COORDS], "ARRAY");
ok(@{$r[2]->[Strassen::COORDS]} > 1);

__END__
