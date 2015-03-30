#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);

use Test::More;

if ($] < 5.010) {
    plan skip_all => 'cvsdiffbbd needs perl 5.10';
}

BEGIN {
    if (!eval q{ use IPC::Run qw(run); 1 }) {
	plan skip_all => 'IPC::Run not available';
    }
}

use BBBikeUtil qw(is_in_path);
use BBBikeTest qw(eq_or_diff);

BEGIN {
    if (!is_in_path('cat')) {
	plan skip_all => 'cat not available';
    }
}

plan 'no_plan';

my $cvsdiffbbd = "$FindBin::RealBin/../miscsrc/cvsdiffbbd";

{
    my $test_diff = <<'EOF';
diff --git c/data/.modified w/data/.modified
index 501fd9a..03cde1d 100644
--- c/data/.modified
+++ w/data/.modified
@@ -11,6 +11,6 @@ data/comments_ferry	1420488881	b0893de56d77f2969a02b6d42e8c2666
 data/comments_kfzverkehr	1420387217	ac4e2c9fbb33534d5386130185c83338
 data/comments_misc	1424018281	86d9a84d7febc635630971d8664e3911
 data/comments_mount	1417884460	82a21c5e232578fa7397ddb9c7e24041
-data/comments_path	1424521315	3773733bae0be7ef0291627e748acc02
+data/comments_path	1424804394	40e1b9779ff48a4bd4c5249f2c5a0493
 data/comments_scenic	1423939202	0ecb50cc3cf035f1e3c4ad24de48d5bd
 data/comments_trafficjam	1424376633	85b579e991b514b45b3e15bada26a7d1
 data/comments_tram	1424018289	b833eaf4dff4808ee9203278f741c32d
diff --git c/data/comments_path w/data/comments_path
index 0509b32..31fec2b 100644
--- c/data/comments_path
+++ w/data/comments_path
@@ -31,6 +31,7 @@ Fu
 Kopernikusstr./Warschauer Str.: Fußgängerampel auf der linken Seite zum Überqueren der Warschauer Str. benutzen	CP; 13467,11778 13651,11731 13895,11663
 Kopernikusstr./Warschauer Str.: Fußgängerampel auf der linken Seite benutzen	CP; 13467,11778 13651,11731 13696,11920
 Boxhagener Str. - Warschauer Str.: Fußgängerampel auf der linken Seite zum Überquerung der Warschauer Str. benutzen	CP; 14045,11965 13745,12118 13696,11920
+Warschauer Str. - Boxhagener Str.: bereits am Frankfurter Tor auf den Mittelstreifen wechseln	PI; 13785,12292 13745,12118 14045,11965
 Neue Bahnhofstr./Boxhagener Str.: Fußgängerampel auf der linken Seite benutzen	CP; 14908,11231 14918,11249 14799,11330
 Neue Bahnhofstr./Boxhagener Str.: Fußgängerampel auf der linken Seite benutzen	CP; 14908,11231 14918,11249 15016,11431
 Rennbahnstr./Bernkasteler Str.: Fußgängerampel auf der linken Seite zum Überqueren der Berliner Allee benutzen	CP; 14528,16910 14558,16907 14673,16895
diff --git c/data/comments_route w/data/comments_route
index cf23725..ad6ab77 100644
--- c/data/comments_route
+++ w/data/comments_route
@@ -40,7 +40,7 @@ ZR1	radroute 40807,15904 41168,16281 41356,16225 41693,16075 41681,15915 42300,1
 #: url: http://www.berlin-usedom-radweginfo.de/ vvv
 #: url: http://www.stadtentwicklung.berlin.de/verkehr/mobil/fahrrad/radrouten/de/usedom/index.shtml vvv
 Berlin - Usedom	radroute 10176,12506 10094,12635 10054,12699 10086,12725 10166,12777 10264,12826 10309,12854 10348,12879 10395,12908 10418,12922 10535,13006 10571,13034 10595,13100 10635,13207 10703,13467 10740,13621 10718,13625 10746,13673 10779,13793 10836,13883 10895,13961 10908,13978 10933,14122 10822,14179 10739,14228 10629,14299 10567,14337 10530,14452 10512,14507 10472,14632 10448,14707 10440,14730 10402,14835 10380,14911 10370,14946 10379,14963 10366,14992 10354,14987
-Berlin - Usedom	radroute 10354,14987 10240,15318 10192,15465 10185,15487 10130,15647 10105,15752 10080,15858 10062,15927 10005,16150 10045,16157 10065,16110 10055,16104 10026,16165 10022,16237 9996,16328 9975,16425 9959,16510 9955,16578 9954,16590 9945,16738 9949,16866 9980,16973 10013,16972 10114,17098 10198,17196 10228,17231 10298,17299 10252,17357 10214,17401 10207,17448 10203,17478 10179,17772 10141,18030 10089,18180 10177,18188 10240,18193
+Berlin - Usedom	radroute 10354,14987 10240,15318 10188,15474 10185,15487 10130,15647 10105,15752 10080,15858 10062,15927 10005,16150 10045,16157 10065,16110 10055,16104 10026,16165 10022,16237 9996,16328 9975,16425 9959,16510 9955,16578 9954,16590 9945,16738 9949,16866 9980,16973 10013,16972 10114,17098 10198,17196 10228,17231 10298,17299 10252,17357 10214,17401 10207,17448 10203,17478 10179,17772 10141,18030 10089,18180 10177,18188 10240,18193
 Berlin - Usedom	radroute; 10240,18193 10320,18197 10469,18262 10487,18270 10660,18345 10680,18380 10602,18382
 Berlin - Usedom	radroute; 10602,18382 10567,18366 10502,18338 10463,18321 10449,18315 10281,18241 10240,18193
 Berlin - Usedom	radroute 10602,18382 10562,18506 10532,18601 10496,18704
diff --git c/data/flaechen w/data/flaechen
index 8c8c656..effac2b 100644
--- c/data/flaechen
+++ w/data/flaechen
@@ -113,8 +113,8 @@ Volkspark Prenzlauer Berg	F:P 14754,14406 14721,14379 14667,14336 14650,14322 14
 Volkspark Anton Saefkow	F:P 13295,14521 13239,14461 13183,14400 13084,14472 13013,14523 12901,14594 12862,14618 12782,14676 12700,14726 12528,14845 12549,14873 12820,14727 13011,14752
 Ernst-Thälmann-Park	F:P 11990,14714 12025,14775 12225,14665 12407,14996 11856,15299 11897,15438 12032,15351 12196,15279 12381,15196 12353,15147 12620,14979 12528,14845 12422,14692 12317,14535
 	F:P 12025,14775 11896,14840 11864,14781 11990,14714
-Mauerpark	F:P 10040,15567 9976,15546 9842,15814 9975,15823 10080,15858 10105,15752 10130,15647 10185,15487 10192,15465 10256,15482 10415,15013 10271,14950
-Falkplatz	F:P 10456,15561 10256,15482 10192,15465 10185,15487 10130,15647 10423,15698
+Mauerpark	F:P 10040,15567 9976,15546 9842,15814 9975,15823 10080,15858 10105,15752 10130,15647 10185,15487 10188,15474 10234,15490 10403,15007 10271,14950
+Falkplatz	F:P 10456,15561 10234,15490 10188,15474 10185,15487 10130,15647 10423,15698
 Goethepark	F:P 5722,15795 5446,15489 5490,15440 5553,15271 5722,15332 5802,15399 5889,15457 5961,15562
 Waldeckpark	F:P 10407,11317 10526,11076 10501,11056 10256,11160
 Hochmeisterplatz	F:P 3359,9968 3348,9806 3427,9771 3469,9807 3457,9827 3468,9961
@@ -724,7 +724,7 @@ Kolonie Bundesallee	F:Orchard 5347,8562 5417,8519 5465,8511 5502,8599 5506,8674
 Friedhof Wilmersdorf	F:Cemetery 3970,8582 4320,8596 4324,8899 4181,8933 4006,8967
 Los-Angeles-Platz	F:P 5669,10704 5822,10609 5780,10542 5627,10637
 Arkonaplatz	F:P 10150,14525 10228,14564 10320,14608 10277,14691 10189,14649 10105,14608
-Friedrich-Ludwig-Jahn-Sportpark	F:Sport 10415,15013 10618,15076 10607,15142 10886,15251 10804,15447 10768,15534 10733,15638 10456,15561 10256,15482
+Friedrich-Ludwig-Jahn-Sportpark	F:Sport 10403,15007 10618,15076 10607,15142 10886,15251 10804,15447 10768,15534 10733,15638 10456,15561 10234,15490
 ehem. Güterbhf. Eberswalder Str.	F:Industrial 10209,14921 10271,14950 10040,15567 9976,15546 10031,15395 10053,15214 10187,14939
 Museumspark	F:P 8654,10254 8558,10022 8518,9929 8468,9939 8456,9989 8439,10073 8476,10182 8525,10240 8540,10215 8596,10210 8617,10239
 Alice-Salomon-Park	F:P 6816,9494 6816,9445 6853,9445 6851,9365 6814,9361 6728,9477
diff --git c/data/gesperrt w/data/gesperrt
index 9732e55..7e6d372 100644
--- c/data/gesperrt
+++ w/data/gesperrt
@@ -2584,6 +2582,9 @@ versetzte Schranke, manchmal offen	BNP:1::trailer=3 24625,20855
 #: temporary: vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
 #: section in Berlin vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
 # 
+#: last_checked: 2015-02-22
+Wartenbergstr.: wegen Einsturzgefahr gesperrt, auch für Radfahrer und Fußgänger	2::inwork 15300,11584 15220,11440
+# 
 #: last_checked: 2015-02-14 vvv
 #: check_frequency: 60d vvv
 Wasserstr. (Niederschöneweide): abgesperrt	2::inwork 17477,6031 17639,6227
EOF

    {
	my $out;
	ok run([$^X, $cvsdiffbbd, "--diff-file=-"], "<", \$test_diff, ">", \$out);
	eq_or_diff $out, <<'EOF';
# File: data/comments_path
Warschauer Str. - Boxhagener Str.: bereits am Frankfurter Tor auf den Mittelstreifen wechseln	#000080 13785,12292 13745,12118 14045,11965
# File: data/comments_route
Berlin - Usedom	#000080 10240,15318 10188,15474 10185,15487
# File: data/flaechen
Mauerpark	#000080 10185,15487 10188,15474 10234,15490 10403,15007 10271,14950
Falkplatz	#000080 10456,15561 10234,15490 10188,15474 10185,15487
Friedrich-Ludwig-Jahn-Sportpark	#000080 10403,15007 10618,15076 10607,15142 10886,15251 10804,15447 10768,15534 10733,15638 10456,15561 10234,15490
# File: data/gesperrt
Wartenbergstr.: wegen Einsturzgefahr gesperrt, auch für Radfahrer und Fußgänger	#000080 15300,11584 15220,11440
EOF
    }

    {
	my $out;
	ok run([$^X, $cvsdiffbbd, "--add-file-label", "--diff-file=-"], "<", \$test_diff, ">", \$out);
	eq_or_diff $out, <<'EOF';
# File: data/comments_path
comments_path: Warschauer Str. - Boxhagener Str.: bereits am Frankfurter Tor auf den Mittelstreifen wechseln	#000080 13785,12292 13745,12118 14045,11965
# File: data/comments_route
comments_route: Berlin - Usedom	#000080 10240,15318 10188,15474 10185,15487
# File: data/flaechen
flaechen: Mauerpark	#000080 10185,15487 10188,15474 10234,15490 10403,15007 10271,14950
flaechen: Falkplatz	#000080 10456,15561 10234,15490 10188,15474 10185,15487
flaechen: Friedrich-Ludwig-Jahn-Sportpark	#000080 10403,15007 10618,15076 10607,15142 10886,15251 10804,15447 10768,15534 10733,15638 10456,15561 10234,15490
# File: data/gesperrt
gesperrt: Wartenbergstr.: wegen Einsturzgefahr gesperrt, auch für Radfahrer und Fußgänger	#000080 15300,11584 15220,11440
EOF
    }

    {
	my $out;
	ok run([$^X, $cvsdiffbbd, "--add-fixed-label=foobar: ", "--diff-file=-"], "<", \$test_diff, ">", \$out);
	eq_or_diff $out, <<'EOF';
# File: data/comments_path
foobar: Warschauer Str. - Boxhagener Str.: bereits am Frankfurter Tor auf den Mittelstreifen wechseln	#000080 13785,12292 13745,12118 14045,11965
# File: data/comments_route
foobar: Berlin - Usedom	#000080 10240,15318 10188,15474 10185,15487
# File: data/flaechen
foobar: Mauerpark	#000080 10185,15487 10188,15474 10234,15490 10403,15007 10271,14950
foobar: Falkplatz	#000080 10456,15561 10234,15490 10188,15474 10185,15487
foobar: Friedrich-Ludwig-Jahn-Sportpark	#000080 10403,15007 10618,15076 10607,15142 10886,15251 10804,15447 10768,15534 10733,15638 10456,15561 10234,15490
# File: data/gesperrt
foobar: Wartenbergstr.: wegen Einsturzgefahr gesperrt, auch für Radfahrer und Fußgänger	#000080 15300,11584 15220,11440
EOF
    }
}

{
    my $test_diff = <<'EOF';
diff --git a/data/handicap_s b/data/handicap_s
index 5beeb6b..d56078f 100644
--- a/data/handicap_s-orig
+++ b/data/handicap_s-orig
@@ -1066,7 +1073,8 @@ Zimmermannstr.: Fu
 #: note: Bordstein am Wendehammer ist an zwei Stellen abgesenkt (aber nicht direkt am Scheitel)
 Deitmerstr.: Fußgänger	q3 5078,5889 5048,5904
 Friedrichsruher Platz: Fußgänger, eng	q2 5942,5775 5935,5874
-Riemenschneiderweg: gemeinsamer Rad- und Gehweg, eng	q1 6878,5946 6895,5873
+#: note: Bordstein am Wendehammer, ansonsten q1 oder q2
+Riemenschneiderweg: gemeinsamer Rad- und Gehweg, eng	q3 6878,5946 6895,5873
 #: XXX_prog: für Anhänger q2 oder q3
 Harkortstr.: Bodenschwellen	q1 7570,5508 7621,5494
 (Plauener Str. - Küllstedter Str.): Fußgänger	q2 17352,14827 17363,14760
EOF
    my $out;
    ok run([$^X, $cvsdiffbbd, '--diff-file=-'], '<', \$test_diff, '>', \$out);
    eq_or_diff $out, "# File: data/handicap_s\n", 'empty diff';
}

__END__
