# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2014 Slaven Rezic. All rights reserved.
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
$VERSION = '1.00';

use Storable qw(dclone);

sub new {
    my($class, $lines) = @_;

    my %xpm;

    $lines = dclone $lines;
    my $header = shift @$lines;
    if (my($w,$h,$numcolors,$charonpixel) = $header =~ m{^"(\d+)\s+(\d+)\s+(\d+)\s+(\d+)",?$}) {
	$charonpixel = 1 if $charonpixel == 0; # TYPViewer oddity, this is for line items with just a xpm colormap and no "body"
	if ($charonpixel < 1 || $charonpixel > 2) {
	    die "We deal only with charonpixel=1 or 2, not $charonpixel";
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
	    if (my($code, $coltype, $color) = $colormap_line =~ m{^"(.{$charonpixel})\s+(\S+)\s+(#[0-9a-fA-F]{6}|none)",?$}) {
		push @colormap, {code => $code, coltype => $coltype, color => $color};
	    } else {
		die "Cannot parse XPM colormap line '$colormap_line' (charonpixel is $charonpixel)";
	    }
	}
	$xpm{colormap} = \@colormap;
    }

    s{,$}{} for @$lines;
    $xpm{data} = $lines;

    bless \%xpm, $class;
}

sub clone {
    my $self = shift;
    dclone $self;
}

sub transform {
    my($self,%opts) = @_;
    my $linewidth = delete $opts{linewidth};
    my $borderwidth = delete $opts{borderwidth};
    die "Unhandled arguments: " . join(" ", %opts) if %opts;

    my %ret;

    my $w = $self->{w};
    my $numcolors = $self->{numcolors};
    my @colorcode = map { $_->{code} } @{ $self->{colormap} || [] };

    if ($w == 0) {
	if (defined $linewidth) {
	    my $final_h = $linewidth + ($borderwidth||0)*2;
	    if (defined $borderwidth) {
		if      ($numcolors == 2) { # line type 0
		    my $day_night = $self->clone;
		    $day_night->{data} = _create_xpm_line_body($linewidth, $colorcode[0],
							       $borderwidth, $colorcode[1]);
		    $day_night->{w} = 32;
		    $day_night->{h} = $final_h;
		    $ret{'day+night'} = $day_night;
		} elsif ($numcolors == 4) { # line type 1
		    my($day, $night) = ($self->clone, $self->clone);
		    for my $def (
				 [$day,   @colorcode[0, 1]],
				 [$night, @colorcode[2, 3]],
				) {
			my($clone, $linecolorcode, $bordercolorcode) = @$def;
			$clone->{data} = _create_xpm_line_body($linewidth, $linecolorcode,
							       $borderwidth, $bordercolorcode);
			$clone->{w} = 32;
			$clone->{h} = $final_h;
			$clone->{numcolors} = 2;
		    }
		    $day->{colormap} = [ dclone $self->{colormap}->[0],
					 dclone $self->{colormap}->[1] ];
		    $night->{colormap} = [ dclone $self->{colormap}->[2],
					   dclone $self->{colormap}->[3] ];
		    $ret{'day'} = $day;
		    $ret{'night'} = $night;
		} elsif ($numcolors == 3) { # line type 3
		    my $day = $self->clone;
		    $day->{data} = _create_xpm_line_body($final_h, $colorcode[0]);
		    $day->{w} = 32;
		    $day->{h} = $final_h;
		    $day->{numcolors} = 1;
		    $day->{colormap} = [ dclone $self->{colormap}->[0] ];
		    my $night = $self->clone;
		    $night->{data} = _create_xpm_line_body($linewidth, $colorcode[1],
							   $borderwidth, $colorcode[2]);
		    $night->{w} = 32;
		    $night->{h} = $final_h;
		    $night->{numcolors} = 2;
		    $night->{colormap} = [ dclone $self->{colormap}->[1],
					   dclone $self->{colormap}->[2] ];
		    $ret{'day'} = $day;
		    $ret{'night'} = $night;
		} else {
		    die "Cannot handle line with defined borderwidth and numcolors=$numcolors";
		}
	    } else {
		if      ($numcolors == 3) { # line type 5 # XXX not definable borderwidth --- is this a bug in the typ editor?
		    my $day = $self->clone;
		    $day->{data} = _create_xpm_line_body($linewidth);
		    $day->{w} = 32;
		    $day->{h} = $final_h;
		    $day->{numcolors} = 2;
		    $day->{colormap} = [ dclone $self->{colormap}->[0],
					 dclone $self->{colormap}->[1] ];
		    my $night = $self->clone;
		    $night->{data} = _create_xpm_line_body($linewidth);
		    $night->{w} = 32;
		    $night->{h} = $final_h;
		    $night->{numcolors} = 1;
		    $night->{colormap} = [ dclone $self->{colormap}->[2] ];
		    $night->{colormap}->[0]->{code} = 'XX';
		    $ret{'day'} = $day;
		    $ret{'night'} = $night;
		} elsif ($numcolors == 1) { # line type 6
		    my $day_night = $self->clone;
		    $day_night->{data} = _create_xpm_line_body($linewidth, 0, $colorcode[0]);
		    $day_night->{w} = 32;
		    $day_night->{h} = $final_h;
		    $ret{'day+night'} = $day_night;
		} elsif ($numcolors == 2) { # line type 7
		    my($day, $night) = ($self->clone, $self->clone);
		    for my $def (
				 [$day,   $colorcode[0]],
				 [$night, $colorcode[1]],
				) {
			my($clone, $colorcode) = @$def;
			$clone->{data} = _create_xpm_line_body($linewidth, $colorcode);
			$clone->{w} = 32;
			$clone->{h} = $final_h;
			$clone->{numcolors} = 1;
		    }
		    $day->{colormap} = [ dclone $self->{colormap}->[0] ];
		    $night->{colormap} = [ dclone $self->{colormap}->[1] ];
		    $ret{'day'} = $day;
		    $ret{'night'} = $night;
		} else {
		    die "Cannot handle line without borderwidth and numcolors=$numcolors";
		}
	    }
	} else {
	    if      ($numcolors == 1) { # polygon type 6
		my $day_night = $self->clone;
		$day_night->{data} = _create_xpm_polygon_body($self->{colormap}->[0]->{code});
		$day_night->{w} = $day_night->{h} = 32;
		$ret{'day+night'} = $day_night;
	    } elsif ($numcolors == 2) { # polygon type 7
		my($day, $night) = ($self->clone, $self->clone);
		for my $def (
			     [$day,   $self->{colormap}->[0]->{code}],
			     [$night, $self->{colormap}->[1]->{code}],
			    ) {
		    my($clone, $colorcode) = @$def;
		    $clone->{data} = _create_xpm_polygon_body($colorcode);
		    $clone->{w} = $clone->{h} = 32;
		    $clone->{numcolors} = 1;
		}
		$day->{colormap}   = [ dclone $self->{colormap}->[0] ];
		$night->{colormap} = [ dclone $self->{colormap}->[1] ];
		#$night->{colormap}->[0]->{code} = 'XX';
		$ret{'day'} = $day;
		$ret{'night'} = $night;
	    } else {
		die "Cannot handle w=0 and numcolors=$numcolors";
	    }
	}
    } else {
	if    ($numcolors == 2) { # polygon types 8, 14, or 15, line types 0, 6, or 7
	    if ($self->{colormap}->[1]->{color} eq 'none') { # polygon type 14, line type 6
		my $day_night = $self->clone;
		if (0) { # for ati.land.cz
		    ($day_night->{colormap}->[0]->{color},
		     $day_night->{colormap}->[1]->{color})
			= ('none',
			   $day_night->{colormap}->[0]->{color});
		}
		$ret{'day+night'} = $day_night;
	    } else { # polygon type 8, line type 0
		my $day_night = $self->clone;
		if (0) { # for ati.land.cz
		    ($day_night->{colormap}->[0]->{color},
		     $day_night->{colormap}->[1]->{color})
			= ($day_night->{colormap}->[1]->{color},
			   $day_night->{colormap}->[0]->{color});
		}
		$ret{'day+night'} = $day_night;
	    }
	} elsif ($numcolors == 4) { # polygon type 9, line type 1
	    my($day, $night) = ($self->clone, $self->clone);
	    for my $clone ($day, $night) {
		$clone->{numcolors} = 2;
	    }
	    if (0) { # buggy (?) ati.land.cz
		($day->{colormap}->[0]->{color},
		 $day->{colormap}->[1]->{color})
		    = ($day->{colormap}->[1]->{color},
		       $day->{colormap}->[0]->{color});
		($night->{colormap}->[0]->{color},
		 $night->{colormap}->[1]->{color})
		    = ($night->{colormap}->[3]->{color},
		       $night->{colormap}->[2]->{color});
	    } else { # TYPViewer output
		($night->{colormap}->[0]->{color},
		 $night->{colormap}->[1]->{color})
		    = ($night->{colormap}->[2]->{color},
		       $night->{colormap}->[3]->{color});
	    }
	    for my $clone ($day, $night) {
		splice @{ $clone->{colormap} }, 2; # delete the rest two colors
	    }
	    $ret{'day'} = $day;
	    $ret{'night'} = $night;
	} elsif ($numcolors == 3) { # polygon types 11 or 13, line types 3 or 5
	    my($day, $night) = ($self->clone, $self->clone);
	    for my $clone ($day, $night) {
		$clone->{numcolors} = 2;
	    }
	    ($day->{colormap}->[0]->{color},
	     $day->{colormap}->[1]->{color})
		= ('none',
		   $day->{colormap}->[0]->{color});
	    ($night->{colormap}->[0]->{color},
	     $night->{colormap}->[1]->{color})
		= ($night->{colormap}->[2]->{color},
		   $night->{colormap}->[1]->{color});
	    for my $clone ($day, $night) {
		splice @{ $clone->{colormap} }, 2; # delete the rest two colors
	    }
	    $ret{'day'} = $day;
	    $ret{'night'} = $night;
	} else {
	    die "Cannot handle numcolors=$numcolors";
	}
    }
    \%ret;
}

# The TYPViewer output is using a (private?) XPM extension for
# specifying alpha values (values are from 0 to 15). The following
# hack operates on unprocessed raw XPM lines and makes everything
# above a given threshold into a transparent value.
sub _perform_alpha_hack {
    my($parse_xpm_lines, $alpha_threshold) = @_;
    if (!defined $alpha_threshold) {
	$alpha_threshold = 15;
    }
    for my $line (@$parse_xpm_lines) {
	if (my($pre, $post, $alpha) = $line =~ m{^(.*\tc )(?:#[0-9a-fA-F]{6})(")\s+alpha=(\d+)}) {
	    if ($alpha >= $alpha_threshold) {
		$line = $pre.'none'.$post."\n";
	    }
	}
    }
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
    my($colorcode) = @_;
    [ map { _create_xpm_line_32($colorcode) } 1..32 ]
}

sub _create_xpm_line_body {
    my($linewidth, $linecolorcode, $borderwidth, $bordercolorcode) = @_;
    my @border = $borderwidth ? (map { _create_xpm_line_32($bordercolorcode) } 1..$borderwidth) : ();
    [
     @border,
     (map { _create_xpm_line_32($linecolorcode) } 1..$linewidth),
     @border,
    ];
}

1;

__END__
