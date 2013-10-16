#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use File::Temp qw(tempfile);
use Getopt::Long;
use Strassen::Core;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

my $have_nowarnings;
BEGIN {
    $have_nowarnings = 1;
    eval 'use Test::NoWarnings';
    if ($@) {
	$have_nowarnings = 0;
	#warn $@;
    }
}

sub load_from_string_and_check ($$);

my $tests_with_data = 7; # in my private directory
my $test_do_all = 1;
my $tests = $tests_with_data + $test_do_all + 39;
plan tests => $tests + $have_nowarnings;

my $gpsman_dir = "$FindBin::RealBin/../misc/gps_data";
my $do_all;
if (!GetOptions("gpsmandir=s" => \$gpsman_dir,
		"all" => \$do_all,
	       )) {
    die <<EOF;
usage: $0 [-gpsmandir directory]
EOF
}

SKIP: {
    skip("No gpsman data directory found", $tests_with_data) if !-d $gpsman_dir;

    my @trk = glob("$gpsman_dir/*.trk");
    skip("No tracks in $gpsman_dir found", $tests_with_data) if !@trk;
    my @wpt = glob("$gpsman_dir/*.wpt");
    skip("No waypoint files in $gpsman_dir found", $tests_with_data) if !@wpt;
    
    my $trk = $trk[rand @trk];
    my $wpt = $wpt[rand @wpt];

 SKIP: {
	skip("Permission denied for $trk", 3)
	    if !open my($fh), $trk;
	my $s1 = Strassen->new($trk);
	isa_ok($s1, "Strassen");
	isa_ok($s1, "Strassen::Gpsman");
	is "@{[ $s1->dependent_files ]}", $trk;
    }

 SKIP: {
	skip("Permission denied for $wpt", 3)
	    if !open my($fh), $wpt;
	my $s2 = eval { Strassen->new($wpt) };
	isa_ok($s2, "Strassen");
	isa_ok($s2, "Strassen::Gpsman");
	is "@{[ $s2->dependent_files ]}", $wpt;
    }

    #require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$s1, $s2],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

 SKIP: {
	skip("No -all option specified", 1)
	    if !$do_all;
	my @errors;
	my $i = 0;
	for my $gpsmanfile (@trk, @wpt) {
	    my $s_new   = Strassen->new($gpsmanfile);
	    my $s_magic = Strassen->new_by_magic($gpsmanfile);
	    if (!$s_new) {
		push @errors, "$gpsmanfile: new failed";
	    } elsif (!$s_magic) {
		push @errors, "$gpsmanfile: new_by_magic failed";
	    } elsif (scalar @{$s_magic->data} != scalar @{$s_new->data}) {
		push @errors, "$gpsmanfile: inconsistent read";
	    }
	}
	ok !@errors, "No errors checking all"
	    or diag join("\n", @errors);
    }
}

require Strassen::Gpsman; # because maybe nobody did it before!

{
    my $trk_sample = <<'EOF';
% Written by /home/e/eserte/src/bbbike/bbbike Wed Dec 28 19:10:26 2005
% Edit at your own risk!

!Format: DDD 1 WGS 84
!Creation: yes

!T:	TRACK
	31-Dec-1989 01:00:00	N53.0945536138593	E12.8748931621168	0
	31-Dec-1989 01:00:00	N53.0943054383567	E12.8761002946735	0
!T:	TRACK
	31-Dec-1989 01:00:00	N53.0940612438672	E12.877531259314	0
	31-Dec-1989 01:00:00	N53.0933655007711	E12.8813741665033	0
	31-Dec-1989 01:00:00	N53.0931727960854	E12.8831759358179	0
	31-Dec-1989 01:00:00	N53.0930156939216	E12.8844531899105	0
	31-Dec-1989 01:00:00	N53.0929946513017	E12.8857984410851	0
	31-Dec-1989 01:00:00	N53.0929775683148	E12.8873675328466	0
	31-Dec-1989 01:00:00	N53.0931440997843	E12.8891516695014	0
	31-Dec-1989 01:00:00	N53.0933489067498	E12.8905605502346	0
	31-Dec-1989 01:00:00	N53.0933013449282	E12.8904135187235	0

EOF
    my $s = load_from_string_and_check $trk_sample, 'trk';
    cmp_ok(scalar(@{$s->data}), "==", 2, "Track sample has two lines");
}

{
    my $wpt_sample = <<'EOF';
% Written by GPSManager 17-Jan-2002 22:35:45 (CET)
% Edit at your own risk!

!Format: DMS 1 WGS 84
!Creation: no

!W:
007		N52 30 46.0	E13 24 42.9	alt=32.3298339844	GD108:class=|c!	GD108:colour=~|Z	GD108:attrs=`	GD108:depth=QY|c%|_i	GD108:state=|cAA	GD108:country=|cAA
008		N52 30 42.6	E13 24 30.6	alt=33.05078125	GD108:class=|c!	GD108:colour=~|Z	GD108:attrs=`	GD108:depth=QY|c%|_i	GD108:state=|cAA	GD108:country=|cAA

EOF
    my $s = load_from_string_and_check $wpt_sample, 'wpt';
    cmp_ok(scalar(@{$s->data}), "==", 2, "Waypoint sample version one has two objects");
}

{
    my $wpt_sample = <<'EOF';
% Written by GPSManager 2006-07-31 00:21:07 (CET)
% Edit at your own risk!

!Format: DMM 2 WGS 84
!Creation: yes

!W:
019	30-JUL-06 13:01:35	2006-07-30 23:57:21	N52 31.152	E13 04.405	symbol=crossing	alt=42.7	GD109:dtyp=|c"	GD109:class=|c!	GD109:colour=|c@	GD109:attrs=p	GD109:depth=1I|c3%	GD109:state=|cAA	GD109:country=|cAA	GD109:ete=~|R$|Z
020	30-JUL-06 13:05:13	2006-07-30 23:57:21	N52 31.591	E13 04.648	symbol=crossing	alt=47.0	GD109:dtyp=|c"	GD109:class=|c!	GD109:colour=|c@	GD109:attrs=p	GD109:depth=1I|c3%	GD109:state=|cAA	GD109:country=|cAA	GD109:ete=~|R$|Z
EOF
    my $s = load_from_string_and_check $wpt_sample, 'wpt';
    cmp_ok(scalar(@{$s->data}), "==", 2, "Waypoint sample version two has two objects");
}

{
    my $utm_sample = <<'EOF';
% Written by GPSManager 08-Feb-2002 10:33:19 (CET)
% Edit at your own risk!

!Format: DMS 1 WGS 84
!Creation: no

!W:
392	WILDENBRUCH WEIGANDUFER	N52 29 06.2	E13 26 40.1	alt=22.4763183594
!Position: UTM/UPS
A2	ALT STRALAU MARKGRAFENDAMM	33	U	395766	5817425
!Position: DMS
A3	ELSEN KIEFHOLZ	N52 29 21.1	E13 27 14.6	alt=11.6732177734

EOF
    my $s = load_from_string_and_check $utm_sample, 'wpt';
    is_deeply $s->data, 
	[
	 "392 (WILDENBRUCH WEIGANDUFER)\tX 13210,8863\n",
	 "A2 (ALT STRALAU MARKGRAFENDAMM)\tX 14548,10215\n",
	 "A3 (ELSEN KIEFHOLZ)\tX 13852,9335\n"
	], 'wpt data with PositionFormat change and UTM/UPS usage';
}

# 9 tests
sub load_from_string_and_check ($$) {
    my($data, $type) = @_;

    my $s = Strassen::Gpsman->new_from_string($data);
    isa_ok $s, "Strassen";
    isa_ok $s, "Strassen::Gpsman";

    my($tmpfh,$tmpfile) = tempfile(SUFFIX => '.'.$type, UNLINK => 1)
	or die $!;
    print $tmpfh $data or die $!;
    close $tmpfh;

    {
	my $s_file = Strassen->new_by_magic($tmpfile);
	isa_ok $s_file, "Strassen";
	isa_ok $s_file, "Strassen::Gpsman";
	is_deeply $s_file->data, $s->data, "Loading $type with magic check";
    }

    {
	my $s_file = Strassen->new($tmpfile);
	isa_ok $s_file, "Strassen";
	isa_ok $s_file, "Strassen::Gpsman";
	is_deeply $s_file->data, $s->data, "Loading $type with magic check in factory method";
	is "@{[ $s_file->dependent_files ]}", $tmpfile;
    }

    $s;
}

__END__
