#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbdtransform.pl,v 1.1 2004/01/10 22:52:37 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Some bbd transformations

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use Strassen::Core;
use Object::Iterate 0.05 qw(iterate);
use Getopt::Long;

my($oper, @oper_args);

if (!GetOptions("translate=s" => sub {
		    $oper = "translate";
		    @oper_args = split /,/, $_[1];
		})) {
    die "usage?";
}

my $file = shift || "-";
my $s = Strassen->new($file);

{
    no strict 'refs';
    &$oper(@oper_args);
}

sub translate {
    my($dx, $dy) = @_;
    my $new_s = Strassen->new;
    iterate {
	my $r = $_;
	local $_;
	for (@{ $r->[Strassen::COORDS] }) {
	    my($x,$y) = split /,/;
	    $x += $dx;
	    $y += $dy;
	    $_ = "$x,$y";
	}
	$new_s->push($r);
    } $s;
    $new_s->write("-");
}

__END__
