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
use File::Temp qw(tempfile);
use Getopt::Long;

sub save_pwd (&);

die "Sorry, mixing cygwin perl and Strawberry Perl does not work at all"
    if $^O eq 'cygwin';

my $patch_exe = "C:/cygwin/bin/patch.exe";
-x $patch_exe
    or die "Need cygwin's patch program";

my $strawberry_dir;
my $bbbikedist_dir;
GetOptions("strawberrydir=s" => \$strawberry_dir,
	   "bbbikedistdir=s" => \$bbbikedist_dir,
	  )
    or usage();
$strawberry_dir or usage();
$bbbikedist_dir or usage();

# XXX configurable? or autodetect strawberry version according to supplied $zipfile name?
my $patchdir = realpath("$FindBin::RealBin/patches/strawberry-perl-5.12.3.0");
die "No patch directory found" if !$patchdir || !-d $patchdir; # XXX maybe some day there won't be any patches necessary

if (!-d $strawberry_dir) {
    mkdir $strawberry_dir
	or die "Can't create $strawberry_dir: $!";
    my $zipfile = shift
	or usage();
    my $zip = Archive::Zip->new;
    $zip->read($zipfile) == AZ_OK
	or die "Error reading $zipfile";

    chdir $strawberry_dir or die $!;
    print STDERR "Extracting zip file...\n";
    $zip->extractTree == AZ_OK
	or die "Error extracting tree";
} else {
    chdir $strawberry_dir or die $!;
    -d "perl"
	or die "ERROR: no 'perl' directory found, maybe Strawberry Perl is not yet extracted in $strawberry_dir?";
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
system("$strawberry_dir/perl/bin/cpan.bat", @mods);

my($tmpfh,$tmpfile) = tempfile(SUFFIX => ".lst", UNLINK => 1)
    or die $!;
save_pwd {
    print STDERR "Creating filelist for strawberry perl distribution...\n";
    chdir $strawberry_dir or die $!;
    open my $fh, qq{find2perl . -type f | $^X |} or die $!;
    while (<$fh>) {
	s{^..}{};
	print $tmpfh $_;
    }
    close $fh or die $!;
};
close $tmpfh
    or die $!;

print STDERR "Copying strawberry perl to $bbbikedist_dir...\n";
system($^X, "$FindBin::RealBin/strawberry-include-exclude.pl",
       "-doit", "-v",
       "-src", $strawberry_dir,
       "-dest", $bbbikedist_dir,
       $tmpfile,
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
