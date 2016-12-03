#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2015,2016 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;

use Carp qw(croak);
use Getopt::Long;
use POSIX qw(strftime);

die "Sorry, this script must be run under CMD.EXE or PowerShell, not cygwin"
    if $^O eq 'cygwin';

my $username = $ENV{USERNAME};
my $do_snapshot;
my $do_continue;
my $do_bbbike_update = 1;
my $strawberry_ver = '5.24.0.1';
my $bbbike_git_remote = 'origin';
my $bbbike_git_branch = 'master';
GetOptions(
	   "snapshot" => \$do_snapshot,
	   "c|cont|continue" => \$do_continue,
	   "bbbike-update!" => \$do_bbbike_update,
	   'strawberry-version|strawberry-ver=s' => \$strawberry_ver,
	   'git-remote=s' => \$bbbike_git_remote,
	   'git-branch=s' => \$bbbike_git_branch,
	  )
    or die "usage: $0 [-snapshot] [-c|-continue] [-no-bbbike-update] [-strawberry-version X.Y.Z.A]";

my $strawberry_base = 'strawberry-perl-' . $strawberry_ver;
my $strawberry_zip_file = $strawberry_base . '-32bit-portable.zip';
my @downloads_paths =
    (
     "$ENV{USERPROFILE}\\Downloads",
     "c:\\Dokumente und Einstellungen\\eserte\\Eigene Dateien\\Downloads",
     "c:\\Users\\eserte\\Downloads",
    );
my $eserte_dos_path = "$ENV{HOMEDRIVE}$ENV{HOMEPATH}";
my $bbbike_dos_path = "$eserte_dos_path\\bbbike";

my $downloads_path;
for my $candidate (@downloads_paths) {
    if (-d $candidate) {
	$downloads_path = $candidate;
	last;
    }
}
if (!$downloads_path) {
    die "Strange: cannot find downloads directory, tried @downloads_paths";
}
my $strawberry_zip_path = $downloads_path . "\\" . $strawberry_zip_file;
if (!-s $strawberry_zip_path) {
    die "$strawberry_zip_path does not exist or is empty. Please download the file from www.strawberryperl.com.\n";
}

my $strawberry_dir = "$eserte_dos_path\\$strawberry_base";
my $strawberry_perl = "$strawberry_dir\\perl\\bin\\perl";
my $bbbikewindist_dir = "$eserte_dos_path\\bbbikewindist";
my $bak_date = strftime("%Y%m%d%H%M%S", localtime);
if (-e $strawberry_dir) {
    if ($do_continue) {
	print STDERR "Reusing existing $strawberry_dir...\n";
    } else {
	print STDERR "Moving existing $strawberry_dir...\n";
	my $dest = "$strawberry_dir.$bak_date.bak";
	rename $strawberry_dir, $dest
	    or die "Can't move $strawberry_dir to $dest: $!";
    }
}
if (-e $bbbikewindist_dir) {
    if ($do_continue) {
	print STDERR "Reusing existing $bbbikewindist_dir...\n";
    } else {
	print STDERR "Moving existing $bbbikewindist_dir...\n";
	my $dest = "$bbbikewindist_dir.$bak_date.bak";
	rename $bbbikewindist_dir, $dest
	    or die "Can't move $bbbikewindist_dir to $dest: $!";
	mkdir $bbbikewindist_dir;
    }
}

if ($do_bbbike_update) {
    # - make sure that the bbbike sources are up-to-date,
    #   e.g. in a git shell:
    #     cd ~/bbbike
    #     git fetch cvrsnica && git checkout cvrsnica/master
    #   or
    #     git fetch origin && git checkout origin/master
    my $bbbike_git_full_branch = $bbbike_git_remote . '/' . $bbbike_git_branch;
    print STDERR "Now fetching from $bbbike_git_full_branch...\n";
    my $cmd = 'cd ' . $bbbike_dos_path . ' && git fetch ' . $bbbike_git_remote . ' && git checkout ' . $bbbike_git_full_branch;
    system $cmd;
    die "Command '$cmd' failed" if $? != 0;
}

{
    # Create a customized strawberry perl distibution into bbbikewindist
    #
    # Something like:
    #
    #     cd C:\cygwin\home\eserte\work\bbbike && perl port\windows\create_customized_strawberry.pl -strawberrydir C:\cygwin\home\eserte\strawberry-5.14.2.1 -bbbikedistdir c:\cygwin\home\eserte\bbbikewindist "c:\Dokumente und Einstellungen\eserte\Eigene Dateien\Downloads\strawberry-perl-5.14.2.1-32bit-portable.zip

    my $cmd = qq{cd $bbbike_dos_path && perl port\\windows\\create_customized_strawberry.pl -strawberrydir $strawberry_dir -bbbikedistdir $bbbikewindist_dir "$strawberry_zip_path"};
    print STDERR "Running $cmd...\n";
    system $cmd;
    $? == 0 or die "Previous command failed";
}

## - copy stripped down gpsbabel distro into \cygwin\home\eserte\bbbikewindist\gpsbabel
##     cd ~/work/bbbike/port/windows && make make-gpsbabel-dist
#exec_cygwin_cmd('cd ' . $bbbike_cygwin_path . '/port/windows && make make-gpsbabel-dist');

# - run dist-making rules
#     cd ~/work/bbbike && perl Makefile.PL
#    cd port/windows && make bbbike-strawberry-dist make-bbbike-dist
#   or to create a bbbike snaphot
#    cd port/windows && make bbbike-strawberry-snapshot-dist make-bbbike-dist
exec_cmd("cd $bbbike_dos_path && $strawberry_perl Makefile.PL");
my $bbbike_strawberry_dist_target = $do_snapshot ? 'bbbike-strawberry-snapshot-dist' : 'bbbike-strawberry-dist';
exec_cmd("cd $bbbike_dos_path\\port\\windows && gmake $bbbike_strawberry_dist_target make-bbbike-dist");

{
    # Run ISS to create the installer:
    my $iss_file = $do_snapshot ? "bbbike-snapshot-" . strftime("%Y%m%d", localtime) . ".iss" : "bbbike.iss";
    my $cmd;
    my $iscc = 'C:\Program Files\Inno Setup 5\ISCC.exe';
    if (-x $iscc) {
	$cmd = qq{cd $bbbike_dos_path\\port\\windows && "$iscc" $iss_file};
	print STDERR "Run command: $cmd...\n";
    } else {
	$cmd = "cd $bbbike_dos_path\\port\\windows && $iss_file";
	print STDERR "Start ISS ($cmd)... please press the green 'play' button!\n";
    }
    system $cmd;
    $? == 0 or die "Previous command failed";
}

sub exec_cmd {
    my $cmd = shift;
    print STDERR "Run '$cmd'...\n";
    system $cmd;
    $? == 0 or croak "Previous command failed";
}

__END__
