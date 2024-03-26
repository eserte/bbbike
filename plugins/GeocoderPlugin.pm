# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2007,2008,2010,2011,2013,2014,2015,2016,2017,2018,2019,2020,2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Geocode using various APIs
# Description (de): Geokodierung
package GeocoderPlugin;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION $geocoder_toplevel);
$VERSION = 3.14;

BEGIN {
    if (!eval '
use Msg qw(frommain);
1;
') {
	warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

use BBBikeUtil qw(bbbike_root);
use BBBikeTkUtil qw(pack_buttonframe);

require Karte::Standard;
require Karte::Polar;

# cease warnings
if (0) {
    $main::devel_host = $main::devel_host;
    $main::advanced = $main::advanced;
    $main::use_obsolete = $main::use_obsolete;
}

# None of the available Google geocoders are usable without an API
# key, and only Geo::Coder::Google is at all available to
# theoretically use an API key.
use constant ENABLE_GOOGLE_GEOCODERS => 0;

sub register {
    my $pkg = __PACKAGE__;
    $BBBikePlugin::plugins{$pkg} = $pkg;
    add_button($pkg);
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};
    BBBikePlugin::remove_from_global_plugins_menu($pkg."_menu");
    destroy_geocoder_dialog();
    delete $BBBikePlugin::plugins{$pkg};
}

sub add_button {
    my($pkg) = @_;
    BBBikePlugin::add_to_global_plugins_menu
	    (-menuitems => [[Button => M("Dialog zeigen"),
			     -command => sub { geocoder_dialog() },
			    ],
			    [Button => M('Dieses Men� l�schen'),
			     -command => sub {
				 $main::top->after(100, sub {
						       unregister();
						   });
			     }
			    ]],
	     -title => 'Geocode',
	     -advertisedname => $pkg."_menu",
	    );
}

sub destroy_geocoder_dialog {
    if (Tk::Exists($geocoder_toplevel)) {
	$geocoder_toplevel->destroy;
	undef $geocoder_toplevel;
    }
}


sub geocoder_dialog {
    require Tk::PathEntry;

    destroy_geocoder_dialog();
    $geocoder_toplevel = $main::top->Toplevel(-title => "Geocode");
    $geocoder_toplevel->transient($main::top) if $main::transient;

    my $street;
    my $place = 'Berlin';
    my $e;
    {
	my $f = $geocoder_toplevel->Frame->pack(-anchor => 'w');

	Tk::grid(
		 $f->Label(-text => 'Street:'),
		 ($e = $f->PathEntry(-textvariable => \$street, -choicescmd => sub {}, -pathcompl => '<Control-Shift-Tab>')),
		 -sticky => 'w',
		);
	$e->focus;
	#$e->icursor("end");
	$e->icursor(0);

	Tk::grid(
		 $f->Label(-text => 'City/Place:'),
		 $f->Entry(-textvariable => \$place),
		 -sticky => 'w',
		);
    }

    my $get_loc = sub {
	# It seems that OSM can deal better with the
	# city/place at the end. Google and Bing are fine with both.
	join(', ', grep { defined && length } ($street, $place));
    };

    my $gcf = $geocoder_toplevel->LabFrame(-label => 'Geocoding modules', -labelside => 'acrosstop'
					  )->pack(-fill => 'x', -expand => 1);
    my $geocoder_api = 'OSM';
    my %apis = (
		(ENABLE_GOOGLE_GEOCODERS ? (
		'My_Google_v3' =>
		{
		 'label' => 'Google v3',
		 'short_label' => 'Google',
		 'devel_only' => 1,

		 'require' => sub { },
		 'new' => sub { Geo::Coder::My_Google_v3->new },
		 'extract_loc' => sub {
		     my $location = shift;
		     @{$location->{geometry}{location}}{qw(lng lat)};
		 },
		 'extract_addr' => sub { shift->{formatted_address} },
		},

		'Google_v3' =>
		{
		 'label' => 'Google v3 (using CPAN module)',
		 'short_label' => 'Google (v3, CPAN)',
		 'devel_only' => 1,

		 'require' => sub { require Geo::Coder::Googlev3 },
		 'new' => sub { Geo::Coder::Googlev3->new },
		 # extract_loc/addr resused from My_Google_v3, see below
		},

		'Google' =>
		{
		 'label' => 'Google (using CPAN module)',
		 'short_label' => 'Google (CPAN)',
		 'devel_only' => 1,

		 'new' => sub { Geo::Coder::Google->new },
		 # extract_loc/addr resused from My_Google_v3, see below
		},
		) : ()),

		'Bing' =>
		{
		 'label' => 'Bing',
		 'include_multi' => 1,
		 'devel_only' => 1, # not really usable for the public --- users are required to create an API key, and licensing is unclear anyway

		 'require' => sub {
		     require Geo::Coder::Bing;
		     # At least 0.04 stopped working at
		     # some time.
		     #
		     # 0.06 has some output encoding
		     # problems which are solved in 0.07,
		     # but these are not so grave. Best is
		     # to use at least 0.10.
		     Geo::Coder::Bing->VERSION(0.06);
		 },
		 'new' => sub {
		     my $apikey = do {
			 my $file = "$ENV{HOME}/.bingapikey";
			 open my $fh, $file
			     or main::status_message("Cannot get key from $file: $!", "die");
			 local $_ = <$fh>;
			 chomp;
			 $_;
		     };
		     Geo::Coder::Bing->new(key => $apikey);
		 },
		 'extract_loc' => sub {
		     my $location = shift;
		     ($location->{point}{coordinates}[1],
		      $location->{point}{coordinates}[0],
		     );
		 },
		 'extract_addr' => sub {
		     my $location = shift;
		     $location->{address}->{formattedAddress};
		 },
		},

		'OSM' =>
		{
		 'include_multi' => 1,
		 'include_multi_master' => 1, # means this geocoder's address will be shown first in a "Multi" call

		 'require' => sub { require Geo::Coder::OSM },
		 'new' => sub { Geo::Coder::OSM->new },
		 'extract_addr' => sub {
		     my $loc = shift;
		     $loc->{display_name};
		 },
		 'extract_loc' => sub {
		     my $loc = shift;
		     ($loc->{lon}, $loc->{lat});
		 },
		},

		'OpenCage' =>
		{
		 'include_multi' => 1,
		 'devel_only' => 1,

		 'require' => sub {
		     require Geo::Coder::OpenCage;
		 },
		 'new' => sub {
		     my $apikey = do {
			 my $file = "$ENV{HOME}/.opencageapikey";
			 open my $fh, $file
			     or main::status_message("Cannot get key from $file: $!", "die");
			 local $_ = <$fh>;
			 chomp;
			 $_;
		     };
		     Geo::Coder::OpenCage->new(api_key => $apikey);
		 },
		 'extract_addr' => sub {
		     my $location = shift;
		     $location->{results}->[0]->{formatted};
		 },
		 'extract_loc' => sub {
		     my $location = shift;
		     my $g = $location->{results}->[0]->{geometry};
		     ($g->{lng}, $g->{lat});
		 },
		},

		'LocalOSM' =>
		{
		 'include_multi' => 1,
		 'devel_only' => 1,

		 'require' => sub {
		     local @INC = (@INC, bbbike_root."/miscsrc");
		     require GeocoderAddr;
		     if ($main::city_obj->is_osm_source) {
			 my $ga = GeocoderAddr->new_osm_addr;
			 $ga->check_availability
			     or die "A suitable _addr (path $ga->{File}) is not available. Maybe osm2bbd-postprocess --only-addr was not run?";
		     } else {
			 my $ga = GeocoderAddr->new_berlin_addr;
			 $ga->check_availability
			     or die "local _addr (path $ga->{File}) is not available. Please use osm2bbd and osm2bbd-postprocess to create this file.";
		     }
		 },
		 'new' => sub {
		     if ($main::city_obj->is_osm_source) {
			 GeocoderAddr->new_osm_addr;
		     } else {
			 GeocoderAddr->new_berlin_addr;
		     }
		 },
		 'extract_addr' => sub {
		     my $loc = shift;
		     $loc->{display_name};
		 },
		 'extract_loc' => sub {
		     my $loc = shift;
		     ($loc->{lon}, $loc->{lat});
		 },
		 'suggest' => sub {
		     my($geocoder, $street, $city) = @_;
		     if ($street eq '') {
			 ();
		     } elsif ($city =~ m{Berlin}) {
			 my @results = $geocoder->geocode(location => $street, limit => 10, incomplete => 1);
			 map { my $details = $_->{details}; $details->{street} . (defined $details->{hnr} && length $details->{hnr} ? ' ' . $details->{hnr} : '') } @results;
		     } else {
			 ();
		     }
		 },
		},
	       );
    if (exists $apis{My_Google_v3}) {
	for my $google_api (qw(Google Google_v3)) { # resuse My_Google_v3 functions
	    if (exists $apis{$google_api}) {
		$apis{$google_api}->{$_} = $apis{My_Google_v3}->{$_} for (qw(extract_loc extract_addr extract_short_addr));
	    }
	}
    }

    my $do_geocoder_init = sub {
	my $gc = shift;
	if ($gc->{require}) {
	    eval { $gc->{require}->() };
	} else {
	    my $mod = 'Geo::Coder::' . $geocoder_api;
	    eval "require $mod";
	}
	if ($@) {
	    main::status_message($@, "die");
	}
    };

    my $do_geocode = sub {
	my($gc, $loc) = @_;

	$do_geocoder_init->($gc);

	my $geocoder = $gc->{new}->();
	my $location = $geocoder->geocode(location => $loc);
	$gc->{fix_result}->($location) if $gc->{fix_result};
	require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$location],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

	$location;
    };

    my $do_suggest = sub {
	my($gc, $street, $city) = @_;

	my $geocoder = $gc->{new}->();
	$gc->{suggest}->($geocoder, $street, $place);
    };

    my $get_short_label = sub {
	my($apiname) = @_;
	my $gc = $apis{$apiname};
	$gc->{short_label} || $gc->{label} || $apiname;
    };

    my $get_long_address = sub {
	my($gc, $location) = @_;
	join("\n", $gc->{extract_addr}->($location), join(",", $gc->{extract_loc}->($location)));
    };

    my $change_geocoder = sub {
	my $gc = $apis{$geocoder_api};
	if ($gc->{suggest}) {
	    $do_geocoder_init->($gc);
	    $e->configure(-choicescmd => sub {
			      my(undef, $text) = @_;
			      [ $do_suggest->($gc, $text) ];
			  });
	} else {
	    $e->configure(-choicescmd => sub {});
	}
    };

    for my $_api (sort keys %apis) {
	my $gc = $apis{$_api};
	my $color;
	if ($gc->{devel_only}) {
	    next if !$main::devel_host;
	    $color = 'red';
	}
	my $label = $gc->{'label'} || $_api;
	$gcf->Radiobutton(-variable => \$geocoder_api,
			  -value => $_api,
			  -text => $label,
			  ($color ? (-foreground => $color) : ()),
			  -command => $change_geocoder,
			 )->pack(-anchor => 'w');
    }
    $change_geocoder->();

    my $bf = $geocoder_toplevel->Frame->pack(-fill => 'x');
    my $res = $geocoder_toplevel->Scrolled("ROText", -scrollbars => 'oe', -width => 40, -height => 3
					  )->pack(-expand => 1, -fill => "both");
    my $okb =
	$bf->Button(Name => "ok",
		    -command => sub {
			my $gc = $apis{$geocoder_api};
			my $location = $do_geocode->($gc, $get_loc->());
			if ($location) {
			    $res->delete("1.0", "end");
			    $res->insert("end", $get_long_address->($gc, $location));
			    my($px,$py) = $gc->{extract_loc}->($location);
			    my($sx,$sy) = $Karte::Polar::obj->map2standard($px,$py);
			    my($tx,$ty) = main::transpose($sx,$sy);
			    main::mark_point(
					     -x => $tx, -y => $ty, -clever_center => 1,
					     -addtag => $get_short_label->($geocoder_api) . ": " . $gc->{extract_addr}->($location),
					    );
			} else {
			    main::status_message("No result", "warn");
			}
		    });
    $e->bind("<Return>" => sub { $okb->invoke });
    my $multib;
    if ($main::advanced) {
	$multib =
	    $bf->Button(-text => 'Multi',
			-command => sub {
			    my @coords;
			    my @labels;
			    my $loc_addr;
			    for my $_api (sort { ($apis{$b}->{include_multi_master}||0) <=> ($apis{$a}->{include_multi_master}||0) } keys %apis) {
				my $gc = $apis{$_api};
				next if !$gc->{include_multi};
				next if $gc->{devel_only} && !$main::devel_host;
				my $location = eval {
				    $do_geocode->($gc, $get_loc->());
				};
				if ($@ || !$location) {
				    warn "Could not geocode '" . $get_loc->() . "' with '$_api': $@";
				} else {
				    if ($gc->{include_multi_master}) {
					$loc_addr = $get_long_address->($gc, $location);
				    }
				    push @coords, [[main::transpose($Karte::Polar::obj->map2standard($gc->{extract_loc}->($location)))]];
				    push @labels, $get_short_label->($_api) . ": " . $gc->{extract_addr}->($location);
				}
			    }
			    if (!@coords) {
				main::status_message('No result', 'warn');
			    } else {
				$res->delete("1.0", "end");
				$res->insert("end", $loc_addr);
				main::mark_street(
						  -coords => \@coords,
						  -labels => \@labels,
						 );
			    }
			})->pack(-side => 'left');
    }
    my $cancelb =
	$bf->Button(Name => "close",
		    -command => sub {
			destroy_geocoder_dialog();
		    })->pack(-side => "left");
    pack_buttonframe($bf, [$okb, ($multib ? $multib : ()), $cancelb]);
}

{
    package Geo::Coder::My_Google_v3;
    sub new { bless {}, shift }
    sub geocode {
	my($self, %args) = @_;
	my $loc = $args{location};
	require LWP::UserAgent; # should be already loaded anyway
	require JSON::XS;
	require BBBikeUtil; # should be already loaded anyway
	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	my $url = BBBikeUtil::uri_with_query
	    (
	     'http://maps.google.com/maps/api/geocode/json',
	     [address => $loc,
	      sensor => 'false'],
	    );
	my $resp = $ua->get($url);
	if ($resp->is_success) {
	    my $content = $resp->decoded_content(charset => "none");
	    my $res = JSON::XS->new->utf8->decode($content);
	    if ($res->{status} eq 'OK') {
		return $res->{results}->[0];
	    } else {
		main::status_message("Fetching $url did not return OK status, but '$res->{status}'", "error");
	    }
	} else {
	    main::status_message("Fetching $url failed: " . $resp->status_line, "error");
	}
    }
}

1;

__END__

=head1 NAME

GeocoderPlugin - a geocoding plugin for BBBike

=head1 SYNOPSIS

None, usually only loaded within bbbike

=head1 DESCRIPTION

Supported geocoding services:

=over

=item OSM

through L<Geo::Coder::OSM>

=back

More supported geocoding services, but only available in
C<$devel_host> mode, and may need additional CPAN modules are other
prerequisites:

=over

=item LocalOSM

Experimental. Requires a
directory F<data_berlin_osm_bbbike> which is the result of a
C<osm2bbd> and C<osm2bbd-postprocess> conversion.

=item Bing

through L<Geo::Coder::Bing>. Requires an API key which should be
stored in F<~/.bingapikey>.

=item OpenCage

through L<Geo::Coder::OpenCage>. Requires an API key which should be
stored in F<~/.opencageapikey>.

=item GeocodeFarm

through L<Geo::Coder::GeocodeFarm>. Does not need an API key, but
number of requests are limited (currently 250 per day and IP).

=back

Unsupported geocoding services:

=over

=item Google v3

through a built-in class (no CPAN modules other than L<LWP> and
L<JSON::XS> required) and through L<Geo::Coder::Googlev3>. Currently
deactived because an API key is required which cannot be supplied to
the underlying geocoder module.

=item Mapquest

through L<Geo::Coder::Mapquest>, requires an API key and is not
production-ready (as of 2011), as there's no support for non-US
addresses

=back

Obsolete geocoding services:

=over

=item old Yahoo API, Yahoo Placefinder

L<Geo::Coder::Yahoo> is using an old and shut down Yahoo API. The
successor API was Yahoo PlaceFinder, served by the module
L<Geo::Coder::PlaceFinder>, but in April 2013 or so this API was
shutdown.

=item Cloudmade

The free API access was shutdown in May 2014 or so.

=item Google v2

Through L<Geo::Coder::Google> and L<Geo::Coder::GoogleMaps>, needs an
API key stored in F<~/.googlemapsapikey>. Was replaced by Google v3.

=item OVI

Through L<Geo::Coder::Ovi>, probably API key is needed. OVI is nowadays HERE.

=back

=cut
