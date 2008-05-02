#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: gpsman_split.pl,v 1.8 2008/05/02 18:43:28 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Getopt::Long;
use File::Path;

my $do;
my $do_mark_as_inexact;
my $do_mark_with_question;
my $destdir = "/tmp/gpsmansplit";

if (!GetOptions("bydate" => sub { $do = "by_date" },
		"markasinexact!" => \$do_mark_as_inexact,
		"markwithquestion!" => \$do_mark_with_question,
		"destdir=s" => \$destdir,
	       )) {
    usage();
}

my $file = shift || usage("gpsman file missing");
my $ext = ".UNKNOWN";

mkpath([$destdir], 1, 0777);

$do = "" if !defined $do;
if ($do eq 'by_date') {
    my $stage = "header";
    my $header;
    my $collection_header;
    my $last_date;
    my %file_seen;
    open(F, $file) or die $!;
    while(<F>) {
	if ($stage eq 'header') {
	    if (/^!T:\t/) {
		$collection_header = $_;
		$stage = "track";
		$ext = ".trk";
	    } elsif (/^!W:$/) {
		$collection_header = $_;
		$stage = 'wpt';
		$ext = ".wpt";
	    } elsif ($do_mark_as_inexact && /^$/) {
		$header .= "\n% whole track marked as inexact\n\n";
	    } elsif ($do_mark_with_question && /^$/) {
		$header .= "\n% whole track marked with question mark\n\n";
	    } else {
		$header .= $_;
	    }
	} else {
	    if (($stage eq 'track' && /^\t(\d+-[^-]+-\d+)\s/) ||
		($stage eq 'wpt' && /^[^\t]+\t(\d+-[^-]+-\d+)\s/)
	       ) {
		my $date = $1;
		if (!defined $last_date || $last_date ne $date) {
		    my($d,$m,$y) = $date =~ /(\d+)-([^-]+)-(\d+)/;
		    if (length($y) == 2) {
			$y = 2000+$y;
		    }
		    $m = monthabbrev_number($m);
		    my $f = sprintf("$destdir/%04d%02d%02d$ext", $y, $m, $d);
		    close OUT if defined fileno(OUT);
		    if ($file_seen{$f}) {
			open(OUT, ">>$f") or die "Can't append to $f: $!";
		    } else {
			if (-e $f) {
			    warn "Overwrite existing file $f...\n";
			} else {
			    warn "Write to $f...\n";
			}
			open(OUT, ">$f") or die "Can't write $f: $!";
			print OUT $header;
			print OUT $collection_header;
			$file_seen{$f}++;
		    }
		}
		$_ = mark_as_inexact($_) if $do_mark_as_inexact && $stage eq 'track';
		$_ = mark_with_question($_) if $do_mark_with_question && $stage eq 'track';
		print OUT $_;
	    } elsif ($_ ne "\n" && $stage eq 'wpt') {
		if (!defined fileno(UNHANDLED_OUT)) {
		    my $f = "$destdir/unhandled$ext";
		    warn "Found waypoints without dates, writing to $f...\n";
		    open UNHANDLED_OUT, ">$f" or die "Can't write $f: $!";
		    print UNHANDLED_OUT $header;
		    print UNHANDLED_OUT $collection_header;
		}
		print UNHANDLED_OUT $_;
	    } else {
		# everything else: passthrough
		print OUT $_;
	    }
	}
    }
    close F;
    close OUT if defined fileno(OUT);
    close UNHANDLED_OUT if defined fileno(UNHANDLED_OUT);
} else {
    usage("The -bydate option is mandatory for now");
}

sub mark_as_inexact {
    my $line = shift;
    my(@f) = split /\t/, $line;
    $f[4] = "~$f[4]" unless $f[4] =~ /^~/;
    join("\t", @f);
}

sub mark_with_question {
    my $line = shift;
    my(@f) = split /\t/, $line;
    $f[4] = "?$f[4]" unless $f[4] =~ /^\?/;
    join("\t", @f);
}

sub usage {
    my $msg = shift;
    if (defined $msg) {
	print STDERR "$msg\n";
    }
    die <<EOF;
usage: $0 [-bydate] [-markasinexact | -markwithquestion] [-destdir directory] gpsmanfile

-markasinexact:    add "~" to elevation to mark the point as inexact
-markwithquestion: add "?" to elevation to mark the point as questionable
-destdir:          use another destination directory than $destdir
-bydate:           split the data by date
EOF
}

# REPO BEGIN
# REPO NAME monthabbrev_number /home/e/eserte/src/repository 
# REPO MD5 5dc25284d4ffb9a61c486e35e84f0662
sub monthabbrev_number {
    my $mon = shift;
    +{'jan' => 1,
      'feb' => 2,
      'mar' => 3,
      'apr' => 4,
      'may' => 5,
      'jun' => 6,
      'jul' => 7,
      'aug' => 8,
      'sep' => 9,
      'oct' => 10,
      'nov' => 11,
      'dec' => 12,
     }->{lc($mon)};
}
# REPO END

__END__
