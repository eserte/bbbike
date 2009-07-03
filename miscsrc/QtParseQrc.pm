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

package QtParseQrc;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Cwd qw(realpath);
use File::Basename qw(dirname);
use File::Spec;
use XML::LibXML;

sub get_qrc_res2file {
    my $qrc_file = shift;
    my $p = XML::LibXML->new;
    my $doc = $p->parse_file($qrc_file);
    my $base_dir = dirname realpath $qrc_file;
    my $root = $doc->documentElement;
    my %res2file;
    for my $qresource_node ($root->findnodes('/RCC/qresource')) {
	my $prefix = $qresource_node->getAttribute('prefix');
	$prefix = '' if !defined $prefix;
	for my $file_node ($qresource_node->findnodes('./file')) {
	    my $raw = $file_node->textContent;
	    my $res_name = $prefix . '/' . $raw;
	    my $file = File::Spec->rel2abs($raw, $base_dir);
	    $res2file{$res_name} = $file;
	}
    }
    \%res2file;
}

1;

__END__

=head1 NAME

QtParseQrc - parse qrc files

=head1 SYNOPSIS

    perl -MData::Dumper -MQtParseQrc -e 'warn Dumper(QtParseQrc::get_qrc_res2file(shift))' /usr/ports/astro/merkaartor/work/merkaartor-0.13.2/Icons/AllIcons.qrc

=cut

