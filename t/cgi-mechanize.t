#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgi-mechanize.t,v 1.3 2003/09/22 20:02:34 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More qw(no_plan);
	use WWW::Mechanize;
	use WWW::Mechanize::FormFiller;
	use URI::URL;
	1;
    }) {
	print "1..0 # skip: no Test::More and/or WWW::Mechanize modules\n";
	exit;
    }
}

my $cgiurl;
if (defined $ENV{BBBIKE_TEST_CGIURL}) {
    $cgiurl = $ENV{BBBIKE_TEST_CGIURL};
} elsif (defined $ENV{BBBIKE_TEST_CGIDIR}) {
    $cgiurl = $ENV{BBBIKE_TEST_CGIDIR} . "/bbbike.cgi";
} else {
    $cgiurl = 'http://www/bbbike/cgi/bbbike.cgi';
}

my $agent = WWW::Mechanize->new();
my $formfiller = WWW::Mechanize::FormFiller->new();
$agent->env_proxy();

$agent->get($cgiurl);
like($agent->content, qr/BBBike/);

$agent->form(1) if $agent->forms and scalar @{$agent->forms};
{ local $^W; $agent->current_form->value('start', 'duden'); };
{ local $^W; $agent->current_form->value('ziel', 'sonntag'); };
$agent->submit();

like($agent->content, qr/Kreuzung/);
{ local $^W; $agent->current_form->value('startc', '8982,8781'); };
{ local $^W; $agent->current_form->value('zielc', '14598,11245'); };
$agent->submit();

like($agent->content, qr/Route/);
$agent->submit();

#like($agent->content_type, qr{^image/}); # XXX how test?
$agent->back();

{
    my $formnr = (($agent->forms)[0]->attr("name") =~ /Ausweichroute/ ? 4 : 3);
    $agent->form($formnr);
}
$agent->submit();

$agent->follow('Start beibehalten');

like($agent->content, qr/BBBike/);
like($agent->content, qr/Sonntagstr./);

{ local $^W; $agent->current_form->value('via', 'Heerstr'); };
{ local $^W; $agent->current_form->value('ziel', 'Adlergestell'); };
$agent->submit();

like($agent->content, qr/genaue/i);
$agent->submit();

like($agent->content, qr/Kreuzung/);
{ local $^W; $agent->current_form->value('zielc', '27342,-3023'); };
$agent->submit();

like($agent->content, qr/Route/);
{
    my $formnr = (($agent->forms)[0]->attr("name") =~ /Ausweichroute/ ? 3 : 2);
    $agent->form($formnr);
}
eval { local $^W; $agent->current_form->value('pref_speed', '25'); };
is($@, "", "setting pref_speed ok");
eval { local $^W; $agent->current_form->value('pref_cat', 'N_RW'); };
is($@, "", "setting pref_cat ok");
eval { local $^W; $agent->current_form->value('pref_quality', 'Q2'); };
is($@, "", "setting pref_quality ok");
eval { local $^W; $agent->current_form->value('pref_ampel', 'yes'); };
is($@, "", "setting pref_ampel ok");
eval { local $^W; $agent->current_form->value('pref_green', 'GR2'); };
is($@, "", "setting pref_green ok");
$agent->submit();

like($agent->content, qr/Route/);

__END__
