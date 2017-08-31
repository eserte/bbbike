# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::Info::GarminDevice;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

sub new {
    my($class, %args) = @_;
    my $file = delete $args{file};
    die "Unhandled args: " . join(" ", %args) if %args;
    bless {
	   file   => $file,
	   config => undef,
	  }, $class;
}

sub get_config {
    my($self) = @_;

    return $self->{config} if $self->{config};

    my %config;
    my $do_get_config = sub {
	my $file = shift;

	require XML::LibXML;
	my $p = XML::LibXML->load_xml(location => $file);
	$p->documentElement->setNamespaceDeclURI(undef, undef);

	$config{model} = $p->findvalue('/Device/Model/Description');

	for my $data_type_node ($p->findnodes('/Device/MassStorageMode/DataType')) {
	    my %data_type = (name => $data_type_node->findvalue('./Name'));
	    for my $file_node ($data_type_node->findnodes('./File')) {
		my $get_existing_nodeval = sub {
		    my($key, $path) = @_;
		    my($node) = $file_node->findnodes($path);
		    if ($node) {
			($key => $node->findvalue('.'));
		    } else {
			();
		    }
		};
		my %file =
		    (
		     $get_existing_nodeval->(path              => './Location/Path'),
		     $get_existing_nodeval->(basename          => './Location/BaseName'),
		     $get_existing_nodeval->(fileextension     => './Location/FileExtension'),
		     $get_existing_nodeval->(transferdirection => './TransferDirection'),
		    );
		push @{ $data_type{files} }, \%file;
	    }
	    push @{ $config{data_types} }, \%data_type;
	}
    };

    if (defined $self->{file}) {
	$do_get_config->($self->{file})
    } else {
	# Convenience: mount device
	require GPS::BBBikeGPS::MountedDevice;
	GPS::BBBikeGPS::MountedDevice->maybe_mount
		(sub {
		     my $dir = shift;
		     my $file = "$dir/Garmin/GarminDevice.xml";
		     $do_get_config->($file);
		 });
    }

    \%config;
}

sub get_device_model {
    my($self) = @_;
    my $config = $self->get_config;
    $config->{model};
}

1;

__END__

=head1 NAME

GPS::Info::GarminDevice - get information about a Garmin device

=head1 SYNOPSIS

    use GPS::Info::GarminDevice;
    ## The device is already mounted:
    my $gigd = GPS::Info::GarminDevice->new(file => "/path/to/device/Garmin/GarminDevice.xml");
    ## Alternatively: automatically do a temporary mount and discover path to GarminDevice.xml automatically
    #  my $gigd = GPS::Info::GarminDevice->new;
    $config = $gigd->get_config; # config hash
    $device_model = $gigd->get_device_model; # e.g. "eTrex 30"

=cut
