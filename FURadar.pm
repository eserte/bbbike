# -*- perl -*-

#
# $Id: FURadar.pm,v 1.6 2001/11/26 09:30:34 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999, 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package FURadar;
use strict;
use vars qw($proxy $radarurldir $VERBOSE @tmpfiles $use_map $progress
	    $buggy_ppmchange);

# set this to 1 if ppmchange can really handle only one pair
$buggy_ppmchange = 1;

if (defined $main::proxy) {
    $proxy = $main::proxy;
}
#$radarurldir = "http://www.met.fu-berlin.de/wetter/radar/";
$radarurldir = "\x68\x74\x74\x70\x3a\x2f\x2f\x77\x77\x77\x2e\x6d\x61\x65\x72\x6b\x69\x73\x63\x68\x65\x61\x6c\x6c\x67\x65\x6d\x65\x69\x6e\x65\x2e\x64\x65\x2f\x67\x72\x61\x66\x69\x6b\x2f\x73\x65\x72\x76\x69\x63\x65\x2f\x77\x65\x74\x74\x65\x72\x2f\x72\x61\x64\x61\x72\x2f"; # alternative...
if (!defined $use_map) {
    #$use_map = 'FURadar';
    $use_map = 'FURadar2';
    #$use_map = 'FURadar3';
}

sub fetch {
    my $ua = main::get_user_agent();
    my $tmp = make_temp("fetch");
    #    my $url = $radarurldir . "R" . latest() . ".gif";
    my $url = $radarurldir . "radar.gif";
    print STDERR "Getting $url => $tmp...\n" if $VERBOSE;
    my $r;
    if ($ua) {
	my $res = $ua->mirror($url, $tmp);
	if ($res->is_success) {
	    $r = 1;
	} else {
	    print STDERR $res->as_string, "\n";
	}
    } else {
	require Http; # XXX evtl. zuerst LWP
	open(WWW, ">$tmp") or die "Cannot write to $tmp: $!";
	my(%res) = Http::get("url" => $url,
			     (defined $proxy ? ("proxy" => $proxy) : ()),
			    );
	if ($res{"error"} == 200) {
	    $r = 1;
	    print WWW $res{"content"};
	} else {
	    print STDERR "Error detecting while fetching $url. Error code: $res{error}\n";
	}
	close WWW;
    }
    if (!$r) {
	undef;
    } else {
	$tmp;
    }
}

# XXX nicht mehr relevant, da Änderung des Bildnamens
# Return the hour string for the latest radar image
#  sub latest {
#      require POSIX;
#      my $last_gmtime = int(POSIX::strftime("%H", gmtime) / 3) * 3;
#      sprintf("%02d00", $last_gmtime);
#  }

#  sub latest_in_dir {
#      my $dir = shift;
#      my $maxtime = 0;
#      my $maxfile;
#      my $prefix = ($use_map eq 'FURadar2' ? 'r' : 'R');
#      foreach my $f (glob("$dir/$prefix????.gif")) {
#  	my(@s) = stat($f);
#  	if ($s[9] > $maxtime) {
#  	    $maxfile = $f;
#  	    $maxtime = $s[9];
#  	}
#      }
#      # XXX maxtime genauer ausrechnen
#      ($maxfile, $maxtime);
#  }

sub interesting_parts {
    my $infile = shift;
    my(%args) = @_;

    my $ratio = 1;
    if (exists $args{-km100pixel} and $args{-km100pixel}) {
	my $obj;
	if ($use_map eq 'FURadar') {
	    require Karte::FURadar;
	    $obj = $Karte::FURadar::obj;
	} elsif ($use_map eq 'FURadar2') {
	    require Karte::FURadar2;
	    $obj = $Karte::FURadar2::obj;
	} else {
	    require Karte::FURadar3;
	    $obj = $Karte::FURadar3::obj;
	}
	my $this_pixel =
	  ($obj->standard2map(100000,0))[0] -
	    ($obj->standard2map(0,0))[0];
	$ratio = ($args{-km100pixel} / $this_pixel);
	warn "ratio = $ratio";
    }

    my $tmp = make_temp("processed");
    my(@cropdim) = (13, 13, 512, 512);
    $cropdim[2]-=$cropdim[0]*2;
    $cropdim[3]-=$cropdim[1]*2;

    eval {
	require Image::Magick;
    };
    if (!$@) {
	my(@coltable) =  # Farben, die übrig bleiben sollen
	  ([qw/  0 170   0/],
	   [qw/100 220   0/],
	   [qw/200 255   0/],
	   [qw/255 220   0/],
	   [qw/255 120   0/],
	   [qw/240   0   0/],
	  );
	print STDERR "Transforming $infile with Image::Magick... "
	  if $VERBOSE;
	my $image = new Image::Magick;
	$image->Read($infile);
	$progress->Update(0.1) if $progress;

	print STDERR "chop... ";
	$image->Crop(geometry => "$cropdim[2]x$cropdim[3]+$cropdim[0]+$cropdim[1]");
	$progress->Update(0.2) if $progress;

	# Sample sollte vor Farbtransformationen durchgeführt werden
	if ($ratio != 1 && $ratio != 0) {
	    print STDERR "scale... ";
	    $image->Sample(height => $image->Get('height')*$ratio,
			   width  => $image->Get('width')*$ratio,
			  );
	    $progress->Update(0.3) if $progress;
	}

	print STDERR "colormap transform... ";
	my(%colhash) = map { (join(",", @$_) => 1) } @coltable;
	foreach my $coli (0 .. $image->Get('colors')-1) {
	    if (!exists $colhash{$image->QueryColor($image->Get("colormap[$coli]"))}) {
		$image->Set("colormap[$coli]" => '#ffffff');
	    }
	}
	$progress->Update(0.4) if $progress;

	# Übler Trick: Colormap-Transformationen gehen ansonsten beim
	# Setzen der transparenten Farbe verloren...
	print STDERR "normalize... ";
	$image->Normalize;
	$progress->Update(0.5) if $progress;

	# Hier hatte ich einen Quantize-Aufruf gehabt.
	# Das war aus zwei Gründen schlecht:
	# 1) Quantize hat eine weitere halbe Sekunde Rechenzeit verbraucht
	# 2) Die Colormap-Transformation wurde ignoriert.
	# XXX ImageMagick 4.2.8 scheint trotzdem noch Probleme bei der
	# Erzeugung der richtigen COlormap zu haben :-(
	$image->Transparent(color => '#ffffff');
	print STDERR "write... ";
	$image->Write($tmp);
	$progress->Update(0.8) if $progress;

	print STDERR "done\n"
	  if $VERBOSE;
    } else {
	my(@anti_coltable) = # Farben, die transparent gemacht werden sollen
	  ([qw/  0   0   0/],
	   [qw/ 80 210 210/],
	   [qw/ 81 210 210/],
	   [qw/165 165 165/],
	   [qw/ 85  85  85/],
	   [qw/ 25  25  25/],
	   [qw/180 180 180/],
	   [qw/185 185 185/],
	   [qw/170 170 170/],
	   [qw/170 100 170/],
	   [qw/175 175 175/],
	   [qw/192 199 178/],
	   [qw/  0   2   0/],
	   [qw/176 184 176/], # diese Farbe bleibt nach ppmquant übrig...
	  );
	my $cmd = "giftopnm $infile | ";
	my $map_color = sub {
	    "rgb:" . join("/", map { sprintf "%02x", $_ } @{$_[0]}) . " rgb:ff/ff/ff"
	};
	if ($buggy_ppmchange) {
	    $cmd .= join(" | ", map { "ppmchange " . $map_color->($_) } @anti_coltable);
	} else {
	    $cmd .= "ppmchange " . join(" ", map { $map_color->($_) } @anti_coltable);
	}
#	  "/usr/ports/graphics/netpbm/work/netpbm/ppm/ppmchange " .
#	    "ppmchange " .
#	    join(" ", map { "rgb:" . join("/", map { sprintf "%02x", $_ } @$_) . " rgb:ff/ff/ff"} @anti_coltable) . " | " .
	$cmd .= " | " .
	    "pnmcut " . join(" ", @cropdim) . " | ";
	if ($ratio != 1 && $ratio != 0) {
	    $cmd .= "pnmscale $ratio | ppmquant 8 | ";
	}
#	$cmd .= "ppmtogif | giftrans -b \\#ffffff -T > $tmp";
	$cmd .= "ppmtogif -transparent \\#ffffff > $tmp";
	print STDERR "Executing $cmd\n" if $VERBOSE;
	system($cmd);
    }
    $tmp;
}

# XXX scaling auf berlinmap fehlt

sub make_temp {
    my $name = shift;
    my $tmp;
    eval 'use POSIX;
          $tmp = POSIX::tmpnam();
         ';
    if (!defined $tmp and -w $main::tmpdir) {
	$tmp = "$main::tmpdir/furadar-$name-$$.tmp";
    }
    if (defined $tmp) {
	push @tmpfiles, $tmp;
    }
    $tmp;
}

sub cleanup {
    if (@tmpfiles) {
	unlink @tmpfiles;
    }
    undef @tmpfiles;
}

return 1 if caller;

package main;

require Getopt::Long;

$FURadar::VERBOSE = 1;

my $from_www = 1;
my $file = "$ENV{HOME}/src/bbbike/misc/radarsample.gif";
my $ua;

Getopt::Long::GetOptions("www!" => \$from_www,
			 "f|file=s" => \$file,
			);

if ($from_www) {
    $file = FURadar::fetch();
}

system("xv " . FURadar::interesting_parts($file));

sub get_user_agent {
    return $ua if defined $ua;
    eval { require LWP::UserAgent };
    return undef if $@;
    $ua = LWP::UserAgent->new;
    $ua->timeout(30);
    $ua;
}

__END__
