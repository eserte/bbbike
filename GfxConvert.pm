# -*- perl -*-

#
# $Id: GfxConvert.pm,v 1.11 2003/11/13 00:06:42 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998,2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package GfxConvert;

use BBBikeUtil;
use strict;
use vars qw(%tmpfiles $VERBOSE %devices $pscap_called %convsub);

%convsub =
  ('ps' => { 'ppm'  => \&ps2ppm,
	     'gif'  => \&ps2gif,
	     'jpeg' => \&ps2jpeg,
	     'png'  => \&ps2png,
	   },
   'xwd' => { 'ppm'  => \&xwd2ppm,
	      'gif'  => \&xwd2gif,
	      'jpeg' => \&xwd2jpeg,
	      'png'  => \&xwd2png,
	   },
  );

sub convert {
    my($infmt, $outfmt, $infile, $outfile, %args) = @_;
    my $convsub = $convsub{$infmt}->{$outfmt};
    if (defined $convsub) {
	$convsub->($infile, $outfile, %args);
    } else {
	die "Konversion von $infmt nach $outfmt kann nicht durchgeführt werden.";
    }
}

######################################################################
# Postscript to anything
#
sub ps2ppm {
    my($infile, $outfile, %args) = @_;
    my $error_preamble = "Die PPM-Datei kann nicht erstellt werden. Grund: ";
    if (!is_in_path("gs")) {
	die $error_preamble . "Ghostscript wird benötigt.";
    }
    my(@cmd) = (qw(gs -q -sDEVICE=ppmraw -DNOPAUSE));
    if ($args{-res}) {
	push @cmd, "-r$args{-res}";
    }
    push @cmd, ("-sOutputFile=$outfile",
		qw(--),
		$infile);
    warn "Executing @cmd ..." if $VERBOSE;
    if (system(@cmd) != 0) {
	die $error_preamble .
	    "Die Konvertierung mit gs fehlgeschlagen (exit: $?)";
    }

    return _ppm_post_transform($outfile, $outfile, %args);
}

sub _ppm_post_transform {
    my($infile, $outfile, %args) = @_;

    if (defined $args{'-autocrop'}) {
	if (!is_in_path("pnmcrop")) {
	    warn "Warnung: pnmcrop ist nicht vorhanden, kein Autocrop möglich.";
	} else {
	    my $tmpfile = "/tmp/GfxConvert-ps2ppm.$$.ppm";
	    $tmpfiles{$tmpfile}++;
	    # Zweimal pnmcrop aufrufen... beim ersten Mal wird der
	    # schwarze Streifen am linken Rand entfernt (Bug in gs?),
	    # beim zweiten Mal wird der eigentliche Schnitt durchgeführt.
	    my @cmd = (["pnmcrop", "-left", $outfile], "|",
		       ["pnmcrop"], ">", $tmpfile);
	    if (!run_command(@cmd)) {
		warn "Warnung: Fehler beim Aufruf von pnmrotate.";
	    } else {
		warn "Mv from $tmpfile to $outfile ..." if $VERBOSE;
		require File::Copy;
		File::Copy::mv($tmpfile, $outfile);
	    }
	}
    }

    if (defined $args{'-rotate'}) {
	if (!is_in_path("pnmrotate")) {
	    warn "Warnung: pnmrotate ist nicht vorhanden, keine Umwandlung nach Landscape.";
	} else {
	    my $tmpfile = "/tmp/GfxConvert-ps2ppm.$$.ppm";
	    $tmpfiles{$tmpfile}++;
	    my @cmd = (["pnmrotate", $args{'-rotate'}, $outfile],
		       ">", $tmpfile);
	    if (!run_command(@cmd)) {
		warn "Warnung: Fehler beim Aufruf von pnmrotate.";
	    } else {
		warn "Mv from $tmpfile to $outfile ..." if $VERBOSE;
		require File::Copy;
		File::Copy::mv($tmpfile, $outfile);
	    }
	}
    }

    if (defined $args{'-mapcolor'}) {
	if (!is_in_path("ppmchange")) {
	    warn "Warnung: ppmchange ist nicht vorhanden, keine Anpassung der Farben.";
	} else {
	    my $tmpfile = "/tmp/GfxConvert-ps2ppm.$$.ppm";
	    $tmpfiles{$tmpfile}++;
	    my @arg = %{ $args{'-mapcolor'} };
	    my @cmd = (["ppmchange", @arg, $outfile], ">", $tmpfile);
	    if (!run_command(@cmd)) {
		warn "Warnung: Fehler beim Aufruf von ppmchange.";
	    } else {
		warn "Mv from $tmpfile to $outfile ..." if $VERBOSE;
		require File::Copy;
		File::Copy::mv($tmpfile, $outfile);
	    }
	}
    }

    1;
}

sub ps2gif {
    my($infile, $outfile, %args) = @_;
    my $error_preamble = "Die GIF-Datei kann nicht erstellt werden. Grund: ";
    if (!is_in_path("ppmtogif")) {
	die $error_preamble .
	    "ppmtogif aus der netpbm-Distribution wird benötigt.\n";
    }
    my $ppmfile = "/tmp/GfxConvert.$$.ppm";
    $tmpfiles{$ppmfile}++;
    ps2ppm($infile, $ppmfile, %args);
    my @cmd = ( ["ppmtogif", $ppmfile], ">", $outfile );
    if (!run_command(@cmd)) {
	die $error_preamble .
	    "Konvertierung mit ppmtogif fehlgeschlagen (exit: $?)";
    }
    1;
}

sub ps2jpeg {
    my($infile, $outfile, %args) = @_;
    my $quality = $args{-quality} || 70;
    my $error_preamble = "Die JPEG-Datei kann nicht erstellt werden. Grund: ";
    if (!is_in_path("cjpeg")) {
	die $error_preamble . "cjpeg aus der JPEG-Distribution wird benötigt.";
    }
    my $ppmfile = "/tmp/GfxConvert.$$.ppm";
    $tmpfiles{$ppmfile}++;
    ps2ppm($infile, $ppmfile, %args);
    my @cmd = (["cjpeg", "-quality", $quality, "$ppmfile"], ">", $outfile);
    if (!run_command(@cmd)) {
	die $error_preamble .
	    "Konvertierung mit cjpeg fehlgeschlagen (exit: $?)";
    }
    1;
}

sub ps2png {
    my($infile, $outfile, %args) = @_;
    my $colormode = $args{-colormode} || 'color';
    my $depth     = $args{-depth} || 24;
    my $error_preamble = "Die PNG-Datei kann nicht erstellt werden. Grund: ";

    if (0 && is_in_path("pnmtopng")) { # XXX pnmtopng ist buggy????
	my $ppmfile = "/tmp/GfxConvert.$$.ppm";
	$tmpfiles{$ppmfile}++;
	ps2ppm($infile, $ppmfile, %args);
	my $cmd = "pnmtopng $ppmfile > $outfile";
	warn "Executing $cmd ..." if $VERBOSE;
	if (system($cmd) != 0) {
	    die $error_preamble . 
	      "Konvertierung mit pnmtopng fehlgeschlagen (exit: $?)";
	}
	return 1;
    }

    # Wenn nicht, dann mit ghostscript versuchen. Allerdings werden hier
    # nicht die ganzen schönen Features wie crop etc. verwendet.
    # XXX überprüfen, ob gs png kann. und welches png.
    if (!is_in_path("gs")) {
	die $error_preamble . "Ghostscript wird benötigt.";
    }
    my $dev;
    if ($colormode eq 'mono') {
	$dev = 'pngmono';
    } elsif ($colormode eq 'gray') {
	$dev = 'pnggray';
    } else {
	if ($depth == 4) {
	    $dev = 'png16';
	} elsif ($depth == 8) {
	    $dev = 'png256';
	} else {
	    $dev = 'png16m';
	}
    }
    my(@cmd) = (qw(gs -q -DNOPAUSE), "-sDEVICE=$dev");
    if ($args{-res}) {
	push @cmd, "-r$args{-res}";
    }
    push @cmd, ("-sOutputFile=$outfile",
		qw(--),
		$infile);
    warn "Executing @cmd ..." if $VERBOSE;
    if (system(@cmd) != 0) {
	die $error_preamble .
	    "Die Konvertierung mit gs fehlgeschlagen (exit: $?)";
    }
    # XXX der ganze andere Wust aus ps2ppm fehlt hier...
    1;
}

# Füllt das Hash %devices mit den eingebauten Devices von Ghostscript zurück.
# Die Device-Namen sind in den Keys des Hashs enthalten.
# XXX Wird noch nicht verwendet.
sub pscap {
    return if $pscap_called;
    $pscap_called++;
    if (!is_in_path("gs")) {
	die "Ghostscript wird benötigt.";
    }
    %devices = ();
    open(GS, "gs -h|");
    my $in_avail_dev;
    while(<GS>) {
	if ($in_avail_dev) {
	    if (/^\s/) {
		s/^\s+//;
		my(@dev) = split;
		foreach (@dev) {
		    $devices{$_}++;
		}
	    } else {
		last;
	    }
	} elsif (/Available devices/i) {
	    $in_avail_dev++;
	}
    }
    close GS;
}

sub transform_image {
    my($in_file, $out_file, %args) = @_;
    my $in_mime  = $args{'-in_mime'}  || "image/gif"; #die "Missing mime type for in file";
    my $out_mime = $args{'-out_mime'} || "image/gif"; #die "Missing mime type for out file";
#    my $colormode = $args{-colormode} || 'color';

    require GD;
    open(GIF, $in_file)
      or die "Die Datei $in_file konnte nicht geöffnet werden: $!";
    binmode GIF;
    my $in_img;
    if ($in_mime eq 'image/jpeg') {
	$in_img = GD::Image->newFromJpeg(\*GIF);
    } elsif ($in_mime eq 'image/png') {
	$in_img = GD::Image->newFromPng(\*GIF);
    } else {
	$in_img = GD::Image->newFromGif(\*GIF);
    }
    my($orig_width, $orig_height) = $in_img->getBounds;
    close GIF;

    my $width  = $args{-width}  || $orig_width;
    my $height = $args{-height} || $orig_height;

    my $out_img = new GD::Image($width, $height);
    $out_img->copyResized($in_img, 0, 0, 0, 0,
			  $width, $height, $orig_width, $orig_height);
    open(OUT, ">$out_file") or
      die "Auf die Datei $out_file kann nicht geschrieben werden: $!";
    binmode OUT;
    print OUT ($in_mime eq 'image/jpeg' ? $out_img->jpeg :
	       ($in_mime eq 'image/png' ? $out_img->png  :
		                          $out_img->gif  ));
    close OUT;
}

######################################################################
# XWD to anything
#
sub xwd2ppm {
    my($infile, $outfile, %args) = @_;
    my $error_preamble = "Die PPM-Datei kann nicht erstellt werden. Grund: ";
    if (!is_in_path("xwdtopnm")) {
	die $error_preamble . "xwdtopnm wird benötigt.";
    }
    my $cmd = "xwdtopnm < $infile > $outfile";
    warn "Executing $cmd ..." if $VERBOSE;
    if (system($cmd) != 0) {
	die $error_preamble .
	    "Die Konvertierung mit xwdtopnm fehlgeschlagen (exit: $?)";
    }

    return _ppm_post_transform($outfile, $outfile, %args);
}

sub xwd2gif {
    my($infile, $outfile, %args) = @_;
    my $error_preamble = "Die GIF-Datei kann nicht erstellt werden. Grund: ";
    if (!is_in_path("ppmtogif")) {
	die $error_preamble .
	  "ppmtogif aus der netpbm-Distribution wird benötigt.\n";
    }
    my $ppmfile = "/tmp/GfxConvert.$$.ppm";
    $tmpfiles{$ppmfile}++;
    xwd2ppm($infile, $ppmfile, %args);
    my @cmd = (["ppmtogif", $ppmfile], ">", $outfile);
    if (!run_command(@cmd)) {
	die $error_preamble .
	    "Konvertierung mit ppmtogif fehlgeschlagen (exit: $?)";
    }
    1;
}

sub xwd2jpeg {
    my($infile, $outfile, %args) = @_;
    my $quality = $args{-quality} || 70;
    my $error_preamble = "Die JPEG-Datei kann nicht erstellt werden. Grund: ";
    if (!is_in_path("cjpeg")) {
	die $error_preamble . "cjpeg aus der JPEG-Distribution wird benötigt.";
    }
    my $ppmfile = "/tmp/GfxConvert.$$.ppm";
    $tmpfiles{$ppmfile}++;
    xwd2ppm($infile, $ppmfile, %args);
    my @cmd = (["cjpeg", "-quality", $quality, "$ppmfile"],
	       ">", $outfile);
    if (!run_command(@cmd)) {
	die $error_preamble .
	    "Konvertierung mit cjpeg fehlgeschlagen (exit: $?)";
    }
    1;
}

sub xwd2png {
    my($infile, $outfile, %args) = @_;
    my $colormode = $args{-colormode} || 'color';
    my $depth     = $args{-depth} || 24;
    my $error_preamble = "Die PNG-Datei kann nicht erstellt werden. Grund: ";

    if (1 && is_in_path("pnmtopng")) { # XXX pnmtopng ist buggy???? oder nicht?
	my $ppmfile = "/tmp/GfxConvert.$$.ppm";
	$tmpfiles{$ppmfile}++;
	xwd2ppm($infile, $ppmfile, %args);
	my $cmd = "pnmtopng $ppmfile > $outfile";
	warn "Executing $cmd ..." if $VERBOSE;
	if (system($cmd) != 0) {
	    die $error_preamble . 
	      "Konvertierung mit pnmtopng fehlgeschlagen (exit: $?)";
	}
	return 1;
    }

    # XXX do not duplicate, see ppm2png

    # Wenn nicht, dann mit ghostscript versuchen. Allerdings werden hier
    # nicht die ganzen schönen Features wie crop etc. verwendet.
    # XXX überprüfen, ob gs png kann. und welches png.
    if (!is_in_path("gs")) {
	die $error_preamble . "Ghostscript wird benötigt.";
    }
    my $dev;
    if ($colormode eq 'mono') {
	$dev = 'pngmono';
    } elsif ($colormode eq 'gray') {
	$dev = 'pnggray';
    } else {
	if ($depth == 4) {
	    $dev = 'png16';
	} elsif ($depth == 8) {
	    $dev = 'png256';
	} else {
	    $dev = 'png16m';
	}
    }
    my(@cmd) = (qw(gs -q -DNOPAUSE), "-sDEVICE=$dev");
    if ($args{-res}) {
	push @cmd, "-r$args{-res}";
    }
    push @cmd, ("-sOutputFile=$outfile",
		qw(--),
		$infile);
    warn "Executing @cmd ..." if $VERBOSE;
    if (system(@cmd) != 0) {
	die $error_preamble . 
	  "Die Konvertierung mit gs fehlgeschlagen (exit: $?)";
    }
    # XXX der ganze andere Wust aus ps2ppm fehlt hier...
    1;
}

# Maybe move to BBBikeUtil
sub run_command {
    my @cmd = @_;
    my $cmd = join(" ",
		   map { s/\#/\\\#/g; $_ } # escape comments
		   map { (ref $_ eq 'ARRAY' ?
			  @$_ :
			  $_
			 ) }
		   @cmd
		  );
    print STDERR "Executing $cmd " if $VERBOSE;
    if (eval { require IPC::Run; 1 }) {
	print STDERR " using IPC::Run...\n" if $VERBOSE;
	IPC::Run::run(@cmd);
    } else {
	print STDERR " using system()...\n" if $VERBOSE;
	my $ret = system $cmd;
	!$ret;
    }
}

1;
