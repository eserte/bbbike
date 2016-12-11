# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1998,2001,2002,2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

package Tk::CanvasFig;

use Tk::Canvas;
use Tk::Font;

use File::Basename;

use strict;
use vars qw($VERSION %capstyle %joinstyle %figcolor @figcolor
	    $usercolorindex);

$VERSION = 1.017;

%capstyle = ('butt' => 0,
	     'projecting' => 2,
	     'round' => 1);
%joinstyle = ('bevel' => 1,
	      'miter' => 0,
	      'round' => 2);

my(%font_warning, %color_warning);

sub col2rgb {
    my($c, $color) = @_;
    if ($color !~ /^\#/) {
	my($r,$g,$b) = $c->rgb($color);
	if (defined $r) {
	    return sprintf("#%02x%02x%02x",
			   $r/256, $g/256, $b/256);
	}
    }
    $color;
}

sub initcolor {
    my $c = shift;
    undef %figcolor;
    @figcolor =
      (
       "black",   "blue",    "green",   "cyan",
       "red",     "magenta", "yellow",  "white",
       "#000090", "#0000b0", "#0000d0", "#87ceff",
       "#009000", "#00b000", "#00d000", "#009090",
       "#00b0b0", "#00d0d0", "#900000", "#b00000",
       "#d00000", "#900090", "#b000b0", "#d000d0",
       "#803000", "#a04000", "#c06000", "#ff8080",
       "#ffa0a0", "#ffc0c0", "#ffe0e0", "gold",
      );
    for(my $i=0; $i<=$#figcolor; $i++) {
	$figcolor[$i] = col2rgb($c, $figcolor[$i]);
	$figcolor{$figcolor[$i]} = $i;
    }
    $usercolorindex = 32;
}

sub newusercolor {
    my($color) = @_;
    if ($usercolorindex > 543) {
	warn "Too many colors, using default\n"
	    unless $color_warning{'toomany'};
	$color_warning{'toomany'}++;
	-1;
    } else {
	my $ci = $usercolorindex;
	$usercolorindex++;
	$figcolor[$ci] = $color;
	$figcolor{$color} = $ci;
	$ci;
    }
}

my $coeff;

sub init {
    my $c = shift;
    $coeff = int ( 1200 / (($c->screenwidth/$c->screenmmwidth)*25.4) );
    initcolor($c);
}

sub transpose {
    my $x = shift;
    int($x*$coeff);
}

sub save {
    my($c, %args) = @_;

    %font_warning = ();
    %color_warning = ();

    my $filename = $args{-file};

    my $imagedir;
    my $imageprefix;
    my $imagecount = 0;
    my $imagedir_warning;
    my %images;
    if ($args{-imagedir} && -d $args{-imagedir} && -w $args{-imagedir}) {
	$imagedir = $args{-imagedir};
	my $filedir = dirname($filename);
	if ($imagedir =~ /^(\Q$filedir\E)(.*)/) {
	    $imageprefix = $2;
	    $imageprefix =~ s|^/+||;
	} else {
	    $imageprefix = $imagedir;
	}
    }

    my $imagetype = "xpm";
    if ($args{-imagetype}) {
	$imagetype = $args{-imagetype};
    }

    init($c);

    my(@items) = $c->find('all');

    my($figobjstr, $figcolstr) = ('','');

    my $figheader = <<EOF;
#FIG 3.2
Landscape
Center
Metric
A4
100.00
Single
-3
1200 2
EOF

    foreach my $item (@items) {
	my $type = $c->type($item);

	if ($type eq 'arc') {
	    $figobjstr .= "5 ";
	    my $style = $c->itemcget($item, '-style');
	    if ($style eq 'chord') {
		# XXX NYI
		$figobjstr .= "1 ";
	    } elsif ($style eq 'arc') {
		$figobjstr .= "1 ";
	    } else { # pie
		$figobjstr .= "2 ";
	    }
	    $figobjstr .= "-1 "; # line style
	    my $width = $c->itemcget($item, '-width');
	    $figobjstr .= "$width ";

	    my($pen_fill_color, $filled) = get_pen_fill_color($c, $item, \$figcolstr);
	    $figobjstr .= $pen_fill_color;

	    $figobjstr .= "0 "; # depth
	    $figobjstr .= "0 "; # pen style
	    $figobjstr .= ($filled ? '20' : '-1') . " "; # area fill
	    $figobjstr .= "0.000 "; #style val
	    $figobjstr .= "0 "; # cap style
	    my $start = $c->itemcget($item, '-start');
	    my $extent = $c->itemcget($item, '-extent');
	    if ($extent < 0) {
		$figobjstr .= "0 "; # clockwise
	    } else {
		$figobjstr .= "1 "; # counterclockwise
	    }
	    $figobjstr .= "0 "; # XXX no forward arrow
	    $figobjstr .= "0 "; # XXX no backward arrow
	    my(@coords) = $c->coords($item);
	    my $rx = ($coords[2]-$coords[0])/2;
	    my $ry = ($coords[3]-$coords[1])/2;
	    if ($rx != $ry) {
		warn "Elliptic arcs not supported by xfig; $rx != $ry";
	    }
	    my($cx,$cy) = ($coords[0]+$rx,$coords[1]+$ry);
	    my($tcx,$tcy) = (transpose($cx), transpose($cy));
	    my($x1,$y1) = (transpose($cx+cos(deg2rad($start))*$rx),
			   transpose($cy-sin(deg2rad($start))*$ry));
	    my($x2,$y2) = (transpose($cx+cos(deg2rad($start+$extent/2))*$rx),
			   transpose($cy-sin(deg2rad($start+$extent/2))*$ry));
	    my($x3,$y3) = (transpose($cx+cos(deg2rad($start+$extent))*$rx),
			   transpose($cy-sin(deg2rad($start+$extent))*$ry));
	    $figobjstr .= "$tcx $tcy $x1 $y1 $x2 $y2 $x3 $y3";
	    $figobjstr .= "\n";

	} elsif ($type eq 'oval') {
	    $figobjstr .= "1 ";
	    my(@coords) = $c->coords($item);
	    my $diameter_x = $coords[2]-$coords[0];
	    my $diameter_y = $coords[3]-$coords[1];
	    if ($diameter_x == $diameter_y) {
		$figobjstr .= "3 "; # circle/radius
	    } else {
		$figobjstr .= "1 "; # ellipse/radius
	    }
	    $figobjstr .= "-1 "; # line style
	    my $width = $c->itemcget($item, '-width');
	    $figobjstr .= "$width ";

	    my($pen_fill_color, $filled) = get_pen_fill_color($c, $item, \$figcolstr);
	    $figobjstr .= $pen_fill_color;

	    $figobjstr .= "0 "; # depth
	    $figobjstr .= "0 "; # pen style
	    $figobjstr .= ($filled ? '20' : '-1') . " "; # area fill
	    $figobjstr .= "0.000 "; #style val
	    $figobjstr .= "1 "; # direction
	    $figobjstr .= "0.000 "; # angle

	    my($cx,$cy) = ($coords[0]+$diameter_x/2,$coords[1]+$diameter_y/2);
	    my($tcx,$tcy) = (transpose($cx), transpose($cy));
	    my($rx,$ry) = (transpose($diameter_x/2),transpose($diameter_y/2));
	    my($x1,$y1) = ($cx+$rx,$cy);
	    my($x2,$y2) = ($cx,$cy+$ry);
	    $figobjstr .= "$tcx $tcy $rx $ry $x1 $y1 $x2 $y2";
	    $figobjstr .= "\n";

	} elsif ($type =~ /^(polygon|line|rectangle)$/) {
	    my $filled = 0;
	    $figobjstr .= "2 ";
	    my(@coords) = $c->coords($item);
	    if ($type eq 'polygon' && @coords >= 3*2) { # to prevent xfig warnings
		$figobjstr .= "3 ";
	    } elsif ($type eq 'line' || $type eq 'polygon') {
		$figobjstr .= "1 ";
	    } elsif ($type eq 'rectangle') {
		$figobjstr .= "2 ";
	    } else {
		die;
	    }
	    $figobjstr .= "-1 "; # line style
	    my $width = $c->itemcget($item, '-width');
	    $figobjstr .= "$width ";
	    if ($type eq 'line') {
		my $pen = col2rgb($c, $c->itemcget($item, '-fill'));
		if (exists $figcolor{$pen}) {
		    $figobjstr .= "$figcolor{$pen} ";
		} else {
		    $pen = newusercolor($pen);
		    $figobjstr .= "$pen ";
		    $figcolstr .= "0 $pen $figcolor[$pen]\n";
		}
		$figobjstr .= "-1 "; # fill color
	    } else {
		# XXX use get_pen_fill_color
		my $fill_figobjstr = "";
		my $fill = $c->itemcget($item, '-fill');
		if (defined $fill && $fill ne '') {
		    $fill = col2rgb($c, $fill);
		    if (exists $figcolor{$fill}) {
			$fill_figobjstr .= "$figcolor{$fill} ";
		    } else {
			$fill = newusercolor($fill);
			$fill_figobjstr .= "$fill ";
			$figcolstr .= "0 $fill $figcolor[$fill]\n";
		    }
		    $filled = 1;
		} else {
		    $fill_figobjstr .= "-1 ";
		}

		# XXX pen = fill, wenn pen nicht definiert
		my $pen = $c->itemcget($item, '-outline');
		if (defined $pen && $pen ne '') {
		    $pen = col2rgb($c, $pen);
		    if (exists $figcolor{$pen}) {
			$figobjstr .= "$figcolor{$pen} ";
		    } else {
			$pen = newusercolor($pen);
			$figobjstr .= "$pen ";
			$figcolstr .= "0 $pen $figcolor[$pen]\n";
		    }
		} else {
		    $figobjstr .= $fill_figobjstr;
		}
		$figobjstr .= $fill_figobjstr;
	    }
	    $figobjstr .= "0 "; # depth
	    $figobjstr .= "0 "; # pen style
	    $figobjstr .= ($filled ? '20' : '-1') . " "; # area fill
	    $figobjstr .= "0.000 "; #style val
	    if ($type eq 'line') {
		my $join = $c->itemcget($item, '-joinstyle');
		$figobjstr .= $joinstyle{$join} . " ";
		my $cap = $c->itemcget($item, '-capstyle');
		$figobjstr .= $capstyle{$cap} . " ";
	    } else {
		$figobjstr .= "0 0 ";
	    }
	    $figobjstr .= "-1 "; # radius
	    if ($type eq 'line') {
		my $arrow = $c->itemcget($item, '-arrow');
		# forward arrow
		$figobjstr .= ($arrow =~ /^(both|last)$/ ? "1" : "0") . " ";
		# backward arrow
		$figobjstr .= ($arrow =~ /^(both|first)$/ ? "1" : "0") . " ";
	    } else {
		$figobjstr .= "0 0 ";
	    }
	    if ($type eq 'rectangle') {
		$figobjstr .= "5 \n\t";
		my($tx1,$ty1) = (transpose($coords[0]), transpose($coords[1]));
		my($tx2,$ty2) = (transpose($coords[2]), transpose($coords[3]));
		$figobjstr .= "$tx1 $ty1 $tx2 $ty1 $tx2 $ty2 $tx1 $ty2 $tx1 $ty1";
	    } else {
		$figobjstr .= (scalar @coords)/2 . " \n\t";
		for(my $i=0; $i<$#coords; $i+=2) {
		    $figobjstr .= transpose($coords[$i]) . " " . transpose($coords[$i+1]) . " ";
		}
	    }
	    $figobjstr .= "\n";

	} elsif ($type eq 'text') {
	    $figobjstr .= "4 ";
	    my $anchor = $c->itemcget($item, '-anchor');
	    if ($anchor =~ /w$/) {
		$figobjstr .= "0 ";
	    } elsif ($anchor =~ /e$/) {
		$figobjstr .= "2 ";
	    } else {
		$figobjstr .= "1 "; # justification
	    }
	    my $pen = col2rgb($c, $c->itemcget($item, '-fill'));
	    if (exists $figcolor{$pen}) {
		$figobjstr .= "$figcolor{$pen} ";
	    } else {
		$pen = newusercolor($pen);
		$figobjstr .= "$pen ";
		$figcolstr .= "0 $pen $figcolor[$pen]\n";
	    }
	    $figobjstr .= "0 "; # depth
	    $figobjstr .= "0 "; # pen style
	    my $font = $c->itemcget($item, '-font');
	    my($fonttype, $fontsize);
	    if (defined $font) {
		($fonttype, $fontsize) = font2figfont($font);
	    } else {
		($fonttype, $fontsize) = (-1, 10);
	    }
	    $figobjstr .= "$fonttype "; # font
	    $figobjstr .= "$fontsize "; # font size
	    $figobjstr .= "0.000 "; # angle
	    $figobjstr .= "4 "; # font flags (postscript fonts)
# XXX anchor => center/south: adjust y coordinate!
	    my(@bbox) = $c->bbox($item);
	    $figobjstr .= transpose(abs($bbox[1]-$bbox[3])) . " ";
	    $figobjstr .= transpose(abs($bbox[0]-$bbox[2])) . " ";
	    my(@coords) = $c->coords($item);
	    $figobjstr .= transpose($coords[0]). " ".transpose($coords[1])." ";
	    my $text = $c->itemcget($item, '-text') . "\\001";
	    $figobjstr .= $text;
	    $figobjstr .= "\n";

	} elsif ($type eq 'image') {
	    my $image = $c->itemcget($item, '-image');
	    if ($image && $imagedir) {
		my $imagename = $images{$image};
		if (!defined $imagename) {
		    # gif/ppm are too slow, because external programs are used
		    # xpm have to be compiled into the xfig binary!
		    my $outimagetype = $imagetype;
		    if ($imagetype eq 'pcx') {
			$outimagetype = 'ppm';
		    }
		    my $outfilebase = "$imagecount.$outimagetype";
		    my $outfilename = "$imagedir/$outfilebase";
		    if ($image->type eq 'pixmap') {
			my $file = $image->cget('-file');
			my $data = $image->cget('-data');
			my $new_image;
			if (defined $data) {
			    # For some reason the /*XPM*/ magic is stripped.
			    # Prepending the magic should not hurt.
			    $data = "/* XPM */" . $data;
			    $new_image = $c->Photo(-data => $data, -format => "xpm");
			} elsif (defined $file) {
			    $new_image = $c->Photo(-file => $file, -format => "xpm");
			} else {
			    # empty pixmap, do nothing
			    next;
			}
			$new_image->write($outfilename, -format => $outimagetype);
			$new_image->delete;
		    } elsif ($image->type eq 'bitmap') {
			warn "Sorry, bitmap is not yet supported...";
			next;
		    } elsif ($image->type eq 'photo') {
			$image->write($outfilename, -format => $outimagetype);
		    } else {
			warn "Sorry image type " . $image->type . " is not supported...";
			next;
		    }
		    if ($imagetype eq 'pcx') {
			$outfilebase = basename(convert_pcximage($outfilename));
		    }
		    $imagename = $images{$image} = "$imageprefix/$outfilebase";
		    $imagecount++;
		}
		$figobjstr .= "2 "; # polyline
		$figobjstr .= "5 "; # imported picture bounding box
		$figobjstr .= "-1 "; # line style
		$figobjstr .= "-1 "; # thickness
		$figobjstr .= "-1 "; # pen color
		$figobjstr .= "-1 "; # fill color
		$figobjstr .= "0 "; # depth
		$figobjstr .= "0 "; # pen style
		$figobjstr .= "-1 "; # area fill
		$figobjstr .= "0.000 "; #style val
		$figobjstr .= "0 0 "; # cap/join style
		$figobjstr .= "-1 "; # radius
		$figobjstr .= "0 0 "; # forward/backward arrow
		my(@coords) = $c->coords($item);
		$figobjstr .= "5\n\t0 $imagename\n\t";

		my $anchor = $c->itemcget($item, '-anchor');
		my $addx = -$image->width/2;
		my $addy = -$image->height/2;
		if ($anchor ne 'center') {
		    if ($anchor =~ /n/) {
			$addy = 0;
		    } elsif ($anchor =~ /s/) {
			$addy = -$image->height;
		    }
		    if ($anchor =~ /w/) {
			$addx = 0;
		    } elsif ($anchor =~ /e/) {
			$addx = -$image->width;
		    }
		}
		my($tx1,$ty1) = (transpose($coords[0]+$addx), transpose($coords[1]+$addy));
		my($tx2,$ty2) = (transpose($coords[0]+$image->width+$addx), transpose($coords[1]+$image->height+$addy));
		$figobjstr .= "$tx1 $ty1 $tx2 $ty1 $tx2 $ty2 $tx1 $ty2 $tx1 $ty1";
		$figobjstr .= "\n";
	    } elsif ($image) {
		warn "Writing images is not enabled (-imagedir not given or not writable)\n"
		    unless $imagedir_warning;
		$imagedir_warning++;
	    }

	} else {
	    warn "Unknown type: $type";
	}
    }

    if (defined $filename) {
	open(FIG, ">$filename") or die "Can't write to $filename: $!";
	print FIG $figheader, $figcolstr, $figobjstr;
	close FIG;
    } else {
	"$figheader$figcolstr$figobjstr";
    }
}

sub font2figfont {
    my($f) = @_;
    my(%a) = $f->actual;
    my $font = -1; # use default font
    my $base;
    if ($a{'-family'} =~ /(times)/i) {
	$base = 0;
    } elsif ($a{'-family'} =~ /(helvetica|arial|geneva)/i) {
	$base = 16;
    } elsif ($a{'-family'} =~ /avantgarde/i) {
	$base = 4;
    } elsif ($a{'-family'} =~ /bookman/i) {
	$base = 8;
    } elsif ($a{'-family'} =~ /courier/i) {
	$base = 12;
    } elsif ($a{'-family'} =~ /new century/i) {
	$base = 24;
    } elsif ($a{'-family'} =~ /palatino/i) {
	$base = 28;
    } else {
	warn "Unknown font family $a{'-family'}, fallback to default\n"
	    unless $font_warning{$a{'-family'}};
	$font_warning{$a{'-family'}}++;
    }
    if (defined $base) {
	if      ($a{'-weight'} eq 'normal' && $a{'-slant'} eq 'roman') {
	    $font = $base;
	} elsif ($a{'-weight'} eq 'normal' && $a{'-slant'} eq 'italic') {
	    $font = $base + 1;
	} elsif ($a{'-weight'} eq 'bold'   && $a{'-slant'} eq 'roman') {
	    $font = $base + 2;
	} elsif ($a{'-weight'} eq 'bold'   && $a{'-slant'} eq 'italic') {
	    $font = $base + 3;
	} else {
	    my $e = "$a{'-weight'} $a{'-slant'}";
	    warn "Unknown handling for $e, fallback to normal roman\n"
		unless $font_warning{$e};
	    $font_warning{$e}++;
	    $font = $base;
	}
    }
    ($font, $a{'-size'});
}

sub get_pen_fill_color {
    my($c, $item, $figcolstrref) = @_;
    my $figobjstr = "";
    my $fill_figobjstr = "";
    my $fill = $c->itemcget($item, '-fill');
    my $filled;
    if (defined $fill && $fill ne '') {
	$fill = col2rgb($c, $fill);
	if (exists $figcolor{$fill}) {
	    $fill_figobjstr .= "$figcolor{$fill} ";
	} else {
	    $fill = newusercolor($fill);
	    $fill_figobjstr .= "$fill ";
	    $$figcolstrref .= "0 $fill $figcolor[$fill]\n";
	}
	$filled = 1;
    } else {
	$fill_figobjstr .= "-1 ";
    }

    my $pen = $c->itemcget($item, '-outline');
    if (defined $pen && $pen ne '') {
	$pen = col2rgb($c, $pen);
	if (exists $figcolor{$pen}) {
	    $figobjstr .= "$figcolor{$pen} ";
	} else {
	    $pen = newusercolor($pen);
	    $figobjstr .= "$pen ";
	    $$figcolstrref .= "0 $pen $figcolor[$pen]\n";
	}
    } else {
	$figobjstr .= $fill_figobjstr;
    }
    $figobjstr .= $fill_figobjstr;
    ($figobjstr, $filled);
}

# Convert a ppm image to pcx. The file extension will be adjusted.
# Return the new file name.
# Note that the original file will be deleted.
sub convert_pcximage {
    my($file) = @_;
    (my $outfile = $file) =~ s/\.[^.]+$/.pcx/;
    if (!is_in_path("ppmtopcx")) {
	die "ppmtopcx from netpbm is not installed, can't write as pcx file";
    }
    system("ppmtopcx $file > $outfile");
    if ($? != 0) {
	warn "Problems while converting $file to $outfile";
    }
    unlink $file;
    $outfile;
}

sub pi ()   { 4 * atan2(1, 1) } # 3.141592653
sub deg2rad { ($_[0]*pi)/180 }

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 1b42243230d92021e6c361e37c9771d1

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

package # hide from CPAN indexer
    Tk::Canvas;

sub fig {
    my($c,@args) = @_;
    Tk::CanvasFig::save($c, @args);
}

1;

__END__

=head1 NAME

Tk::CanvasFig - additional Tk::Canvas methods for dealing with figs

=head1 SYNOPSIS

    use Tk::CanvasFig;
    $canvas->fig(-file => $filename, -imagedir => $filename."-images");

=head1 DESCRIPTION

This module adds another method to the Tk::Canvas namespace: C<fig>.
The C<fig> method creates a xfig compatible file from the given
canvas. The output is written to a file if the C<-file> option is
specified, otherwise it is returned as a string. The creation of
images is only supported if the C<-imagedir> option is specified.

=head2 ARGUMENTS

=over 4

=item -file

The file name for the FIG output. If this option is not specified,
then the result will be returned as a string.

=item -imagedir

If images are included in the canvas, then they will be written into
the directory specified by this option. The directory has to exist.
If this option is not specified, no images are created.

=item -imagetype

The image type for the images created in C<-imagedir>. By default,
C<xpm> is used, but every C<Tk>-supported and C<xfig>-supported image
type can be used. Note that a plain C<xfig> build does not have C<xpm>
support. Also note that xfig uses external programs for decoding other
file formats like C<gif> or C<ppm>, so this can be *very* slow if you
have a lot of images in the canvas. If C<netpbm> with C<ppmtopcx> is
installed, the image type C<pcx> can be used, for which C<xfig> does
not need an external program. See also L</BUGS>.

=back

=head1 BUGS

Not all canvas items are implemented (grid, groups).

Not everything is perfect.

C<xfig> 3.2.3d dumps core if C<xpm> images with more than 256 colors
are used. If you have such images, you have to use another
C<-imagetype>.

Transparency will only be handled in C<xpm> images correctly. This is
because C<netpbm> programs does not handle transparency.

=head1 SEE ALSO

L<Tk>, L<Tk::Canvas>, L<xfig(1)>

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=head1 COPYRIGHT

Copyright (c) 1998, 2001, 2002, 2009 Slaven Rezic. All rights reserved. This
module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
