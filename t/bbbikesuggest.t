#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../babybike/lib",
	);

BEGIN {
    if (!eval q{
	use Test::More;
	use Tk;
	use Tk::PathEntry 2.17;
	1;
    }) {
	print "1..0 # skip no Test::More, Tk and/or Tk::PathEntry modules\n";
	exit;
    }
}

my $mw = eval { tkinit };
if (!$mw) {
    plan skip_all => 'No display available';
    CORE::exit(0);
}

plan tests => 3;

use_ok 'BBBikeSuggest';
my $suggest = BBBikeSuggest->new;
isa_ok $suggest, 'BBBikeSuggest';
$suggest->set_zipfile("$FindBin::RealBin/../data/Berlin.coords.data");
pass 'Setting zipfile was successful';
my $sw = $suggest->suggest_widget($mw, -selectcmd => sub { warn shift->get });
$sw->pack;

if (exists $ENV{BATCH} && $ENV{BATCH} =~ m{^(0|no)$}) {
    MainLoop;
}

__END__
