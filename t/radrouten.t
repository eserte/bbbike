#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

# Test if all links (maps, lists) on radrouten.html are successful.
#
# Without -test-all or BBBIKE_LONG_TESTS set, only one random link is
# picked for testing (because the full test is quite slow).

use strict;
use FindBin;
use lib $FindBin::RealBin;

BEGIN {
    my @missing_mods;
    for my $mod (qw(HTML::TreeBuilder::XPath LWP::UserAgent Test::More URI)) {
	if (!eval qq{use $mod; 1}) {
	    push @missing_mods, $mod;
	}
    }
    if (@missing_mods) {
	print "1..0 # skip The following module(s) are/is missing: @missing_mods\n";
	exit;
    }
}

if ($ENV{BBBIKE_TEST_SKIP_MAPSERVER}) {
    plan skip_all => 'Skipping mapserver-related tests';
    exit;
}

use Getopt::Long;

use BBBikeTest qw(check_cgi_testing like_html $mapserverstaticurl);

check_cgi_testing;

my $test_all = !!$ENV{BBBIKE_LONG_TESTS};
my $test_matching;
GetOptions(
	   'test-all!'       => \$test_all,
	   'test-matching=s' => \$test_matching,
	  )
    or die "usage: $0 [-test-all | -test-matching rx]";

if ($test_all && $test_matching) {
    die "Can't specify -test-all and -test-matching together";
}
if ($test_matching) {
    $test_matching = qr{$test_matching};
}

plan 'no_plan';

my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent("BBBike-Test/1.0");
push @{ $ua->requests_redirectable }, 'POST'; # violating RFC 2616

my $root_url = $mapserverstaticurl . "/brb/radroute.html";
my $root_resp = $ua->get($root_url);
if (!ok $root_resp->is_success, "Fetching $root_url") {
 SKIP: {
	skip "No success - no need to continue further", 1;
    }
    exit 1;
}

my @test_defs;

my $p = HTML::TreeBuilder::XPath->new;
$p->parse($root_resp->decoded_content(charset => "none"));
for my $form_node ($p->findnodes('//form')) {
    my $action = $form_node->findvalue('./@action');
    my $url = URI->new_abs($action, $root_url)->as_string;
    my $name = $form_node->findvalue('.');
    $name =~ s{^[\xa0\s]+}{}; $name =~ s{[\xa0\s]+$}{};

    my @inputs = map {
	my($name, $value) = ($_->findvalue('./@name'), $_->findvalue('./@value'));
	if ($name =~ m{^(coords_forw|coords_rev)$}) { # simulate js function transform_coords_forw_rev
	    ('coords' => $value);
	} elsif ($name ne '') { # filter out submit buttons
	    ($name => $value);
	} else {
	    ();
	}
    } $form_node->findnodes('.//input');

    push @test_defs, {
		      name   => $name,
		      url    => $url,
		      inputs => \@inputs,
		     };
}
if (!@test_defs) {
    diag "Full content from $root_url:\n" . $root_resp->decoded_content(charset => 'none');
    BAIL_OUT("UNEXPECTED: no <FORM>s found. Probably radroute.html creation failed in some way.");
}

if ($test_matching) {
    @test_defs = grep { $_->{name} =~ $test_matching } @test_defs;
} elsif (!$test_all) {
    @test_defs = $test_defs[rand($#test_defs)];
    if (defined &note) {
	note("Without -test-all or BBBIKE_LONG_TESTS picking only one random test case...");
    }
}

for my $test_def (@test_defs) {
    my $url    = $test_def->{url};
    my @inputs = @{ $test_def->{inputs} };
    my $name   = $test_def->{name};

    my $resp_map = $ua->post($url, \@inputs);
    ok $resp_map->is_success, "$name ... map"
	or diag "POSTing to $url failed: " . $resp_map->status_line;
    my $map_content = $resp_map->decoded_content(charset => 'none');
    unlike $map_content, qr{<HEAD><TITLE>MapServer Message</TITLE></HEAD>}, "No MapServer (error) message title detected for $name ... map";
    unlike $map_content, qr{(Unknown identifier|Parsing error near)}, "No MapServer parsing error detected for $name ... map";
    unlike $map_content, qr{(Image handling error|Failed to draw layer named|DBASE file error|Invalid record number)}, "No MapServer rendering error detected for $name ... map";
    like_html $map_content, qr{<head><title>Berlin/Brandenburg - BBBike - Mapserver</title>}i, 'correct html title';
    like_html $map_content, qr{Letzte Aktualisierung der Daten:}, 'expected text pretty at the end';

    for my $i (0 .. $#inputs) {
	if ($inputs[$i] eq 'showroutelist') {
	    $inputs[$i+1] = 1;
	    last;
	}
    }

    my $resp_list = $ua->post($url, \@inputs);
    ok $resp_list->is_success, "$name ... list";
}

__END__
