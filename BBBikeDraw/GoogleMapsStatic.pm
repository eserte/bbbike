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

=head1 NAME

BBBikeDraw::GoogleMapsStatic - draw maps via the Google Static Maps API

=head1 SYNOPSIS

From command line:

    ./miscsrc/bbbikedraw.pl -bbox 8000,8000,12000,12000 -module GoogleMapsStatic -imagetype png | display -
    ./miscsrc/bbbikedraw.pl -markerpoint 10000,1000 -routefile /path/to/track.trk -module GoogleMapsStatic -imagetype png | display -

For module usage see L<BBBikeDraw>.

=head1 NOTES

=head2 Long paths

The URI length of the API request is limited to 2048 bytes for the
path part. To get over this limit for long routes, a simplification
algortihm (i.e. douglas-peucker) is used on the path, beginning with a
tolerance parameter of 10, and then increasing by 100 until 1000 is
reached.

There will be issued a mandatory warning if the simplification
algortihm is triggered.

=head2 Encoded polylines

To save space for long routes, it is possible to use a compression
algorithm. This is available if L<Algorithm::GooglePolylineEncoding>
is installed.

=head1 EXAMPLES

To create all tracks into static maps:

    cd .../bbbike
    mkdir /tmp/googlemapsstatic
    for i in misc/gps_data/*.trk; do dest=/tmp/googlemapsstatic/`basename $i`.png; [ -e $dest ] || (echo $dest; ./miscsrc/bbbikedraw.pl -routefile $i -module GoogleMapsStatic -imagetype png > $dest); done

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<BBBikeDraw>, L<Algorithm::GooglePolylineEncoding>.

=cut

package BBBikeDraw::GoogleMapsStatic;

use strict;
use vars qw($VERSION $DEBUG);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use base qw(BBBikeDraw);

use URI::Escape    qw(uri_escape);
use LWP::UserAgent qw();

use Karte;
Karte::preload(qw(Standard Polar));

#use constant LIMIT_URI_PATH => 2048; # does not work anymore
use constant LIMIT_URI_PATH => 1630; # the limit is somewhere between 1630 and 1866

sub pre_draw {
    my $self = shift;
    $self->{PreDrawCalled}++;
}

sub draw_route { } # dummy, everything's done in flush()

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
    my @paths;
    my $center;
    if (@multi_c) {
	@paths = _make_paths_from_coords(\@multi_c);
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

    my $format = (($self->{ImageType}||'') eq 'png' ? 'png32' :
		  ($self->{ImageType}||'') eq 'jpeg' ? 'jpg' : 'gif');

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

    my $url;
    my $tolerance = 0;
    while(1) {
	if ($tolerance) {
	    @paths = _shorten_paths(\@multi_c, $tolerance);
	}
	my @cgi_params = ("size=${w}x${h}",
			  'maptype=roadmap', # XXX make configurable (hybrid, satellite etc.)
			  'mobile=true',
			  'sensor=false',
			  ($marker_c ? ("markers=size:mid|color:red|$marker_c") : ()),
			  # markers=40.702147,-74.015794,blues%7C40.711614,-74.012318,greeng%7C40.718217,-73.998284,redc
			  "key=$my_api_key",
			  "format=$format",
			  (@paths ? map { "path=$_" } @paths :
			   ( "center=$center",
			     "zoom=14", # XXX
			   )
			  ),
			 );
	$url = "http://maps.google.com/maps/api/staticmap?" . join("&", @cgi_params);
	last if (!@multi_c || length $url <= LIMIT_URI_PATH || $tolerance > 10000);
	if ($tolerance == 0) {
	    $tolerance = 10;
	} elsif ($tolerance < 100) {
	    $tolerance += 50;
	} elsif ($tolerance < 1000) {
	    $tolerance += 100;
	} else {
	    $tolerance += 1000;
	}
	warn "Need to shorten path, next tolerance value is $tolerance...\n";
    }

    warn "URL: $url\n" if $DEBUG;
    my $resp = $ua->get($url);
    die "Error while getting $url\n" . $resp->status_line . "\n" . $resp->headers->as_string if !$resp->is_success;

    my $fh = $args{Fh} || $self->{Fh};
    binmode $fh;
    print $fh $resp->decoded_content;
}

sub _make_paths_from_coords {
    my($multi_c_ref) = @_;
    my @paths = map { _make_path_from_coords($_) } grep { scalar @$_ } @$multi_c_ref;
    @paths;
}

sub _make_path_from_coords {
    my($c_ref) = @_;
    my $path;
    if (eval { require Algorithm::GooglePolylineEncoding; 1 }) {
	my @points = map {
	    my($x, $y) = $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map(split /,/, $_));
	    +{ lat => $y, lon => $x };
	} @$c_ref;
	my $eline = Algorithm::GooglePolylineEncoding::encode_polyline(@points);
	$path = 'enc:' . uri_escape($eline, '\x60');
    } else {
	# unencoded polyline, may more easily exceed URL limits
	$path = join("|", map {
	    my($x, $y) = $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map(split /,/, $_));
	    $y.",".$x;
	} @$c_ref);
    }
    $path = 'color:0x0000ff80|weight:5|' . $path; # XXX make settable
    $path;
}

sub _shorten_paths {
    my($multi_c_ref, $tolerance) = @_;

    require Storable;
    my @multi_c = grep { scalar @$_ } @{ Storable::dclone($multi_c_ref) };

    {
	require Strassen::Util;
	# simplify gaps away if smaller than $tolerance
	my @new_multi_c = $multi_c[0];
	for my $i (1 .. $#multi_c) {
	    my $gap_dist = Strassen::Util::strecke_s($new_multi_c[-1][-1], $multi_c[$i][0]);
	    if ($gap_dist < $tolerance) {
		push @{ $new_multi_c[-1] }, @{ $multi_c[$i] };
	    } else {
		push @new_multi_c, $multi_c[$i];
	    }
	}
	@multi_c = @new_multi_c;
    }

    require Strassen::Core;
    my $s = Strassen->new;
    for my $line (@multi_c) {
	next if @$line == 0; # may this happen?
	$s->push(["", $line, "X"]);
    }

    $s->simplify($tolerance);

    my @new_multi_c;
    $s->init;
    while(1) {
	my $r = $s->next;
	my $c = $r->[Strassen::COORDS()];
	last if !@$c;
	push @new_multi_c, $c;
    }

    _make_paths_from_coords(\@new_multi_c);
}

1;

__END__
