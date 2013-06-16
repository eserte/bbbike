#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011,2012 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use File::Basename qw(basename);
use File::Temp qw(tempdir);
use Getopt::Long;
use LWP::UserAgent;

use BBBikeDir qw(get_data_osm_directory);
use BBBikeVar ();

sub usage ();

our $VERSION = '0.02';

my $rooturl = 'http://download.bbbike.org/bbbike/data-osm';
my $city;
my $o;
my $agent_suffix;
my $debug = 0;

GetOptions(
	   "url=s" => \$rooturl,
	   "debug=i" => \$debug,
	   "city=s" => \$city,
	   "o=s" => \$o, # download directory, for tests only
	   "agentsuffix=s" => \$agent_suffix, # for tests only
	  )
    or usage;
@ARGV and usage;

my $ua = LWP::UserAgent->new;
$ua->agent("bbbike/$BBBike::VERSION (bbbike.org_download.pl/$VERSION) (LWP::UserAgent/$LWP::VERSION) ($^O)" . ($agent_suffix ? $agent_suffix : ""));

if (!$city) {
    listing();
} else {
    city($city);
}

sub listing {
    my $url = $rooturl . '/';

    require XML::LibXML;
    my $p = XML::LibXML->new;

    my $resp = $ua->get($url);
    die "Can't get $url: " . $resp->status_line
	if !$resp->is_success;

    my $root = $p->parse_html_string($resp->decoded_content)->documentElement;

    for my $a_node ($root->findnodes('//a')) {
	my $href = $a_node->getAttribute('href');
	next if ($href !~ m{\.tbz$});
	$href =~ s{\.tbz$}{};
	print $href, "\n";
    }
}

sub city {
    my $city = shift;
    my $url = "$rooturl/$city.tbz";
    my $data_osm_directory = $o || get_data_osm_directory(-create => 1);
    my $tmpdir = tempdir(DIR => $data_osm_directory, CLEANUP => 1)
	or die "Can't create temporary directory in $data_osm_directory: $!";
    my $tmpfile = "$tmpdir/$city.tbz";
    chdir $data_osm_directory
	or die "Can't chdir to $data_osm_directory: $!";

    print STDERR "Downloading data for $city...\n" if $debug;

    my $resp = $ua->mirror($url, $tmpfile);
    die "Can't get $url to $tmpfile: " . $resp->status_line
	if !$resp->is_success;

    print STDERR "Extracting data to $data_osm_directory...\n" if $debug;
    if (eval { require Archive::Tar; Archive::Tar->has_bzip2_support }) {
	my $success = Archive::Tar->extract_archive($tmpfile);
	if (!$success) {
	    die "Error while extracting $tmpfile with Archive::Tar: " . Archive::Tar->error;
	}
    } else {
	my @cmd = ("tar", "xfj", $tmpfile);
	system @cmd;
	die "Error while extracting using @cmd" if $? != 0;
    }

    print STDERR "Finished.\n" if $debug;
}

sub usage () {
    die <<EOF;
usage: $0 [-url ...] [-city ...]
EOF
}

__END__

=for org TODO

* Download location
  Where exactly to download? Maybe: if bbbike is uninstalled, then
  under .../bbbike/data-osm. If bbbike is installed, then in a user
  directory, e.g. ~/.bbbike/data-osm.
  -> need a function which determines the install type.
     Does something like this exist already?
* How bbbike-chooser.pl and bbbike.org-download.pl should interact?
  Probably this should be a proper module. Name? BBBikeOrgDownload? Or
  BBBikeOrg::Download?
* tar bzip2 under Windows
  Probably done with a module. Is it already in Strawberry?
  -> Archive::Tar & ...::Bzip is available, just try it out
* LWP UserAgent operation: mask as a BBBike UA
  Find my standard UA. Don't forget version, git id etc.
  (BBBikeHeavy::get_user_agent is problematic, because it expects to be run within bbbike, see above)
* Updating
  Do I need to care about things? Or just overwrite existing stuff?

