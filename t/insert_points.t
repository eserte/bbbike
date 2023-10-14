#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use File::Temp qw(tempfile);
use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test::More;
	use IPC::Run qw(run);
	1;
    }) {
	print "1..0 # skip no Test::More and/or IPC::Run modules\n";
	exit;
    }
}

#use POSIX 'strftime';
#use constant TODO_MEHRINGDAMM_FRAGEZEICHEN => "2016-10-14T12:00:00" gt strftime('%FT%T', localtime) && 'temporary fragezeichen entry';

my @insert_points = ($^X, "$FindBin::RealBin/../miscsrc/insert_points");
my $datadir = "$FindBin::RealBin/../data";
if (!-e $insert_points[-1]) {
    print "1..0 # skip insert_points script not available\n";
    exit 0;
}

my $v;
GetOptions("v!" => \$v)
    or die "usage: $0 [-v]";

plan tests => 19 * 2;

my($logfh,$logfile) = tempfile(SUFFIX => ".log", UNLINK => 1);

my $dudenstr      = "9229,8785"; # ecke Mehringdamm

BEGIN { $^W = 0 }
my @methfesselstr = qw(8982,8781 9063,8935);
BEGIN { $^W = 1 }

# In the following checks, ignore changes regarding fragezeichen
# or fragezeichen-orig --- such changes are usually temporary.

for my $use_indexer (0, 1) {
    my $indexer_label = ($use_indexer ? "(with indexer)" : "(without indexer)");

    my @common_args = ("-report", "-useint",
		       "-datadir", $datadir, "-n",
		       "-logfile", $logfile,
		       ($use_indexer ? "-indexer" : "-noindexer"),
		      );
    if ($v) {
	push @common_args, "-v";
    }

 SKIP: {
	skip "Workaround utf-8 problem", 4
	    if $] == 5.008 && defined $ENV{LANG} && $ENV{LANG} =~ /utf/i;

	{
	    my($stdout, $stderr, $success) = run_insert_points("-operation", "grep",
							       @common_args,
							       $dudenstr);
	    my @res = grep { $_ ne 'fragezeichen-orig' } @$stdout;
	    is(join(" ", sort @res),
	       join(" ",
		    qw(../misc/ampelschaltung-orig.txt),
		    "$FindBin::RealBin/../data/temp_blockings/bbbike-temp-blockings.pl",
		    qw(
		       ampeln-orig
		       ampelschaltung-orig
		       exits-orig
		       flaechen-orig
		       hoehe-orig
		       housenumbers-orig
		       radwege-orig
		       strassen-orig
		      )),
	       "orig and grep $indexer_label");
	    is $stderr, '', 'no warnings';
	    ok $success;
	}

	{
	    my($stdout) = run_insert_points("-operation", "grep",
					    @common_args,
					    "-noorig",
					    $dudenstr);
	    my @res = grep { $_ ne 'fragezeichen' } @$stdout;
	    is(join(" ", sort @res),
	       join(" ",
		    qw(../misc/ampelschaltung.txt),
		    "$FindBin::RealBin/../data/temp_blockings/bbbike-temp-blockings.pl",
		    qw(
		       ampeln
		       ampelschaltung
		       exits
		       flaechen
		       hoehe
		       housenumbers
		       radwege_exact
		       strassen
		      )),
	       "generated and grep $indexer_label");
	}

	{
	    my($stdout, $stderr, $success) = run_insert_points("-operation", "grep",
							       @common_args,
							       $dudenstr, "0,0");
	    is_deeply $stdout, [], 'no hit detected because of error';
	    like $stderr, qr{Too many points}, 'expected too many points warning';
	    ok !$success, 'detected error';
	}

	{
	    my($stdout, $stderr, $success) = run_insert_points("-operation", "change",
							       @common_args,
							       $dudenstr, $dudenstr);
	    is_deeply $stdout, [], 'same point, no change needed';
	    like $stderr, qr/same point/i, 'expected warning';
	    ok $success;
	}

	{
	    my($stdout) = run_insert_points("-operation", "change",
					    @common_args,
					    $dudenstr, "0,0");
	    my @res = grep { $_ ne 'fragezeichen-orig' } @$stdout;
	    is(join(" ", sort @res),
	       join(" ",
		    qw(../misc/ampelschaltung-orig.txt),
		    "$FindBin::RealBin/../data/temp_blockings/bbbike-temp-blockings.pl",
		    qw(
		       ampeln-orig
		       ampelschaltung-orig
		       exits-orig
		       flaechen-orig
		       hoehe-orig
		       housenumbers-orig
		       radwege-orig
		       strassen-orig
		      )),
	       "orig and change $indexer_label");
	}

	{
	    my($stdout) = run_insert_points("-operation", "change",
					    @common_args,
					    "-noorig",
					    $dudenstr, "0,0");
	    my @res = grep { $_ ne 'fragezeichen' } @$stdout;
	    is(join(" ", sort @res),
	       join(" ",
		    qw(../misc/ampelschaltung.txt),
		    "$FindBin::RealBin/../data/temp_blockings/bbbike-temp-blockings.pl",
		    qw(
		       ampeln
		       ampelschaltung
		       exits
		       flaechen
		       hoehe
		       housenumbers
		       radwege_exact
		       strassen
		      )),
	       "generated and change $indexer_label");
	}

	{
	    my($stdout) = run_insert_points("-operation", "grepline",
					    @common_args,
					    @methfesselstr);
	    is(join(" ", sort @$stdout),
	       join(" ", qw(qualitaet_s-orig strassen-orig)),
	       "orig and grepline $indexer_label");
	}

	{
	    my($stdout) = run_insert_points("-operation", "changeline",
					    @common_args,
					    @methfesselstr, "0,0");
	    is(join(" ", sort @$stdout),
	       join(" ", qw(qualitaet_s-orig strassen-orig)),
	       "orig and changeline $indexer_label");
	}

	{
	    my($stdout) = run_insert_points("-operation", "insertmulti",
					    @common_args,
					    $methfesselstr[0], "0,0", $methfesselstr[1]);
	    is(join(" ", sort @$stdout),
	       join(" ", qw(qualitaet_s-orig strassen-orig)),
	       "orig and insertmulti $indexer_label");
	}

	{
	    my($stdout, $stderr, $success) = run_insert_points("-operation", "grep",
							       @common_args,
							       "123456789,987654321");
	    is_deeply $stdout, [];
	    like $stderr, qr{Punkt nicht gefunden};
	}

	{
	    my($stdout, $stderr, $success) = run_insert_points("-operation", "grepline",
							       @common_args,
							       "123456789,987654321", "987654321,123456789");
	    is_deeply $stdout, [];
	    like $stderr, qr{Strecke nicht gefunden};
	}
    }
}

sub run_insert_points {
    my(@args) = @_;
    my($stdout, $stderr);
    my $success = run [@insert_points, @args], '>', \$stdout, '2>', \$stderr;
    my @stdout = split /\n\r?/, $stdout;
    (\@stdout, $stderr, $success);
}

__END__
