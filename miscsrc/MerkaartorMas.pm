# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package MerkaartorMas;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Cwd qw(realpath);
use QtQrc;
use XML::LibXML;

# XXX Can only do simple attribute matches. In the future, the full
# selector expression will be supported.
sub parse_icons_from_mas {
    my($mas_file, $qrc_file) = @_;

    my $res2file = QtQrc::get_qrc_res2file($qrc_file);

    my $p = XML::LibXML->new;
    my $doc = $p->parse_file($mas_file);
    my $root = $doc->documentElement;

    my %match_to_icon;

    for my $painter_node ($root->findnodes('/mapStyle/painter[@icon]')) {
	my $icon = $painter_node->getAttribute('icon');
	if ($icon !~ m{^:(.*)}) {
	    warn "Unexpected icon attribute '$icon', skipping...\n";
	}
	my $res_icon = $1;
	if (!exists $res2file->{$res_icon}) {
	    warn "Cannot find file for resource icon '$res_icon', skipping...\n";
	    next;
	}
	my $selector_expr = $painter_node->findvalue('./selector/@expr');
	if (!$selector_expr) {
	    warn "No selector expression, skipping...\n";
	}
	my($match_attr, @match_vals);
	if      ($selector_expr =~ m{^\[(.*?)\]\s+is\s+(\S+)$}) {
	    $match_attr = $1;
	    @match_vals = $2;
	} elsif ($selector_expr =~ m{^\[(.*?)\]\s+isoneof\s+\(\s*(.*?)\s*\)$}) {
	    $match_attr = $1;
	    @match_vals = split /\s*,\s*/, $2;
	} else {
	    warn "NYI: selector expression '$selector_expr', skipping...\n";
	    next;
	}

	for my $val (@match_vals) {
	    $match_to_icon{"$match_attr:$val"} = $res2file->{$res_icon};
	}
    }

    \%match_to_icon;
}

1;

__END__

=head1 NAME

MerkaartorMas - parse Merkaartor .mas files

=head1 SYNOPSIS

    perl -MData::Dumper -MMerkaartorMas -e 'warn Dumper(MerkaartorMas::parse_icons_from_mas(shift, shift))' /usr/ports/astro/merkaartor/work/merkaartor-0.13.2/Styles/MapnikPlus.mas /usr/ports/astro/merkaartor/work/merkaartor-0.13.2/Icons/AllIcons.qrc

=cut
