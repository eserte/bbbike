#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

# Test if all links (maps, lists) on radrouten.html are successful.

use strict;

BEGIN {
    if (!eval q{
	use HTML::TreeBuilder::XPath;
	use LWP::UserAgent;
	use Test::More;
	use URI;
	1;
    }) {
	print "1..0 # skip no HTML::TreeBuilder::XPath, LWP::UserAgent, URI, and/or Test::More modules\n";
	exit;
    }
}

use Getopt::Long;

my $doit;
GetOptions("doit" => \$doit)
    or die "usage: $0 [-doit]";

if (!$doit) {
    plan skip_all => "Tests only executed if -doit is given";
    exit 0;
}

plan 'no_plan';

my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent("BBBike-Test/1.0");
push @{ $ua->requests_redirectable }, 'POST'; # violating RFC 2616

my $root_url = "http://localhost/bbbike/mapserver/brb/radroute.html";
my $root_resp = $ua->get($root_url);
ok $root_resp->is_success, "Fetching $root_url"
    or BAIL_OUT "No sucess - no need to continue further";

my $p = HTML::TreeBuilder::XPath->new;
$p->parse($root_resp->decoded_content(charset => "none"));
for my $form_node ($p->findnodes('//form')) {
    my $action = $form_node->findvalue('./@action');
    my $url = URI->new_abs($action, $root_url)->as_string;
    my $name = $form_node->findvalue('.');
    $name =~ s{^[\xa0\s]+}{}; $name =~ s{[\xa0\s]+$}{};

    my @inputs = map { ($_->findvalue('./@name') => $_->findvalue('./@value')) } $form_node->findnodes('.//input');
    my $resp_map = $ua->post($url, \@inputs);
    ok $resp_map->is_success, "$name ... map";

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
