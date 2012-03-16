#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;

use File::Basename qw(basename);
use File::Temp qw(tempdir);
use Getopt::Long;
use LWP::UserAgent;
use XML::LibXML;

#use lib "/home/e/eserte/src/bbbike"; # XXX!!!
#use BBBikeHeavy ();

my $rooturl = 'http://download.bbbike.org/bbbike/data-osm/';
my $bbbikedir = "$ENV{HOME}/src/bbbike";
my $city;
GetOptions("url=s" => \$rooturl,
	   "city=s" => \$city,
	  )
    or die "usage?";
@ARGV and die "usage?";

## This would work, but throws a number of warnings because BBBikeHeavy expects some
## variables only defined within bbbike application ($os, $progname...)
#my $ua = BBBikeHeavy::get_user_agent();
#die "Cannot get user agent" if !$ua;
my $ua = LWP::UserAgent->new;
my $p = XML::LibXML->new;

if (!$city) {
    listing();
} else {
    city($city);
}

sub listing {
    my $url = $rooturl;

    my $resp = $ua->get($url);
    die "Can't get $url: " . $resp->status_line
	if !$resp->is_success;

    my $root = $p->parse_html_string($resp->decoded_content)->documentElement;

    for my $a_node ($root->findnodes('//a')) {
	my $href = $a_node->getAttribute('href');
	next if ($href !~ m{\.tbz$});
	print $href, "\n";
    }
}

sub city {
    my $city = shift;
    my $url = "$rooturl/$city.tbz";
    my $tmpdir = tempdir(TMPDIR => 1, CLEANUP => 1)
	or die "Can't create temporary directory: $!";
    my $tmpfile = "$tmpdir/$city.tbz";
    my $dataosmdir = "$bbbikedir/data-osm";
    if (!-d $dataosmdir) {
	mkdir $dataosmdir
	    or die "Can't create $dataosmdir: $!";
    }
    chdir $dataosmdir
	or die "Can't chdir to $dataosmdir: $!";

    print STDERR "Downloading data for $city...\n";

    my $resp = $ua->mirror($url, $tmpfile);
    die "Can't get $url to $tmpfile: " . $resp->status_line
	if !$resp->is_success;

    print STDERR "Extracting data to $dataosmdir...\n";
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

    print STDERR "Finished.\n";
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

