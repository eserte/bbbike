#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: gpsman_split.pl,v 1.4 2004/03/02 08:37:58 eserte Exp $
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
my $ext = ".trk"; # XXX get from file?

mkpath([$destdir], 1, 0777);

$do = "" if !defined $do;
if ($do eq 'by_date') {
    my $stage = "header";
    my $header;
    my $track_header;
    my $last_date;
    open(F, $file) or die $!;
    while(<F>) {
	if ($stage eq 'header') {
	    if (/^!T:\t/) {
		$track_header = $_;
		$stage = "track";
	    } elsif ($do_mark_as_inexact && /^$/) {
		$header .= "\n% whole track marked as inexact\n\n";
	    } elsif ($do_mark_with_question && /^$/) {
		$header .= "\n% whole track marked with question mark\n\n";
	    } else {
		$header .= $_;
	    }
	} else {
	    if (/^\t(\d+-[^-]+-\d+)\s/) {
		my $date = $1;
		if (!defined $last_date || $last_date ne $date) {
		    my($d,$m,$y) = $date =~ /(\d+)-([^-]+)-(\d+)/;
		    $m = monthabbrev_number($m);
		    my $f = sprintf("$destdir/%02d%02d%02d$ext", $y, $m, $d);
		    warn "Write to $f...\n";
		    close OUT if defined fileno(OUT);
		    if (-e $f) {
			warn "Overwrite existing file $f...\n";
		    }
		    open(OUT, ">$f") or die "Can't write $f: $!";
		    print OUT $header;
		    print OUT $track_header;
		    $_ = mark_as_inexact($_) if $do_mark_as_inexact;
		    $_ = mark_with_question($_) if $do_mark_with_question;
		    print OUT $_;
		    $last_date = $date;
		} else {
		    $_ = mark_as_inexact($_) if $do_mark_as_inexact;
		    $_ = mark_with_question($_) if $do_mark_with_question;
		    print OUT $_;
		}
	    }
	}
    }
    close F;
    close OUT if defined fileno(OUT);
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
usage: $0 [-bydate] [-markasinexact] [-destdir directory] gpsmanfile

-markasinexact: add "~" to elevation to mark the point as inexact
-destdir:       use another destination directory than $destdir
-bydate:        split the data by date
EOF
}

# REPO BEGIN
# REPO NAME monthabbrev_number /home/e/eserte/src/repository 
# REPO MD5 5dc25284d4ffb9a61c486e35e84f0662
sub monthabbrev_number {
    my $mon = shift;
    +{'Jan' => 1,
      'Feb' => 2,
      'Mar' => 3,
      'Apr' => 4,
      'May' => 5,
      'Jun' => 6,
      'Jul' => 7,
      'Aug' => 8,
      'Sep' => 9,
      'Oct' => 10,
      'Nov' => 11,
      'Dec' => 12,
     }->{$mon};
}
# REPO END

__END__
