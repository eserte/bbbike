#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: plzlogfile.t,v 1.13 2006/05/23 21:33:37 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../data", "$FindBin::RealBin/../lib", $FindBin::RealBin);
use PLZ;
use PLZ::Multi;
use Getopt::Long;
use CGI;
use BBBikeTest;
use Strassen::Strasse;

BEGIN {
    if (!eval q{
	use Test::More;
	use Fcntl qw(:seek);
	use File::ReadBackwards 1.00; # tell method
	1;
    }) {
	print "1..0 # skip no Test::More, recent Fcntl and/or File::ReadBackwards modules\n";
	exit;
    }
}

BEGIN { plan tests => 1 }

my $doit;
my $hnr;
my $seek = 0;
my $potsdam = 1;
my $extern = 1;
my $forward = 0;
my $v;

GetOptions("doit!" => \$doit,
	   "hnr!"  => \$hnr,
	   "logfile=s" => \$logfile,
	   "seek=i" => \$seek,
	   "forward" => \$forward,
	   "potsdam!" => \$potsdam,
	   "extern!" => \$extern,
	   "v" => \$v,
	  ) or die <<EOF;
usage: $0 -doit [-hnr] [-logfile file] [-seek pos]
          [-nopotsdam] [-noextern] [-forward] [-v]
EOF
SKIP: {
skip("Call this test script with -doit", 1) unless $doit;

my $plz = ($potsdam
	   ? # as used in bbbike.cgi:
	   PLZ::Multi->new("Berlin.coords.data",
			   "Potsdam.coords.data",
			   Strassen->new("plaetze"), # because there are also some "sehenswuerdigkeiten" in
			   -cache => 1,
			  )
	   : PLZ->new
	  );

my @standard_look_loop_args =
    (
     Max => 1,
     MultiZIP => 1, # introduced because of Hauptstr./Friedenau vs. Hauptstr./Schöneberg problem
     MultiCitypart => 1, # works good with the new combine method
     Agrep => 'default',
     Noextern => !$extern,
    );

my $LOGFILE;
#open(LOGFILE, $logfile)
if ($forward) {
    require IO::File;
    $LOGFILE = IO::File->new($logfile, "r")
	or die "Can't open $logfile in forward mode: $!";
    $LOGFILE->seek($seek, SEEK_SET);
} else {
    $LOGFILE = File::ReadBackwards->new($logfile)
	or die "Can't open $logfile: $!";
    if ($seek) {
	$LOGFILE->{seek_pos} = $seek; # XXX Hack! not needed with newer versions of File::ReadBackward?
	#$LOGFILE->seek($seek, SEEK_SET);
    }
}

my %seen;

my $lastdate;
{
    local $SIG{INT} = sub {
	warn "Seek: " . $LOGFILE->tell;
	exit 1;
    };

    my $nextline = $LOGFILE->can("getline")
	           ? sub { $LOGFILE->getline }
	           : do {
		       warn "Fallback to old readline method";
		       sub { $LOGFILE->readline };
		   };

    while(defined($_ = $nextline->())) {
	m{GET\s+\S+bbbike\.cgi\?(.*)\s+} or next;
	next if m{"BBBike-Test/\d};
	chomp;
	my $q = CGI->new($1);
	my($thisdate, $thistime) = $_ =~ m{\[(\d{2}/.{3}/\d{4}):([0-9:]+)};
	if (!defined $lastdate || $lastdate ne $thisdate) {
	    print "# $thisdate " . ("#"x60) . "\n";
	    $lastdate = $thisdate;
	}
	for my $param (qw(start via ziel)) {
	    my $s = $q->param($param);
	    if (defined $s) {
		next if $seen{$s};
		$seen{$s}++;
	    }
	    ($s) = Strasse::split_crossing($s);
	    if (defined $s && ((!$hnr && $s ne "") ||
			       ( $hnr && $s =~ /\s+\d+\s*$/))) {
		my @res = lookup($s);
		printf "# %-35s => %2d %-35s",
		    $s, scalar @{$res[0]},
			(!@{$res[0]} ? "-"x30 : $res[0]->[0]->[PLZ::LOOK_NAME]);
		if ($v) {
		    print " ($thistime)";
		}
		print "\n";
	    }
	}
    }
    $LOGFILE->close;
}

ok(1);

sub lookup {
    my $street = shift;
    my @res = $plz->look_loop(PLZ::split_street($street),
			      @standard_look_loop_args);
    @res;
}

}

__END__
