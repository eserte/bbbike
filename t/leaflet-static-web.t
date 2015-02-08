#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);
use Getopt::Long;
use LWP::UserAgent ();
use Test::More 'no_plan';
use URI ();

use BBBikeTest qw(libxml_parse_html_or_skip check_cgi_testing $htmldir get_std_opts);

check_cgi_testing;

use BBBikeLeaflet::Template;

my $test_all;
GetOptions(get_std_opts('htmldir'),
	   "test-all" => \$test_all)
    or die "usage: $0 [--test-all]\n";

my $ua = LWP::UserAgent->new;

my $blt = BBBikeLeaflet::Template->new(use_old_url_layout => 1);
isa_ok $blt, 'BBBikeLeaflet::Template';

my $html = $blt->as_string;

SKIP: {
    my $html_doc = libxml_parse_html_or_skip(1, $html); # as we run under no_plan we don't care about exact number of skips
    for my $script_src_node (
			     $html_doc->findnodes('//script/@src'),
			     $html_doc->findnodes('//link/@href'),
			    ) {
	my $url = $script_src_node->textContent;

	my $u;
	if ($url =~ m{^https?:}) {
	    next if !$test_all;
	    $u = URI->new($url);
	} else {
	    $u = URI->new_abs($url, $htmldir);
	}
	$url = $u->as_string;
	my $resp = $ua->head($url);
	ok $resp->is_success, "success for HEAD $url"
	    or diag $resp->as_string;
    }
}

__END__
