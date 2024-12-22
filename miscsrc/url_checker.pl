#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010,2014,2016,2018,2023,2024 Slaven Rezic. All rights reserved.
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
    die "usage: $0 [-frequency days] [-n] [-v] [-debug] -log file bbdfile ...";
}

our $VERSION = '0.06';

my $check_frequency = 30; # days
my $log_file;
my $dry_run;
my $v;
my $debug;
GetOptions("frequency=i" => \$check_frequency,
	   "log=s"       => \$log_file,
	   "n|dry-run"   => \$dry_run,
	   "v"           => \$v,
	   "debug"       => \$debug,
	  )
    or usage;
defined $log_file or usage;

sub v_print (@) { print STDERR @_ if $v }

my %nonexpired_urls;
if (open my $fh, "<", $log_file) {
    while(<$fh>) {
	chomp;
	my($url, $epoch, $status) = split /\s+/, $_, 3;
	die "Cannot parse line '$_'" if !defined $epoch || !defined $status;
	my $age = time - $epoch;
	if ($age/86400 < $check_frequency) {
	    $nonexpired_urls{$url} = [$epoch, $status];
	}
    }
}

my $ofh;
if (!$dry_run) {
    open $ofh, ">", "$log_file~"
	or die "Cannot write to file $log_file~: $!";
}

my $ua = LWP::UserAgent->new;
# some servers (e.g. flaeming-skate.de) return a 403 if no Accept
# header is available
$ua->default_headers->push_header('Accept' => 'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5');
# some servers don't like user agents with "libwww-perl" or "LWP"
$ua->agent("url_checker.pl/$VERSION");

my @files = @ARGV
    or usage;
my @errors;
my %seen_urls;
for my $file (@files) {
    my $s = Strassen->new_stream($file, UseLocalDirectives => 1);
    $s->read_stream
	(sub {
	     my($r, $dir) = @_;
	     for my $url (@{ $dir->{url} || [] }) {
		 $url =~ s{\s.*}{}; # strip comments
		 next if $seen_urls{$url};
		 v_print "Check URL <$url> ... ";
		 if (!$dry_run) {
		     if (exists $nonexpired_urls{$url}) {
			 v_print " skip, was checked before " . int((time-$nonexpired_urls{$url}->[0])/86400) . " day(s)";
			 print $ofh join("\t", $url, $nonexpired_urls{$url}->[0], $nonexpired_urls{$url}->[1]), "\n";
		     } else {
			 my $resp = $ua->head($url);
			 if (!$resp->is_success) {
			     # maybe HEAD is not supported?
			     $resp = $ua->get($url);
			 }
			 my $status = $resp->code;
			 v_print $status;
			 print $ofh join("\t", $url, time, $status), "\n";
			 if (!$resp->is_success) {
			     push @errors, [$url, $status];
			     v_print " ERROR!";
			     if ($debug) {
				 print STDERR $resp->dump;
			     }
			 }
		     }
		 } else {
		     if (!exists $nonexpired_urls{$url}) {
			 print STDERR "Would check URL <$url>...\n" if !$v;
		     }
		 }
		 v_print "\n";
		 $seen_urls{$url} = 1;
	     }
	 });
}

if ($ofh) {
    close $ofh
	or die "Error while closing $log_file~: $!";
    rename "$log_file~", $log_file
	or die "Error while renaming $log_file~ to $log_file: $!";
}

if (@errors) {
    print "Found following errors:\n" . join("\n", map { "$_->[0]\t$_->[1]" } @errors) . "\n";
    exit 1;
}

__END__
