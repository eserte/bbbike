# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2005,2014,2015 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::GPX;

use strict;
use vars qw($VERSION @ISA);
$VERSION = '1.25';

use Strassen::Core;

use vars qw($use_xml_module);

sub _require_XML_LibXML () {
    eval {
	require XML::LibXML;
	1;
    };
}

sub _require_XML_Twig () {
    eval {
	require XML::Twig;
	XML::Twig->VERSION("3.26"); # set_root
	1;
    };
}

BEGIN {
    my @errs;
    # Prefer XML::LibXML over XML::Twig:
    # * currently it's somewhat faster when parsing huge gpx files
    #   (for example, ski.gpx (1.5MB) takes less than 1 second with XML::LibXML,
    #    and 8 seconds with XML::Twig, on a Athlon64, i386-freebsd,
    #    perl 5.8.8)
    if (_require_XML_LibXML) {
	$use_xml_module = "XML::LibXML";
    } else {
	push @errs, $@;
	if (_require_XML_Twig) {
	    $use_xml_module = "XML::Twig";
	} else {
	    push @errs, $@;
	    die "No XML::LibXML or XML::Twig 3.26 installed: @errs";
	}
    }
}

use Karte::Polar;
use Karte::Standard;

@ISA = 'Strassen';

my @COMMON_META_ATTRS = qw(name cmt desc src link number type); # common for rte and trk

use constant TRIP_EXT_NS => 'http://www.garmin.com/xmlschemas/TripExtensions/v1';

sub new {
    my($class, $filename_or_object, %args) = @_;
    if (UNIVERSAL::isa($filename_or_object, "Strassen")) {
	bless $filename_or_object, $class;
    } else {
	my $self = {};
	bless $self, $class;

	if ($filename_or_object) {
	    my $name = delete $args{name};
	    my $fallbackname = delete $args{fallbackname};
	    my $cat  = delete $args{cat};
	    $self->gpx2bbd($filename_or_object, name => $name, fallbackname => $fallbackname, cat => $cat);
	}

	$self;
    }
}

######################################################################
# GPX to BBD
#
sub gpx2bbd {
    my($self, $file, %args) = @_;

    my $latlong2xy = $self->_get_gpx2bbd_converter;

    $self->{File} = $file;

    if ($use_xml_module eq 'XML::LibXML') {
	_require_XML_LibXML;
	my $p = XML::LibXML->new;
	my $doc = $p->parse_file($file);
	$self->_gpx2bbd_libxml($doc, latlong2xy => $latlong2xy, %args);
    } else {
	_require_XML_Twig;
	my $twig = XML::Twig->new;
	$twig->parsefile($file);
	$self->_gpx2bbd_twig($twig, latlong2xy => $latlong2xy, %args);
    }
}

sub gpxdata2bbd {
    my($self, $data, %args) = @_;

    my $latlong2xy = $self->_get_gpx2bbd_converter;

    if ($use_xml_module eq 'XML::LibXML') {
	_require_XML_LibXML;
	my $p = XML::LibXML->new;
	my $doc = $p->parse_string($data);
	$self->_gpx2bbd_libxml($doc, latlong2xy => $latlong2xy, %args);
    } else {
	_require_XML_Twig;
	my $twig = XML::Twig->new;
	$twig->parse($data);
	$self->_gpx2bbd_twig($twig, latlong2xy => $latlong2xy, %args);
    }
}

sub _get_gpx2bbd_converter {
    my($self) = @_;

    my $latlong2xy;
    my $map = $self->get_global_directive("map");
    if ($map && $map eq 'polar') {
	if ($use_xml_module eq 'XML::LibXML') {
	    $latlong2xy = \&latlong2longlat;
	} else {
	    $latlong2xy = \&latlong2longlat_twig;
	}
    } else {
	if ($use_xml_module eq 'XML::LibXML') {
	    $latlong2xy = \&latlong2xy;
	} else {
	    $latlong2xy = \&latlong2xy_twig;
	}
    }

    $latlong2xy;
}

sub _gpx2bbd_libxml {
    my($self, $doc, %args) = @_;

    my $def_name = delete $args{name};
    my $def_cat  = delete $args{cat};
    if (!defined $def_cat) {
	$def_cat = "X";
    }
    my $fallback_name = delete $args{fallbackname};
    my $latlong2xy = delete $args{latlong2xy};

    my $name_xpath = XML::LibXML::XPathExpression->new('./*[local-name()="name"]');

    my $get_name = sub {
	my($node) = @_;
	my $name;
	if (defined $def_name) {
	    $name = $def_name;
	} else {
	    $name = $node->findvalue($name_xpath);
	    if ($name eq '' && defined $fallback_name) {
		$name = $fallback_name;
	    }
	}
	$name;
    };

    my $root = $doc->documentElement;

    for my $wpt ($root->childNodes) {
	next if $wpt->nodeName ne "wpt";
	my($x, $y) = $latlong2xy->($wpt);
	my $name = $get_name->($wpt);
	$self->push([$name, ["$x,$y"], $def_cat]);
    }

    for my $trk ($root->childNodes) {
	next if $trk->nodeName ne "trk";
	for my $trk_child ($trk->childNodes) {
	    if ($trk_child->nodeName eq 'trkseg') {
		my @c;
		for my $trkpt ($trk_child->childNodes) {
		    next if $trkpt->nodeName ne 'trkpt';
		    my($x, $y) = $latlong2xy->($trkpt);
		    #my $ele = $wpt->findvalue(q{./ele});
		    #my $time = $wpt->findvalue(q{./time});
		    push @c, "$x,$y";
		}
		if (@c) {
		    local $^W = 0;
		    my $name = $get_name->($trk);
		    $self->push([$name, [@c], $def_cat]);
		}
	    }
	}
    }

    for my $rte ($root->childNodes) {
	next if $rte->nodeName ne "rte";
	my @c;
	for my $rte_child ($rte->childNodes) {
	    if ($rte_child->nodeName eq 'rtept') {
		my($x, $y) = $latlong2xy->($rte_child);
		push @c, "$x,$y";
	    }
	}
	if (@c) {
	    local $^W = 0;
	    my $name = $get_name->($rte);
	    $self->push([$name, [@c], $def_cat]);
	}
    }
}

sub _gpx2bbd_twig {
    my($self, $twig, %args) = @_;

    my $def_name = delete $args{name};
    my $def_cat  = delete $args{cat};
    if (!defined $def_cat) {
	$def_cat = "X";
    }
    my $fallback_name = delete $args{fallbackname};
    my $latlong2xy = delete $args{latlong2xy};

    my $seen_name; # used to remember the <name> element while parsing

    my $get_name = sub {
	my $name;
	if (defined $def_name) {
	    $name = $def_name;
	} else {
	    if (defined $seen_name) {
		$name = $seen_name;
	    } elsif (defined $fallback_name) {
		$name = $fallback_name;
	    } else {
		$name = '';
	    }
	}
	$name;
    };

    my($root) = $twig->children;
    for my $wpt_or_trk ($root->children) {
	if ($wpt_or_trk->name eq 'wpt') {
	    my $wpt = $wpt_or_trk;
	    undef $seen_name;
	    my($x, $y) = $latlong2xy->($wpt);
	    if (!defined $def_name) {
		for my $name_node ($wpt->children) {
		    next if $name_node->name ne "name";
		    $seen_name = $name_node->children_text;
		    last;
		}
	    }
	    my $name = $get_name->();
	    $self->push([$name, ["$x,$y"], $def_cat]);
	} elsif ($wpt_or_trk->name eq 'trk') {
	    my $trk = $wpt_or_trk;
	    undef $seen_name;
	    for my $trk_child ($trk->children) {
		if ($trk_child->name eq 'name' && !defined $def_name) {
		    $seen_name = $trk_child->children_text;
		} elsif ($trk_child->name eq 'trkseg') {
		    my @c;
		    for my $trkpt ($trk_child->children) {
			next if $trkpt->name ne 'trkpt';
			my($x, $y) = $latlong2xy->($trkpt);
			push @c, "$x,$y";
		    }
		    if (@c) {
			my $name = $get_name->();
			$self->push([$name, [@c], $def_cat]);
		    }
		}
	    }
	} elsif ($wpt_or_trk->name eq 'rte') {
	    my $rte = $wpt_or_trk;
	    undef $seen_name;
	    my @c;
	    for my $rte_child ($rte->children) {
		if ($rte_child->name eq 'name' && !defined $def_name) {
		    $seen_name = $rte_child->children_text;
		} elsif ($rte_child->name eq 'rtept') {
		    my($x, $y) = $latlong2xy->($rte_child);
		    push @c, "$x,$y";
		}
	    }
	    if (@c) {
		my $name = $get_name->();
		$self->push([$name, [@c], $def_cat]);
	    }
	}
    }
}

######################################################################
# BBD to GPX
#
sub bbd2gpx {
    my($self, %args) = @_;

    my $xy2longlat = \&xy2longlat;
    my $map = $self->get_global_directive("map");
    if ($map && $map eq 'polar') {
	$xy2longlat = \&longlat2longlat;
    }
    $args{xy2longlat} = $xy2longlat;

    if (!exists $args{-name}) {
	my $title = $self->get_global_directive('title');
	if (defined $title) {
	    $args{-name} = $title;
	}
    }

    if ($use_xml_module eq 'XML::LibXML') {
	_require_XML_LibXML;
	$self->_bbd2gpx_libxml(%args);
    } else {
	_require_XML_Twig;
	$self->_bbd2gpx_twig(%args);
    }
}

sub _bbd2gpx_libxml {
    my($self, %args) = @_;
    my $xy2longlat = delete $args{xy2longlat};
    my $meta = delete $args{-meta} || {};
    my $as = delete $args{-as} || 'track';
    $meta->{name} = delete $args{-name} if exists $args{-name};
    $meta->{number} = delete $args{-number} if exists $args{-number};
    my $with_trip_extensions = delete $args{-withtripext};

    my $has_encode = eval { require Encode; 1 };
    if (!$has_encode) {
	warn "WARN: No Encode.pm module available, non-ascii characters may be broken...\n";
    }
    my $has_utf8_upgrade = $] >= 5.008;


    $self->init;
    my @wpt;
    my @trkseg;
    while(1) {
	my $r = $self->next;
	last if !@{ $r->[Strassen::COORDS] };
	my $name = $r->[Strassen::NAME];
	if ($has_utf8_upgrade) {
	    utf8::upgrade($name); # This smells like an XML::LibXML bug
	}
	if (@{ $r->[Strassen::COORDS] } == 1) {
	    push @wpt,
		{
		 name => $name,
		 coords => [ $xy2longlat->($r->[Strassen::COORDS][0]) ],
		};
	} elsif ($as eq 'route') {
	    my $i = 0;
	    push @wpt,
		map {
		    +{
		      name => $name.$i++,
		      coords => [ $xy2longlat->($_) ]
		     }
		} @{ $r->[Strassen::COORDS] };
	} else {
	    push @trkseg,
		{
		 name => $name,
		 coords => [ map { [ $xy2longlat->($_) ] } @{ $r->[Strassen::COORDS] } ],
		};
	}
    }

    my $dom = XML::LibXML::Document->new('1.0', 'utf-8');
    my $gpx = $dom->createElement("gpx");
    $dom->setDocumentElement($gpx);
    $gpx->setAttribute("version", "1.1");
    $gpx->setAttribute("creator", "Strassen::GPX $VERSION (XML::LibXML $XML::LibXML::VERSION) - http://www.bbbike.de");
    $gpx->setNamespace("http://www.w3.org/2001/XMLSchema-instance","xsi");
    my $schema_location = "http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd";
    if ($with_trip_extensions) {
	$gpx->setNamespace(TRIP_EXT_NS, 'trp');
	$schema_location .= ' ' . TRIP_EXT_NS . ' http://www.garmin.com/xmlschemas/TripExtensionsv1.xsd';
    }
    $gpx->setAttribute("xsi:schemaLocation", $schema_location);
    $gpx->setNamespace("http://www.topografix.com/GPX/1/1"); # should be the last setNamespace call

    if ($as eq 'route') {
	my $rtexml = $gpx->addNewChild(undef, "rte");
	_add_meta_attrs_libxml($rtexml, $meta);
	for my $wpt_i (0 .. $#wpt) {
	    my $wpt = $wpt[$wpt_i];
	    my $rteptxml = $rtexml->addNewChild(undef, "rtept");
	    $rteptxml->setAttribute("lat", $wpt->{coords}[1]);
	    $rteptxml->setAttribute("lon", $wpt->{coords}[0]);
	    $rteptxml->appendTextChild("name", $wpt->{name});
	    if ($with_trip_extensions) {
		my $ext = $rteptxml->addNewChild(undef, 'extensions');
		if ($wpt_i != 0 && $wpt_i != $#wpt) {
		    $ext->addNewChild(TRIP_EXT_NS, 'ShapingPoint');
		} else {
		    $ext->addNewChild(TRIP_EXT_NS, 'ViaPoint');
		}
	    }
	}
    } else {
	for my $wpt (@wpt) {
	    my $wptxml = $gpx->addNewChild(undef, "wpt");
	    $wptxml->setAttribute("lat", $wpt->{coords}[1]);
	    $wptxml->setAttribute("lon", $wpt->{coords}[0]);
	    $wptxml->appendTextChild("name", $wpt->{name});
	}
	my $trkseg_counter = 1;
	while (@trkseg) {
	    my $trkxml = $gpx->addNewChild(undef, "trk");
	    my $name = _get_name_for_trk(\@trkseg, $trkseg_counter, $meta, $as);
	    _add_meta_attrs_libxml($trkxml, {%$meta, name => $name});
	    while (@trkseg) {
		my $trkseg = shift @trkseg; $trkseg_counter++;
		my $trksegxml = $trkxml->addNewChild(undef, "trkseg");
		for my $wpt (@{ $trkseg->{coords} }) {
		    my $trkptxml = $trksegxml->addNewChild(undef, "trkpt");
		    $trkptxml->setAttribute("lat", $wpt->[1]);
		    $trkptxml->setAttribute("lon", $wpt->[0]);
		}
		last if $as eq 'multi-tracks';
	    }
	}
    }
    if ($XML::LibXML::VERSION < 1.63 && $has_encode) {
	Encode::encode("utf-8", $dom->toString);
    } else {
	$dom->toString;
    }
}

sub _bbd2gpx_twig {
    my($self, %args) = @_;
    my $xy2longlat = delete $args{xy2longlat};
    my $meta = delete $args{-meta} || {};
    my $as = delete $args{-as} || 'track';
    $meta->{name} = delete $args{-name} if exists $args{-name};
    $meta->{number} = delete $args{-number} if exists $args{-number};
    my $with_trip_extensions = delete $args{-withtripext};

    $self->init;
    my @wpt;
    my @trkseg;
    while(1) {
	my $r = $self->next;
	last if !@{ $r->[Strassen::COORDS] };
	my $name = $r->[Strassen::NAME];
	if (@{ $r->[Strassen::COORDS] } == 1) {
	    push @wpt, { name => $name,
			 coords => [ $xy2longlat->($r->[Strassen::COORDS][0]) ],
		       };
	} else {
	    push @trkseg,
		{
		 name => $name,
		 coords => [ map { [ $xy2longlat->($_) ] } @{ $r->[Strassen::COORDS] } ],
		};
	}
    }

    if (!defined $meta->{name} && @trkseg && $as ne 'multi-tracks') {
	$meta->{name} = make_name_from_trkseg(\@trkseg);
    }

    my $twig = XML::Twig->new(output_encoding => 'utf-8');
    my $gpx = XML::Twig::Elt->new(gpx => { version => "1.1",
					   creator => "Strassen::GPX $VERSION (XML::Twig $XML::Twig::VERSION) - http://www.bbbike.de",
					   xmlns => "http://www.topografix.com/GPX/1/1",
					   #$gpx->setNamespace("http://www.w3.org/2001/XMLSchema-instance","xsi");
					   #"xsi:schemaLocation" => "http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd",
					   'xmlns:trp' => TRIP_EXT_NS,
					 },
				 );
    $twig->set_root($gpx);

    if ($as eq 'route') {
	my $rtexml = XML::Twig::Elt->new("rte");
	$rtexml->paste(last_child => $gpx);
	_add_meta_attrs_twig($rtexml, $meta);
	for my $wpt_i (0 .. $#wpt) {
	    my $wpt = $wpt[$wpt_i];
	    my $rteptxml = XML::Twig::Elt->new("rtept", {lat => $wpt->{coords}[1],
							 lon => $wpt->{coords}[0],
							},
					      );
	    $rteptxml->paste(last_child => $rtexml);
	    my $namexml = XML::Twig::Elt->new("name", {}, $wpt->{name});
	    $namexml->paste(last_child => $rteptxml);
	    if ($with_trip_extensions) {
		my $ext = XML::Twig::Elt->new('extensions');
		$ext->paste(last_child => $rteptxml);
		if ($wpt_i != 0 && $wpt_i != $#wpt) {
		    my $shppnt = XML::Twig::Elt->new('trp:ShapingPoint');
		    $shppnt->paste(last_child => $ext);
		} else {
		    my $viapnt = XML::Twig::Elt->new('trp:ViaPoint');
		    $viapnt->paste(last_child => $ext);
		}
	    }
	}
    } else {
	for my $wpt (@wpt) {
	    my $wptxml = XML::Twig::Elt->new("wpt", {lat => $wpt->{coords}[1],
						     lon => $wpt->{coords}[0],
						    },
					    );
	    $wptxml->paste(last_child => $gpx);
	    my $namexml = XML::Twig::Elt->new("name", {}, $wpt->{name});
	    $namexml->paste(last_child => $wptxml);
	}
	my $trkseg_counter = 1;
	while (@trkseg) {
	    my $trkxml = XML::Twig::Elt->new("trk");
	    my $name = _get_name_for_trk(\@trkseg, $trkseg_counter, $meta, $as);
	    _add_meta_attrs_twig($trkxml, {%$meta, name => $name});
	    $trkxml->paste(last_child => $gpx);
	    while (@trkseg) {
		my $trkseg = shift @trkseg; $trkseg_counter++;
		my $trksegxml = XML::Twig::Elt->new("trkseg");
		$trksegxml->paste(last_child => $trkxml);
		for my $wpt (@{ $trkseg->{coords} }) {
		    my $trkptxml = XML::Twig::Elt->new("trkpt", { lat => $wpt->[1],
								  lon => $wpt->[0],
								});
		    $trkptxml->paste(last_child => $trksegxml);
		}
		last if $as eq 'multi-tracks';
	    }
	}
    }
    my $xml = $twig->sprint;
    $xml;
}

######################################################################
# Helpers

sub latlong2xy {
    my($node) = @_;
    my $lat = $node->getAttribute('lat');
    my $lon = $node->getAttribute('lon');
    my($x, $y) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($lon, $lat));
    ($x, $y);
}

sub latlong2longlat {
    my($node) = @_;
    my $lat = $node->getAttribute('lat');
    my $lon = $node->getAttribute('lon');
    ($lon, $lat);
}

sub latlong2xy_twig {
    my($node) = @_;
    my $lat = $node->att("lat");
    my $lon = $node->att("lon");
    my($x, $y) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($lon, $lat));
    ($x, $y);
}

sub latlong2longlat_twig {
    my($node) = @_;
    my $lat = $node->att("lat");
    my $lon = $node->att("lon");
    ($lon, $lat);
}

sub xy2longlat {
    my($c) = @_;
    my($lon, $lat) = $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map(split /,/, $c));
    ($lon, $lat);
}

sub longlat2longlat {
    my($c) = @_;
    my($lon, $lat) = split /,/, $c;
    ($lon, $lat);
}

sub make_name_from_trkseg {
    my($trkseg_ref) = @_;

    my $name_from = $trkseg_ref->[0]->{name};
    my $name_to   = $trkseg_ref->[-1]->{name};
    my $name = $name_from;
    if ($name_from ne $name_to) {
	$name .= " - $name_to";
    }
    $name;
}

sub _get_name_for_trk {
    my($trksegs, $trkseg_counter, $meta, $as) = @_;
    return $meta->{name} if defined $meta->{name};
    if ($as eq 'track') {
	make_name_from_trkseg($trksegs);
    } elsif ($as eq 'multi-tracks') {
	my $name = $trksegs->[0]->{name};
	if (!$name) {
	    $name = "Track $trkseg_counter";
	}
	$name;
    } else {
	warn "Should not happen: as=$as";
    }
}

sub _add_meta_attrs_libxml {
    my($node, $meta) = @_;
    for my $attr (@COMMON_META_ATTRS) {
	if (defined $meta->{$attr}) {
	    if ($attr eq 'link') {
		if (!defined $meta->{link}{href}) {
		    die "meta->link->href is required if meta->link is given";
		}
		my $linknode = $node->addNewChild(undef, "link");
		$linknode->appendTextChild("text", $meta->{link}{text}) if defined $meta->{link}{text};
		$linknode->appendTextChild("type", $meta->{link}{type}) if defined $meta->{link}{type};
		$linknode->setAttribute("href", $meta->{link}{href});
	    } else {
		$node->appendTextChild($attr, $meta->{$attr});
	    }
	}
    }
}

sub _add_meta_attrs_twig {
    my($node, $meta) = @_;
    for my $attr (@COMMON_META_ATTRS) {
	if (defined $meta->{$attr}) {
	    if ($attr eq 'link') {
		if (!defined $meta->{link}{href}) {
		    die "meta->link->href is required if meta->link is given";
		}
		my $linknode = XML::Twig::Elt->new("link", {href => $meta->{link}{href}});
		$linknode->paste(last_child => $node);
		if (defined $meta->{link}{text}) {
		    my $textnode = XML::Twig::Elt->new("text", {}, $meta->{link}{text});
		    $textnode->paste(last_child => $linknode);
		}
		if (defined $meta->{link}{type}) {
		    my $typenode = XML::Twig::Elt->new("type", {}, $meta->{link}{type});
		    $typenode->paste(last_child => $linknode);
		}
	    } else {
		my $newnode = XML::Twig::Elt->new($attr, {}, $meta->{$attr});
		$newnode->paste(last_child => $node);
	    }
	}
    }
}

1;

__END__

=head1 NAME

Strassen::GPX - convert between bbd and gpx formats

=head1 SYNOPSIS

Read a gpx file:

    use Strassen::GPX;
    my $s = Strassen::GPX->new;
    $s->gpx2bbd("/path/to/file.gpx");

Alternatively:

    use Strassen::GPX;
    my $s = Strassen::GPX->new("/path/to/file.gpx");

Read a bbd file and dump it as gpx:

    use Strassen::GPX;
    my $s = Strassen->new("/path/to/file.bbd");
    my $gpx = $s->bbd2gpx;

=head1 DESCRIPTION

L<Strassen::GPX> may be used to read C<.gpx> files into
C<Strassen>-compatible objects, or to dump C<Strassen>-compatible
objects as C<.gpx> files.

=head2 bbd2gpx

This method would create a gpx file where one-point bbd records are
converted into C<< <wpt> >> (waypoint) elements, and multi-point bbd
records are converted into C<< <trk> >> (track) elements, or C<< <rte>
>> (route) elements if the C<-as> option is set (see below).

Takes the following named parameters:

=over

=item C<< -meta => {...} >>

A hash which can contain the following keys: C<name>, C<cmt>, C<desc>,
C<src>, C<link>, C<number>, and C<type>. These would used for creating
the same-named elements in C<rte> or C<trk> elements. See below for
the C<-number> and C<-name> options, too.

=item C<< -name => ... >>

Set the value for the C<< <name> >> element in tracks and routes. This
takes precedence over the definition in C<-meta>.

If the name is not given, then the module tries a number of fallbacks:

=over

=item * the value of the global directive C<title>

=item * for track only: the name will be constructed from names of the
first and last bbd records, creating something like "Start - Goal"

=item * for multi-tracks only: the name will be constructed from 
"Track " and a counter starting at 1

=back

=item C<< -number => ... >>

Set the C<< <number> >> element; takes precedence over the C<-meta>
definition.

=item C<< -as => 'track' >>

If creating tracks, then create a single C<< <trk> >> element with
possibly multiple C<< <trkseg> >> elements. This is the default.

One-point records are not affected by this option and are created as
C<< <wpt> >> elements.

=item C<< -as => 'route' >>

Instead of creating tracks, create routes.

=item C<< -as => 'multi-tracks' >>

Instead of creating one C<< <trk> >> with multiple C<< <trkseg> >>
elements, create multiple C<< <trk> >> elements with one
C<< <trkseg> >> element each.

=item C<< -withtripext => $bool >>

Create C<ShapingPoint> and C<ViaPoint> elements for Garmin's trip
extensions.

=back

=head2 gpx2bbd

Parses the given C<.gpx> file into the object. Waypoints are converted
into one-coordinate bbd records, track and route segments are
converted into multi-coordinate bbd records.

Takes the following named parameters:

=over

=item C<< -name => ... >>

Force the use of the given name for the created bbd records,
overriding existing C<< <name> >> definitions in the C<.gpx> file.

=item C<< -fallbackname => ... >>

Use this name only if C<< <name> >> is missing for the feature in the
C<.gpx> file.

=item C<< -cat => ... >>

Define the category for the created bbd records. If not given, then
C<X> is used.

=back

=head2 IMPLEMENTATION NOTES

L<Strassen::GPX> may use L<XML::LibXML> or L<XML::Twig> to do the XML
parsing and creation work. By default, C<XML::LibXML> is preferred
over C<XML::Twig>. To force an implementation, set
C<$Strassen::GPX::use_xml_module> to one of the both XML package
names.

C<XML::Twig> running on older perls (< 5.16.0) has problems with
larger documents and may even segfault.

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<Strassen::Core>, L<XML::LibXML>, L<XML::Twig>.

=cut
