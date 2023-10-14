#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2023 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

=head1 NAME

mudways-enriched-to-handicap.pl - create a handicap-compatible bbd file from mudways

=head1 DESCRIPTION

From mudways_enriched.bbd create a handicap-compatible bbd file using
the given bf10 value (soil moisture at 10cm). This can be used as a
"prognosis" file.

=head2 TYPICAL WORKFLOW

    BF10=$(~/src/bbbike-aux/misc/dwd-soil-update.pl -q | tee /dev/tty | perl -nale 'print $F[3] if /Dahlem/')
    ~/src/bbbike-aux/misc/mudways-enrich.pl
    ~/src/bbbike-aux/misc/mudways-enriched-to-handicap.pl --bf10=$BF10 >| /tmp/mudways_prognosis.bbd
    ~/src/bbbike/bbbikeclient /tmp/mudways_prognosis.bbd 

Currently also available as a "current mudways" layer from the
SRTShortcuts plugin.

=cut

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/../../bbbike", "$FindBin::RealBin/../../bbbike/lib");

use Getopt::Long;

use BBBikeUtil qw(bbbike_aux_dir);
use Strassen::Core;

my $current_bf10;
GetOptions("bf10=i" => \$current_bf10)
    or die "usage?";
die "please specify --bf10 option"
    if !defined $current_bf10;

print "#: line_width: 5\n";
print "#: line_dash.?: 4,4\n";
{
    my %cat_colors = (
	'q0' => '#8FBC8F',
	'q1' => '#9ACD32',
	'q2' => '#FFD700',
	'q3' => '#FF0000',
	'q4' => '#c00000',
    );
    for my $cat (sort keys %cat_colors) {
	for my $tendency ('', '-', '+') {
	    print "#: line_color.$cat$tendency: $cat_colors{$cat}\n";
	}
    }
    print "#: line_color.?: #6c0000\n";
    print "#:\n";
}

print "# Angenommener BF10-Wert: $current_bf10\n";
print "# \n";

print "#: source_file: mudways\n"; # XXX Eigentlich müsste source_file in mudways_enriched.bbd reingeschrieben und hier übernommen werden
my $mudways_enriched_linenumber_offset = 2; # XXX besser wäre es, wenn in mudways_enriched.bbd auch source_file/line abgelegt werden würde, und wenn man das übernehmen könnte

my $f = "/tmp/mudways_enriched.bbd";
my $s = Strassen->new_stream($f);
$s->read_stream(sub {
    my($r, $dir, $linenumber) = @_;

    my @mud_candidates;
    for my $mud (@{ $dir->{mud} || [] }) {
	if (my($date, $bf10, $rest) = $mud =~ /^(\d{4}-\d{2}-\d{2}):\s+BF10=(\d+):\s+(.*)/) {
	    my $delta = abs($bf10-$current_bf10);
	    if ($delta <= 20) {
		if (my($desc, $h) = $rest =~ m{(.*)\th=(q\d[+-]?)}) {
		    push @mud_candidates, { delta => $delta,
					    date  => $date,
					    bf10  => $bf10,
					    desc  => $desc,
					    h     => $h,
					  };
		}
	    }
	} else {
	    warn "Cannot parse mud directive '$mud' in $f:$linenumber...\n";
	}
    }
    print "#: source_line: " . ($linenumber-$mudways_enriched_linenumber_offset) . "\n";
    if (@mud_candidates) {
	my($used_mud_candidate) = sort { $a->{delta} <=> $b->{delta} || $b->{date} cmp $a->{date} } @mud_candidates;
	print "$r->[Strassen::NAME]; Prognose: $used_mud_candidate->{desc} ($used_mud_candidate->{date}, BF10=$used_mud_candidate->{bf10})\t$used_mud_candidate->{h} @{ $r->[Strassen::COORDS] }\n";
    } else {
	print "$r->[Strassen::NAME]; keine Prognose\t? @{ $r->[Strassen::COORDS] }\n";
    }
});

__END__
