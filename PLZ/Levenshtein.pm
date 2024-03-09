# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2007,2018 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

package PLZ::Levenshtein;

use strict;
use vars qw($VERSION);
$VERSION = '1.03';

use base qw(PLZ);

use Text::LevenshteinXS qw(distance);

sub look_loop {
    shift->look_loop_levenshtein(@_);
}

sub look_loop_levenshtein {
    my($self, $str, %args) = @_;

    my $max_agrep = $self->_get_max_agrep($str, \%args);

    my %street_to_distance;
    my %street_to_data;
    my $overall_best_distance = 999999;
    for my $pass (0, 1, 2, 3, 4) {
	if ($pass == 4) { # this corresponds to step 5. in PLZ::look_loop
	    if (length $str >= 4 && $overall_best_distance > $max_agrep) {
		my @matchref = $self->look($str, GrepType => 'grep-inword');
		if (@matchref) {
		    return (\@matchref, 0);
		}
	    }
	    next;
	}

	my $transformed;
	if ($pass == 0) {
	    $transformed = $str;
	} elsif ($pass == 1) {
	    $transformed = PLZ::_strip_strasse($str);
	} elsif ($pass == 2) {
	    $transformed = PLZ::_strip_hnr($str);
	} elsif ($pass == 3) {
	    $transformed = PLZ::_expand_strasse($str);
	}
	next if !$transformed;
	$transformed = lc $transformed;
	my($bests, $best_distance) = $self->look_levenshtein($transformed);
	next if !$bests;
	if ($overall_best_distance > $best_distance) {
	    $overall_best_distance = $best_distance;
	    %street_to_data = ();
	    %street_to_distance = ();
	} elsif ($best_distance > $overall_best_distance) {
	    next;
	}
	for my $data (@$bests) {
	    my $street_name = join "|", @$data;
	    if (!exists $street_to_distance{$street_name} ||
		$street_to_distance{$street_name} > $best_distance) {
		$street_to_distance{$street_name} = $best_distance;
		push @{ $street_to_data{$street_name} }, $data;
	    }
	}
    }
    ([ map { @$_ } values %street_to_data], $overall_best_distance);
}

sub look_levenshtein {
    my($self, $str) = @_;

    my @result;
    my $overall_best_distance = 999999;
    CORE::open(my $fh, $self->{File})
	    or die "Die Datei <$self->{File}> kann nicht ge�ffnet werden: $!";
    binmode $fh;
    while(<$fh>) {
	chomp;
	my(@fields) = split /\|/;
	my $distance = distance($str, lc substr($fields[0], 0, length($str)+2));
	next if $distance > $overall_best_distance;
	if ($distance < $overall_best_distance) {
	    @result = ();
	    $overall_best_distance = $distance;
	}
	push @result, \@fields;
    }

    (\@result, $overall_best_distance);
}

1;

__END__
