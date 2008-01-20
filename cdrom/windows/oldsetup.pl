#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: oldsetup.pl,v 1.7 2005/03/27 18:08:26 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use FindBin;
use lib "$FindBin::RealBin/BBBike/lib"; # for Win32Util
use File::Path;
use File::Spec;
use Config;

use strict;

my $destdir;

my $fc;
my $os;

my $mw;

if ($^O ne 'MSWin32') {
    require File::NCopy;
    $fc = new File::NCopy
	'recursive' => 1,
	'force_write' => 1,
    ;
    $destdir = "/usr/local/BBBike";
    $os = $^O;
} else {
    $destdir = File::Spec->catdir("C:", "BBBike");
    $os = "windows";
}

if ($^O eq 'MSWin32') {
    ask_tk();
} else {
    ask_console();
}

sub ask_tk {
    require Tk;
    $mw = MainWindow->new;
    my $f = $mw->Frame->pack;

    my @install_dirs;
    # preferred directory: C:\program files
    eval {
	require Win32Util;
	push @install_dirs, File::Spec->catdir(Win32Util::get_program_folder(), "BBBike");
    };
    warn $@ if $@;

    my @drives;
    eval {
	require Win32Util;
	@drives = Win32Util::get_drives("fixed,remote");
    };
    warn $@ if $@;
    if (!@drives) {
	@drives = qw(C: D: E: F:);
    }

    foreach my $drive (@drives) {
	push @install_dirs, File::Spec->catdir($drive, "BBBike");
    }

    $f->Label(-text => "Installieren in:")->pack(-anchor => "w");
    my $is_first = 1;
    foreach my $install_dir (@install_dirs) {
	$f->Button
	    (-text => $install_dir . ($is_first ? " (bevorzugt)" : ""),
	     -command => [sub {
			      my $drive = shift;
			      $destdir = $install_dir;
			      $mw->configure(-cursor => "watch");
			      do_install();
			      $mw->destroy;
			  }, $install_dir],
	     -anchor => "w",
	    )->pack(-anchor => "w", -fill => "x");
	$is_first = 0;
    }
    $mw->Button(-text => "Installation abbrechen",
		-command => sub {
		    $mw->destroy
		})->pack;
    Tk::MainLoop();
    exit(0);
}

sub ask_console {
    print STDERR "This will install BBBike to $destdir\n";
    print STDERR "Das Setup-Programm wird BBBike in $destdir installieren. Fortsetzen? (J/n) ";
    chomp(my $yn = <STDIN>);
    if ($yn =~ /^n/i) {
	exit(1);
    }
    do_install();
}

sub do_install {
    if ($mw) {
	my $t = $mw->Toplevel(-title => "Installation");
	$t->Label(-text => "Installation wird durchgeführt, bitte warten...")->pack;
	$t->Popup;
	$t->update;
    }
    warn "Installation in $destdir:\n";
    eval {
	mkpath([$destdir], 1, 0755);
	if (!-d $destdir) {
	    die "Can't create $destdir: $!";
	}

	xcopy(File::Spec->catdir($FindBin::RealBin, "BBBike"),
	      File::Spec->catdir($destdir, "BBBike"));
	xcopy(File::Spec->catdir($FindBin::RealBin, $os),
	      File::Spec->catdir($destdir, $os));
	xcopy(File::Spec->catdir($FindBin::RealBin, "bbbike.bat"), $destdir);
	my @args = (File::Spec->catdir($destdir, $os, $Config{'version'}, "bin", $Config{'archname'}, "perl"),
		    File::Spec->catdir($destdir, "BBBike", "install.pl"));
	warn "@args\n";
	system(@args);
    };
    if ($@) {
	warn "Installation abgebrochen: $@";
	if ($^O eq 'MSWin32') {
	    warn "RETURN drücken";
	    <STDIN>;
	}
    }
}

sub xcopy {
    my($from, $to) = @_;
    if ($fc) {
	$fc->copy($from, $to);
    } elsif ($^O eq 'MSWin32') {
	system("xcopy /E /I /Y $from $to");
    } else {
	die "Don't know how to copy from <$from> to <$to>";
    }
}

__END__
