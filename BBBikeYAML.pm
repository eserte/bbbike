# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeYAML;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(Load Dump LoadFile DumpFile);

use YAML::XS ();

sub Load { YAML::XS::Load(@_) }
sub Dump { YAML::XS::Dump(@_) }
sub LoadFile { YAML::XS::LoadFile(@_) }
sub DumpFile { YAML::XS::DumpFile(@_) }

1;

__END__
