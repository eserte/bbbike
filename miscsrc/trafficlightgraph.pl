#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: trafficlightgraph.pl,v 1.10 2007/12/14 23:01:46 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2007,2010 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Getopt::Long;
use List::Util qw(min);
use Tk;

use BBBikeUtil qw(kmh2ms ms2kmh s2ms);
use Route;
use Strassen::Core;
use Strassen::Strasse;
use Strassen::Util;

my $v_kmh = 50;
my $default_test_kmh = 30;
my @v_test_kmh;
my $green_s = 20;
my $cycle_s = 70;
my($canvas_w,$canvas_h)=(800,500);
my $reversed = 0;
my $ignorelsa = "";
my($scale_x,$scale_y);

sub usage (;$) {
    my $msg = shift;
    print STDERR $msg, "\n" if $msg;
    die <<EOF;
usage: $0 [-velocity kph] [-testvelocity|tv kph,kph,...]
\t[-green secs] [-cycle secs]
\t[-canvasw|-cw pixels] [-canvash|-ch pixels]
\t[-reversed] [-ignorelsa "x,y x,y ..."]
\t[-scalex float] [-scaley float] bbrfile
EOF
}

GetOptions("velocity=s"         => \$v_kmh,
	   'testvelocity|tv=s@' => \@v_test_kmh,
	   "green=i"            => \$green_s,
	   "cycle=i"            => \$cycle_s,
	   "canvasw|cw=i"       => \$canvas_w,
	   "canvash|ch=i"       => \$canvas_h,
	   "reversed!"          => \$reversed,
	   "ignorelsa=s"        => \$ignorelsa,
	   "scalex=f"           => \$scale_x,
	   "scaley=f"           => \$scale_y,
	  ) or usage;
my $v_ms = kmh2ms($v_kmh);
if (!@v_test_kmh) {
    @v_test_kmh = ($default_test_kmh);
} else {
    # expand
    @v_test_kmh = map { split /,/ } @v_test_kmh;
}
my @v_test_ms;
for (@v_test_kmh) {
    push @v_test_ms, kmh2ms($_);
}

my $route_file = shift or usage ".bbr file is missing";
my $route = Route::load($route_file);

my $ampeln_s = Strassen->new("$FindBin::RealBin/../data/ampeln");
my %ampeln = %{ $ampeln_s->get_hashref_by_cat };
{
    my @ignorelsa = split /[; |]/, $ignorelsa;
    for (@ignorelsa) {
	if (exists $ampeln{$_}) {
	    delete $ampeln{$_};
	} else {
	    warn "LSA $_ not found\n";
	}
    }
}

my $s = Strassen->new("$FindBin::RealBin/../data/strassen");
my $crossings = $s->all_crossings(RetType => "hash",
				  UseCache => 1,
				 );

my $top = tkinit;
my $c = $top->Scrolled("Canvas", -scrollbars => "osoe", -width => $canvas_w, -height => $canvas_h)->pack(qw(-fill both -expand 1));

my $p = eval { $c->Photo(-file => "$FindBin::RealBin/../images/ampel.gif") };

my @labels;
my $length = 0;
{
    my($lastxy);
    my %laststreets;
    for my $coord (@{ $route->{RealCoords} }) {
	my $xy = join(",",@$coord);
	if (defined $lastxy) {
	    $length += Strassen::Util::strecke_s($lastxy, $xy);
	}
	$lastxy = $xy;
	my $def;
	if (exists $crossings->{$xy}) {
	    my @crossing_streets = map { Strasse::strip_bezirk($_) } @{$crossings->{$xy}};
	    $def->{label} = join("/", grep { !$laststreets{$_} } @crossing_streets);
	    %laststreets = map {($_,1)} @crossing_streets;
	}
	if (exists $ampeln{$xy}) {
	    if ($p) {
		$def->{image} = $p;
	    }
	    $def->{trafficlight} = $ampeln{$xy};
	}
	if ($def) {
	    $def->{length} = $length;
	    push @labels, $def;
	}
	
    }
}

my($origin_x, $origin_y) = (70,20);
my $min_v_test_ms = min @v_test_ms;
if (!$scale_x) {
    $scale_x = $canvas_w/(1.7*$length/$min_v_test_ms);
}
if (!$scale_y) {
    $scale_y = $canvas_h/$length;
}

$c->createLine(w2c(0,0), w2c(0,$length), -arrow => 'last');
$c->createLine(w2c(0,0), w2c($canvas_w/$scale_x*2,0), -arrow => 'last');

for my $def (@labels) {
    my($label,$length,$image,$trafficlight) = @{$def}{qw(label length image trafficlight)};
    my($cx,$cy) = w2c(0,$length);
    if ($image) {
	$c->createImage($cx,$cy,-image => $p, -anchor => 'e');
    }
    $c->createText($cx-7,$cy, -text => $label, -anchor => 'e');
    if (defined $trafficlight) {
	$c->createLine($cx,$cy,$canvas_w*2,$cy, -dash => "..");
    }
}

{
    my $x = 0;
    my $last_cx;
    while() {
	my($cx,$cy)=w2c($x,-3);
	$last_cx = $cx if !defined $last_cx;
	last if $cx > $c->cget(-width)*2; # XXX can vary if resizing...
	my($cx2,$cy2)=w2c($x,3);
	$c->createLine($cx,$cy,$cx2,$cy2);
	if ($x%60==0 || $scale_x >= 2) {
	    if ($cx-$last_cx > 30) {
		my $label = s2ms($x);
		$c->createText($cx,$cy,-text => $label, -anchor => "n");
		$last_cx = $cx;
	    }
	}
	if ($x%60==0) {
	    $c->createLine($cx,$cy,$cx,0,-dash => "..");
	}
	$x+=10;
    }
}

{
    my $x = 0;
    my $state = "green";
    while() {
	my($cx,$cy) = w2c($x,0);
	last if $cx > $c->cget(-width)*2; # XXX can vary if resizing...
	my($phase, $fill);
	if ($state eq 'green') {
	    ($phase, $fill) = ($green_s, "green");
	} else {
	    ($phase, $fill) = ($cycle_s-$green_s, "red");
	}
	my($cx2,$cy2) = w2c($x+$length/$v_ms,$length);
	my($cx3,$cy3) = w2c($x+$length/$v_ms+$phase,$length);
	my($cx4,$cy4) = w2c($x+$phase,0);
	$c->createPolygon($cx,$cy,$cx2,$cy2,$cx3,$cy3,$cx4,$cy4,$cx,$cy,
			  #-outline => 'black',
			  -fill => $fill,
			  -tags => ["lsabg"],
			 );
	$state = $state eq 'green' ? 'red' : 'green';
	$x+=$phase;
    }
}

my @print_status;

draw_voyage();
if ($reversed) {
    draw_voyage(reversed => 1);
}

# legend:
{
    my($cx,$cy) = w2c(0, $length);
    $cx+=2;
    $cy-=5;
    my $status_text = 
	"Grüne Welle: " . ms2kmh($v_ms) . "km/h\n" .
	    "grün: " . $green_s . "s/Zyklus: " . $cycle_s . "s";
    $c->createText($cx,$cy,-anchor => "sw",
		   -justify => "left",
		   -text => $status_text);
    unshift @print_status, $status_text;
    unshift @print_status, "Länge: " . int($length) . "m";
}

$c->configure(-scrollregion => [$c->bbox("all")]);
$c->Subwidget("scrolled")->lower("lsabg");

print join("\n", @print_status), "\n";
MainLoop;

sub draw_voyage {
    my(%args) = @_;
    my $reversed = delete $args{reversed};
    die "Extra arguments" if %args;

    my @labels_i = (0 .. $#labels);
    if ($reversed) {
	@labels_i = reverse @labels_i;
	shift @labels_i;
    }
    for my $v_test_ms (@v_test_ms) {
	my $last_time = 0;
	if ($reversed) {
	    $last_time = $length/$v_test_ms;
	}
	my $last_length = 0;
	$last_length = $length if $reversed;
	for my $def_i (@labels_i) {
	    my $def = $labels[$def_i];
	    my($cx,$cy) = w2c($last_time, $last_length);
	    my($this_length, $trafficlight) = @{$def}{qw(length trafficlight)};
	    my $hop_length = abs($this_length-$last_length);
	    my $hop_time = $hop_length/$v_test_ms;
	    my($cx2,$cy2) = w2c($last_time+$hop_time, $this_length);
	    ($last_time, $last_length) = ($last_time+$hop_time, $this_length);
	    $c->createLine($cx,$cy,$cx2,$cy2);
	    if ($def_i < $#labels) {
		if ($trafficlight) {
		    my $tl_state = trafficlight_state($last_time, $this_length);
		    if ($tl_state->{state} eq 'red') {
			my($cx3,$cy3) = w2c($tl_state->{to}, $this_length);
			$c->createLine($cx2,$cy2,$cx2,$cy3);
			$last_time = $tl_state->{to};
		    }
		}
	    }
	}
	my $status_text = ms2kmh($v_test_ms)."km/h: " . s2ms($last_time);
	if ($reversed) {
	    $status_text .= " (reversed)";
	}
	$c->createText(w2c($last_time,$last_length),-anchor => "s",
		       -text => $status_text);
	push @print_status, $status_text;
    }
}

sub w2c {
    my($x,$y) = @_;
    ($x*$scale_x+$origin_x, $canvas_h-$y*$scale_y+$origin_y);
}

sub trafficlight_state {
    my($time_s, $this_length) = @_;

    my $x = 0;
    my $state = 'green';
    while() {
	my $from = $x+$this_length/$v_ms;
	my $to   = $from + ($state eq 'green' ? $green_s : $cycle_s-$green_s);
	if ($time_s >= $from && $time_s <= $to) {
	    return { state => $state,
		     from  => $from,
		     to    => $to,
		   };
	} elsif ($time_s < $from) {
	    return { state => $state eq 'green' ? 'red' : 'green',
		     to    => $from,
		   }
	}
	if ($state eq 'green') {
	    $x += $green_s;
	    $state = "red";
	} else {
	    $x += ($cycle_s-$green_s);
	    $state = "green";
	}
    }
}

__END__

=head1 EXAMPLES

 Leipziger: Spittelmarkt -> Potsdamer Platz (Länge: 1695m)
     grün: 20s/Zyklus: 60s
     Grüne Welle:	30km/h	50km/h
     15km/h:		 9:25	 9:29
     20km/h:		 6:07	 6:58
     25km/h:		 4:40	 4:54
     30km/h:		 3:23	 4:37
     
     grün: 20s/Zyklus: 70s
     Grüne Welle:	30km/h	50km/h
     15km/h:		10:15	10:29
     20km/h:		 6:27	 7:38 
     25km/h:		 4:50	 5:14 
     30km/h:		 3:23	 4:57 
     
 Leipziger: Potsdamer Platz -> Spittelmarkt
     grün: 20s/Zyklus: 70s
     Grüne Welle:	30km/h	50km/h
     15km/h:		 9:42	 9:43
     20km/h:		 7:08	 7:08
     25km/h:		 4:52	 5:49
     30km/h:		 3:23	 4:53
     
     grün: 20s/Zyklus: 60s
     Grüne Welle:	30km/h	50km/h
     15km/h:		 8:52	 9:43
     20km/h:		 6:38	 6:28
     25km/h:		 4:42	 5:19
     30km/h:		 3:23	 4:33
     
 Stralauer: Markgrafendamm -> Warschauer Str. (Länge: 1358m)
     grün: 25s/Zyklus: 60s
     Grüne Welle:	30km/h	50km/h
     15km/h		 5:38	 5:27
     20km/h		 4:04	 4:21
     25km/h		 3:50	 3:59
     30km/h		 2:42	 2:51

     grün: 30s/Zyklus: 90s
     Grüne Welle: 	30km/h	50km/h
     15km/h: 		 6:18	 5:49
     20km/h: 		 4:30	 5:09
     25km/h: 		 3:15	 3:29
     30km/h: 		 2:42	 3:21

     grün: 20s/Zyklus: 60s
     Grüne Welle: 	30km/h	50km/h
     15km/h:		 6:18	 5:27
     20km/h:		 5:00	 4:21
     25km/h:		 3:50	 3:59
     30km/h:		 2:42	 2:51

=head1 TODO

 * Alternative display: only draw green/red lines along the horizontal
   trafficlight lines. The red ones thicker, they should be seen as
   "barriers".

 * Use real-world traffic light cycle times, from ampelschaltung.txt
   and elsewhere. Should probably use only data for one day first, and
   fill up missing data with good guesses and statistics (i.e.:
   - green is only 20% or so from cycle time (maybe depends on primary vs.
     residential street)
   - a street keeps its cycle time until it crosses a higher order street
   - default cycle time in West Berlin is 60s (with some known exceptions
     like the Kanalstraßen) and 70s - 90s in East Berlin (the higher value
     being at crossings with tramways)
   - default cycle time may be higher in Berufsverkehr (70s in West Berlin)
   )

 * Draw also a line with an optimal speed: define a maximum speed
   which must not be exceeded, and fallback to slower pace if red
   light threatens.

=cut
