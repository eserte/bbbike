#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgi-mechanize.t,v 1.12 2004/12/04 22:50:51 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use WWW::Mechanize;
	use WWW::Mechanize::FormFiller;
	use URI::URL;
	use Test::More qw(no_plan);
	1;
    }) {
	print "1..0 # skip: no Test::More and/or WWW::Mechanize modules\n";
	exit;
    }
}

my $do_xxx;

use Getopt::Long;

my $cgiurl;
if (defined $ENV{BBBIKE_TEST_CGIURL}) {
    $cgiurl = $ENV{BBBIKE_TEST_CGIURL};
} elsif (defined $ENV{BBBIKE_TEST_CGIDIR}) {
    $cgiurl = $ENV{BBBIKE_TEST_CGIDIR} . "/bbbike.cgi";
} else {
    $cgiurl = 'http://www/bbbike/cgi/bbbike.cgi';
}

if (!GetOptions("cgiurl=s" => \$cgiurl,
		"xxx" => \$do_xxx,
	       )) {
    die "usage: $0 [-cgiurl url] [-xxx]";
}

if ($do_xxx) {
    goto XXX;
}

######################################################################
# general testing

{

my $agent = WWW::Mechanize->new();
#XXX my $formfiller = WWW::Mechanize::FormFiller->new();
$agent->env_proxy();

$agent->get($cgiurl);
like($agent->content, qr/BBBike/, "Startpage $cgiurl is not empty");

$agent->form(1) if $agent->forms and scalar @{$agent->forms};
{ local $^W; $agent->current_form->value('start', 'duden'); };
{ local $^W; $agent->current_form->value('ziel', 'sonntag'); };
$agent->submit();

like($agent->content, qr/Kreuzung/, "On the crossing page");
{ local $^W; $agent->current_form->value('startc', '8982,8781'); };
{ local $^W; $agent->current_form->value('zielc', '14598,11245'); };
$agent->submit();

like($agent->content, qr/Route/, "On the route result page");
$agent->submit();

#like($agent->content_type, qr{^image/}); # XXX how test?
$agent->back();

{
    my $formnr = (($agent->forms)[0]->attr("name") =~ /Ausweichroute/ ? 4 : 3);
    $agent->form($formnr);
}
$agent->submit();

$agent->follow('Start beibehalten');

like($agent->content, qr/BBBike/, "On the startpage again ...");
like($agent->content, qr/Sonntagstr./, "... with the start street preserved");

{ local $^W; $agent->current_form->value('via', 'Heerstr'); };
{ local $^W; $agent->current_form->value('ziel', 'Adlergestell'); };
$agent->submit();

like($agent->content, qr/genaue/i, "expecting multiple matches");
$agent->submit();

like($agent->content, qr/Kreuzung/, "On the crossing page");
{ local $^W; $agent->current_form->value('zielc', '27342,-3023'); };
$agent->submit();

like($agent->content, qr/Route/, "On the route result page");
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

}

######################################################################
# test for Kaiser-Friedrich-Str. (Potsdam) problem

{

my $agent = WWW::Mechanize->new;
#XXX my $formfiller = WWW::Mechanize::FormFiller->new();
$agent->env_proxy;

$agent->get($cgiurl);
$agent->form("BBBikeForm");
{ local $^W; $agent->current_form->value('start', 'kaiser-friedrich-str'); };
{ local $^W; $agent->current_form->value('ziel', 'helmholtzstr'); };
$agent->submit();

like($agent->content, qr/genaue.*startstr.*ausw/i, "Start is ambigous");
like($agent->content, qr/genaue.*zielstr.*ausw/i,  "Goal is ambigous");

$agent->form("BBBikeForm");

my $form = $agent->current_form;
my $input = $form->find_input("start2");
ok($input, "start2 input exists");
TRY: {
    my $testname = "Potsdam among start alternatives";
    for my $value ($input->possible_values) {
	if ($value =~ /potsdam/i) {
	    $input->value($value);
	    pass($testname);
	    last TRY;
	}
    }
    fail($testname);
}

$input = $form->find_input("ziel2");
ok($input, "ziel2 input exists");
TRY: {
    my $testname = "Potsdam among goal alternatives";
    for my $value ($input->possible_values) {
	if ($value =~ /potsdam/i) {
	    $input->value($value);
	    pass($testname);
	    last TRY;
	}
    }
    fail($testname);
}

$agent->submit;

like($agent->content, qr/Kuhfortdamm/);
like($agent->content, qr/Mangerstr/);

}

######################################################################
# test for Am Neuen Palais

{

my $agent = WWW::Mechanize->new;
#XXX my $formfiller = WWW::Mechanize::FormFiller->new();
$agent->env_proxy;

$agent->get($cgiurl);
$agent->form("BBBikeForm");
{ local $^W; $agent->current_form->value('start', 'am neuen palais'); };
{ local $^W; $agent->current_form->value('ziel', 'dudenstr'); };
$agent->submit();

like($agent->content, qr/genaue.*kreuzung.*angeben/i, "Crossings page");
like($agent->content, qr/\QAm Neuen Palais (F2.2) (Potsdam)/i,  "Correct start resolution (Neues Palais ...)");

}

######################################################################
# A street in Potsdam but not in "landstrassen"

{

my $agent = WWW::Mechanize->new;
#XXX my $formfiller = WWW::Mechanize::FormFiller->new();
$agent->env_proxy;

$agent->get($cgiurl);
$agent->form("BBBikeForm");
{ local $^W; $agent->current_form->value('start', 'Petri Dank'); };
{ local $^W; $agent->current_form->value('ziel', 'Römische Bäder'); };
$agent->submit();

like($agent->content, qr{\QHans-Sachs-Str. (Potsdam)/Meistersingerstr. (Potsdam)}i,  "Correct goal resolution (Hans-Sachs-Str. ...)");
like($agent->content, qr{\QMarquardter Damm (Marquardt)/Schlänitzseer Weg (Marquardt)}i,  "Correct goal resolution (Marquardt ...)");
                           
}

######################################################################
# Test custom blockings

# XXX:
# {

# my $agent = WWW::Mechanize->new;
# #XXX my $formfiller = WWW::Mechanize::FormFiller->new();
# $agent->env_proxy;

# $agent->get($cgiurl);
# $agent->form("BBBikeForm");
# { local $^W; $agent->current_form->value('start', 'gitschiner str'); };
# { local $^W; $agent->current_form->value('ziel', 'warschauer str'); };
# $agent->submit();

# $agent->submit;

# like($agent->content, qr{Oberbaumbr.*cke}, "Route contains Oberbaumbrücke");

# $agent->back;
# $agent->current_form->value(
# }

######################################################################
# test for a street in Berlin.coords.data but not in strassen

{

my $agent = WWW::Mechanize->new;
$agent->env_proxy;

$agent->get($cgiurl);
$agent->form("BBBikeForm");
{ local $^W; $agent->current_form->value('start', 'kleine parkstr'); };
{ local $^W; $agent->current_form->value('ziel', 's lehrter bahnhof'); };
$agent->submit();

like($agent->content, qr/Kleine Parkstr\..*ist nicht bekannt/i, "Street not in database");
like($agent->content, qr{\Qhtml/newstreetform.html?\E.*\Qstrname=Kleine%20Parkstr}i, "newstreetform link");
like($agent->content, qr{Lehrter Bahnhof.*?die nächste Kreuzung}is,  "S-Bhf.");
like($agent->content, qr{Invalidenstr./Heidestr.}i,  "S-Bhf., next crossing");

}

######################################################################
# Brandenburger Tor: in Berlin and Potsdam

XXX: {
my $agent = WWW::Mechanize->new;
$agent->env_proxy;

$agent->get($cgiurl);
$agent->form("BBBikeForm");
{ local $^W; $agent->current_form->value('start', 'brandenburger tor'); };
{ local $^W; $agent->current_form->value('ziel', 'seumestr'); };
$agent->submit();

like($agent->content, qr/genaue.*startstr.*ausw/i, "Start is ambigous");

my $form = $agent->current_form;
my $input = $form->find_input("start2");
ok($input, "start2 input exists");
for my $test (["Brandenburger Tor/Mitte among start alternatives",
	       qr/brandenburger tor.*mitte/i],
	      ["Brandenburger Tor/Potsdam among start alternatives",
	       qr/brandenburger tor.*potsdam/i],
	     )
    {
    TRY: {
	    my $testname = $test->[0];
	    my $rx       = $test->[1];
	    for my $value ($input->possible_values) {
		if ($value =~ $rx) {
		    pass($testname);
		    last TRY;
		}
	    }
	    fail($testname);
	}
    }

$input->value(($input->possible_values)[0]);
$agent->submit;

like($agent->content, qr/brandenburger tor.*mitte/i, "Mitte alternative selected");

$agent->back;

$form = $agent->current_form;
$input = $form->find_input("start2");
for my $value ($input->possible_values) {
    if ($value =~ /potsdam/i) {
	$input->value($value);
	last;
    }
}
$agent->submit;

like($agent->content, qr/brandenburger tor.*potsdam/i, "Potsdam alternative selected");

}
__END__
