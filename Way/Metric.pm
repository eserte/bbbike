# -*- perl -*-

#
# $Id: Metric.pm,v 1.1 2000/08/23 23:24:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Way::Metric;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub sqr { $_[0] * $_[0] }

######################################################################
package Way::Node::Metric;
use base qw(Way::Node);

# Return angle and direction
sub angle {
    my $node = shift;
    return if !$node->{PrevEdge} || !$node->{NextEdge};

    my $prev_node = $node->{PrevEdge}{PrevNode};
    my $next_node = $node->{NextEdge}{NextNode};

    require POSIX; # XXX fallback to Math::Trig, if necessary

    my $x1 = $node->{X}-$prev_node->{X};
    my $y1 = $node->{Y}-$prev_node->{Y};
    my $x2 = $next_node->{X}-$node->{X};
    my $y2 = $next_node->{Y}-$node->{Y};

    my $sp = $x1*$y2-$y1*$x2;
    my $direction = ($sp > 0 ? 'l' : ($sp == 0 ? '' : 'r'));
    my $angle = 0;
    eval {
	$angle = POSIX::acos
	    (
	     ($x1*$x2+$y1*$y2) /
	     (sqrt(Way::Metric::sqr($x1)+Way::Metric::sqr($y1)) *
	      sqrt(Way::Metric::sqr($x2)+Way::Metric::sqr($y2))
	     )
	    );
    };
    warn $@ if $@;
    ($angle, $direction);
}

######################################################################
package Way::Edge::Metric;
use base qw(Way::Edge);

sub calc_len {
    my $self = shift;
    my($x1,$y1) = @{ $self->{PrevNode} }{qw/X Y/};
    my($x2,$y2) = @{ $self->{NextNode} }{qw/X Y/};
    $self->{Len} = sqrt(Way::Metric::sqr($x2-$x1) + Way::Metric::sqr($y2-$y1));
}

######################################################################
package Way::Metric;
use base qw(Way);

sub node_class { "Way::Node::Metric" }
sub edge_class { "Way::Edge::Metric" }

sub add_node {
    my($self, $node) = @_;
    my $res = $self->SUPER::add_node($node);
    if (@{ $self->{Edges} }) {
	$self->{Edges}[-1]->calc_len;
    }
    $res;
}

1;

__END__
