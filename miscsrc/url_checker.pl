#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
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
use LWP::UserAgent;

use Strassen::Core;

sub usage () {
    die "usage: $0 [-frequency days] [-n] [-v] -log file bbdfile ...";
}

my $check_frequency = 30; # days
my $log_file;
my $dry_run;
my $v;
GetOptions("frequency=i" => \$check_frequency,
	   "log=s"       => \$log_file,
	   "n|dry-run"   => \$dry_run,
	   "v"           => \$v,
	  )
    or usage;
defined $log_file or usage;

sub v_print (@) { print STDERR @_ if $v }

my %seen_urls;
if (open my $fh, "+<", $log_file) {
    while(<$fh>) {
	chomp;
	my($url, $epoch, $status) = split /\s+/, $_, 3;
	die "Cannot parse line '$_'" if !defined $epoch || !defined $status;
	my $age = time - $epoch;
	if ($age/86400 < $check_frequency) {
	    $seen_urls{$url} = [$epoch, $status];
	}
    }
}

my $ofh;
if (!$dry_run) {
    open $ofh, ">>", $log_file
	or die "Cannot write to file $log_file: $!";
}

my $ua = LWP::UserAgent->new;

my @files = @ARGV
    or usage;
my @errors;
for my $file (@files) {
    my $s = Strassen->new_stream($file, UseLocalDirectives => 1);
    $s->read_stream
	(sub {
	     my($r, $dir) = @_;
	     for my $url (@{ $dir->{url} || [] }) {
		 next if exists $seen_urls{$url};
		 v_print "Check URL <$url> ... ";
		 if (!$dry_run) {
		     my $resp = $ua->head($url);
		     if (!$resp->is_success) {
			 # maybe HEAD is not supported?
			 $resp = $ua->get($url);
		     }
		     my $status = $resp->code;
		     v_print $status;
		     print $ofh join("\t", $url, time, $status), "\n";
		     $seen_urls{$url} = [time, $status];
		     if (!$resp->is_success) {
			 push @errors, [$url, $status];
			 v_print " ERROR!";
		     }
		 } else {
		     print STDERR "Would check URL <$url>...\n" if !$v;
		     $seen_urls{$url} = [time, '200'];
		 }
		 v_print "\n";
	     }
	 });
}

if ($ofh) {
    close $ofh
	or die "Error while closing $log_file: $!";
}

if (@errors) {
    print "Found following errors:\n" . join("\n", map { "$_->[0]\t$_->[1]" } @errors) . "\n";
    exit 1;
}

__END__
