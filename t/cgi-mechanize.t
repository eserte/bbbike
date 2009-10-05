#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgi-mechanize.t,v 1.54 2009/01/24 09:06:55 eserte Exp $
# Author: Slaven Rezic
#

# Expect test failures if the server returns utf-8 encoded content, but
# the test script runs under perl 5.8.7 or older.

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

if ($WWW::Mechanize::VERSION == 1.54) {
    package WWW::Mechanize;
    local $^W;
    *_update_page = sub {
# kept original WWW::Mechanize indentation:
    my ($self, $request, $res) = @_;

    $self->{req} = $request;
    $self->{redirected_uri} = $request->uri->as_string;

    $self->{res} = $res;

    $self->{status}  = $res->code;
    $self->{base}    = $res->base;
    $self->{ct}      = $res->content_type || '';

    if ( $res->is_success ) {
        $self->{uri} = $self->{redirected_uri};
        $self->{last_uri} = $self->{uri};
    }

    if ( $res->is_error ) {
        if ( $self->{autocheck} ) {
            $self->die( 'Error ', $request->method, 'ing ', $request->uri, ': ', $res->message );
        }
    }

    $self->_reset_page;

    # Try to decode the content. Undef will be returned if there's nothing to decompress.
    # See docs in HTTP::Message for details. Do we need to expose the options there?
    my $content = $res->decoded_content(charset => 'none');
    $content = $res->content if (not defined $content);

    $content .= _taintedness();

    if ($self->is_html) {
        $self->update_html($content);
    }
    else {
        $self->{content} = $content;
    }

    return $res;
} # _update_page
} # monkey-patch end

use FindBin;
use lib ("$FindBin::RealBin",
	 "$FindBin::RealBin/..",
	);
use BBBikeTest;

use Getopt::Long;

my @browsers;
my $v;
my %do_xxx;
		
if (!GetOptions(get_std_opts("cgiurl", "xxx"),
		"v" => \$v,
		'browser=s@' => \@browsers,
		'xxx-petri-dank' => \$do_xxx{PETRI_DANK},
	       )) {
    die "usage: $0 [-cgiurl url] [-xxx|-xxx-petri-dank] [-v] [-browser ...]";
}

if (!@browsers) {
    @browsers
	= ("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.3) Gecko/20040913",
	   "Lynx/2.8.3rel.1 libwww-FM/2.14 SSL-MM/1.4.1 OpenSSL/0.9.5a",
	   "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; [eburo v1.3]; Wanadoo 7.0 ; NaviWoo1.1)"
	  );
}
@browsers = map { "$_ BBBikeTest/1.0" } @browsers;

my $outer_berlin_tests = 16;
my $tests = 110 + $outer_berlin_tests;
plan tests => $tests * @browsers;

######################################################################
# general testing

for my $browser (@browsers) {

    my $is_textbrowser = $browser =~ /^lynx/i;
    my $can_javascript = $browser !~ /^(lynx|dillo)/i;

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
	    $agent->follow_link(text => $button_value);
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

    my $like_long_data = sub {
	my($expected, $testname, $suffix) = @_;
	$suffix = ".html" if !defined $suffix;
	local $Test::Builder::Level = $Test::Builder::Level+1;
	like_long_data(get_ct($agent), $expected, $testname, $suffix)
	    or diag("URL is <" . $agent->uri . ">");
    };

    my $unlike_long_data = sub {
	my($expected, $testname, $suffix) = @_;
	$suffix = ".html" if !defined $suffix;
	local $Test::Builder::Level = $Test::Builder::Level+1;
	unlike_long_data(get_ct($agent), $expected, $testname, $suffix)
	    or diag("URL is <" . $agent->uri . ">");
    };

    my $known_on_2nd_page = sub {
	local $Test::Builder::Level = $Test::Builder::Level+1;
	$unlike_long_data->(qr/ist nicht bekannt/i, "Known street");
	$unlike_long_data->(qr/genaue kreuzung w.*hlen/i, "Exact match, no crossings");
	$like_long_data->(qr/Bevorzugte Geschwindigkeit/i, "Einstellungen page");
    };

    # -xxx... handling
    for my $key (keys %do_xxx) {
	if ($do_xxx{$key}) {
	    eval 'goto XXX_' . $key; die $@ if $@;
	}
    }
    if ($do_xxx) {
	goto XXX;
    }

    {
	$get_agent->();

	$agent->get($cgiurl);
	$like_long_data->(qr/BBBike/, "Emulating $browser, Startpage $cgiurl is not empty");
	my_tidy_check($agent);

	$agent->form_number(1) if $agent->forms and scalar @{$agent->forms};
	{
	    local $^W; $agent->current_form->value('start', 'duden');
	}
	;
	{
	    # This used to be just "sonntag", but now there are some
	    # new "Kolonien" starting with the same prefix...
	    local $^W; $agent->current_form->value('ziel', 'sonntagstr');
	}
	;
	$agent->submit();
	my_tidy_check($agent);

	$like_long_data->(qr/Kreuzung/, "On the crossing page");
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

	$like_long_data->(qr/Route/, "On the route result page");

	my $has_ausweichroute = ($agent->forms)[0]->attr("name") =~ /Ausweichroute/;
	{
	    my $formnr = $has_ausweichroute ? 2 : 1;
	    $agent->form_number($formnr);
	    $agent->submit();
	}

	like($agent->ct, qr{^image/}, "Content is image");
	$agent->back();

	{
	    my $formnr = $has_ausweichroute ? 4 : 3;
	    $agent->form_number($formnr);
	}
	$agent->submit();
	my_tidy_check($agent);

	$result_search_form_button->($agent, 'Start beibehalten');

	my_tidy_check($agent);

	$like_long_data->(qr/BBBike/, "On the startpage again ...");
	$like_long_data->(qr/Sonntagstr./, "... with the start street preserved");

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

	$like_long_data->(qr/genaue/i, "expecting multiple matches");
	$agent->submit();
	my_tidy_check($agent);

	$like_long_data->(qr/Kreuzung/, "On the crossing page");
	{
	    local $^W; $agent->current_form->value('zielc', '27360,-3042');
	}
	;			# Wernsdorfer Str.
	$agent->submit();
	my_tidy_check($agent);

	$like_long_data->(qr/Route/, "On the route result page");
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

	$like_long_data->(qr/Route/, "Route in content");

	######################################################################
	# exact crossings
	$result_search_form_button->($agent, 'Start und Ziel neu eingeben');
	#XXX del: $agent->follow('Start und Ziel neu eingeben');
	$agent->current_form->value('start', 'seume/simplon');
	$agent->current_form->value('ziel', 'brandenburger tor (mitte)');
	$agent->submit;
	my_tidy_check($agent);

	$like_long_data->(qr{Einstellungen}, "On the settings page");
	$unlike_long_data->(qr{genaue.*kreuzung}i, "Crossings are exact");

    }

    ######################################################################
    # A street in Potsdam but not in "landstrassen"

 XXX_PETRI_DANK: {

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
	# should be the end of "Lennéstr.", but the find-nearest-crossing code finds
	# only real crossing, not endpoints of streets.
	{
	    local $TODO;
	    $TODO = "Known to fail with perl 5.10.0 (regexp problem)"
		if $] == 5.010;
	    $like_long_data->(
	     qr{(\QHans-Sachs-Str. (Potsdam)/Meistersingerstr. (Potsdam)\E
		|\QCarl-von-Ossietzky-Str. (Potsdam)/Lennéstr. (Potsdam)\E
		|\Q(Ökonomieweg, Sanssouci) (Potsdam)/(Lennéstr. - Ökonomieweg, Sanssouci)\E
		|\Q(Ökonomieweg, Sanssouci)/(Lennéstr. - Ökonomieweg, Sanssouci) (Potsdam)\E
		|\Q(Lennéstr. - Ökonomieweg, Sanssouci) (Potsdam)/Lennéstr. (Potsdam)\E
		|\Q(Lennéstr. - Ökonomieweg, Sanssouci) (Potsdam)/(Hans-Sachs-Str. - Lennéstr.) (Potsdam)/Lennéstr. (Potsdam)\E
		|\Q(Lennéstr. - Ökonomieweg, Sanssouci)/(Hans-Sachs-Str. - Lennéstr.)/Lennéstr. (Potsdam)\E
	       )}ix,  "Correct goal resolution (Hans-Sachs-Str. ... or Lennéstr. ... or Ökonomieweg ...)");
	}
	$like_long_data->(qr{(\QMarquardter Damm (Marquardt)/Schlänitzseer Weg (Marquardt)\E
			     |\QMarquardter Damm/Schlänitzseer Weg (Marquardt)\E
			    )}ix,  "Correct goal resolution (Marquardt ...)");
                           
    }

    ######################################################################
    # test for Kaiser-Friedrich-Str. (Potsdam) problem

    {

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

	$like_long_data->(qr/genaue.*startstr.*ausw/i, "Start is ambiguous");
	$like_long_data->(qr/genaue.*zielstr.*ausw/i,  "Goal is ambiguous");

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

	$like_long_data->(qr{genaue kreuzung}i, "On the crossing page");
	$like_long_data->(qr/Kuhfort(er )?damm/i, "Expected start crossing");
	$like_long_data->(qr/Mangerstr/, "Expected goal crossing");

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

	$like_long_data->(qr/genaue.*kreuzung.*angeben/i, "On the crossing page");
	$like_long_data->(qr/\QAm Neuen Palais (Potsdam)/i,  "Correct start resolution (Neues Palais ...)");

    }

    ######################################################################
    # Test custom blockings

 XXX: { ; }
    {

	# Hier wird eine temporäre baustellenbedingte Einbahnstraße in
	# der Rixdorfer Str. getestet.
	# Diese Einschränkung hat das Attribut "handicap" gesetzt.

	$get_agent->();

	$agent->get($cgiurl);
	$agent->form_name("BBBikeForm");
	{
	    local $^W; $agent->current_form->value('start', 'Rixdorfer Str. (Niederschöneweide)/schnellerstr');
	}
	;
	{
	    local $^W; $agent->current_form->value('ziel', 'Rixdorfer Str. (Niederschöneweide)/südostallee');
	}
	;
	$agent->submit;

	$agent->submit;

	{
	    my $content = get_ct($agent);
	    if ($content =~ /L.*?nge:.*?([\d\.]+)\s*km/) {
		my $length = $1;
		cmp_ok($length, "<=", 1, "Short path (got $length km)")
		    or diag $content;
	    } else {
		fail("Cannot get length from content, URL is <" . $agent->uri . ">");
		diag $content;
	    }
	}

	{
	    my $url = $agent->uri;
	    $url .= ";test=custom_blockings";
	    $agent->get($url);
	}

	my_tidy_check($agent);
	$like_long_data->(qr{Ereignisse, die die Route betreffen}, "Found temp blocking hit");
	$like_long_data->(qr{\(Zeitverlust ca\. \d+ Minuten\)}, "Found Zeitverlust for handicap-typed blocking");
	$like_long_data->(qr{Ausweichroute suchen}, "Found Ausweichroute button");
	my $ausweichroute_choose_url = $agent->uri;
	my $form = $agent->form_name("Ausweichroute");
	isa_ok($form, "HTML::Form");
	for my $input ($form->inputs) {
	    if ($input->type eq 'checkbox') {
		$input->check;
	    }
	}
	$agent->submit;

	my_tidy_check($agent);
	$like_long_data->(qr{M.*gliche Ausweichroute}, "Using Ausweichroute");
	$like_long_data->(qr{\(um \d+ Meter l.*nger\)}, "Info: längere Route")
	    or diag("Test is known to fail if Apache::Session::Counted is not available");
	if (get_ct($agent) =~ /L.*?nge:.*([\d\.]+)\s*km/) {
	    my $length = $1;
	    cmp_ok($length, ">=", 1, "Longer path ($length km)");
	} else {
	    fail("Cannot get length from content");
	}
	$like_long_data->(qr{Sterndamm}, "Expected street in Ausweichroute");

	$agent->form_name('search');
	$agent->click_button(value => "Rückweg");

	$unlike_long_data->(qr{Ausweichroute}, "Keine Ausweichroute mehr");

	{
	    my $url = $ausweichroute_choose_url . ";output_as=xml";
	    my $resp = $agent->get($url);
	    ok($resp->is_success, "Success for $url")
		or diag $resp->status_line;
	    my $xml = $resp->decoded_content(charset => "none"); # using decoded_content with charset decoding is problematic
	    xmllint_string($xml, "XML output OK");
	SKIP: {
		skip("Needs XML::LibXML for further XML tests", 5)
		    if !eval { require XML::LibXML; 1 };
		my $p = XML::LibXML->new;
		my $doc = eval { $p->parse_string($xml) };
		if (!$doc || $@) {
		    my $err = $@;
		    require File::Temp;
		    my($fh,$file) = File::Temp::tempfile(SUFFIX => ".xml");
		    print $fh $xml;
		    close $xml;
		    diag <<EOF;
Failed parsing XML: ${err}XML data written to $file
Following failure is expected.
EOF
		}
		my $root = $doc->documentElement;
		my($affBlockNode) = $root->findnodes("/BBBikeRoute/AffectingBlocking");
		ok($affBlockNode, "Found AffectingBlocking node");
		my($xy) = $affBlockNode->findvalue("./LongLatHop/XY[position()=1]");
		like($xy, qr{^13\.\d+,52\.\d+$}, "XY looks like long/lat in Berlin");
		is($affBlockNode->findvalue("./Text"), 'Rixdorfer Str. (Treptow) in beiden Richtungen zwischen Südostallee und Schnellerstr. Baustelle, Straße vollständig gesperrt (bis 07.08.2006 5 Uhr)', "temp blockings text");
		is($affBlockNode->findvalue("./Index"), 631, "temp blockings id");
		is($affBlockNode->findvalue("./Type"), "handicap", "temp blockings type");
	    }
	}
    }

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
	    local $^W; $agent->current_form->value('ziel', 's hauptbahnhof');
	}
	;
	$agent->submit();
	my_tidy_check($agent);

    SKIP: {
	    skip("Street is known now!", 2); # XXX find another unknown street?
	    $like_long_data->(qr/Kleine Parkstr\..*ist nicht bekannt/i, "Street not in database");
	    $like_long_data->(qr{\Qhtml/newstreetform(utf8.)?.html?\E.*\Qstrname=Kleine%20Parkstr}i, "newstreetform link");
	}
	$like_long_data->(qr{Hauptbahnhof.*?die nächste Kreuzung}is,  "S-Bhf.");
	$like_long_data->(qr{(Invalidenstr.|Ella-Trebe-Str.)}i,  "S-Bhf., next crossing (Invalidenstr or Ella-Trebe-Str.)");
	$like_long_data->(qr{(Minna-Cauer-Str.|Europaplatz)}i,  "S-Bhf., next crossing (Minna-Cauer-Str or Europaplatz)");

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

	$like_long_data->(qr/genaue.*startstr.*ausw/i, "Start is ambiguous");
	
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

	$like_long_data->(qr/brandenburger tor.*mitte/i, "Mitte alternative selected");

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

	$like_long_data->(qr/brandenburger tor.*potsdam/i, "Potsdam alternative selected");

	$agent->submit;
	my_tidy_check($agent);

	# Search normally
	$agent->submit;
	my_tidy_check($agent);

	# Back to crossings form again
	$agent->back;

	######################################################################
	# winter optimization
	my %winter_len;
	for my $winter_optimization ("", "WI1", "WI2") {
	    $form = $agent->current_form;
	    $input = $form->find_input("pref_winter");
	SKIP: {
		skip("winter_optimization not available", 2) if !defined $input;
		$input->value($winter_optimization);
		$agent->submit;
		my_tidy_check($agent);
		my($len) = get_ct($agent) =~ /l.*?nge:.*?([\d\.]+)\s*km/;
		ok(defined $len, "Got length=$len with winter optimization=$winter_optimization");
		$winter_len{$winter_optimization} = $len;
		$agent->back;
	    }
	}

    SKIP: {
	    skip("winter_optimization not available", 2) if !keys %winter_len;
	    cmp_ok($winter_len{""}, "<=", $winter_len{"WI1"}, "No optimization is shortest");
	    cmp_ok($winter_len{"WI1"}, "<=", $winter_len{"WI2"}, "Strong optimization is farthest");
	}

	######################################################################
	# unlit optimization
	my %unlit_len;
	for my $unlit_value ("", "NL") {
	    $form = $agent->current_form;
	    $input = $form->find_input("pref_unlit");
	SKIP: {
		skip("unlit optimization not available", 2) if !defined $input || $input->readonly;
		if ($unlit_value ne '') {
		    $input->check;
		}
		#$input->value($unlit_value);
		$agent->submit;
		my_tidy_check($agent);
		my($len) = get_ct($agent) =~ /l.*?nge:.*?([\d\.]+)\s*km/;
		ok(defined $len, "Got length=$len with unlit optimization=$unlit_value")
		    or diag("URL is <" . $agent->uri . ">");
		$unlit_len{$unlit_value} = $len;
		$agent->back;
	    }
	}

    SKIP: {
	    skip("unlit optimization not available", 1) if !keys %unlit_len;
	    cmp_ok($unlit_len{""}, "<=", $unlit_len{"NL"}, "No optimization is shortest");
	}
    }


    ######################################################################
    # non-utf8 checks

    {
	$get_agent->();

	$agent->get($cgiurl);
	is($agent->response->code, 200, "$cgiurl returned OK");

	$agent->follow_link(text_regex => qr/Info/);
	my_tidy_check($agent);

	$like_long_data->(qr{Information}, "On the info page");
	{
	    local $^W = 0; # cease "Parsing of undecoded UTF-8 will give garbage when decoding entities" warning
	    $agent->follow_link(text_regex => qr{dieses Formular});
	}
	my_tidy_check($agent);

	$like_long_data->(qr{Neue Stra.*e f.*r BBBike}, "On the new street form");
	my $fragezeichenform_url = $agent->uri;
	$fragezeichenform_url =~ s{newstreetform}{fragezeichenform};

	$agent->field("strname", "TEST IGNORE");
	$agent->field("author",  "TEST IGNORE");
    SKIP: {
	    skip("URL is hardcoded and not valid on radzeit.herceg.de", 2)
		if $cgiurl =~ /radzeit.herceg.de/;
	    $agent->submit;
	    my_tidy_check($agent);

	    $like_long_data->(qr{Danke, die Angaben.*gesendet}, "Sent comment");
	}

	{
	    local $^W = 0; # cease "Parsing of undecoded UTF-8 will give garbage when decoding entities" warning
	    $agent->get($fragezeichenform_url);
	}
	my_tidy_check($agent);

	$agent->field("strname",  "TEST IGNORE");
	$agent->field("comments", "TEST IGNORE with umlauts äöüß");
	$agent->field("author",   "TEST IGNORE");
    SKIP: {
	    skip("URL is hardcoded and not valid on radzeit.herceg.de", 2)
		if $cgiurl =~ /radzeit.herceg.de/;
	    $agent->submit;
	    my_tidy_check($agent);

	    $like_long_data->(qr{Danke, die Angaben.*gesendet}, "Sent comment (fragezeichenform)");
	}
    }

    ######################################################################
    # streets in plaetze in Potsdam

    {

	$get_agent->();

	$agent->get($cgiurl);
	$agent->form_name("BBBikeForm");
	{
	    local $^W; $agent->current_form->value('start', 'Schloß Sanssouci');
	}
	;
	{
	    local $^W; $agent->current_form->value('ziel', 'Potsdam Hauptbahnhof');
	}
	;
	$agent->submit();
	my_tidy_check($agent);
	$known_on_2nd_page->();
	$like_long_data->(qr/scope.*region/i, "Scope is set to region");
	$agent->submit();
	my_tidy_check($agent);
	$like_long_data->(qr/Route/, "On the result page");
    }

    ######################################################################
    # outer Berlin

 SKIP: {
	skip("XXX Outer Berlin feature needs bbbike2.cgi", $outer_berlin_tests)
	    if $cgiurl !~ /bbbike2\.cgi/ && $cgiurl ne 'http://localhost/bbbike/cgi/bbbike.cgi';

	$get_agent->();
	$agent->get($cgiurl);
	my $form = $agent->current_form;
	$form->value('start', 'kirchsteig');
	$form->value('startort', 'Königs Wusterhausen');
	$form->value('via', 'kalkberger');
	$form->value('viaort', 'Schöneiche bei Berlin');
	$form->value('ziel', 'flora');
	$form->value('zielort', 'Hohen Neuendorf');
	$agent->submit;
	my_tidy_check($agent);
	$known_on_2nd_page->();
	$like_long_data->(qr/scope.*region/i, "Scope is set to region");
	$like_long_data->(qr/Wernsdorf/, "Crossing for start");
	$like_long_data->(qr/Woltersdorfer Str/, "Crossing for via");
	$like_long_data->(qr/Invalidensiedlung/, "Crossing for goal");
	$agent->submit();
	my_tidy_check($agent);
	$like_long_data->(qr/Route/, "On the result page");
	for my $expected_place (qw(Erkner Woltersdorf Dahlwitz-Hoppegarten)) {
	    $like_long_data->(qr/$expected_place/, "Expected place on route ($expected_place)");
	}

	{
	    $get_agent->();
	    $agent->get($cgiurl);
	    my $form = $agent->current_form;
	    $form->value('start', 'bahnhofstr');
	    $form->value('startort', 'Erkner');
	    $form->value('ziel', 'bahnhofstr');
	    $form->value('zielort', 'Schwanebeck');
	    $agent->submit;
	    my_tidy_check($agent);
	    $like_long_data->(qr/\QBahnhofstr. (Erkner)/, "Start known");
	    $like_long_data->(qr{\Q<i>bahnhofstr</i> in <i>Schwanebeck</i> ist nicht bekannt}, "Unknown goal");
	}
    }

} # for

sub get_ct {
    my($agent) = @_;
    if ($] < 5.008008) {
	$agent->content;
    } else {
	$agent->response->decoded_content;
    }
}

sub my_tidy_check {
    my($agent) = @_;
    if (!$agent->response->is_success) {
	return fail("No success for URL <" . $agent->uri . ">, status line <" . $agent->response->status_line . ">");
    }
    my $uri = $agent->uri;
    if (!$v) {
	$uri =~ s/^.*?\?/...?/;
	my $maxlen = 55;
	$uri = substr($uri, 0, $maxlen) . "..." if length($uri) > $maxlen;
    }

    my $charset;
    require HTTP::Headers::Util;
    my($ct, %ct_param);
    if (my @ct = HTTP::Headers::Util::split_header_words($agent->response->header("Content-Type"))) {
	(undef, undef, %ct_param) = @{$ct[-1]};
	$charset = $ct_param{charset};
    }
    tidy_check(get_ct($agent),
	       "HTML check: $uri",
	       -uri => $agent->uri,
	       -charset => $charset,
	      );
}

__END__
