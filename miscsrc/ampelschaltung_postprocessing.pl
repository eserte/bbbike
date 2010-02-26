#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# An experiment on processing the ampelschaltung.txt file. Script will
# be removed some day.

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib"
	);

use Storable qw(dclone);

use Ampelschaltung;

use constant MAX_CYCLE_TIME => 121;

sub D ($) { }
#sub D ($) { warn $_[0] }

my $as = Ampelschaltung2->new;
$as->open("$FindBin::RealBin/../misc/ampelschaltung.txt") or die;
my @aes = $as->get_entries;
for (@aes) {
    $_->add_epoch_times;
    # XXX for easier dumping later
    delete $_->{Root};
}

my %ampel_data;
for my $ae (@aes) {
    no warnings 'uninitialized';
    my $key = join("|", $ae->{Point}, $ae->{DirFrom}, $ae->{DirTo}, $ae->{Comment});
    if ($ae->{RedTimeEpoch} && $ae->{GreenTimeEpoch}) {
	# have to split
	my $red_ae   = $ae;
	my $green_ae = dclone $ae;
	for (qw(GreenTime GreenTimeEpoch)) { delete $red_ae->{$_} }
	for (qw(RedTime   RedTimeEpoch))   { delete $green_ae->{$_} }
	if ($red_ae->{RedTimeEpoch} < $green_ae->{GreenTimeEpoch}) {
	    push @{ $ampel_data{$key} }, $red_ae, $green_ae;
	} else {
	    push @{ $ampel_data{$key} }, $green_ae, $red_ae;
	}
	if ($ae->{Cycle}) {
	    if ($red_ae->{RedTimeEpoch} < $green_ae->{GreenTimeEpoch}) {
		my $red2_ae = dclone $red_ae;
		$red2_ae->{RedTimeEpoch} += $ae->{Cycle};
		# XXX RedTime missing
		push @{ $ampel_data{$key} }, $red2_ae;
	    } else {
		my $green2_ae = dclone $green_ae;
		$green2_ae->{GreenTimeEpoch} += $ae->{Cycle};
		# XXX GreenTime missing
		push @{ $ampel_data{$key} }, $green2_ae;
	    }
	}
    } else {
	push @{ $ampel_data{$key} }, $ae;
    }
}

# remove duplicates created with the cycle insertion above
for my $key (keys %ampel_data) {
    for(my $i=0; $i < $#{ $ampel_data{$key} }; $i++) {
	my $ae      = $ampel_data{$key}->[$i];
	my $next_ae = $ampel_data{$key}->[$i+1];
	if ($ae->{GreenTimeEpoch} && $next_ae->{GreenTimeEpoch} && $ae->{GreenTimeEpoch} == $next_ae->{GreenTimeEpoch}) {
	    splice @{ $ampel_data{$key} }, $i, 1;
	    $i--;
	} elsif ($ae->{RedTimeEpoch} && $next_ae->{RedTimeEpoch} && $ae->{RedTimeEpoch} == $next_ae->{RedTimeEpoch}) {
	    splice @{ $ampel_data{$key} }, $i, 1;
	    $i--;
	}
    }
}

my %ampel_data_with_cycles;
for my $key (keys %ampel_data) {
    for(my $i=0; $i <= $#{ $ampel_data{$key} }; $i++) {
	my $ae      = $ampel_data{$key}->[$i];
	push @{ $ampel_data_with_cycles{$key} }, $ae;
	my $next_ae;
	my $next_after_ae;
	if ($i+1 <= $#{ $ampel_data{$key} }) {
	    $next_ae = $ampel_data{$key}->[$i+1];
	    if ($i+2 <= $#{ $ampel_data{$key} }) {
		$next_after_ae = $ampel_data{$key}->[$i+2];
	    }
	}
	if ($next_ae && $next_ae->{TimeEpoch} - $ae->{TimeEpoch} < MAX_CYCLE_TIME) { # XXX
	    my($red, $green, $cycle);
	    if ($next_ae->{RedTimeEpoch} && $ae->{GreenTimeEpoch}) {
		$green = $next_ae->{RedTimeEpoch} - $ae->{GreenTimeEpoch};
	    }
	    if ($next_ae->{GreenTimeEpoch} && $ae->{RedTimeEpoch}) {
		$red = $next_ae->{GreenTimeEpoch} - $ae->{RedTimeEpoch};
	    }
	    if ($next_ae->{RedTimeEpoch} && $ae->{RedTimeEpoch}) {
		$cycle = $next_ae->{RedTimeEpoch} - $ae->{RedTimeEpoch};
if (!$cycle) {require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$ae,$next_ae],[qw()])->Indent(1)->Useqq(1)->Dump; }
	    }
	    if ($next_ae->{GreenTimeEpoch} && $ae->{GreenTimeEpoch}) {
		$cycle = $next_ae->{GreenTimeEpoch} - $ae->{GreenTimeEpoch};
if (!$cycle) {require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$ae,$next_ae],[qw()])->Indent(1)->Useqq(1)->Dump; }
	    }
	    if (defined $next_after_ae) {
		if ($next_after_ae->{RedTimeEpoch} && $ae->{RedTimeEpoch}) {
		    my $maybe_cycle = $next_after_ae->{RedTimeEpoch} - $ae->{RedTimeEpoch};
		    if ($maybe_cycle < MAX_CYCLE_TIME) {
			if (defined $cycle && $maybe_cycle != $cycle) {
			    warn "Conflicting cycles (may this happen?): $cycle vs. $maybe_cycle; " . $ae->as_string;
			}
			$cycle = $maybe_cycle;
		    }
		}
		if ($next_after_ae->{GreenTimeEpoch} && $ae->{GreenTimeEpoch}) {
		    my $maybe_cycle = $next_after_ae->{GreenTimeEpoch} - $ae->{GreenTimeEpoch};
		    if ($maybe_cycle < MAX_CYCLE_TIME) {
			if (defined $cycle && $maybe_cycle != $cycle) {
			    warn "Conflicting cycles (may this happen?): $cycle vs. $maybe_cycle; " . $ae->as_string;
			}
			$cycle = $maybe_cycle;
		    }
		}
	    }
	    if (defined $red || defined $green || defined $cycle) {
		my $constructed_data = bless { (defined $red   ? (Red   => $red  ) : ()),
					       (defined $green ? (Green => $green) : ()),
					       (defined $cycle ? (Cycle => $cycle) : ()),
					     }, 'Ampelschaltung::ConstructedData';
		push @{ $ampel_data_with_cycles{$key} }, $constructed_data;
	    }
	}
    }
}

my @sorted_ampel_data_with_cycles_keys = do {
    no warnings 'numeric';
    map { $_->[0] }
	sort {
	    my $res = $a->[1] <=> $b->[1];
	    if ($res == 0) {
		$res = $a->[2] <=> $b->[2];
		if ($res == 0) {
		    $res = $a->[3] cmp $b->[3];
		}
	    }
	    $res;
	} map {
	    my @f = split /\|/;
	    [ $_, split(/,/, $f[0]), @f[1..$#f] ];
	} keys %ampel_data_with_cycles;
};
    
for my $key (@sorted_ampel_data_with_cycles_keys) {
    my $header_printed;
    for my $ae_or_cd (@{ $ampel_data_with_cycles{$key} }) {
	if ($ae_or_cd->can('as_string')) {
	    if (!$header_printed) {
		print $ae_or_cd->{Crossing} . " $key\n";
		$header_printed = 1;
	    }
	    print "    ", $ae_or_cd->as_string, "\n";
	} else {
	    # ConstructedData
	    no warnings 'uninitialized';
	    my($red, $green, $cycle) = @{$ae_or_cd}{qw(Red Green Cycle)};
	    my($red_percent, $green_percent);
	    if (defined $cycle) {
		if (!defined $red && defined $green) {
		    $red = $cycle - $green;
		} elsif (defined $red && !defined $green) {
		    $green = $cycle - $red;
		}

		if (defined $red) {
		    $red_percent = int($red/$cycle*100);
		}
		if (defined $green) {
		    $green_percent = int($green/$cycle*100);
		}
	    }
	    printf "  cycle:%-2s | red:%-2s %-5s | green:%-2s %-5s\n",
		$cycle,
		    $red, (defined $red_percent ? "($red_percent%)" : ""),
			$green, (defined $green_percent ? "($green_percent%)" : "");
	}
    }
    print "-"x70, "\n";
}

#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\%ampel_data_with_cycles],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX



if (0) {    
for(my $i = $#aes; $i>=1; $i--) {
    my $ae      = $aes[$i];
    my $prev_ae = $aes[$i-1];
#{local $ae->{Root} = undef; local $prev_ae->{Root} = undef; require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$ae, $prev_ae],[qw()])->Indent(1)->Useqq(1)->Dump; }
    no warnings 'uninitialized';
    if ($prev_ae->{Point}   eq $ae->{Point}   &&
	$prev_ae->{DirFrom} eq $ae->{DirFrom} &&
	$prev_ae->{DirTo}   eq $ae->{DirTo}   &&
	$prev_ae->{Comment} eq $ae->{Comment}) {
	# maybe combinable
	if ($ae->{RedTime} && $ae->{GreenTime}) {
	    D("already full (ae)");
	} elsif (!$ae->{RedTime} && !$ae->{GreenTime}) {
	    D("empty slot (maybe only cycle time?) (ae)");
	} elsif ($prev_ae->{RedTime} && $prev_ae->{GreenTime}) {
	    D("already full (prev_ae)");
	} elsif (!$prev_ae->{RedTime} && !$prev_ae->{GreenTime}) {
	    D("empty slot (maybe only cycle time?) (prev_ae)");
	} elsif (!$prev_ae->{GreenTime} && $ae->{GreenTime} && $ae->{GreenTimeEpoch}-$prev_ae->{RedTimeEpoch} < MAX_CYCLE_TIME) {
	    D("combinable (here green + prev red): " . $ae->as_string . " + " . $prev_ae->as_string);
	    $prev_ae->{GreenTime} = $ae->{GreenTime};
	    $prev_ae->{GreenTimeEpoch} = $ae->{GreenTimeEpoch};
	    splice @aes, $i, 1;
	} elsif (!$prev_ae->{RedTime}   && $ae->{RedTime}   && $ae->{RedTimeEpoch}-$prev_ae->{GreenTimeEpoch} < MAX_CYCLE_TIME) {
	    D("combinable (here red + prev green): " . $ae->as_string . " + " . $prev_ae->as_string);
	    $prev_ae->{RedTime} = $ae->{RedTime};
	    $prev_ae->{RedTimeEpoch} = $ae->{RedTimeEpoch};
	    splice @aes, $i, 1;
	} else {
	    D("not combinable: " . $ae->as_string . " + " . $prev_ae->as_string);
	}
    }
}

for (@aes) { delete $_->{Root} } require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([@aes],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

}

__END__
