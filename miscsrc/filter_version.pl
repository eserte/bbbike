#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: filter_version.pl,v 1.5 2003/09/02 21:43:41 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

# copy a source tree and filtering the special ***VERSION=n***

use strict;
use File::Copy;
use File::Find;
use File::Path;
use File::Spec;
use File::Temp qw(tempfile);
use File::Compare;
use Cwd;
use Getopt::Long;
use Errno qw(EACCES);

my $version;
my $prefix = "VERSION";
my $update;
my $force;

if (!GetOptions("prefix=s"  => \$prefix,
		"version=i" => \$version,
		"update!"   => \$update,
		"force!"    => \$force,
	       )) {
    die "usage: $0 [-prefix prefix] [-[no]update] [-[no]force] -version i fromdir todir";
}

if (!defined $version) {
    die "-version is not optional!";
}

my $fromdir = shift || "from directory not specified";
my $todir   = shift || "to directory not specified";

if (!-d $fromdir) {
    die "$fromdir is no directory";
}

if (!File::Spec->file_name_is_absolute($todir)) {
    $todir = File::Spec->catdir(cwd(), $todir);
}
if (-e $todir && !$force) {
    die "$todir must NOT exist (or use -force)";
}

chdir $fromdir or die "Can't chdir to $fromdir: $!";

find(\&wanted_dirs, ".");
find(\&wanted_files, ".");

sub ignore {
    # ignore some file/dirs from rcsignore -perlbuild
    return (/^(RCS|blib|_Inline|Makefile\.old|pm_to_blib|typemap|.*\.bs|.*\.ppd|.*\.inl)$/);
}

sub wanted_dirs {
    if (ignore()) {
	$File::Find::prune = 1 if -d $_;
	return;
    }
    (my $path = $File::Find::name) =~ s|^\./||;
    my $src = $_;
    my $dest = "$todir/$path";
    if (-d $src) {
	mkpath([$dest], 1, 0755);
    }
}

sub wanted_files {
    if (ignore()) {
	$File::Find::prune = 1 if -d $_;
	return;
    }
    (my $path = $File::Find::name) =~ s|^\./||;
    my $src = $_;
    my $dest = "$todir/$path";
    if (-f $src) {
	if ($update && -e $dest && -M $src >= -M $dest) {
	    warn "$dest is newer than $src, skipping...\n";
	    return;
	}
	warn "Filter to $dest...\n";
	filter($src, $dest) and	copy_stat($src, $dest);
    }
}

sub filter {
    my($from, $to) = @_;
    open(R, "< $from") or die "Can't read $from: $!";
    my($fh, $filename) = tempfile(UNLINK => 1);
    my $stage = 'copy';
    while(<R>) {
	if (s/\# *\*\*\*$prefix=$version\*\*\*//) {
	    $stage = 'removecomment';
	} elsif (s/\# *\*\*\*$prefix=all\*\*\*//) {
	    $stage = 'copy';
	} elsif (/\# *\*\*\*$prefix=\d+\*\*\*/) {
	    $stage = 'ignore';
	}
	if ($stage eq 'removecomment') {
	    s/^\#//;
	    print $fh $_;
	} elsif ($stage eq 'copy') {
	    print $fh $_;
	}
    }
    close $fh;
    close R;

    if (compare($filename, $to) != 0) {
	copy($filename, $to) or do {
	    unlink $to;
	    copy($filename, $to) or do {
		die "Can't write to $to: $!";
	    }
	};
	return 1;
    } else {
	warn "... unchanged\n";
	return 0;
    }
}

# REPO BEGIN
# REPO NAME copy_stat /home/e/eserte/src/repository 
# REPO MD5 f567def1f7ce8f3361e474b026594660

=head2 copy_stat($src, $dest)

=for category File

Copy stat information (owner, group, mode and time) from one file to
another. If $src is an array reference, then this is used as the
source stat information.

=cut

sub copy_stat {
    my($src, $dest) = @_;
    my @stat = ref $src eq 'ARRAY' ? @$src : stat($src);
    die "Can't stat $src: $!" if !@stat;

    chmod $stat[2], $dest
	or warn "Can't chmod $dest to " . sprintf("0%o", $stat[2]) . ": $!";
    chown $stat[4], $stat[5], $dest
	or do {
	    my $save_err = $!; # otherwise it's lost in the get... calls
	    warn "Can't chown $dest to " .
		 (getpwuid($stat[4]))[0] . "/" .
                 (getgrgid($stat[5]))[0] . ": $save_err";
	};
    utime $stat[8], $stat[9], $dest
	or warn "Can't utime $dest to " .
	        scalar(localtime $stat[8]) . "/" .
		scalar(localtime $stat[9]) .
		": $!";
}
# REPO END

__END__
