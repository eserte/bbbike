#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: route-pdf.t,v 1.8 2005/02/14 01:09:56 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	 "$FindBin::RealBin",
	);
use Route::PDF;
use Strassen::Core;
use Strassen::MultiStrassen;
use Strassen::StrassenNetz;
use Strassen::Dataset;
use BBBikeXS;
use Getopt::Long;

use BBBikeTest;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

BEGIN { plan tests => 1 }

$pdf_prog = "gv";
if (!GetOptions(get_std_opts(qw(display pdfprog)))) {
    die "usage: $0 [-pdfprog pdfviewer] [-display]";
}

my @arg;
# if ($do_display && $pdf_prog eq 'gv') {
#     open(GV, "|$pdf_prog -");
#     @arg = (-fh => \*GV);
# } else {
    @arg = (-filename => "/tmp/test.pdf");
# }

my $s = Strassen->new("strassen");
my $inacc = Strassen->new("inaccessible_strassen");
my $inacc_hash = $inacc->get_hashref;

my $net = StrassenNetz->new($s);
$net->make_net;

my $via_name;
my($start_coord, $via_coord, $goal_coord);
for my $coordref (\$start_coord, \$via_coord, \$goal_coord) {
    while(1) {
	my $r = $s->get(rand($#{$s->{Data}}));
	$$coordref = $r->[Strassen::COORDS][0];
	if ($coordref == \$via_coord) {
	    $via_name = $r->[Strassen::NAME];
	}
	last if (!exists $inacc_hash->{$$coordref});
    }
}

my($route) = $net->search($start_coord, $goal_coord,
			  Via => [$via_coord], AsObj => 1);

my $comments_net;
{
    my @s;
    for my $s ((map { "comments_$_" } @Strassen::Dataset::comments_types),
	       qw(handicap_s qualitaet_s)) {
	eval {
	    push @s, Strassen->new($s);
	};
	warn "$s: $@" if $@;
    }
    if (@s) {
	$comments_net = StrassenNetz->new(MultiStrassen->new(@s));
	$comments_net->make_net_cat(-net2name => 1, -multiple => 1);
    }
}

my $rp = Route::PDF->new(@arg);
$rp->output(-vianame => $via_name,
	    -commentsnet => $comments_net,
	    -net => $net, -route => $route);
$rp->{PDF}->close;

if (fileno(GV)) {
    close(GV);
} elsif ($do_display) {
    do_display("/tmp/test.pdf");
}

ok(1);

__END__
