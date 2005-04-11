#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: perlinstall.pl,v 1.1 1999/09/30 22:37:49 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use PerlInstall;
use Config;
use File::Copy;
use File::Basename;
use File::Path;

$show = 0;

$destdir = shift || "/usr/tmp/cdrom";

$pi = new PerlInstall;
$pi->get_std_perl_libs;
$pi->get_custom_perl_libs
    (["libwww-perl",
      "Tk",
      "Tk::JPEG",
      "Tk::Getopt",
      "Tk::FontDialog",
      "Tk::HistEntry",
      "Tk::GBARR",
      "Tk::Pod",
      "Net",
      "MLDBM",
      "Storable",
      "Mail",
      "GD",
      "X11::Protocol",
      "URI",
      "HTML::Parser",
      "CGI",
      "Devel::Peek",
      "String::Approx",
      "Tie::Watch",
      ]);
if ($^O =~ /freebsd/) {
    $pi->set_assignment
	([
	  "^$Config{installsitelib}" => "$destdir/freebsd/lib/perl/site",
	  "^$Config{installprivlib}" => "$destdir/freebsd/lib/perl",
	  "^$Config{installman3dir}" => "$destdir/freebsd/man/man3",
	  "^$Config{installman1dir}" => "$destdir/freebsd/man/man1",
	  "^$Config{installbin}"     => "$destdir/freebsd/bin",
	  "^/usr/bin"       => "$destdir/freebsd/bin",
	  "^/usr/local/bin" => "$destdir/freebsd/bin",
	  "^/usr/lib"       => "$destdir/freebsd/lib",
	]);
} elsif ($^O =~ /linux/) {
    $pi->set_assignment
	([
	  "^$Config{installsitelib}" => "$destdir/linux/lib/perl/site",
	  "^$Config{installprivlib}" => "$destdir/linux/lib/perl",
	  "^$Config{installman3dir}" => "$destdir/linux/man/man3",
	  "^$Config{installman1dir}" => "$destdir/linux/man/man1",
	  "^$Config{installbin}"     => "$destdir/freebsd/bin",
	  "^/usr/bin"       => "$destdir/linux/bin",
	  "^/usr/local/bin" => "$destdir/linux/bin",
	  "^/lib"           => "$destdir/linux/lib",
	  "^/usr/lib"       => "$destdir/linux/lib",
	]);
} elsif ($^O =~ /mswin/i) {
    $pi->set_assignment
	([
	  "^$Config{installsitelib}" => "$destdir/windows/lib/perl/site",
	  "^$Config{installprivlib}" => "$destdir/windows/lib/perl",
	  "^$Config{installman3dir}" => "$destdir/windows/man/man3",
	  "^$Config{installman1dir}" => "$destdir/windows/man/man1",
	  "^$Config{installbin}"     => "$destdir/freebsd/bin",
	  "^/usr/bin"       => "$destdir/windows/bin",
	  "^/usr/local/bin" => "$destdir/windows/bin",
	  "^/lib"           => "$destdir/windows/lib",
	  "^/usr/lib"       => "$destdir/windows/lib",
	]);
    $pi->{ShLib} = [
		   ];
} else {
    die "Unknown os $^O";
}

foreach my $f (@{ $pi->{ShLib} },
	       $pi->{Executable},
	       @{ $pi->{StdLibs} },
	       @{ $pi->{CustomLibs} }) {
    my $trf = $pi->translate_path($f, 1);
    if (defined $trf) {
	if ($show) {
	    warn "copy $f => $trf...\n";
	} else {
	    if (!-d dirname($trf)) {
		mkpath([dirname($trf)], 1, 0755);
	    }
	    copy $f, $trf;
	    chmod(((stat($f))[2]), $trf);
	}
    }
}

#use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([$pi],[]); # XXX


__END__
