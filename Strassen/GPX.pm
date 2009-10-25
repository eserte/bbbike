# -*- perl -*-

#
# $Id: GPX.pm,v 1.22 2008/11/06 22:06:07 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::GPX;

use strict;
use vars qw($VERSION @ISA);
$VERSION = sprintf("%d.%02d", q$Revision: 1.22 $ =~ /(\d+)\.(\d+)/);

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
    # Downside:
    # * XML::Twig has additional support for gracefully drop encoding to
    #   avoid using utf-8 or iso-8859-1 if possible
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

sub new {
    my($class, $filename_or_object, %args) = @_;
    if (UNIVERSAL::isa($filename_or_object, "Strassen")) {
	bless $filename_or_object, $class;
    } else {
	my $self = {};
	bless $self, $class;

	if ($filename_or_object) {
	    my $name = delete $args{name};
	    my $cat  = delete $args{cat};
	    $self->gpx2bbd($filename_or_object, name => $name, cat => $cat);
	}

	$self;
    }
}

######################################################################
# GPX to BBD
#
sub gpx2bbd {
    my($self, $file, %args) = @_;
    
    if ($use_xml_module eq 'XML::LibXML') {
	_require_XML_LibXML;
	my $p = XML::LibXML->new;
	my $doc = $p->parse_file($file);
	$self->_gpx2bbd_libxml($doc, %args);
    } else {
	_require_XML_Twig;
	my $twig = XML::Twig->new;
	$twig->parsefile($file);
	$self->_gpx2bbd_twig($twig, %args);
    }
}

sub gpxdata2bbd {
    my($self, $data, %args) = @_;

    if ($use_xml_module eq 'XML::LibXML') {
	_require_XML_LibXML;
	my $p = XML::LibXML->new;
	my $doc = $p->parse_string($data);
	$self->_gpx2bbd_libxml($doc, %args);
    } else {
	_require_XML_Twig;
	my $twig = XML::Twig->new;
	$twig->parse($data);
	$self->_gpx2bbd_twig($twig, %args);
    }
}

sub _gpx2bbd_libxml {
    my($self, $doc, %args) = @_;

    my $def_name = delete $args{name};
    my $def_cat  = delete $args{cat};
    if (!defined $def_cat) {
	$def_cat = "X";
    }

    my $root = $doc->documentElement;

    for my $wpt ($root->childNodes) {
	next if $wpt->nodeName ne "wpt";
	my($x, $y) = latlong2xy($wpt);
	my $name;
	if (defined $def_name) {
	    $name = $def_name;
	} else {
	    $name = "";
	    for my $name_node ($wpt->childNodes) {
		next if $name_node->nodeName ne "name";
		$name = $name_node->textContent;
		last;
	    }
	}
	$self->push([$name, ["$x,$y"], $def_cat]);
    }

    for my $trk ($root->childNodes) {
	next if $trk->nodeName ne "trk";
	my $name = $def_name;
	for my $trk_child ($trk->childNodes) {
	    if ($trk_child->nodeName eq 'name' && !defined $name) {
		$name = $trk_child->textContent;
	    } elsif ($trk_child->nodeName eq 'trkseg') {
		my @c;
		for my $trkpt ($trk_child->childNodes) {
		    next if $trkpt->nodeName ne 'trkpt';
		    my($x, $y) = latlong2xy($trkpt);
		    #my $ele = $wpt->findvalue(q{./ele});
		    #my $time = $wpt->findvalue(q{./time});
		    push @c, "$x,$y";
		}
		if (@c) {
		    local $^W = 0;
		    $self->push([$name, [@c], $def_cat]);
		}
	    }
	}
    }

    for my $rte ($root->childNodes) {
	next if $rte->nodeName ne "rte";
	my $name = $def_name;
	my @c;
	for my $rte_child ($rte->childNodes) {
	    if ($rte_child->nodeName eq 'name' && !defined $name) {
		$name = $rte_child->textContent;
	    } elsif ($rte_child->nodeName eq 'rtept') {
		my($x, $y) = latlong2xy($rte_child);
		push @c, "$x,$y";
	    }
	}
	if (@c) {
	    local $^W = 0;
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

    my($root) = $twig->children;
    for my $wpt_or_trk ($root->children) {
	if ($wpt_or_trk->name eq 'wpt') {
	    my $wpt = $wpt_or_trk;
	    my($x, $y) = latlong2xy_twig($wpt);
	    my $name;
	    if (defined $def_name) {
		$name = $def_name;
	    } else {
		$name = "";
		for my $name_node ($wpt->children) {
		    next if $name_node->name ne "name";
		    $name = $name_node->children_text;
		    last;
		}
	    }
	    $self->push([$name, ["$x,$y"], $def_cat]);
	} elsif ($wpt_or_trk->name eq 'trk') {
	    my $trk = $wpt_or_trk;
	    my $name = $def_name;
	    for my $trk_child ($trk->children) {
		if ($trk_child->name eq 'name' && !defined $name) {
		    $name = $trk_child->children_text;
		} elsif ($trk_child->name eq 'trkseg') {
		    my @c;
		    for my $trkpt ($trk_child->children) {
			next if $trkpt->name ne 'trkpt';
			my($x, $y) = latlong2xy_twig($trkpt);
			push @c, "$x,$y";
		    }
		    if (@c) {
			$self->push([$name, [@c], $def_cat]);
		    }
		}
	    }
	} elsif ($wpt_or_trk->name eq 'rte') {
	    my $rte = $wpt_or_trk;
	    my $name = $def_name;
	    my @c;
	    for my $rte_child ($rte->children) {
		if ($rte_child->name eq 'name' && !defined $name) {
		    $name = $rte_child->children_text;
		} elsif ($rte_child->name eq 'rtept') {
		    my($x, $y) = latlong2xy_twig($rte_child);
		    push @c, "$x,$y";
		}
	    }
	    if (@c) {
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
    my $name = delete $args{-name};
    my $number = delete $args{-number};

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

    if (!defined $meta->{name} && @trkseg) {
	$meta->{name} = make_name_from_trkseg(\@trkseg);
    }

    my $dom = XML::LibXML::Document->new('1.0', 'utf-8');
    my $gpx = $dom->createElement("gpx");
    $dom->setDocumentElement($gpx);
    $gpx->setAttribute("version", "1.1");
    $gpx->setAttribute("creator", "Strassen::GPX $VERSION (XML::LibXML $XML::LibXML::VERSION) - http://www.bbbike.de");
    $gpx->setNamespace("http://www.w3.org/2001/XMLSchema-instance","xsi");
    $gpx->setNamespace("http://www.topografix.com/GPX/1/1");
    $gpx->setAttribute("xsi:schemaLocation", "http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd");

    if ($as eq 'route') {
	my $rtexml = $gpx->addNewChild(undef, "rte");
	_add_meta_attrs_libxml($rtexml, $meta);
	$rtexml->appendTextChild('name', $name) if defined $name && $name ne '';
	$rtexml->appendTextChild('number', $number) if defined $number && $number ne '';
	for my $wpt (@wpt) {
	    my $rteptxml = $rtexml->addNewChild(undef, "rtept");
	    $rteptxml->setAttribute("lat", $wpt->{coords}[1]);
	    $rteptxml->setAttribute("lon", $wpt->{coords}[0]);
	    $rteptxml->appendTextChild("name", $wpt->{name});
	}
    } else {
	for my $wpt (@wpt) {
	    my $wptxml = $gpx->addNewChild(undef, "wpt");
	    $wptxml->setAttribute("lat", $wpt->{coords}[1]);
	    $wptxml->setAttribute("lon", $wpt->{coords}[0]);
	    $wptxml->appendTextChild("name", $wpt->{name});
	}
	if (@trkseg) {
	    my $trkxml = $gpx->addNewChild(undef, "trk");
	    _add_meta_attrs_libxml($trkxml, $meta);
	    $trkxml->appendTextChild('name', $name) if defined $name && $name ne '';
	    $trkxml->appendTextChild('number', $number) if defined $number && $number ne '';
	    for my $trkseg (@trkseg) {
		my $trksegxml = $trkxml->addNewChild(undef, "trkseg");
		for my $wpt (@{ $trkseg->{coords} }) {
		    my $trkptxml = $trksegxml->addNewChild(undef, "trkpt");
		    $trkptxml->setAttribute("lat", $wpt->[1]);
		    $trkptxml->setAttribute("lon", $wpt->[0]);
		}
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

    # Try to find minimum needed encoding. This is to help
    # broken applications (wrt correct XML parsing) like gpsman 6.3.2
    my $need_utf8;
    my $need_latin1;
    my $encoding_checker = ($] >= 5.008 ? eval <<'EOF' :
sub {
    my $name = shift;
    if (!$need_utf8) {
	if ($name =~ m{[\x{0100}-\x{1ffff}]}) {
	    $need_utf8 = 1;
	} elsif (!$need_latin1) {
	    if ($name =~ m{[\x80-\xff]}) {
		$need_latin1 = 1;
	    }
	}
    }
}
EOF
			    sub { } # no/limited unicode support with older perls
			   );

    $self->init;
    my @wpt;
    my @trkseg;
    while(1) {
	my $r = $self->next;
	last if !@{ $r->[Strassen::COORDS] };
	my $name = $r->[Strassen::NAME];
	$encoding_checker->($name);
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

    if (!defined $meta->{name} && @trkseg) {
	$meta->{name} = make_name_from_trkseg(\@trkseg);
    }

    my $twig = XML::Twig->new($need_utf8   ? (output_encoding => 'utf-8') :
			      $need_latin1 ? (output_encoding => 'iso-8859-1') :
			      ()
			     );
    my $gpx = XML::Twig::Elt->new(gpx => { version => "1.1",
					   creator => "Strassen::GPX $VERSION (XML::Twig $XML::Twig::VERSION) - http://www.bbbike.de",
					   xmlns => "http://www.topografix.com/GPX/1/1",
					   #$gpx->setNamespace("http://www.w3.org/2001/XMLSchema-instance","xsi");
					   #"xsi:schemaLocation" => "http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd",
					 },
				 );
    $twig->set_root($gpx);

    if ($args{-as} && $args{-as} eq 'route') {
	my $rtexml = XML::Twig::Elt->new("rte");
	$rtexml->paste(last_child => $gpx);
	_add_meta_attrs_twig($rtexml, $meta);
	for my $wpt (@wpt) {
	    my $rteptxml = XML::Twig::Elt->new("rtept", {lat => $wpt->{coords}[1],
							 lon => $wpt->{coords}[0],
							},
					      );
	    $rteptxml->paste(last_child => $rtexml);
	    my $namexml = XML::Twig::Elt->new("name", {}, $wpt->{name});
	    $namexml->paste(last_child => $rteptxml);
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
	if (@trkseg) {
	    my $trkxml = XML::Twig::Elt->new("trk");
	    $trkxml->paste(last_child => $gpx);
	    _add_meta_attrs_twig($trkxml, $meta);
	    for my $trkseg (@trkseg) {
		my $trksegxml = XML::Twig::Elt->new("trkseg");
		$trksegxml->paste(last_child => $trkxml);
		for my $wpt (@{ $trkseg->{coords} }) {
		    my $trkptxml = XML::Twig::Elt->new("trkpt", { lat => $wpt->[1],
								  lon => $wpt->[0],
								});
		    $trkptxml->paste(last_child => $trksegxml);
		}
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

sub latlong2xy_twig {
    my($node) = @_;
    my $lat = $node->att("lat");
    my $lon = $node->att("lon");
    my($x, $y) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($lon, $lat));
    ($x, $y);
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
