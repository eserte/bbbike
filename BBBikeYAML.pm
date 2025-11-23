# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2025 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

package BBBikeYAML;

use strict;
use vars qw($VERSION);
$VERSION = '0.02';

use Exporter 'import';
our @EXPORT_OK = qw(Load Dump LoadFile DumpFile);

# Note: currently only YAML::XS is supported
# XXX: other YAML modules are prepared, but exact configuration regarding utf8 handling etc. is missing

if (eval { require YAML::XS; 1 }) {
    *Load     = sub { YAML::XS::Load(@_) };
    *Dump     = sub { YAML::XS::Dump(@_) };
    *LoadFile = sub { YAML::XS::LoadFile(@_) };
    *DumpFile = sub { YAML::XS::DumpFile(@_) }
} elsif (0 && eval { require YAML::PP; 1 }) {
    *Load     = sub { YAML::PP::Load(@_) };
    *Dump     = sub { YAML::PP::Dump(@_) };
    *LoadFile = sub { YAML::PP::LoadFile(@_) };
    *DumpFile = sub { YAML::PP::DumpFile(@_) }
} elsif (0 && eval { require YAML::Syck; 1 }) {
    *Load     = sub { YAML::Syck::Load(@_) };
    *Dump     = sub { YAML::Syck::Dump(@_) };
    *LoadFile = sub { YAML::Syck::LoadFile(@_) };
    *DumpFile = sub { YAML::Syck::DumpFile(@_) }
} elsif (0 && eval { require YAML; 1 }) {
    *Load     = sub { YAML::Load(@_) };
    *Dump     = sub { YAML::Dump(@_) };
    *LoadFile = sub { YAML::LoadFile(@_) };
    *DumpFile = sub { YAML::DumpFile(@_) }
} else {
    #die "Either YAML::XS, YAML::PP, YAML::Syck or YAML required";
    die $@;
}

1;

__END__
