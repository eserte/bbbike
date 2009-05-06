# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2008,2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Example usage: ./miscsrc/bbbikedraw.pl -bbox 8000,8000,12000,12000 -module GoogleMapsStatic -imagetype png | display -

package BBBikeDraw::GoogleMapsStatic;

use strict;
use vars qw($VERSION $DEBUG);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use base qw(BBBikeDraw);

use CGI            qw();
use LWP::UserAgent qw();

use Karte;
Karte::preload(qw(Standard Polar));

sub pre_draw {
    my $self = shift;
    $self->{PreDrawCalled}++;
}

sub flush {
    my $self = shift;
    my %args = @_;

    my $ua = LWP::UserAgent->new;
    $ua->agent($ua->agent . " (" . __PACKAGE__ . " " . $VERSION . ")");

    my $google_api_key_file = "$ENV{HOME}/.googlemapsapikey";
    my $my_api_key;
    if (open(APIKEY, $google_api_key_file)) {
	$my_api_key = <APIKEY>;
	$my_api_key =~ s{[\r\n\s+]}{}g;
	close APIKEY;
	warn "Loaded Google Maps API key from $google_api_key_file...\n" if $DEBUG;
    }
    if (!$my_api_key) {
	die "No googlemapsapikey, cannot continue...";
    }

    my @multi_c = @{ $self->{MultiCoords} || [] } ? @{ $self->{MultiCoords} } : @{ $self->{Coords} || [] } ? [ @{ $self->{Coords} } ] : ();
    my $path;
    my $center;
    if (@multi_c) {
	$path = join("|", map { join("|", map {
	    my($x, $y) = $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map(split /,/, $_));
	    $y.",".$x;
	} @$_) } @multi_c);
	$path = 'rgb:0x0000ff,weight:5|' . $path; # XXX make settable
    } else {
	my($cx,$cy) = ($self->{Min_x} + ($self->{Max_x}-$self->{Min_x})/2,
		       $self->{Min_y} + ($self->{Max_y}-$self->{Min_y})/2,
		      );
	($cx,$cy) = $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map($cx, $cy));
	$center = $cy.",".$cx;
    }

    my $marker_c;
    if ($self->{MarkerPoint}) {
	my($x,$y) = $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map(split /,/, $self->{MarkerPoint}));
	$marker_c = "$y,$x";
    }

    my $format = ($self->{ImageType} eq 'png' ? 'png32' :
		  $self->{ImageType} eq 'jpeg' ? 'jpg' : 'gif');

    # max imagesize according to http://code.google.com/apis/maps/documentation/staticmaps/#Imagesizes
    my $w = $self->{Width};
    my $h = $self->{Height};
    if ($w > 640) {
	$h = $h*(640/$w);
	$w = 640;
    }
    if ($h > 640) {
	$w = $w*(640/$h);
	$h = 640;
    }

    CGI->import('-oldstyle_urls');
    my $qs = CGI->new({size => $w."x".$h,
		       maptype => "mobile", # XXX make settable
		       ($marker_c ? (markers => "$marker_c,red") : ()),
		       # markers=40.702147,-74.015794,blues%7C40.711614,-74.012318,greeng%7C40.718217,-73.998284,redc
		       key => $my_api_key,
		       format => $format,
		       ($path ? (path => $path) :
			( center => $center,
			  zoom => 14, # XXX
			)
		       ),
		      })->query_string;
    my $url = "http://maps.google.com/staticmap?$qs";
    my $resp = $ua->get($url);
    die "Error while getting $url: " . $resp->status_line if !$resp->is_success;

    my $fh = $args{Fh} || $self->{Fh};
    binmode $fh;
    print $fh $resp->decoded_content;
}

1;

__END__
