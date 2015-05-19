#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2004,2010,2015 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Getopt::Long;
use File::Basename qw(basename);
use File::Path;

my $do;
my $do_mark_as_inexact;
my $do_mark_with_question;
my $do_split_ampelschaltung;
my $do_write_empty;
my $destdir = "/tmp/gpsmansplit";

if (!GetOptions("bydate" => sub { $do = "by_date" },
		"markasinexact!" => \$do_mark_as_inexact,
		"markwithquestion!" => \$do_mark_with_question,
		"splitampelschaltung!" => \$do_split_ampelschaltung,
		"writeempty!" => \$do_write_empty,
		"destdir=s" => \$destdir,
	       )) {
    usage();
}

my @files = @ARGV;
if (!@files) {
    usage("gpsman file(s) missing");
}
my $ext = ".UNKNOWN";

mkpath($destdir, 1, 0777);
my $destdir_ampelschaltung;
if ($do_split_ampelschaltung) {
    $destdir_ampelschaltung = "$destdir/ampelschaltung";
    mkpath($destdir_ampelschaltung, 1, 0777);
}

$do = "" if !defined $do;
if ($do eq 'by_date') {
    my %file_seen;
    my($ofh, $unhandled_ofh);
    for my $file (@files) {
	my $stage = "header";
	my $header;
	my $collection_header;
	my $last_date;
	my $seen_normal_wpts;
	open my $fh, '<', $file
	    or die "Can't open $file: $!";
	while(<$fh>) {
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
			my $dir;
			if ($do_split_ampelschaltung && m{symbol=buoy_white_(red|green)}) {
			    $dir = $destdir_ampelschaltung;
			} else {
			    $dir = $destdir;
			    $seen_normal_wpts = 1;
			}
			my $f = sprintf("$dir/%04d%02d%02d$ext", $y, $m, $d);
			close $ofh if $ofh && defined fileno($ofh);
			if ($file_seen{$f}) {
			    open $ofh, '>>', $f
				or die "Can't append to $f: $!";
			} else {
			    if (-e $f) {
				warn "Overwrite existing file $f...\n";
			    } else {
				warn "Write to $f...\n";
			    }
			    open $ofh, '>', $f
				or die "Can't write $f: $!";
			    print $ofh $header;
			    print $ofh $collection_header;
			    $file_seen{$f}++;
			}
		    }
		    $_ = mark_as_inexact($_) if $do_mark_as_inexact && $stage eq 'track';
		    $_ = mark_with_question($_) if $do_mark_with_question && $stage eq 'track';
		    print $ofh $_;
		} elsif ($_ ne "\n" && $stage eq 'wpt') {
		    if (!defined $unhandled_ofh && !defined fileno($unhandled_ofh)) {
			my $f = "$destdir/unhandled$ext";
			warn "Found waypoints without dates, writing to $f...\n";
			open $unhandled_ofh, '>', $f
			    or die "Can't write $f: $!";
			print $unhandled_ofh $header;
			print $unhandled_ofh $collection_header;
		    }
		    print $unhandled_ofh $_;
		} else {
		    # everything else: passthrough
		    print $ofh $_;
		}
	    }
	}
	close $fh;
	if ($do_write_empty && !$seen_normal_wpts) {
	    my $ofile = "$destdir/" . basename($file);
	    warn "Create empty file $ofile...\n";
	    open my $emptyfh, '>', $ofile
		or die "Can't create $ofile: $!";
	    close $emptyfh
		or die $!;
	}
    }
    close $ofh if $ofh && defined fileno($ofh);
    close $unhandled_ofh if $unhandled_ofh && defined fileno($unhandled_ofh);
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
usage: $0 [-bydate] [-splitampelschaltung] [-markasinexact | -markwithquestion] [-destdir directory] gpsmanfile

-markasinexact:       add "~" to elevation to mark the point as inexact
-markwithquestion:    add "?" to elevation to mark the point as questionable
-destdir:             use another destination directory than $destdir
-bydate:              split the data by date
-splitampelschaltung: split waypoints marked with buoy_white_red/green symbols into separate directory
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

=head1 EXAMPLES

Howto organize your GPS tracks using gpsman and gpsman_split.pl.

    TMPTRACKDIR=$HOME/trash
    BBBIKEDIR=$HOME/src/bbbike
    rm -f $TMPTRACKDIR/track.trk $TMPTRACKDIR/trash/wpt.wpt
    gpsman getwrite TR GPSMan $TMPTRACKDIR/track.trk
    gpsman getwrite WP GPSMan $TMPTRACKDIR/wpt.wpt
    $BBBIKEDIR/miscsrc/gpsman_split.pl -bydate $TMPTRACKDIR/track.trk
    $BBBIKEDIR/miscsrc/gpsman_split.pl -bydate $TMPTRACKDIR/wpt.wpt
    # now copy the files from /tmp/gpsmansplit manually to your track dir or use tkincorporate
    tkincorporate /tmp/gpsmansplit $BBBIKEDIR/misc/gps_data

=cut
