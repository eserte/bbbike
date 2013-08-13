# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package
    Typ2Legend::XPM;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Storable qw(dclone);

sub new {
    my($class, $lines) = @_;

    my %xpm;

    my $header = shift @$lines;
    if (my($w,$h,$numcolors,$charonpixel) = $header =~ m{^"(\d+)\s+(\d+)\s+(\d+)\s+(\d+)"$}) {
	if ($charonpixel != 2) {
	    die "We deal only with charonpixel=2, not $charonpixel";
	}
	$xpm{w} = $w;
	$xpm{h} = $h;
	$xpm{numcolors} = $numcolors;
	$xpm{charonpixel} = $charonpixel;
    } else {
	die "Cannot parse XPM header '$header'";
    }

    {
	my @colormap;
	my $charonpixel = $xpm{charonpixel};
	for my $i (0 .. $xpm{numcolors}-1) {
	    my $colormap_line = shift @$lines;
	    if (!defined $colormap_line) {
		die "Short read while parsing XPM colormap";
	    }
	    if (my($code, $coltype, $color) = $colormap_line =~ m{^"(\S{$charonpixel})\s+(\S+)\s+(#[0-9a-fA-F]{6}|none)"$}) {
		push @colormap, {code => $code, coltype => $coltype, color => $color};
	    } else {
		die "Cannot parse XPM colormap line '$colormap_line'";
	    }
	}
	$xpm{colormap} = \@colormap;
    }

    $xpm{data} = $lines;

    bless \%xpm, $class;
}

sub clone {
    my $self = shift;
    dclone $self;
}

sub transform {
    my($self,%opts) = @_;
    my $prefer13 = delete $opts{prefer13}; # over 11
    my $prefer15 = delete $opts{prefer15}; # over 14
    die "Unhandled arguments: " . join(" ", %opts) if %opts;

    my %ret;

    my $w = $self->{w};
    my $numcolors = $self->{numcolors};

    if ($w == 0) {
	if      ($numcolors == 1) { # type 6
	    my $day_night = $self->clone;
	    $day_night->{data} = _create_xpm_polygon_body();
	    $day_night->{w} = $day_night->{h} = 32;
	    $ret{'day+night'} = $day_night;
	} elsif ($numcolors == 2) { # type 7
	    my($day, $night) = ($self->clone, $self->clone);
	    for my $clone ($day, $night) {
		$clone->{data} = _create_xpm_polygon_body();
		$clone->{w} = $clone->{h} = 32;
		$clone->{numcolors} = 1;
	    }
	    $day->{colormap}   = [ dclone $self->{colormap}->[0] ];
	    $night->{colormap} = [ dclone $self->{colormap}->[1] ];
	    $night->{colormap}->[0]->{code} = 'XX';
	    $ret{'day'} = $day;
	    $ret{'night'} = $night;
	} else {
	    die "Cannot handle w=0 and numcolors=$numcolors";
	}
    } else {
	if    ($numcolors == 2) { # type 8, 14, or 15
	    if ($self->{colormap}->[1]->{color} eq 'none') { # type 14
		my $day_night = $self->clone;
		($day_night->{colormap}->[0]->{color},
		 $day_night->{colormap}->[1]->{color})
		    = ('none',
		       $day_night->{colormap}->[0]->{color});
		$ret{'day+night'} = $day_night;
	    } elsif ($prefer15) { # type 15
		my($day, $night) = ($self->clone, $self->clone);
		($day->{colormap}->[0]->{color},
		 $day->{colormap}->[1]->{color})
		    = ('none',
		       $day->{colormap}->[0]->{color});
		($night->{colormap}->[0]->{color},
		 $night->{colormap}->[1]->{color})
		    = ('none',
		       $night->{colormap}->[1]->{color});
		$ret{'day'} = $day;
		$ret{'night'} = $night;
	    } else { # type 8
		my $day_night = $self->clone;
		($day_night->{colormap}->[0]->{color},
		 $day_night->{colormap}->[1]->{color})
		    = ($day_night->{colormap}->[1]->{color},
		       $day_night->{colormap}->[0]->{color});
		$ret{'day+night'} = $day_night;
	    }
	} elsif ($numcolors == 4) { # type 9
	    my($day, $night) = ($self->clone, $self->clone);
	    for my $clone ($day, $night) {
		$clone->{numcolors} = 2;
	    }
	    ($day->{colormap}->[0]->{color},
	     $day->{colormap}->[1]->{color})
		= ($day->{colormap}->[1]->{color},
		   $day->{colormap}->[0]->{color});
	    ($night->{colormap}->[0]->{color},
	     $night->{colormap}->[1]->{color})
		= ($night->{colormap}->[3]->{color},
		   $night->{colormap}->[2]->{color});
	    for my $clone ($day, $night) {
		splice @{ $clone->{colormap} }, 2; # delete the rest two colors
	    }
	    $ret{'day'} = $day;
	    $ret{'night'} = $night;
	} elsif ($numcolors == 3) { # type 11 or 13
	    my($day, $night) = ($self->clone, $self->clone);
	    for my $clone ($day, $night) {
		$clone->{numcolors} = 2;
	    }
	    if (!$prefer13) {
		($day->{colormap}->[0]->{color},
		 $day->{colormap}->[1]->{color})
		    = ('none',
		       $day->{colormap}->[0]->{color});
		($night->{colormap}->[0]->{color},
		 $night->{colormap}->[1]->{color})
		    = ($night->{colormap}->[2]->{color},
		       $night->{colormap}->[1]->{color});
	    } else {
		($day->{colormap}->[0]->{color},
		 $day->{colormap}->[1]->{color})
		    = ($night->{colormap}->[1]->{color},
		       $day->{colormap}->[0]->{color});
		($night->{colormap}->[0]->{color},
		 $night->{colormap}->[1]->{color})
		    = ('none',
		       $night->{colormap}->[2]->{color});
	    }
	    for my $clone ($day, $night) {
		splice @{ $clone->{colormap} }, 2; # delete the rest two colors
	    }
	    $ret{'day'} = $day;
	    $ret{'night'} = $night;
	} elsif ($numcolors == 1) {
	} else {
	    die "Cannot handled numcolors=$numcolors";
	}
    }
    \%ret;
}

sub as_string {
    my $self = shift;
    my $s = <<'EOF';
/* XPM */
static char *XPM[] = {
EOF
    $s .= sprintf qq{"%d %d %d %d",\n}, $self->{w}, $self->{h}, $self->{numcolors}, $self->{charonpixel};
    for my $cmapline (@{ $self->{colormap} }) {
	$s .= sprintf qq{"%s %s %s",\n}, $cmapline->{code}, $cmapline->{coltype}, $cmapline->{color};
    }
    $s .= join ",\n", @{ $self->{data} };
    $s .= "\n};\n";
    $s;
}

sub _create_xpm_line_32 {
    my($colorcode) = @_;
    qq{"}.($colorcode x 32) . qq{"};
}

sub _create_xpm_polygon_body {
    [ map { _create_xpm_line_32('XX') } 1..32 ]
}


1;

__END__
