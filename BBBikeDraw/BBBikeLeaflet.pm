# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW: http://bbbike.de
#

package BBBikeDraw::BBBikeLeaflet;

use strict;
use warnings;
use vars qw($VERSION);
$VERSION = '0.01';

use base qw(BBBikeDraw);

use CGI qw(:standard);

sub module_handles_all_cgi { 1 }

sub pre_draw {
    my $self = shift;
    $self->{PreDrawCalled}++;
}

my $default_bbbikeleaflet_url = "http://bbbike.de/cgi-bin/bbbikeleaflet.cgi"; # XXX probably use BBBikeVar.pm or so for default bbbike.de URL instead

# XXX??? nop, automatically drawn if coordinates exist
sub draw_route { }

# Without the need to POST:
sub flush_direct_redirect {
    my $self = shift;
    my $q = $self->{CGI} || CGI->new;
    my @wpt;
    if ($self->{BBBikeRoute}) {
	for my $wpt (@{ $self->{BBBikeRoute} }) {
	    push @wpt, join "!", $wpt->{Strname}, $wpt->{Coord};
	}
    }
    my @multi_c = @{ $self->{MultiCoords} || [] } ? @{ $self->{MultiCoords} } : @{ $self->{Coords} || [] } ? [ @{ $self->{Coords} } ] : ();
    my $q2 = CGI->new({coords  => [map { join "!", @$_ } @multi_c], # XXX coords vs wgs84_coords?
		       #XXX? (@wpt ? (wpt => \@wpt) : ()),
		       (!@multi_c && !@wpt ? (wpt => join(",", $self->get_map_center)) : ()),
		      });
    print $q->redirect($self->_bbbikeleafet_url . "?" . $q2->query_string);
    return;
}

sub mimetype { "text/html" }

sub flush {
    my $self = shift;
    my $q = $self->{CGI} || CGI->new;
    my @multi_c = @{ $self->{MultiCoords} || [] } ? @{ $self->{MultiCoords} } : @{ $self->{Coords} || [] } ? [ @{ $self->{Coords} } ] : ();
    my $oldcoords =
	@{ $self->{OldCoords} || [] }
	    ? join "!", @{ $self->{OldCoords} }
		: undef;
    my @wpt;
    if ($self->{BBBikeRoute}) {
	for my $wpt (@{ $self->{BBBikeRoute} }) {
	    push @wpt, join "!", $wpt->{Strname}, $wpt->{Coord};
	}
    }

    my $fh = $self->{Fh} || \*STDOUT;

    print $fh header(-type => $self->mimetype,
		     -Vary => "User-Agent", # XXX needed?
		    );
    print $fh start_html(-onLoad => "init()",
			 -script => <<EOF);
function init() {
    document.forms[0].submit();
}
EOF
    print $fh start_form(-action => $self->_bbbikeleafet_url,
			 -method => "POST");
    for my $c (@multi_c) {
	my $coords = join "!", @$c;
	print $fh hidden("coords", $coords);
    }
    # XXX this canot work
    if (!@multi_c) {
	print $fh hidden("wpt", join(",", $self->get_map_center));
    }
    # XXX no support --- print $fh hidden("oldcoords", $oldcoords) if $oldcoords;
    # XXX no support for my $wpt (@wpt) { print $fh hidden("wpt", $wpt); }
    print $fh "<noscript>";
    print $fh submit("Weiterleitung auf bbbikeleaflet");
    print $fh "</noscript>";
    print $fh end_form, end_html;
}

sub get_map_center {
    my($self) = @_;
    my $x = int(($self->{Max_x} - $self->{Min_x})/2 + $self->{Min_x});
    my $y = int(($self->{Max_y} - $self->{Min_y})/2 + $self->{Min_y});
    ($x, $y);
}

sub _bbbikeleafet_url {
    my($self) = @_;
require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$self->{Conf}],[qw()])->Indent(1)->Useqq(1)->Sortkeys(1)->Terse(1)->Dump; # XXX
    $self->{Conf}->{BBBikeLeafletUrl} || $default_bbbikeleaflet_url;
}

1;

__END__
