#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2023,2024 Slaven Rezic. All rights reserved.
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

    cd ~/src/bbbike
    BF10=$(./miscsrc/dwd-soil-update.pl -q | tee /dev/tty | perl -nale 'print $F[3] if /Dahlem/')
    ./miscsrc/mudways-enrich.pl
    ./miscsrc/mudways-enriched-to-handicap.pl --bf10=$BF10 >| /tmp/mudways_prognosis.bbd
    ~/bbbikeclient /tmp/mudways_prognosis.bbd 

Currently also available as a "current mudways" layer from the
SRTShortcuts plugin.

=head2 CONSISTENCY CHECK

To check how good the prognosis algorithm works try

    ./miscsrc/mudways-enriched-to-handicap.pl --consistency-check

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
	   "consistency-check" => \my $do_consistency_check,
	  )
    or usage;
if (!$do_consistency_check) {
    usage "Please specify --bf10 option."
	if !defined $current_bf10;
}

my $today = strftime "%Y-%m-%d", localtime;
my $max_delta = 20;

my $ofh;
if ($outfile) {
    open $ofh, '>', "$outfile.$$"
	or die "Can't write to $outfile.$$: $!";
    select $ofh;
}

my $mudways_enriched_linenumber_offset;
if (!$do_consistency_check) {
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
    $mudways_enriched_linenumber_offset = 2; # XXX besser wäre es, wenn in mudways_enriched.bbd auch source_file/line abgelegt werden würde, und wenn man das übernehmen könnte
}

my $f = "/tmp/mudways_enriched.bbd";
my $s = Strassen->new_stream($f);
if (!$do_consistency_check) {
    $s->read_stream(sub {
        my($r, $dir, $linenumber) = @_;

	my $best_mud_candidate = find_best_mud_candidate($dir->{mud}, $f, $linenumber);
	my $h_directed = $best_mud_candidate->{h} . ($r->[Strassen::CAT] =~ /;$/ ? ';' : '');

	print "#: source_line: " . ($linenumber-$mudways_enriched_linenumber_offset) . "\n";
	print "$r->[Strassen::NAME]; $best_mud_candidate->{text_de}\t$h_directed @{ $r->[Strassen::COORDS] }\n";
    });
} else {
    $s->read_stream(sub {
        my($r, $dir, $linenumber) = @_;

	my @categorized_mud_directives = grep { /\th=q\d/ } @{ $dir->{mud} || [] };
	if (@categorized_mud_directives >= 2) {
	    my $count = 0;
	    my $sum_percentage = 0;
	    for my $i (0 .. $#categorized_mud_directives-1) {
		my($this_current_bf10) = $categorized_mud_directives[$i+1] =~ /:\s+BF10=(\d+)/;
		next if !defined $this_current_bf10;
		my $best_mud_candidate = find_best_mud_candidate([@categorized_mud_directives[0..$i]], $f, $linenumber, $this_current_bf10);
		if ($best_mud_candidate->{type} eq 'best') {
		    my($current_h) = $categorized_mud_directives[$i+1] =~ /\th=(q\d[+-]?)/;
		    my $prognosis_h = $best_mud_candidate->{h};
		    my $current_h_number = q_string_to_number($current_h);
		    my $prognosis_h_number = q_string_to_number($prognosis_h);
		    my $delta = $prognosis_h_number-$current_h_number;
		    my $percentage = (100 * (4+2/3-abs($delta))) / (4+2/3);
		    print "$r->[Strassen::NAME]: $best_mud_candidate->{date}: BF10=$this_current_bf10: prognosis=$prognosis_h vs real=$current_h => " .
			($delta == 0 ? "!OK!" : "DELTA=".$delta) .
			"\n";
		    $count++;
		    $sum_percentage += $percentage;
		}
	    }
	    if ($count) {
		printf "=> %d%% (prognosis quality)\n", $sum_percentage/$count;
		print "-"x70, "\n";
	    }
	}
    });
}

sub find_best_mud_candidate {
    my($mud_directives, $f, $linenumber, $used_current_bf10) = @_;
    $used_current_bf10 //= $current_bf10;

    my $today_candidate;
    my @mud_candidates;
    my @other_candidates;
    for my $mud (@{ $mud_directives || [] }) {
	if (my($date, $bf10, $rest) = $mud =~ m{^(\d{4}-\d{2}-\d{2}):\s+BF10=(\d+|N/A):\s+(.*)}) {
	    my($desc, $h) = $rest =~ m{(.*)\th=(q\d[+-]?)}; # may fail to match if q is missing
	    if ($date eq $today) {
		# usually no bf10 value for today available
		$today_candidate = { date => $date,
				     desc => $desc,
				     h    => $h,
				   };
	    } elsif ($bf10 =~ /^\d+$/) { # i.e. not 'N/A'
		my $delta = abs($bf10-$used_current_bf10);
		my $candidate_info;
		if (defined $h) {
		    $candidate_info = {
				       delta => $delta,
				       date  => $date,
				       bf10  => $bf10,
				       desc  => $desc,
				       h     => $h,
				      };
		}
		if ($delta <= $max_delta) {
		    if ($candidate_info) {
			push @mud_candidates, $candidate_info;
		    }
		} else {
		    if ($candidate_info) {
			push @other_candidates, $candidate_info;
		    }
		}
	    }
	} else {
	    warn "Cannot parse mud directive '$mud' in $f:$linenumber...\n";
	}
    }
    if ($today_candidate) {
	return { type => 'today', text_de => "Ist-Zustand: $today_candidate->{desc}", date => $today, h => $today_candidate->{h} };
    } elsif (@mud_candidates) {
	my($used_mud_candidate) = sort { $a->{delta} <=> $b->{delta} || $b->{date} cmp $a->{date} } @mud_candidates;
	return { type => 'best', text_de => "Prognose: $used_mud_candidate->{desc} ($used_mud_candidate->{date}, BF10=$used_mud_candidate->{bf10})", date => $used_mud_candidate->{date}, h => $used_mud_candidate->{h} };
    } elsif (@other_candidates) {
	my($lower_candidate) = sort { $a->{delta} <=> $b->{delta} || $b->{date} cmp $a->{date} } grep { $_->{bf10} <= $used_current_bf10 } @other_candidates;
	my($upper_candidate) = sort { $a->{delta} <=> $b->{delta} || $b->{date} cmp $a->{date} } grep { $_->{bf10} >  $used_current_bf10 } @other_candidates;
	my $text_de = "keine Prognose";
	if ($lower_candidate || $upper_candidate) {
	    $text_de .= ", Zustand vermutlich";
	    if ($lower_candidate) {
		$text_de .= " nasser als \"$lower_candidate->{desc}\" ($lower_candidate->{date}, BF10=$lower_candidate->{bf10}, $lower_candidate->{h})";
	    }
	    if ($lower_candidate && $upper_candidate) {
		$text_de .= " und";
	    }
	    if ($upper_candidate) {
		$text_de .= " trockener als \"$upper_candidate->{desc}\" ($upper_candidate->{date}, BF10=$upper_candidate->{bf10}, $upper_candidate->{h})";
	    }
	}
	return { type => 'other', text_de => $text_de, date => undef, h => "?" };
    } else {
	return { type => 'none', text_de => "keine Prognose", date => undef, h => "?" };
    }
}

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

sub q_string_to_number {
    my($str) = @_;

    my $q_regex = qr/^([qQ])(\d+)([+-])?$/;
    $str =~ $q_regex;
    my $q = $2;
    my $tendency = $3 // '';
    if ($tendency eq '+') {
	$q -= 1/3;
    } elsif ($tendency eq '-') {
	$q += 1/3;
    }
    $q;
}

__END__
