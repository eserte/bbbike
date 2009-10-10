#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: mkrpm.pl,v 1.9 2008/03/01 21:30:48 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../..");
use MetaPort;

use strict;

use vars qw($bbbike_version $tmpdir $bbbike_dir);
use vars qw($bbbike_base $bbbike_archiv
	    $bbbike_archiv_dir $bbbike_archiv_path);
use vars qw($bbbike_comment $bbbike_descr);

chdir "$FindBin::RealBin" or die $!;

my $rpms = "/usr/local/src/redhat/RPMS/i386";
my $inst_dir = "/usr/local/BBBike";

my $release;

if (!-e "$inst_dir/bbbike") {
    die "BBBike is not installed. Do:
cd ../.. && make fbsdport && cd /tmp/BBBike && make && sudo make install
";
}

if (-d $rpms) {
    my $max_release = -1;
    foreach my $f (glob("$rpms/BBBike-$bbbike_version-*.rpm")) {
	if ($f =~ /BBBike-$bbbike_version-(\d+)\..*\.rpm/) {
	    $max_release = $1 if ($max_release < $1);
	} else {
	    warn "Can't parse file name $f";
	}
    }
    $release = $max_release+1 if $max_release >= 0;
}

if (!defined $release) {
    $release = 0;
    if (open(REL, ".rpm.release")) {
	chomp(my $ver_rel = <REL>);
	close REL;
	my($old_ver, $old_rel) = split /\s+/, $ver_rel;
	if ($old_ver eq $bbbike_version) {
	    $release = $old_rel+1;
	}
    }
}

open(RPM, ">bbbike.rpm.spec") or die $!;
print RPM <<EOF;
### DO NOT EDIT! CREATED AUTOMATICALLY BY $0! ###
%define __prefix        %{_prefix}
Name: BBBike
Version: $bbbike_version
Release: $release
Copyright: GPL
Group: Applications/Productivity
Requires: perl >= 5.005, perl-tk >= 800
Prefix: %{__prefix}
URL: $BBBike::BBBIKE_SF_WWW
Packager: $BBBike::EMAIL
Source: $BBBike::DISTFILE_SOURCE
Summary: $bbbike_comment
EOF

print RPM "%description\n";
if (open(COMMENT, "$bbbike_descr")) {
    while(<COMMENT>) {
	chomp;
	next if (/^\s*$/);
	print RPM "$_\n";
    }
    close COMMENT;
    print RPM "\n";
}
print RPM "\n";

print RPM "%files\n";

# XXX funktioniert erst, nachdem eine Installation bereits durchgeführt wurde
# besser: Files aus MANIFEST irgendwo hin kopieren, Linux-Binaries erzeugen
# und dann zusammenpacken
# %install dafür verwenden
# Buildroot: setzen
# PREFIX/bin/bbbike: Shell-Skript, das bbbike mit korrekter Perl-Version
# aufruft
# XXX

use ExtUtils::Manifest;
$ExtUtils::Manifest::MANIFEST = "$FindBin::RealBin/../../MANIFEST";
my @warn_files;
my @rpm_files;
foreach (keys %{ ExtUtils::Manifest::maniread() }) {
    my $file = "$inst_dir/$_";
    my $rpm_file = "%{__prefix}/BBBike/$_";
    if (!-e $file) {
	push @warn_files, $file;
    } elsif ($file =~ /i386.*freebsd/) { # should not fire...
	warn "Ignoring non-linux file $file\n";
    } else {
	push @rpm_files, $rpm_file;
    }
}
if (@warn_files) {
    warn "
Warning: the following files exist in MANIFEST, but not in $inst_dir:
" . join("\n", map "  $_", @warn_files) . "\n";
}

print RPM join("\n", sort @rpm_files), "\n\n";

# XXX this is not perfect... how to replace __prefix with the real relocated
# path???
print RPM "%post
rm -f %{_prefix}/bin/bbbike
ln -s %{_prefix}/BBBike/bbbike %{_prefix}/bin/bbbike

";

close RPM;

warn "Building rpm...\n";
system("rpm -bb bbbike.rpm.spec");

open(REL, ">.rpm.release") or die "Can't write release info";
print REL "$bbbike_version $release\n";
close REL;

__END__
