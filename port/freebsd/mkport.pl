#!/usr/local/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1998,2000,2004,2013,2014 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net/
#

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../..");
use MetaPort;

use strict;

use ExtUtils::Manifest;
use File::Basename;
use File::Copy qw(cp);
use File::Path qw(mkpath);
use Getopt::Long;

use BBBikeUtil qw(is_in_path);

sub plist_line ($$);

use vars qw($bbbike_version $tmpdir $bbbike_dir);
use vars qw($bbbike_base $bbbike_archiv
	    $bbbike_archiv_dir $bbbike_archiv_path);

my %dir;

my $v = 0;
my $do_fast;
my $use_version;
my $portsdir = "/usr/ports";

if (!GetOptions("v" => \$v,
		"fast" => \$do_fast,
		"useversion=s" => \$use_version,
		"portsdir=s" => \$portsdir)) {
    die "usage: $0 [-v] [-fast] [-useversion x.yy] [-portsdir /usr/ports]

-v: be verbose
-useversion: use another version than $BBBike::STABLE_VERSION
-fast: do not call the port test script, only call portlint
";
}

chdir $FindBin::RealBin
    or die "Can't chdir to $FindBin::RealBin: $!";

if (defined $use_version) {
    if ($use_version eq 'last' && $BBBike::STABLE_VERSION =~ m{^(\d+)\.(\d+)}) {
	my($major, $minor) = ($1, $2);
	$use_version = $major.".".sprintf("%02d", $minor-1);
    }
    $bbbike_version = $BBBike::STABLE_VERSION = $use_version;
}

my $bbbike_base        = "BBBike-$bbbike_version";
my $bbbike_archiv      = "$bbbike_base.tar.gz";
my $bbbike_archiv_dir  = $bbbike_dir;
my $bbbike_archiv_path = "$bbbike_archiv_dir/$bbbike_archiv";
if (!-f $bbbike_archiv_path) {
    # try in distfiles:
    $bbbike_archiv_dir = "$bbbike_dir/distfiles";
    $bbbike_archiv_path = "$bbbike_archiv_dir/$bbbike_archiv";
    if (!-f $bbbike_archiv_path) {
	die "Can't find $bbbike_archiv in $bbbike_archiv_dir";
    }
}
my $bbbike_ports_dir = "$portsdir/german/BBBike";
my $old_ports_makefile = "$bbbike_ports_dir/Makefile";
my @bbbike_perl_exe = qw(bbbike cbbbike bbbikeclient cmdbbbike smsbbbike);
my $bbbike_perl_exe = join ' ', @bbbike_perl_exe;
my %bbbike_perl_exe = map {($_,1)} @bbbike_perl_exe;

my $freebsd_ident = <<'EOF';
# $FreeBSD: ports/german/BBBike/Makefile,v 1.11 2002/07/15 10:55:17 ijliao Exp $
EOF
if (open(M, $old_ports_makefile)) {
    my $found;
    while(<M>) {
	chomp;
	if (/^\#\s+\$FreeBSD:/) {
	    $freebsd_ident = $_;
	    $found++;
	    last;
	}
    }
    close M;
    if (!$found) {
	warn "Cannot find FreeBSD tag in $old_ports_makefile";
    }
} else {
    warn "Cannot open $old_ports_makefile: $!";
}

my $portdir = "$tmpdir/BBBike";

my $bbbike_manifest;
{
    local(%ENV) = %ENV;
    $ENV{SHELL} = "/bin/sh";
    my $cmd;
    $cmd = "rm -f $tmpdir/$bbbike_base/MANIFEST";
    warn "$cmd\n" if $v;
    if (!-d "$tmpdir/$bbbike_base") {
	if (-e "$tmpdir/$bbbike_base") {
	    die "$tmpdir/$bbbike_base exists, but is not a directory. Please remove first";
	}
	mkpath "$tmpdir/$bbbike_base" or die $!
    }
    system($cmd) and die "Failed on command $cmd with $?";
    $cmd = "zcat $bbbike_archiv_path | ( cd $tmpdir && tar xf - $bbbike_base/MANIFEST )";
    warn "$cmd\n" if $v;
    system($cmd) and die "Failed on command $cmd with $?";
    $bbbike_manifest = "$tmpdir/$bbbike_base/MANIFEST";
}

my @files = keys %{ ExtUtils::Manifest::maniread($bbbike_manifest) };
if (!@files) {
    die "Can't read MANIFEST";
}

system("rm -rf $portdir");

umask 022;
mkdir $portdir, 0755 or die $!;

substitute("Makefile.tmpl", "$portdir/Makefile");

my $plist = "$portdir/pkg-plist.in";
open my $PLIST, ">", $plist
    or die "Can't write to $plist: $!";

#XXX requiredd?
# print $PLIST <<'EOF';
# @owner root
# @group wheel
# EOF

foreach (sort @files) {
    plist_line($_, $PLIST);
}

print $PLIST "man/man1/bbbike.1.gz\n";

my %insert_after;
my $in_insert_after;

if (open my $PLISTADD, "<", "pkg-plist.add") {
    while(<$PLISTADD>) {
	chomp;
	my $l = $_;
	if ($l =~ /^#/) {
	    if ($l =~ /^# after:\s*(.*)/) {
		$in_insert_after = $1;
	    } else {
		die "Unknown # directive $l";
	    }
	} else {
	    if (defined $in_insert_after) {
		$insert_after{$in_insert_after} = $l;
		undef $in_insert_after;
	    } else {
		plist_line($l, $PLIST);
	    }
	}
    }
    close $PLISTADD;
}

foreach my $dir (keys %dir) {
    while ($dir ne '' && $dir ne '.') {
	my $dirdir = dirname $dir;
	if (!exists $dir{$dir}) {
	    $dir{$dir}++;
	    last;
	}
	$dir = $dirdir;
    }
}
foreach (sort { dircmp($a, $b) } keys %dir) {
    my $line = "\@dirrm $_";
    print $PLIST "$line\n";
    if (exists $insert_after{$line}) {
	print $PLIST $insert_after{$line}, "\n";
	delete $insert_after{$line};
    }
}
close $PLIST;

if (keys %insert_after) {
    die "Following insert afters were unhandled: " . keys(%insert_after);
}

my $sha256;
{
    warn "Get SHA256 of $bbbike_archiv_dir/$bbbike_archiv:\n";
    $sha256 = `cd $bbbike_archiv_dir && sha256 $bbbike_archiv`;
    my $md5_sha256_qr = qr/^(MD5|SHA256)\s*(\(.*\))\s*(=)\s*(.*)$/;

    if (!defined $sha256 || $sha256 !~ $md5_sha256_qr) {
	# try sha256sum:
	$sha256 = `cd $bbbike_archiv_dir && sha256sum $bbbike_archiv`;
	if (!$sha256) {
	    die "Couldn't get SHA256 of $bbbike_archiv, tried sha256 and sha256sum";
	} else {
	    $sha256 = (split /\s+/, $sha256)[0];
	    $sha256 = "SHA256 ($bbbike_archiv) = $sha256";
	    if ($sha256 !~ $md5_sha256_qr) {
		die "$sha256 does not match the proper SHA256 pattern";
	    }
	    $sha256 = "$1 $2 $3 $4"; # reformat sha256 value
	}
    } else {
	$sha256 = "$1 $2 $3 $4"; # reformat md5 value
    }
}

my $distsize = (stat("$bbbike_archiv_dir/$bbbike_archiv"))[7];

open(DISTINFO, ">$portdir/distinfo") or die "Can't write distinfo file: $!";
print DISTINFO $sha256, "\n";
print DISTINFO "SIZE ($bbbike_archiv) = $distsize\n";
close DISTINFO;

substitute("pkg-descr",   "$portdir/pkg-descr");
substitute("pkg-message", "$portdir/pkg-message");
if ($do_fast) {
    system("cd $tmpdir/BBBike && portlint -a -b -c -t");
} else {
    if (!is_in_path("port")) {
	warn <<EOF;
WARN: cannot find "port" utility. Please install using
      either one of the following commands

    sudo pkg install porttools
    sudo pkg_add -r porttools

and re-run the command.
EOF
    }
    my $cmd = "cd $tmpdir/BBBike && port test";
    system($cmd);
    $? == 0
	or die "The command '$cmd' failed";

    # check for and delete package file, created by "port test"
    chomp(my $pkgfile = `cd $tmpdir/BBBike && make -VPKGFILE`);
    if (!defined $pkgfile) {
	warn "WARN: Cannot get PKGFILE from Makefile, cannot delete package file";
    } else {
	if (!-e $pkgfile) {
	    warn "WARN: no package file '$pkgfile' found, but it should be created by 'port test'";
	} else {
	    unlink $pkgfile
		or die "Cannot delete package file '$pkgfile': $!";
	}
    }
}
#system("cd $tmpdir && tar cfvz $tmpdir/bbbike-fbsdport.tar.gz BBBike");

warn <<EOF;
Now:

- Make sure that $bbbike_ports_dir is up-to-date using
    sudo portsnap fetch && sudo portsnap extract
  (Actually, you should do this before starting doing
   changes)

- Execute
    cd $portdir && port diff -d /usr/ports >| $tmpdir/bbbike-fbsdport.patch

- File a send-pr report, including the patch

EOF

sub dircmp {
    my($a, $b) = @_;
    if (0) { # The results of this one is nicer, but use the same comparison as in the fbsdport-pkg-plist-check makefile rule
	my $a_c = @_ = split '/', $a;
	my $b_c = @_ = split '/', $b;
	my $r = $b_c <=> $a_c || $b cmp $a;
	$r;
    } else {
	(length $b <=> length $a) || ($b cmp $a);
    }
}

sub plist_line ($$) {
    my $in = shift;
    my $out = shift or die "out fh is missing";
    my $file = "BBBike/$in";
    print $out "$file\n";
    # perl executables in /usr/local/bin:
    if ($bbbike_perl_exe{$in}) {
	print $out "bin/$in\n";
    }
    my $dir = dirname $file;
    $dir{$dir}++;
}

sub substitute {
    my($src, $dest) = @_;

    my $distdir = $BBBike::DISTDIR;
    my $master_site_subdir = '';
    if ($distdir =~ /sourceforge/) {
	$distdir = '${MASTER_SITE_SOURCEFORGE}';
	$master_site_subdir = 'MASTER_SITE_SUBDIR=	${PORTNAME}';
    }
    if ($distdir !~ m|/$|) {
	$distdir .= "/";
    }

    open(SRC, $src) or die "Can't open $src: $!";
    open(DEST, ">$dest") or die "Can't write to $dest: $!";
    while(<SRC>) {
	s/ \@VERSION\@    	  /$BBBike::STABLE_VERSION/gx;
	s/ \@DISTDIR\@    	  /$distdir/gx;
	s/ \@MASTER_SITE_SUBDIR\@ /$master_site_subdir/gx;
	s/ \@EMAIL\@      	  /$BBBike::EMAIL/gx;
	s/ \@BBBIKE_WWW\@ 	  /$BBBike::BBBIKE_WWW/gx;
	s/ \@BBBIKE_SF_WWW\@ 	  /$BBBike::BBBIKE_SF_WWW/gx;
	s/ \@BBBIKE_WAP\@ 	  /$BBBike::BBBIKE_WAP/gx;
	s/ \@FREEBSD_IDENT\@ 	  /$freebsd_ident/gx;
	s/ \@BBBIKE_PERL_EXE\@    /$bbbike_perl_exe/gx;
	print DEST $_;
    }
    close DEST;
    close SRC;
}


__END__
