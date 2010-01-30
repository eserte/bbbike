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

# Description (en): Show Panoramio images on BBBike map
# Description (de): Panoramio-Bilder auf der BBBike-Karte anzeigen
package BBBikePanoramioPlugin;

use BBBikePlugin;
push @ISA, "BBBikePlugin";

use strict;
use vars qw($VERSION);
$VERSION = 1.06;

use File::Temp qw(tempfile);
use JSON::XS;
use LWP::UserAgent;

use vars qw(@photos);

sub register { 
    my $pkg = __PACKAGE__;

    $main::info_plugins{$pkg} =
	{ name => "Panoramio on BBBike",
	  callback => sub { show_mini_images(@_) },
	  callback_3 => sub { show_panoramio_menu(@_) },
	};
}

sub show_mini_images {
    my(%args) = @_;

    my $data;
    my $displayed_photos = 0;

    main::IncBusy($main::top);
    eval {

	my($cminx, $cminy, $cmaxx, $cmaxy) = $main::c->get_corners;
	my($minx,$miny) = $Karte::Polar::obj->standard2map(main::anti_transpose($cminx,$cminy));
	my($maxx,$maxy) = $Karte::Polar::obj->standard2map(main::anti_transpose($cmaxx,$cmaxy));
	($minx,$maxx) = ($maxx,$minx) if $minx > $maxx;
	($miny,$maxy) = ($maxy,$miny) if $miny > $maxy;

	$main::c->delete("panoramio");
	for (@photos) {
	    eval { $_->delete }; warn $@ if $@;
	}
	@photos = ();

	my $ua = LWP::UserAgent->new;
	$ua->agent("BBBike/$main::VERSION (BBBikePanoramioPlugin/$VERSION LWP/$LWP::VERSION");

	my $max_display_photos = 30; # previously I used 21, try how "cluttered" it would be with 30
	my $fetch_per_iteration = 100;

	my $fetched_photos = 0;
	my $available_photos;
	my $iteration_breaker = 0;
    FETCH_ALL_PHOTOS: while($displayed_photos < $max_display_photos &&
			    ((defined $available_photos && $fetched_photos < $available_photos) ||
			     !defined $available_photos)) {
	    die "Iteration breaker!" if $iteration_breaker++>100;
	    my $from = $fetched_photos;
	    my $to = $fetched_photos + $fetch_per_iteration - 1;
	    my $json_url = "http://www.panoramio.com/map/get_panoramas.php?order=popularity&set=full&size=thumbnail" .
		"&from=$from&to=$to" .
		    "&minx=$minx&maxx=$maxx&miny=$miny&maxy=$maxy";
	    my $resp = $ua->get($json_url);
	    if (!$resp->is_success) {
		die "Fetching $json_url was not successful: " . $resp->status_line;
	    }
	    $data = JSON::XS::decode_json($resp->content);

	    if (!defined $available_photos) {
		$available_photos = $data->{count};
		last if !$available_photos;
	    }

	    for my $rec (@{ $data->{photos} || [] }) {
		next if ($rec->{longitude} > $maxx || $rec->{longitude} < $minx ||
			 $rec->{latitude}  > $maxy || $rec->{latitude}  < $miny);
		my($sx,$sy) = $Karte::Polar::obj->map2standard($rec->{longitude}, $rec->{latitude});
		my($tx,$ty) = main::transpose($sx,$sy);
		my($fh, $imgfile) = tempfile(UNLINK => 1, SUFFIX => "_panoramio.jpg");
		my $resp = $ua->get($rec->{photo_file_url}, ':content_file' => $imgfile);
		if ($resp->is_success) {
		    my $p = $main::c->Photo(-file => $imgfile);
		    push @photos, $p;
		    close $fh; # also unlinks file
		    (my $medium_url = $rec->{photo_file_url}) =~ s{/thumbnail/}{/medium/};
		    $main::c->createImage($tx,$ty, -image => $p, -tags => ['panoramio', $rec->{photo_url}, "ImageURL: $medium_url"]);
		    $displayed_photos++;
		    last FETCH_ALL_PHOTOS if $displayed_photos >= $maxy;
		} else {
		    close $fh; # also unlinks file
		}
	    }

	    $fetched_photos += $fetch_per_iteration;
	}
    };
    my $err = $@;
    main::DecBusy($main::top);
    main::status_message($err, 'die') if $err;

    if ($data) {
	main::status_message("Panoramia API returned $data->{count} photo(s), displayed $displayed_photos within visible area", "info");
    }
}

sub show_panoramio_menu {
    my(%args) = @_;
    my $w = $args{widget};
    if (!Tk::Exists($w->{"PanoramioMenu"})) {
	my $panoramio_menu = $w->Menu(-title => "Panoramio",
				      -tearoff => 0);
	$panoramio_menu->command(-label => "Panoramio-Bilder löschen",
				 -command => sub { delete_panoramio_images() },
				);
	$w->{"PanoramioMenu"} = $panoramio_menu;
    }

    my $e = $w->XEvent;
    $w->{"PanoramioMenu"}->Post($e->X, $e->Y);
    Tk->break;
}

sub delete_panoramio_images {
    $main::c->delete('panoramio');
}

1;

__END__

=pod

 TODO:

 * take panoramio stuff from multimap to here
 * add icon
 * maybe make the info entry a button? as it works differently than the other info stuff (visible region!)
 * parallel fetching (e.g. if LWP::Parallel is available, but this has to be patched, does not work anymore
   with newer libwww!)

=cut
