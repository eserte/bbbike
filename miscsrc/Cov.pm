# -*- perl -*-

#
# $Id: Cov.pm,v 1.4 2003/06/02 23:00:45 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# TODO: Can I use PDL to speed this thing up?

package Statistics::Descriptive::Full;
use Statistics::Descriptive;
use Math::MatrixReal;
use strict;

sub variance_n {
    my $self = shift;
    my $n = $self->count;
    my $mean_x = $self->mean;
    my $sum = 0;
    foreach ($self->get_data) {
	my $q = $_-$mean_x;
	$sum += $q*$q;
    }
    $sum/$n;
}

sub covariance {
    my($set1, $set2) = @_;
    die 'usage: $stat1->covariance($stat2)'
      if !$set2->isa('Statistics::Descriptive::Full');
    my $n = $set1->count;
    die 'count($stat1) != count($stat2' if $n != $set2->count;
    my $mean_x = $set1->mean;
    my $mean_y = $set2->mean;
    my $sum = 0;
    my @x = $set1->get_data;
    my @y = $set2->get_data;
    for(my $j = 0; $j <= $#x; $j++) {
	$sum += ($x[$j]-$mean_x)*($y[$j]-$mean_y);
    }
    $sum/$n;
}

# abhängige Variable ist $set2
sub linear_regression {
    my($set1, $set2) = @_;
    die 'usage: $stat1->covariance($stat2)'
      if !$set2->isa('Statistics::Descriptive::Full');
    my $b1 = $set1->covariance($set2) / $set1->variance_n;
    my $b0 = $set2->mean - $set1->mean*$b1;
    ($b0, $b1);
}

sub bestimmtheitsmass { # XXX englische Bezeichnung
    my($set1, $set2) = @_;
    my $b1 = ($set1->linear_regression($set2))[1];
    $b1*$b1*$set1->variance_n/$set2->variance_n;
}

# abhängige Variable wird zuerst angegeben (im Gegensatz zu linear_regression)
sub multiple_regression {
    my(@sets) = @_;
    my @setdata;
    for(my $i = 0; $i <= $#sets; $i++) {
	die '$set must be a Statistics::Descriptive::Full object'
	  if !$sets[$i]->isa('Statistics::Descriptive::Full');
	@{$setdata[$i]} = $sets[$i]->get_data;
    }
    my $yset = shift @sets;
    my $ysetdata = shift @setdata;

    my $X = new Math::MatrixReal $sets[0]->count, scalar @sets + 1;
    # x_0
    for(my $i = 1; $i <= $sets[0]->count; $i++) {
	$X->assign($i, 1, 1);
    }
    # x_1 .. x_m
    for(my $j = 2; $j <= scalar @sets + 1; $j++) {
	for(my $i = 1; $i <= $sets[0]->count; $i++) {
	    $X->assign($i, $j, $setdata[$j-2]->[$i-1]);
	}
    }

    my $y = new Math::MatrixReal $yset->count, 1;
    for(my $i = 1; $i <= $yset->count; $i++) {
	$y->assign($i, 1, $ysetdata->[$i-1]);
    }

    my $XX = ~$X * $X;
    my $LR_matrix = $XX->decompose_LR();
    my $inv;
    if (!($inv = $LR_matrix->invert_LR())) {
	die "Can't invert matrix";
    }
    my $b = $inv*~$X*$y;
    my @b;
    for (1 .. ($b->dim)[0]) {
	push(@b, $b->element($_, 1));
    }
    @b;
}

return 1 if caller();

