#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;

{
    package ReverseGeocoding;

    sub new {
	my $class = shift;
	my $using = shift || 'bbbike';
	my $factory_class = 'ReverseGeocoding::' . ucfirst($using);
	$factory_class->new;
    }
}

{
    package ReverseGeocoding::Bbbike;
    use vars qw(@ISA);
    @ISA = 'ReverseGeocoding';

    sub new {
	my $class = shift;

	require Strassen::MultiStrassen;
	require Karte::Polar;
	$Karte::Polar::obj = $Karte::Polar::obj if 0; # cease -w
	require Karte::Standard;

	bless { }, $class;
    }

    sub _get_area_grid {
	my $self = shift;
	if (!$self->{area}) {
	    $self->{area} = MultiStrassen->new('orte', 'orte2');
	}
	$self->{area};
    }

    sub _get_road_grid {
	my $self = shift;
	if (!$self->{road}) {
	    $self->{road} = MultiStrassen->new('strassen', 'landstrassen', 'landstrassen2');
	}
	$self->{road};
    }

    sub find_closest {
	my($self, $pxy, $type) = @_;#
	$type = 'area' if !$type;
	my($sxy) = join ',', $Karte::Polar::obj->map2standard(split /,/, $pxy);
	my $get_grid_method = '_get_' . $type . '_grid'; # 'poi' is unsupported
	my $grid_obj = $self->$get_grid_method;
	my $res = $grid_obj->nearest_point($sxy, FullReturn => 1);
	if ($res) {
	    my $name = $res->{StreetObj}[0];
	    $name =~ s{\|}{ }g; # e.g. "Rollberg|bei Eickstedt"
	    $name;
	} else {
	    undef;
	}
    }
}
	
{
    package ReverseGeocoding::Cloudmade;
    use vars qw(@ISA);
    @ISA = 'ReverseGeocoding';

    sub new {
	my $class = shift;
	
	require Geo::Cloudmade;

	my $apikey = do {
	    my $file = "$ENV{HOME}/.cloudmadeapikey";
	    open my $fh, $file
		or main::status_message("Cannot get key from $file: $!", "die");
	    local $_ = <$fh>;
	    chomp;
	    $_;
	};

	my $geo = Geo::Cloudmade->new($apikey);

	bless { geo => $geo }, $class;
    }

    sub find_closest {
	my($self, $pxy, $type) = @_;
	$type = 'area' if !$type;
	my($px, $py) = split /,/, $pxy;

	my($res) = $self->{geo}->find_closest($type, [$py, $px], {return_geometry=>'False'});
	defined $res ? $res->name : undef;
    }
}

return 1 if caller;

{
    require Getopt::Long;
    require FindBin;
    $FindBin::RealBin = $FindBin::RealBin if 0; # cease -w
    require lib;
    lib->import("$FindBin::RealBin/../lib");
    my $type;
    my $module;
    Getopt::Long::GetOptions('module=s' => \$module, 'type=s' => \$type) or die "usage?";
    if (@ARGV == 1) {
	@ARGV = split /,/, $ARGV[0];
    }
    die "Expects longitude and latitude" if @ARGV != 2;
    my($px, $py) = @ARGV;
    print ReverseGeocoding->new($module)->find_closest("$px,$py", $type), "\n";
}

__END__

=head1 EXAMPLES

Using from command line:

    perl miscsrc/ReverseGeocoding.pm 13.5 52.5

Different geocoding modules:

    perl -module bbbike miscsrc/ReverseGeocoding.pm 13.5 52.5

    perl -module cloudmade miscsrc/ReverseGeocoding.pm 13.5 52.5

Different types (road, api, area):

    perl -module bbbike -type road miscsrc/ReverseGeocoding.pm 13.5 52.5

C<-type area> is the default. Note that the bbbike module does not
have general poi search yet.

Inject location names into track meta files (see L<GPS::GpsmanData::Stats>):

    perl -Mstrict -MYAML::Syck=LoadFile,DumpFile -Imiscsrc -Ilib -MReverseGeocoding -e 'my $rb=ReverseGeocoding->new("bbbike"); my $rc=ReverseGeocoding->new("cloudmade"); for my $file (@ARGV) { my @route_name; my $d = LoadFile $file; next if $d->{route_name}; warn $file; for my $loc (@{$d->{route}||[]}) { my $res = $rb->find_closest($loc, "road"); if (!$res) { warn "   use cloudmade...\n"; $res = $rc->find_closest($loc, "road") . ", " . $rc->find_closest($loc) } push @route_name, $res } $d->{route_name} = \@route_name; DumpFile($file, $d) }' /tmp/trkstats/*.yml

=cut
