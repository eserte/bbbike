#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: mkipk.pl,v 1.5 2003/01/12 20:02:15 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../..");
use MetaPort;

use strict;
use Getopt::Long;
use File::Path;

my $dist = "bbbike";
my $test = 0;
my $destdir = "/tmp";

if (!GetOptions("dist=s" => \$dist,
		"test!"  => \$test,
		"destdir=s" => \$destdir,
	       )) {
    die "usage";
}

if ($dist eq 'babybike') {
    dist_babybike();
} elsif ($dist eq 'tkbabybike') {
    dist_tkbabybike();
} else {
    die "Dist type $dist not supported (yet)";
}

sub dist_babybike {
    require ExtUtils::MakeMaker;
    my $babybike_version = MM->parse_version("$FindBin::RealBin/../../babybike/babybike") or die "Can't get babybike version";

    my $prefix = "/usr/local";
    if ($test) {
	$prefix = "/tmp$prefix";
    }
    (my $prefix_top = $prefix) =~ s|^/([^/]+)|$1|;
    system("rm", "-rf", "/tmp/$prefix");
    system("rm", "-rf", "/tmp/ipk");

    chdir "$FindBin::RealBin/../../babybike" or die "Can't chdir: $!";
    system("make", "stable-dist");
    mkpath(["/tmp$prefix"], 1, 0775) or die "Can't mkpath /tmp$prefix: $!";
    rename "/tmp/BBBike", "/tmp/${prefix}/BBBike" or die "Can't rename: $!";
    chdir "/tmp" or die "Can't chdir to /tmp: $!";
    mkpath(["/tmp/ipk"], 1, 0775) or die "Can't mkpath ipk: $!";
    system("tar", "cfvz", "/tmp/ipk/data.tar.gz", $prefix_top);

    open(CONTROL, ">/tmp/control") or die "Can't create control file: $!";
    print CONTROL <<EOF;
Package: babybike
Version: $babybike_version
Priority: optional
Architecture: arm
Depends: perl (>= 5.00503), perl-Gtk (>= 0.7006)
Maintainer: Slaven Rezic <slaven.rezic\@berlin.de>
Description: Route planner for cyclists in Berlin
 This is a small perl-Gtk version of bbbike for handhelds. Please
 consider to get tkbabybike instead, because the perl-Gtk version is
 not maintained anymore.
EOF
    close CONTROL;
    system("tar", "cfvz","/tmp/ipk/control.tar.gz", "control");

    open(VER, ">/tmp/ipk/debian-binary") or die "Can't write debian-binary: $!";
    print VER "2.0\n"; # XXX?
    close VER;

    chdir "/tmp/ipk" or die "Can't change to ipk directory: $!";
    my $destfile = "$destdir/babybike_${babybike_version}.ipk";
    system("tar cfvz $destfile ./*");
    chmod 0644, $destfile;
}

sub dist_tkbabybike {
    require ExtUtils::MakeMaker;
    my $tkbabybike_version = MM->parse_version("$FindBin::RealBin/../../babybike/tkbabybike") or die "Can't get tkbabybike version";

    my $prefix = "/usr/local";
    if ($test) {
	$prefix = "/tmp$prefix";
    }
    (my $prefix_top = $prefix) =~ s|^/([^/]+)|$1|;
    system("rm", "-rf", "/tmp/$prefix");
    system("rm", "-rf", "/tmp/ipk");

    chdir "$FindBin::RealBin/../../babybike" or die "Can't chdir: $!";
    system("make", "stable-tkbabybike-dist");
    mkpath(["/tmp$prefix"], 1, 0775) or die "Can't mkpath /tmp$prefix: $!";
    rename "/tmp/BBBike", "/tmp/${prefix}/BBBike" or die "Can't rename: $!";
    chdir "/tmp" or die "Can't chdir to /tmp: $!";
    mkpath(["/tmp/ipk"], 1, 0775) or die "Can't mkpath ipk: $!";
    system("tar", "cfvz", "/tmp/ipk/data.tar.gz", $prefix_top);

    open(CONTROL, ">/tmp/control") or die "Can't create control file: $!";
    print CONTROL <<EOF;
Package: tkbabybike
Version: $tkbabybike_version
Priority: optional
Architecture: arm
Depends: perl (>= 5.00503), perl-Tk (>= 800.023)
Maintainer: Slaven Rezic <slaven.rezic\@berlin.de>
Description: Route planner for cyclists in Berlin
 This is a small perl-Tk version of bbbike for handhelds.
EOF
    close CONTROL;
    system("tar", "cfvz","/tmp/ipk/control.tar.gz", "control");

    open(VER, ">/tmp/ipk/debian-binary") or die "Can't write debian-binary: $!";
    print VER "2.0\n"; # XXX?
    close VER;

    chdir "/tmp/ipk" or die "Can't change to ipk directory: $!";
    my $destfile = "$destdir/tkbabybike_${tkbabybike_version}.ipk";
    system("tar cfvz $destfile ./*");
    chmod 0644, $destfile;
}

__END__
