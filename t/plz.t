#!/usr/local/bin/perl
# -*- perl -*-

#
# $Id: plz.t,v 1.1 2003/06/21 14:36:03 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998,2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: <URL:mailto:eserte@cs.tu-berlin.de>
# WWW:  <URL:http://www.cs.tu-berlin.de/~eserte/>
#

#
# Diese Tests können fehlschlagen, wenn "strassen" oder "plaetze" erweitert
# wurde. In diesem Fall muss die Testausgabe per Augenschein überprüft oder
# mit der Option -create aktualisiert werden.
#

package main;

use Test;
BEGIN { plan tests => 22 }

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../data", "$FindBin::RealBin/../lib");
use PLZ;
use Strassen;
use File::Basename;
use Getopt::Long;

use strict;

my $tmpdir = "$FindBin::RealBin/tmp/plz";
my $create;
my $test_file = 0;
my $INTERACTIVE;
my $in_str;

if (!GetOptions("create!" => \$create,
	       )) {
    die "Usage: $0 [-create]";
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
    print "# Test files are written to $tmpdir.\n";
    print "# If there are non-fatal errors, try to re-run this script with -create\n";
}

my $plz = new PLZ;
if (!defined $plz) {
    if ($INTERACTIVE) {
	die "Das PLZ-Objekt konnte nicht definiert werden";
    } else {
	ok(0);
	exit;
    }
}
ok(1);

testplz();

if (0 && !$INTERACTIVE) { # XXX geht noch nicht
    my $f = "/tmp/" . basename($plz->{File}) . ".gz";
    system("gzip < $plz->{File} > $f");
    if (!-f $f) {
	ok(0);
	exit;
    }
    $plz = new PLZ $f;
    if (!defined $plz) {
	ok(0);
	exit;
    }
    ok(1);

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

{

    my $dump = sub {
	my $obj = shift;
	require Data::Dumper;
	Data::Dumper->new([$obj],[])->Indent(1)->Useqq(1)->Dump;
    };

    my @res = $plz->look("Hauptstr.", MultiZIP => 1);
    ok(scalar @res, 8, $dump->(\@res));
    @res = map { $plz->combined_elem_to_string_form($_) } $plz->combine(@res);
    ok(scalar @res, 7, $dump->(\@res));

    @res = $plz->look("Hauptstr.", MultiCitypart => 1, MultiZIP => 1);
    ok(scalar @res, 9, $dump->(\@res));
    @res = map { $plz->combined_elem_to_string_form($_) } $plz->combine(@res);
    ok(scalar @res, 7, $dump->(\@res));
    my($friedenau_schoeneberg) = grep { $_->[1] =~ /friedenau/i } @res;
    ok($friedenau_schoeneberg->[PLZ::LOOK_NAME], "Hauptstr.");
    ok($friedenau_schoeneberg->[PLZ::LOOK_CITYPART], "Friedenau, Sch\366neberg");
    ok($friedenau_schoeneberg->[PLZ::LOOK_ZIP], "10827, 12159");
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
		ok(scalar @str, 0);
		next;
	    }
	    if (!@str) {
		if ($INTERACTIVE) {
		    die "Keine Straße in der PLZ gefunden"
		} else {
		    ok(0, 1, "Keine Straße für $in_str gefunden");
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
	open(T, ">$tmpdir/$file") or die "Can't create $tmpdir/$file: $!";
	print T $res;
	close T;
	1;
    } else {
	open(T, "$tmpdir/$file") or die "Can't open $tmpdir/$file: $!. Please use the -create option first and check the results in $tmpdir!\n";
	my $buf = join '', <T>;
	close T;

	ok($buf, $res);
    }
}
