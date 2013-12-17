#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

# You may call this script also with "keepcool", to simulate a busy
# system. For example
#
#    keepcool -sf 0.1 -sr 0.4 perl t/smoothshow.t -doit
#
# keepcool may be found at $CPAN/authors/id/A/AN/ANDK

use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";

BEGIN {
    if (!eval q{
	use Test::More;
	use Tk;
	1;
    }) {
	print "1..0 # skip no Test::More and/or Tk modules\n";
	exit;
    }
}

use Getopt::Long;

my $doit = !!$ENV{BBBIKE_LONG_TESTS};
GetOptions("doit" => \$doit)
    or die "usage: $0 [-doit]";
if (!$doit) {
    plan skip_all => "Please run with -doit switch";
    exit 0;
}

my $mw = eval { tkinit };
if (!Tk::Exists($mw)) {
    plan skip_all => "Cannot create MainWindow: $@";
    exit 0;
}

plan tests => 4;

require Tk::SmoothShow;

$mw->geometry("+20+20");
my $c = $mw->Canvas->pack(qw(-fill both -expand 1));

my $infobar;
{
    my %stdcolor = (-bg => 'yellow');
    $infobar = $c->Frame(Name => "blockingsinfobar", %stdcolor, -relief => 'raised', -borderwidth => 1);
    $infobar->Label(-text => "This is an infobar", %stdcolor)->pack(-side => "left");
    $infobar->Button(-padx => 1, -pady => 1, -borderwidth => 1,
		     -text => "Test",
		    )->pack(-side => "left", -padx => 10);
    $infobar->idletasks; # to force -reqheight to be set
}

my $test_step = -1;
$mw->after(100, \&test_step);

sub test_step {
    $test_step++;
    if      ($test_step == 0) {
	Tk::SmoothShow::show($infobar, -completecb => \&test_step);
    } elsif ($test_step == 1) {
	pass 'Completely shown';
	$mw->after(500, sub { Tk::SmoothShow::hide($infobar, -completecb => \&test_step) });
    } elsif ($test_step == 2) {
	pass 'Completely hidden';
	$mw->after(100, sub { Tk::SmoothShow::show($infobar, -speed => 100, -wait => 5, -completecb => \&test_step) });
    } elsif ($test_step == 3) {
	pass 'Completely shown, non-default opts';
	$mw->after(500, sub { Tk::SmoothShow::hide($infobar, -speed => 100, -wait => 5, -completecb => \&test_step) });
    } elsif ($test_step == 4) {
	pass 'Completely hidden, non-default opts';
	$mw->after(500, sub { $mw->destroy });
    } else {
	die "Unexpected test step $test_step";
    }
}

MainLoop;

__END__
