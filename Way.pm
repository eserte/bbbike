# -*- perl -*-

#
# $Id: Way.pm,v 1.2 2001/07/25 21:37:04 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Way;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use Storable ();

######################################################################
package Way::Node;

use fields qw(X Y PrevEdge NextEdge IsVia Name Attrib);

BEGIN {
    if (!defined &fields::new) {
	eval <<'EOF';
sub fields::new {
  my $class = shift;
  no strict 'refs';
  my $self = bless [\%{"$class\::FIELDS"}], $class;
  $self;
}
EOF
        warn $@ if $@;
    }
}

sub new {
    my Way::Node $self = shift;
    $self = fields::new($self) unless ref $self;

    my %args = @_;

    while(my($k,$v) = each %args) {
	$self->{$k} = $v;
    }

    $self;
}

sub clone { Storable::dclone($_[0]) }

sub xy { $_[0]->{X} . "," . $_[0]->{Y} }

######################################################################
package Way::Edge;

use fields qw(Len PrevNode NextNode Name AttribBoth AttribFw AttribBw);

sub new {
    my Way::Edge $self = shift;
    $self = fields::new($self) unless ref $self;

    my %args = @_;

    while(my($k,$v) = each %args) {
	$self->{$k} = $v;
    }

    $self;
}

sub clone { Storable::dclone($_[0]) }

######################################################################
package Way;

use fields qw(Edges Nodes);

sub node_class { "Way::Node" }
sub edge_class { "Way::Edge" }

sub new {
    my Way $self = shift;
    $self = fields::new($self) unless ref $self;

    $self->reset;

    $self;
}

sub new_from_nodes {
    my($class, @nodes) = @_;
    my Way $self = $class->new();
    return unless @nodes;

    my $edge_class = $self->edge_class;

    $self->add_node(shift @nodes);
    foreach my $node (@nodes) {
	my Way::Edge $edge = $edge_class->new;
	$self->add_edge($edge);
	$self->add_node($node);
    }

    $self;
}

sub reverse {
    my $self = shift;
    my @new_nodes;
    my @new_edges;
    while(@{ $self->{Nodes} }) {
	push @new_nodes, pop @{ $self->{Nodes} };
	($new_nodes[-1]->{NextEdge}, $new_nodes[-1]->{PrevEdge}) =
	    ($new_nodes[-1]->{PrevEdge}, $new_nodes[-1]->{NextEdge});
    }
    while(@{ $self->{Edges} }) {
	push @new_edges, pop @{ $self->{Edges} };
	($new_edges[-1]->{NextNode}, $new_edges[-1]->{PrevNode}) =
	    ($new_edges[-1]->{PrevNode}, $new_edges[-1]->{NextNode});
    }

    @{ $self->{Nodes} } = @new_nodes;
    @{ $self->{Edges} } = @new_edges;

    $self;
}

sub clone { Storable::dclone($_[0]) }

sub concat {
    my($class, @ways) = @_;

    my Way $self =
	(ref $class && $class->isa(__PACKAGE__)
	 ? $class
	 : $class->new()
	);

    foreach my $way (@ways) {
	if (not $way->is_empty) {
	    my $way_nodes = $way->{Nodes};
	    if (not $self->is_empty) {
		if ($self->{Nodes}[-1]->xy != $way_nodes->[0]->xy) {
		    die "Nodes do not match in concat";
		}
		push @{ $self->{Nodes} }, @{ $way_nodes }[1 .. $#$way_nodes];
		push @{ $self->{Edges} }, @{ $way->{Edges} };
	    }
	}
    }

    $self;
}

sub reset {
    my $self = shift;
    $self->{Edges} = [];
    $self->{Nodes} = [];
}

sub is_empty {
    my $self = shift;
    @{ $self->{Nodes} } == 0;
}

sub from {
    my $self = shift;
    if (!$self->is_empty) {
	$self->{Nodes}[0];
    } else {
	undef;
    }
}

sub to {
    my $self = shift;
    if (!$self->is_empty) {
	$self->{Nodes}[-1];
    } else {
	undef;
    }
}

sub via {
    my $self = shift;
    my @via;
    foreach my $node (@{ $self->{Nodes} }) {
	if ($node->{IsVia}) {
	    push @via, $node;
	}
    }
    \@via;
}

sub len {
    my $self = shift;
    my $len = 0;
    foreach my $edge (@{ $self->{Edges} }) {
	$len += $edge->{Len};
    }
    $len;
}

sub dump {
    my $self = shift;
    my $edge_i = 0;
    my $node_i = 0;
    print STDERR "Way $self\n";
    my $len    = 0;
    foreach my $node (@{ $self->{Nodes} }) {
	printf STDERR
	    "Node %04d: (%.1f/%.1f)\n", $node_i, $node->{X}, $node->{Y};
	my $edge = $self->{Edges}[$edge_i];
	if ($edge) {
	    printf STDERR "Edge %04d:", $edge_i;
	    if (defined $edge->{Len}) {
		$len += $edge->{Len};
		printf STDERR " len=%.1f", $edge->{Len};
	    }
	    printf STDERR "\n";
	}
	$node_i++;
	$edge_i++;
    }
    print STDERR "Len=$len\n";
}

sub nodes_by_sub {
    my $self = shift;
    my $sub = shift;
    my @nodes;
    foreach my $node (@{ $self->{Nodes} }) {
	if ($sub->($self, $node)) {
	    push @nodes, $node;
	}
    }
    \@nodes;
}

sub edges_by_sub {
    my $self = shift;
    my $sub = shift;
    my @edges;
    foreach my $edge (@{ $self->{Edges} }) {
	if ($sub->($self, $edge)) {
	    push @edges, $edge;
	}
    }
    \@edges;
}

sub add_node {
    my($self, $node) = @_;
    if (@{ $self->{Edges} } < @{ $self->{Nodes} }) {
	die "Mismatch: must add edge before node";
    }
    push @{ $self->{Nodes} }, $node;
    my $last_edge = $self->{Edges}[-1];
    return unless $last_edge;
    $last_edge->{NextNode} = $node;
    $node->{PrevEdge} = $last_edge;
}

sub add_edge {
    my($self, $edge) = @_;
    if (@{ $self->{Nodes} } <= @{ $self->{Edges} }) {
	die "Mismatch: must add node before edge";
    }
    push @{ $self->{Edges} }, $edge;
    my $last_node = $self->{Nodes}[-1];
    $last_node->{NextEdge} = $edge;
    $edge->{PrevNode} = $last_node;
}

sub del_last_node {
    my($self) = @_;
    if (!@{ $self->{Nodes} }) {
	die "Nothing to delete, no nodes available";
    }
    if (@{ $self->{Nodes} } <= @{ $self->{Edges} }) {
	die "Mismatch: must del edge before node";
    }
    my $node = pop @{ $self->{Nodes} };
    my $last_edge = $self->{Edges}[-1];
    return unless $last_edge;

    undef $last_edge->{NextNode};
    undef $node->{PrevEdge};
    $node;
}

sub del_last_edge {
    my($self) = @_;
    if (!@{ $self->{Edges} }) {
	die "Nothing to delete, no edges available";
    }
    if (@{ $self->{Edges} } < @{ $self->{Nodes} }) {
	die "Mismatch: must del node before edge";
    }
    my $edge = pop @{ $self->{Edges} };
    my $last_node = $self->{Nodes}[-1];
    undef $last_node->{NextEdge};
    undef $edge->{PrevNode};
    $edge;
}

sub DESTROY {
    my $self = shift;
    foreach my $node (@{ $self->{Nodes} }) {
	delete $node->{PrevEdge};
	delete $node->{NextEdge};
    }
    foreach my $edge (@{ $self->{Edges} }) {
	delete $edge->{PrevNode};
	delete $edge->{NextNode};
    }
}

1;

__END__
