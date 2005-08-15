# -*- perl -*-

#
# $Id: DB_File.pm,v 1.4 2005/08/15 05:46:48 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::DB_File;

use strict;
use vars qw($VERSION @ISA);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

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

# Has to be overwritten to handle comments and directives
sub next {
    my($self) = shift;
    my $r = $self->SUPER::next(@_);
    if (defined $r->[Strassen::NAME] && $r->[Strassen::NAME] =~ /^#/) {
	$self->next;
    } else {
	$r;
    }
}

1;

__END__
