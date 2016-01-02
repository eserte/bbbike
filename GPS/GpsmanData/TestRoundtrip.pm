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
$VERSION = '0.04';

use File::Temp qw(tempfile);
use IPC::Run qw(run);
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

    # normalize xml attributes
    for ($doc_before, $doc_after) {
	$_->setStandalone(-1) if $_->standalone == 0;
	$_->setEncoding('UTF-8') if $_->encoding eq 'utf-8';
    }

    # Newlines are preserved in gpsman files
    for my $node ($doc_before->findnodes('//*[local-name(.)="cmt"]/text()')) {
	my $node_value = $node->getData;
	if ($node_value =~ m{\n}) {
	    $node_value =~ s{\n}{ }g;
	    $node->setData($node_value);
	}
    }

    ######################################################################
    # Compare
    my $before_string = $doc_before->serialize(1);
    my $after_string  = $doc_after ->serialize(1);

    if ($before_string ne $after_string) {
	# Maybe just whitespace diffs? Do additional
	# normalization using xmllint (hopefully installed)
	my($formatted_before_string, $formatted_after_string);
	if (!run ['xmllint', '-format', '-'], '<', \$before_string, '>', \$formatted_before_string) {
	    die "Error running xmllint: $!";
	}
	if (!run ['xmllint', '-format', '-'], '<', \$after_string, '>', \$formatted_after_string) {
	    die "Error running xmllint: $!";
	}
	if ($formatted_before_string eq $formatted_after_string) {
	    return 1;
	} else {
	    my($before_fh,$before_file) = tempfile(SUFFIX => '_before.gpx', UNLINK => 1);
	    my($after_fh, $after_file)  = tempfile(SUFFIX => '_after.gpx',  UNLINK => 1);
	    print $before_fh $formatted_before_string;
	    print $after_fh  $formatted_after_string;
	    close $before_fh or die $!;
	    close $after_fh or die $!;
	    system("diff -u $before_file $after_file 1>&2");
	    my $st = $?;
	    unlink $before_file;
	    unlink $after_file;
	    if ($st == 0) {
		return 1;
	    } else {
		return 0;
	    }
	}
    } else {
	return 1;
    }
}

# Normalize following things:
# - in root element:
#   - missing (unnecessary) namespace declarations
#   - schemaLocation incomplete
# - <metadata> not handled
# - <trk><number> not handled
sub strip_unhandled_gpx_stuff {
    my $doc = shift;
    my $root = $doc->documentElement;

    # namespace normalizations
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

    # sort root attributes
    for my $new_attribute (sort { $a->[0] cmp $b->[0] } @new_attributes) {
	$new_root->setAttribute($new_attribute->[0], $new_attribute->[1]);
    }

    # remove <metadata>
    for my $elem ($root->childNodes) {
	if ($elem->nodeName ne 'metadata') {
	    $new_root->appendChild($elem);
	}
    }

    # we're finish with root element manipulations
    $doc->setDocumentElement($new_root);

    # remove <trk><number>
    for my $node ($doc->findnodes('//*[local-name(.)="trk"]/*[local-name(.)="number"]')) {
	$node->parentNode->removeChild($node);
    }

}

1;

__END__

=head1 NAME

GPS::GpsmanData::TestRoundtrip - roundtrip check for gpx -> gpsman conversion

=head1 SYNOPSIS

    use GPS::GpsmanData::TestRoundtrip;
    $success = GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($gpxfile, timeoffset => ...);

=head1 DESCRIPTION

Provides a function for checking the data consistency of a gpx ->
gpsman -> gpx roundtrip when using L<GPS::GpsmanData::Any>. The
roundtrip check is using a normalization step, because some data is
known to not be preserved or needs to be normalized:

=over

=item * C<creator> may contain the name of a creating program or the
name of the creating GPS device. If nothing is set, then
L<GPS::GpsmanData> would fill in its own name in the creation process.

=item * The default for C<standalone> or the capitalization of the
C<encoding> attribute may be different.

=item * The GPSMan format cannot handle newlines in comments.

=item * Unused XML namespace declarations may be stripped in the
conversion process.

=item * The GPSMan format does not handle the <metadata> element.

=item * The GPSMan format does not handle the <number> element in <trk>
elements.

=back

The C<timeoffset> argument is optional.

If the roundtrip was successful, then a true value is returned.

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<GPS::GpsmanData::Any>, L<xmllint(1)>, L<diff(1)>.

=cut
