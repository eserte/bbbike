#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: mkport.pl,v 1.23 2004/03/15 21:39:38 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 1998,2000,2004 Slaven Rezic. All rights reserved.
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
use Getopt::Long;

use vars qw($bbbike_version $tmpdir $bbbike_dir);
use vars qw($bbbike_base $bbbike_archiv
	    $bbbike_archiv_dir $bbbike_archiv_path);

my %dir;

my $v = 0;
my $use_version;
my $portsdir = "/usr/ports";

if (!GetOptions("v" => \$v,
		"useversion=s" => \$use_version,
		"portsdir=s" => \$portsdir)) {
    die "usage: $0 [-v] [-useversion x.yy] [-portsdir /usr/ports]";
}

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
my $old_ports_makefile = "$portsdir/german/BBBike/Makefile";

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
    system($cmd) and die "Failed on command $cmd with $?";
    $cmd = "zcat $bbbike_archiv_path | ( cd $tmpdir ; tar xf - $bbbike_base/MANIFEST )";
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

my $plist = "$portdir/pkg-plist";
my $plist5005 = "$portdir/pkg-plist.5005";
open(PLIST, ">$plist") or die "Can't write to $plist: $!";
open(PLIST_5005, ">$plist5005") or die "Can't write to $plist5005: $!";
foreach (sort @files) {
    plist_line($_);
    plist_line($_, \*PLIST_5005);
}

if (open(PLISTADD, "pkg-plist.add")) {
    while(<PLISTADD>) {
	chomp;
	plist_line($_, \*PLIST_5005);
	my $l = $_;
# 	if ($l =~ m|^lib/|) {
# 	    $l =~ s|^lib|lib/%%PERL_VER%%|;
	    plist_line($l);
#	}
    }
    close PLISTADD;
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
    print PLIST "\@dirrm $_\n";
    print PLIST_5005 "\@dirrm $_\n";
}
close PLIST_5005;
close PLIST;

warn "Get MD5 of $bbbike_archiv_dir/$bbbike_archiv:\n";
my $md5 = `cd $bbbike_archiv_dir; md5 $bbbike_archiv`;
my $md5_qr = qr/^(MD5)\s*(\(.*\))\s*(=)\s*(.*)$/;
if (!defined $md5 || $md5 !~ $md5_qr) {
    # try md5sum:
    $md5 = `cd $bbbike_archiv_dir; md5sum $bbbike_archiv`;
    if (!$md5) {
	die "Couldn't get MD5 of $bbbike_archiv, tried md5 and md5sum";
    } else {
	$md5 = (split /\s+/, $md5)[0];
	$md5 = "MD5 ($bbbike_archiv) = $md5";
	if ($md5 !~ $md5_qr) {
	    die "$md5 does not match the proper MD5 pattern";
	}
    }
}
$md5 = "$1 $2 $3 $4"; # reformat md5 value

open(DISTINFO, ">$portdir/distinfo") or die "Can't write distinfo file: $!";
print DISTINFO $md5, "\n";
close DISTINFO;

substitute("pkg-descr",   "$portdir/pkg-descr");
substitute("pkg-message", "$portdir/pkg-message");
#system("cd $tmpdir/BBBike && portlint -a -b -c -t");
system("cd $tmpdir/BBBike && port test");
system("cd $tmpdir && tar cfvz $tmpdir/bbbike-fbsdport.tar.gz BBBike");

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

sub plist_line {
    my $in = shift;
    my $out = shift || \*PLIST;
    my $file = "BBBike/$in";
    print $out "$file\n";
    # executables in /usr/local/bin:
    if (/^(c?bbbike|cmdbbbike|smsbbbike|bbbikeclient)$/) {
	print $out "\@exec ln -fs %D/%F %D/bin/$in\n";
	print $out "\@unexec rm -f %D/bin/$in\n";
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
	print DEST $_;
    }
    close DEST;
    close SRC;
}

__END__
