#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: plzlogfile.t,v 1.1 2003/08/07 22:21:30 eserte Exp eserte $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../data", "$FindBin::RealBin/../lib");
use PLZ;
use PLZ::Multi;
use Getopt::Long;
use CGI;
use Fcntl qw(:seek);

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

BEGIN { plan tests => 1 }

my $doit;
my $hnr;
my $logfile = "$ENV{HOME}/www/log/radzeit.de-access_log";
my $seek = 0;
my $potsdam = 1;
my $extern = 1;

GetOptions("doit!" => \$doit,
	   "hnr!"  => \$hnr,
	   "logfile=s" => \$logfile,
	   "seek=i" => \$seek,
	   "potsdam!" => \$potsdam,
	   "extern!" => \$extern,
	  ) or die "usage?";
if (!$doit) {
    skip(1, "Call this test script with -doit");
    exit 0;
}

my $plz = ($potsdam
	   ? PLZ::Multi->new("Berlin.coords.data", "Potsdam.coords.data",
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

open(LOGFILE, $logfile) or die "Can't open $logfile: $!";
select LOGFILE; $| = 1; select STDOUT;

if ($seek) {
    seek LOGFILE, $seek, SEEK_SET;
}

{
    local $SIG{INT} = sub {
	warn "Seek: " . tell(LOGFILE);
	exit 1;
    };

    while(<LOGFILE>) {
	m{GET\s+\S+bbbike\.cgi\?(.*)\s+} or next;
	chomp;
	my $q = CGI->new($1);
	my $s = $q->param("start");
	if (defined $s && ((!$hnr && $s ne "") ||
			   ( $hnr && $s =~ /\s+\d+\s*$/))) {
	    my @res = lookup($s);
	    printf "# %-35s => %2d %-35s\n",
		$s, scalar @{$res[0]},
		    (!@{$res[0]} ? "-"x30 : $res[0]->[0]->[PLZ::LOOK_NAME]);
	}
    }
    close LOGFILE;
}

ok(1);

sub lookup {
    my $street = shift;
    my @res = $plz->look_loop(PLZ::split_street($street),
			      @standard_look_loop_args);
    @res;
}

__END__
