#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2020,2023 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/..";

use File::Find qw(find);
use Getopt::Long;

use BBBikeYAML;

my $all_attrs;
my $with_appearances;
my $gps_data_dir = "$FindBin::RealBin/../misc/gps_data";
my $out_file;

GetOptions(
	   "all-attrs!" => \$all_attrs,
	   "with-appearances!" => \$with_appearances,
	   "gps-data-dir=s" => \$gps_data_dir,
	   "o=s" => \$out_file,
	  )
    or die "usage: $0 [--all-attrs] [--with-appearances] [--gps-data-dir ...] [-o file]\n";

my $search_key = $all_attrs ? '[^=]+' : 'srt:[^=]+';
$search_key = qr{$search_key};

my %attrs;

find sub {
    if ($File::Find::name =~ /\.trk$/) {
	open my $fh, $_
	    or die "Can't open $File::Find::name: $!";
	my $vehicle;

	my $rel_filename;
	if ($with_appearances) {
	    $rel_filename = substr($File::Find::name, length($gps_data_dir)+1);
	}

	# Only count one appearance of a key-value pair per file.
	#
	# Sometimes this is probably better (e.g. if there are
	# multiple srt:with values, where persons enter or leave the
	# ride), sometimes it is not clear if it's worse (e.g. if
	# doing a OEPNV trip to some destination, then wander a bit,
	# and finally travel back with the same OEPNV line --- should
	# it be counted once or twice?)
	my %this_file_attrs;
	my $add = sub {
	    my($k, $v, $v2) = @_;
	    if (defined $v2) {
		if (!$this_file_attrs{$k}->{$v}->{$v2}) {
		    if ($with_appearances) {
			push @{ $attrs{$k}->{$v}->{$v2} }, $rel_filename;
		    } else {
			$attrs{$k}->{$v}->{$v2}++;
		    }
		    $this_file_attrs{$k}->{$v}->{$v2} = 1;
		}
	    } else {
		if (!$this_file_attrs{$k}->{$v}) {
		    if ($with_appearances) {
			push @{ $attrs{$k}->{$v} }, $rel_filename;
		    } else {
			$attrs{$k}->{$v}++;
		    }
		    $this_file_attrs{$k}->{$v} = 1;
		}
	    }
	};

	while(<$fh>) {
	    chomp;
	    if (/^!T:/) {
		my(@attrs) = split /\t/, $_;
		shift @attrs; # !T:
		shift @attrs; # track name
		my %this_attrs;
		for my $attr (@attrs) {
		    if ($attr =~ /^($search_key)=(.*)/) {
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
			    $add->($k, $vehicle, $v);
			}
		    } elsif ($k eq 'srt:with') {
			my @items = split /,\s*/, $v;
			for my $item (@items) {
			    $add->($k, $item);
			}
		    } else {
			$add->($k, $v);
		    }
		}
	    }
	}
    }
}, $gps_data_dir;

if ($with_appearances) {
    while(my($k,$v) = each %attrs) {
	while(my($k1,$v1) = each %$v) {
	    if (ref $v1 eq 'ARRAY') {
		$v->{$k1} = [ sort @$v1 ];
	    } elsif (ref $v1 eq 'HASH') {
		while(my($k2,$v2) = each %$v1) {
		    if (ref $v2 eq 'ARRAY') {
			$v1->{$k2} = [ sort @$v2];
		    }
		}
	    }
	}
    }
}

if (defined $out_file) {
    require File::Temp;
    require File::Basename;
    my $tmp = File::Temp->new("trkstats-XXXXXXXX", DIR => File::Basename::dirname($out_file), SUFFIX => '.yml');
    $tmp->print(BBBikeYAML::Dump(\%attrs));
    $tmp->close
	or die $!;
    rename "$tmp", $out_file
	or die "Error while renaming temporary file to $out_file: $!";
} else {
    print BBBikeYAML::Dump(\%attrs);
}

__END__
