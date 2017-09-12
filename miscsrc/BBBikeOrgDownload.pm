# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2016,2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeOrgDownload;

use strict;
use vars qw($VERSION);
$VERSION = '0.06';

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
	   debug        => $debug,
	  }, $class;
}

sub listing {
    my($self) = @_;

    my $url = $self->{root_url} . '/';
    my $debug = $self->{debug};
    my $ua = $self->{ua};

    require XML::LibXML;
    my $p = XML::LibXML->new;

    print STDERR "Downloading listing from $url...\n" if $debug;

    my $resp = $ua->get($url);
    die "Can't get $url: " . $resp->status_line
	if !$resp->is_success;

    print STDERR "Parsing listing using XML::LibXML...\n" if $debug;

    my $root = $p->parse_html_string($resp->decoded_content)->documentElement;

    my @cities;
    for my $a_node ($root->findnodes('//a')) {
	my $href = $a_node->getAttribute('href');
	next if ($href !~ m{\.tbz$});
	$href =~ s{\.tbz$}{};
	push @cities, $href;
    }

    print STDERR "Parsing done, found " . scalar(@cities) . " cities.\n" if $debug;

    @cities;
}

sub get_city_url {
    my($self, $city) = @_;
    my $root_url = $self->{root_url};
    "$root_url/$city.tbz";
}

sub get_city {
    my($self, $city) = @_;

    my $debug = $self->{debug};
    my $ua = $self->{ua};

    my $url = $self->get_city_url($city);
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
    if (eval { require Archive::Tar; Archive::Tar->has_bzip2_support; }) {
	no warnings 'redefine';
	local *Archive::Tar::_get_handle = \&Archive::Tar::_get_handle;
	if ($Archive::Tar::VERSION < 2.24) {
	    # Workaround for pbzip2-compressed tarballs, see
	    # https://rt.cpan.org/Ticket/Display.html?id=119262
	    # Fixed in 2.24
	    print STDERR "Monkey-patching Archive::Tar $Archive::Tar::VERSION...\n" if $debug;
	    *Archive::Tar::_get_handle = sub {
		my($self, $file) = @_;
		no warnings 'once';
		my $fh = IO::Uncompress::Bunzip2->new( $file, MultiStream => 1 ) ||
		    $self->_error( qq[Could not read '$file': ] .
				   $IO::Uncompress::Bunzip2::Bunzip2Error
				 );
		$fh;
	    };
	}
	my $success = Archive::Tar->extract_archive($tmpfile);
	# Can't check just for $success, see
	# https://rt.cpan.org/Ticket/Display.html?id=118850
	if (!$success || Archive::Tar->error) {
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
