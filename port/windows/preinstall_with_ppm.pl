#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2018,2024 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
my $bbbikesrc_dir; BEGIN { $bbbikesrc_dir = "$FindBin::RealBin/../.." }
use lib (
	 "$bbbikesrc_dir/lib",
	 $bbbikesrc_dir,
	);

use Doit;
use Doit::Log;

use ExtUtils::MakeMaker ();
use Getopt::Long;
use PPM ();
use YAML::Tiny ();
use version ();

use BBBikeUtil qw(module_path);

my $doit = Doit->init;

GetOptions("v" => \my $v)
    or die "usage: $0 [--dry-run] [-v]\n";

if ($v) {
    my %opts = PPM::GetPPMOptions();
    $opts{'VERBOSE'} = "1";
    PPM::SetPPMOptions("options" => \%opts, "save" => 0);
}

$doit->system($^X, "Makefile.PL");
my $mymeta = YAML::Tiny::LoadFile("MYMETA.yml");
my @packages;
while(my($mod, $req_version) = each %{ $mymeta->{requires} || {} }) {
    my $path = module_path($mod);
    if ($path) {
	if ($req_version) {
	    my $version = MM->parse_version($path);
	    if (version->new($version) >= version->new($req_version)) {
		next;
	    }
	} else {
	    next;
	}
    }
    # XXX simple-minded conversion
    (my $package = $mod) =~ s{::}{-}g;
    push @packages, $package;
}

for my $package (@packages) {
    info "Install $package via PPM" . ($doit->is_dry_run ? " (dry-run)" : "");
    PPM::InstallPackage(package => $package);
}

__END__

=head1 NAME

preinstall_with_ppm.pl - try installation using PPM first

=head1 SYNOPSIS

    preinstall_with_ppm.pl [-v] [--dry-run]

=head1 DESCRIPTION

Installing using L<PPM> is faster than with L<CPAN>. This script is
expected to be run within a distribution directory with a
F<Makefile.PL>. This file is executed and the resulting F<MYMETA.yml>
inspected for prerequisites (currently only the C<requires> section).
Then a simple-minded module-to-package translation is done, and the
list of prerequisites is (tried to) install using C<PPM>.

Typically called from L<C<create_customized_strawberry.pl>> (with the
switch C<-try-ppm>) or L<C<create_bbbike_dist.pl>> (with the switch
C<-strawberry-opts="-try-ppm">).

Current problem: C<create_customized_strawberry.pl> runs by default
with C<$strip_vendor=1>, but then F<PPM.pm> is stripped and needs to be
re-installed ... and this may be problematic.

So currently it works only if the C<-no-strip-vendor> switch of
C<create_customized_strawberry.pl> is also set.

=cut
