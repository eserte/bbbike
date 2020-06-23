#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2018,2020 Slaven Rezic. All rights reserved.
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
use LWP::UserAgent;
use Term::ANSIColor qw(colored);
use Tie::IxHash;

use Strassen::Core;

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
tie my %check_urls, 'Tie::IxHash';
for my $file (@files) {
    my $s = Strassen->new_stream($file, UseLocalDirectives => 1);
    $s->read_stream
	(sub {
	     my($r, $dir) = @_;
	     for my $by (@{ $dir->{by} || [] }) {
		 if ($by =~ m{^(https?://www.bvg.de/de/Fahrinfo/Verkehrsmeldungen/\S+)}) {
		     my $url = $1;
		     $check_urls{$url} = $r->[Strassen::NAME] if !$check_urls{$url};
		 }
	     }
	 }
	);
}

my $errors = 0;
if (%check_urls) {
    if ($list_only) {
	printerr join("\n", keys %check_urls) . "\n";
    } else {
	my $ua = LWP::UserAgent->new(keep_alive => 1);

	while(my($check_url, $strname) = each %check_urls) {
	    printerr "$check_url ($strname)... ";
	    my $resp = $ua->get($check_url);
	    if (!$resp->is_success) {
		printerr "request failed " . $resp->code, "red on_black";
		$errors++;
	    } else {
		my $content = $resp->decoded_content;
		if ($content =~ m{Die Meldung ist nicht verf.*?gbar}) {
		    printerr "note is not available anymore", "red on_black";
		    $errors++;
		} else {
		    printerr "OK", "green on_black";
		}
	    }
	    printerr "\n";
	}
    }
}

if ($errors) {
    exit 1;
}

# Only rename in the success case. So only bvg_checks.log~ tays around
# and might be inspected, while a failed run would also fail the next
# time and won't get unnoticed.
if ($logfh) {
    close $logfh
	or die $!;
    rename "$log~", $log
	or die "Error while renaming $log~ to $log: $!";
}

__END__
