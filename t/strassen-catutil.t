#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use Test::More 'no_plan';

use FindBin;
use lib "$FindBin::RealBin/..";
use Strassen::CatUtil;
use Storable qw(dclone);

my @warnings;
local $SIG{__WARN__} = sub { push @warnings, @_ };

{
    my %penalty = (
		   "Q0" => 1,
		   "Q1" => 1.3,
		   "Q2" => 1.6,
		   "Q3" => 1.9,
		  );
    apply_tendencies_in_penalty(\%penalty);

    is_deeply \%penalty,
	{
	 "Q0+" => 1,
	 "Q0"  => 1,
	 "Q0-" => 1.1,
	 "Q1+" => 1.2,
	 "Q1"  => 1.3,
	 "Q1-" => 1.4,
	 "Q2+" => 1.5,
	 "Q2"  => 1.6,
	 "Q2-" => 1.7,
	 "Q3+" => 1.8,
	 "Q3"  => 1.9,
	 "Q3-" => 2,
	}
	or diag(explain(\%penalty));

    my $remember_penalty = dclone \%penalty;
    apply_tendencies_in_penalty(\%penalty);
    is_deeply \%penalty, $remember_penalty, 'no change if called twice'; # and no warnings
}

{
    my %speed = (
		 "Q0" => 25,
		 "Q1" => 22,
		 "Q2" => 19,
		 "Q3" => 16,
		);
    apply_tendencies_in_speed(\%speed);

    is_deeply \%speed,
	{
	 "Q0+" => 26,
	 "Q0"  => 25,
	 "Q0-" => 24,
	 "Q1+" => 23,
	 "Q1"  => 22,
	 "Q1-" => 21,
	 "Q2+" => 20,
	 "Q2"  => 19,
	 "Q2-" => 18,
	 "Q3+" => 17,
	 "Q3"  => 16,
	 "Q3-" => 15,
	}
	or diag(explain(\%speed));

    my $remember_speed = dclone \%speed;
    apply_tendencies_in_speed(\%speed);
    is_deeply \%speed, $remember_speed, 'no change if called twice'; # and no warnings
}

is_deeply \@warnings, [], 'no warnings';

__END__
