#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: sparkassen.pl,v 1.7 2003/01/17 00:57:12 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001-2003 Slaven Rezic. All rights reserved.
#

use FindBin;
use lib ("$FindBin::RealBin",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
use TelbuchDBApprox;
use LWP::UserAgent;
use HTML::LinkExtor;
use strict;
use Strassen;
use Getopt::Long;
use File::Basename;
use File::Path;

#$TelbuchApprox::VERBOSE = 1;

my $galeon_cache = "/home/e/eserte/.galeon/mozilla/galeon/Cache";
my $sparkasse_base1 = "https://www.berliner-sparkasse.de/bsk/design.nsf/HTMLTemplates";
my $sparkassen_tmp = "/tmp/sparkasse";

my $net_optimize; # sucht den nächsten Knotenpunkt --- gut für StrassenNetz::search!
my $sparkasse;
my $citibank;
my $local;
my $cache = 1;
my $getcoords = 1;
my $v;
if (!GetOptions("netoptimize!" => \$net_optimize,
		"sparkasse!" => \$sparkasse,
		"citibank!" => \$citibank,
		"local!" => \$local,
		"cache|usecache!" => \$cache,
		"getcoords!" => \$getcoords,
		"v" => \$v,
	       )) {
    die "usage";
}

$| = 1;

my $tb = TelbuchDBApprox->new(-multimatchprefer => 'streets',
			      -approxhnr => 1,
			     );

my $ua = LWP::UserAgent->new;
$ua->env_proxy;

my @url;

my $cat;

my $s;
if ($net_optimize) {
    $s = new Strassen "strassen";
}

if ($sparkasse) {
    $cat = "IMG:/home/e/eserte/images/icons/sparkasse.gif";
    get_sparkasse();
}
if ($citibank) {
    # XXX mit anchor?
    #$cat = "IMG:/home/e/eserte/images/icons/citibank.gif|ANCHOR:e";
    $cat = "IMG:/home/e/eserte/images/icons/citibank.gif";
    get_citibank();
}

sub get_sparkasse {
    mkpath([$sparkassen_tmp], 1, 0755);

    my @cityparts = sparkasse_get_city_overview();

    my @filiale_url;
    if ($local) {
	push @filiale_url, sparkasse_get_citypart_overview("file://$galeon_cache/245C965Ed01");
    } else {
	foreach my $citypart (@cityparts) {
	    my $url = "$sparkasse_base1/$citypart";
	    push @filiale_url, sparkasse_get_citypart_overview($url);
	}
    }

    if ($local) {
	for my $res (sparkasse_get_filiale("file://$galeon_cache/A4499DB2d01")) {
	    find_coords_and_print($res);
	}
    } else {
	foreach my $filiale_url (@filiale_url) {
	    for my $res (sparkasse_get_filiale($filiale_url)) {
		find_coords_and_print($res);
	    }
	}
    }
}

sub get_citibank {
    open(C, "/home/e/eserte/src/bbbike/misc/citibank.txt") or die $!;
    while(<C>) {
	chomp;
	if (/^D\s+(\d+)\s+(?:Berlin)\s+([^,]+),\s*(.*)/) {
	    my($zip,$citypart,$str) = ($1,$2,$3);
	    push @url, {StreetNr => $str,
			Zip => $zip,
			Category => $cat,
		       };
	} else {
	    warn "Can't parse $_";
	}
    }
    close C;

    foreach my $url (@url) {
	find_coords_and_print($url);
    }
}

######################################################################

sub _get_from_cache_or_real {
    my $url = shift;
    my $real_url = $url;
    warn "$url...\n" if $v;

    if ($cache) {
	$url = "file://$sparkassen_tmp/" . basename($url);
	my $resp = $ua->get($url);
	if ($resp->is_success) {
	    return $resp;
	}
    }

    my $resp = $ua->get($real_url);
    if (!$resp->is_success) {
	die $resp->message;
    }

    if ($cache) {
	if (open(OUT, ">$sparkassen_tmp/" . basename($url))) {
	    print OUT $resp->content;
	    close OUT;
	}
    }
    $resp;
}

sub sparkasse_get_city_overview {
    my $url;
    if ($local) {
	$url = "file://$galeon_cache/71214450d01";
    } else {
	$url = "$sparkasse_base1/filialen?OpenDocument";
    }

    my $resp = _get_from_cache_or_real($url);

    my $follow_hash = {};
    my $p = HTML::LinkExtor->new( sub { sparkasse_parse_city_overview($follow_hash, @_) });
    $p->parse($resp->content);
    keys %$follow_hash;
}

sub sparkasse_parse_city_overview {
    my($follow_hash, $tag, %links) = @_;
    if (defined $links{'href'} &&
	$links{'href'} =~ /^pkc_/ &&
	!$follow_hash->{$links{'href'}}) {
	$follow_hash->{$links{'href'}}++;
    }
}

sub sparkasse_get_citypart_overview {
    my $url = shift;

    my $resp = _get_from_cache_or_real($url);

    my $follow_hash = {};
    my $p = HTML::LinkExtor->new( sub { sparkasse_parse_citypart_overview($follow_hash, @_) }, $url);
    $p->parse($resp->content);
    keys %$follow_hash;
}

sub sparkasse_parse_citypart_overview {
    my($follow_hash, $tag, %links) = @_;
    if (defined $links{'href'} &&
	$links{'href'} =~ /Viewfilialen\/filiale_/ &&
	!$follow_hash->{$links{'href'}}) {
	$follow_hash->{$links{'href'}}++;
    }
}

sub sparkasse_get_filiale {
    my $url = shift;

    my $resp = _get_from_cache_or_real($url);

    my $ret;
    my $p = HTML::LinkExtor->new( sub { stadtplandienst_cb(\$ret, @_) });
    $p->parse($resp->content);
    $ret;
}

sub stadtplandienst_cb {
    my($ret, $tag, %links) = @_;
    if (defined $links{'href'} &&
	$links{'href'} =~ m|http://www.stadtplandienst.de/query|) {
	my($ort) = $links{'href'} =~ /ORT=([^&]+)/;
	my($plz) = $links{'href'} =~ /PLZ=([^&]+)/;
	my($str) = $links{'href'} =~ /STR=([^&]+)/;
	$str =~ s/\+/ /g;
	$str =~ s/%20/ /g;
	my($hnr) = $links{'href'} =~ /HNR=([^&]+)/;
	my($txt) = $links{'href'} =~ /TXT=([^&]+)/;
	$txt =~ s/\+/ /g;
	$txt =~ s/%20/ /g;
	$$ret = {Street => $str,
		 Nr => $hnr,
		 StreetNr => defined $hnr ? "$str $hnr" : $str,
		 Zip => $plz,
		 Comment => $txt,
		 Category => $cat,
		};
    }
}

######################################################################

sub find_coords_and_print {
    my $url = shift;
    return if !$getcoords;
    my($res) = $tb->search($url->{StreetNr}, $url->{Zip});
    if (!$res->{Coord}) {
	print "# $url->{StreetNr}, $url->{Zip}\n";
	next;
    }
    my $coord;
    if ($net_optimize) {
	$coord = $s->nearest_point($res->{Coord});
    } else {
	$coord = $res->{Coord};
    }
    if (!$coord) {
	warn "-netoptimize failed for $res->{Street}";
	next;
    }
    print "$res->{Street} $res->{Nr}" . ($url->{Comment} ? " ($url->{Comment})" : "") . "\t$url->{Category} $coord\n";
}


__END__
