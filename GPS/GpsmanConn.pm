#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: GpsmanConn.pm,v 1.9 2003/01/08 20:12:24 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# package to connect to a GPS receiver and up/download data in the
# gpsman format

package GPS::GpsmanConn;
use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);
use Config;

# XXX should go away some day...
BEGIN {
 SEARCH_FOR_BBBIKE_DIRS: {
	foreach my $dir (@INC) {
	    if (-r "$dir/GPS/SerialStty.pm") {
		last SEARCH_FOR_BBBIKE_DIRS;
	    }
	}
	eval 'use lib qw(/home/e/eserte/src/bbbike
	                 /home/e/eserte/src/bbbike/lib
	                 /home/e/eserte/src/bbbike/data)';
	eval 'use lib qw(/usr/local/bbbike
                         /usr/local/bbbike/lib
                         /usr/local/bbbike/data)';
    }
 SEARCH_FOR_GARMIN: {
	foreach my $dir (@INC) {
	    if (-r "$dir/GPS/Garmin.pm") {
		last SEARCH_FOR_GARMIN;
	    }
	}
	# make sure /tmp version is first
	if (-e "/tmp/prod.perl-GPS") {
	    eval 'use blib "/tmp/prod.perl-GPS"'; warn $@ if $@;
	} elsif (-e "/usr/local/prod.perl-GPS") {
	    eval 'use blib "/usr/local/prod.perl-GPS"'; warn $@ if $@;
	} else {
	    eval 'use blib "/home/e/eserte/work/prod.perl-GPS"';
	}
    }
    require Config;
    if ($Config::Config{archname} eq 'arm-linux') {
	eval 'use GPS::GarminX'; die $@ if $@;
    } else {
	eval 'use GPS::Garmin'; die $@ if $@; # 0.12 plus
    }
}

use Karte::Polar;

{
    package GPS::Test;
    sub new { bless {}, shift }
    sub prepare_transfer {
	my($w, $type) = @_;
	$w->{Type} = $type;
	$w->{Records} = 50;
	$w->{_First} = 1;
	$w->{WaypointIndex} = 0;
	$w->{Desc} = "";
	@{$w}{qw(Lat Lon Time Alt Depth IsFirst)}
	    = (52.663844, 13.548460, time, 30, 0, 0);
    }
    sub get_reply { }
    sub records { shift->{Records} }
    sub grab {
	my $w = shift;
	# XXX check type
	$w->{Records}--;
	$w->{Lat} += rand(0.0001)-0.00002;
	$w->{Lon} += rand(0.0001)-0.00002;
	if ($w->{Type} eq 'trk') {
	    $w->{Time} = int($w->{Time} + rand(60));
	    $w->{Alt} += rand(2)-1;
	    if ($w->{_First}) {
		$w->{IsFirst} = 1;
		$w->{_First} = 0;
	    } else {
		$w->{IsFirst} = (rand(100) <= 2 ? 1 : 0);
	    }
	    @{$w}{qw(Lat Lon Time Alt Depth IsFirst)};
	} elsif ($w->{Type} eq 'wpt') {
	    $w->{WaypointIndex}++;
	    @{$w}{qw(WaypointIndex Lat Lon Desc)};
	} else {
	    die "Unknown type $w->{Type}";
	}
    }
}

sub new {
    my($class, %args) = @_;
    my $self = {};
    $self->{GPS} = $args{GPS};
    if (!$self->{GPS}) {
	#XXX require GPS::Garmin;
	GPS::Garmin->VERSION(0.12); # 0.12 plus
	my $port = $args{Port} || ($Config::Config{archname} eq 'arm-linux' ? '/dev/ttySA0' : '/dev/cuaa0'); # more distinctions
	my $baud = $args{Baud} || 9600;
	$self->{GPS} = new GPS::Garmin('Port' => $port,
				       'Baud' => $baud,
				       verbose => $args{Verbose} > 1,
				      );
	die "Can't create GPS object" if !$self->{GPS};
    }
    $self->{Verbose} = $args{Verbose};
    bless $self, $class;
}

sub _time_to_gpsman {
    my $time = shift;
    my @l = localtime $time;
    sprintf "%02d-%s-%04d %02d:%02d:%02d",
	$l[3],
	[qw(Jan Feb May Apr May Jun Jul Aug Sep Oct Nov Dec)]->[$l[4]],
	$l[5]+1900,
	@l[2,1,0];
}

sub _ddd_to_dms {
    my($ddd, $is_lat) = @_;
    my($d,$m,$s) = Karte::Polar::ddd2dms($ddd);
    if ($s >= 59.95) {
	$s = 0;
	$m++;
	if ($m >= 60) {
	    $m = 0;
	    if ($d > 0) {
		$d++;
	    } else {
		$d--;
	    }
	}
    }
    my $prefix;
    if ($is_lat) {
	if ($d > 0) {
	    $prefix = 'N';
	} else {
	    $prefix = 'S';
	    $d = -$d;
	}
    } else {
	if ($d > 0) {
	    $prefix = 'E';
	} else {
	    $prefix = 'W';
	    $d = -$d;
	}
    }
    sprintf "%s%02d %02d %04.1f",
	$prefix,
	$d, $m, $s;
}

sub header {
    my $self = shift;
    <<EOF;
% Written by @{[ __PACKAGE__  ]}/$VERSION @{[scalar localtime]}

!Format: DMS 1 WGS 84

EOF
}

sub get_tracks {
    my($self) = @_;
    my $gps = $self->{GPS};
    $gps->prepare_transfer("trk");
    my @r;
    my $r = "";

    my $write_header = sub {
	$r .= $self->header . <<EOF;
!T:	ACTIVE LOG
EOF
    };

    $write_header->();

    my $numr = $gps->records;
    warn "records to read: $numr\n" if $self->{Verbose};
    $gps->get_reply; # overread header --- XXX valuable info here! (name etc?)
    my $r_i = 0;
    while ($gps->records) {
	my($lat,$lon,$time,$alt,$depth,$isfirst) = $gps->grab;
	if (0 && $isfirst) { # XXX ignore isfirst
	    if ($r ne "") {
		push @r, $r;
		$r = "";
	    }
	    $write_header->();
	}
	#XXX ? $r .= "!TS:\n" if $isfirst;
	$r .= join("\t",
		   "",
		   _time_to_gpsman($time),
		   _ddd_to_dms($lat, 1),
		   _ddd_to_dms($lon, 0),
		   $alt
		  ) . "\n";
	$r_i++;
	printf STDERR "Records read: %d%%     \r", $r_i/$numr*100
	    if $self->{Verbose};
    }
    printf STDERR "\n" if $self->{Verbose};
    push @r, $r;
    @r;
}

sub write_tracks {
    my($self, $tracks_ref, $directory, %opt) = @_;
    if (!-d $directory || !-w $directory) {
	die "Non-existing or non-writable directory $directory";
    }
    foreach my $track (@$tracks_ref) {
	# hack: search for first date
	my $date;
	my($Y,$M,$D,$h,$m,$s);
	foreach my $l (split /\n/, $track) {
	    if ($l =~ /^\t(\d{2})-([^-]+)-(\d{4})\s+(\d{2}):(\d{2}):(\d{2})/) {
		($D,$M,$Y,$h,$m,$s) = ($1,sprintf("%02d", monthabbrev_number($2)),$3,$4,$5,$6);
		last;
	    }
	}
	if (!defined $Y || !defined $M) {
	    die "Can't parse track for date";
	}
	my $out;
	if (!$opt{-filefmt}) {
	    $out = "$directory/$Y-$M-$D"."_$h:$m:$s.trk";
	} else {
	    my %d = (Y=>$Y,M=>$M,D=>$D,h=>$h,m=>$m,s=>$s);
	    my $replace = sub {
		my $out;
		($out = $opt{-filefmt}) =~ s/%([YMDhmsc])/$d{$1}/g;
		$out;
	    };
	    my $c = ""; # extra character
	    while (1) {
		$d{c} = $c;
		$out = $replace->();
		$out = "$directory/$out";
		if (-e $out) {
		    if ($opt{-filefmt} =~ /%c/) {
			if ($c eq '') {
			    $c = "b";
			} elsif ($c eq 'z') {
			    warn "Won't overwrite $out with -filefmt option, write to $out~";
			    $out = "$out~";
			    last;
			} else {
			    $c = chr(ord($c)+1);
			}
		    } else {
			warn "Won't overwrite $out with -filefmt option, write to $out~";
			$out = "$out~";
			last;
		    }
		} else {
		    last;
		}
	    }
	}
	open(F, ">$out") or die "Can't write to $out: $!";
	print F $track;
	close F;
    }
}

sub get_waypoints {
    my($self) = @_;
    my $gps = $self->{GPS};
    my $r = $self->header . <<EOF;
!W:
EOF
    $gps->prepare_transfer("wpt");
    my $numr = $gps->records;
    warn "records to read: $numr\n" if $self->{Verbose};
    my $r_i = 0;
    while ($gps->records) {
	my($title,$lat,$lon,$desc) = $gps->grab;
	$r .= join("\t",
		   ($title||""),
		   ($desc||""),
		   _ddd_to_dms($lat, 1),
		   _ddd_to_dms($lon, 0),
		   ) . "\n";
	$r_i++;
	printf STDERR "Records read: %d%% (%d/%d)    \r", $r_i/$numr*100, $r_i, $numr
	    if $self->{Verbose};
    }
    printf STDERR "\n" if $self->{Verbose};
    $r;
}

sub write_waypoints {
    my($self, $w, $file) = @_;
    open(F, ">$file") or die "Can't write to $file: $!";
    print F $w;
    close F;
}

sub put_route_from_bbd {
    my($self, $bbd_file, %args) = @_;
    my $gps = $self->{GPS};
    my $number = $args{-number};
    if (!defined $number) { $number = 1 }
    my $comment = $args{-comment};
    if (!defined $comment) { $comment = "Route $number" }
    require Strassen;
    require Karte;
    require Karte::Standard;
    my @d;
    push @d,
	[$gps->GRMN_RTE_HDR, $gps->pack_Rte_hdr({nmbr => $number, cmnt => $comment})];
    my $s = new Strassen $bbd_file or die "Can't open $bbd_file: $!";
    $s->init;
    my $r = $s->next;
    my $first = 1;
    my $i=0;
    foreach my $p (@{ $r->[Strassen::COORDS()] }) {
	my($lon,$lat) = split /,/, $p;
	($lon,$lat) = $Karte::map{'polar'}->standard2map($lon,$lat);
	unless ($first) {
	    push @d, [$gps->GRMN_RTE_LINK_DATA, $gps->pack_Rte_link_data];
	}
	push @d, [$gps->GRMN_RTE_WPT_DATA, $gps->pack_Rte_wpt_data({lat => $lat, lon => $lon, ident => "I".(++$i)})];
	$first = 0;
    }
    $gps->upload_data2(\@d);
}

# REPO BEGIN
# REPO NAME monthabbrev_number /home/e/eserte/src/repository 
# REPO MD5 5dc25284d4ffb9a61c486e35e84f0662
sub monthabbrev_number {
    my $mon = shift;
    +{'Jan' => 1,
      'Feb' => 2,
      'Mar' => 3,
      'Apr' => 4,
      'May' => 5,
      'Jun' => 6,
      'Jul' => 7,
      'Aug' => 8,
      'Sep' => 9,
      'Oct' => 10,
      'Nov' => 11,
      'Dec' => 12,
     }->{$mon};
}
# REPO END

{
# XXX should be moved to prod code, but is already in "new" code...
use GPS::Garmin::Handler;
package GPS::Garmin::Handler;

sub Trk_data {
    my $self = shift;
	$self->{records}--;
	my ($data) = $self->read_packet;
	my (@ident,@comm,$lt,$ln);

	# D300 Track Point Datatype
#	my ($lat,$lon,$time,$is_first) = unpack('llLb',$data);	
	# D301 Track Point Datatype
	my ($lat,$lon,$time,$alt,$dpth,$is_first) = unpack('llLffb',$data);	
    $lat = $self->semicirc_deg($lat);
    $lon = $self->semicirc_deg($lon);
#warn "$lat $lon $alt $dpth $time @{[ scalar localtime $time ]}\n";
	if ($time == 0xffffffff) { # XXX check
		undef $time;
	} else {
		$time += GPS::Garmin::Constant::GRMN_UTC_DIFF();
	}
#warn "$time @{[ scalar localtime $time ]}\n";

#XXX	$res = new GPS::Garmin::D301_Trk_data_Type;

	$self->send_packet(GPS::Garmin::Constant::GRMN_ACK());
	if($self->{records} == 0) { $self->get_reply; }
	return($lat,$lon,$time,$alt,$dpth,$is_first);
}

sub pack_Trk_hdr {
	my $self = shift;
	my $d = shift || {};
	my %d = %$d;
	$d{dspl} = 0 unless defined $d{dspl};
	$d{color} = 255 unless defined $d{color};
	if (!defined $d{ident}) {
		die "ident is required";
	}
	# D310
	my $s = pack("cC", $d{dspl}, $d{color});
	$s .= $d{ident}."\0";
	$s;
}

sub pack_Trk_data {
	my $self = shift;
	my $d = shift || {};
	my %d = %$d;
	if (!exists $d{lat} || !exists $d{lon}) {
		die "lat and lon required!";
	}
	$d{lat} = $self->deg_semicirc($d{lat});
	$d{lon} = $self->deg_semicirc($d{lon});
	$d{'time'} = 0 unless defined $d{'time'}; # XXX can't upload anyway
	$d{'alt'} = 0 unless defined $d{'alt'}; # XXX set to undef?
	$d{'dpth'} = 0 unless defined $d{'dpth'}; # XXX set to undef?
	$d{'is_first'} = 0 unless defined $d{'is_first'};
	# D301
	my $s = pack("llLffb", $d{lat}, $d{lon}, $d{'time'}, $d{'alt'},
				 $d{'dpth'}, $d{'is_first'});
	$s;
}

}

return 1 if caller;

# XXX command line

my %opt;
require Getopt::Long;
if (!Getopt::Long::GetOptions(\%opt,
			      "v+",
			      "test!", "dir|directory=s", "file=s",
			      "filefmt=s")) {
    usage();
}
my $action = shift or usage();

my $gpsconn;
if ($opt{test}) {
    $gpsconn = GPS::GpsmanConn->new(Verbose => $opt{'v'},
				    GPS => GPS::Test->new);
} else {
    $gpsconn = GPS::GpsmanConn->new(Verbose => $opt{'v'},
				   );
}

if ($action eq 'gettrk') {
    if (defined $opt{file}) {
	die "-file option is meaningless with gettrk, use -dir instead";
    }
    my @t = $gpsconn->get_tracks;
    if (@t && $opt{dir}) {
	$gpsconn->write_tracks(\@t, $opt{dir}, -filefmt => $opt{filefmt});
    } else {
	print join("\n", @t);
    }
} elsif ($action eq 'getwpt') {
    if (defined $opt{dir}) {
	die "-dir option is meaningless with getwpt, use -file instead";
    }
    my $w = $gpsconn->get_waypoints;
    if ($opt{file}) {
	$gpsconn->write_waypoints($w, $opt{file});
    } else {
	print $w;
    }
} else {
    warn "Unknown action $action";
    usage();
}

sub usage {
    die <<EOF
usage: $0 [-test] [-file file] [-filefmt fmt] [-dir directory] action

where action is one of:
gettrk getwpt

EOF
}

__END__
