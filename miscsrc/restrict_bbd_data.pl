#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: restrict_bbd_data.pl,v 2.2 2003/06/29 22:23:02 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

=head1 NAME

restrict_bbd_data.pl - Restrict bbd data to a given bounding box

=head1 SYNOPSIS

    restrict_bbd_data.pl
        [ -bbox x1,y1,x2,y2 | -in file1,... | -notin file1,... ]
        -scope [city|region|wideregion] | -strdata file1,file2,...
        -o outputfile

=head1 DESCRIPTION

Restricts bbd data to the bounding box given by C<-bbox>. The bbd data
is either the default C<strassen> and C<landstrassen> if C<-scope> is
specified, or a comma-separated list if C<-strdata> is specified. The
generated bbd is written to I<outputfile>.

Stdin/out operation with:

    restrict_bbd_data.pl -bbox ... -strdata=- -o=- < ... > ...

=cut

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
use Strassen;
use Getopt::Long;
use BBBikeRouting;
eval 'use BBBikeXS';

@Strassen::datadirs = ();

my $bbox;
my @in;
my @notin;
my $scope = "city";
my $outfile;
my $strdata;

sub usage {
    my $msg = shift;
    warn $msg if $msg;
    require Pod::Usage;
    Pod::Usage::pod2usage(1);
}

if (!GetOptions("bbox=s" => \$bbox,
		"scope=s" => \$scope,
		"datadir=s@" => \@Strassen::datadirs,
		"str|strdata=s" => \$strdata,
		"in=s" => sub {
		    @in = split /,/, $_[1];
		},
		"notin=s" => sub {
		    @notin = split /,/, $_[1];
		},
		"o=s" => \$outfile,
	       )) {
    usage();
}

usage() if (!$bbox && !@in && !@notin);
my @bbox;
if ($bbox) {
    @bbox = split /,/, $bbox;
    usage("Wrong bounding box") if @bbox != 4;
    #warn "Bounding box is @bbox\n";
    if ($bbox[0] > $bbox[2]) { @bbox[0,2] = @bbox[2,0] }
    if ($bbox[1] > $bbox[3]) { @bbox[1,3] = @bbox[3,1] }
}

my($in_net, $notin_net);
if (@in) {
    my $in_s = MultiStrassen->new(@in);
    $in_net = StrassenNetz->new($in_s);
    $in_net->make_net;
}
if (@notin) {
    my $notin_s = MultiStrassen->new(@notin);
    $notin_net = StrassenNetz->new($notin_s);
    $notin_net->make_net;
}

die "-o is missing" if !$outfile;

my $s;
if ($strdata) {
    $s = MultiStrassen->new(split /,/, $strdata)
	or die "Can't make Strassen object of $strdata";
} else {
    my $routing = BBBikeRouting->new->init_context;
    my $context = $routing->Context;
    $context->Scope($scope) if $scope;
    $s = $routing->init_str;
}

my $new_s = Strassen->new;
$s->init;
while(1) {
    my $r = $s->next;
    last if !@{ $r->[Strassen::COORDS] };

    my @new_c;
    my $push_it = sub {
	my $new_r = [];
	for (0 .. Strassen::LAST) {
	    next if $_ == Strassen::COORDS;
	    $new_r->[$_] = $r->[$_];
	}
	$new_r->[Strassen::COORDS] = [@new_c];
	$new_s->push($new_r);
	@new_c = ();
    };

    # XXX Should be combinable with -bbox
    if ($in_net) {
	for my $i (1 .. $#{ $r->[Strassen::COORDS] }) {
	    my($xy1,$xy2) = ($r->[Strassen::COORDS][$i-1],
			     $r->[Strassen::COORDS][$i]);
	    if (exists $in_net->{Net}{$xy1}{$xy2}) {
		$new_s->push($r);
		last;
	    }
	}
    } elsif ($notin_net) {
    CHECK: {
	    for my $i (1 .. $#{ $r->[Strassen::COORDS] }) {
		my($xy1,$xy2) = ($r->[Strassen::COORDS][$i-1],
				 $r->[Strassen::COORDS][$i]);
		if (exists $notin_net->{Net}{$xy1}{$xy2}) {
		    last CHECK;
		}
	    }
	    $new_s->push($r);
	}
    } else {
	# XXX What about gaps, that is, if a street leaves the bbox and
	# enters again?
	for my $c (@{ $r->[Strassen::COORDS] }) {
	    my($x,$y) = split /,/, $c;
	    if ($x >= $bbox[0] && $x <= $bbox[2] &&
		$y >= $bbox[1] && $y <= $bbox[3]) {
		push @new_c, $c;
	    } else {
		if (@new_c) {
		    $push_it->();
		}
	    }
	}
	if (@new_c) {
	    $push_it->();
	}
    }
}
$new_s->write($outfile);

__END__
