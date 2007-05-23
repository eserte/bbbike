# -*- perl -*-

#
# $Id: BBBikeESRI.pm,v 1.15 2007/05/23 21:08:59 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeESRI;
use strict;
use ESRI::Shapefile;

sub null_conv {
    map {
	#warn "$_->[0],$_->[1]\n";
	join(",", $_->[0], $_->[1]);
    } @{ $_[0] }
}

######################################################################

package ESRI::Shapefile;

use vars qw($VERBOSE);

sub as_bbd {
    my $self = shift;
    my(%args) = @_;

    # output filehandle or string
    my $outfh = $args{-outfh};
    my $s = "";
    if (!$outfh) {
	eval q{open($outfh, ">", \$s) or die "Can't write to scalar variable: $!"};
	if ($@) {
	    warn $@;
	    require IO::Scalar;
	    $outfh = new IO::Scalar \$s;
	}
    }

    $self->Main->init(-nopreload => 1, -force => 1);

    my $conv = $args{-conv};

    if ($args{-autoconv}) {
	my $hdr = $self->Main->Header;
	my $bbox = $hdr->BoundingBox;
	my($cx,$cy) = (($bbox->{Xmax}+$bbox->{Xmin})/2,
		       ($bbox->{Ymax}+$bbox->{Ymin})/2);
	$conv = sub {
	    # Internal note: 8500/12000 is the offset from Kleinmachnow
	    # to Brandenburger Tor
	    map {
		sprintf "%d,%d", $_->[0] - $cx + 8500, $_->[1] - $cy + 12000;
	    } @{ $_[0] }
	}
    }

    if (!$conv) {
	$conv = \&BBBikeESRI::null_conv;
    }

    my $get_name;
    if ($args{-dbfinfo}) {
	$self->DBase->init; # XXX (-nopreload => 1);
    }
    if (defined $args{-getname} && ref $args{-getname} eq 'CODE') {
	$get_name = $args{-getname};
    } elsif (defined $args{-dbfinfo} && $args{-dbfinfo} eq 'NAME') {
	if (defined $args{-dbfcol}) {
	    my $col = $args{-dbfcol};
	    $get_name = sub { ($self->DBase->Data->[$_[0]] ?
			       $self->DBase->Data->[$_[0]]->[$col] :
			       "Index $_[0]")
			  };
	} else {
	    $get_name = sub { ($self->DBase->Data->[$_[0]] ?
			       join(":", @{ $self->DBase->Data->[$_[0]] }) :
			       "Index $_[0]")
			  };
	}
    }

    my $get_cat;
    if ($args{-getcat} && ref $args{-getcat} eq 'CODE') {
	$get_cat = $args{-getcat};
    }

    my $handle_all;
    if ($args{-handleall} && ref $args{-handleall} eq 'CODE') {
	# in:  row index, coordinates
	# out: name, category, coordinates ref (or empty list to skip)
	$handle_all = $args{-handleall};
    }

    my $afterhook;
    if ($args{-afterhook} && ref $args{-afterhook} eq 'CODE') {
	# in:  row index, coordinates
	$afterhook = $args{-afterhook};
    }

    my $inx = 0;
    while(defined(my $record = $self->Main->next_record)) {
	if ($handle_all) {
	    my @coords;
	    if ($record->isa("ESRI::Shapefile::Main::Record::Polygon")) {
		@coords = @{ $record->Areas }; # XXX correct?
	    } elsif ($record->isa("ESRI::Shapefile::Main::Record::Point")) {
		@coords = [$record->Point];
	    } elsif ($record->isa("ESRI::Shapefile::Main::Record::Null")) {
		next;
	    } else {
		@coords = @{ $record->Lines };
	    }
	    @coords = map { $conv->($_) } @coords;
	    my(@res) = $handle_all->($inx, \@coords);
	    if (@res) {
		print $outfh "$res[0]\t$res[1] " . join(" ", @{$res[2]}) . "\n";
	    }
	    _call_afterhook($afterhook, $inx, \@coords);
	} else {
	    my($name,$cat);
	    eval {
		$name = $get_name ? $get_name->($inx) : "$inx";
		$cat  = $get_cat  ? $get_cat->($inx)  : "?";
	    };
	    if ($@) {
		warn $@ if $VERBOSE;
		next;
	    }
	    if ($record->isa("ESRI::Shapefile::Main::Record::Polygon")) {
		if (!$args{-forcelines}) {
		    $cat = "F:red"; # XXX use $get_cat??? or $get_area_cat?
		}
		foreach my $a (@{ $record->Areas }) {
		    my @coords = $conv->($a);
		    print $outfh "$name\t$cat " . join(" ", @coords) . "\n";
		    _call_afterhook($afterhook, $inx, \@coords);
		}
	    } elsif ($record->isa("ESRI::Shapefile::Main::Record::Null")) {
		next;
	    } else {
		my @coords;
		if ($record->isa("ESRI::Shapefile::Main::Record::Point")) {
		    @coords = $conv->([$record->Point]);
		} else {
		    @coords = map { $conv->($_) } @{ $record->Lines };
		}
		print $outfh "$name\t$cat " . join(" ", @coords) . "\n";
		_call_afterhook($afterhook, $inx, \@coords);
	    }
	}
    } continue {
	$inx++;
    }

    if ($s ne "") {
	return $s;
    }
}

sub as_attribute_bbd {
    my $self = shift;
    my(%args) = @_;

    $self->Main->init(-nopreload => 1, -force => 1);

    my $s = "";

    my $conv = $args{-conv} || \&BBBikeESRI::null_conv;
    my $q = defined $args{-quiet} ? $args{-quiet} : 1;

    $self->DBase->init; # XXX (-nopreload => 1);
    my $dbdata = $self->DBase->Data;

    my $sep = $args{-separator} || ',';
    my $seprx = quotemeta($sep);

    my $cat = "X"; # not used
    my $restrict = $args{-restrict};
    my $check_street_length = $args{-checkstreetlength};
    my $street_length_index = $args{-streetlengthindex};

    my $handle_all = sub {
	my($inx, $coords_ref) = @_;
	my $name = join($sep, map {
	    if (/$seprx/) {
		s/$seprx/_/g;
		if (!$q) {
		    warn "Mask separator <$sep> in line <$_>" if $VERBOSE;
		}
	    }
	    $_;
	} ($restrict ? @{$dbdata->[$inx]}[@$restrict] : @{$dbdata->[$inx]}));

	# just testing street length
	if ($check_street_length) {
	    my $s = 0;
	    foreach my $c_i (1 .. $#$coords_ref) {
		$s += Strassen::Util::strecke_s($coords_ref->[$c_i-1],
						$coords_ref->[$c_i]);
	    }
	    my $delta = abs($s-$dbdata->[$inx][$street_length_index]);
	    if ($delta > 10) {
		warn "Suspicious delta <$delta m>, Index <$inx>, Record <@{$dbdata->[$inx]}>\n" if $VERBOSE;
	    }
	}

	($name, $cat, $coords_ref);
    };

    my $afterhook;
    if ($args{-afterhook} && ref $args{-afterhook} eq 'CODE') {
	# in:  row index, coordinates
	$afterhook = $args{-afterhook};
    }

    my $inx = 0;
    while(defined(my $record = $self->Main->next_record)) {
#    foreach my $record (@{ $self->Main->Records }) {
	my @coords;
	if ($record->isa("ESRI::Shapefile::Main::Record::Polygon")) {
	    @coords = @{ $record->Areas };
	} elsif ($record->isa("ESRI::Shapefile::Main::Record::Point")) {
	    @coords = [$record->Point];
	} elsif ($record->isa("ESRI::Shapefile::Main::Record::Null")) {
	    next;
	} else {
	    @coords = @{ $record->Lines };
	}
	@coords = map { $conv->($_) } @coords;
	my(@res) = $handle_all->($inx, \@coords);
	if (@res) {
	    $s.="$res[0]\t$res[1] " . join(" ", @{$res[2]}) . "\n";
	}
	_call_afterhook($afterhook, $inx, \@coords);
    } continue {
	$inx++;
    }
    $s;
}

sub dump_bbd {
    my($self, $outfile, %args) = @_;
    die "outfile not defined" if !defined $outfile;
    open(BBD, ">$outfile") or die "Can't write to $outfile: $!";
    if ($args{-preamble}) {
	$args{-preamble}->(\*BBD, $self, $outfile);
    }
    $args{-outfh} = \*BBD;
#    print BBD $self->as_bbd(%args);
    $self->as_bbd(%args);
    if ($args{-postamble}) {
	$args{-postamble}->(\*BBD, $self, $outfile);
    }
    close BBD;
}

sub _call_afterhook {
    my($afterhook, $inx, $coordref) = @_;
    if ($afterhook) {
	$afterhook->($inx, \@$coordref);
    }
}

######################################################################

package ESRI::Shapefile::DBase;

sub merge_with_bbd {
    my($self, $bbdfile, $outfile) = @_;

    require Strassen;

    my $sth = $self->_get_all_sth;

    open(IN, $bbdfile) or die "Can't open $bbdfile: $!";
    open(OUT, ">$outfile") or die "Can't write to $outfile: $!";

    my @row;
    while(@row = $sth->fetchrow_array) {
	my $l = scalar <IN>;
	if (!defined $l) {
	    die "Less data in bbd file $bbdfile than in " . $self->File;
	}
	my $ret = Strassen::parse($l);
	print OUT join(":", @row) . "\t" . $ret->[&Strassen::CAT] . " " . join(" ", @{ $ret->[&Strassen::COORDS] }), "\n";
    }

    if (defined <IN>) {
	die "More data in bbd file $bbdfile than in " . $self->File;
    }

    close IN;
    close OUT;

    $self->_finish_db;
}

1;

__END__
