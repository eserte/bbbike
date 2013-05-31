#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012,2013 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use utf8;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../miscsrc", # für ReverseGeocoding.pm
	 $FindBin::RealBin,
	);

use Cwd qw(realpath);
use Getopt::Long;
use POSIX qw(strftime);
use Time::Local qw(timelocal);

use BBBikeUtil qw(int_round);
use Strassen::Util ();
use StrassenNextCheck;

use constant ORG_MODE_HEADLINE_LENGTH => 77; # used for tag alignment

my $with_dist = 1;
my $dist_dbfile;
my $centerc;
my $center2c;
GetOptions(
	   "with-dist!" => \$with_dist,
	   "dist-dbfile=s" => \$dist_dbfile,
	   "centerc=s" => \$centerc,
	   "center2c=s" => \$center2c,
	  )
    or die "usage: $0 [--nowith-dist] [--dist-dbfile dist.db] [--centerc X,Y [--center2c X,Y]] bbdfile ...";

if ($with_dist && !$centerc) {
    my $config_file = "$ENV{HOME}/.bbbike/config";
    if (!-e $config_file) {
	warn "WARNING: disabling --with-dist option, $config_file does not exist.\n";
	$with_dist = 0;
    } else {
	require Safe;
	my $config = Safe->new->rdo($config_file);
	if (!$config) {
	    warn "WARNING: disabling --with-dist option, cannot load $config_file.\n";
	    $with_dist = 0;
	} else {
	    if (!$config->{centerc}) {
		warn "WARNING: disabling --with-dist option, no centerc option in $config_file set.\n";
		$with_dist = 0;
	    } else {
		$centerc = $config->{centerc};
		if ($config->{center2c}) {
		    $center2c = $config->{center2c};
		}
	    }
	}
    }
}

my $dists_are_exact;
if ($with_dist) {
    $dists_are_exact = $dist_dbfile ? 1 : 0;
}

my @files = @ARGV
    or die "Please specify bbd file(s)";

my @records;

for my $file (@files) {
    my $abs_file = realpath $file;
    my $s = StrassenNextCheck->new_stream($file);
    $s->read_stream_nextcheck_records
	(sub {
	     my($r, $dir) = @_;
	     if ($dir->{_nextcheck_date} && $dir->{_nextcheck_date}[0] && (my($y,$m,$d) = $dir->{_nextcheck_date}[0] =~ m{^(\d{4})-(\d{2})-(\d{2})$})) {
		 my $epoch = eval { timelocal 0,0,0,$d,$m-1,$y };
		 if ($@) {
		     warn "ERROR: Invalid day '$dir->{_nextcheck_date}[0]' ($@) in file '$file', line '" . $r->[Strassen::NAME] . "', skipping...\n";
		 } else {
		     my $wd = [qw(Su Mo Tu We Th Fr Sa)]->[(localtime($epoch))[6]];
		     my $date = "$y-$m-$d";
		     my $subject = $r->[Strassen::NAME] || ($dir->{XXX} && join(" ", @{$dir->{XXX}})) || "(" . $file . "::$.)";
		     my $dist_tag = '';
		     my $any_dist; # either one way or two way dist in meters
		     if ($centerc) {
			 my $dist_m = _get_dist($centerc, $r->[Strassen::COORDS]);
			 $dist_tag = ':' . _make_dist_tag($dist_m) . ':';
			 if ($center2c) {
			     my $dist2_m = _get_dist($center2c, $r->[Strassen::COORDS]);
			     $dist2_m += $dist_m;
			     $dist_tag .= _make_dist_tag($dist2_m) . ':';
			     $any_dist = $dist2_m;
			 } else {
			     $any_dist = $dist_m;
			 }
		     }
		     my $prio;
		     if ($prio = $dir->{priority}) {
			 $prio = $prio->[0];
			 if ($prio !~ m{^#[ABC]$}) {
			     warn "WARN: priority should be #A..#C, not '$prio', ignoring...\n";
			     undef $prio;
			 }
		     }
		     my $headline = "** TODO <$date $wd> " . ($prio ? "[$prio] " : "") . $subject;
		     if ($dist_tag) {
			 if (length($headline) + 1 + length($dist_tag) < ORG_MODE_HEADLINE_LENGTH) {
			     $headline .= " " x (ORG_MODE_HEADLINE_LENGTH-length($headline)-length($dist_tag));
			 } else {
			     $headline .= " ";
			 }
			 $headline .= $dist_tag;
		     }
		     my $body = <<EOF;
$headline
   : $r->[Strassen::NAME]\t$r->[Strassen::CAT] @{$r->[Strassen::COORDS]}
   [[${abs_file}::$.]]
EOF
		     push @records, { date => $date, body => $body, dist => $any_dist };
		 }
	     } else {
		 warn "ERROR: Cannot parse date '$dir->{_nextcheck_date}[0]' (file $file), skipping...\n";
	     }
	 });
}

@records = sort {
    my $cmp = $b->{date} cmp $a->{date};
    return $cmp if $cmp != 0;
    if (defined $a->{dist} && defined $b->{dist}) {
	return $b->{dist} <=> $a->{dist};
    } else {
	0;
    }
} @records;

my $today = strftime "%Y-%m-%d", localtime;

my @expired_records;
if ($centerc) {
    @expired_records = sort {
	my $cmp = 0;
	if (defined $a->{dist} && defined $b->{dist}) {
	    $cmp = $a->{dist} <=> $b->{dist};
	}
	return $cmp if $cmp != 0;
	return $b->{date} cmp $a->{date};
    } grep { $_->{date} le $today } @records;
}

binmode STDOUT, ':utf8';
print "fragezeichen/nextcheck\t\t\t-*- mode:org; coding:utf-8 -*-\n\n";

if ($with_dist) {
    require ReverseGeocoding;
    require Karte::Polar;
    require Karte::Standard;
    my $rh = ReverseGeocoding->new;
    if ($centerc) {
	my($px,$py) = $Karte::Polar::obj->standard2map(split /,/, $centerc);
	print "1st reference point for distances: ". $rh->find_closest("$px,$py", "road"), "\n";
	if ($center2c) {
	    my($p2x,$p2y) = $Karte::Polar::obj->standard2map(split /,/, $center2c);
	    print "2nd reference point for distances: ". $rh->find_closest("$p2x,$p2y", "road"), "\n";
	}
	print "\n";
    }
}

my $today_printed = 0;
for my $record (@records) {
    if (!$today_printed && $record->{date} le $today) {
	print "** ---------- TODAY ----------\n";
	$today_printed = 1;
    }
    print $record->{body};
}

if (@expired_records) {
    print "* expired records, alternative sorting\n";
    for my $expired_record (@expired_records) {
	print $expired_record->{body};
    }
}

print <<'EOF';
* settings
# Local variables:
# compile-command: "(cd ../data && make fragezeichen-nextcheck.org-exact-dist)"
# End:
EOF
# Alternative compile command (without using the dist.db):
## compile-command: "(cd ../data && make ../tmp/fragezeichen-nextcheck.org)"

sub _get_dist {
    my($p1, $p2s) = @_;
    my $inacc_hash = $dist_dbfile ? _get_innaccessible_points() : {};
    my($min_dist, $min_p);
    for my $this_p (@$p2s) {
	next if $inacc_hash->{$this_p};
	my $this_dist = Strassen::Util::strecke_s($p1, $this_p);
	if (!$min_dist || $min_dist > $this_dist) {
	    $min_dist = $this_dist;
	    $min_p    = $this_p;
	}
    }
    if (!$dist_dbfile) {
	return $min_dist;
    }

    # $min_p is only an approximation for the nearest point from $p1
    my $dist_db = _get_distdb();
    my $dist = eval { $dist_db->get_dist($p1, $min_p) };
    if ($@) {
	die "Failed to get distance between $p1 and $min_p: $@";
    }
    $dist;
}

sub _get_innaccessible_points {
    our $inacc_hash;
    return $inacc_hash if $inacc_hash;

    require Strassen::Core;
    my $s = Strassen->new("inaccessible_landstrassen");
    $inacc_hash = $s->get_hashref;
}

sub _get_distdb {
    our $dist_db;
    return $dist_db if $dist_db;
    require DistDB;
    $dist_db = DistDB->new($dist_dbfile);
}

sub _make_dist_tag {
    my $dist_m = shift;
    ($dists_are_exact ? '' : '~') . int_round($dist_m/1000) . 'km';
}

__END__

=head1 NAME

fragezeichen2org - create org-mode file from date-based fragezeichen records

=head1 SYNOPSIS

    ./miscsrc/fragezeichen2org.pl data/*-orig tmp/bbbike-temp-blockings-optimized.bbd > tmp/fragezeichen-nextcheck.org

=head1 DESCRIPTION

B<fragezeichen2org.pl> creates an emacs org-mode compatible file from
all "fragezeichen" entries with an last_checked/next_check date found
in the given bbbike data files.

The records are sorted by date. Records from the same date are
additionally sorted by distance (if the C<--centerc> option is given).
A special marker C<<--- TODAY --->> is created between past and future
entries.

Expired entries are additionally listed in a section "expired records,
alternative sorting". This section is sorted by distance only.

=head2 OPTIONS

=over

=item C<--with-dist> (set by default)

Add distance tags to every fragezeichen record. Distance is the
as-the-bird-flies distance from the "centerc" point (see below) to the
fragezeichen record.

=item C<--nowith-dist>

Disable the generation of distance tags.

=item C<--dist-dbfile >I</path/to/dist.db>

Specify a F<dist.db> for use with L<DistDB>. Using this option
automatically enables exact distance calculation.

Note that it's possible that the route search might find no route for
a coordinate pair (e.g. because of inaccessible points not covered by
F<inaccessible_landstrassen>). In this case the script stops. So this
option is not yet suitable for unattended batch jobs.

=item C<--centerc I<x,y>>

The home coordinate (in BBBike coord system, not WGS84) for the
L</--with-dist> calculation. If not given, then the value is taken
from F<~/.bbbike/config> (which is usually written by the Perl/Tk
app). If the value is not defined there, either, then the distance
tags are disabled.

=item C<--center2c I<x,y>>

A 2nd home coordinate for the distance tag generation. This is used
for a 2nd tag, which is the as-the-bird-flies distance from the 1st
coordinate to the fragezeichen record to the 2nd coordinate.

Note that the <center2c> config option needs to be set manually in
F<~/.bbbike/config>; it's not possible to do this with the option
editor of the Perl/Tk app.

=back

=cut
