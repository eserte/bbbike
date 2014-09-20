# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeDraw::Mapnik;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use base qw(BBBikeDraw);

use File::Basename qw(dirname);
use File::Temp qw(tempfile);

use BBBikeUtil qw(bbbike_root);
use Karte;
Karte::preload(qw(Standard Polar));

my $mapnik_bbbike_dir;
my $mapnik_renderer_py;

sub init {
    my $self = shift;

    $self->SUPER::init();

    $self->{Width}  ||= 800;
    $self->{Height} ||= 600;

    if ($self->{OldImage}) {
	die "No support for drawing over old images in " . __PACKAGE__;
    }

    if (!$mapnik_bbbike_dir) {
	my $src_dir = dirname(bbbike_root);
	my $candidate = "$src_dir/mapnik-bbbike";
	if (-d $candidate) {
	    $mapnik_bbbike_dir = $candidate;
	    my $renderer_candidate = "$mapnik_bbbike_dir/tools/renderer.py";
	    if (-e $renderer_candidate) {
		$mapnik_renderer_py = $renderer_candidate;
	    } else {
		die <<EOF;
$renderer_candidate is missing.
Please check if your mapnik-bbbike directory
$mapnik_bbbike_dir
is complete
EOF
	    }
	} else {
	    die <<EOF
The mapnik-bbbike directory is missing, expected in
$candidate.
You can get it using the following commands:

    cd $src_dir
    git clone git://github.com/eserte/mapnik-bbbike.git
EOF
	}
    }

    $self;
}

sub draw_route {
    die "draw_route not supported in " . __PACKAGE__;
}

sub flush {
    my($self, %args) = @_;

    my(@bbox) = (
		 $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map($self->{Min_x}, $self->{Min_y})),
		 $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map($self->{Max_x}, $self->{Max_y})),
		);
    my @cmd = (
	       $mapnik_renderer_py,
	       '--geometry=' . $self->{Width} . 'x' . $self->{Height},
	       '--bbox=' . join(',', @bbox),
	      );

    my(undef,$tmpfile) = tempfile(SUFFIX => '_bbbikedraw_mapnik.png', UNLINK => 1); # XXX correct suffix?
    push @cmd, "--outfile=$tmpfile";
    system @cmd;
    if ($? != 0) {
	die "'@cmd' failed with exit code $?";
    }

    my $ofh = $args{Fh} || $self->{Fh};
    binmode $ofh;
    open my $ifh, "<", $tmpfile
	or die "Can't open $tmpfile: $!";
    local $/ = \4096;
    while(<$ifh>) {
	print $ofh $_;
    }
    close $ofh
	or die "Error while closing output filehandle: $!";

    unlink $tmpfile; # as early as possible
}

1;

__END__

=head1 NAME

BBBikeDraw::Mapnik - render BBBike maps with Mapnik

=head1 SYNOPSIS

Using C<bbbikedraw.pl>:

    ./miscsrc/bbbikedraw.pl -module Mapnik -geometry 800x600 -bbox 8067,12651,12121,10233 -o map.png

=head1 PREREQUISITES

It's necessary to prepare C<mapnik-bbbike> first. git-clone it from

    git://github.com/eserte/mapnik-bbbike.git

next to the F<bbbike> directory, and follow the setup instructions in
F<mapnik-bbbike/tools/Makefile>.

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<BBBikeDraw>.

=cut
