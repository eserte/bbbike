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

package BBBikeMapserver::Bbox;

use strict;
use vars qw($VERSION @EXPORT);
$VERSION = '0.01';

use Exporter 'import';
@EXPORT = qw(get_bbox_for_scope get_bbox_string_for_scope);

sub get_bbox_for_scope {
    my($self, $scope) = @_;
    my $bbox = {'region'    => [-80800,-86200,108200,81600],
		'city'      => [-15700,-8800,37300,31300],
		'innercity' => [1887,6525,15337,16087],
		'potsdam'   => [-17562,-4800,-7200,2587],
	       }->{$scope};
    $bbox ? @$bbox : ();
}

sub get_bbox_string_for_scope {
    my($self, $scope) = @_;
    join(",", $self->get_bbox_for_scope($scope));
}

1;

__END__
