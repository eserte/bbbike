#!/usr/bin/perl -w
# -*- mode:cperl;coding:raw-text; -*-

#
# $Id: route-pdf.t,v 1.16 2009/03/15 16:22:41 eserte Exp $
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
eval q{ use BBBikeXS; };
use Getopt::Long;

use BBBikeTest;

BEGIN {
    if (!eval q{
	use Test::More;
	use File::Temp qw(tempfile);
	1;
    }) {
	print "1..0 # skip no Test::More and/or File::Temp module(s)\n";
	exit;
    }
}

plan tests => 4;

my $lang;
if (!GetOptions("lang=s" => \$lang,
		get_std_opts(qw(display pdfprog)),
	       )) {
    die "usage: $0 [-lang lang] [-pdfprog pdfviewer] [-display]";
}

my(undef, $pdffile) = tempfile(SUFFIX => "_test.pdf",
			       UNLINK => 1);

my @arg = (-filename => $pdffile);

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
$rp->output(($lang ? (-lang => $lang) : ()),
	    -vianame => $via_name,
	    -commentsnet => $comments_net,
	    -net => $net,
	    -route => $route,
	   );
$rp->{PDF}->close;

maybe_display($pdffile);
trivial_pdf_test($pdffile);

{
    # testing with UTF-8 encoding --- currently does not work!
    my(undef, $pdffile) = tempfile(SUFFIX => "_test.pdf",
				   UNLINK => 1);
    my $s = Strassen->new_from_data_string(<<EOF);
#: encoding: utf-8
#:
Dudenstraße	X 100,100 200,200 300,300
Trg bana Jelačića	X 300,300 400,400 500,500
# Moskva, cyrillic:
Москва	X 500,500 600,600
EOF
    my $start = $s->get(0)          ->[Strassen::COORDS()]->[0];
    my $goal  = $s->get($s->count-1)->[Strassen::COORDS()]->[-1];

    my $net = StrassenNetz->new($s);
    $net->make_net;
    my($route) = $net->search($start, $goal, AsObj => 1);
    my $rp = Route::PDF->new(-filename => $pdffile);
    $rp->output(($lang ? (-lang => $lang) : ()),
		-net => $net,
		-route => $route,
	       );
    $rp->{PDF}->close;
    maybe_display($pdffile);
    trivial_pdf_test($pdffile);
}

sub maybe_display {
    my $pdffile = shift;
    if ($do_display) {
	do_display($pdffile);
	sleep 5; # for the displaying program to settle, otherwise the temporary file might be already deleted
    }
}

sub trivial_pdf_test {
    my $pdffile = shift;
    ok(-s $pdffile, "$pdffile is non-empty");
    open(PDF, $pdffile) or die $!;
    my $firstline = <PDF>;
    like($firstline, qr/^%PDF-1\.\d+/, "PDF magic in $pdffile");
}

__END__
