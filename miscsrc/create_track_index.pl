#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: create_track_index.pl,v 1.2 2006/07/05 21:48:46 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
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

use Getopt::Long;
use File::Spec;
use DB_File;
use POSIX qw(strftime);

use GPS::GpsmanData;

my $tmpdir = "$FindBin::RealBin/../tmp";
# mapping: filename -> filename id
my $filename_index_file = "$tmpdir/track_filenames.db";
# mapping: iso date -> list of [filename ids, longitude, latitude], space separated
my $date_index_file = "$tmpdir/track_dates.db";

my $v = 0;

GetOptions("v!" => \$v,
	   "filenameindex=s" => \$filename_index_file,
	   "dateindex=s" => \$date_index_file,
	  )
    or die "usage: $0 [-v] [-filenameindex file] [-dateindex file] tracks ...";

tie my %filenames, "DB_File", $filename_index_file, O_RDWR|O_CREAT, 0644, $DB_HASH
    or die "Can't tie $filename_index_file: $!";
tie my %dates, 'DB_File', $date_index_file, O_RDWR|O_CREAT, 0644, $DB_BTREE
    or die "Can't tie $date_index_file: $!";

my @files = @ARGV;
for my $file (@files) {
    print STDERR "$file ..." if $v;
    my $absfile = File::Spec->file_name_is_absolute($file) ? $file : File::Spec->rel2abs($file);
    if (!seems_like_a_gpsman_file($absfile)) {
	print STDERR " no gpsman file\n" if $v;
	next;
    }

    my $fileindex = $filenames{$absfile};
    if (!defined $fileindex) {
	my $last = $filenames{"_last"} || 0;
	$last++;
	$fileindex = $filenames{$absfile} = $filenames{"_last"} = $last;
    }

    my $gpsman = GPS::GpsmanMultiData->new;
    $gpsman->load($absfile);
    for my $chunk (@{ $gpsman->Chunks }) {
	for my $wpt (@{ $chunk->Points }) {
	    my $unixtime = $wpt->Comment_to_unixtime;
	    my $isodate = strftime("%Y-%m-%dT%H%M%S", localtime $unixtime);
	    next if $isodate lt "1990-01-01T000000";

	    my $olddata = $dates{$isodate} || "";
	    my @olddata = split / /, $olddata;
	TRY: {
		if (@olddata) {
		    for(my $i=0; $i < $#olddata; $i+=3) {
			my $oldfileindex = $olddata[$i];
			if ($oldfileindex == $fileindex) {
			    # replace
			    $olddata[$i+1] = $wpt->Longitude;
			    $olddata[$i+2] = $wpt->Latitude;
			    last TRY;
			}
		    }
		}
		push @olddata, $fileindex, $wpt->Longitude, $wpt->Latitude;
	    }
	    $dates{$isodate} = join " ", @olddata;
	}
    }

    print STDERR "\n" if $v;
}

sub seems_like_a_gpsman_file {
    my($file) = @_;
    open my $fh, $file
	or die "Can't open $file: $!";
    while(<$fh>) {
	return 1 if /^!Format:\s+/;
	return 0 if $. > 100; # read max 100 lines
    }
    return 0;
}

__END__
