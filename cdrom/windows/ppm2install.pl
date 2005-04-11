#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: ppm2install.pl,v 1.10 2002/07/13 20:56:41 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Online Office Berlin. All rights reserved.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://bbbike.sourceforge.net
#

=head1 NAME

ppm2install - direct installation of PPM packages

=head1 SYNOPSIS

    ppm2install.pl package.tar.gz [/path/to/perl]

=head1 DESCRIPTION

Installs PPM packages of ActiveState perl directly without the use of
the PPM program. This can be used for systems without ActiveState perl
installed (e.g. for CDROM installations outside of Windows). This is
tested with ActiveState build 613.

=cut

use Cwd;

use File::Path;
use File::Spec 0.8; # tmpdir
use File::Basename;

use Getopt::Long;

use Config;

use strict;

my $base       = "PPMpackages/5.6/MSWin32-x86-multi-thread";
my $local_base = "local-PPMpackages/5.6/MSWin32-x86-multi-thread";

my $make_ppm_root = sub {
    my $base = shift;
    ($^O eq 'MSWin32'
     ? do { (my $w = $base) =~ s|/|\\|g; "o:\\distfiles\\".$w }
#     ? do { (my $w = $base) =~ s|/|\\|g; "\\\\mom\\distfiles\\".$w }
     : "/usr/src/packages/SOURCES/$base");
};

my $ppm_root       = $make_ppm_root->($base);
my $ppm_local_root = $make_ppm_root->($local_base);

my $use_active_paths = 1;
my $arch_path;
my $lib_path;
my $script_path;
my $pretend = 0;
my $dest;

my $top;
my $tk_text;

if (!GetOptions("ppmroot=s" => \$ppm_root,
		"activepaths!" => \$use_active_paths,
		"arch=s" => \$arch_path,
		"lib=s"  => \$lib_path,
		"script=s" => \$script_path,
		"n!" => \$pretend,
		"dest=s" => \$dest,
	       )) {
    die <<EOF;
usage: $0 [-ppmroot dir] [-blib dir] [-n]
	[-activepaths] [-arch path] [-lib path] [-script path]
	ppm-package.tgz perldir

-ppmroot dir:    directory holding archives
-n:              just show commands, do not execute them
-activepaths:    use paths of active $^X (default if perldir is missing)
-arch path:      directory for architecture-dependent perl files
-lib path:       directory for architecture-independent perl files
-script path:    directory for perl scripts
-dest perldir:   package should be installed to perl directory
ppm-package.tgz: blib archive or directory of module
EOF
}

my @src;
my $src  = shift;
if (!defined $src) {
    if ($^O eq 'MSWin32') {
	# force installation of Tk first...
	if (!eval { require Tk; 1 }) {
	    @src = "Tk";
	}
    }
    if (!@src) {
	@src = get_src();
	if (!@src) {
	    die "Package or blib to install missing";
	}
    }
} else {
    @src = $src;
}

if (defined $dest) {
    $use_active_paths = 0;
}
if (!defined $dest && !$use_active_paths) {
    die "Top perl directory $dest missing";
}
if ($use_active_paths && $^O ne 'MSWin32') {
    die "-activepaths works only within Windows";
}

if (!$use_active_paths) {
    if (!-d $dest || !-w $dest) {
	die "$dest does not exist or is not writable";
    }
}
if ($^O ne 'MSWin32' && $dest !~ m|^/|) {
    $dest = File::Spec->rel2abs($dest);
}

my $tmpdir = File::Spec->catfile(File::Spec->tmpdir, "ppm2install-tmp");

my $fc;
eval {
    die "Don't use NCopy";
    require File::NCopy;
    $fc = new File::NCopy
	'recursive' => 1,
	'force_write' => 1,
    ;
};
if (!$fc) {
    warn "$@\nTry using fallback.";
}

my $cwd = cwd;
# try as complete path first
foreach my $src (@src) {
    chdir $cwd || die "Can't chdir to $cwd: $!";

    if (!-r $src) {

	my $search_in_ppm_root = sub {
	    my $ppm_root = shift;

	    # now try the package in the ppm root directory
	    $src = File::Spec->catfile($ppm_root, $src);
	    if (!-r $src) {
		# probably the user did not specify the extension
		$src .= ".tar.gz";
		if (!-r $src) {
		    return undef;
		}
	    }
	    $src;
	};

	my $try_src = $search_in_ppm_root->($ppm_root);
	if (!$try_src) {
	    $search_in_ppm_root->($ppm_local_root);
	    if (!$try_src) {
		die "Can't find $src";
	    }
	}
	$src = $try_src;
    } else {
	$src = File::Spec->rel2abs($src);
    }

    if ($tk_text) {
	$tk_text->insert("end", "\n" . $src . " ... ");
	$tk_text->see("end");
    }

    my $blib_install = (-d $src); # it's probably a blib directory

    unless ($blib_install) {
	warn "rm old tree $tmpdir\n";
	if (!$pretend) {
	    rmtree([$tmpdir], 1, 0);
	}
	warn "make new tree in $tmpdir\n";
	if (!$pretend) {
	    mkpath([$tmpdir], 1, 0775);
	}
    }

    if ($blib_install) {
	chdir $src || die "Can't chdir to $src: $!";
    } else {
	chdir $tmpdir || die "Can't chdir to $tmpdir: $!";
	warn "Untar $src in $tmpdir\n";
	if (!$pretend) {
	    if ($^O eq 'MSWin32') {	    # XXX anderer Test
		require Archive::Tar;
		my $tar = Archive::Tar->new($src, 1);
		$tar->extract($tar->list_files);
	    } else {
		system("tar", "xfvzp", $src);
	    }
	}
    }

    if ($use_active_paths) {
	$arch_path = $Config{"installsitearch"} unless defined $arch_path;
	$lib_path = $Config{"installsitelib"} unless defined $lib_path;
	$script_path = $Config{"installscript"} unless defined $script_path;
    }
    if (!defined $arch_path) {
	# Default for ActiveState Perl/Windows
	$arch_path   = File::Spec->catdir($dest, qw/site lib/);
	$lib_path    = File::Spec->catdir($dest, qw/site lib/);
	$script_path = File::Spec->catdir($dest, qw/site bin/);
    }

    do_copy(File::Spec->catdir("blib", "arch"),   $arch_path,
	    "Copy arch files to $arch_path");
    do_copy(File::Spec->catdir("blib", "lib"),    $lib_path,
	    "Copy lib files to $lib_path");
    do_copy(File::Spec->catdir("blib", "script"), $script_path,
	    "Copy script files to $script_path");

    if ($tk_text) {
	$tk_text->insert("end", "OK");
    }
}

if ($tk_text) {
    $tk_text->insert("end", "\nREADY!");
    $tk_text->see("end");
    my $weiter;
    $top->Button(-text => "Close",
		 -command => sub { $weiter = 0 })->pack;
    $top->protocol('WM_DELETE_WINDOW', sub { $weiter = 0 });
    $tk_text->waitVariable(\$weiter);
    $top->destroy;
}

sub do_copy {
    my($from, $to, $message) = @_;
    warn "$message\n";
    if (!$pretend) {
	if ($fc) {
	    $fc->copy($from, dirname($to)); # XXX check it!
	} elsif ($^O ne 'MSWin32') {
	    system("cp -Rpv $from/* $to");
	} else {
	    system("xcopy /E /I $from $to");
	}
    }
}

sub get_src {
    my @src;
    require Tk;
    $top = MainWindow->new;

    my $make_lb = sub {
	my $ppm_root = shift;
	my $lb = $top->Scrolled("Listbox",
				-selectmode => "multiple",
				-scrollbars => "osoe",
				-bg => "white",
				-exportselection => 0,
			       )->pack(-fill => "both", -expand => 1);
	foreach my $tgz (glob("$ppm_root/*.tar.gz"),
			 glob("$ppm_root/*.tgz")) {
	    $lb->insert("end", basename($tgz));
	}
	$lb;
    };

    $top->Label(-text => "Activestate ppm modules:")->pack;
    my $global_lb = $make_lb->($ppm_root);

    $top->Label(-text => "Local ppm modules:")->pack;
    my $local_lb  = $make_lb->($ppm_local_root);

    my $weiter;
    my $bf = $top->Frame->pack(-fill => "x");
    $bf->Button(-text => "Ok",
		-command => sub { $weiter = 1 })->pack(-side => "left");
    $bf->Button(-text => "Cancel",
		-command => sub { $weiter = 0 })->pack(-side => "left");
    $top->protocol('WM_DELETE_WINDOW', sub { $weiter = 0 });
    $top->waitVariable(\$weiter);
    if ($weiter) {
	my(@sel) = $global_lb->curselection;
	foreach (@sel) {
	    my $base = $global_lb->get($_);
	    push @src, "$ppm_root/$base";
	}
	@sel = $local_lb->curselection;
	foreach (@sel) {
	    my $base = $local_lb->get($_);
	    push @src, "$ppm_local_root/$base";
	}
    }

    $_->destroy for $top->children;

    require Tk::ROText;
    $tk_text = $top->Scrolled("ROText", -scrollbars => "osoe"
			     )->pack(-fill => "both", -expand => 1);

    @src;
}
__END__
