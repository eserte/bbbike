#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: old_comments.t,v 1.17 2008/12/31 17:18:01 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..", $FindBin::RealBin);

use Getopt::Long;
use CGI qw();
use Data::Dumper;

BEGIN {
    if (!eval q{
	use Test::More;
	use LWP::UserAgent;
	use YAML::Syck qw(Load Dump);
	1;
    }) {
	print "1..0 # skip: no Test::More, LWP::UserAgent and/or YAML::Syck modules\n";
	exit;
    }
}

{
    #use POSIX qw(strftime);
    #use constant TODO_NEW_COMMENTS => "2009-11-01T12:00:00" gt strftime("%FT%T", localtime) && 'Known failures';
    use constant TODO_NEW_COMMENTS => 'Known failure (missing implementation for compressing Teilstrecke)';
}

use BBBikeTest qw(eq_or_diff);

BEGIN {
    if ($] < 5.006) {
	$INC{"warnings.pm"} = 1;
	*warnings::import = sub { };
	*warnings::unimport = sub { };
    }
}

$YAML::Syck::ImplicitUnicode = 1; # otherwise utf8 is wrong

no warnings 'qw';

my @urls;
if (defined $ENV{BBBIKE_TEST_CGIURL}) {
    push @urls, $ENV{BBBIKE_TEST_CGIURL};
} elsif (defined $ENV{BBBIKE_TEST_CGIDIR}) {
    push @urls, $ENV{BBBIKE_TEST_CGIDIR} . "/bbbike.cgi";
}

my $firstindex = 0;
my $v;
if (!GetOptions("cgiurl=s" => sub {
		    @urls = $_[1];
		},
		"firstindex=i" => \$firstindex,
		"v+" => \$v,
	       )) {
    die "usage: $0 [-cgiurl url] [-firstindex index] [-v]";
}

if (!@urls) {
    @urls = "http://localhost/bbbike/cgi/bbbike.cgi";
}

my @tests = (
	     # Czeminskistr. -> Julius-Leber-Brücke 
	     ["7603,8911", "7497,8916", <<EOF, "CP;"],
- 'gegen die Einbahnstraßenrichtung, ggfs. schieben': 1
- als Julius-Leber-Brücke ausgeschildert: 1
- {}
EOF
	     ["7497,8916", "7603,8911", <<EOF, "CP; Rückweg"],
- {}
- {}
- {}
EOF

	     # Hagelberger/Yorck
	     ["8773,9524", "8595,9495", <<EOF, "PI"],
- Kopfsteinpflaster: 1
- auf linken Gehweg fahren, Straßenseite an der Fußgängerampel Yorckstr./Katzbachstr. wechseln: 1
- {}
EOF
	     ["8777,9601", "8595,9495", <<EOF, "No PI, starting point outside"],
- {}
- {}
EOF
	     ["8648,9526", "8595,9495", <<EOF, "No PI, starting point inside"],
- {}
- {}
EOF

	     # Bergmannstr.
	     ["9248,9350", "10533,9240", <<EOF, "CS (was Route, now no route here)"],
- Kopfsteinpflaster (Teilstrecke): 1
  TR4: 1
- {}
EOF

 	     # Belziger Str.
	     ["7315,9156", "6977,8934", <<EOF, "CS (Route)"],
- 'RR1': 1
  'RR12': 1
  'TR4': 1
  'mäßiges, teilweise holpriges Kopfsteinpflaster (Teilstrecke)': 1
- {}
EOF

	     # CP2; check
	     [qw(8102,11099 8184,11160), <<EOF, "CP2; am Startpunkt"],
- ausgeschildert zum Reichpietschufer 22: 1
- {}
EOF
	     [qw(8184,11160 8102,11099), <<EOF, "Rückweg ohne Kommentare"],
- {}
- {}
EOF
	     # Bismarckplatz
	     [qw(2316,9400 2380,9402), <<EOF, "Hubertusallee als Teilstrecke"],
- als Hubertusallee ausgeschildert (Teilstrecke): 1
- {}
EOF

	     # Bismarckplatz
	     ["2947,9367", "2348,9398", <<EOF, "CP2; ohne Teilstrecke"],
- {}
- als Caspar-Theyß-Str. ausgeschildert: 1
- {}
EOF
	     ["2348,9398", "2947,9367", <<EOF, "Rückweg"],
- als Hubertusallee ausgeschildert (Teilstrecke): 1
- {}
- {}
EOF

	     # Lützowplatz
	     ["6732,10754", "6642,12010", <<EOF, "Mehrere Kommentare am gleichen Abschnitt", TODO_NEW_COMMENTS],
- als Lützowplatz ausgeschildert (Teilstrecke): 1
- {}
- {}
- R1: 1
  RR2: 1
  RR3: 1
- {}
EOF
	     ["6642,12010", "6732,10754", <<EOF, "Rückweg", TODO_NEW_COMMENTS],
- R1: 1
  RR2: 1
  RR3: 1
- {}
- {}
- als Lützowplatz ausgeschildert (Teilstrecke): 1
- {}
EOF
	    );

if ($firstindex) {
    @tests = @tests[$firstindex .. $#tests];
}

plan tests => scalar(@urls) * scalar(@tests) * 2;

my $ua = new LWP::UserAgent;
$ua->agent("BBBike-Test/1.0");

for my $cgiurl (@urls) {
    my $inx = -1 + $firstindex;
    for my $test (@tests) {
	$inx++;
	my($from, $to, $expected, $desc, $is_todo) = @$test;
	my $qs = get_qs($from, $to);
	my $url = "$cgiurl?$qs";
	my $res = $ua->get($url);
	ok($res->is_success, "Index $inx, $from - $to");
	my $got = Load($res->decoded_content);
	my $comments = [ map {
	    +{ map { ($_,1) } split /;\s+/, $_->{Comment} };
	} @{$got->{Route}} ];
	local $TODO;
	$TODO = $is_todo if ($is_todo);
	eq_or_diff($comments, Load("--- #YAML:1.0\n$expected"), $desc) or do {
	    if ($v) {
		diag Dumper $got;
	    }
	    diag Dump($comments);
	};
    }
}

sub get_qs {
    my($start_c, $ziel_c) = @_;
    my $qs = CGI->new({ startc => $start_c,
			zielc  => $ziel_c,
			pref_seen => 1,
			output_as => "yaml",
		      })->query_string;
    $qs;
}

__END__
