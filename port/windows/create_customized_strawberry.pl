#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;

use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use Cwd qw(realpath);
use File::Temp qw(tempdir);
use Getopt::Long;

sub save_pwd (&);

die "Sorry, mixing cygwin perl and Strawberry Perl does not work at all"
    if $^O eq 'cygwin';

my $patch_exe = "C:/cygwin/bin/patch.exe";
-x $patch_exe
    or die "Need cygwin's patch program";

my $strawberry_dest;
GetOptions("destdir=s" => \$strawberry_dest,
	  )
    or usage();

# XXX configurable? or autodetect using $zipfile?
my $patchdir = realpath("$FindBin::RealBin/patches/strawberry-perl-5.12.3.0");
die "No patch directory found" if !$patchdir || !-d $patchdir; # XXX maybe some day there won't be any patches necessary

if (!$strawberry_dest) {
    my $zipfile = shift
	or usage();
    my $zip = Archive::Zip->new;
    $zip->read($zipfile) == AZ_OK
	or die "Error reading $zipfile";

    $strawberry_dest = tempdir("strawberry-XXXXXXXX",
			       DIR => $ENV{HOME},
			      )
	or die "Can't create temporary directory";
    chdir $strawberry_dest or die $!;
    print STDERR "Extracting zip file...\n";
    $zip->extractTree == AZ_OK
	or die "Error extracting tree";
} else {
    chdir $strawberry_dest or die $!;
    -d "perl"
	or die "ERROR: no 'perl' directory found, maybe Strawberry Perl is not yet extracted in $strawberry_dest?";
}

print STDERR "Patch files...\n";
patch_if_needed("$patchdir/portable_perl.diff");
save_pwd {
    chdir "perl/vendor/lib" or die "Can't chdir to perl/vendor/lib: $!";
    patch_if_needed("$patchdir/Portable_Config.diff");
};

print STDERR "Add modules...\n";
my @mods = qw(
		 Tk
		 Algorithm::Permute
		 Class::Accessor
		 List::Permutor
		 MLDBM
		 PDF::Create
		 String::Approx
		 Tk::Date
		 Tk::NumEntry
		 Tk::Pod
		 Win32::Registry
		 Win32::Shortcut
		 XML::Twig
	    );
system("$strawberry_dest/perl/bin/cpan.bat", @mods);

# XXX nyi: now copy distribution to new final directory,
# excluding some files/filesets

print STDERR "NOTE: new distribution is in $strawberry_dest.\n";

sub usage {
    die <<EOF;
usage: $0 [-destdir dir] strawberrydist.zip
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

# REPO BEGIN
# REPO NAME save_pwd /home/e/eserte/work/srezic-repository 
# REPO MD5 0f7791cf8e3b62744d7d5cfbd9ddcb07

=head2 save_pwd(sub { ... })

=for category File

Save the current directory and assure that outside the block the old
directory will still be valid.

=cut

sub save_pwd (&) {
    my $code = shift;
    require Cwd;
    my $pwd = Cwd::cwd();
    eval {
	$code->();
    };
    my $err = $@;
    chdir $pwd or die "Can't chdir back to $pwd: $!";
    die $err if $err;
}
# REPO END

__END__
