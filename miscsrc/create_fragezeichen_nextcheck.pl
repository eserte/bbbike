#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Date::Calc qw(Add_Delta_Days);
use POSIX qw(strftime);

use Strassen::Core;

my $fragezeichen_mode = 0;
my $door_mode = 'out';

for my $arg (@ARGV) {
    if ($arg =~ m{^--?(.*)$}) {
	$arg = $1;
	if ($arg eq 'fragezeichen-mode') {
	    $fragezeichen_mode = 1;
	} elsif ($arg eq 'no-fragezeichen-mode') {
	    $fragezeichen_mode = 0;
	} elsif ($arg eq 'indoor-mode') {
	    $door_mode = 'in';
	} elsif ($arg eq 'outdoor-mode') {
	    $door_mode = 'out';
	} else {
	    die "Unknown argument -$arg";
	}
    } else {
	handle_file($arg);
    }
}

sub handle_file {
    my($file) = @_;
    my $s = Strassen->new_stream($file);

    my $check_frequency_days = 30;
    my $glob_dir = $s->get_global_directives;
    if ($glob_dir && $glob_dir->{check_frequency}) {
	($check_frequency_days) = $glob_dir->{check_frequency}[0] =~ m{(\d+)};
    }
    my $today = strftime "%Y-%m-%d", localtime;

    $s->read_stream
	(sub {
	     my($r, $dir) = @_;

	     my $check_now; # undef: not given, 0: given and not now, 1: given and now

	     my $add_name;

	     if (exists $dir->{next_check}) {
		 my($y,$m,$d) = $dir->{next_check}[0] =~ m{(\d{4})-(\d{2})-(\d{2})};
		 if (!$y) {
		     ($y,$m) = $dir->{next_check}[0] =~ m{(\d{4})-(\d{2})};
		     $d=1;
		 }
		 if (!$y) {
		     warn "*** WARN: Malformed next_check directive '$dir->{next_check}[0]' in '$file', ignoring...\n";
		 } else {
		     my $date = sprintf "%04d-%02d-%02d", $y,$m,$d;
		     if ($date lt $today) {
			 $add_name = "(next check: $date)";
			 $check_now = 1;
		     } else {
			 $check_now = 0;
		     }
		 }
	     } elsif (exists $dir->{last_checked}) {
		 my($y,$m,$d) = $dir->{last_checked}[0] =~ m{(\d{4})-(\d{2})-(\d{2})};
		 if (!$y) {
		     ($y,$m) = $dir->{last_checked}[0] =~ m{(\d{4})-(\d{2})};
		     $d=1;
		 }
		 if (!$y) {
		     warn "*** WARN: Malformed last_checked directive '$dir->{next_check}[0]' in '$file', ignoring...\n";
		 } else {
		     my $check_frequency_days = $check_frequency_days;
		     if (exists $dir->{check_frequency}) {
			 ($check_frequency_days) = $dir->{check_frequency}[0] =~ m{(\d+)}; # XXX duplicated, see above
		     }
		     my $last_checked_date = sprintf "%04d-%02d-%02d", $y,$m,$d;
		     ($y,$m,$d) = Add_Delta_Days($y,$m,$d, $check_frequency_days);
		     my $date = sprintf "%04d-%02d-%02d", $y,$m,$d;
		     if ($date lt $today) {
			 $add_name = "(last checked: $last_checked_date)";
			 $check_now = 1;
		     } else {
			 $check_now = 0;
		     }
		 }
	     } elsif ($r->[Strassen::NAME] =~ m{(\d{4})-(\d{2})-(\d{2})}) {
		 my($y,$m,$d) = ($1,$2,$3);
		 my $date = sprintf "%04d-%02d-%02d", $y,$m,$d;
		 if ($date lt $today) {
		     $check_now = 1;
		 } else {
		     $check_now = 0;
		 }
	     }

	     return if defined $check_now && !$check_now;

	     if ($door_mode eq 'out') {
		 return if $fragezeichen_mode && (exists $dir->{XXX_prog} || exists $dir->{XXX_indoor});
		 if (!$fragezeichen_mode) {
		     return if (!$check_now &&
				!exists $dir->{add_fragezeichen} &&
				!exists $dir->{XXX} &&
				!exists $dir->{XXX_outdoor} &&
				!exists $dir->{temporary}
			       );
		     my $more_add_name = join(", ", grep { defined } 
					      $dir->{add_fragezeichen}[0],
					      $dir->{XXX}[0],
					      $dir->{XXX_outdoor}[0]
					     );
		     if (length $more_add_name) {
			 if (defined $add_name && length $add_name) { $add_name .= " " }
			 $add_name .= "($more_add_name)";
		     }
		 }
	     } else {
		 return if (!exists $dir->{XXX_prog} &&
			    !exists $dir->{XXX_indoor}
			   );
		 return if defined $check_now && !$check_now;
		 my $more_add_name = join(", ", grep { defined } 
					  $dir->{XXX_prog}[0],
					  $dir->{XXX_outdoor}[0]
					 );
		 if (length $more_add_name) {
		     if (defined $add_name && length $add_name) { $add_name .= " " }
		     $add_name .= "($more_add_name)";
		 }
	     }

	     my $cat;
	     if ($r->[Strassen::CAT] =~ m{^\?}) {
		 $cat = $r->[Strassen::CAT];
	     } elsif ($r->[Strassen::CAT] =~ m{:inwork}) {
		 $cat = '?::inwork';
	     } else {
		 $cat = '?';
	     }

	     # XXX better!!!
	     print $r->[Strassen::NAME] . (defined $add_name ? (length $r->[Strassen::NAME] ? ' ' : '') . $add_name : '') . "\t$cat " . join(" ", @{ $r->[Strassen::COORDS] }) . "\n";
	 });
}

__END__

=head1 EXAMPLES

    ./miscsrc/create_fragezeichen_nextcheck.pl -no-fragezeichen-mode data/ampeln-orig -fragezeichen-mode data/fragezeichen-orig -no-fragezeichen-mode data/gesperrt-orig data/qualitaet_s-orig data/qualitaet_l-orig data/handicap_s-orig data/handicap_l-orig tmp/bbbike-temp-blockings-optimized.bbd data/strassen-orig

=cut
