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
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");

use Getopt::Long;
use POSIX qw(strftime);

use BBBikeUtil qw(bbbike_aux_dir);
use Strassen::Core;

sub usage (;$) {
    my $msg = shift;
    warn $msg, "\n" if $msg;
    die "usage: $0 --bf10 soil_moisture_value [-o outfile]\n";
}

my $current_bf10;
GetOptions(
	   "bf10=i" => \$current_bf10,
	   "o|outfile=s" => \my $outfile,
	  )
    or usage;
usage "Please specify --bf10 option."
    if !defined $current_bf10;

my $today = strftime "%Y-%m-%d", localtime;

my $ofh;
if ($outfile) {
    open $ofh, '>', "$outfile.$$"
	or die "Can't write to $outfile.$$: $!";
    select $ofh;
}

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

    my $today_candidate;
    my @mud_candidates;
    my @other_candidates;
    for my $mud (@{ $dir->{mud} || [] }) {
	if (my($date, $bf10, $rest) = $mud =~ m{^(\d{4}-\d{2}-\d{2}):\s+BF10=(\d+|N/A):\s+(.*)}) {
	    my($desc, $h) = $rest =~ m{(.*)\th=(q\d[+-]?)}; # may fail to match if q is missing
	    if ($date eq $today) {
		# usually no bf10 value for today available
		$today_candidate = { date => $date,
				     desc => $desc,
				     h    => $h,
				   };
	    } elsif ($bf10 =~ /^\d+$/) { # i.e. not 'N/A'
		my $delta = abs($bf10-$current_bf10);
		if ($delta <= 20) {
		    if (defined $h) {
			push @mud_candidates, { delta => $delta,
						date  => $date,
						bf10  => $bf10,
						desc  => $desc,
						h     => $h,
					      };
		    }
		} elsif (defined $h && $h ne 'q0') {
		    push @other_candidates, { date => $date,
					      bf10  => $bf10,
					      desc => $desc,
					      h    => $h,
					    };
		}
	    }
	} else {
	    warn "Cannot parse mud directive '$mud' in $f:$linenumber...\n";
	}
    }
    my $directed = $r->[Strassen::CAT] =~ /;$/ ? ';' : '';
    print "#: source_line: " . ($linenumber-$mudways_enriched_linenumber_offset) . "\n";
    if ($today_candidate) {
	print "$r->[Strassen::NAME]; Ist-Zustand: $today_candidate->{desc}\t$today_candidate->{h}$directed @{ $r->[Strassen::COORDS] }\n";
    } elsif (@mud_candidates) {
	my($used_mud_candidate) = sort { $a->{delta} <=> $b->{delta} || $b->{date} cmp $a->{date} } @mud_candidates;
	print "$r->[Strassen::NAME]; Prognose: $used_mud_candidate->{desc} ($used_mud_candidate->{date}, BF10=$used_mud_candidate->{bf10})\t$used_mud_candidate->{h}$directed @{ $r->[Strassen::COORDS] }\n";
    } elsif (@other_candidates) {
	my($used_other_candidate) = sort { compare_q_strings($b->{h}, $a->{h}) } @other_candidates;
	print "$r->[Strassen::NAME]; keine Prognose, schlechtester bekannter Zustand: $used_other_candidate->{desc} ($used_other_candidate->{date}, BF10=$used_other_candidate->{bf10}, $used_other_candidate->{h})\t?$directed @{ $r->[Strassen::COORDS] }\n";
    } else {
	print "$r->[Strassen::NAME]; keine Prognose\t? @{ $r->[Strassen::COORDS] }\n";
    }
});

if ($outfile) {
    rename "$outfile.$$", $outfile
	or die "Can't rename to $outfile: $!";
}

sub compare_q_strings {
    my ($str1, $str2) = @_;

    my $q_regex = qr/^([qQ])(\d+)([+-])?$/;

    $str1 =~ $q_regex;
    my $q1 = $2;
    my $tendency1 = $3 // '';

    $str2 =~ $q_regex;
    my $q2 = $2;
    my $tendency2 = $3 // '';

    if ($q1 != $q2) {
        return $q1 <=> $q2;
    } elsif ($tendency1 eq '' && $tendency2 eq '+') {
        return 1;
    } elsif ($tendency1 eq '' && $tendency2 eq '-') {
        return -1;
    } elsif ($tendency1 eq '+' && $tendency2 eq '') {
        return -1;
    } elsif ($tendency1 eq '-' && $tendency2 eq '') {
        return 1;
    } elsif ($tendency1 eq '+' && $tendency2 eq '-') {
        return -1;
    } elsif ($tendency1 eq '-' && $tendency2 eq '+') {
        return 1;
    } else {
        return 0;
    }
}

__END__
