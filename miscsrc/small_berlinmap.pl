#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: small_berlinmap.pl,v 2.16 2005/05/24 23:32:19 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998,2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net/
#

=head1 NAME

small_berlinmap.pl - create a small overview map of Berlin

=head1 SYNOPSIS

    ./small_berlinmap.pl [-width w] [-height h] [-normbg bgcolor]
                         [-includepotsdam] [-nogif] [-v [-v ...]]

=head1 DESCRIPTION

The default width and height are 200 pixels. The generated images will
be saved in the /tmp directory as berlin_small.gif (the normal
image) and berlin_small_hi.gif (the highlighted image). There will be
also PNG pictures generated (see L</BUGS> below). Also, some
parameters for transpose functions are printed to stdout.

The -normbg option sets the background color of the normal picture
(default: transparent).

With -includepotsdam the borders of Potsdam are also included.

With -nogif only the PNG images will be created.

=head1 OS DEPENDENCIES

=over 4

=item FreeBSD port: graphics/ImageMagick

=comment
=item FreeBSD port: graphics/giftrans

=item FreeBSD port: graphics/netpbm

=back

=head1 BUGS

-imagemagick geht nicht mehr: 

    Exception 410: no images to mogrify (Transparent) at /home/e/eserte/src/bbbike/miscsrc/../BBBikeDraw/ImageMagick.pm line 134.

Leider kann Netscape anscheinend keine transparenten PNGs darstellen ...
deshalb ist eine Konvertierung nach GIF erforderlich.

The fill center point for Potsdam is very rough and can lead to wrong
results.

=head1 AUTHOR

Slaven Rezic <eserte@users.sourceforge.net>

=head1 COPYRIGHT

Copyright (c) 1998,2001 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib", "$FindBin::RealBin/../data");
use BBBikeDraw;
use BBBikeUtil qw(is_in_path);
use Getopt::Long;
use strict;

my $img_w = 200;
my $img_h = 200;
my $normbg = 'transparent';
my $geometry;
my $includepotsdam;
my $use_imagemagick;
my $use_gif = 1;
my $use_xpm = 1;
my @strfiles = ('sbahn', 'ubahn', 'wasser');
my @border;
my $v = 0;

my @orig_ARGV = @ARGV;
if (!GetOptions("width=i" => \$img_w,
		"height=i" => \$img_h,
		"normbg=s" => \$normbg,
		"geometry=s" => \$geometry,
		"includepotsdam!" => \$includepotsdam,
		"strfiles=s" => sub { @strfiles = split /,/, $_[1] },
		"borderfiles=s" => sub { @border = split /,/, $_[1] },
		"imagemagick!" => \$use_imagemagick,
		"gif!" => \$use_gif,
		"xpm!" => \$use_xpm,
		"v+" => \$v,
	       )) {
    die "usage!";
}

if (defined $geometry) {
    if ($geometry !~ /^(\d+)x(\d+)$/) {
	die "Can't parse geometry string $geometry";
    }
    ($img_w, $img_h) = ($1, $2);
}

my %draw_args;
my %draw2_args = (Draw => [@strfiles, '!sbahnhof', '!ubahnhof']);
if ($img_w <= 50 || $img_h <= 50) {
    $draw_args{NoScale} = 1;
    $draw2_args{Draw} = [];
}
if ($use_imagemagick) {
    $draw_args{Module} = $draw2_args{Module} = "ImageMagick";
}

if (!@border) {
    @border = ('berlin');
    if ($includepotsdam) {
	push @border, 'potsdam';
    }
}

for my $type ('norm', 'hi') {
    my $base = "/tmp/berlin_small" . ($type eq 'hi' ? '_hi' : '');
    my $img     = "$base.png";
    my $img_gif = "$base.gif";
    my $img_xpm = "$base.xpm";
    my $img_dim = "$base.dim";
    open(IMG, ">$img") or die "Can't write $img: $!";
    print STDERR "# Creating $type ...\n" if $v;
    my($w, $h) = ($img_w, $img_h);
    my $draw = new BBBikeDraw
	Fh => \*IMG,
        Geometry => $w."x".$h,
	Draw => [@border],
	Bg => ($type eq 'hi' ? '#ffdead' : $normbg),
        FrontierColor => 'red',
	ImageType => 'png',
	%draw_args,
        ;
    $draw->set_bbox_max(new MultiStrassen @border);
    print "
my \$minx = $draw->{Min_x};
my \$maxx = $draw->{Max_x};
my \$miny = $draw->{Min_y};
my \$maxy = $draw->{Max_y}
\n" if $v >= 2;
    $draw->create_transpose(-asstring => 1);
    my $xm = ($draw->{Max_x}-$draw->{Min_x})/$w;
    my $ym = ($draw->{Max_y}-$draw->{Min_y})/$h;
    print "my \$xm = $xm;\nmy \$ym = $ym;\n\n" if $v >= 2;
#    warn join(", ", $draw->{Transpose}->($draw->{Min_x}, $draw->{Min_y}))."\n";
#    warn join(", ", $draw->{Transpose}->($draw->{Max_x}, $draw->{Max_y}))."\n";
    my($xx,$yy) = $draw->{Transpose}->($draw->{Min_x}, $draw->{Min_y});
#    warn join(", ", $draw->{AntiTranspose}->(0, 0))."\n";
#    warn join(", ", $draw->{AntiTranspose}->($img_w, $img_h))."\n";
    print "my \$transpose = $draw->{TransposeCode};\n" if $v >= 2;
    print "my \$anti_transpose = $draw->{AntiTransposeCode};\n\n" if $v >= 2;

    $draw->draw_map;
    my $gd_img = $draw->{Image};
    if ($type ne 'hi') {
	if ($draw->{Module} eq 'ImageMagick') {
	    $gd_img->ColorFloodfill(geometry=>'+'.($w/2).'+'.+($h/2),
				    fill=>$draw->get_color("white"));
	    if ($includepotsdam) {
		# XXX rough estimate to catch a point in Potsdam...
		$gd_img->ColorFloodfill(geometry=>'+'.($w/10).'+'.($h/4*3),
					fill=>$draw->get_color("white"));
	    }
	} else {
	    $gd_img->fill($w/2, $h/2, $draw->get_color("white"));
	    if ($includepotsdam) {
		# XXX rough estimate to catch a point in Potsdam...
		$gd_img->fill($w/10, $h/4*3, $draw->get_color("white"));
	    }
	}
    }

    {
	package BBBikeDraw::MyGD;
	use base qw(BBBikeDraw::GD);
	no strict;
	sub init {
	    my $self = shift;
	    # The following are just a hack ... no proper inheritance
	    # yet possible with BBBikeDraw::*
	    $self->{CategoryColors} = { %BBBikeDraw::GD::color };
	    $self->{CategoryOutlineColors} = { %BBBikeDraw::GD::outline_color };
	    $self->{CategoryWidths} = { %BBBikeDraw::GD::width };
	    $self->SUPER::init();
	}

	sub set_category_colors {
	    my($self, @args) = @_;
	    $self->SUPER::set_category_colors(@args);
	    # XXX ugly hack follows!
	    $BBBikeDraw::GD::color{I} = $self->{Bg} =~ /white/ ? $BBBikeDraw::GD::white : $BBBikeDraw::GD::grey_bg; # XXX why ::GD:: and not ::MyGD::
	}
    }

    my $draw2 = new BBBikeDraw
        Module => 'MyGD',
	OldImage => $gd_img,
	Fh => \*IMG,
        Geometry => $w."x".$h,
	ImageType => 'png',
	%draw2_args,
	Bg => ($type eq 'hi' ? '#ffdead' : 'white') . "transparent",
	%draw_args,
	;
    $draw2->set_dimension_max(new MultiStrassen @border);
    $draw2->create_transpose;
    $draw2->draw_map;
    $draw2->flush;
    close IMG;

    if (open(DIM, ">$img_dim")) {
	require Data::Dumper;
	print DIM "# generated by $0 @orig_ARGV\n";
	print DIM Data::Dumper->Dumpxs([$draw], ['draw']);
	close DIM;
    }

    if ($use_gif) {
	system("convert", $img, $img_gif) == 0
	    or die "Failed $img -> $img_gif conversion: $?";
	if (0) { # XXX old code using netpbm
	    system("pngtopnm $img | ppmtogif > $img_gif");

	    if (is_in_path("giftool")) {
		# add comment
		system("giftool", "-B", "+c", "created by $0 on ".scalar(localtime),
		       $img_gif);
	    }

	    if ($type eq 'norm' && $normbg =~ /transparent/) {
		# find transparent color
		my $tr_color;
		open(GIFTR, "giftrans -L $img_gif 2>&1 |");
		while (<GIFTR>) {
		    if (/Color\s+(\d+):.*\#999999/) {
			$tr_color = $1;
			last;
		    }
		}
		close GIFTR;
		if (!defined $tr_color) {
		    die "Can't find transparent color in $img_gif";
		}

		rename $img_gif, "$img_gif~";
		system "giftrans -t $tr_color -o $img_gif $img_gif~";
		die if $?;
	    }
	}
    }

    if ($use_xpm) {
	system("convert", $img, $img_xpm) == 0
	    or die "Failed $img -> $img_xpm conversion: $?";
    }
}

__END__
