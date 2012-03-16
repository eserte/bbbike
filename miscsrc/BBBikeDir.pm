# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeDir;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(get_data_osm_directory);

use BBBikeUtil qw(catfile);

sub get_data_osm_directory {
    my(%opts) = @_;
    my $do_create = delete $opts{-create};
    die "Unhandled options: " . join(" ", %opts) if %opts;

    # XXX Note: most of this is taken from BBBike
    my $home = $ENV{HOME};
    my $bbbike_configdir;
    if ($^O eq 'MSWin32') {
	require Win32Util;
	$home = Win32Util::get_user_folder();
	if (-d $home) {
	    $bbbike_configdir = catfile($home, "BBBike");
	}
    }
    if (!defined $bbbike_configdir) {
	if (!defined $home) {
	    $home = eval { (getpwuid($<))[7] };
	    if (!defined $home) {
		die "Sorry, I can't find your home directory.";
	    }
	}
	$bbbike_configdir = catfile($home, ".bbbike");
    }
    my $data_osm_directory = catfile($bbbike_configdir, 'data-osm');

    if ($do_create) {
	if (!-d $bbbike_configdir) {
	    mkdir $bbbike_configdir;
	}
	if (!-d $data_osm_directory) {
	    mkdir $data_osm_directory
		or die "Can't create $data_osm_directory: $!";
	}
    }

    $data_osm_directory;
}

1;

__END__
