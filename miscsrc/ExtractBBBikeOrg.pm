# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package ExtractBBBikeOrg;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use URI ();
use URI::QueryParam ();

sub new { bless {}, shift }

sub get_dataset_title {
    my($class, $directory) = @_;
    $class->_get_dataset_title_from_readme($directory);
}

sub _get_dataset_title_from_readme {
    my(undef, $directory) = @_;
    my $f = "$directory/README.txt";
    my $dataset_title;
    open my $fh, '<', $f
	or die "Can't open $f: $!";
    while (<$fh>) {
	if (/^Script URL:\s+(.*)/) {
	    my $u = URI->new($1);
	    $dataset_title = $u->query_param('city');
	    last;
	}
    }
    $dataset_title;
}

1;

__END__
