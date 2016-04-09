# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009,2013,2014,2015,2016 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Hmmm... XXXX

package BBBikeCGI::API;

use strict;
use vars qw($VERSION);
$VERSION = '0.05';

use JSON::XS qw();

require Karte::Polar;
require Karte::Standard;

sub action {
    my($action, $q) = @_;
    if ($action !~ m{^(revgeocode|config)$}) {
	die "Invalid action $action";
    }
    my $func = "action_$action";
    no strict 'refs';
    &{$func}($q);
}

sub action_revgeocode {
    my $q = shift;
    my $lon = $q->param('lon');
    $lon eq '' and die "lon is missing";
    my $lat = $q->param('lat');
    $lat eq '' and die "lat is missing";

    no warnings 'once';
    my($x,$y) = $main::data_is_wgs84 ? ($lon,$lat) : $Karte::Polar::obj->map2standard($lon,$lat);
    # XXX Die Verwendung von main::... bricht, wenn bbbike.cgi als
    # Apache::Registry-Skript ausgeführt wird, da das Package dann ein
    # anderes ist! -> beste Lösung: alle Funktionen von bbbike.cgi
    # müssen in ein Package überführt werden
    my $xy = main::get_nearest_crossing_coords($x,$y);
    my $cr;
    if (defined $xy) {
	my @cr = split m{/}, main::crossing_text($xy);
	@cr = @cr[0,1] if @cr > 2; # bbbike.cgi can deal only with A/B
	$cr = join("/", @cr);
    }
    print $q->header(-type => 'text/plain', -access_control_allow_origin => '*');
    print JSON::XS->new->canonical->ascii->encode({ crossing => $cr,
						    bbbikepos => $xy,
						    origlon => $lon,
						    origlat => $lat,
						  });
}

sub action_config {
    my $q = shift;
    print $q->header(-type => 'text/plain');

    require BBBikeCGI::Config;
    my $r = BBBikeCGI::Config->the_config('json');

    my %modules_info;
    for my $module_name (
			 'Geo::Distance::XS',
			 'Geo::SpaceManager',
			 'YAML::XS', # for BBBikeYAML
			) {
	$modules_info{$module_name} = _module_info($module_name);
    }

    $r->{modules_info} = \%modules_info;
    print JSON::XS->new->canonical->ascii->encode($r);
}

# Module info can contain:
#  installed => bool:   module is installed or not installed
#  version   => string: module's stringified version
#  version   => false:  module's version is not available
sub _module_info {
    my $module_name = shift;
    if (eval { require Module::Metadata; 1 }) {
	_module_info_via_module_metadata($module_name);
    } else {
	_module_info_via_eumm($module_name);
    }
}

sub _module_info_via_module_metadata {
    my $module_name = shift;
    my $mod = Module::Metadata->new_from_module($module_name, collect_pod => 0);
    if ($mod) {
	my $ret = { installed => JSON::XS::true };
	my $ver = $mod->version;
	if ($ver->can('stringify'))  {
	    $ret->{version} = $ver->stringify; # stringify for json
	} else {
	    warn "Unexpected: cannot get version for '$module_name' via Module::Metadata";
	    $ret->{version} = JSON::XS::false;
	}
	$ret;
    } else {
	+{ installed => JSON::XS::false }
    }
}

sub _module_info_via_eumm {
    my $module_name = shift;
    my $file = _module_path($module_name);
    if (defined $file) {
	my $ret = { installed => JSON::XS::true };
	require ExtUtils::MakeMaker;
	my $ver = eval { MM->parse_version($file) };
	if (defined $ver) {
	    $ret->{version} = "$ver";
	} else {
	    warn "Unexpected: cannot get version for '$module_name' via EUMM, error: $@";
	    $ret->{version} = JSON::XS::false;
	}
	$ret;
    } else {
	+{ installed => JSON::XS::false }
    }
}

# Derived from module_exists from srezic-repository
sub _module_path {
    my($filename) = @_;
    $filename =~ s{::}{/}g;
    $filename .= ".pm";
    return $INC{$filename} if $INC{$filename};
    foreach my $prefix (@INC) {
	my $realfilename = "$prefix/$filename";
	if (-r $realfilename) {
	    return $realfilename;
	}
    }
    undef;
}
# REPO END


1;

__END__
