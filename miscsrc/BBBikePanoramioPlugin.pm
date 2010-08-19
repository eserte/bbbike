# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2008,2009,2010 Slaven Rezic. All rights reserved.
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
$VERSION = 1.07;

use File::Temp qw(tempfile);
use JSON::XS;
use LWP::UserAgent;

use vars qw(@photos);

use vars qw($panoramio_bbbike_icon);

sub register { 
    my $pkg = __PACKAGE__;
    _create_icon();
    $main::info_plugins{$pkg} =
	{ name => "Panoramio on BBBike",
	  callback => sub { show_mini_images(@_) },
	  callback_3 => sub { show_panoramio_menu(@_) },
	  ($panoramio_bbbike_icon ? (icon => $panoramio_bbbike_icon) : ()),
	};
    Hooks::get_hooks("delete_background_images")->add
	    (sub {
		 delete_panoramio_images();
	     }, __PACKAGE__);
}

sub _create_icon {
    if (!defined $panoramio_bbbike_icon) {
	$panoramio_bbbike_icon = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAOe9AC0tLS4uLjIyMjs7Oz09PUJCQkVFRQlWkwpZlklPVU9PTwxemVNTUxdg
mhphmhpjnFlZWR1lnR9lnB9lniJmniNmnSVonSJpoCVpn19fXyVqoFdffilsoitsoi9soWNj
Yy1vozpxpTZ0pxB80Tt2qEB2qD53qDt4qRt+1jt5rEF6q3JyciKA2UN7qkp6pnNzcyqD3Hd3
dy6F20+ArlGAqXl5eUuCrkqDsEqEsDiF4VCDsFKDsFKGskCH5HB+tkCI5EyH3UOK44KCgk2K
6YWFhV+MtUyN5k2O54mJiWGSt4OJrmGSuVmQ5liS6Y2NjVmU6WaXvGKV7ZGRkXGXvZKSkmSX
7WubvnKZvmaY7ZSUlHWZzJeXl3adwZiYmHOfwXugwpubm4Gg0X2jxXCn4KWlpaenp6mpqYWt
8aqqqo+vy46s9pSq+qysrJCt9o6zzpSz0a+vr4+y9Jey+Jq30J240LS0tJ640Z650py80Z69
05y87Ku+0KvC2KvD2azD2K7D2cHBwcLCwq/G2rPE+7PI3LHK27jL3crMzr7P4bvQ4bzQ37vR
4M7OzsPQ+cTT4cLU4r/V4c3T28nS/NTU1MnW5MnY5szb59Lf6t7e3t/f39ni7dfk7OPj49zk
7t7j/9/k/9zq7ujo6ODq7+rq6uvr6+fr/+fu9Ovt/+7x9u/x/+z09e319fH09/T09PX19fn5
+fj6/Pf7+vr7+/r7/Pv7+/j8+vv7//n8/Pz8/P39/f39/v7//v///v//////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
/////////////////////////////////yH5BAEKAP8ALAAAAAAQABAAAAj+AHv10sWqEp9E
pmadOhPHlkCBswSpeHAhAoc0ekYMSfUwlx8MUCCJouNmgphGnj49REXCyqpbhq7sytOAUpQj
DxE5KGRJk4gvvVSd4NIkyMM5Hh7NOLCgwx9ZS3TAYGFETa8+FkDxuoOAxw47OIpMNdKmV6cK
eGIRKiFwk4Q3T3o8nDUFhKJFjmpdutFiDJAeVF71IpWABgUbXpJoMBFGBpMeQgrQyhAI1h4X
IVJoibRBThW5WZwAEKgERQ4fh8BI6YXlR69QBgIILLWmFIRJZJD0kjSoFyYFK9g85EQA16gB
rh7GKNNqwIs6UgAwEghHQBc0DD4IpGWmxpZRD3sHZcpCBJDAgAA7
EOF
    }
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

	Hooks::get_hooks("delete_background_images")->execute;
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
		my($fh, $tempfile) = tempfile(UNLINK => 1, SUFFIX => "_panoramio.jpg");
		my $resp = $ua->get($rec->{photo_file_url}, ':content_file' => $tempfile);
		if ($resp->is_success) {
		    my $p = $main::c->Photo(-file => $tempfile);
		    unlink $tempfile; # delete temporary as soon as possible
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
	$panoramio_menu->command(-label => "Panoramio- und andere Bilder löschen",
				 -command => sub { Hooks::get_hooks("delete_background_images")->execute },
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
