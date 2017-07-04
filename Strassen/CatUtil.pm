# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::CatUtil;

use strict;
use vars qw($VERSION @EXPORT);
$VERSION = '0.01';

use Exporter 'import';
@EXPORT = qw(apply_tendencies_in_penalty apply_tendencies_in_speed);

sub _apply_tendencies {
    my($penalty_ref, $type) = @_;
    for my $key (keys %$penalty_ref) {
	if (my($prefix, $num) = $key =~ m{^(.*?)(\d+)$}) {
	    my $nextnum = $num+1;
	    if (exists $penalty_ref->{"$prefix$nextnum"}) {
		my $delta = $penalty_ref->{"$prefix$nextnum"} - $penalty_ref->{$key};
		if ($num == 0) {
		    my $new_penalty;
		    if ($type eq 'penalty' && $penalty_ref->{$key} == 1) {
			$new_penalty = 1;
		    } else {
			$new_penalty = $penalty_ref->{$key} - $delta/3;
			if ($type eq 'penalty' && $new_penalty < 1) {
			    $new_penalty = 1;
			}
		    }
		    $penalty_ref->{$key."+"} = $new_penalty;
		}
		$penalty_ref->{$key.            "-"} = $penalty_ref->{$key}             + $delta/3;
		$penalty_ref->{$prefix.$nextnum."+"} = $penalty_ref->{$prefix.$nextnum} - $delta/3;
	    } else { # last number
		my $delta = $penalty_ref->{$key} - $penalty_ref->{$prefix.($num-1)};
		$penalty_ref->{$key."-"} = $penalty_ref->{$key} + $delta/3;
	    }
	} elsif ($key =~ m{[+-]$}) {
	    # the supplied hashref already has tendency information - ignore
	} else {
	    warn "Cannot parse unexpected key '$key'";
	}
    }
}

sub apply_tendencies_in_penalty {
    _apply_tendencies($_[0], 'penalty');
}

sub apply_tendencies_in_speed {
    _apply_tendencies($_[0], 'speed');
}

1;

__END__
