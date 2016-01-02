# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2016 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::GpsmanData::TestRoundtrip;

use strict;
use vars qw($VERSION);
$VERSION = '0.02';

use File::Temp qw(tempfile);
use XML::LibXML;

use GPS::GpsmanData;
use GPS::GpsmanData::Any;

sub gpx2gpsman2gpx {
    my($file, %args) = @_;
    my $timeoffset = delete $args{timeoffset};
    die 'Unhandled arguments: ' . join(' ', %args) if %args;

    my $gpsman_any = GPS::GpsmanData::Any->load($file, (defined $timeoffset ? (timeoffset => $timeoffset) : ()));

    my($tmp0fh,$tmp0file) = tempfile(SUFFIX => '_gpx2gpsman.gpsman', UNLINK => 1);
    $gpsman_any->write($tmp0file);

    my $gpsman = GPS::GpsmanMultiData->new;
    $gpsman->load($tmp0file);

    my($tmpfh,$tmpfile) = tempfile(SUFFIX => '_gpx2gpsman.gpx', UNLINK => 1);
    print $tmpfh $gpsman->as_gpx;
    close $tmpfh
	or die "Can't write to $tmpfile: $!";

    my $doc_before = XML::LibXML->new->parse_file($file);
    my $doc_after  = XML::LibXML->new->parse_file($tmpfile);

    unlink $tmpfile;

    ######################################################################
    # Strip and normalize
    strip_unhandled_gpx_stuff($doc_before);
    strip_unhandled_gpx_stuff($doc_after);

    # If the creator was empty before, or the string "GPSMan", then
    # it's OK to have it filled afterwards; normalize this difference
    # away.
    if ($doc_before->documentElement->getAttribute('creator') =~ m{^(|GPSMan)$} &&
	$doc_after->documentElement->getAttribute('creator') =~ m{^GPS::GpsmanData}) {
	$_->documentElement->removeAttribute('creator') for ($doc_before, $doc_after);
    }

    for ($doc_before, $doc_after) {
	$_->setStandalone(-1) if $_->standalone == 0;
	$_->setEncoding('UTF-8') if $_->encoding eq 'utf-8';
    }

    ######################################################################
    # Compare
    my $before_string = $doc_before->serialize(1);
    my $after_string  = $doc_after ->serialize(1);

    if ($before_string ne $after_string) {
	# Maybe just whitespace diffs? Do additional
	# normalization using xmllint (hopefully installed)
	my($before_fh,$before_file) = tempfile(SUFFIX => '_before.gpx', UNLINK => 1);
	my($after_fh, $after_file)  = tempfile(SUFFIX => '_after.gpx',  UNLINK => 1);
	print $before_fh $before_string;
	print $after_fh  $after_string;
	close $before_fh or die $!;
	close $after_fh or die $!;
	system('zsh', '-c', "diff -u =(xmllint -format $before_file) =(xmllint -format $after_file) 1>&2");
	my $st = $?;
	unlink $before_file;
	unlink $after_file;
	if ($st == 0) {
	    return 1;
	} else {
	    return 0;
	}
    } else {
	return 1;
    }
}

# Normalize following things:
# - missing (unnecessary) namespace declarations
# - schemaLocation incomplete
# - <metadata> not handled
sub strip_unhandled_gpx_stuff {
    my $doc = shift;
    my $root = $doc->documentElement;

    my $new_root = $doc->createElementNS($root->namespaceURI, $root->nodeName);

    my @new_attributes;
    for my $attr ($root->attributes) {
	if (!UNIVERSAL::isa($attr, 'XML::LibXML::Namespace')) {
	    my $name = $attr->name;
	    if ($name ne 'schemaLocation') {
		push @new_attributes, [$name, $attr->value];
	    }
	}
    }
    for my $new_attribute (sort { $a->[0] cmp $b->[0] } @new_attributes) {
	$new_root->setAttribute($new_attribute->[0], $new_attribute->[1]);
    }

    for my $elem ($root->childNodes) {
	if ($elem->nodeName ne 'metadata') {
	    $new_root->appendChild($elem);
	}
    }

    $doc->setDocumentElement($new_root);
}

1;

__END__
