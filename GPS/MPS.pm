# -*- perl -*-

#
# $Id: MPS.pm,v 1.2 2003/12/22 19:44:38 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::MPS;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use Fcntl qw(:seek);

sub check {
    my $self = shift;
    my $file = shift;
    my(%args) = @_;

    open(F, $file) or return 0;
    read(F, my $buf, 6);
    return 0 if ($buf ne "MsRcd\0");
    1;
}

sub convert_to_route {
    my($self, $file, %args) = @_;
    require GPS::GpsmanData;
    require File::Temp;
    my($fh,$tmpfile) = File::Temp::tempfile(UNLINK => 1,
					    SUFFIX => ".trk");
    open(INFH, $file) or die "Can't read $file: $!";
    binmode INFH;
    print $fh $self->convert_to_gpsman(\*INFH);
    close $fh;
    my @res = GPS::GpsmanData->convert_to_route($tmpfile, %args);
    unlink $tmpfile;
    @res;
}

sub convert_to_gpsman {
    my $self = shift;
    my $fh = shift;

    my $out = <<EOF;
% Written by $0 @{[ scalar localtime ]}
% Edit at your own risk!

!Format: DDD 1 WGS 84
!Creation: yes

EOF

    my $buf;
    read($fh, $buf, 6);
    if ($buf ne "MsRcd\0") {
	die "Wrong magic";
    }

    my $version;

    {
	read($fh, $buf, 4);
	my $len = unpack("V", $buf);
	read($fh, $buf, $len);
	if ($buf eq 'Dd') {
	    $version = 1; # old
	} elsif ($buf eq 'Df') {
	    $version = 2; # new
	} else {
	    warn "Unknown version $buf";
	}
	seek($fh, 1, SEEK_CUR);
    }

    read($fh, $buf, 4);
    my $len = unpack("V", $buf);
    #warn $len;
    read($fh, $buf, $len+1);

    #warn $buf;
#      read($fh, $buf, 6);
#      if ($buf ne "buell\0") {
#  	warn "$buf is not always buell";
#      }
#      read($fh, $buf, 11);
#      warn $buf; # date
#      seek($fh, 1, SEEK_CUR);
#      read($fh, $buf, 8);
#      warn $buf; # time
#    seek($fh, 1, SEEK_CUR);

    while(!eof($fh)) {
	read($fh, $buf, 4);
	my $len = unpack("V", $buf);
	read($fh, $buf, $len+1);
	my $type = substr($buf, 0, 1);
	if ($type eq 'W') {
	    my($name) = substr($buf, 1) =~ /^([^\0]+)/;
#	    warn "Waypoint $name\n";
	    $buf = substr($buf, length($name)); # skip name
	    $buf = substr($buf, 12*2+($version==2?1:0)); # skip 00 and ff
	    my $coords = substr($buf, 0, 16);
	    my @c = unpack("V*", $coords);
#	    warn join(", ", @c), "\n";;
#warn semicirc_deg($c[0]);
#warn semicirc_deg($c[1]);
	    if (substr($buf, 17) !~ /^\0/) {
#		warn substr($buf, 17); # comment
	    }
	} elsif ($type eq 'T') {
	    my $dist = 0;
	    my($name) = substr($buf, 1) =~ /^([^\0]+)/;
#	    warn "Track $name\n";
	    $out .= "!T:\t$name\n";
	    $buf = substr($buf, length($name));
	    my($lastx,$lasty);
	    while($buf =~ /(.{31})/gs) {
		my $rec = $1;
		#warn $rec;
		my @f = unpack("V*", substr($rec, -5*4));#-5
#		warn join(", ", @f),"\n";
		my $lat = semicirc_deg($f[0]);
		my $long = semicirc_deg($f[1]);
		$out .= "\t31-Dec-1989 01:00:00\tN$lat\tE$long\t0.0\n";
		if (0) {
		    #warn join(", ", unpack("c*", pack("V", $f[1])));
		    my @h = unpack("v*", pack("V", $f[-2]));
		    $h[1]-=16384; # XXX wahrscheinlich height
		    warn join(", ", @h);
		    #warn scalar localtime($f[-1]-1040684395);
		    if (defined $lastx) {
			$dist += sqrt(sqr($lastx-$f[0])+
				      sqr($lasty-$f[1]));
		    }
		    ($lastx,$lasty) = @f[0,1];
		}
	    }
#	    warn "Dist: $dist";
	} else {
	    warn "Unhandled type $type";
	}
    }
    $out;
}

sub semicirc_deg {
    return shift() * (180/2**31);
}

sub deg_semicirc {
    return shift() * (2**31/180);
}

sub strip0 { $_[0] =~ s/\0+// }

# REPO BEGIN
# REPO NAME sqr /home/e/eserte/src/repository 
# REPO MD5 846375a266b4452c6e0513991773b211

sub sqr { $_[0] * $_[0] }
# REPO END

1;

__END__
