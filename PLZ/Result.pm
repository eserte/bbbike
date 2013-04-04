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

package PLZ::Result;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Scalar::Util qw(weaken);

sub new {
    my($class, $plz_obj, $result_arrayref) = @_;
    weaken $plz_obj;
    bless {
	   r   => $result_arrayref,
	   plz => $plz_obj,
	  }, $class;
}

sub get_name      { shift->{r}->[PLZ::FILE_NAME()]     }
sub get_citypart  { shift->{r}->[PLZ::FILE_CITYPART()] }
sub get_zip       { shift->{r}->[PLZ::FILE_ZIP()]      }
sub get_coord     { shift->{r}->[PLZ::FILE_COORD()]    }

sub get_field {
    my($self, $key) = @_;
    $self->{plz}->get_extfield($self->{r}, $key);
}

sub add_field {
    my($self, $key, $val) = @_;
    push @{ $self->{r} }, "$key=$val";
}

sub get_street_type {
    my($self) = @_;
    $self->{plz}->get_street_type($self->{r});
}

1;

__END__
