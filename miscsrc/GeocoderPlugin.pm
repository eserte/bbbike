# -*- perl -*-

#
# $Id: GeocoderPlugin.pm,v 1.3 2007/12/18 00:27:22 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2007 Slaven Rezic. All rights reserved.
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

require Karte::Standard;
require Karte::Polar;

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
	    (-menuitems => [[Button => 'Show dialog',
			     -command => \&geocoder_dialog,
			    ],
			    [Button => "Delete this menu",
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
    my $loc = "Berlin, ";
    my $e = $geocoder_toplevel->LabEntry(-textvariable => \$loc,
					 -labelPack => [-side => 'left'],
					 -label => 'Location:',
					)->pack(-anchor => 'w');
    $e->focus;
    $e->icursor("end");

    my $gcf = $geocoder_toplevel->LabFrame(-label => 'Geocoding modules', -labelside => 'acrosstop'
					  )->pack(-fill => 'x', -expand => 1);
    my $geocoder_api = 'Yahoo';
    my %apis = ('Google' => { 'new' => sub {
				  my $apikey = do {
				      my $file = "$ENV{HOME}/.googlemapsapikey";
				      open my $fh, $file
					  or main::status_message("Cannot get key from $file: $!", "die");
				      local $_ = <$fh>;
				      chomp;
				      $_;
				  };
				  Geo::Coder::Google->new(apikey => $apikey);
			      },
			      'extract_loc' => sub {
				  my $location = shift;
				  @{$location->{Point}{coordinates}};
			      },
			      'extract_addr' => sub {
				  my $location = shift;
				  $location->{address} . "\n" .
				      join(",", @{$location->{Point}{coordinates}});
			      },
			      'label' => 'Google (needs API key)',
			    },
		'Yahoo' => { 'new' => sub {
				 Geo::Coder::Yahoo->new(appid => 'bbbike');
			     },
			     'extract_loc' => sub {
				 my $locations = shift;
				 ($locations->[0]{longitude}, $locations->[0]{latitude});
			     },
			     'extract_addr' => sub {
				 my $locations = shift;
				 my $location = $locations->[0];
				 $location->{address} . ", " . $location->{city} . ", " . $location->{state} . "\n" .
				     $location->{longitude} . "," . $location->{latitude};
			     },
			   },
	       );
    for my $_api (sort keys %apis) {
	my $label = $apis{$_api}->{'label'} || $_api;
	$gcf->Radiobutton(-variable => \$geocoder_api,
			  -value => $_api,
			  -text => $label,
			 )->pack(-anchor => 'w');
    }

    my $bf = $geocoder_toplevel->Frame->pack(-fill => 'x');
    my $res = $geocoder_toplevel->Scrolled("Text", -scrollbars => 'oe', -width => 40, -height => 3
					  )->pack(-expand => 1, -fill => "both");
    my $okb =
	$bf->Button(-text => "OK",
		    -command => sub {
			my $mod = 'Geo::Coder::' . $geocoder_api;
			eval "require $mod";
			if ($@) {
			    main::status_message($@, "die");
			}
			my $gc = $apis{$geocoder_api};
			my $geocoder = $gc->{new}->();
			my $location = $geocoder->geocode(location => $loc);
			require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$location],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX
			if ($location) {
			    $res->delete("1.0", "end");
			    my $loc_addr = $gc->{extract_addr}->($location);
			    $res->insert("end", $loc_addr);
			    my($px,$py) = $gc->{extract_loc}->($location);
			    my($sx,$sy) = $Karte::Polar::obj->map2standard($px,$py);
			    my($tx,$ty) = main::transpose($sx,$sy);
			    main::mark_point(-x => $tx, -y => $ty, -clever_center => 1);
			} else {
			    main::status_message("No result", "warn");
			}
		    })->pack(-side => "left");
    $e->bind("<Return>" => sub { $okb->invoke });
    $bf->Button(-text => "Close",
		-command => sub {
		    destroy_geocoder_dialog();
		})->pack(-side => "left");
}

1;

__END__
