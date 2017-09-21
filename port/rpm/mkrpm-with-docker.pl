#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use FindBin;
use lib "$FindBin::RealBin/../../lib";
use Doit;
use Doit::Log;
use Cwd 'realpath';
use Getopt::Long;

return 1 if caller;

my $doit = Doit->init;

GetOptions(
	   "--distro=s" => \my $distro_spec,
	  )
    or die "usage: $0 [--dry-run] --distro distroname\n";

if (!$distro_spec) {
    error "Please set --distro option to something like 'centos:7'";
}

for my $tool (qw(docker)) {
    $doit->qx('which', $tool); # existence check
}

my $bbbike_root = realpath "$FindBin::RealBin/../..";
my $bbbike_distfiles = realpath "$bbbike_root/../bbbike-distfiles";
error "bbbike-distfiles directory is missing" if !-d $bbbike_distfiles;

require File::Temp;
my $dir = File::Temp::tempdir("bbbike_rpm_docker_XXXXXXXX", TMPDIR => 1, CLEANUP => 1);

$doit->write_binary("$dir/Dockerfile", <<"EOF");
FROM $distro_spec
MAINTAINER Slaven Rezic "srezic\@cpan.org"

RUN yum -y install perl
RUN yum -y install rpm-build

EOF

chdir $dir
    or die "Can't chdir to $dir: $!";
$doit->system(qw(docker build -t bbbike-rpm-build .));
$doit->system(
	      qw(docker run),
	      '-v', "$bbbike_root:/data",
	      '-v', "$bbbike_distfiles:/data/distfiles",
	      qw(-v /tmp:/pkg bbbike-rpm-build),
	      'sh', '-c', 'mkdir -p /root/rpmbuild/SOURCES && cp /data/distfiles/*.tar.gz /root/rpmbuild/SOURCES/ && cd /data/port/rpm && perl ./mkrpm.pl && cp /root/rpmbuild/RPMS/noarch/BBBike-*.rpm /pkg'
	     );

__END__
