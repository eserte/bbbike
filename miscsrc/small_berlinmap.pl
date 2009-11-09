#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: small_berlinmap.pl,v 2.21 2007/04/01 20:02:17 eserte Exp eserte $
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
			 [-datadir directory]
			 [-strfiles file,file,...]
			 [-borderfiles file,file,...]
			 [-bbox x,y,x,y]
			 [-imagemagick] [-gif|-xpm]
			 [-cgisettings] [-customplaces place;place;...]
			 [-suffix suffix] [-fill]
			 [-o prefix]

=head1 DESCRIPTION

The default width and height are 200 pixels. This can be overriden by
the -width and -height options. The generated images will be saved in
the /tmp directory as berlin_small.gif (the normal image) and
berlin_small_hi.gif (the highlighted image). There will be also PNG
pictures generated (see L</BUGS> below). Also, a parameter file for
transpose functions is created (with the suffix .dim). With -v -v some
constants will be return for inclusion in bbbike.cgi.

The -normbg option sets the background color of the normal picture
(default: transparent).

With -includepotsdam the borders of Potsdam are also included.

With -nogif only the PNG images will be created.

-strfiles may include a comma-separated list of bbd files which should
be drawn. This overrides the default (streets, S-Bahn).

-borderfiles may include a comma-separated list of bbd files for
borders to draw and use for automatic bbox calculation. This overrides
the default (Berlin, and, if -includepotsdam is set, also Potsdam).

With -bbox the bounding box (expressed as standard BBBike coordinates)
can be set. By default, the bounding box is calculated by the borders.

With -imagemagick the BBBikeDraw::ImageMagick backend is used, but see
L</BUGS>.

With -customplaces a list of semicolon-separated places (probably must
be quoted in most shells!) can be added. See
L<BBBikeDraw::GDHeavy/draw_custom_places> for the exact format of the
list.

With -cgisettings the standard settings for bbbike.cgi are used.

-suffix: set a suffix for all generated files (usually something like
 _I<width>).

Use -fill to fill the area between borders with normbg.

=head1 OS DEPENDENCIES

=over 4

=item FreeBSD port: graphics/ImageMagick

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

=head1 CAVEATS

Es sieht so aus, als ob das generierte GIF-Bild kaputt wäre (fast
alles schwarz), wenn man es sich mit display oder xv anschaut. Mit
Mozilla sieht es aber OK aus. Anscheinend wird die transparente Farbe
dort falsch interpretiert...

=head1 AUTHOR

Slaven Rezic <eserte@users.sourceforge.net>

=head1 COPYRIGHT

Copyright (c) 1998,2001 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib", "$FindBin::RealBin/../data");

use File::Spec qw();
use File::Temp qw(tempfile);
use Getopt::Long;

use BBBikeDraw;
use BBBikeUtil qw(is_in_path);

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
my $bbox;
my $v = 0;
my $use_cgi_settings;
my $custom_places;
my $suffix = "";
my $datadir;
my $o_prefix = "/tmp/berlin";
my $do_fill;

my @orig_ARGV = @ARGV;
if (!GetOptions("width=i" => \$img_w,
		"height=i" => \$img_h,
		"normbg=s" => \$normbg,
		"fill!" => \$do_fill,
		"geometry=s" => \$geometry,
		"includepotsdam!" => \$includepotsdam,
		"datadir=s" => \$datadir,
		"strfiles=s" => sub { @strfiles = split /,/, $_[1] },
		"borderfiles=s" => sub { @border = split /,/, $_[1] },
		"bbox=s" => \$bbox,
		"imagemagick!" => \$use_imagemagick,
		"gif!" => \$use_gif,
		"xpm!" => \$use_xpm,
		"v+" => \$v,
		"cgisettings!" => \$use_cgi_settings,
		"customplaces=s" => \$custom_places,
		"suffix=s" => \$suffix,
		"o=s" => \$o_prefix,
	       )) {
    die "usage!";
}

if (defined $datadir) {
    $datadir = File::Spec->rel2abs($datadir);
    @Strassen::datadirs = ($datadir);
}

if ($use_cgi_settings) {
    if (0) {
	# old cgi settings (width=200 etc.)
    } elsif (1) {
	# Nauen <-> Strausberg
	$bbox = '-25901,-11471,43275,34695';
	$includepotsdam = 1;
	$custom_places = "Bernau;Königs Wusterhausen,-anchor,e;Teltow,-anchor,nc;Velten;Hennigsdorf,-anchor,e;Ahrensfelde,-anchor,nw;Michendorf;Mahlow;Werder,-anchor,nc;Strausberg,-anchor,e;Nauen,-anchor,w;Oranienburg;Zossen;Falkensee,-anchor,e";
	$img_w = 280;
	$img_h = 240;
	$suffix = "_".$img_w."x".$img_h;
    } else {
	$bbox = '-19716,-11471,33957,34695';
	$includepotsdam = 1;
	$custom_places = "Nauen,-anchor,w;Bernau;Königs Wusterhausen,-anchor,ne;Teltow,-anchor,nc;Velten;Hennigsdorf,-anchor,ne;Ahrensfelde;Michendorf;Mahlow";
	$img_w = $img_h = 240;
	$suffix = "_".$img_w;
    }
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
    my $base = $o_prefix . "_small" . ($type eq 'hi' ? '_hi' : '') . $suffix;
    my $img     = "$base.png";
    my $img_gif = "$base.gif";
    my $img_xpm = "$base.xpm";
    my $img_dim = "$base.dim";
    open(IMG, ">$img") or die "Can't write $img: $!";
    chmod 0644, $img;
    print STDERR "# Creating $type ...\n" if $v;
    my($w, $h) = ($img_w, $img_h);
    my $draw = new BBBikeDraw
	Fh => \*IMG,
        Geometry => $w."x".$h,
	Draw => [@border],
	Bg => ($type eq 'hi' ? '#ffdead' : $normbg),
        FrontierColor => 'red',
	ImageType => 'png',
	FontSizeScale => 0.68,
	%draw_args,
        ;
    set_bbox($draw);
    $draw->create_transpose(-asstring => 1);
    # Note: this has to be called after create_transpose, because of possible
    # adjustments
    print "
my \$minx = $draw->{Min_x};
my \$maxx = $draw->{Max_x};
my \$miny = $draw->{Min_y};
my \$maxy = $draw->{Max_y};
\n" if $v >= 2;
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

    if ($use_cgi_settings) {
	print <<EOF;
# For addition in bbbike.cgi:
\$berlin_small_width  = $img_w;
\$berlin_small_height = $img_h;
\$berlin_small_suffix = "$suffix";
\$xm = $xm;
\$ym = $ym;
\$x0 = $draw->{Min_x};
\$y0 = $draw->{Max_y};
EOF
    }

    $draw->draw_map;
    my $gd_img = $draw->{Image};
    if ($do_fill && $type ne 'hi') {
	no warnings 'uninitialized';
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
	Scope => 'region',
	;
    set_bbox($draw2);
    #XXX del: $draw2->set_dimension_max(new MultiStrassen @border);
    $draw2->create_transpose;
    $draw2->draw_map;
    if (defined $custom_places) {
	$draw->draw_custom_places($custom_places);
    }
    $draw2->flush;
    close IMG;

    if (open(DIM, ">$img_dim")) {
	chmod 0644, $img_dim;
	require Data::Dumper;
	local $Data::Dumper::Sortkeys = $Data::Dumper::Sortkeys = 1;
	print DIM "# generated by $0 @orig_ARGV\n";
	my $dim_data = {};
	for (qw(Width Height AntiTransposeCode TransposeCode Min_y Min_x Max_y Max_x Xk Yk)) { $dim_data->{$_} = $draw->{$_} }
	print DIM Data::Dumper->Dumpxs([$dim_data], ['draw']);
	close DIM;
    }

    if ($use_gif) {
	if (1) {
	    system("convert", $img, $img_gif) == 0
		or die "Failed $img -> $img_gif conversion: $?,\n" .
		    "maybe ImageMagick is not installed?";
	} else {
	    # XXX old code using netpbm
	    my($alphafh,$alphafile) = tempfile(SUFFIX => "_alpha.pbm",
					       UNLINK => 1,
					      );
	    my($pgmfh,$pgmfile) = tempfile(SUFFIX => "_alpha.pgm",
					   UNLINK => 1,
					  );
	    system("pngtopnm -alpha $img > $alphafile");
	    system("pgmtopbm $alphafile > $pgmfile");
	    system("pngtopnm $img | ppmtogif -alpha=$pgmfile > $img_gif");

	    if (is_in_path("giftool")) {
		# add comment
		system("giftool", "-B", "+c", "created by $0 on ".scalar(localtime),
		       $img_gif);
	    }

# 	    if ($type eq 'norm' && $normbg =~ /transparent/) {
# 		# find transparent color
# 		my $tr_color;
# 		open(GIFTR, "giftrans -L $img_gif 2>&1 |");
# 		while (<GIFTR>) {
# 		    if (/Color\s+(\d+):.*\#999999/) {
# 			$tr_color = $1;
# 			last;
# 		    }
# 		}
# 		close GIFTR;
# 		if (!defined $tr_color) {
# 		    die "Can't find transparent color in $img_gif";
# 		}

# 		rename $img_gif, "$img_gif~";
# 		system "giftrans -t $tr_color -o $img_gif $img_gif~";
# 		die if $?;
# 	    }
	}
	chmod 0644, $img_gif;
    }

    if ($use_xpm) {
	system("convert", $img, $img_xpm) == 0
	    or die "Failed $img -> $img_xpm conversion: $?,\n" .
		"maybe ImageMagick is not installed?";
	chmod 0644, $img_xpm;
    }
}

sub set_bbox {
    my($draw) = @_;
    if ($bbox) {
	$draw->set_bbox(split /,/, $bbox);
    } else {
	$draw->set_bbox_max(new MultiStrassen @border);
    }
}

__END__
