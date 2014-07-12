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
use Test::More;

BEGIN {
    if (!eval { require Tie::Handle::Offset; 1 }) {
	plan skip_all => 'Tie::Handle::Offset not installed';
    }
}

use Strassen::Lookup;

sub check_lookup ($$$);

plan 'no_plan';

my($tmpfh,$tmpfile) = tempfile(UNLINK => 1, SUFFIX => "_sorted.bbd");

{
    my $s = Strassen::Lookup->new("$FindBin::RealBin/../data/strassen");
    isa_ok $s, 'Strassen::Lookup';
    $s->convert_for_lookup($tmpfile);
}

my $s = Strassen::Lookup->new($tmpfile);
isa_ok $s, 'Strassen::Lookup';

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
#:
# Note: this file is sorted and suitable for Strassen::Lookup
Auguststraße	X 3,4
Auguststraße	X 5,6
Dudenstraße	X 1,2
Franklinallee	X 5,6
EOF
    close $tmpfh;

    my $s = Strassen::Lookup->new($tmpfile);
    my $rec;

    $rec = $s->search_first("Dudenstraße");
    is $rec->[Strassen::NAME], 'Dudenstraße', 'utf8 example';

    $rec = $s->search_first("Auguststraße");
    is $rec->[Strassen::NAME], 'Auguststraße', 'another utf8 example';
    $rec = $s->search_next;
    is $rec->[Strassen::NAME], 'Auguststraße', 'search_next with utf8 works';
    ok !$s->search_next, 'no more Auguststraße';
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
