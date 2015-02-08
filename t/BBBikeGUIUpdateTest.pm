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

use strict;
use vars qw($VERSION);
$VERSION = 0.01;

use File::Compare qw(compare);
use File::Copy qw(cp);
use Test::More qw(no_plan);

my($top, $c);
my $sample_coord = $ENV{BBBIKE_TEST_SAMPLE_COORD};
my $orig_file = $ENV{BBBIKE_TEST_ORIG_FILE};

sub start_guitest {
    warn "Starting GUI test...\n";

    $top = $main::top;
    $c   = $main::c;

    $BBBike::BBBIKE_UPDATE_WWW = $ENV{BBBIKE_TEST_HTMLDIR};

    main::plot("p", "lsa", -draw => 1);
    $top->update;
    pass("Ampeln plotted");

    isa_ok $main::p_obj{lsa}, 'Strassen', 'lsa object exists';
    ok !exists $main::ampeln{$sample_coord}, 'Sample coord is still removed';

    ok compare($orig_file, 'data/ampeln') != 0, 'file content is different';

    cp $orig_file, 'data/ampeln'
	or return stop_test("Copy failed: $!");

    ok !$main::p_obj{lsa}->is_current, 'lsa is not current';

    require Update;
    Update::bbbike_data_update();
    pass 'Update done';

    ok $main::p_obj{lsa}->is_current, 'lsa is again current';
    ok compare($orig_file, 'data/ampeln') == 0, 'file content again the same';
    ok exists $main::ampeln{$sample_coord}, 'Sample coord is now there';

    exit_app();
}

sub exit_app {
    main::exit_app_noninteractive();
    pass 'Application exited';
}

sub stop_test {
    my $msg = shift;
    main::exit_app_noninteractive();
    fail 'Test failed: ' . $msg;
}

1;

__END__

1;

__END__
