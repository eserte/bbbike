# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeMapserver::Info;

use strict;
use warnings;
our $VERSION = '0.01';

use BBBikeUtil qw(is_in_path);

{
    my $info;
    sub get_info {
	my(%opts) = @_;
	my $force_refresh = delete $opts{forcerefresh};
	die "ERROR: Unhandled options: " . join(" ", %opts) . "\n" if %opts;

	if ($force_refresh) {
	    undef $info;
	}
	if ($info) {
	    return $info;
	}

	$info = {
		 mapserver_version => undef,
		 map2img_path      => undef,
		 OUTPUT   => {},
		 INPUT    => {},
		 SUPPORTS => {},
		};

	my $map2img_path;
	$map2img_path = is_in_path('map2img');
	if (!defined $map2img_path) {
	    $map2img_path = is_in_path('shp2img');
	    if (!defined $map2img_path) {
		return $info;
	    }
	}
	$info->{map2img_path} = $map2img_path;

	my $map2img_v_output = do {
	    open my $fh, '-|', $map2img_path, '-v' or die $!;
	    local $/;
	    scalar <$fh>;
	};
	$map2img_v_output =~ s/^MapServer version (\S+)\s+//;
	$info->{mapserver_version} = $1;
	for my $capdef (split /\s+/, $map2img_v_output) {
	    if (my($k,$v) = $capdef =~ /^(OUTPUT|SUPPORTS|INPUT)=(.*)/) {
		$info->{$k}->{$v} = 1;
	    } else {
		warn "WARN: Ignore unhandled capability $capdef";
	    }
	}

	return $info;
    }
}

1;

__END__
