#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: way.t,v 1.3 2009/02/25 23:41:16 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

use lib "$FindBin::RealBin/..";

use Way;
use Way::Metric;

BEGIN {
    if (!eval q{
	use Test;
	$^W = 1;
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

BEGIN { plan tests => 65 }

my Way $way = new Way;
ok(ref $way, "Way");
ok($way->is_empty, 1);

my Way $way2 = new Way;
my Way $way3 = concat Way $way, $way2;
ok(ref $way3, "Way");
ok($way3->is_empty, 1);

my Way::Node $node1 = new Way::Node X => 1, Y => 2;
ok(ref $node1, "Way::Node");
ok($node1->{X}, 1);
ok($node1->{Y}, 2);
ok($node1->xy, "1,2");
ok($node1->{IsVia}, undef);

my Way::Edge $edge1 = new Way::Edge;
ok(ref $edge1, "Way::Edge");

$way->add_node($node1);
ok(scalar @{ $way->{Nodes} }, 1);
$way->add_edge($edge1);
ok(scalar @{ $way->{Edges} }, 1);

ok($node1->{NextEdge}, $edge1);
ok($node1->{PrevEdge}, undef);
ok($edge1->{NextNode}, undef);
ok($edge1->{PrevNode}, $node1);

eval {
    $way->add_edge($edge1);
};
ok($@ ne "", 1);

my Way::Node $node2 = new Way::Node X => 3, Y => 4;
eval {
    $way->add_node($node2);
    $way->add_node($node1);
};
ok($@ ne "", 1);

ok($edge1->{NextNode}, $node2);
ok($node2->{PrevEdge}, $edge1);

ok($way->edge_class, "Way::Edge");
ok($way->node_class, "Way::Node");
ok(edge_class Way, "Way::Edge");
ok(node_class Way, "Way::Node");

# subclassing

my Way::Metric $waym = new Way::Metric;
ok(ref $waym, "Way::Metric");
ok($waym->isa('Way'), 1);

ok($waym->edge_class, "Way::Edge::Metric");
ok($waym->node_class, "Way::Node::Metric");
ok(edge_class Way::Metric, "Way::Edge::Metric");
ok(node_class Way::Metric, "Way::Node::Metric");

my Way::Node::Metric $nodem = new Way::Node::Metric X => 1, Y => 2;
ok(ref $nodem, "Way::Node::Metric");
ok($nodem->isa('Way::Node'), 1);

my Way::Edge::Metric $edgem = new Way::Edge::Metric;
ok(ref $edgem, "Way::Edge::Metric");
ok($edgem->isa('Way::Edge'), 1);

$waym->add_node($nodem);
$waym->add_edge($edgem);

my Way::Node::Metric $node2m = new Way::Node::Metric X => 5, Y => 5;
$waym->add_node($node2m);

ok($edgem->{Len}, 5);
ok($waym->len, 5);

my $cloned = $waym->clone;
ok(ref $cloned, "Way::Metric");
ok(scalar @{ $waym->{Nodes} }, scalar @{ $cloned->{Nodes} });
ok(scalar @{ $waym->{Edges} }, scalar @{ $cloned->{Edges} });
ok($waym->from->xy, $cloned->from->xy);
ok($waym->to->xy, $cloned->to->xy);
ok($waym->{Nodes}[0] eq $cloned->{Nodes}[0], "");
ok($waym->{Edges}[0] eq $cloned->{Edges}[0], "");

$cloned->reverse;
ok(ref $cloned, "Way::Metric");
ok(scalar @{ $waym->{Nodes} }, scalar @{ $cloned->{Nodes} });
ok(scalar @{ $waym->{Edges} }, scalar @{ $cloned->{Edges} });
ok($waym->from->xy, $cloned->to->xy);
ok($waym->to->xy, $cloned->from->xy);

my Way::Edge::Metric $edge0m = new Way::Edge::Metric;
$cloned->add_edge($edge0m);
my Way::Node::Metric $node0m = new Way::Node::Metric X => -3, Y => -1;
$cloned->add_node($node0m);

my $node_middle = $cloned->{Nodes}[1];
ok($cloned->len, 10);
ok(($node_middle->angle)[0], 0);
ok(($node_middle->angle)[1], '');

my $last_node = $cloned->del_last_node;
$last_node->{Y} = 0;
$cloned->add_node($last_node);
ok(($node_middle->angle)[1], 'r');
my($angle_right) = $node_middle->angle;
ok($angle_right >= 0.179 && $angle_right <= 0.180, 1);

$last_node = $cloned->del_last_node;
$last_node->{X} = -2;
$last_node->{Y} = -1;
$cloned->add_node($last_node);
ok(($node_middle->angle)[1], 'l');
my($angle_left) = $node_middle->angle;
ok($angle_left >= 0.141 && $angle_left <= 0.142, 1);

$last_node = $cloned->del_last_node;
$last_node->{X} = -2;
$last_node->{Y} = 6;
$cloned->add_node($last_node);
ok(($node_middle->angle)[1], 'r');
my($angle_rect) = $node_middle->angle;
ok($angle_rect, pi()/2);

eval {
    $waym->del_last_edge;
};
ok($@ ne "", 1);

$waym->del_last_node;
ok($edgem->{NextNode}, undef);
ok($node2m->{PrevEdge}, undef);
$waym->del_last_edge;
ok($nodem->{NextEdge}, undef);

my Way::Metric $way_from_nodes = new_from_nodes Way::Metric $nodem, $node2m;
ok(ref $way_from_nodes, "Way::Metric");
my $edge_from_nodes = $way_from_nodes->{Edges}[0];
ok($edge_from_nodes->{Len}, 5);
ok($edge_from_nodes, $nodem->{NextEdge});
ok($edge_from_nodes, $node2m->{PrevEdge});

# REPO BEGIN
# REPO NAME pi /home/e/eserte/src/repository 
# REPO MD5 c36e29c0a7cfc05784032fff5b741475
sub pi { 4 * atan2(1, 1) } # 3.141592653
# REPO END

__END__
