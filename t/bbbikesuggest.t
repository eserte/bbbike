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
	use Encode;
	use File::Temp qw(tempfile);
	1;
    }) {
	print "1..0 # skip no Test::More, Tk, File::Temp and/or Encode modules\n"; # actually these should all be available...
	exit;
    }
}

BEGIN {
    if (!eval q{
	use Tk::PathEntry 2.17;
	1;
    }) {
	print "1..0 # skip no Tk::PathEntry module\n"; # ... but this one is optional
	exit;
    }
}

my $mw = eval { tkinit };
if (!$mw) {
    plan skip_all => 'No display available';
    CORE::exit(0);
}

plan tests => 7;

use BBBikeSuggest;

{
    my $suggest = BBBikeSuggest->new;
    isa_ok $suggest, 'BBBikeSuggest';
    $suggest->set_zipfile("$FindBin::RealBin/../data/Berlin.coords.data");
    is $suggest->{zip_file}, "$FindBin::RealBin/../data/Berlin.coords.data";
    ok exists $suggest->{zip_file_encoding};
    ok !$suggest->{zip_file_encoding}, 'encoding not defined -> iso-8859-1';
    my $sw = $suggest->suggest_widget($mw, -selectcmd => sub { warn shift->get });
    $sw->pack;
    $sw->destroy;
}

{
    my($tmpfh,$tmpfile) = tempfile(UNLINK => 1, SUFFIX => "_bbbikesuggest.t.utf8");
    binmode $tmpfh, ':encoding(utf-8)';
    open my $ifh, "$FindBin::RealBin/../data/Berlin.coords.data" or die $!;
    while(<$ifh>) {
	print $tmpfh $_;
    }
    close $ifh;
    close $tmpfh
	or die "Error while closing temporary file: $!";

    my $suggest = BBBikeSuggest->new;
    isa_ok $suggest, 'BBBikeSuggest';
    $suggest->set_zipfile($tmpfile, -encoding => 'utf-8');
    is $suggest->{zip_file}, $tmpfile;
    is $suggest->{zip_file_encoding}, 'utf-8', 'encoding is now utf-8';
    my $sw = $suggest->suggest_widget($mw, -selectcmd => sub {
					  binmode STDERR, ':encoding(utf-8)';
					  warn shift->get
				      });
    $sw->pack;
    $sw->focus;
}

if (exists $ENV{BATCH} && $ENV{BATCH} =~ m{^(0|no)$}) {
    MainLoop;
}

__END__
