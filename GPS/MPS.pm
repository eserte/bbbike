# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2003,2005,2012,2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::MPS;

use strict;
use vars qw($VERSION $DEBUG);
$VERSION = '1.11';

use Data::Dumper;

use constant SEEK_CUR => 1; # no Fcntl for 5.005 compatibility

use vars qw($magic);
$magic = qr{^MsRc[df]\0};

#$DEBUG=100;#XXXX

sub new {
    my($class) = @_;
    bless {}, $class;
}

sub check {
    my $self = shift;
    my $file = shift;
    my(%args) = @_;

    open my $F, $file or return 0;
    read($F, my $buf, 6);
    return 0 if ($buf !~ $magic);
    1;
}

sub convert_to_route {
    my($self, $file, %args) = @_;
    require GPS::GpsmanData;
    require File::Temp;
    my($fh,$tmpfile) = File::Temp::tempfile(UNLINK => 1,
					    SUFFIX => ".trk");
    open my $INFH, $file or die "Can't read $file: $!";
    binmode $INFH;
    print $fh $self->convert_to_gpsman($INFH);
    close $fh;
    my @res = GPS::GpsmanMultiData->convert_to_route($tmpfile, %args);
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

EOF

    my $buf;
    read($fh, $buf, 6);
    if ($buf !~ $magic) {
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
	} elsif ($buf eq 'Di') {
	    $version = 2; # XXX?
	} elsif ($buf eq 'Dl') {
	    $version = 3; # even newer
	} elsif ($buf eq 'Dg') {
	    $version = 2; # XXX not tested, but Dg is between Df and Di...
	} else {
	    warn "Unknown version $buf";
	}
	seek($fh, 1, SEEK_CUR);
    }

    read($fh, $buf, 4);
    my $len = unpack("V", $buf);
    warn "Len=$len\n" if $DEBUG;
    read($fh, $buf, $len+1);

    if ($version == 3) {
	my($date, $time) = split /\0/, substr($buf, 7);
	warn "Datum=$date, Zeit=$time\n" if $DEBUG;

	my $mapsource = "";
	while(1) {
	    read($fh, my $ch, 1);
	    last if $ch eq "\0";
	    $mapsource .= $ch;
	}
	warn "Mapsource=$mapsource\n" if $DEBUG;
    }

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

    my $last_type;

    while(!eof($fh)) {
	read($fh, $buf, 4);
	my $len = unpack("V", $buf);
	read($fh, $buf, $len+1);
	my $type = substr($buf, 0, 1);
#XXX warn "$type $len";
	if ($type eq 'W') {
	    my($name) = substr($buf, 1) =~ /^([^\0]+)/;
	    warn "Waypoint <$name>\n" if $DEBUG;
	    $buf = substr($buf, length($name)); # skip name
	    $buf = substr($buf, 12*2+($version>=2?1:0)+($version>=3?4:0)); # skip 00 and ff
	    my $coords = substr($buf, 0, 16);
	    my @c = unpack("V*", $coords);
	    my $lat = semicirc_deg($c[0]);
	    my $long = semicirc_deg($c[1]);
#XXX warn "$name $version $lat $long";
	    if (!defined $last_type || $last_type ne 'W') {
		$out .= "!W:\n";
		$last_type = 'W';
	    }
	    $out .= uc($name) . "\t\tN$lat\tE$long\n";
	    if (substr($buf, 17) !~ /^\0/) {
		warn "Comment: " . substr($buf, 17) if $DEBUG;
	    }
	} elsif ($type eq 'T') {
	    my $dist = 0;
	    my($name) = substr($buf, 1) =~ /^([^\0]+)/;
	    warn "Track $name\n" if $DEBUG;
	    $out .= "!T:\t$name\n";
	    $last_type = 'T';
	    $buf = substr($buf, length($name));
	    my($lastx,$lasty);
	    my $reclen = $version <= 2 ? 31 : 24;
#XXX del
# for (0..$reclen) {
# my$rec=substr($buf,$_,$reclen);
# my @f = unpack("V*", substr($rec, -5*4));#-5
# #warn join(", ", @f),"\n" if $DEBUG;
# my $lat = semicirc_deg($f[0]);
# my $long = semicirc_deg($f[1]);
# warn "$lat $long\n";
# }
	    while($buf =~ /(.{$reclen})/gs) {
		my $rec = $1;
		#warn $rec if $DEBUG;
		my @f = unpack("V*", $version <= 2 ? substr($rec, -5*4) : substr($rec, 11));
		#warn join(", ", @f),"\n" if $DEBUG;
		my $lat = semicirc_deg($f[0]);
		my $long = semicirc_deg($f[1]);
#XXX del: warn "$lat/$long";
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
	} elsif ($type eq 'V') {
	    # seems to be a no-op
	} else {
	    warn "Unhandled type <$type>, len <$len>. Dump: " . 
		Data::Dumper->new([$buf],[qw()])->Indent(1)->Useqq(1)->Dump;
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
