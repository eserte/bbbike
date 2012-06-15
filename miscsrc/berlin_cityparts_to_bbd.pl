#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Getopt::Long;

use Geography::Berlin_DE;
use Strassen::Core;

my $ortsteile_bbd = Strassen->new("berlin_ortsteile");
my $out_bbd       = Strassen->new;
my $geo           = Geography::Berlin_DE->new;

my $cat;
my $inbbd;
GetOptions("cat=s" => \$cat,
	   "inbbd" => \$inbbd,
	  )
    or die "usage?";

while(<>) {
    chomp;
    if ($inbbd) {
	if (!s{^# REPLACE }{}) {
	    print $_, "\n";
	    next;
	}
    }
    my($type,$name) = split /:/;
    if ($type eq 'BEZIRK') {
	my @ortsteile = $geo->get_all_subparts($name);
	if (!@ortsteile) {
	    die "Wrong BEZIRK $name?";
	}
	add_records_for_ortsteile($_, @ortsteile);
    } elsif ($type eq 'ALTBEZIRK') {
	my $citypart_to_subcitypart = $geo->citypart_to_subcitypart;
	if (!exists $citypart_to_subcitypart->{$name}) {
	    die "Wrong ALTBEZIRK $name?";
	}
	my @ortsteile = @{ $citypart_to_subcitypart->{$name} };
	# convention: every Bezirk has a Ortsteil with same name
	push @ortsteile, $name;
	add_records_for_ortsteile($_, @ortsteile);
    } elsif ($type eq 'ORTSTEIL') {
	add_records_for_ortsteile($_, $name);
    } else {
	die "Please specify TYPE:NAME where TYPE is BEZIRK, ALTBEZIRK, ORTSTEIL\n";
    }
}

print $out_bbd->as_string;

sub add_records_for_ortsteile {
    my($name, @ortsteile) = @_;
    my $rx = '^(' . join("|", map { quotemeta } @ortsteile) . ')$';
    $rx = qr{$rx};
    my @res = $ortsteile_bbd->get_all_by_name($rx, 1);
    if (!@res) {
	die "No result for regexp $rx";
    }
    for my $ret (@res) {
	$ret->[Strassen::NAME] = $name;
	if (defined $cat) {
	    $ret->[Strassen::CAT] = $cat;
	}
	$out_bbd->push($ret);
    }
}

__END__

=head1 NAME

berlin_cityparts_to_bbd.pl - create bbd files for Berlin city parts

=head1 SYNOPSIS

    berlin_cityparts_to_bbd.pl [-inbbd] [-cat ...] < input > output.bbd

=head1 DESCRIPTION

There are two modes:

=over

=item 1.

Use a template .bbd file with "C<# REPLACE I<TYPE>:I<NAME>>" tags
which are expanded to citypart polygons. This mode is triggered with
the C<-inbbd> option.

=item 2.

Use a text file with I<TYPE>:I<NAME> lines as input. This is the
default.

=back

I<TYPE> is either BEZIRK, ALTBEZIRK, or ORTSTEIL.

I<NAME> is the name of the city part.

C<-cat> may be specified to change the category.

=cut
