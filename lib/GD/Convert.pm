# -*- perl -*-

#
# $Id: Convert.pm,v 2.11 2004/04/15 23:25:16 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.sourceforge.net/projects/srezic
#

package GD::Convert;

use strict;
use vars qw($VERSION $DEBUG %installed);
$VERSION = sprintf("%d.%02d", q$Revision: 2.11 $ =~ /(\d+)\.(\d+)/);

$DEBUG = 0 if !defined $DEBUG;

sub import {
    my($pkg, @args) = @_;
    foreach my $arg (@args) {
	my($f, $as) = split /=/, $arg;
	if ($f =~ /^(gif|newFromGif|newFromGifData)$/) {
	    if (!defined $as || $as eq 'any') {
		# check whether GD handles the gif itself
		if ($GD::VERSION <= 1.19 ||
		    ($GD::VERSION >= 1.37 && $GD::VERSION < 1.40 && !$installed{"gif"} && GD::Image->can("gif")) # better check for "gif" than for $f
		   ) {
		    undef $as;
		} elsif ($GD::VERSION >= 2.15) {
		    # hmmm ...
		} elsif ($GD::VERSION >= 1.40 && !$installed{$f} && GD::Image->can($f)) {
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
			die "Can't find any converter for $f in $ENV{PATH}";
		    }
		}
	    }
	} elsif ($f =~ /^(wbmp)$/) {
	    if ($GD::VERSION >= 1.26) {
		# wbmp support already in GD
	    } else {
		$as = "_wbmp";
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
	    $installed{$f}++;
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

sub newFromPpmData {
    my($self, $data, $truecolor) = @_;
    (my $signature, my $dimensions, my $maxval, $data) = split /\n/, $data, 4;
    if ($signature ne 'P6') {
	die "Can handle only P6 (ppm raw) files, got <$signature>";
    }
    my($width, $height) = split /\s+/, $dimensions;
    if ($maxval != 255) {
	die "Can handle only ppm files with maxval=255, got <$maxval>";
    }
    my $gd;
    if ($GD::VERSION >= 2 && defined $truecolor) {
	$gd = $self->new($width, $height, $truecolor);
    } else {
	$gd = $self->new($width, $height);
    }
    my %palette;
    my $x = 0;
    my $y = 0;
    for(my $i = 0; $i < length($data); $i+=3) {
	my($r,$g,$b) = map { ord } split //, substr($data, $i, 3);
	my $color;
	if (exists $palette{"$r/$g/$b"}) {
	    $color = $palette{"$r/$g/$b"};
	} else {
	    $color = $gd->colorAllocate($r,$g,$b);
	    $palette{"$r/$g/$b"} = $color;
	}
	$gd->setPixel($x, $y, $color);
	$x++;
	if ($x >= $width) {
	    $x = 0;
	    $y++;
	    if ($y > $height) {
		die "Image data does not match dimensions $width x $height";
	    }
	}
    }

    $gd;
}

sub newFromPpm {
    my($self, $file, $truecolor) = @_;
    my $data = _data_from_file($file);
    $self->newFromPpmData($data, $truecolor);
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

    my $gif = _3_pipe(\$in_image, \@cmd);
    $gif;

}

sub _newFromGif_external {
    my($self, $ext_type, $source_type, $data, $truecolor) = @_;

    if ($source_type eq 'file') {
	# $data is a file name
	$data = _data_from_file($data);
    }

    my @cmd;
    my $input_type;

    if ($ext_type eq 'netpbm') {
	@cmd = ("giftopnm");
	$input_type = "pnm";
    } elsif ($ext_type eq 'imagemagick') {
	my $can_png;
	if (GD::Image->can('png')) {
	    # Prefer gif => png, because transparency information won't get
	    # lost.
	    $input_type = "png";
	    $can_png = 1;
	} else {
	    $input_type = "pnm";
	}

	@cmd = ("convert");

	if (!$can_png) {
	    push @cmd, "gif:-", "ppm:-";
	} else {
	    push @cmd, "gif:-", "png:-";
	}
    } else {
	die "Unhandled type $ext_type";
    }

    my $data2 = _3_pipe(\$data, \@cmd);

    my $cmd;
    if ($input_type eq 'png') {
	$cmd = "newFromPngData";
    } else {
	$cmd = "newFromPpmData";
    }

    my $gd;
    if ($GD::VERSION >= 2 && defined $truecolor) {
	$gd = $self->$cmd($data2, $truecolor);
    } else {
	$gd = $self->$cmd($data2);
    }
    $gd;
}

sub gif_netpbm      { shift->_gif_external("netpbm", @_) }
sub gif_imagemagick { shift->_gif_external("imagemagick", @_) }

sub newFromGif_netpbm      {
    shift->_newFromGif_external("netpbm", "file", @_);
}
sub newFromGif_imagemagick {
    shift->_newFromGif_external("imagemagick", "file", @_);
}
sub newFromGifData_netpbm      {
    shift->_newFromGif_external("netpbm", "data", @_);
}
sub newFromGifData_imagemagick {
    shift->_newFromGif_external("imagemagick", "data", @_);
}

sub _wbmp {
    my $im = shift;
    GD::Wbmp::write($im, @_);
}

sub _data_from_file {
    my $file = shift;
    no strict 'refs'; # for perl 5.00503
    my $FH;
    my $do_close;
    if (ref $file eq 'GLOB' || UNIVERSAL::isa($file, 'IO::Handle')) {
	$FH = $file;
    } else {
	no strict 'refs';
	$FH = "FH";
	open($FH, $file) or die "Can't open $file: $!";
	$do_close = 1;
    }
    local $/ = undef;
    my $data = <$FH>;
    close $FH if $do_close;
    $data;
}

sub _3_pipe {
    my($in_ref, $cmd_ref) = @_;

    warn "Cmd: @$cmd_ref\n" if $GD::Convert::DEBUG;

    if ($ENV{MOD_PERL}) {
#	return _3_pipe_ipc_run(@_); # XXX see below
	warn "Using File::Temp interface instead of IPC::Open3"
	    if $GD::Convert::DEBUG;
	return _3_pipe_file_temp(@_);
    }

    require IPC::Open3;

    my $pid = IPC::Open3::open3(\*WTR, \*RDR, \*ERR, @$cmd_ref);
    die "Can't create process for @$cmd_ref" if !defined $pid;
    binmode RDR;
    binmode WTR;
    warn "About to write " . length($$in_ref) . " Bytes, signature is "
	. substr($$in_ref, 0, 3) . " ...\n"
	    if $GD::Convert::DEBUG > 1;
    print WTR $$in_ref;
    warn "... written\n" if $GD::Convert::DEBUG > 1;
    close WTR;

    my $out;
    {
	local $/ = undef;
	warn "About to read result ...\n" if $GD::Convert::DEBUG > 1;
	$out = scalar <RDR>;
	warn "... read " . length($out) . " bytes\n"
	    if $GD::Convert::DEBUG > 1;
    }
    close RDR;

    if ($GD::Convert::DEBUG) {
	local $/ = undef;
	my $err = scalar <ERR>;
	warn $err if defined $err && $err ne "";
    }

    $out;
}

sub _3_pipe_file_temp {
    my($in_ref, $cmd_ref) = @_;

    require File::Temp;
    my($fh, $filename) = File::Temp::tempfile
	(UNLINK => $GD::Convert::DEBUG < 10);
    print $fh $$in_ref;
    close $fh;

    my $cmd = "cat $filename | @$cmd_ref 2>/dev/null";
    warn "Cmd (for File::Temp): $cmd, length of data: ".length($$in_ref)."\n"
	if $GD::Convert::DEBUG;
    my $out = `$cmd`;

    if ($GD::Convert::DEBUG < 10) {
	unlink $filename;
    } else {
	warn "Keep temporary file $filename";
    }

    $out;
}

# XXX does not work with LANG=..utf-8
sub _3_pipe_ipc_run {
    my($in_ref, $cmd_ref) = @_;

    require IPC::Run;

    my $h = IPC::Run::start(
	$cmd_ref,
	'<pipe', \*WTR,
	'>pipe', \*RDR,
	'2>pipe', \*ERR
    ) or die "Can't create process for @$cmd_ref";
    binmode RDR;
    binmode WTR;
    warn "About to write " . length($$in_ref) . " Bytes, signature is " . substr($$in_ref, 0, 3) . " ...\n"
	if $GD::Convert::DEBUG > 1;
    print WTR $$in_ref;
    warn "... written\n" if $GD::Convert::DEBUG > 1;
    close WTR;

    my $out;
    {
	local $/ = undef;
	warn "About to read result ...\n" if $GD::Convert::DEBUG > 1;
	$out = scalar <RDR>;
	warn "... read " . length($out) . " bytes\n"
	    if $GD::Convert::DEBUG > 1;
    }
    close RDR;

    if ($GD::Convert::DEBUG) {
	local $/ = undef;
	my $err = scalar <ERR>;
	warn $err if defined $err && $err ne "";
    }

    IPC::Run::finish($h);

    $out;
}

package GD::Wbmp;

use constant WBMP_WHITE => 1;
use constant WBMP_BLACK => 0;

sub write {
    my($gd_image, $fg) = @_;

    # create the WBMP
    my($width, $height) = $gd_image->getBounds;
    my $wbmp = createwbmp($width, $height, WBMP_WHITE);
    if (!$wbmp) {
	die "Could not create WBMP";
    }

    # fill up the WBMP structure
    my $pos = 0;
    for(my $y=0; $y<$height; $y++) {
	for(my $x=0; $x<$width; $x++) {
	    if ($gd_image->getPixel($x, $y) == $fg) {
		$wbmp->{Bitmap}[$pos] = WBMP_BLACK;
	    }
	    $pos++;
	}
    }

    # write the WBMP as a string
    writewbmp($wbmp);

}

sub createwbmp {
    my($width, $height, $color) = @_;

    my $wbmp = {Bitmap => [],
		Width  => $width,
		Height => $height,
	       };

    for (my $i = 0; $i<$width*$height; $wbmp->{Bitmap}[$i++] = $color) {}

    $wbmp;
}

sub writewbmp {
    my($wbmp) = @_;

    my $out_buf = "";

    # Generate the header
    $out_buf .= "\0";         # WBMP Type 0: B/W, Uncompressed bitmap
    $out_buf .= "\0";         # FixHeaderField

    # Size of the image
    my($width, $height) = ($wbmp->{Width}, $wbmp->{Height});
    $out_buf .= putmbi($width);      # width
    $out_buf .= putmbi($height);     # height

    # Image data
    for(my $row=0; $row<$height; $row++) {
        my $bitpos=8;
        my $octet=0;
        for(my $col=0; $col<$width; $col++) {
            $octet |= (($wbmp->{Bitmap}[ $row*$width + $col] == 1)
		       ? WBMP_WHITE
		       : WBMP_BLACK) << --$bitpos;
            if ($bitpos == 0) {
                $bitpos=8;
                $out_buf .= pack("C", $octet);
                $octet=0;
            }
        }
        if ($bitpos != 8) {
	    $out_buf .= pack("C", $octet);
	}
    }

    $out_buf;
}

# putmbi
#
# Put a multibyte intgerer in some kind of output stream
# I work here with a function pointer, to make it as generic
# as possible. Look at this function as an iterator on the
# mbi integers it spits out.
#
sub putmbi {
    my($i) = @_;

    my $out_buf = "";
    my($cnt, $l, $accu);

    # Get number of septets
    $cnt = 0;
    $accu = 0;
    while ( $accu != $i ) {
        $accu += $i & 0x7f << 7*$cnt++;
    }

    # Produce the multibyte output
    for ($l = $cnt-1; $l>0; $l--) {
        $out_buf .= pack("C", 0x80 | ($i & 0x7f << 7*$l ) >> 7*$l);
    }

    $out_buf .= pack("C", $i & 0x7f);
    $out_buf;
}

1;

__END__

=head1 NAME

GD::Convert - additional output formats for GD

=head1 SYNOPSIS

    use GD;
    use GD::Convert qw(gif=gif_netpbm newFromGif=newFromGif_imagemagick wbmp);
    # or:
    require GD::Convert;
    import GD::Convert;
    ...
    $gd->ppm;
    $gd->xpm;
    $gd->gif;
    $gd->wbmp;
    ...
    $gd = GD::Image->newFromPpmData(...);
    $gd = GD::Image->newFromGif(...);

=head1 DESCRIPTION

This module provides additional output methods for the GD module:
C<ppm>, C<xpm>, C<wbmp>, C<gif_netpbm> and C<gif_imagemagick>, and also
additional constructors: C<newFromPpm>, C<newFromPpmData>,
C<newFromGif_netpbm>, C<newFromGifData_netpbm>,
C<newFromGif_imagemagick>, C<newFromGifData_imagemagick>.

The new methods go into the C<GD> namespace.

For convenience, it is possible to set shorter names for the C<gif>,
C<newFromGif> and C<newFromGifData> methods by providing one of the
following strings in the import list:

=over 4

=item gif=gif_netpbm

=item newFromGif=newFromGif_netpbm

=item newFromGifData=newFromGifData_netpbm

Use external commands from netpbm to load and create GIF images.

=item gif=gif_imagemagick

=item newFromGif=newFromGif_imagemagick

=item newFromGifData=newFromGifData_imagemagick

Use external commands from imagemagick to load and create GIF images.

=item gif=any

=item newFromGif=any

=item newFromGifData=any

Use any of the above methods to load and create GIF images.

=item wbmp

Create wbmp images. Only necessary for GD before version 1.26, but it
does not hurt if it is included with newer GD versions.

=back

The new methods and constructors:

=over 4

=item $ppmdata = $image->ppm

Take a GD image and return a string with a PPM file as its content.

=item $xpmdata = $image->xpm

Take a GD image and return a string with a XPM file as its content.

=item $gifdata = $image->gif_netpbm([...])

Take a GD image and return a string with a GIF file as its content.
The conversion will use the C<ppmtogif> binary from C<netpbm>. Make
sure that C<ppmtogif> is actually in your C<PATH>. If you specify
C<gif=gif_netpbm> in the C<use> line, then you can use the method name
C<gif> instead.

The gif_netpbm handles the optional parameter C<-transparencyhack>. If
set to a true value, a transparent GIF file will be produced. Note
that this will not work if the transparent color occurs also as a
normal color.

=item $gifdata = $image->gif_imagemagick

This is the same as C<gif_netpbm>, instead it is using the C<convert>
program of ImageMagick.

=item $image = GD::Image->newFromPpm($file, [$truecolor])

Create a GD image from the named ppm file or filehandle reference.
Only raw ppm files (signature P6) are supported.

=item $image = GD::Image->newFromPpmData($data, [$truecolor])

Create a GD image from the data string containing ppm data. Only raw
ppm files are supported.

=item $image = GD::Image->newFromGif_netpbm($file, [$truecolor]);

Create a GD image from the named file or filehandle reference using
external netpbm programs.

=item $image = GD::Image->newFromGifData_netpbm($file, [$truecolor]);

Create a GD image from the data string using external netpbm programs.

=item $image = GD::Image->newFromGif_imagemagick($file, [$truecolor]);

Create a GD image from the named file or filehandle reference using
external ImageMagick programs.

=item $image = GD::Image->newFromGifData_imagemagick($file, [$truecolor]);

Create a GD image from the data string using external ImageMagick
programs.

=back

You can set the variable C<$GD::Convert::DEBUG> to a true value to get
some information about external commands used while converting.

=head1 BUGS

Transparency will get lost in PPM images.

The transparency handling for GIF images is clumsy --- maybe the new
--alpha option of ppmtogif should be used.

The size of the created files should be smaller, especially of the XPM
output.

IPC::Open3 does not work if running under mod_perl. In this case
($ENV{MOD_PERL} detected) a scheme with temporary files is used. This
may be still flaky, better solutions are in the research.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=head1 COPYRIGHT

Copyright (c) 2001,2003 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<GD>, L<netpbm(1)>, L<convert(1)>.

