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

# Description (en): Show Flickr images on BBBike map
# Description (de): Flickr-Bilder auf der BBBike-Karte anzeigen
package BBBikeFlickrPlugin;

use BBBikePlugin;
push @ISA, "BBBikePlugin";

use strict;
use vars qw($VERSION);
$VERSION = 1.00;

use File::Temp qw(tempfile);
use Flickr::API ();
use LWP::UserAgent ();
use YAML::Syck qw(LoadFile);
use XML::LibXML ();

use vars qw(@photos);

use vars qw($flickr_bbbike_icon);

sub register { 
    my $pkg = __PACKAGE__;
    _create_icon();
    $main::info_plugins{$pkg} =
	{ name => "Flickr on BBBike",
	  callback => sub { show_mini_images(@_) },
	  callback_3 => sub { show_flickr_menu(@_) },
	  ($flickr_bbbike_icon ? (icon => $flickr_bbbike_icon) : ()),
	};
}

sub _create_icon {
    if (!defined $flickr_bbbike_icon) {
	# XXX make one
# 	$flickr_bbbike_icon = $main::top->Photo
# 	    (-format => 'gif',
# 	     -data => <<EOF);
# EOF
    }
}

sub show_mini_images {
    my(%args) = @_;

    my $data;
    my $displayed_photos = 0;

    my $api = get_api();
    my $p = XML::LibXML->new;
    my $ua = LWP::UserAgent->new;
    $ua->agent("BBBike/$main::VERSION (BBBikeFlickrPlugin/$VERSION LWP/$LWP::VERSION");

    my $get_xml_resp = sub {
	my($method, $args) = @_;
	my $response = $api->execute_method($method, $args);
	my $root = $p->parse_string($response->decoded_content)->documentElement;
	$root;
    };

    main::IncBusy($main::top);
    eval {

	my($cminx, $cminy, $cmaxx, $cmaxy) = $main::c->get_corners;
	my($minx,$miny) = $Karte::Polar::obj->standard2map(main::anti_transpose($cminx,$cminy));
	my($maxx,$maxy) = $Karte::Polar::obj->standard2map(main::anti_transpose($cmaxx,$cmaxy));
	($minx,$maxx) = ($maxx,$minx) if $minx > $maxx;
	($miny,$maxy) = ($maxy,$miny) if $miny > $maxy;

	delete_flickr_images();
	for (@photos) {
	    eval { $_->delete }; warn $@ if $@;
	}
	@photos = ();

	my $max_display_photos = 30; # same value as in Panoramio
                                     # plugin. Allowed max in the API
                                     # is 250.

	my $group_photos = $get_xml_resp->
	    ('flickr.photos.search',
	     {
	      per_page       => $max_display_photos,
	      bbox           => "$minx,$miny,$maxx,$maxy",
	      min_taken_date => time-3*365*86400, # need something to prevent database from crying
	      extras         => 'geo,url_t,url_m',
	     },
	    );

	for my $photo_node ($group_photos->findnodes('/rsp/photos/photo')) {
	    my($lon, $lat) = ($photo_node->getAttribute('longitude'),
			      $photo_node->getAttribute('latitude'));
	    my $id = $photo_node->getAttribute('id');
	    my $owner = $photo_node->getAttribute('owner');
	    my $thumb_url = $photo_node->getAttribute('url_t');
	    my $photo_url = $photo_node->getAttribute('url_m');
	    my $page_url = "http://www.flickr.com/photos/$owner/$id";
	    my($sx,$sy) = $Karte::Polar::obj->map2standard($lon, $lat);
	    my($tx,$ty) = main::transpose($sx,$sy);
	    my($fh, $imgfile) = tempfile(UNLINK => 1, SUFFIX => "_flickr.jpg");
	    my $resp = $ua->get($thumb_url, ':content_file' => $imgfile);
	    if ($resp->is_success) {
		my $p = $main::c->Photo(-file => $imgfile);
		push @photos, $p;
		close $fh; # also unlinks file
		$main::c->createImage($tx,$ty, -image => $p, -tags => ['flickr', $page_url, "ImageURL: $photo_url"]);
	    }
	}
    };
    my $err = $@;
    main::DecBusy($main::top);
    main::status_message($err, 'die') if $err;
}

sub show_flickr_menu {
    my(%args) = @_;
    my $w = $args{widget};
    if (!Tk::Exists($w->{"FlickrMenu"})) {
	my $flickr_menu = $w->Menu(-title => "Flickr",
				   -tearoff => 0);
	$flickr_menu->command(-label => "Flickr-Bilder löschen",
			      -command => sub { delete_flickr_images() },
			     );
	$w->{"FlickrMenu"} = $flickr_menu;
    }

    my $e = $w->XEvent;
    $w->{"FlickrMenu"}->Post($e->X, $e->Y);
    Tk->break;
}

sub delete_flickr_images {
    $main::c->delete('flickr');
}

sub get_api {
    my $apifile = "$ENV{HOME}/.flickrapi";
    my $apiauth = eval { LoadFile($apifile) };
    if ($@) {
	# XXX Msg
	main::status_message(<<EOF, 'die');
File $apifile with API credentials
does not exist or is invalid. This needs to be
technically a YAML file with the keys key and
secret:

key: XXX
secret: YYY

Error message was: $@
EOF
    }
    my $api = Flickr::API->new({'key'    => $apiauth->{key},
				'secret' => $apiauth->{secret}
			       });
    $api;
}

1;

__END__

