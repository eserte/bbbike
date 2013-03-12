#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use Getopt::Long;
use POSIX qw(strftime);

die "Sorry, this script must be run under CMD.EXE, not cygwin"
    if $^O eq 'cygwin';

my $do_snapshot;
my $do_continue;
GetOptions(
	   "snapshot" => \$do_snapshot,
	   "c|cont|continue" => \$do_continue,
	  )
    or die "usage: $0 [-snapshot] [-c|-continue]";

my $strawberry_ver = 'strawberry-perl-5.14.2.1';
my $strawberry_zip_file = $strawberry_ver . '-32bit-portable.zip';
my $downloads_path = "c:\\Dokumente und Einstellungen\\eserte\\Eigene Dateien\\Downloads";
my $eserte_dos_path = "c:\\cygwin\\home\\eserte";
my $bbbike_cygwin_path = '~/work/bbbike';
my $bbbike_git_remote = 'cvrsnica';
my $bbbike_git_branch = 'master';

my $strawberry_zip_path = $downloads_path . "\\" . $strawberry_zip_file;
if (!-s $strawberry_zip_path) {
    die "$strawberry_zip_path does not exist or is empty. Please download the file from www.strawberryperl.com.\n";
}

my $strawberry_dir = "$eserte_dos_path\\$strawberry_ver";
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
    }
}

{
    # - make sure that the bbbike sources are up-to-date,
    #   e.g. in a cygwin shell:
    #     cd ~/work/bbbike
    #     git fetch cvrsnica && git checkout cvrsnica/master
    #   or
    #     git fetch origin && git checkout origin/master
    my $bbbike_git_full_branch = $bbbike_git_remote . '/' . $bbbike_git_branch;
    print STDERR "Now fetching from $bbbike_git_full_branch...\n";
    exec_cygwin_cmd('cd ' . $bbbike_cygwin_path . ' && git fetch ' . $bbbike_git_remote . ' && git checkout ' . $bbbike_git_full_branch);
}

{
    # Create a customized strawberry perl distibution into bbbikewindist
    #
    # Something like:
    #
    #     cd C:\cygwin\home\eserte\work\bbbike && perl port\windows\create_customized_strawberry.pl -strawberrydir C:\cygwin\home\eserte\strawberry-5.14.2.1 -bbbikedistdir c:\cygwin\home\eserte\bbbikewindist "c:\Dokumente und Einstellungen\eserte\Eigene Dateien\Downloads\strawberry-perl-5.14.2.1-32bit-portable.zip

    my $cmd = qq{cd $eserte_dos_path\\work\\bbbike && perl port\\windows\\create_customized_strawberry.pl -strawberrydir $strawberry_dir -bbbikedistdir $bbbikewindist_dir "$strawberry_zip_path"};
    print STDERR "Running $cmd...\n";
    system $cmd;
    $? == 0 or die "Previous command failed";
}

# - copy stripped down gpsbabel distro into \cygwin\home\eserte\bbbikewindist\gpsbabel
#     cd ~/work/bbbike/port/windows && make make-gpsbabel-dist
exec_cygwin_cmd('cd ' . $bbbike_cygwin_path . '/port/windows && make make-gpsbabel-dist');

# - run dist-making rules
#     cd ~/work/bbbike && perl Makefile.PL
#    cd port/windows && make bbbike-strawberry-dist make-bbbike-dist
#   or to create a bbbike snaphot
#    cd port/windows && make bbbike-strawberry-snapshot-dist make-bbbike-dist
exec_cygwin_cmd('cd ' . $bbbike_cygwin_path . ' && perl Makefile.PL');
my $bbbike_strawberry_dist_target = $do_snapshot ? 'bbbike-strawberry-snapshot-dist' : 'bbbike-strawberry-dist';
exec_cygwin_cmd('cd ' . $bbbike_cygwin_path . '/port/windows && make ' . $bbbike_strawberry_dist_target . ' make-bbbike-dist');

{
    # Run ISS to create the installer:
    my $iss_file = $do_snapshot ? "bbbike-" . strawberry("Y%m%d", localtime) . ".iss" : "bbbike.iss";
    my $cmd = "cd $eserte_dos_path\\work\\bbbike\\port\\windows && $iss_file";
    print STDERR "Start ISS ($cmd)... please press the green 'play' button!\n";
    system $cmd;
    $? == 0 or die "Previous command failed";
}

print STDERR <<EOF;
The created installable .exe lives in cygwin's /tmp
with the name BBBike-X.XX-Windows.exe
EOF

sub exec_cygwin_cmd {
    my $cmd = shift;
    my @cygwin_cmd = ('c:/cygwin/bin/sh', '-l', '-c', $cmd);
    system @cygwin_cmd;
    die "Command '@cygwin_cmd' failed" if $? != 0;
}

__END__
