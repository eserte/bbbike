#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: small_berlinmap.pl,v 2.14 2002/08/22 20:58:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998,2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

=head1 NAME

small_berlinmap.pl - create a small overview map of Berlin

=head1 SYNOPSIS

    ./small_berlinmap.pl [-width w] [-height h] [-normbg bgcolor]
                         [-includepotsdam] [-nogif]

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

=item FreeBSD port: graphics/giftrans

=item FreeBSD port: graphics/netpbm

=back

=head1 BUGS

Leider kann Netscape anscheinend keine transparenten PNGs darstellen ...
deshalb ist eine Konvertierung nach GIF erforderlich.

The fill center point for Potsdam is very rough and can lead to wrong
results.

=head1 AUTHOR

Slaven Rezic <slaven.rezic@berlin.de>

=head1 COPYRIGHT

Copyright (c) 1998,2001 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib", "$FindBin::RealBin/../data");
use BBBikeDraw;
use Getopt::Long;
use strict;

##XXX was ist das?
# use Strassen;
#  open(BA, "$FindBin::RealBin/combine_streets.pl - < $FindBin::RealBin/../data/berlin |");
#  open(OUT, ">/tmp/berlin_area") or die $!;
#  while(<BA>) {
#      my $l = Strassen::parse($_);
#      $l->[Strassen::CAT] = "F:" . $l->[Strassen::CAT];
#      $l->[Strassen::COORDS] = join(" ", @{ $l->[Strassen::COORDS] });
#      print OUT Strassen::arr2line($l);
#  }
#  close OUT;
#  close BA;
# push @Strassen::datadirs, "/tmp";

my $img_w = 200;
my $img_h = 200;
my $normbg = 'transparent';
my $geometry;
my $includepotsdam;
my $use_imagemagick;
my $use_gif = 1;
my @strfiles = ('sbahn', 'ubahn', 'wasser');
my @border;

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
my %draw2_args = (Draw => [@strfiles]);
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
    my $img_dim = "$base.dim";
    open(IMG, ">$img") or die "Can't write $img: $!";
    print STDERR "# Creating $type ...\n";
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
\n";
    $draw->create_transpose(-asstring => 1);
    my $xm = ($draw->{Max_x}-$draw->{Min_x})/$w;
    my $ym = ($draw->{Max_y}-$draw->{Min_y})/$h;
    print "my \$xm = $xm;\nmy \$ym = $ym;\n\n";
#    warn join(", ", $draw->{Transpose}->($draw->{Min_x}, $draw->{Min_y}))."\n";
#    warn join(", ", $draw->{Transpose}->($draw->{Max_x}, $draw->{Max_y}))."\n";
    my($xx,$yy) = $draw->{Transpose}->($draw->{Min_x}, $draw->{Min_y});
#    warn join(", ", $draw->{AntiTranspose}->(0, 0))."\n";
#    warn join(", ", $draw->{AntiTranspose}->($img_w, $img_h))."\n";
    print "my \$transpose = $draw->{TransposeCode};\n";
    print "my \$anti_transpose = $draw->{AntiTransposeCode};\n\n";

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
    my $draw2 = new BBBikeDraw
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

    if ($use_gif) {
	system("pngtopnm $img | ppmtogif > $img_gif");

	if (is_in_path("giftool")) {
	    # add comment
	    system("giftool", "-B", "+c", "created by $0 on ".scalar(localtime),
		   $img_gif);
	}
    }

    if (open(DIM, ">$img_dim")) {
	require Data::Dumper;
	print DIM "# generated by $0 @orig_ARGV\n";
	print DIM Data::Dumper->Dumpxs([$draw], ['draw']);
	close DIM;
    }

    if ($use_gif) {
	if ($type eq 'norm' && $normbg =~ /transparent/) {
	    # find transparent color
	    my $tr_color;
	    open(GIFTR, "giftrans -L $img_gif 2>&1 |");
	    while(<GIFTR>) {
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

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 1b42243230d92021e6c361e37c9771d1

=head2 is_in_path($prog)

=for category File

Return the pathname of $prog, if the program is in the PATH, or undef
otherwise.

DEPENDENCY: file_name_is_absolute

=cut

sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -f $prog and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    return "$_\\$prog"
		if (-x "$_\\$prog.bat" ||
		    -x "$_\\$prog.com" ||
		    -x "$_\\$prog.exe");
	} else {
	    return "$_/$prog" if (-x "$_/$prog");
	}
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 a77759517bc00f13c52bb91d861d07d0

=head2 file_name_is_absolute($file)

=for category File

Return true, if supplied file name is absolute. This is only necessary
for older perls where File::Spec is not part of the system.

=cut

sub file_name_is_absolute {
    my $file = shift;
    my $r;
    eval {
        require File::Spec;
        $r = File::Spec->file_name_is_absolute($file);
    };
    if ($@) {
	if ($^O eq 'MSWin32') {
	    $r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	} else {
	    $r = ($file =~ m|^/|);
	}
    }
    $r;
}
# REPO END

__END__
