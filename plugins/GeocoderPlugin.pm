# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2007,2008,2010,2011,2013 Slaven Rezic. All rights reserved.
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
$VERSION = 3.01;

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

use BBBikeTkUtil qw(pack_buttonframe);

require Karte::Standard;
require Karte::Polar;

# cease warnings
if (0) {
    $main::devel_host = $main::devel_host;
    $main::advanced = $main::advanced;
}

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
			    [Button => M('Dieses Menü löschen'),
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
    destroy_geocoder_dialog();
    $geocoder_toplevel = $main::top->Toplevel(-title => "Geocode");
    $geocoder_toplevel->transient($main::top) if $main::transient;
    #my $loc = "Berlin, ";
    my $loc = ", Berlin"; # It seems that Yahoo and OSM can deal better with the city at the end. Google and Bing are fine with both.
    my $e = $geocoder_toplevel->LabEntry(-textvariable => \$loc,
					 -labelPack => [-side => 'left'],
					 -label => 'Location:',
					)->pack(-anchor => 'w');
    $e->focus;
    #$e->icursor("end");
    $e->icursor(0);

    my $gcf = $geocoder_toplevel->LabFrame(-label => 'Geocoding modules', -labelside => 'acrosstop'
					  )->pack(-fill => 'x', -expand => 1);
    my $geocoder_api = 'My_Google_v3';
    my %apis = (
		'My_Google_v3' =>
		{
		 'label' => 'Google v3',
		 'short_label' => 'Google',
		 'include_multi' => 1,
		 'include_multi_master' => 1, # means this geocoder's address will be shown first in a "Multi" call

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
		 'label' => 'Google (needs API key)',
		 'short_label' => 'Google (CPAN)',
		 'devel_only' => 1,

		 'new' => sub {
		     my $apikey = do {
			 my $file = "$ENV{HOME}/.googlemapsapikey";
			 open my $fh, $file
			     or main::status_message("Cannot get key from $file: $!", "die");
			 local $_ = <$fh>;
			 chomp;
			 $_;
		     };
		     my $google = Geo::Coder::Google->new(apikey => $apikey);
		     if ($Geo::Coder::Google::VERSION < 0.06) {
			 $google->ua->agent("Mozilla/5.0 (compatible; Geo::Coder::Google/$Geo::Coder::Google::VERSION; Google, please stop smoking crack; http://rt.cpan.org/Public/Bug/Display.html?id=35173)");
		     }
		     $google;
		 },
		 'extract_loc' => sub {
		     my $location = shift;
		     @{$location->{Point}{coordinates}};
		 },
		 'extract_addr' => sub {
		     my $location = shift;
		     $location->{address};
		 },
		},

		'GoogleMaps' =>
		{
		 'label' => 'Google (alternative implementation, needs API key)',
		 'short_label' => 'Google (CPAN, GoogleMaps)',
		 'devel_only' => 1,

		 'new' => sub {
		     my $apikey = do {
			 my $file = "$ENV{HOME}/.googlemapsapikey";
			 open my $fh, $file
			     or main::status_message("Cannot get key from $file: $!", "die");
			 local $_ = <$fh>;
			 chomp;
			 $_;
		     };
		     require LWP::UserAgent; # should be already loaded anyway
		     Geo::Coder::GoogleMaps->VERSION(0.04); # API changes, bug fixes
		     Geo::Coder::GoogleMaps->new(apikey => $apikey,
						 ua => LWP::UserAgent->new(agent => "Mozilla/5.0 (compatible; Geo::Coder::GoogleMaps/$Geo::Coder::GoogleMaps::VERSION; Google, please stop smoking crack; http://rt.cpan.org/Public/Bug/Display.html?id=49483)"),
						);
		 },
		 'fix_result' => sub {
		     if (!$_[0]->is_success) {
			 main::status_message("No success getting the result.", "info");
			 $_[0] = undef;
		     }
		     $_[0] = $_[0]->placemarks->[0]; # return only first one
		 },
		 'extract_loc' => sub {
		     my $location = shift;
		     return unless $location;
		     ($location->longitude, $location->latitude);
		 },
		 'extract_addr' => sub {
		     my $location = shift;
		     return unless $location;
		     $location->address;
		 },
		},

		'Bing' =>
		{
		 'label' => 'Bing',
		 'include_multi' => 1,

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
		     Geo::Coder::Bing->new;
		 },
		 'extract_loc' => sub {
		     my $location = shift;
		     ($location->{BestLocation}{Coordinates}{Longitude},
		      $location->{BestLocation}{Coordinates}{Latitude},
		     );
		 },
		 'extract_addr' => sub {
		     my $location = shift;
		     $location->{Address}->{FormattedAddress};
		 },
		},

		'Cloudmade' =>
		{
		 'label' => 'Cloudmade (needs API key, avoid umlauts)',
		 'short_label' => 'Cloudmade',
		 'devel_only' => 1,

		 'require' => sub { require Geo::Cloudmade },
		 'new' => sub {
		     my $apikey = do {
			 my $file = "$ENV{HOME}/.cloudmadeapikey";
			 open my $fh, $file
			     or main::status_message("Cannot get key from $file: $!", "die");
			 local $_ = <$fh>;
			 chomp;
			 $_;
		     };
		     my $cloudmade = Geo::Cloudmade->new($apikey);
		     bless { cloudmade => $cloudmade }, 'Geo::Coder::MyCloudmade';
		 },
		 extract_addr => sub {
		     my $loc = shift;
		     $loc->name;
		 },
		 extract_loc => sub {
		     my $loc = shift;
		     ($loc->centroid->long, $loc->centroid->lat);
		 },
		 # See
		 # http://developers.cloudmade.com/issues/show/1007
		 # for the umlauts issue
		},

		'OSM' =>
		{
		 'include_multi' => 1,

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

		'Yahoo PlaceFinder' =>
		{
		 'label' => 'Yahoo PlaceFinder (needs app id)',
		 'short_label' => 'Yahoo PlaceFinder',
		 'devel_only' => 1,

		 'require' => sub { require Geo::Coder::PlaceFinder },
		 'new' => sub {
		     my $apikey = do {
			 my $file = "$ENV{HOME}/.yahooapikey";
			 open my $fh, $file
			     or main::status_message("Cannot get key from $file: $!", "die");
			 local $_ = <$fh>;
			 chomp;
			 $_;
		     };
		     Geo::Coder::PlaceFinder->new(appid => $apikey);
		 },
		 'extract_addr' => sub {
		     my $location = shift;
		     join(", ", grep { defined && length } @{$location}{qw(line1 line2 line3 line4)});
		 },
		 'extract_loc' => sub {
		     my $location = shift;
		     ($location->{longitude}, $location->{latitude});
		 },
		},
	       );
    $apis{Google_v3}->{$_} = $apis{My_Google_v3}->{$_} for (qw(extract_loc extract_addr extract_short_addr));

    my $do_geocode = sub {
	my($gc, $loc) = @_;
			
	if ($gc->{require}) {
	    eval { $gc->{require}->() };
	} else {
	    my $mod = 'Geo::Coder::' . $geocoder_api;
	    eval "require $mod";
	}
	if ($@) {
	    main::status_message($@, "die");
	}

	my $geocoder = $gc->{new}->();
	my $location = $geocoder->geocode(location => $loc);
	$gc->{fix_result}->($location) if $gc->{fix_result};
	require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$location],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

	$location;
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
			 )->pack(-anchor => 'w');
    }

    my $bf = $geocoder_toplevel->Frame->pack(-fill => 'x');
    my $res = $geocoder_toplevel->Scrolled("Text", -scrollbars => 'oe', -width => 40, -height => 3
					  )->pack(-expand => 1, -fill => "both");
    my $okb =
	$bf->Button(Name => "ok",
		    -command => sub {
			my $gc = $apis{$geocoder_api};
			my $location = $do_geocode->($gc, $loc);
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
				my $location = eval {
				    $do_geocode->($gc, $loc);
				};
				if ($@ || !$location) {
				    warn "Could not geocode '$loc' with '$_api': $@";
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
    package Geo::Coder::MyCloudmade;
    sub geocode {
	my($self, %args) = @_;
	my $loc = $args{location};
	my($res) = $self->{cloudmade}->find($loc, {results=>1});
	$res;
    }
}

{
    package Geo::Coder::My_Google_v3;
    sub new { bless {}, shift }
    sub geocode {
	my($self, %args) = @_;
	my $loc = $args{location};
	require CGI;
	CGI->import(qw(-oldstyle_urls));
	require LWP::UserAgent; # should be already loaded anyway
	require JSON::XS;
	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	my $url = 'http://maps.google.com/maps/api/geocode/json?' . CGI->new({address => $loc,
									      sensor => 'false'})->query_string;
	my $resp = $ua->get($url);
	if ($resp->is_success) {
	    my $content = $resp->decoded_content(charset => "none");
	    my $res = JSON::XS->new->utf8->decode($content);
	    if ($res->{status} eq 'OK') {
		return $res->{results}->[0];
	    } else {
		main::status_message("Fetching $url did not return OK status", "error");
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

=item Google v3

through a built-in class (no CPAN modules other than L<LWP> and
L<JSON::XS> required) and through L<Geo::Coder::Googlev3>

=item Bing

through L<Geo::Coder::Bing>, at least version 0.10 is recommended,
though 0.06 works, too, with some limitations/problems

=item OSM

through L<Geo::Coder::OSM>

=back

More supported geocoding services, but not enabled in non-advanced
mode:

=over

=item Google v2

through L<Geo::Coder::Google> and L<Geo::Coder::GoogleMaps>, needs an
API key stored in F<~/.googlemapsapikey>

=item Cloudmade

through L<Geo::Cloudmade>, needs an API key stored in
F<~/.cloudmadeapikey>

=item Yahoo's PlaceFinder

through L<Geo::Coder::PlaceFinder>, needs an app id which should be
stored in F<~/.yahooapikey>.

=back

Unsupported geocoding services:

=over

=item Mapquest

through L<Geo::Coder::Mapquest>, requires an API key and is not
production-ready (as of 2011), as there's no support for non-US
addresses

=item OVI

through L<Geo::Coder::Ovi>, probably API key is needed

=back

Obsolete geocoding services:

=over

=item old Yahoo API

L<Geo::Coder::Yahoo> is using an old and shut down Yahoo API. Use
PlaceFinder instead.

=back

=cut
