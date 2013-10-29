# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeOrgDownload;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use File::Basename qw(basename);
use File::Temp qw(tempdir);
use LWP::UserAgent;

use BBBikeDir qw(get_data_osm_directory);
use BBBikeUtil qw(save_pwd2);
use BBBikeVar ();

use constant DEFAULT_ROOT_URL => 'http://download.bbbike.org/bbbike/data-osm';

sub new {
    my($class, %args) = @_;
    my $agent_suffix = delete $args{agentsuffix}; # for tests only
    my $download_dir = delete $args{downloaddir}; # for tests only
    my $root_url     = delete $args{url} || DEFAULT_ROOT_URL;
    my $debug        = delete $args{debug};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    my $ua = LWP::UserAgent->new;
    $ua->agent("bbbike/$BBBike::VERSION (" . __PACKAGE__ . "/$VERSION) (LWP::UserAgent/$LWP::VERSION) ($^O)" . ($agent_suffix ? $agent_suffix : ""));

    bless {
	   ua           => $ua,
	   download_dir => $download_dir,
	   root_url     => $root_url,
	   debug        => 0,
	  }, $class;
}

sub listing {
    my($self) = @_;
    my $url = $self->{root_url} . '/';

    require XML::LibXML;
    my $p = XML::LibXML->new;

    my $ua = $self->{ua};
    my $resp = $ua->get($url);
    die "Can't get $url: " . $resp->status_line
	if !$resp->is_success;

    my $root = $p->parse_html_string($resp->decoded_content)->documentElement;

    my @cities;
    for my $a_node ($root->findnodes('//a')) {
	my $href = $a_node->getAttribute('href');
	next if ($href !~ m{\.tbz$});
	$href =~ s{\.tbz$}{};
	push @cities, $href;
    }

    @cities;
}

sub get_city {
    my($self, $city) = @_;

    my $root_url = $self->{root_url};
    my $debug = $self->{debug};
    my $ua = $self->{ua};

    my $url = "$root_url/$city.tbz";
    my $data_osm_directory = $self->{download_dir} || get_data_osm_directory(-create => 1);
    my $tmpdir = tempdir(DIR => $data_osm_directory, CLEANUP => 1)
	or die "Can't create temporary directory in $data_osm_directory: $!";
    my $tmpfile = "$tmpdir/$city.tbz";
    my $save_pwd = save_pwd2;
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

1;

__END__

=for org TODO

* Download location
  Where exactly to download? Maybe: if bbbike is uninstalled, then
  under .../bbbike/data-osm. If bbbike is installed, then in a user
  directory, e.g. ~/.bbbike/data-osm.
  -> need a function which determines the install type.
     Does something like this exist already?
* tar bzip2 under Windows
  Probably done with a module. Is it already in Strawberry?
  -> Archive::Tar & ...::Bzip is available, just try it out
* LWP UserAgent operation: mask as a BBBike UA
  Find my standard UA. Don't forget version, git id etc.
  (BBBikeHeavy::get_user_agent is problematic, because it expects to be run within bbbike, see above)
* Updating
  Do I need to care about things? Or just overwrite existing stuff?

