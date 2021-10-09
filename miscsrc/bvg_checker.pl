#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2018,2020,2021 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use FindBin;
my $bbbike_dir; BEGIN { $bbbike_dir = "$FindBin::RealBin/.." }
use lib $bbbike_dir, "$bbbike_dir/lib";

use File::Glob qw(bsd_glob);
use Getopt::Long;
use Term::ANSIColor qw(colored);
use Tie::IxHash;

use Strassen::Core;

my $id_prefix = 'bvg2021';

GetOptions(
	   "list-only" => \my $list_only,
	   "log=s" => \my $log,
	  )
    or die "usage?";

my $logfh;
if ($log) {
    open $logfh, ">", "$log~"
	or die "Can't write to $log~: $!";
}

sub printerr ($;$) {
    my($msg, $color) = @_;
    if ($color) {
	print STDERR colored([$color], $msg);
    } else {
	print STDERR $msg;
    }
    if ($logfh) {
	print $logfh $msg;
    }
}

my @files = (
	     bsd_glob("$bbbike_dir/data/*-orig"),
	     "$bbbike_dir/tmp/bbbike-temp-blockings-optimized.bbd",
	    );
tie my %check_sourceids, 'Tie::IxHash';
for my $file (@files) {
    my $s = Strassen->new_stream($file, UseLocalDirectives => 1);
    $s->read_stream
	(sub {
	     my($r, $dir) = @_;
	     for my $by (@{ $dir->{by} || [] }) {
		 if ($by =~ m{^(https?://www.bvg.de/de/Fahrinfo/Verkehrsmeldungen/\S+)}) {
		     my $url = $1;
		     printerr "WARNING: Found old by directive in $file for $r->[Strassen::NAME]: $url", "red on_black"; printerr "\n";
		 }
	     }
	     for my $sourceid (@{ $dir->{source_id} || [] }) {
		 if ($sourceid =~ m{^(\Q$id_prefix\E:\S+)}) {
		     $check_sourceids{$1} = $r->[Strassen::NAME];
		 }
	     }
	 }
	);
}

my $errors = 0;
if (%check_sourceids) {
    if ($list_only) {
	printerr join("\n", keys %check_sourceids) . "\n";
    } else {
	my $traffic_url = 'https://www.bvg.de/de/verbindungen/stoerungsmeldungen?type=traffic';
	require Firefox::Marionette;
	my $firefox = Firefox::Marionette->new->go($traffic_url);
	$firefox->await(sub { $firefox->loaded });
	my %links;
	{
	    my(@old_links, @links);
	    for my $try (1..3) {
		@links = map {
		    my $href = $_->attribute('href');
		    if ($href && $href =~ m{/de/verbindungen/stoerungsmeldungen/(.*#.*)}) {
			$1;
		    } else {
			();
		    }
		} $firefox->find('//a');
		if (!@links || (@old_links < @links)) {
		    @old_links = @links;
		    warn "INFO: sleep another second to make sure that the page is complete...\n" if $try > 1;
		    sleep 1;
		    next;
		}
	    }
	    if (!@links) {
		# likely a severe problem (connection problems, page not found, site changed...)
		die "Cannot find any entries in $traffic_url.\n";
	    }
	    %links = map {("$id_prefix:$_",1)} @links;
	}

	while(my($check_sourceid, $strname) = each %check_sourceids) {
	    printerr "$check_sourceid ($strname)... ";
	    if (!$links{$check_sourceid}) {
		printerr "note is not available anymore", "red on_black";
		$errors++;
	    } else {
		printerr "OK", "green on_black";
	    }
	    printerr "\n";
	}
    }
}

if ($errors) {
    exit 1;
}

# Only rename in the success case. So only bvg_checks.log~ stays around
# and might be inspected, while a failed run would also fail the next
# time and won't get unnoticed.
if ($logfh) {
    close $logfh
	or die $!;
    rename "$log~", $log
	or die "Error while renaming $log~ to $log: $!";
}

__END__
