#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

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

my $doit;
GetOptions("doit" => \$doit)
    or die "usage: $0 [-doit]";
if (!$doit) {
    plan skip_all => "Please run with -doit switch";
    exit 0;
}

plan tests => 1;

require Tk::SmoothShow;

my $mw = tkinit;
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

$mw->after(100, sub { Tk::SmoothShow::show($infobar) });
$mw->after(1100, sub { Tk::SmoothShow::hide($infobar) });

$mw->after(2100, sub { Tk::SmoothShow::show($infobar, -speed => 100, -wait => 5) });
$mw->after(3100, sub { Tk::SmoothShow::hide($infobar, -speed => 100, -wait => 5) });

$mw->after(4100, sub { $mw->destroy });

MainLoop;

pass;

__END__
