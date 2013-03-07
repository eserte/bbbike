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

package DistDB;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use DB_File;
use Fcntl qw(O_CREAT O_RDWR);


sub new {
    my($class, $dbfile) = @_;
    die "dbfile not given" if !$dbfile;
    tie my %db, 'DB_File', $dbfile, O_RDWR|O_CREAT
	or die "Cannot tie $dbfile: $!";
    bless { db => \%db }, $class;
}

sub _get_routing {
    my $self = shift;
    return $self->{routing} if $self->{routing};

    require BBBikeRouting;

    my $routing = BBBikeRouting->new;
    $routing->init_context;
    $routing->change_scope("wideregion");
    $self->{routing} = $routing;
}

sub get_dist {
    my($self, $from, $to) = @_;
    my $db = $self->{db};
    my $key = $from . ' ' . $to;
    my $dist = $db->{$key};
    if (!defined $dist) {
	$dist = $self->calculate_dist($from, $to);
	$db->{$key} = $dist;
    }
    $dist;
}


sub calculate_dist {
    my($self, $from, $to) = @_;
    my $routing = $self->_get_routing;
    $routing->reset;
    $routing->Start->Coord($from);
    $routing->Goal->Coord($to);
    $routing->fix_position($_) for ($routing->Start, $routing->Goal);
    $routing->search;
    my $route_info = $routing->RouteInfo;
    $route_info->[-1]->{WholeMeters};
}

1;

__END__

=head1 NAME

DistDB - a cache database with calculated distances

=head1 DESCRIPTION

B<DistDB> is a simple caching layer for the distance result of a route
search. First use of the L<get_dist> method for an previously
unhandled coordinate pair does a route search (using L<BBBikeRouting>
with default settings), and stores the value to the db. A second call
just fetches the cached value.

Note that no modification checks are done here. If the street net
significantly changed, then the dist db needs to be recalculated again
(e.g. by removing the old db file).

Note also that only default settings can be used ("bike" vehicle,
standard search options, Berlin street data).

=head1 EXAMPLES

Command line usage:

    cd .../bbbike
    perl -I. -Imiscsrc -Ilib -MDistDB -e '$ddb=DistDB->new("/tmp/dist.db"); warn $ddb->get_dist("12793,11132", "13086,9825")'

=head1 SEE ALSO

L<BBBikeRouting>.

=cut
