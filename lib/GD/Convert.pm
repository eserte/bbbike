# -*- perl -*-

#
# $Id: Convert.pm,v 2.1 2003/02/07 11:38:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GD::Convert;

use strict;
use vars qw($VERSION $DEBUG);
$VERSION = sprintf("%d.%02d", q$Revision: 2.1 $ =~ /(\d+)\.(\d+)/);

sub import {
    my($pkg, @args) = @_;
    foreach my $arg (@args) {
	my($f, $as) = split /=/, $arg;
	if ($f =~ /^(gif|newFromGif)$/) {
	    if ($as eq 'any') {
		# check whether GD handles the gif itself
		if ($GD::VERSION <= 1.19 ||
		    ($GD::VERSION >= 1.37 && $GD::VERSION < 1.40 && GD::Image->can($f))) {
		    undef $as;
		} elsif ($GD::VERSION >= 1.40 && GD::Image->can($f)) {
		    $@ = "";
		    GD::Image->new->$f();
		    if ($@ !~ /libgd was not built with gif support/) {
			undef $as;
		    }
		}
		# No? Then try alternatives
		if (defined $as) {
		    if ($f eq 'gif' && is_in_path("ppmtogif")) {
			$as = $f . "_netpbm";
		    } elsif ($f eq 'newFromGif' && is_in_path("giftopnm")) {
			$as = $f . "_netpbm";
		    } elsif ($^O ne 'MSWin32' && is_in_path("convert")) {
			# convert is a special command on MSWin32
			$as = $f . "_imagemagick";
		    } else {
			die "Can't find any GIF converter for $f in $ENV{PATH}";
		    }
		}
	    }
	} else {
	    die "Import directive $arg invalid: $f not handled";
	}

	if (defined $as) {
	    my $sub = "GD::Image::$f";
	    my $prototype = prototype $sub;
	    if (!defined $prototype) {
		$prototype = "";
	    } else {
		$prototype = "($prototype)";
	    }
	    my $code = "sub $sub $prototype { shift->$as(\@_) }";
	    if ($] >= 5.006) { # has warnings
		$code = "{ no warnings qw(redefine); $code; }";
	    }
	    #warn $code;
	    eval $code;
	    die "$code\n\nfailed with: $@" if $@;
	}
    }
}

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

package
    GD::Image;

sub xpm {
    my $im = shift;

    my $gd = $im->gd;

    my($width, $height) = $im->getBounds;
    my $chars_per_pixel = 2;

    my($bufp, $is_gd2, $is_truecolor, $no_colors) = _get_header(\$gd);

    my $xpm = <<EOF;
/* XPM */
static char *noname[] = {
/* width height ncolors chars_per_pixel */
"$width $height $no_colors $chars_per_pixel",
/* colors */
EOF

    my $ch1 = "a";
    my $ch2 = "a";
    my @color;
    for(my $i=0; $i<256; $i++) {
        my $buf = substr($gd, $bufp, 3); $bufp+=3;
	if ($is_gd2) { $bufp++ } # ignore alpha
	next if $i >= $no_colors; # unused color entries
	$color[$i] = "$ch1$ch2";
	if ($im->transparent == $i) {
	    $xpm .= "\"$ch1$ch2 s mask c none\",\n";
	} else {
	    $xpm .= sprintf "\"$ch1$ch2 c #%02x%02x%02x\",\n", unpack("C*", $buf);
	}
	$ch1 = chr(ord($ch1)+1);
	if ($ch1 gt "z") {
	    $ch1 = "a";
	    $ch2 = chr(ord($ch2)+1);
	}
    }

    $xpm .= "/* pixels */\n";
    for(my $rows=0; $rows<$height; $rows++) {
	$xpm .= "\"";
	for(my $cols=0; $cols<$width; $cols++) {
	    my $buf = substr($gd, $bufp, 1); $bufp++;
	    $xpm .= $color[unpack("c", $buf)];
	}
	$xpm .= "\",\n";
    }
    $xpm .= "};\n";

    $xpm;
}

sub ppm {
    my $im = shift;

    my $gd = $im->gd;

    my($width, $height) = $im->getBounds;

    my($bufp, $is_gd2, $is_truecolor, $no_colors) = _get_header(\$gd);
    my @color;
    for(my $i=0; $i<256; $i++) {
	my $buf = substr($gd, $bufp, 3); $bufp+=3;
	$color[$i] = $buf;
	if ($is_gd2) { $bufp++ } # ignore alpha
    }

    my $ppm = "P6\n"
	    . "$width $height\n"
            . "255\n";
    for(my $rows=0; $rows<$height; $rows++) {
	for(my $cols=0; $cols<$width; $cols++) {
	    my $buf = substr($gd, $bufp, 1); $bufp++;
	    #XXX not necessary yet: next if ($is_truecolor && $cols%4==3); # ignore alpha channel
	    $ppm .= $color[unpack("c", $buf)];
	}
    }

    $ppm;
}

sub _get_header {
    my $gdref = shift;
    my $is_gd2 = 0;
    my $bufp;
    my $is_truecolor = 0;
    my $no_colors;
    if (substr($$gdref, 0, 2) eq "\xff\xff") {
	$bufp = 6;
	$is_truecolor = unpack("c", substr($$gdref, $bufp, 1));
	$bufp++;
	if (!$is_truecolor) {
	    $no_colors = unpack("n", substr($$gdref, $bufp, 2));
	    $bufp+=2;
	} else {
	    die "True color images not supported!";
	}
	$bufp+=4; # transparent color
	$is_gd2 = 1;
    } else {
	$bufp = 4+3;
	$no_colors = 256;
    }
    ($bufp, $is_gd2, $is_truecolor, $no_colors);
}

sub _gif_external {
    my($im, $ext_type, @args) = @_;

    my $in_image;

    my @cmd;

    if ($ext_type eq 'netpbm') {
	my(%args) = @args;

	$in_image = $im->ppm;

	@cmd = ("ppmtogif");
	if ($im->interlaced) {
	    push @cmd, "-interlace";
	}
	my $tr_idx = $im->transparent;
	if ($tr_idx != -1) {
	    if (defined $args{-transparencyhack}) {
		my($r,$g,$b) = $im->rgb($tr_idx);
		my $rgb = sprintf "#%02x%02x%02x", $r, $g, $b;
		push @cmd, "-transparent", "$rgb";
	    } else {
		warn "Can't handle transperancy (yet)";
	    }
	}
    } elsif ($ext_type eq 'imagemagick') {
	my(%args) = @args;

	my $can_png;
	if ($im->can('png')) {
	    # Prefer png => gif, because transparency information won't get
	    # lost.
	    $in_image = $im->png;
	    $can_png = 1;
	} else {
	    $in_image = $im->ppm;
	}

	@cmd = ("convert");
	if ($im->interlaced) {
	    push @cmd, "-interlace", "Line";
	}

	if (!$can_png) {
	    my $tr_idx = $im->transparent;
	    if ($tr_idx != -1) {
		if (defined $args{-transparencyhack}) {
		    my($r,$g,$b) = $im->rgb($tr_idx);
		    my $rgb = sprintf "#%02x%02x%02x", $r, $g, $b;
		    push @cmd, "-transparency", "$rgb";
		} else {
		    warn "Can't handle transperancy (yet)";
		}
	    }
	    push @cmd, "ppm:-", "gif:-";
	} else {
	    push @cmd, "png:-", "gif:-";
	}
    } else {
	die "Unhandled type $ext_type";
    }

    require IPC::Open3;

    warn "Cmd: @cmd\n" if $GD::Convert::DEBUG;
    my $pid = IPC::Open3::open3(\*WTR, \*RDR, \*ERR, @cmd);
    die "Can't create process for @cmd" if !defined $pid;
    binmode RDR;
    binmode WTR;
    print WTR $in_image;
    close WTR;

    my $gif;
    {
	local $/ = undef;
	$gif = scalar <RDR>;
    }
    close RDR;

    $gif;

}

sub gif_netpbm      { shift->_gif_external("netpbm", @_) }
sub gif_imagemagick { shift->_gif_external("imagemagick", @_) }

#XXX implementation pending...
sub newFromGif_netpbm      { die "NYI" }
sub newFromGif_imagemagick { die "NYI" }

#XXX merge with GD::Wbmp, delete GD::Wbmp
sub _wbmp {
    my $im = shift;
    if ($im->can('wbmp')) {
	$im->wbmp(@_);
    } else {
	die "NYI";
    }
}

1;

__END__

=head1 NAME

GD::Convert - additional output formats for GD

=head1 SYNOPSIS

    use GD;
    use GD::Convert 'gif=gif_netpbm';
    ...
    $gd->ppm;
    $gd->xpm;
    $gd->gif;

=head1 DESCRIPTION

This module provides additional output functions for the GD module:
ppm, xpm and gif_netpbm/gif_imagemagick.

=over 4

=item $ppmdata = $image->ppm

Take a GD image and return a string with a PPM file as its content.

=item $xpmdata = $image->xpm

Take a GD image and return a string with a XPM file as its content.

=item $gifdata = $image->gif_netpbm([...])

Take a GD image and return a string with a GIF file as its content.
The conversion will use the C<ppmtogif> binary from C<netpbm>. If you
specify C<gif=gif_netpbm> in the C<use> line, then you can use the
method name C<gif> instead.

The gif_netpbm handles the optional parameter C<-transparencyhack>. If
set to a true value, a transparent GIF file will be produced. Note
that this will not work if the transparent color occurs also as a
normal color.

=item $gifdata = $image->gif_imagemagick

This is the same as C<gif_netpbm>, instead it is using the C<convert>
program of ImageMagick.

=back

=head1 BUGS

Transparency will get lost in PPM images.

The transparency handling for GIF images is clumsy --- maybe the new
--alpha option of ppmtogif should be used.

The size of the created files should be smaller, especially of the XPM
output.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=head1 COPYRIGHT

Copyright (c) 2001,2003 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

GD(3), netpbm(1).

