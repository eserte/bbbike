#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: sternfahrt.t,v 1.6 2009/04/04 11:23:27 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
	use WWW::Mechanize;
	use WWW::Mechanize::FormFiller;
	1;
    }) {
	print "1..0 # skip: no Test::More, WWW::Mechanize and/or WWW::Mechanize::FormFiller modules\n";
	exit;
    }
}

use Getopt::Long;

my $year = 2007;
my $use_live;
GetOptions("live!" => \$use_live,
	   "year=i" => \$year,
	  )
    or die "usage: $0 [-live] [-year ....]";

my $host = $use_live ? "bbbike.de" : "radzeit.herceg.de";

plan tests => 7;

my $agent = WWW::Mechanize->new();
my $formfiller = WWW::Mechanize::FormFiller->new();
$agent->env_proxy();

my $init_url = 'http://'.$host.'/mapserver/brb/sternfahrt'.$year.'_init.html';
$agent->get($init_url);
ok($agent->success, "Sternfahrt init page")
    or diag("While getting <$init_url>: " . $agent->response->status_line);

$agent->follow_link(text_regex => qr((?-xism:Mapserver)));
ok($agent->success, "Followed redirect link");

$agent->follow_link(text_regex => qr((?i-xsm:liste.*treffpunkte)));
ok($agent->success, "Followed treffpunkte cgi");
ok($agent->content, qr{treffpunkte}i);

$agent->follow_link(text_regex => qr((?-xism:Sortiert.*nach.*Treffpunkt)));
ok($agent->success, "Sorted nach Treffpunkt");

$agent->follow_link(text_regex => qr((?-xism:Sortiert.*nach.*Zeit)));
ok($agent->success, "Sorted nach Zeit");

$agent->follow_link(text_regex => qr{Potsdam});
ok($agent->success, "Found Potsdam");

__END__
