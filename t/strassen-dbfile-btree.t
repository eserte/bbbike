#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-dbfile-btree.t,v 1.5 2009/02/25 23:41:49 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data");

BEGIN {
    if (!eval q{
	use File::Temp qw(tempfile);
	use Test;
	use Strassen::DB_File_Btree;
	1;
    }) {
	print "1..0 # skip no Test/DB_File/File::Temp modules\n";
	exit;
    }
}

BEGIN {
    if (!eval q{
	require Object::Iterate;
	1;
    }) {
	print "1..0 # skip no Object::Iterate module, needed for convert() method\n";
	exit;
    }
}

BEGIN { plan tests => 17 }

my(undef, $tmpfile) = tempfile(SUFFIX => "test-dbfile-btree.db",
			       UNLINK => 1);

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
my $nn_seen;
for (@r) {
    ok($_->[Strassen::NAME], "Baruther Str.");
    ok($_->[Strassen::CAT] =~ /^(N|NN)$/);
    if ($_->[Strassen::CAT] eq "NN") {
	$nn_seen++;
    }
}
ok($nn_seen, 1);
ok(ref $r[2]->[Strassen::COORDS], "ARRAY");
ok(@{$r[2]->[Strassen::COORDS]} > 1);

__END__
