# -*- perl -*-

#
# $Id: GeocoderPlugin.pm,v 1.6 2008/07/19 18:27:14 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2007,2008 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Geocode using various APIs
# Description (de): Geokodierung
package GeocoderPlugin;

# TODO:
# * if there are multiple results, then show them all in a list or so
# * watch from time to time if the Yahoo issues are solved, especially the utf8 problems

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION $geocoder_toplevel);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

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
    my $loc = ", Berlin"; # It seems that Yahoo can deal better with the city at the end. Google is fine with both.
    my $e = $geocoder_toplevel->LabEntry(-textvariable => \$loc,
					 -labelPack => [-side => 'left'],
					 -label => 'Location:',
					)->pack(-anchor => 'w');
    $e->focus;
    #$e->icursor("end");
    $e->icursor(0);

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
			     'fix_result' => sub {
				 my $location = shift;
				 if ($Yahoo::Search::XML::VERSION le '20060729.004') {
				     # utf-8 not flagged correctly, trying to fix
				     # See http://rt.cpan.org/Ticket/Display.html?id=31618
				     if (eval { require Data::Rmap;
						require Encode;
					    }) {
					 Data::Rmap::rmap(sub { $_ = Encode::decode("utf-8", $_) }, $location);
				     } else {
					 warn "Cannot repair Yahoo response: $@";
				     }
				 }
			     },
			     'label' => 'Yahoo (avoid umlauts)',
			   },
		'Bing' => { 'new' => sub {
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
			     'label' => 'Bing',
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
	$bf->Button(Name => "ok",
		    -command => sub {
			my $mod = 'Geo::Coder::' . $geocoder_api;
			eval "require $mod";
			if ($@) {
			    main::status_message($@, "die");
			}
			my $gc = $apis{$geocoder_api};
			my $geocoder = $gc->{new}->();
			my $location = $geocoder->geocode(location => $loc);
			$gc->{fix_result}->($location) if $gc->{fix_result};
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
		    });
    $e->bind("<Return>" => sub { $okb->invoke });
    my $cancelb =
	$bf->Button(Name => "close",
		    -command => sub {
			destroy_geocoder_dialog();
		    })->pack(-side => "left");
    pack_buttonframe($bf, [$okb, $cancelb]);
}

1;

__END__
