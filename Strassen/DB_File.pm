# -*- perl -*-

#
# $Id: DB_File.pm,v 1.3 2003/01/08 20:14:09 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::DB_File;

use strict;
use vars qw($VERSION @ISA);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

@ISA = qw(Strassen);

use Strassen::Core;
use DB_File;
use Fcntl;

sub read_data {
    my($self) = @_;
    my $file = $self->{File};
    if ($self->{IsGzipped}) {
	die "Strassen::DB_File does not support gzipped files";
    }
    tie @{ $self->{Data} }, 'DB_File', $file, O_RDONLY, 0644, $DB_RECNO
	or die "Can't tie $file: $!";
    # XXX optional sanity check: no comments in data
}

1;

__END__
