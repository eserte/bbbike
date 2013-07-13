#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009,2012 Slaven Rezic. All rights reserved.
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
	 $FindBin::RealBin,
	);

use Getopt::Long;
use POSIX qw(strftime);

use StrassenNextCheck;

my $fragezeichen_mode = 0;
my $door_mode = 'out';
my $today = strftime "%Y-%m-%d", localtime;
my $do_preamble;
my $coloring;
my $verbose;

my @actions;

GetOptions(
	   "today=s" => \$today,
	   "verbose" => \$verbose,
	   "preamble" => \$do_preamble,
	   "coloring=s" => \$coloring,
	   "fragezeichen-mode"    => sub { push @actions, sub { $fragezeichen_mode = 1 } },
	   "no-fragezeichen-mode" => sub { push @actions, sub { $fragezeichen_mode = 0 } },
	   "indoor-mode"          => sub { push @actions, sub { $door_mode = 'in' } },
	   "outdoor-mode"         => sub { push @actions, sub { $door_mode = 'out' } },
	   "<>"                   => sub { my $f = $_[0]; push @actions, sub { handle_file($f) } },
	  )
    or die "usage: $0 [--today YYYY-MM-DD] [--verbose] [--fragezeichen-mode|--no-fragezeichen-mode|--indoor-mode|--outdoor-mode] ...";

if ($today !~ m{^\d{4}-\d{2}-\d{2}$}) {
    die "Unexpected argument for --today '$today', expected YYYY-MM-DD";
}

if (!@actions) {
    warn "No actions, nothing to do...\n";
    exit;
}

my %colors;
my @time_limits;
if ($coloring) {
    my $today_epoch = do {
	my($Y,$m,$d) = split /-/, $today;
	require Time::Local;
	Time::Local::timelocal(0,0,0,$d,$m-1,$Y);
    };
    my @items = split /\s+/, $coloring;
    my $cat = '?';
    $colors{$cat} = shift @items;
    for(my $i=0; $i<$#items; $i+=2) {
	$cat .= '?';
	my($interval,$color) = @items[$i,$i+1];
	if (my($count,$unit) = $interval =~ m{^\+(\d+)([dwmy])$}) {
	    my $epoch = $today_epoch + $count * {d => 1, w => 7, m => 30, y => 365}->{$unit} * 86400;
	    my $date = strftime "%Y-%m-%d", localtime $epoch;
	    $colors{$cat} = $color;
	    push @time_limits, [$date, $cat];
	} else {
	    die "Invalid interval '$interval'\n";
	}
    }
}

if ($do_preamble) {
    print <<'EOF';
#: line_dash: 8, 5
#: line_width: 5
EOF
    if (%colors) {
	for my $cat (sort { length $a <=> length $b} keys %colors) {
	    print "#: category_color.$cat: $colors{$cat}\n";
	}
    }
    print <<'EOF';
#:
EOF
}

for my $action (@actions) {
    $action->();
}

sub handle_file {
    my($file) = @_;
    if ($verbose) { print STDERR "$file... " }
    my $s = StrassenNextCheck->new_stream($file);

    $s->read_stream_nextcheck_records
	(sub {
	     my($r, $dir) = @_;

	     my $check_now; # undef: not given, 0: given and not now, 1: given and now
	     my $add_name;

	     my $cat;

	     if ($dir->{_nextcheck_date} && $dir->{_nextcheck_date}[0]) {
		 if ($dir->{_nextcheck_date}[0] le $today) {
		     if ($dir->{_nextcheck_label} && $dir->{_nextcheck_label}[0]) {
			 $add_name = "($dir->{_nextcheck_label}[0])";
		     }
		     $check_now = 1;
		 } else {
		 CHECK_TIME_LIMITS: {
			 if (@time_limits) {
			     for my $time_limit (@time_limits) {
				 my($date, $_cat) = @$time_limit;
				 if ($dir->{_nextcheck_date}[0] le $date) {
				     $cat = $_cat;
				     if ($r->[Strassen::CAT] =~ m{^.*?:+(.*)}) { # preserve some category attributes like "projected", "inwork"
					 my(@attr) = grep { $_ =~ m{^(?:projected|inwork|ignrte);?$} } split /::?/, $1;
					 if (@attr) {
					     $cat .= "::" . join("::", @attr);
					 }
				     }
				     $add_name = "($dir->{_nextcheck_label}[0])";
				     $check_now = 1;
				     last CHECK_TIME_LIMITS;
				 }
			     }
			 }
			 $check_now = 0;
		     }
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

	     if (!defined $cat) {
		 if ($r->[Strassen::CAT] =~ m{^\?}) {
		     $cat = $r->[Strassen::CAT];
		 } elsif ($r->[Strassen::CAT] =~ m{:(inwork|projected)}) {
		     $cat = "?::$1";
		 } else {
		     $cat = '?';
		 }
	     }

	     # XXX better!!!
	     $add_name =~ s{[\t\r\n]}{ }g if defined $add_name;
	     print $r->[Strassen::NAME] . (defined $add_name ? (length $r->[Strassen::NAME] ? ' ' : '') . $add_name : '') . "\t$cat " . join(" ", @{ $r->[Strassen::COORDS] }) . "\n";
	 }, passthru_without_nextcheck => 1);

    if ($verbose) { print STDERR "done\n" }
}

__END__

=head1 EXAMPLES

    ./miscsrc/create_fragezeichen_nextcheck.pl -no-fragezeichen-mode data/ampeln-orig -fragezeichen-mode data/fragezeichen-orig -no-fragezeichen-mode data/gesperrt-orig data/qualitaet_s-orig data/qualitaet_l-orig data/handicap_s-orig data/handicap_l-orig tmp/bbbike-temp-blockings-optimized.bbd data/strassen-orig

=cut
