# -*- perl -*-

#
# $Id: BBBikeEditUtil.pm,v 1.20 2008/07/16 19:02:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeEditUtil;
use strict;
use vars qw(%file2base);

sub base {
    my $datadir = shift || $main::datadir;
    open(BASE, "$datadir/BASE") or die "Can't open $datadir/BASE: $!";
    while(<BASE>) {
	chomp;
	my($file, $base) = split(/\s+/, $_);
	$file2base{$file} = $base;
    }
    close BASE;
    %file2base;
}

# XXX maybe should not return just the basenames...
sub get_orig_files {
    my $datadir = shift || $main::datadir;
    my @files;
    opendir(DIR, $datadir) or die "Can't opendir $datadir: $!";
    my $f;
    while(defined(my $f = readdir DIR)) {
	if (-f "$datadir/$f" && $f =~ /-orig$/) {
	    push @files, $f;
	}
    }
    closedir DIR;
#XXXdel:    my $fr_file = "$FindBin::RealBin/misc/fragezeichen-orig";
#     if (-e $fr_file) {
#  	push @files, $fr_file;
#     }
    sort @files;
}

# Same as get_orig_files, but without -orig
sub get_generated_files {
    my $datadir = shift || $main::datadir;
    my @files;
    opendir(DIR, $datadir) or die "Can't opendir $datadir: $!";
    my $f;
    while(defined(my $f = readdir DIR)) {
	next if $f =~ /^(\.|.*[Mm]akefile.*|README.*|BASE|datachange\.log)/;
	next if $f =~ /(-info|\.coords\.data|\.desc|\.st|\.inx|\.inx4|\.lock|~)$/;
	if (-f "$datadir/$f" && $f !~ /-orig$/) {
	    push @files, $f;
	}
    }
    closedir DIR;
    for my $misc_file (qw(zebrastreifen)) {
	my $file = "$FindBin::RealBin/misc/$misc_file";
	if (-r $file) {
	    push @files, $file;
	}
    }
    for my $misc_file (glob("$ENV{HOME}/.bbbike/data/*.bbd")) {
	if (-r $misc_file) {
	    push @files, $misc_file;
	}
    }
    sort @files;
}

sub parse_dates {
    my $btxt = shift;

    my @month_names = qw(Januar Februar März April Mai Juni Juli
			 August September Oktober November Dezember);
    my $month_rx = join("|", map { quotemeta } @month_names);
    my %month_to_num;
    $month_to_num{$month_names[$_-1]} = $_ for (1..@month_names);

    require Time::Local;

    my $date_time_to_epoch = sub {
	my($S,$M,$H,$d,$m,$y) = @_;
	$m--;
	if    ($y < 90)  { $y += 2000 }
	elsif ($y < 100) { $y += 1900 }
	$y-=1900;
	my $day_inc = 0;
	if ($H == 24) {
	    $H = 0;
	    $day_inc = 1;
	}
	my $time;
	eval {
	    $time = Time::Local::timelocal($S,$M,$H,$d,$m,$y);
	};
	if ($@) {
	    if ($d == 0) {
		# use end of month
		# warn "adjust to end of month";
		$d = month_days($m,$y);
	    }
	    eval {
		$time = Time::Local::timelocal($S,$M,$H,$d,$m,$y);
	    };
	    if ($@) {
		if (defined &main::status_message) {
		    main::status_message($@, "die");
		} else {
		    require Carp;
		    Carp::confess($@);
		}
	    }
	}
	if ($day_inc) {
	    $time += 86400;
	}
	$time;
    };

    my $nat_de_to_epoch = sub {
	my($day_nat, $month_nat, $year, $dir) = @_;

	my $month;
	if ($month_nat =~ /^\d+$/) {
	    $month = int $month_nat;
	} else {
	    $month = $month_to_num{$month_nat};
	}
	return undef if !defined $month;

	local $^W = 0; # $day_nat may be undef

	if (length $year == 2) {
	    $year = "20$year";
	}
	if (length $year != 4) {
	    warn "Year '$year' looks fishy!";
	}

	my $day;
	if ($day_nat =~ /anfang/i) {
	    $day = 1;
	} elsif ($day_nat =~ /mitte/i) {
	    $day = 15;
	} elsif ($day_nat =~ /(\d+)/i) {
	    $day = $1;
	} else { # undef and anything else is treated as "ende"
	    $day = month_days($month, $year);
	}

	my($H,$M,$S) = (0, 0, 0);
	if ($dir == 1) {
	    ($H,$M,$S) = (23, 59, 59);
	}
	$date_time_to_epoch->($S,$M,$H, $day,$month,$year);
    };

    my($new_start_time, $new_end_time, $prewarn_days, $rx_matched);

    my $date_rx       = qr/(\d{1,2})\.(\d{1,2})\.((?:20)?\d{2})/;
    my $short_date_rx = qr/([0-3]?[0-9])\.([0-1]?[0-9])\./;
    my $time_rx       = qr/(\d{1,2})[\.:](\d{2})\s*Uhr/;
    my $short_time_rx = qr/(\d{1,2})\s*Uhr/;
    my $full_date_rx  = qr/$date_rx\D+$time_rx/;
    my $ab_rx         = qr/(?:ab[:\s]+|Dauer[:\s]+|vo[mn][:\s]+)/;
    my $bis_und_rx    = qr/(?:[Bb]is|und|\s*-\s*)(?:\s+(?:ca\.|voraussichtlich|zum))?/;
    my $isodaterx = qr/\b(20\d{2})-(\d{2})-(\d{2})\b/;
    my $eudaterx  = qr/\b([0123]?\d)\.([01]?\d)\.(\d{4})\b/;
    # XXX add ? after Anfang... group?
    my $nat_de_rx = qr{(Anfang|Mitte|Ende|\d+(?:\.)?)?\s+($month_rx|\d|0\d|1[012])[./ ]((?:20)?\d{2})}i;
    my $nat_de_year_rx = qr{(Anfang|Ende)\s+(20\d{2})\b};

    my $this_year = (localtime)[5] + 1900;
    my($d1,$m1,$y1, $H1,$M1, $d2,$m2,$y2, $H2,$M2, @to_matches, $rest);
    # XXX use $full_date_rx etc. (after testing rxes!)
TRY_MATCHES: {
    if (($d1,$m1,$y1, $H1,$M1, $H2,$M2) = $btxt =~
	/(\d{1,2})\.(\d{1,2})\.((?:20)?\d{2})\D+(\d{1,2})\.(\d{2})\s*Uhr\s*$bis_und_rx\s*(\d{1,2})\.(\d{2})\s*Uhr/) {
	$new_start_time = $date_time_to_epoch->(0,$M1,$H1,$d1,$m1,$y1);
	$new_end_time   = $date_time_to_epoch->(0,$M2,$H2,$d1,$m1,$y1);
	$rx_matched     = 1;
    } elsif (($d1,$m1,$y1, $H1,$M1, $d2,$m2,$y2, $H2, $M2) = $btxt =~
	     /$full_date_rx\s*$bis_und_rx\s*$full_date_rx/) {
	$new_start_time = $date_time_to_epoch->(0,$M1,$H1,$d1,$m1,$y1);
	$new_end_time   = $date_time_to_epoch->(0,$M2,$H2,$d2,$m2,$y2);
	$rx_matched     = 16;
    } elsif (($d1,$m1,$y1, $H1,$M1, $d2,$m2,$y2) = $btxt =~
	     /$full_date_rx\s*$bis_und_rx\s*$date_rx/) {
	$new_start_time = $date_time_to_epoch->(0,$M1,$H1,$d1,$m1,$y1);
	$new_end_time   = $date_time_to_epoch->(0,  0, 24,$d2,$m2,$y2);
	$rx_matched     = 2;
    } elsif (($d1,$m1,$y1, $d2,$m2,$y2) = $btxt =~
	     /$nat_de_rx\s*$bis_und_rx\s*$nat_de_rx/) {
	$new_start_time = $nat_de_to_epoch->($d1,$m1,$y1, -1);
	$new_end_time   = $nat_de_to_epoch->($d2,$m2,$y2, +1);
	$rx_matched     = 20;
    } elsif (($d1,$m1,$y1, $H1,$M1, @to_matches) = $btxt =~
	     /$full_date_rx\s*$bis_und_rx\s*$nat_de_rx/) {
	$new_start_time = $date_time_to_epoch->(0,$M1,$H1,$d1,$m1,$y1);
	$new_end_time   = $nat_de_to_epoch->(@to_matches, +1);
	$rx_matched     = 16;
    } elsif (($d1,$m1,$y1, $H1,$M1, $d2,$m2,$y2, $H2,$M2) = $btxt =~
	     /(\d{1,2})\.(\d{1,2})\.((?:20)?\d{2})\D+(\d{1,2})\.(\d{2})\s*Uhr\s*$bis_und_rx\s*(\d{1,2})\.(\d{1,2})\.((?:20)?\d{2})\D+(\d{1,2})\.(\d{2})\s*Uhr/) {
	$new_start_time = $date_time_to_epoch->(0,$M1,$H1,$d1,$m1,$y1);
	$new_end_time   = $date_time_to_epoch->(0,$M2,$H2,$d2,$m2,$y2);
	$rx_matched     = 3;
#      } elsif (($d2,$m2,$y2, $H2,$M2) = $btxt =~ /bis\s+$full_date_rx/) {
#  	$new_start_time = time; # now
#  	$prewarn_days = 0;
#  	$new_end_time   = $date_time_to_epoch->(0,$M2,$H2,$d2,$m2,$y2);
#    } elsif (($d2,$m2,$y2) = $btxt =~ /bis\s+$date_rx/) {
#	$new_start_time = time; # now
#	$prewarn_days = 0;
#	$new_end_time   = $date_time_to_epoch->(0,0,24,$d2,$m2,$y2);
    } elsif (($d1,$m1, $d2,$m2) = $btxt =~ /$short_date_rx\s*$bis_und_rx\s*$short_date_rx/) {
	$new_start_time = $date_time_to_epoch->(0,0,0,$d1,$m1,$this_year);
	$new_end_time   = $date_time_to_epoch->(59,59,23,$d2,$m2,$this_year);
	$rx_matched     = 8;
    } elsif (($d1,$m1, @to_matches) = $btxt =~ /$short_date_rx\s*$bis_und_rx\s*$nat_de_rx/) {
	$new_start_time = $date_time_to_epoch->(0,0,0,$d1,$m1,$this_year);
	$new_end_time   = $nat_de_to_epoch->(@to_matches, +1);
	$rx_matched     = 16;
    } else {
	if (($d1,$m1,$y1, $H1,$M1) = $btxt =~
	    /$ab_rx$date_rx(?:\D+$time_rx)?/) {
	    $H1 = 0 if !defined $H1;
	    $M1 ||= 0;
	    $new_start_time = $date_time_to_epoch->(0,$M1,$H1,$d1,$m1,$y1);
	} elsif (($d1,$m1,$y1, $H1,$M1, $rest) = $btxt =~
	    /$date_rx(?:\D+$time_rx)?\s*-(unbekannt)?/) {
	    $H1 = 0 if !defined $H1;
	    $M1 ||= 0;
	    $new_start_time = $date_time_to_epoch->(0,$M1,$H1,$d1,$m1,$y1);
	    if ($rest) {
		$rx_matched = 18;
		last TRY_MATCHES;
	    }
	}
	if (($d1,$m1,$y1, $H1) = $btxt =~
	    /$bis_und_rx\s*$date_rx(?:\D+$short_time_rx)?/) {
	    $H1 = 24 if !defined $H1;
	    $M1 = 0;
	    $new_end_time = $date_time_to_epoch->(0,$M1,$H1,$d1,$m1,$y1);
	    $rx_matched     = 22;
	} elsif (($d1,$m1,$y1, $H1,$M1) = $btxt =~
	    /$bis_und_rx\s*$date_rx(?:\D+$time_rx)?/) {
	    $H1 = 24 if !defined $H1;
	    $M1 ||= 0;
	    $new_end_time = $date_time_to_epoch->(0,$M1,$H1,$d1,$m1,$y1);
	    $rx_matched     = 4;
	} elsif ((my $month, $y1) = $btxt =~
		 /$bis_und_rx\s*($month_rx)\s+(\d+)/i) {
	    $H1 = 24;
	    $M1 = 0;
	    $m1 = $month_to_num{$month};
	    $d1 = month_days($m1, $y1);
	    $new_end_time = $date_time_to_epoch->(0,$M1,$H1,$d1,$m1,$y1);
	    $rx_matched     = 5;
	} elsif ((@to_matches) = $btxt =~ /$bis_und_rx\s*$nat_de_rx/i) {
	    $new_end_time = $nat_de_to_epoch->(@to_matches, +1);
	    $rx_matched     = 17;
	} elsif (($d1, $y1) = $btxt =~ /$bis_und_rx\s*$nat_de_year_rx/i) {
	    my $S1;
	    if ($d1 =~ /anfang/i) {
		($d1,$m1, $H1,$M1,$S1) = ( 1, 1,  0, 0, 0);
	    } else {
		($d1,$m1, $H1,$M1,$S1) = (31,12, 23,59,59);
	    }
	    $new_end_time = $date_time_to_epoch->($S1,$M1,$H1, $d1,$m1,$y1);
	    $rx_matched     = 19;
	} elsif (my($months) = $btxt =~
		 /für\s+(?:ca\.|voraussichtlich)\s+(\d+)\s+Monat/i) {
	    my @l = localtime $new_start_time;
	    $l[4]+=$months; # XXX >12 months not handled yet
	    if ($l[4] > 11) {
		$l[4]-=12;
		$l[5]++;
	    }
	    $new_end_time = Time::Local::timelocal(@l);
	    $rx_matched     = 6;

	# These are originally from check_dates:
	} elsif (($y1,$m1,$d1, $y2,$m2,$d2) = $btxt =~
		 /$isodaterx # start date
		  .*
		  $isodaterx # end date
		  /x) {
	    $new_start_time = $date_time_to_epoch->(0,0,0,$d1,$m1,$y1);
	    $new_end_time   = $date_time_to_epoch->(59,59,23,$d2,$m2,$y2);
	    $rx_matched     = 10;
	} elsif (($d1,$m1,$y1, $d2,$m2,$y2) = $btxt =~
		 /$eudaterx # start date
		  .*
		  $eudaterx # end date
		  /x) {
	    $new_start_time = $date_time_to_epoch->(0,0,0,$d1,$m1,$y1);
	    $new_end_time   = $date_time_to_epoch->(59,59,23,$d2,$m2,$y2);
	    $rx_matched     = 11;
	} elsif (($y1,$m1,$d1) = $btxt =~
		 /\b(?: seit|ab|vom )\s+(?: dem\s+ )? $isodaterx/xi) {
	    $new_start_time = $date_time_to_epoch->(0,0,0,$d1,$m1,$y1);
	    $rx_matched     = 12;
	} elsif (($d1,$m1,$y1) = $btxt =~
		 /\b(?: seit|ab|vom )\s+(?: dem\s+ )? $eudaterx/xi){
	    $new_start_time = $date_time_to_epoch->(0,0,0,$d1,$m1,$y1);
	    $rx_matched     = 13;
	} elsif (($y2,$m2,$d2) = $btxt =~
		 /$isodaterx      # end date
		  /x) {
	    $new_end_time   = $date_time_to_epoch->(59,59,23,$d2,$m2,$y2);
	    $rx_matched     = 14;
	} elsif (($d2,$m2,$y2) = $btxt =~
		 /$eudaterx         # end date
		  /x) {
	    $new_end_time   = $date_time_to_epoch->(59,59,23,$d2,$m2,$y2);
	    $rx_matched     = 15;

	# ^^^ until here

	} elsif (($d2,$m2) = $btxt =~ /\s*$bis_und_rx\s*$short_date_rx/) {
	    $new_end_time   = $date_time_to_epoch->(59,59,23,$d2,$m2,$this_year);
	    $rx_matched     = 21;
	
	} else {
	    $rx_matched     = 7;
	}
    }
    }

    if (defined $new_end_time && !defined $new_start_time) {
	$new_start_time = time;
	$prewarn_days = 0;
    }
    ($new_start_time, $new_end_time, $prewarn_days, $rx_matched);
}

# REPO BEGIN
# REPO NAME month_days /home/e/eserte/src/repository 
# REPO MD5 349f6caae4054c70e91da1cda0eeea5f

sub month_days {
    my($m,$y) = @_;
    my $d = [31,28,31,30,31,30,31,31,30,31,30,31]->[$m-1];
    $d++ if $m == 2 && leapyear($y);
    $d;
}
# REPO END

# REPO BEGIN
# REPO NAME leapyear /home/e/eserte/work/srezic-repository 
# REPO MD5 22fe07ae80911c135aeee23d4dce1e89

=head2 leapyear($year)

=for category Date

Return true if the given year is a leap year.

=cut

sub leapyear {
    my $year = $_[0];
    ($year % 4 == 0 &&
     (($year % 100 != 0) || ($year % 400 == 0)));
}
# REPO END

1;

__END__
