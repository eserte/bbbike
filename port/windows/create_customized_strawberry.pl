#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011,2012,2015,2016 Slaven Rezic. All rights reserved.
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
my $use_bundle; # by default, use task
my $only_action;
my $strip_vendor = 1;
GetOptions(
	   "strawberrydir=s" => \$strawberry_dir,
	   "strawberryver=s" => \$strawberry_ver,
	   "bbbikedistdir=s" => \$bbbikedist_dir,
	   "bundle!" => \$use_bundle,
	   'only-action=s' => \$only_action,
	   'strip-vendor!' => \$strip_vendor,
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
		if (/myuname=.*strawberry-?perl ([\d\.]+)/) {
		    $strawberry_ver = $1;
		    last;
		}
	    }
	    die "Cannot find strawberryperl version in $config_heavy.\n"
		if !$strawberry_ver;
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

if ($only_action) {
    my $action_sub = 'action_' . $only_action;
    if (!defined &$action_sub) {
	die "Action $only_action does not exist";
    } else {
	no strict 'refs';
	&$action_sub;
    }
    exit;
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
    if ($strip_vendor) {
	print STDERR "Extracting zip file (without perl/vendor)...\n";
	for my $member ($zip->members) {
	    my $filename = $member->fileName;
	    if ($filename =~ m{^perl/vendor/lib/} && $filename !~ m{^perl/vendor/lib/Portable($|/|\.pm$)}) {
		# skip vendor
	    } else {
		$zip->extractMember($member) == AZ_OK
		    or die "Error extracting $filename";
	    }
	}
    } else {
	print STDERR "Extracting zip file...\n";
	$zip->extractTree == AZ_OK
	    or die "Error extracting tree";
    }
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

action_add_bbbike_bundle();

sub action_add_bbbike_bundle {
    # Fix PATH, otherwise Tk and probably other stuff cannot be built
    local $ENV{PATH} = join(";",
			    "$strawberry_dir\\perl\\site\\bin",
			    "$strawberry_dir\\perl\\bin",
			    "$strawberry_dir\\c\\bin",
			    "$ENV{PATH}"
			   );
    save_pwd {
	# For some reason CPAN.pm may not create the
	# build directory itself (if used like below?)
	if (!-d $strawberry_dir . '\\cpan\\build') {
	    print STDERR "Create CPAN build directory...\n";
	    mkdir $strawberry_dir . '\\cpan\\build';
	}
	my $perl_exe = "$strawberry_dir/perl/bin/perl.exe";
	my $get_common_cpan_cmd = sub {
	    my(%opts) = @_;
	    my $initial = delete $opts{initial};
	    die "Unhandled options: " . join(" ", %opts) if %opts;
	    (
	     $perl_exe,
	     "-MCPAN",
	     "-e",
	     'CPAN::HandleConfig->load; ' .
	     ($initial ? '' :
	      # Use srezic's CPAN distroprefs:
	      '$CPAN::Config->{prefs_dir} = q{' . $strawberry_dir . '\\cpan\\prefs}; '
	     ) .
	     # Keep the BBBike distribution as small as possible:
	     '$CPAN::Config->{build_requires_install_policy} = q{no}; ' .
	     # Smells like a CPAN.pm bug: if build_requires_install_policy=no is set
	     # and halt_on_failure=1, and there's a build_requires dependency, then
	     # the build stops.
	     '$CPAN::Config->{halt_on_failure} = q[0]; ' . 
	     # Too slow especially for large Bundles or Tasks, and
	     # I don't worry about memory currently (difference is
	     # 160MB vs. 32MB):
	     '$CPAN::Config->{use_sqlite} = q[0]; ' . 
	     # distroprefs is not YAML-XS ready
	     '$CPAN::Config->{yaml_module} = q[YAML::Syck]; ' .
	     'install shift',
	    );
	};

	my $assert_module_installed = sub {
	    my $mod = shift;
	    my @cmd = ($perl_exe, "-M$mod", '-e1');
	    system @cmd;
	    die "Module $mod is not installed for $perl_exe" if $? != 0;
	};

	if ($strip_vendor) {
	    print STDERR "Add YAML::Syck as early as possible (for distroprefs)...\n";
	    my @cpan_cmd = $get_common_cpan_cmd->(initial => 1);
	    system(@cpan_cmd, 'YAML::Syck');
	    $assert_module_installed->('YAML::Syck');
	}

	{
	    my @cpan_cmd = $get_common_cpan_cmd->();
	    chdir $bbbikesrc_dir
		or die "Can't chdir to $bbbikesrc_dir: $!";
	    local $ENV{PERL_CANARY_STABILITY_NOPROMPT} = 1; # needed by JSON::XS...
	    if ($use_bundle) {
		print STDERR "Add modules from Bundle::BBBike_windist...\n";
		system(@cpan_cmd, 'Bundle::BBBike_windist');
		$assert_module_installed->('Bundle::BBBike_windist');
	    } else {
		print STDERR "Add modules from Task::BBBike::windist...\n";
		chdir "Task/BBBike/windist"
		    or die "Can't chdir to task directory: $!";
		system(@cpan_cmd, '.');
		$assert_module_installed->('Task::BBBike::windist');
	    }
	}
    };
}

action_copy_to_bbbikedistdir();

sub action_copy_to_bbbikedistdir {
    print STDERR "Copying strawberry perl to $bbbikedist_dir...\n";
    my @cmd = ($^X, "$FindBin::RealBin/strawberry-include-exclude.pl",
	       "-doit", "-v",
	       "-src", $strawberry_dir,
	       "-dest", $bbbikedist_dir,
	      );
    system @cmd;
    die "Failure of command: @cmd" if $? != 0; 
}

print STDERR "Finished.\n";

sub usage {
    die <<EOF;
usage: $0 --strawberrydir dir --bbbikedistdir dir strawberrydist.zip

Both --strawberrydir and --bbbikedistdir directories should
not exist yet, only the parent directories.

Optional: --bundle may be specified to use Bundle instead of Task.

To run only one action specify the --only-action=\$action option.

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
