#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use File::Temp qw(tempfile);
use Getopt::Long;
use Test::More;

BEGIN {
    if (!eval { require Tie::Handle::Offset; 1 }) {
	plan skip_all => 'Tie::Handle::Offset not installed';
    }
}

use Strassen::Core;
use Strassen::Lookup;
use Strassen::Util;

sub check_lookup ($$$);

plan 'no_plan';

my $keep_sorted_file;
GetOptions("keep-sorted-file!" => \$keep_sorted_file)
    or die "usage: $0 [--keep-sorted-file]\n";

my($tmpfh,$tmpfile) = tempfile(UNLINK => !$keep_sorted_file, SUFFIX => "_sorted.bbd");
if ($keep_sorted_file) {
    diag "Temporary file '$tmpfile' will be kept";
}

{
    my $s = Strassen::Lookup->new("$FindBin::RealBin/../data/strassen");
    isa_ok $s, 'Strassen::Lookup';
    $s->convert_for_lookup($tmpfile);
}

my $s = Strassen::Lookup->new($tmpfile);
isa_ok $s, 'Strassen::Lookup';

my $bbd = Strassen->new($tmpfile);
isa_ok $bbd, 'Strassen', 'converted file still parsable as bbd';
is $bbd->get_global_directive('strassen_lookup_suitable'), 'yes', 'marked as suitable for Strassen::Lookup';
is $bbd->get_global_directive('encoding'), 'utf-8', 'utf-8 is forced on files for Strassen::Lookup';

{
    my $last_street_name = $bbd->data->[-1];
    my($first_char) = $last_street_name =~ m{^[^A-Za-z]*(.)};
    is lc($first_char), 'z', 'last street in sorted file begins with z'
	or diag join("Last entry is: $bbd->data->[-1]");
}

{
    check_lookup $s, 'Bergmannstr.',
	{
	 'saw_Bergmannstr_N' => sub {
	     $_[0]->[Strassen::NAME] eq 'Bergmannstr. (Kreuzberg)' && $_[0]->[Strassen::CAT] eq 'N';
	 },
	 'saw_Bergmannstr_NN' => sub {
	     $_[0]->[Strassen::NAME] eq 'Bergmannstr. (Kreuzberg)' && $_[0]->[Strassen::CAT] eq 'NN';
	 },
	 'saw_Bergmannstr_H' => sub {
	     $_[0]->[Strassen::NAME] eq 'Bergmannstr. (Kreuzberg)' && $_[0]->[Strassen::CAT] eq 'H';
	 },
	 'saw_Bergmannstr_Zehlendorf' => sub {
	     $_[0]->[Strassen::NAME] eq 'Bergmannstr. (Zehlendorf)';
	 }
	};
}

{
    check_lookup $s, 'Kurfürstendamm',
	{
	 'saw_Kurfürstendamm' => sub {
	     $_[0]->[Strassen::NAME] =~ 'Kurfürstendamm';
	 },
	};
}

{
    check_lookup $s, 'Ährenweg',
	{
	 'saw_Aehrenweg' => sub {
	     $_[0]->[Strassen::NAME] =~ 'Ährenweg';
	 },
	};
}

{
    check_lookup $s, 'Öschelbronner Weg',
	{
	 'saw_Oeschelbronner_Weg' => sub {
	     $_[0]->[Strassen::NAME] =~ 'Öschelbronner Weg';
	 },
	};
}

{
    my $rec = $s->search_first("This street does not exist");
    is $rec, undef, 'non-existent street';
}

{
    my $res = $s->look("This street does not exist");
    isnt $res, -1, 'no error in look call';
    my $rec = $s->get_next;
    like $rec->[Strassen::NAME], qr{^T}, 'some street starting with "T"';
}

{
    # an utf8 example
    my($tmpfh,$tmpfile) = tempfile(UNLINK => 1, SUFFIX => ".bbd");
    binmode $tmpfh, ':utf8';
    print $tmpfh <<'EOF';
#: encoding: utf-8
#: note: this file is sorted and suitable for Strassen::Lookup
#:
Auguststraße	X 3,4
Auguststraße	X 5,6
Dudenstraße	X 1,2
Franklinallee	X 5,6
Zingster Straße	X 8,9
EOF
    close $tmpfh;

    {
	my $s = Strassen::Lookup->new($tmpfile);

	my $bbd = Strassen->new($tmpfile);
	isa_ok $bbd, 'Strassen';
	is $bbd->get_global_directive('encoding'), 'utf-8', 'encoding directive was preserved in bbd';

	my $rec;

	$rec = $s->search_first("Dudenstraße");
	is $rec->[Strassen::NAME], 'Dudenstraße', 'utf8 example';

	$rec = $s->search_first("dudenstraße");
	is $rec->[Strassen::NAME], 'Dudenstraße', 'utf8 example, lowercase';

	$rec = $s->search_first("Auguststraße");
	is $rec->[Strassen::NAME], 'Auguststraße', 'another utf8 example';
	$rec = $s->search_next;
	is $rec->[Strassen::NAME], 'Auguststraße', 'search_next with utf8 works';
	ok !$s->search_next, 'no more Auguststraße';

	# Tests with delimited
	$rec = $s->search_first("Dudenstraße", 1);
	is $rec->[Strassen::NAME], 'Dudenstraße', 'delimited';
	$rec = $s->search_first("Dudenstr", 0);
	is $rec->[Strassen::NAME], 'Dudenstraße', 'not delimited';
	$rec = $s->search_first("Dudenstr", 1);
	ok !$rec, 'delimited and not found';
    }
}

{
    # unicode levels
    my($tmpfh,$tmpfile) = tempfile(UNLINK => 1, SUFFIX => ".bbd");
    binmode $tmpfh, ':utf8';
    print $tmpfh <<'EOF';
#: encoding: utf-8
#: note: this file is not sorted yet
#:
Alt-Reinickendorf|1|13407|Berlin	HNR 7171,18718
Alt-Reinickendorf|4-5|13407|Berlin	HNR 7129,18726
Alt-Reinickendorf|10|13407|Berlin	HNR 7013,18730
Alt-Reinickendorf|45|13407|Berlin	HNR 6829,18711
Alt-Reinickendorf|46|13407|Berlin	HNR 6846,18711
EOF
    close $tmpfh;

    my($sortedtmpfh,$sortedtmpfile) = tempfile(UNLINK => 1, SUFFIX => "_sorted.bbd");
    my $s = Strassen::Lookup->new($tmpfile, SubSeparator => '|');
    $s->convert_for_lookup($sortedtmpfile);
    my $rec = $s->search_first("Alt-Reinickendorf|4-5|");
    is $rec->[Strassen::NAME], 'Alt-Reinickendorf|4-5|13407|Berlin', 'hnr 4-5 vs. 45';
}

SKIP: {
    my $addr_file = "$FindBin::RealBin/../data_berlin_osm_bbbike/_addr";
    skip "osm converted data for Berlin not available (run data_berlin_osm_bbbike_untiled make target in misc)", 1
	if !-f $addr_file;
    my $s = Strassen::Lookup->new($addr_file);
    isa_ok $s, 'Strassen::Lookup';
    check_lookup $s, 'Unter den Linden|77|',
	{
	 'saw_UdL_Adlon' => sub {
	     my($xy) = $_[0]->[Strassen::COORDS]->[0];
	     my $dist = Strassen::Util::strecke_s($xy, "8750,12222");
	     if ($dist > 100) {
		 diag "Unexpected distance: ${dist}m";
		 return 0;
	     }
	     if ($_[0]->[Strassen::NAME] !~ qr{^Unter den Linden\|77\|}) {
		 diag "Unexpected name: $_[0]->[Strassen::NAME]";
		 return 0;
	     }
	     return 1;
	 },
	};
}

sub check_lookup ($$$) {
    my($s, $in_str, $_checks) = @_;

    my %checks = %$_checks; # flat copy, because of the deletes

    for (my $rec = $s->search_first($in_str); $rec; $rec = $s->search_next) {
	for my $check_key (keys %checks) {
	    if ($checks{$check_key}->($rec)) {
		delete $checks{$check_key};
		last;
	    }
	}
    }
    is_deeply [keys %checks], [], "all checks done for '$in_str'";
}

__END__
