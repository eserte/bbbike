#!/usr/bin/env perl
# -*- perl -*-

#
# $Id: plz.t,v 1.40 2009/04/22 19:53:51 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998,2002,2003,2004,2006,2007 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

#
# Diese Tests können fehlschlagen, wenn "strassen" oder "plaetze" erweitert
# wurde. In diesem Fall muss die Testausgabe per Augenschein überprüft und
# dann mit der Option -create aktualisiert werden.
#

package main;

use Test::More;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../data",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin",
	);
use PLZ;
use PLZ::Multi;
use Strassen;
use File::Basename;
use Getopt::Long;
use Data::Dumper;
use BBBikeTest qw(eq_or_diff);

use strict;

my @approx_tests = (
		    ["Altstädter Ring" => "Altstädter Ring"], # exact match with umlaut
		    ($] >= 5.008 ? [eval q{ substr("Altstädter Ring\x{20ac}",0,-1) }, "Altstädter Ring"] : ()), # forcing utf8
		    #["anhalterbahnho", "Anhalter Bahnhof"], # fails, because "plaetze" is not in PLZ.pm object
		    ["kreutzbergstr" => "Kreuzbergstr."],
		    ["Karl-Herz-Ufer" => "Carl-Herz-Ufer"],
		    ["Simon dach" => "Simon-Dach-Str."],
		    ["yorkstraße" => "Yorckstr."],
		    ["Gräfestr." => "Graefestr."],
		    ["Etgar-Andre Str. 4" => "Etkar-André-Str."],
		    ["henriette hertz platz", "Henriette-Herz-Platz"],
		    ["potsdammer platz", "Potsdamer Platz"],
		    ["am zicus", "Am Zirkus"],
		    ["bahnhof Jungfernheide", "Am Bahnhof Jungfernheide"],
		    ["paul linke ufer", "Paul-Lincke-Ufer"],
		    ["Waldstr.37", "Waldstr."],
		    ["ddnstraße", "Dudenstr."],
		    ["Seuemstr", "Seumestr."],
		    ["Stefanstr.", "Stephanstr."],
		    ["Lennestr.", "Lennéstr."],
		    ["Lennéstr.", "Lennéstr."],
		    # Ku'damm => Kurfürstendamm, fails, maybe an extra rule?
		   );
		    
my $tmpdir = "$FindBin::RealBin/tmp/plz";
my $create;
my $test_file = 0;
my $INTERACTIVE;
my $in_str;
my $goto_xxx;
my $max = 1;
my $extern_first;

my $do_levenshtein;

if (!GetOptions("create!" => \$create,
		"xxx!" => \$goto_xxx,
		"v" => \$PLZ::VERBOSE,
		"max=i" => \$max,
		"externfirst!" => \$extern_first,
		"levenshtein!" => \$do_levenshtein,
	       )) {
    die "Usage: $0 [-create] [-xxx] [-v] [-[no]extern] [-levenshtein]";
}

if ($create) {
    plan 'no_plan';
} else {
    plan tests => 162 + scalar(@approx_tests)*4;
}

# XXX auch Test mit ! -small

use constant STREET   => 0;
use constant MATCHINX => 1;
use constant NOMATCH  => 2;

my @in_str;
if (defined $in_str) {
    $INTERACTIVE = 1;
    @in_str = ([$in_str]);
} else {
    # Array-Definition:
    # 0: gesuchte Straße
    # 1: bei mehreren Matches: Index des Matches, der schließlich genommen wird
    # 2: 1, wenn für diese Straße nichts gefunden werden kann
    @in_str =
      (
       ['KURFUERSTENDAMM',0],
       ['duden'],
       ['methfesselstrasse'],
       ['garibaldi'],
       ['heerstr', 1],
       ['fwefwfiiojfewfew', undef, 1],
       ['mollstrasse',0],
      );
    if ($create) {
	print "# Test files are written to $tmpdir.\n";
    } else {
	print "# Test files read from $tmpdir.\n";
	print "# If there are non-fatal errors, try to re-run this script with -create\n";
    }
}

my $plz = new PLZ;
if (!defined $plz) {
    if ($INTERACTIVE) {
	die "Das PLZ-Objekt konnte nicht definiert werden";
    } else {
	fail("PLZ object");
	exit;
    }
}
pass("PLZ object");

my $plz_multi = PLZ::Multi->new("Berlin.coords.data",
				"Potsdam.coords.data",
				Strassen->new("plaetze"),
				-cache => 1,
			       );
isa_ok($plz_multi, "PLZ");

my $dump = sub {
    my $obj = shift;
    Data::Dumper->new([$obj],[])->Indent(1)->Useqq(1)->Dump;
};

if (!$goto_xxx) {
    testplz();

    if (0 && !$INTERACTIVE) {	# XXX geht noch nicht
	my $f = "/tmp/" . basename($plz->{File}) . ".gz";
	system("gzip < $plz->{File} > $f");
	if (!-f $f) {
	    ok(0);
	    exit;
	}
	$plz = new PLZ $f;
	if (!defined $plz) {
	    ok(0, "PLZ object by file");
	    exit;
	}
	ok(1, "PLZ object by file");
	
	@in_str =
	    (
	     ['duden', <<EOF],
Columbiadamm
Dudenstr.
Friesenstr. (Kreuzberg, Tempelhof)
Golßener Str.
Großbeerenstr. (Kreuzberg)
Heimstr.
Jüterboger Str.
Katzbachstr.
Kreuzbergstr.
Mehringdamm
Methfesselstr.
Monumentenstr.
Möckernstr.
Schwiebusser Str.
Yorckstr.
Züllichauer Str.
EOF
	    );
	testplz();
    }
}

my @extern_order = $extern_first ? (0, 1) : (1, 0);

if ($do_levenshtein) {
    require PLZ::Levenshtein;
    $plz = PLZ::Levenshtein->new;
}

for my $noextern (@extern_order) {
    my @standard_look_loop_args =
	(
	 Max => $max,
	 MultiZIP => 1, # introduced because of Hauptstr./Friedenau vs. Hauptstr./Schöneberg problem
	 MultiCitypart => 1, # works good with the new combine method
	 Agrep => 'default',
	 Noextern => $noextern,
	);

    if ($do_levenshtein) {
	pass("*** This is a test with Text::Levenshtein $Text::Levenshtein::VERSION");
    } else {
	pass("*** This is a test with " . ($noextern ? "String::Approx $String::Approx::VERSION" : "agrep") . " (if available) ***");
    }

    if ($goto_xxx) { goto XXX }

    {
	my @res;
    
	for my $def (@approx_tests) {
	    my($wrong, $correct) = @$def;
	    my @res = $plz->look_loop(PLZ::split_street($wrong),
				      @standard_look_loop_args);
	    my $hits = scalar @{$res[0]};
	    cmp_ok($hits, "<=", 20, "$wrong - not too much hits ($hits)")
		or diag $dump->(\@res);
	    ok((grep { $_->[PLZ::LOOK_NAME] eq $correct } @{$res[0]}),
	       "And $correct is amongst them")
		or diag $dump->(\@res);
	}
	
	@res = $plz->look("Hauptstr.", MultiZIP => 1);
	is(scalar @res, 8, "Hits for Hauptstr.")
	    or diag $dump->(\@res);
	@res = map { $plz->combined_elem_to_string_form($_) } $plz->combine(@res);
	is(scalar @res, 7, "Combine hits")
	    or diag $dump->(\@res);

	@res = $plz->look("Hauptstr.", MultiCitypart => 1, MultiZIP => 1);
	is(scalar @res, 9, "Hits for Hauptstr. with MultiCitypart")
	    or diag $dump->(\@res);
	@res = map { $plz->combined_elem_to_string_form($_) } $plz->combine(@res);
	is(scalar @res, 7, "Combine hits")
	    or diag $dump->(\@res);
	my($friedenau_schoeneberg) = grep { $_->[1] =~ /friedenau/i } @res;
	is($friedenau_schoeneberg->[PLZ::LOOK_NAME], "Hauptstr.");
	is($friedenau_schoeneberg->[PLZ::LOOK_CITYPART], "Friedenau, Sch\366neberg");
	is($friedenau_schoeneberg->[PLZ::LOOK_ZIP], "10827, 12159", "Check PLZ");

	@res = grep { defined $_->[PLZ::LOOK_COORD] } $plz->look("Am Nordgraben", MultiCitypart => 1, MultiZIP => 1);
	is(scalar @res, 3, "Hits for Am Nordgraben. with MultiCitypart")
	    or diag $dump->(\@res);
	@res = map { $plz->combined_elem_to_string_form($_) } $plz->combine(@res);
	is(scalar @res, 2, "Combine hits")
	    or diag $dump->(\@res);

	@res = $plz->look("friedrichstr", Citypart => "mitte");
	is(scalar @res, 1, "Lower case match, Citypart supplied")
	    or diag $dump->(\@res);
	is($res[0]->[PLZ::LOOK_NAME], 'Friedrichstr.');
	is($res[0]->[PLZ::LOOK_CITYPART], 'Mitte');
	is($res[0]->[PLZ::LOOK_ZIP], 10117);

	@res = $plz->look("friedrichstr", Citypart => 10117);
	is(scalar @res, 1, "ZIP supplied as citypart")
	    or diag $dump->(\@res);
	is($res[0]->[PLZ::LOOK_NAME], 'Friedrichstr.');
	is($res[0]->[PLZ::LOOK_CITYPART], 'Mitte');
	is($res[0]->[PLZ::LOOK_ZIP], 10117);

	@res = $plz->look_loop(PLZ::split_street("Heerstr. 1"),
			       @standard_look_loop_args);
	is(scalar @{$res[0]}, 7, "Hits for Heerstr.")
	    or diag $dump->(\@res);
	ok(grep { $_->[PLZ::LOOK_NAME] eq 'Heerstr.' } @{$res[0]});

	@res = $plz->look_loop(PLZ::split_street("Straße des 17. Juni"),
			       @standard_look_loop_args);
	is(scalar @{$res[0]}, 2, "Hits for Straße des 17. Juni")
	    or diag $dump->(\@res);

	@res = $plz->look_loop(PLZ::split_street("str.des 17.Juni"),
			       @standard_look_loop_args);
	is(scalar @{$res[0]}, 2, "Hits for Straße des 17. Juni (missing spaces)")
	    or diag $dump->(\@res);

	@res = $plz->look_loop(PLZ::split_street("  Str. des 17. Juni 153  "),
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Straße des 17. Juni' } @{$res[0]}), 1,
	   "Hits for Straße des 17. Juni (hard one)")
	    or diag $dump->(\@res);

	@res = $plz->look_loop(PLZ::split_street("gaertnerstrasse 22"),
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Gärtnerstr.' } @{$res[0]}), 1)
	    or diag $dump->(\@res);

	## This is too hard: the algorithm can't strip "strasse" because of the missing
	## "s". Well...
	#      @res = $plz->look_loop(PLZ::split_street("KAnzowtrasse 1"),
	#  			   @standard_look_loop_args);
	#      ok(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Kanzowstr.' } @{$res[0]}), 1,
	#         $dump->(\@res));

	@res = $plz->look_loop(PLZ::split_street("Grossbeerenstr. 27a"),
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Großbeerenstr.' } @{$res[0]}), 1,
	   "Missing sz")
	    or diag $dump->(\@res);

	@res = $plz->look_loop(PLZ::split_street("Leibnizstrasse 3-4"),
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Leibnizstr.' } @{$res[0]}), 1,
	   "`strasse' instead of `str.', complex house number")
	    or diag $dump->(\@res);

	@res = $plz_multi->look_loop(PLZ::split_street("Mühlenstraße 24 - 26"),
				     @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Mühlenstr.' } @{$res[0]}), 1,
	   "`straße' instead of `str.', complex house number with whitespace")
	    or diag $dump->(\@res);

	@res = $plz->look_loop(PLZ::split_street("Sanderstr. 29/30"),
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Sanderstr.' } @{$res[0]}), 1,
	   "Complex house number")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("Tierpark",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Am Tierpark' } @{$res[0]}), 1,
	   "Tierpark => Am Tierpark")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("Schumacher",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Kurt-Schumacher-Damm' } @{$res[0]}), 1,
	   "Schumacher => Kurt-Schumacher")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("karower chausee",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Karower Chaussee' } @{$res[0]}), 1,
	   "Rechtschreibfehler")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("Augsburger Str. (Charlottenburg",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Augsburger Str.' } @{$res[0]}), 1,
	   "Quoting regexp")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("Augsburger Str. (Charlottenburg",
			       @standard_look_loop_args, GrepType => "grep-umlaut");
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Augsburger Str.' } @{$res[0]}), 1,
	   "Quoting regexp for grep-umlaut search type")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("Augsburger Str. (Charlottenburg",
			       @standard_look_loop_args,
			       GrepType => "grep", Noextern => 1);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Augsburger Str.' } @{$res[0]}), 1,
	   "Quoting regexp for grep search type")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("U-Bhf Platz der Luftbr",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'U-Bhf Platz der Luftbrücke' } @{$res[0]}), 1,
	   "U-Bahnhof")
	    or diag $dump->(\@res);

    XXX:
	@res = $plz->look_loop("S-Bhf. Grünau",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'S-Bhf Grünau' } @{$res[0]}), 1,
	   "S-Bhf with dot, should find Grünau")
	    or diag $dump->(\@res);
	{
	    local $TODO = <<EOF;
The S-Bhf. -> S-Bhf translation exists in PLZ.pm, but is called to late.
Maybe unambiguous translations (= normalizations) should be done quite
early?
EOF
	    is(scalar(@res), 1, "S-Bhf with dot, should be exact");
	}

	@res = $plz->look_loop("u weberwiese",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'U-Bhf Weberwiese' } @{$res[0]}), 1,
	   "U-Bahnhof, abbreviated")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("s+u wedding",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'S-Bhf Wedding' } @{$res[0]}), 1,
	   "S+U-Bahnhof, abbreviated")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("u+s friedrichstr.",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'S-Bhf Friedrichstr.' } @{$res[0]}), 1,
	   "U+S-Bahnhof, abbreviated (unusual order)")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("s+u-bhf alexanderpl",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'S-Bhf Alexanderplatz' } @{$res[0]}), 1,
	   "U+S-Bahnhof, middle form")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("u+s-bhf zoo",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'S-Bhf Zoologischer Garten' } @{$res[0]}), 1,
	   "U+S-Bahnhof, middle form (unusual order)")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("s+u-bahnhof friedrichstr.",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'S-Bhf Friedrichstr.' } @{$res[0]}), 1,
	   "U+S-Bahnhof, long form")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("u+s-bahnhof friedrichstr.",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'S-Bhf Friedrichstr.' } @{$res[0]}), 1,
	   "U+S-Bahnhof, long form (unusual order)")
	    or diag $dump->(\@res);

	{
	    local $TODO = "Does not work yet";
	    @res = $plz->look_loop("u+s bahnhof friedrichstr.",
				   @standard_look_loop_args);
	    is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'S-Bhf Friedrichstr.' } @{$res[0]}), 1,
	       "U+S Bahnhof, long form with space (unusual order)")
		or diag $dump->(\@res);
	}

	@res = $plz->look_loop("s-bahnhof heerstr",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'S-Bhf Heerstr.' } @{$res[0]}), 1,
	   "S-Bahnhof (Heerstr), long form")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("s-bahnhof grunewald",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'S-Bhf Grunewald' } @{$res[0]}), 1,
	   "S-Bahnhof (Grunewald), long form")
	    or diag $dump->(\@res);

	{
	    local $TODO = "Does not work yet";
	    @res = $plz->look_loop("s bahnhof grunewald",
				   @standard_look_loop_args);
	    is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'S-Bhf Grunewald' } @{$res[0]}), 1,
	       "S Bahnhof (Grunewald), long form with space")
		or diag $dump->(\@res);
	}

	# A complaint by alh (but obsolete now):
	@res = $plz->look_loop("lehrter bahnhof",
			       @standard_look_loop_args);
	is(scalar(@{$res[0]}), 0, "No more Lehrter Bahnhof")
	    or diag $dump->(\@res);

	@res = $plz->look_loop("hauptbahnhof",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'S-Bhf Hauptbahnhof' } @{$res[0]}), 1,
	   "S-Bahnhof")
	    or diag $dump->(\@res);

	@res = $plz_multi->look("brandenburger tor");
	is(scalar(grep { $_->[PLZ::LOOK_CITYPART] eq 'Mitte' } @res), 1,
	   "Should find Brandenburger Tor in Mitte")
	    or diag $dump->(\@res);
	is(scalar(grep { $_->[PLZ::LOOK_CITYPART] eq 'Potsdam' } @res), 1,
	   "Should find Brandenburger Tor in Potsdam")
	    or diag $dump->(\@res);

	@res = $plz_multi->look_loop("lennestr.",
				     @standard_look_loop_args);
	is(scalar(grep { $_->[PLZ::LOOK_CITYPART] eq 'Tiergarten' } @{$res[0]}), 1,
	   "Should find Lennéstr. in Tiergarten (initially without accent)")
	    or diag $dump->(\@res);
	is(scalar(grep { $_->[PLZ::LOOK_CITYPART] eq 'Potsdam' } @{$res[0]}), 1,
	   "Should find Lennéstr. in Potsdam (initially without accent)")
	    or diag $dump->(\@res);

	@res = $plz_multi->look("lennéstr.");
	is(scalar(grep { $_->[PLZ::LOOK_CITYPART] eq 'Tiergarten' } @res), 1,
	   "Should find Lennéstr. in Tiergarten (initially with accent)")
	    or diag $dump->(\@res);
	is(scalar(grep { $_->[PLZ::LOOK_CITYPART] eq 'Potsdam' } @res), 1,
	   "Should find Lennéstr. in Potsdam (initially with accent)")
	    or diag $dump->(\@res);

	@res = $plz_multi->look_loop("brandenburger tor",
				     @standard_look_loop_args);
	is(scalar(grep { $_->[PLZ::LOOK_CITYPART] eq 'Mitte' } @{$res[0]}), 1,
	   "Should find Brandenburger Tor in Mitte")
	    or diag $dump->(\@res);
	is(scalar(grep { $_->[PLZ::LOOK_CITYPART] eq 'Potsdam' } @{$res[0]}), 1,
	   "Should find Brandenburger Tor in Potsdam")
	    or diag $dump->(\@res);

	@res = $plz_multi->look_loop("kl. präsidentenstr.");
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Kleine Präsidentenstr.' } @{$res[0]}), 1,
	   "Expanding kl.")
	    or diag $dump->(\@res);
	@res = $plz_multi->look_loop("gr. seestr.");
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Große Seestr.' } @{$res[0]}), 1,
	   "Expanding gr.")
	    or diag $dump->(\@res);

	@res = $plz_multi->look_loop(PLZ::split_street("potsdam, schopenhauerstr."),
				     @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq "Schopenhauerstr." } @{$res[0]}), 1, 
	   "split_street with city, street syntax, city part")
	    or diag $dump->(\@res);
	is(!!(grep { $_->[PLZ::LOOK_CITYPART] eq "Potsdam" } @{$res[0]}), 1, 
	   "split_street with city, street syntax, street part")
	    or diag $dump->(\@res);

	@res = $plz_multi->look("herz", GrepType => "grep-inword");
	for my $test (
		      "Alice-Herz-Platz",
		      "Carl-Herz-Ufer",
		      "Henriette-Herz-Platz",
		     ) {
	    ok((grep { $_->[PLZ::LOOK_NAME] eq $test } @res), "grep-inword: Matched $test");
	}
	ok((!grep { $_->[PLZ::LOOK_NAME] =~ /herzberg/i } @res), "Does not match Herzberg");

	@res = $plz_multi->look("herz", GrepType => "grep-substr");
	for my $test (
		      "Alice-Herz-Platz",
		      "Herzbergstr.",
		     ) {
	    ok((grep { $_->[PLZ::LOOK_NAME] eq $test } @res), "grep-substr: Matched $test");
	}

	for my $test (
		      "S-Bhf. Potsdam Hauptbahnhof",
		      "S-Bhf. Griebnitzsee",
		     ) {
	    @res = $plz_multi->look($test);
	    like($res[0][0], qr{$test}i, "S-Bhf. in Potsdam ($test)");
	}

	# Check also for an agrep trap: comma is a special boolean operator
	@res = $plz->look_loop("Gustav-müller-str, 16",
			       @standard_look_loop_args);
	is(!!(grep { $_->[PLZ::LOOK_NAME] eq 'Gustav-Müller-Str.' } @{$res[0]}), 1,
	   "Hard stuff: strip house number and comma used instead of dot")
	    or diag $dump->(\@res);

	my $hits = scalar @{$res[0]};
	cmp_ok($hits, "<=", 4, "not too much hits ($hits)")
	    or diag $dump->(\@res);

	{
	    local $TODO = "Should get all four Eichenstr. in Berlin";

	    @res = $plz->look_loop("Eichenstraße 1 A", @standard_look_loop_args);
	    my $hits = scalar @{$res[0]};
	    cmp_ok($hits, ">=", 4, "Should get not only Eichenstraße in Mahlsdorf (hits=$hits)")
		or diag $dump->(\@res);
	}

    }
}

sub testplz {

    foreach my $noextern (0, 1) {
	foreach my $def (@in_str) {
	    $in_str = $def->[STREET];
	    my($str_ref) = $plz->look_loop($in_str,
					   Max => 20,
					   Agrep => 3,
					   Noextern => $noextern,
					  );
	    my(@str) = @$str_ref;
	    if ($def->[NOMATCH]) {
		is(scalar @str, 0, "Expected no match");
		next;
	    }
	    if (!@str) {
		if ($INTERACTIVE) {
		    die "Keine Straße in der PLZ gefunden"
		} else {
		    is(0, 1, "Keine Straße für $in_str gefunden");
		    next;
		}
	    }

	    my $str;
	    if (@str == 1) {
		$str = $str[0];
	    } else {
		if ($INTERACTIVE) {
		    my $i = 0;
		    foreach (@str) {
			print $i+1 . ": $_->[STREET] ($_->[NOMATCH])\n";
			$i++;
		    }
		    print "> ";
		    chomp(my $res = <STDIN>);
		    $str = $str[$res-1];
		} else {
		    $str = $str[$def->[MATCHINX]];
		}
	    }
	    my $plz_re = $plz->make_plz_re($str->[2]);
	    my @res1 = $plz->look($plz_re, Noextern => 0, Noquote => 1);
	    $str = new Strassen "strassen";

	    my @s = ();
	    foreach ($str->union(\@res1)) {
		push(@s, $str->get($_)->[0]);
	    }

	    my $printres = join("\n", sort @s) . "\n";

	    if ($INTERACTIVE) {
		print $printres;
	    } else {
		do_file($printres);
	    }
	}
    }

}

sub do_file {
    my $res = shift;
    my $file = ++$test_file;

    if ($create) {
	if (!-d $tmpdir) {
	    require File::Path;
	    File::Path::mkpath([$tmpdir]);
	}
	my $outfile = "$tmpdir/$file";
	open(T, "> $outfile") or die "Can't create $outfile: $!";
	print T $res;
	close T;
	chmod 0644, $outfile;
	1;
    } else {
	my $infile = "$tmpdir/$file";
	if (open(T, $infile)) {
	    my $buf = join '', <T>;
	    close T;

	    my $label = "Compare results with file $file";
	    eq_or_diff($res, $buf, $label);
	} else {
	    warn "Can't open $infile: $!. Please use the -create option first and check the results in $tmpdir!\n";
	    ok(0);
	}
    }
}
