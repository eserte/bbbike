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

# XXX TODO UNFINISHED!
# TODO: parse selector

package MerkaartorMas;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Cwd qw(realpath);
use QtQrc;
use XML::LibXML;

sub parse_icons_from_mas {
    my($mas_file, $qrc_file) = @_;

    my $res2file = QtQrc::get_qrc_res2file($qrc_file);

    my $p = XML::LibXML->new;
    my $doc = $p->parse_file($mas_file);
    my $root = $doc->documentElement;

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
	warn $res_icon . ' -> ' . $res2file->{$res_icon} . "\n";
    }
}

1;

__END__

=head1 NAME

MerkaartorMas - parse Merkaartor .mas files

=head1 SYNOPSIS

    perl -MData::Dumper -MMerkaartorMas -e 'warn Dumper(MerkaartorMas::parse_icons_from_mas(shift, shift))' /usr/ports/astro/merkaartor/work/merkaartor-0.13.2/Styles/MapnikPlus.mas /usr/ports/astro/merkaartor/work/merkaartor-0.13.2/Icons/AllIcons.qrc

=cut
