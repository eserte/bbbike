#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2004,2015,2021 Slaven Rezic. All rights reserved.
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
use Getopt::Long;

my($oper, @oper_args);

if (!GetOptions
    (
     'translate=s' => sub {
	 $oper = 'translate';
	 @oper_args = split /,/, $_[1];
     },
     'oneline' => sub {
	 $oper = 'oneline';
     },
     'set-name=s' => sub {
	 $oper = 'set';
	 push @oper_args, 'name' => $_[1];
     },
     'set-cat=s' => sub {
	 $oper = 'set';
	 push @oper_args, 'cat' => $_[1];
     },
     'polygon-center|area-center' => sub {
	 $oper = 'polygon_center';
     },
    ),
   ) {
    die "usage?";
}

if (!$oper) {
    die "Please specify an operation (--translate, --oneline ... etc.)\n";
}

my $file = shift || "-";
my $s = Strassen->new_stream($file);

{
    no strict 'refs';
    &$oper(@oper_args);
}

sub set {
    my(%args) = @_;
    my $new_s = Strassen->new;
    $s->read_stream
	(sub {
	     my($r) = @_;
	     if (defined $args{name}) {
		 $r->[Strassen::NAME] = $args{name};
	     }
	     if (defined $args{name}) {
		 $r->[Strassen::CAT] = $args{cat};
	     }
	     $new_s->push($r);
	 });
    $new_s->write('-');
}

sub oneline {
    my($new_name, $new_cat, @new_coords);
    $s->read_stream
	(sub {
	     my($r) = @_;
	     if (!defined $new_name) {
		 $new_name = $r->[Strassen::NAME];
	     }
	     if (!defined $new_cat) {
		 $new_cat = $r->[Strassen::CAT];
	     }
	     my @c = @{ $r->[Strassen::COORDS] };
	     if (@new_coords && $new_coords[-1] eq $c[0]) {
		 shift @c;
	     }
	     push @new_coords, @c;
	 });

    my $new_s = Strassen->new;
    $new_s->push([$new_name, \@new_coords, $new_cat]);
    $new_s->write('-');
}

sub translate {
    my($dx, $dy) = @_;
    my $new_s = Strassen->new;
    $s->read_stream
	(sub {
	     my($r) = @_;
	     local $_;
	     for (@{ $r->[Strassen::COORDS] }) {
		 my($x,$y) = split /,/;
		 $x += $dx;
		 $y += $dy;
		 $_ = "$x,$y";
	     }
	     $new_s->push($r);
	 });
    $new_s->write("-");
}

sub polygon_center {
    require VectorUtil;
    my $new_s = Strassen->new;
    my $karte = $s->get_karte;
    $s->read_stream
	(sub {
	     my($r) = @_;
	     my @c = VectorUtil::get_polygon_center(map { split /,/ } @{ $r->[Strassen::COORDS] });
	     if (!@c) {
		 warn "Cannot get polygon center for $r->[Strassen::NAME] @{ $r->[Strassen::COORDS] }, skip this record...\n";
	     } else {
		 @c = $karte->trim_accuracy(@c);
		 $r->[Strassen::COORDS] = [join(",", @c)];
		 $new_s->push($r);
	     }
	 });
    $new_s->write('-');
}

__END__

=head1 NAME

bbdtransform.pl - various transformations on bbd files

=head1 SYNOPSIS

    ./bbdtransform.pl --translate=dx,dy [file]

    ./bbdtransform.pl --oneline [file]

    ./bbdtransform.pl --set-name=name --set-cat=cat [file]

    ./bbdtransform.pl --polygon-center [file]

=head1 DESCRIPTION

Following transformations are available:

=over

=item translate

Translate all coordinates by the given x and y values.

=item oneline

Combine all lines in the bbd file to a single line. Name and category
are taken from the first line.

=item set-name

Set the name of lines to the given argument.

=item set-cat

Set the category of lines to the given argument.

=item polygon-center

Treat source coordinates as areas and replace with the center coordinate.

=back

Note: currently these transformations lose all global and local
directives.

Note: except for C<--set-name> and C<--set-cat> it is not possible to
combine transformation operations. Use operating system pipes instead.

=head1 AUTHOR

Slaven Rezic

=cut
