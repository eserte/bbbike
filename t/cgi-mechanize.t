#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgi-mechanize.t,v 1.22 2005/03/24 00:53:21 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use WWW::Mechanize;
	#use WWW::Mechanize::FormFiller;# not yet
	use URI::URL;
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More, URI::URL and/or WWW::Mechanize modules\n";
	exit;
    }
}

use FindBin;
use lib ("$FindBin::RealBin",
	 "$FindBin::RealBin/..",
	);
use BBBikeTest;

use Getopt::Long;

my @browsers;
		
if (!GetOptions(get_std_opts("cgiurl", "xxx"),
		'browser=s@' => \@browsers)) {
    die "usage: $0 [-cgiurl url] [-xxx] [-browser ...]";
}

if (!@browsers) {
    @browsers
	= ("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.3) Gecko/20040913",
	   "Lynx/2.8.3rel.1 libwww-FM/2.14 SSL-MM/1.4.1 OpenSSL/0.9.5a",
	   "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; [eburo v1.3]; Wanadoo 7.0 ; NaviWoo1.1)"
	  );
}
@browsers = map { "$_ BBBikeTest/1.0" } @browsers;

my $tests = 67; # XXX
plan tests => $tests * @browsers;

if ($do_xxx) {
    goto XXX;
}

######################################################################
# general testing

for my $browser (@browsers) {

    my $is_textbrowser = $browser =~ /lynx/i;
    my $can_javascript = $browser !~ /lynx/i;

    my $agent;
    #XXX my $formfiller;
    my $get_agent = sub {
	$agent = WWW::Mechanize->new();
	$agent->agent($browser);
	#XXX $formfiller = WWW::Mechanize::FormFiller->new();
	$agent->env_proxy();
    };

    my $result_search_form_button = sub {
	my($agent, $button_value) = @_;
	if (!$can_javascript) {
	    $agent->follow($button_value);
	} else {
	    my $form = $agent->form_name("search");
	    my($input) = grep { defined $_->{value} && $_->{value} eq $button_value } $form->inputs; # but $_->value should also work?!
	    # Extract javascript location.href=...
	    my $onclick = $input->{onclick};
	    if ($onclick =~ m{'(http://.*)'}) {
		my $new_url = $1;
		$agent->get($new_url);
	    } else {
		die "Cannot find link in <$onclick>";
	    }
	    #$agent->click_button(value => "Start beibehalten");
	}
    };


    {
	$get_agent->();

	$agent->get($cgiurl);
	like($agent->content, qr/BBBike/, "Emulating $browser, Startpage $cgiurl is not empty");
	my_tidy_check($agent);

	$agent->form_number(1) if $agent->forms and scalar @{$agent->forms};
	{
	    local $^W; $agent->current_form->value('start', 'duden');
	}
	;
	{
	    local $^W; $agent->current_form->value('ziel', 'sonntag');
	}
	;
	$agent->submit();
	my_tidy_check($agent);

	like($agent->content, qr/Kreuzung/, "On the crossing page");
	{
	    local $^W; $agent->current_form->value('startc', '8982,8781');
	}
	;			# Set Duden/Methfesselstr.
	{
	    local $^W; $agent->current_form->value('zielc', '14598,11245');
	}
	;			# Set Sonntag/Böcklinstr.
	$agent->submit();
	my_tidy_check($agent);

	like($agent->content, qr/Route/, "On the route result page");
	$agent->submit();

	like($agent->ct, qr{^image/}, "Content is image");
	$agent->back();

	{
	    my $formnr = (($agent->forms)[0]->attr("name") =~ /Ausweichroute/ ? 4 : 3);
	    $agent->form_number($formnr);
	}
	$agent->submit();
	my_tidy_check($agent);

	$result_search_form_button->($agent, 'Start beibehalten');

	my_tidy_check($agent);

	like($agent->content, qr/BBBike/, "On the startpage again ...");
	like($agent->content, qr/Sonntagstr./, "... with the start street preserved");

	{
	    local $^W; $agent->current_form->value('via', 'Heerstr');
	}
	;
	{
	    local $^W; $agent->current_form->value('ziel', 'Adlergestell');
	}
	;
	$agent->submit();
	my_tidy_check($agent);

	like($agent->content, qr/genaue/i, "expecting multiple matches");
	$agent->submit();
	my_tidy_check($agent);

	like($agent->content, qr/Kreuzung/, "On the crossing page");
	{
	    local $^W; $agent->current_form->value('zielc', '27342,-3023');
	}
	;			# Wernsdorfer Str.
	$agent->submit();
	my_tidy_check($agent);

	like($agent->content, qr/Route/, "On the route result page");
	{
	    my $formnr = (($agent->forms)[0]->attr("name") =~ /Ausweichroute/ ? 3 : 2);
	    $agent->form_number($formnr);
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
	my_tidy_check($agent);

	like($agent->content, qr/Route/, "Route in content");

	######################################################################
	# exact crossings
	$result_search_form_button->($agent, 'Start und Ziel neu eingeben');
	#XXX del: $agent->follow('Start und Ziel neu eingeben');
	$agent->current_form->value('start', 'seume/simplon');
	$agent->current_form->value('ziel', 'brandenburger tor (mitte)');
	$agent->submit;
	my_tidy_check($agent);

	like($agent->content, qr{Einstellungen}, "On the settings page");
	unlike($agent->content, qr{genaue.*kreuzung}i, "Crossings are exact");

    }

    ######################################################################
    # test for Kaiser-Friedrich-Str. (Potsdam) problem

 XXX: {

	$get_agent->();

	$agent->get($cgiurl);
	$agent->form_name("BBBikeForm");
	{
	    local $^W; $agent->current_form->value('start', 'kaiser-friedrich-str');
	}
	;
	{
	    local $^W; $agent->current_form->value('ziel', 'helmholtzstr');
	}
	;
	$agent->submit();
	my_tidy_check($agent);

	like($agent->content, qr/genaue.*startstr.*ausw/i, "Start is ambiguous");
	like($agent->content, qr/genaue.*zielstr.*ausw/i,  "Goal is ambiguous");

	$agent->form_name("BBBikeForm");

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
	    diag("Selection box is empty") if !$input->possible_values;
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
	    diag("Selection box is empty") if !$input->possible_values;
	}

	$agent->submit;
	my_tidy_check($agent);

	like($agent->content, qr{genaue kreuzung}i, "On the crossing page");

	like($agent->content, qr/Kuhfortdamm/, "Expected start crossing")
	    or diag $agent->uri;
	like($agent->content, qr/Mangerstr/, "Expected goal crossing")
	    or diag $agent->uri;

    }

    ######################################################################
    # test for Am Neuen Palais

    {

	$get_agent->();

	$agent->get($cgiurl);
	$agent->form_name("BBBikeForm");
	{
	    local $^W; $agent->current_form->value('start', 'am neuen palais');
	}
	;
	{
	    local $^W; $agent->current_form->value('ziel', 'dudenstr');
	}
	;
	$agent->submit();
	my_tidy_check($agent);

	like($agent->content, qr/genaue.*kreuzung.*angeben/i, "On the crossing page");
	like($agent->content, qr/\QAm Neuen Palais (F2.2) (Potsdam)/i,  "Correct start resolution (Neues Palais ...)");

    }

    ######################################################################
    # A street in Potsdam but not in "landstrassen"

    {

	$get_agent->();

	$agent->get($cgiurl);
	$agent->form_name("BBBikeForm");
	{
	    local $^W; $agent->current_form->value('start', 'Petri Dank');
	}
	;
	{
	    local $^W; $agent->current_form->value('ziel', 'Römische Bäder');
	}
	;
	$agent->submit();
	my_tidy_check($agent);

	# May have different results depending on $use_exact_streetchooser.
	# The first is with $use_exact_streetchooser=0, the second with
	# $use_exact_streetchooser=1. Actually the correct crossing in this case
	# should be the end of "Lennestr.", but the find-nearest-crossing code finds
	# only real crossing, not endpoints of streets.
	like($agent->content,
	     qr{(\QHans-Sachs-Str. (Potsdam)/Meistersingerstr. (Potsdam)\E
		|\QCarl-von-Ossietzky-Str. (Potsdam)/Lennéstr. (Potsdam)\E
	       )}ix,  "Correct goal resolution (Hans-Sachs-Str. ... or Lennestr. ...)");
	like($agent->content, qr{\QMarquardter Damm (Marquardt)/Schlänitzseer Weg (Marquardt)}i,  "Correct goal resolution (Marquardt ...)");
                           
    }

    ######################################################################
    # Test custom blockings

    # XXX:
    # {

    # $get_agent->();

    # $agent->get($cgiurl);
    # $agent->form_name("BBBikeForm");
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

	$get_agent->();

	$agent->get($cgiurl);
	$agent->form_name("BBBikeForm");
	{
	    local $^W; $agent->current_form->value('start', 'kleine parkstr');
	}
	;
	{
	    local $^W; $agent->current_form->value('ziel', 's lehrter bahnhof');
	}
	;
	$agent->submit();
	my_tidy_check($agent);

	like($agent->content, qr/Kleine Parkstr\..*ist nicht bekannt/i, "Street not in database");
	like($agent->content, qr{\Qhtml/newstreetform.html?\E.*\Qstrname=Kleine%20Parkstr}i, "newstreetform link");
	like($agent->content, qr{Lehrter Bahnhof.*?die nächste Kreuzung}is,  "S-Bhf.");
	like($agent->content, qr{Invalidenstr./Heidestr.}i,  "S-Bhf., next crossing");

    }

    ######################################################################
    # Brandenburger Tor: in Berlin and Potsdam

    {
	$get_agent->();

	$agent->get($cgiurl);
	$agent->form_name("BBBikeForm");
	{
	    local $^W; $agent->current_form->value('start', 'brandenburger tor');
	}
	;
	{
	    local $^W; $agent->current_form->value('ziel', 'seumestr');
	}
	;
	$agent->submit();
	my_tidy_check($agent);

	like($agent->content, qr/genaue.*startstr.*ausw/i, "Start is ambiguous");

	my $form = $agent->current_form;
	my $input = $form->find_input("start2");
	ok($input, "start2 input exists");
	for my $test (["Brandenburger Tor/Mitte among start alternatives",
		       qr/brandenburger tor.*mitte/i],
		      ["Brandenburger Tor/Potsdam among start alternatives",
		       qr/brandenburger tor.*potsdam/i],
		     ) {
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
	my_tidy_check($agent);

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
	my_tidy_check($agent);

	like($agent->content, qr/brandenburger tor.*potsdam/i, "Potsdam alternative selected");

	$agent->submit;
	my_tidy_check($agent);

	my %len;
	for my $winter_optimization ("", "WI1", "WI2") {
	    $form = $agent->current_form;
	    $input = $form->find_input("pref_winter");
	SKIP: {
		skip("winter_optimization not available", 2) if !defined $input;
		$input->value($winter_optimization);
		$agent->submit;
		my_tidy_check($agent);
		my($len) = $agent->content =~ /l.*?nge:.*?([\d\.]+)\s*km/;
		ok(defined $len, "Got length=$len with winter optimization=$winter_optimization");
		$len{$winter_optimization} = $len;
		$agent->back;
	    }
	}

    SKIP: {
	    skip("winter_optimization not available", 2) if !keys %len;
	    cmp_ok($len{""}, "<=", $len{"WI1"}, "No optimization is shortest");
	    cmp_ok($len{"WI1"}, "<=", $len{"WI2"}, "Strong optimization is farthest");
	}

    }

} # for

sub my_tidy_check {
    my($agent) = @_;
    my $uri = $agent->uri;
    $uri =~ s/^.*?\?/...?/;
    my $maxlen = 55;
    $uri = substr($uri, 0, $maxlen) . "..." if length($uri) > $maxlen;
    tidy_check($agent->content, "HTML check: $uri", -uri => $agent->uri);
}

__END__
