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
    Hooks::get_hooks("delete_background_images")->add
	    (sub {
		 delete_flickr_images();
	     }, __PACKAGE__);
}

sub _create_icon {
    if (!defined $flickr_bbbike_icon) {
	# XXX make one
	$flickr_bbbike_icon = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAOedAC0tLS4uLi4vNzIyMjs7Oz09Pf0AhP4AhP8Ag/8AhEBAQP4Bg/4BhPQF
h/UFhkJCQkVFRf8Jh/4LikZJWU9PT1NTU7QvowBix1VVVQBjyAFjxwBkyAFkyFlZWVpaWglp
ygppyjhdvQtqysQ4rFdefV9fX2NjYw160VdmyWFqjhF80hN80xR81Bt+1nBwcOVJr3JyciKA
2XNzcyiB23Jt1CmC2yuD3Hd3d3l5eTqE3TmG4Xt01fNVskCH5EOH40GI5HB/t02H3UOK5IKC
gvdbs0eL5IWFhU2N506O54mJiVuN6WmM0/5jtFqQ54SKrmCP8I2NjVqU6pGRkVua25KSklyb
222V6WSY7ZSUlGaZ7WKe3WOf3ZeXl5uP35iYmGeh3nec9Jubm/58v/99v5+fn4Gm84Wl9IGn
86WlpY6l+6enp7Of5oyp94Gv4qmpqaqqqpSq+46t9qysrJCu9q+vr5Cy9Jiz+LS0tMHBwcLC
wrPE+8vMz87OztPT08nT/dTU1NXV1dna3sjd8//S6d7e3t/f39Lj9f/X69Pk9tTl9uPj49fn
9t/k/+bm5ufn5+jo6Orq6uvr6+fr/+jr//Dw8O/x//T09PX19fn5+fj5/vv7+/v7//z8/P//
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
/////////////////////////////////yH+FUNyZWF0ZWQgd2l0aCBUaGUgR0lNUAAsAAAA
ABAAEAAACPkAOyHSssVQp06DmBDpUmfTwU6JQGS48GHRoQgJEjSgUenhlwwcNGxoMwYBgwMH
eDDyCFJkGzEIDCw4MALJw0QiJoJYtMbBgQQSdgh52EnQlCqCOoEJ8cICChsxjsQh2skRoAk+
cihhAfXIHKpkFLhJs+LMjCg9iFJK4sFFgUxPTpSZEaQHFUydIgXA0geDACsq2Cyp0aTHkAea
SuTp1ChFERVmApGwcyUtFigADjppoQPInjBSOmX50ekRhAAHJ8GR1OEPmiSd/OjpRIgCDDkP
FRXgBInApYc31FgiIOOOFAB8DtIZ4OVNBRMHNbnBwQUS0UJYjOA5GBAAOw==
EOF
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

	Hooks::get_hooks("delete_background_images")->execute;
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

	my $seen_photos = 0;
	for my $photo_node ($group_photos->findnodes('/rsp/photos/photo')) {
	    $seen_photos++;
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

	main::status_message("Flickr API returned $seen_photos photo(s) within visible area", "info");
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
	$flickr_menu->command(-label => "Flickr- und andere Bilder löschen",
			      -command => sub { Hooks::get_hooks("delete_background_images")->execute },
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

