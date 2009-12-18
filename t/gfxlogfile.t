#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: gfxlogfile.t,v 1.2 2004/12/29 23:35:07 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../data", "$FindBin::RealBin/../lib", $FindBin::RealBin);
use Getopt::Long;
use CGI;
use LWP::UserAgent;
use BBBikeTest;

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
my $seek = 0;
my $seek_i = undef;
my $forward = 0;
my $only_type;

GetOptions("doit!" => \$doit,
	   "logfile=s" => \$logfile,
	   "seek=i" => \$seek,
	   "seeki=i" => \$seek_i,
	   "forward" => \$forward,
	   "only|onlytype=s" => \$only_type,
	  ) or die "usage?";
SKIP: {
skip("Call this test script with -doit", 1) unless $doit;

my $ua = LWP::UserAgent->new;
$ua->agent("BBBike-Test/1.0 (gfxlogfile.t)");

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

my $outdir = "/tmp/gfxlogfile";
mkdir $outdir, 0755;
die "Can't create $outdir" if (!-d $outdir);

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

    my $counter = 0;
    while(defined($_ = $nextline->())) {
	m{GET\s+\S+bbbike\.cgi\?(.*?)\s+} or next;
	next if m{"BBBike-Test/\d};
	chomp;
	my $q = CGI->new($1);
	my($thisdate) = $_ =~ m{\[(\d{2}/.{3}/\d{4}):};
	if (defined $q->param("imagetype") &&
	    defined $q->param("coords") &&
	    $q->param("imagetype") =~ /^(gif|png|jpe?g|pdf)/
	   ) {
	    my $suffix = $1;
	    next if (defined $only_type && $suffix ne $only_type);
	    if (!defined $seek_i || $counter >= $seek_i) {
		my $qs = $q->query_string;
		my $url = "http://localhost/bbbike/cgi/bbbike.cgi?" . $qs;
		#warn $url;
		my $resp = $ua->get($url);
		if (!$resp->is_success) {
		    warn "Error with $url: " . $resp->content;
		}
		if ($resp->content_type !~ /^image/ &&
		    $resp->content_type !~ m{application/pdf}) {
		    warn "Wrong content type for $url: " . $resp->content_type;
		}
		my $file = sprintf "$outdir/%05d.$suffix", $counter;
		print STDERR "$file...         \r";
		open(GFX, "> $file") or die "Can't write to $file: $!";
		binmode GFX;
		print GFX $resp->content;
		close GFX;

		open(INFO, "> $file.info") or die $!;
		print INFO "querystring: $qs\n";
		print INFO "seek pos:    " . $LOGFILE->tell . "\n";
		close INFO;
	    }
	    $counter++;
	}
    }
    $LOGFILE->close;
}

ok(1);

}

__END__
