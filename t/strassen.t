#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen.t,v 1.3 2004/08/27 07:23:52 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data");
use Getopt::Long;

use Strassen;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

BEGIN { plan tests => 16 }

my $do_xxx;
GetOptions("xxx" => \$do_xxx) or die "usage";
goto XXX if $do_xxx;

{
    my $s = Strassen->new;
    ok($s->isa("Strassen"));

    my $ms = MultiStrassen->new($s, $s);
    ok($ms->isa("Strassen"));
    ok($ms->isa("MultiStrassen"), "MultiStrassen isa MultiStrassen");
}

{
    my $s = Strassen->new("strassen");
    my $count = scalar @{$s->data};
    ok($count > 0);
    is($s->id, "strassen", "Non-empty data");

    my %seen;

    my $i = 0;
    $s->init;
    while(1) {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS] };
	$i++;
	$seen{"Sonntagstr."}++   if $r->[Strassen::NAME] eq 'Sonntagstr.';
	$seen{"Dudenstr."}++     if $r->[Strassen::NAME] eq 'Dudenstr.';
	$seen{"Comeniusplatz"}++ if $r->[Strassen::NAME] eq 'Comeniusplatz';
    }
    is($count, $i, "Checking iteration");
    is(scalar keys %seen, 3, "Streets seen");
}

{
    my $ms = MultiStrassen->new(qw(strassen landstrassen landstrassen2));
    is($ms->id, "strassen_landstrassen_landstrassen2", "Checking id");
}

{
    my $data = <<EOF;
Dudenstr.	H 9222,8787 8982,8781 8594,8773 8472,8772 8425,8771 8293,8768 8209,8769
Methfesselstr.	N 8982,8781 9057,8936 9106,9038 9163,9209 9211,9354
Mehringdamm	HH 9222,8787 9227,8890 9235,9051 9248,9350 9280,9476 9334,9670 9387,9804 9444,9919 9444,10000 9401,10199 9395,10233
EOF
    my $s = Strassen->new_from_data_string($data);
    is(scalar @{$s->data}, 3, "Constructing from string data");
}

XXX: {
    my $data = <<EOF;
#:
#: section projektierte Radstreifen der Verkehrsverwaltung vvv
#: by http://www.berlinonline.de/berliner-zeitung/berlin/327989.html?2004-03-26 vvv
Heinrich-Heine	? 10885,10928 10939,11045 11034,11249 11095,11389 11242,11720
Leipziger Straße zwischen Leipziger Platz und Wilhelmstraße (entweder beidseitig oder nur auf der Südseite)	? 8733,11524 9046,11558
Pacelliallee	? 2585,5696 2609,6348 2659,6499 2711,6698 2733,7039
#: by ^^^
#: by Tagesspiegel 2004-07-25 (obige waren auch dabei) vvv
Reichsstr.	H 1391,11434 1239,11567 1053,11735 836,11935 653,12109 504,12293 448,12361 269,12576 147,12640 50,12695 -112,12866 -120,12915
#: by ^^^
#: section ^^^
#
#: section Straßen in Planung vvv
Magnus-Hirschfeld-Steg: laut Tsp geplant	? 7360,12430 7477,12374
Uferweg an der Kongreßhalle: laut Tsp im Frühjahr 2005 fertig	?::inwork 7684,12543 7753,12578
#: section ^^^
EOF
    my $s = Strassen->new_from_data_string($data, UseLocalDirectives => 1);
    is(scalar @{ $s->data }, 6, "Constructing from string data with directives");
    $s->init_for_iterator("bla");
    while(1) {
	my $r = $s->next_for_iterator("bla");
	last if !@{ $r->[Strassen::COORDS] };
	my $dir = $s->get_directive_for_iterator("bla");
	my $name = $r->[Strassen::NAME];
	if ($name eq 'Heinrich-Heine') {
	    like($dir->{section}, qr{projektierte Radstreifen});
	    like($dir->{by}, qr{berliner-zeitung});
	} elsif ($name eq 'Reichsstr.') {
	    like($dir->{section}, qr{projektierte Radstreifen});
	    like($dir->{by}, qr{Tagesspiegel});
	} elsif ($name =~ /^Magnus-Hirschfeld-Steg/) {
	    like($dir->{section}, qr{Straßen in Planung});
	    is($dir->{by}, undef);
	}
    }

    
}

__END__
