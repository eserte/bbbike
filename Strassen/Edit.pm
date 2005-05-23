# -*- perl -*-

#
# $Id: Edit.pm,v 1.1 2005/05/23 22:30:34 eserte Exp $
#
# Copyright (c) 2005 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::Edit;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

package Strassen;
use strict;
use Strassen::Core;

sub edit_delete_point {
    my($self, $line, $point_to_delete) = @_;
    my $c = $line->[Strassen::COORDS];
    my $deleted = 0;
    for(my $i = $#$c; $i >= 0; $i--) {
	if ($c->[$i] eq $point_to_delete) {
	    splice @$c, $i, 1;
	    $deleted++;
	}
    }
    $deleted;    
}

sub edit_all_delete_points {
    my($self, $point_to_delete) = @_;
    $self->init;
    my $total_deletions_in_lines = 0;
    my $total_deleted_points = 0;
    while(1) {
	my $ret = $self->next;
	last if !@{ $ret->[Strassen::COORDS] } && !defined $ret->[Strassen::NAME];
	my $deleted = $self->edit_delete_point($ret, $point_to_delete);
	$total_deleted_points += $deleted;
	if ($deleted) {
	    $total_deletions_in_lines++;
	}
	if (@{ $ret->[Strassen::COORDS] } == 0) {
	    # XXX This is not done automatically because of possible
	    # line directives or empty block directives.
	    warn "Line $ret->[Strassen::NAME] left with empty coords, please remove record manually!";
	}
    }
}

# XXX Will probably be replaced by a more powerful method
sub edit_delete_2_coord_lines {
    my($self, $line, $coord1, $coord2) = @_;
    my $c = $line->[Strassen::COORDS];
    if (@$c != 2) {
	warn "Can't handle only two point lines";
	return 0;
    }
    if (($c->[0] eq $coord1 && $c->[1] eq $coord2) ||
	($c->[0] eq $coord2 && $c->[1] eq $coord1)) {
	1; # delete
    } else {
	0; # don't delete
    }
}

# XXX see above
sub edit_all_delete_2_coord_lines {
    my($self, @coords) = @_;
    $self->init;
    while(1) {
	my $ret = $self->next;
	last if !@{ $ret->[Strassen::COORDS] } && !defined $ret->[Strassen::NAME];
	my $do_delete = 0;
	for my $i (1 .. $#coords) {
	    my($c1, $c2) = @coords[$i-1, $i];
	    if ($self->edit_delete_2_coord_lines($ret, $c1, $c2)) {
		$do_delete = 1;
		last;
	    }
	}
	if ($do_delete) {
	    $self->delete_current;
	}
    }
}


1;

__END__

=head1 NAME

Strassen::Edit - editing functionality for Strassen

=head1 SYNOPSIS

   use Strassen::Core;
   use Strassen::Edit;

=head1 SEE ALSO

L<Strassen::Core>

=cut
