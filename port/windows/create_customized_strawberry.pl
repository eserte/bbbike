#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011,2012,2015 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
my $bbbikesrc_dir; BEGIN { $bbbikesrc_dir = "$FindBin::RealBin/../.." }
use lib (
	 $bbbikesrc_dir,
	 "$bbbikesrc_dir/lib",
	);

use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use Cwd qw(realpath);
use Getopt::Long;

use BBBikeUtil qw(save_pwd is_in_path);

die "Sorry, mixing cygwin perl and Strawberry Perl does not work at all"
    if $^O eq 'cygwin';

my $patch_exe;

my $strawberry_dir;
my $strawberry_ver;
my $bbbikedist_dir;
GetOptions(
	   "strawberrydir=s" => \$strawberry_dir,
	   "strawberryver=s" => \$strawberry_ver,
	   "bbbikedistdir=s" => \$bbbikedist_dir,
	  )
    or usage();
$strawberry_dir or usage();
$bbbikedist_dir or usage();
my $strawberry_zipfile = shift; # optional

# Detect Strawberry Perl version, either from Config_heavy.pl or
# parsing the zip file name
{
    if ($strawberry_zipfile && $strawberry_zipfile =~ m{strawberry-perl-([\d\.]+)}) {
	$strawberry_ver = $1;
    } else {
	eval {
	    my $config_heavy = "$strawberry_dir/perl/lib/Config_heavy.pl";
	    open my $fh, $config_heavy
		or die "Cannot open $config_heavy ($!).\n";
	    while(<$fh>) {
		if (/myuname=.*strawberryperl ([\d\.]+)/) {
		    $strawberry_ver = $1;
		    last;
		}
	    }
	    die "Cannot find strawberryperl version in $config_heavy.\n";
	};
	if ($@) {
	    die <<EOF;
$@
Cannot automatically determine Strawberry Perl version.
Please set -strawberryver option.
EOF
	}
    }
}

my $patchdir = "$FindBin::RealBin/patches/strawberry-perl-$strawberry_ver";
if (-d $patchdir) {
    $patchdir = realpath($patchdir);
    # XXX use strawberry's own patch in c/bin/patch.exe
    $patch_exe = "C:/cygwin/bin/patch.exe";
    -x $patch_exe
	or die "Need cygwin's patch program";
} else {
    warn "INFO: No patches for Strawberry Perl $strawberry_ver found (expected patch directory: $patchdir).\n";
    undef $patchdir;
}

if (!-d $strawberry_dir) {
    if (!-f $strawberry_zipfile) {
	die "The zip file $strawberry_zipfile does not exist.\n";
    }
    mkdir $strawberry_dir
	or die "Can't create $strawberry_dir: $!";
    $strawberry_zipfile
	or usage();
    my $zip = Archive::Zip->new;
    $zip->read($strawberry_zipfile) == AZ_OK
	or die "Error reading $strawberry_zipfile";

    chdir $strawberry_dir or die $!;
    print STDERR "Extracting zip file...\n";
    $zip->extractTree == AZ_OK
	or die "Error extracting tree";
} else {
    chdir $strawberry_dir or die $!;
    -d "perl"
	or die "ERROR: no 'perl' directory found, maybe Strawberry Perl is not yet extracted in $strawberry_dir?";
}

if ($patchdir) {
    print STDERR "Patch files...\n";
    patch_if_needed("$patchdir/portable_perl.diff");
    save_pwd {
	chdir "perl/vendor/lib" or die "Can't chdir to perl/vendor/lib: $!";
	patch_if_needed("$patchdir/Portable_Config.diff");
    };
}

print STDERR "Get/update distroprefs from github...\n";
save_pwd {
    chdir "$strawberry_dir/cpan"
	or die "Can't chdir to $strawberry_dir/cpan: $!";
    my @cmd;
    my $chdir;
    if (-d "prefs/.git") {
	$chdir = 'prefs';
	@cmd = ("git", "pull", '--depth=10');
    } else {
	@cmd = ("git", "clone", '--depth=10', "git://github.com/eserte/srezic-cpan-distroprefs.git", "prefs");
    }
    if (is_in_path('git')) {
	if ($chdir) {
	    chdir $chdir
		or die "Can't chdir to subdirectory '$chdir': $!";
	}
	system @cmd;
    } else {
	(my $escaped_strawberry_dir = $strawberry_dir) =~ s{\\}{\\\\\\}g;
	exec_cygwin_cmd('cd $(cygpath ' . $escaped_strawberry_dir . ')/cpan' . ($chdir ? "/$chdir" : '') . ' && ' . join(' ', @cmd));
    }
    if ($? != 0) {
	print STDERR <<EOF;
**********************************************************************
* WARNING: the command
*    @cmd
* failed. This means that some CPAN modules may need interactive
* configuration, and some patches may be missing.
**********************************************************************
EOF
    }
};

print STDERR "Add modules from Bundle::BBBike_windist...\n";
{
    # Fix PATH, otherwise Tk and probably other stuff cannot be built
    local $ENV{PATH} = join(";",
			    "$strawberry_dir\\perl\\site\\bin",
			    "$strawberry_dir\\perl\\bin",
			    "$strawberry_dir\\c\\bin",
			    "$ENV{PATH}"
			   );
    save_pwd {
	chdir $bbbikesrc_dir
	    or die "Can't chdir to $bbbikesrc_dir: $!";
	system("$strawberry_dir/perl/bin/perl.exe", "-MCPAN", "-e", 'CPAN::HandleConfig->load; $CPAN::Config->{prefs_dir} = q{' . $strawberry_dir . '\\cpan\\prefs}; install shift', 'Bundle::BBBike_windist');
    };
}

print STDERR "Copying strawberry perl to $bbbikedist_dir...\n";
system($^X, "$FindBin::RealBin/strawberry-include-exclude.pl",
       "-doit", "-v",
       "-src", $strawberry_dir,
       "-dest", $bbbikedist_dir,
      );

print STDERR "Finished.\n";

sub usage {
    die <<EOF;
usage: $0 --strawberrydir dir --bbbikedistdir dir strawberrydist.zip

Both --strawberrydir and --bbbikedistdir directories should
not exist yet, only the parent directories.
EOF
}

sub patch_if_needed {
    my($difffile) = @_;
    my $out = `$patch_exe -p0 --batch --dry-run < $difffile 2>&1`;
    if ($out !~ m{previously applied.*patch detected}i) {
	my $cmd = "$patch_exe -p0 < $difffile";
	system $cmd;
	die "$cmd failed: $?" if $? != 0;
    }
}

sub exec_cygwin_cmd {
    my $cmd = shift;
    my @cygwin_cmd = ('c:/cygwin/bin/sh', '-l', '-c', $cmd);
    system @cygwin_cmd;
    die "Command '@cygwin_cmd' failed" if $? != 0;
}

__END__
