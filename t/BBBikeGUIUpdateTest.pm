# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2015 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeGUIUpdateTest;

use Test::More qw(no_plan);

use strict;
use vars qw($VERSION);
$VERSION = 0.01;

my($top, $c);

sub start_guitest {
    warn "Starting GUI test...\n";

    $top = $main::top;
    $c   = $main::c;

    $BBBike::BBBIKE_UPDATE_WWW = $ENV{BBBIKE_TEST_HTMLDIR};

    require Update;
    Update::bbbike_data_update();
    pass 'Update done';

    exit_app();
}

sub exit_app {
    main::exit_app_noninteractive();
    pass 'Application exited';
}

1;

__END__

1;

__END__
