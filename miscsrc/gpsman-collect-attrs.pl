#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2020 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use File::Find qw(find);
use Getopt::Long;
use YAML;

my $gps_data_dir = "$ENV{HOME}/src/bbbike/misc/gps_data";

GetOptions("gps-data-dir=s" => \$gps_data_dir)
    or die "usage?";

my %attrs;

find sub {
    if ($File::Find::name =~ /\.trk$/) {
	open my $fh, $File::Find::name
	    or die "Can't open $File::Find::name: $!";
	my $vehicle;
	while(<$fh>) {
	    chomp;
	    if (/^!T:/) {
		my(@attrs) = split /\t/, $_;
		shift @attrs; # !T:
		shift @attrs; # track name
		my %this_attrs;
		for my $attr (@attrs) {
		    if ($attr =~ /^(srt:[^=]+)=(.*)/) {
			my($k,$v) = ($1,$2);
			$this_attrs{$k} = $v;
		    }
		}
		while(my($k,$v) = each %this_attrs) {
		    if ($k eq 'srt:brand') {
			if (exists $this_attrs{'srt:vehicle'}) {
			    $vehicle = $this_attrs{'srt:vehicle'};
			}
			if (!$vehicle) {
			    warn "Found '$k' '$v' without 'srt:vehicle' in file '$File::Find::name', ignoring.\n";
			} else {
			    $attrs{$k}->{$vehicle}->{$v}++;
			}
		    } elsif ($k eq 'srt:with') {
			my @items = split /,\s*/, $v;
			for my $item (@items) {
			    $attrs{$k}->{$item}++;
			}
		    } else {
			$attrs{$k}->{$v}++;
		    }
		}
	    }
	}
    }
}, $gps_data_dir;

print YAML::Dump(\%attrs);

__END__
