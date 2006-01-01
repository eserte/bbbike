# -*- perl -*-

#
# $Id: Touratech.pm,v 1.2 2005/12/31 17:11:06 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::Touratech;

use strict;
use vars qw($VERSION @ISA);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use File::Basename qw(dirname);

use XML::LibXML;
use XML::LibXSLT;

use Strassen::Core;
use Strassen::GPX;

@ISA = 'Strassen';

sub new {
    my($class, $filename, %args) = @_;
    my $self = {};
    bless $self, $class;

    if ($filename) {
	my $gpxdata = $self->ttqv2gpx($filename, %args);

	my $gpx = Strassen::GPX->new;
	$gpx->gpxdata2bbd($gpxdata);

	# hmmm, somewhat hackish...
	bless $gpx, $class;
	return $gpx;
    }

    $self;
}

sub ttqv2gpx {
    my($self, $filename, %args) = @_;

    my $xslt_file = dirname(__FILE__) . "/../misc/ttqv2gpx.xsl";

    my $p = XML::LibXML->new;
    my $xslt = XML::LibXSLT->new;

    my $source = $p->parse_file($filename);
    my $style_doc = $p->parse_file($xslt_file);
    my $stylesheet = $xslt->parse_stylesheet($style_doc);
    my $results = $stylesheet->transform($source);
    $stylesheet->output_string($results);
}

1;

__END__
