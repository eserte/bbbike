#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2000,2001,2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

=head1 NAME

link_ext_mod.pl - link or copy external modules

=head1 DESCRIPTION

Link or copy external modules from ~/lib/perl to ~/src/bbbike/lib

=head1 TODO

 * sollte auch Config{archname} und evtl. auch
 * perl-Version beachten

=cut

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

use File::Copy qw(cp);
use File::Find;
use File::Basename;
use File::Path;
use File::Spec 0.8;
use Getopt::Long;
use Cwd;
use Cwd qw(abs_path);

use BBBikeUtil qw(is_in_path save_pwd);

# be nice:
umask 2;

my $verbose = 0;
my $lib_perl = abs_path("$ENV{HOME}/lib/perl");
my $do_exec = 1;
my $do_rellink = 1;
my $do_copy = 0;
my $force = 0;

if (!GetOptions("n" => sub { $do_exec = 0; $verbose = 1; },
		"v+" => \$verbose,
		"f" => \$force,
		"libperldir=s" => \$lib_perl,
		"rellink!" => \$do_rellink,
		"copy!" => \$do_copy,
	       )) {
    die "usage: $0 [-n] [-v [-v ...]] [-f] [-[no]rellink] [-copy] [-libperldir ~/lib/perl]";
}

die "Works only on the source system and not on Win32"
    if $^O eq 'MSWin32';

my $make = $^O =~ m{bsd}i ? "make" : "pmake";
if (!is_in_path($make)) {
    die "The $make program is not available.\n";
}

# Vorgehensweise:
# * mit echoextmodcpan und echoextmodperl feststellen, welche Module gelinkt
#   werden

chdir "$FindBin::RealBin/.." or die "chdir: $!";
#system_or_print($^X, "Makefile.PL");

die "Makefile is not available, did you run 'perl Makefile.PL'?"
    if !-r "Makefile";

# XXX The echo rules could be replaced by using "make -V..."
my($extmodcpantop) = `$make echoextmodcpantop`;
chomp $extmodcpantop;

my($extmodcpan) = `$make echoextmodcpan`;
chomp $extmodcpan;
my @extmodcpan = split /\s+/, $extmodcpan;

my($extmodperltop) = `$make echoextmodperltop`;
chomp $extmodperltop;

my($extmodperl) = `$make echoextmodperl`;
chomp $extmodperl;
my @extmodperl = split /\s+/, $extmodperl;

# * für jedes dieser Module blib/lib/* ohne .exists feststellen

my @lib_files;
my @lib_dirs;
foreach my $top_dir ($extmodcpantop, $extmodperltop) {
    foreach my $mod ($top_dir eq $extmodcpantop
		     ? @extmodcpan
		     : @extmodperl) {
	my $blib = "$top_dir/$mod/blib";
	my $blib_lib = "$top_dir/$mod/blib/lib";
	if (!-d $blib_lib) {
	    warn "$blib_lib does not exist!";
	    next;
	}

	find(sub {
		 return if /^(\.|\.\.|\.exists)$/;
		 (my $base = $File::Find::name) =~ s|^$blib_lib/||;
		 if (-f $_) {
		     push @lib_files, $base;
		 }
	     }, $blib_lib);
    }
}

{
    my %lib_dirs;
    foreach my $f (@lib_files) {
	my $dir = dirname($f);
	if ($dir ne ".") {
	    $lib_dirs{$dir}++;
	}
    }
    @lib_dirs = keys %lib_dirs;
}

# * Warnung, falls .so/.bs existiert XXX

# * für alle *.pm (u.a.):

warn "Directories:\n" if $verbose;
chdir "lib" or die $!;
for my $f (sort @lib_dirs) {
    if (-d $f) {
	# OK
    } elsif (-e $f && !-d $f) {
	warn "$f exists, but is not a directory!";
    } else {
	if ($do_exec) {
	    mkpath([$f], $verbose, 0755);
	} else {
	    warn "Create directory $f, mode 0755...\n";
	}
    }
}

warn "Files:\n" if $verbose;
for my $f (sort @lib_files) {

    my $abssrc = "$lib_perl/$f";
    my $dir = ($f !~ m|/| ? "" : "/" . dirname($f));
    my $src = File::Spec->abs2rel($abssrc, cwd.$dir);
    print STDERR "$f " if $verbose;
    if ($verbose >= 2 && $do_exec) {
	print STDERR "<- $src\n";
    }

    #   * nachgucken, ob in lib/perl eine Entsprechung existiert (ansonsten
    #     Warnung!)
    {
	my $do_next;
	save_pwd {
	    my $destdir = cwd . $dir;
	    if (!chdir $destdir) {
		if ($do_exec) {
		    die "Can't chdir to $destdir: $!";
		} else {
		    warn "$destdir does not exist yet, cannot check...\n";
		}
	    } else {
		if (!-f $src) {
		    warn "$src does not exist\n";
		    $do_next = 1;
		    return;
		}
	    }
	};
	next if $do_next;
    }

    #   * nachgucken, ob die Dateien in lib/perl nicht älter sind (ansonsten
    #     Warnung!) XXX

    #   * feststellen, ob die Position unter bbbike leer ist oder nur ein
    #     symlink (wenn nicht, Abbruch!)
    if (!$do_copy) {
	if (-e $f && !-l $f) {
	    warn "$f is not empty and not a symlink\n";
	    next;
	}

	if (-l $f) {
	    if (-e $f) {
		my $link = readlink($f);
#	    if (File::Spec->rel2abs($link) ne $src) {
		if ($link ne $src) {
		    if ($f) {
			print STDERR "Remove old link $f because " . File::Spec->rel2abs($link) . " ne ". $src . "\n" if $verbose;
			if ($do_exec) {
			    unlink $f;
			}
		    } else {
			warn "Link mismatch: $link <=> $src\n";
			next;
		    }
		} else {
		    # ok, nothing to do
		    next;
		}
	    } else {
		print STDERR "Remove old link $f because unexisting target\n" if $verbose;
		if ($do_exec) {
		    unlink $f;
		}
	    }
	}
    }

    #   * Erzeugen des Symlinks
    if ($do_exec) {
	if ($do_copy) {
	    print STDERR "<- $abssrc" if $verbose;
	    cp $abssrc, $f
		or die "Cannot copy $abssrc to $f: $!";
	} else {
	    print STDERR "<- $src" if $verbose;
	    symlink $src, $f
		or die "Cannot symlink $f -> $src: $!";
	}
    } else {
	print STDERR "<- $src" if $verbose;
    }
    print STDERR "\n" if $verbose;
}

# REPO BEGIN
# REPO NAME system_or_print /home/e/eserte/src/repository 
# REPO MD5 077305e5aeadf69bc092419e95b33d14

=head2 system_or_print(cmd, param1, ...)

=for category System

If the global variable $do_exec is set to a true value, then execute the
given command with its parameters, otherwise print the command string to
standard error. If Tk is running and there is a LogWindow, then the command
string is logged to this widget.

=cut

sub system_or_print {
    my(@cmd) = @_;

    my $log_window;
    if (defined &Tk::MainWindow::Existing) {
	my($mw) = Tk::MainWindow::Existing();
	if (defined $mw and
	    Tk::Exists($mw->{LogWindow})) {
	    $log_window = $mw->{LogWindow};
	}
    }
    if ($log_window) {
	$log_window->insert('end', join(" ", @cmd));
	$log_window->see('end');
	$log_window->update;
    }

    if ($do_exec) {
	system @cmd;
    } else {
	print STDERR join(" ", @cmd), "\n";
    }
}
# REPO END

__END__
