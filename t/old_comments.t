#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: old_comments.t,v 1.3 2005/05/02 23:27:15 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Getopt::Long;
use CGI qw();
use Data::Dumper;

BEGIN {
    if (!eval q{
	use Test::More;
	use LWP::UserAgent;
	use YAML;
	1;
    }) {
	print "1..0 # skip: no Test::More, LWP::UserAgent and/or YAML modules\n";
	exit;
    }
}

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
    die "usage!";
}

if (!@urls) {
    @urls = "http://www/bbbike/cgi/bbbike.cgi";
}

my @tests = (
	     # Czeminskistr. -> Julius-Leber-Brücke 
	     ["7603,8911", "7497,8916", <<EOF, "CP;"],
- ''
- Als Julius-Leber-Brücke ausgeschildert
- ~
EOF
	     ["7497,8916", "7603,8911", <<EOF, "CP; Rückweg"],
- ''
- ''
- ~
EOF

	     # Hagelberger/Yorck
	     ["8773,9524", "8595,9495", <<EOF, "PI"],
- ! >-
  Kopfsteinpflaster; Straßenseite bei der Fußgängerampel
  Yorckstr./Katzbachstr. wechseln
- ''
- ~
EOF
	     ["8777,9601", "8595,9495", <<EOF, "No PI, starting point outside"],
- ''
- ~
EOF
	     ["8648,9526", "8595,9495", <<EOF, "No PI, starting point inside"],
- ''
- ~
EOF

	     # Bergmannstr.
	     ["9248,9350", "10533,9240", <<EOF, "CS (Route)"],
- Route K; Kopfsteinpflaster (Teilstrecke)
- ~
EOF

	     # Franz-Mehring-Platz
	     ["12811,12081", "12744,11904", <<EOF, "CP2; am Startpunkt"],
- Als Franz-Mehring-Platz ausgeschildert
- ~
EOF
	     ["12744,11904", "12811,12081", <<EOF, "Rückweg ohne Kommentare"],
- ''
- ~
EOF
	     ["12852,12306", "12744,11904", <<EOF, "Franz-Mehring-Platz als Teilstrecke"],
- Als Franz-Mehring-Platz ausgeschildert (Teilstrecke)
- ~
EOF

	     # Bismarckplatz
	     ["2947,9367", "2348,9398", <<EOF, "CP2; ohne Teilstrecke"],
- ''
- als Caspar-Theyß-Str. ausgeschildert
- ~
EOF
	     ["2348,9398", "2947,9367", <<EOF, "Rückweg"],
- als Hubertusallee ausgeschildert
- ''
- ~
EOF

	     # Lützowplatz
	     ["6732,10754", "6642,12010", <<EOF, "Mehrere Kommentare am gleichen Abschnitt"],
- Als Lützowplatz ausgeschildert (Teilstrecke)
- ''
- ''
- R1
- ~
EOF
	     ["6642,12010", "6732,10754", <<EOF, "Rückweg"],
- R1
- ''
- ''
- Als Lützowplatz ausgeschildert (Teilstrecke)
- ~
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
	my($from, $to, $expected, $desc) = @$test;
	my $qs = get_qs($from, $to);
	my $url = "$cgiurl?$qs";
	my $res = $ua->get($url);
	ok($res->is_success, "Index $inx, $from - $to");
	my $got = YAML::Load($res->content);
	my $comments = [ map { $_->{Comment} } @{$got->{Route}} ];
	is_deeply($comments, YAML::Load("--- #YAML:1.0\n$expected"), $desc) or do {
	    if ($v >= 2) {
		diag Dumper $got;
	    } elsif ($v) {
		diag YAML::Dump($comments);
	    }
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
