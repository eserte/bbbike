#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: new_comments.t,v 1.1 2005/03/17 22:50:24 eserte Exp eserte $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../data",
	);
use Strassen;
use Strassen::StrassenNetzNew;

BEGIN {
    if (!eval q{
	use Test::More;
	die if ! -r "$FindBin::RealBin/../miscsrc/XXX_new_comments.pl";
	1;
    }) {
	print "1..0 # skip: no Test::More module or new_comments script\n";
	exit;
    }
}

BEGIN { plan tests => 1 }

require "$FindBin::RealBin/../miscsrc/XXX_new_comments.pl";

my $str_data = <<EOF;
Foobar	N 700,1000 1000,1000
Promenade, am Teltowkanal	N 1000,1000 1000,1300 1000,1600
Königsberger Str.	N 700,1300 1000,1300
EOF

my $qs_data = <<EOF;
Promenade: Route H	CS 1000,1000 1000,1300
Promenade: Parkweg, OK	Q1 1000,1000 1000,1300
EOF

my $str = Strassen->new_from_data_string($str_data);
my $net = StrassenNetz->new($str);
$net->make_net;

my $qs = Strassen->new_from_data_string($qs_data);
my $qs_net = StrassenNetz->new($qs);
$qs_net->make_net_cat(-net2name => 1, -multiple => 1);

my $handicap_net = StrassenNetz->new(Strassen->new("handicap_s"));
$handicap_net->make_net_cat;

my $comments_net = $qs_net;

my $comments_points = $net->make_comments_points;

my $fragezeichen_net = StrassenNetz->new(Strassen->new("fragezeichen"));
$fragezeichen_net->make_net_cat;

NewComments::set_data($net, $qs_net);

## Setup end

my($route) = $net->search("700,1000", "1000,1600",
			  AsObj => 1,
			 );

my $res = $net->extended_route_info(Route => $route,
				    City => "Berlin_DE",
				    GoalName => "Ziel!",
				    HandicapNet => $handicap_net,
				    CommentsNet => $comments_net,
				    CommentsPoints => $comments_points,
				    FragezeichenNet => $fragezeichen_net,
				   );
NewComments::process_data($res);

require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([
 map { $_->{Comment} } @{$res->{Route}}
],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

__END__
