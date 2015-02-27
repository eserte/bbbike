#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use File::Glob qw(bsd_glob);
use File::Spec qw();
use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test::More 'no_plan'; # number of tests varies
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

my $do_skip = 1;
GetOptions("skip!" => \$do_skip)
    or die "usage: $0 [-noskip]";

chdir "$FindBin::RealBin/.." or die $!;

my @files = grep { -f $_ && !m{\.el$} && !m{\.sh$} && !m{\.xslt$} } bsd_glob("miscsrc/*");

my $has_skips = 0;
sub myskip ($$) {
    my($why, $howmany) = @_;
    if ($do_skip) {
	$has_skips++;
	skip $why, $howmany;
    }
}

# Simulate mod_perl2 if needed
if (eval { require Apache2::Const; 1 }) {
    $ENV{MOD_PERL_API_VERSION} = 2;
}

for my $f (@files) {
 SKIP: {
	skip "Using non-standard NetPBM modules", 1
	    if $f =~ m{/tilemap$};
	myskip "$f works only with installed mod_perl (1 or 2)", 1
	    if $f =~ m{/FixRemoteAddrHandler\.pm$} && !eval { require Apache2::Const; 1 } && !eval { require Apache::Constants; 1 };
	myskip "$f works only with installed Tk::Zinc", 1
	    if $f =~ m{/tkzincbbbike$} && !eval { require Tk::Zinc; 1 };
	myskip "$f works only with installed Tk", 1
	    if $f =~ m{/( bbbike_chooser.pl
		       |  BBBikeRouteLister.pm
		       |  trafficlightgraph.pl
		       )$}x && !eval { require Tk; 1 };
	myskip "$f works only with installed Statistics::Descriptive", 1
	    if $f =~ m{/( convert_berlinmap.pl
		       |  Cov.pm
		       )$}x && !eval { require Statistics::Descriptive; 1 };
	myskip "$f works only with installed Text::Table", 1
	    if $f =~ m{/( track_stats.pl
		       |  XXX_new_comments.pl
		       )$}x && !eval { require Text::Table; 1 };
	myskip "$f works only with installed MIME::Parser", 1
	    if $f =~ m{/visualize_user_input.pl$} && !eval { require MIME::Parser; 1 };
	myskip "$f works only with installed File::ReadBackwards", 1
	    if $f =~ m{/replay_accesslog$} && !eval { require File::ReadBackwards; 1 };
	myskip "$f works only with installed DB_File::Lock", 1
	    if $f =~ m{/correct_data.pl$} && !eval { require DB_File::Lock; 1 };
	myskip "$f works only with perl >= 5.10.0", 1
	    if $f =~ m{/cvsdiffbbd} && $] < 5.010;
	
	my @add_opts;
	if ($f =~ m{\.pm$}) {
	    push @add_opts, "-Ilib", "-Imiscsrc";
	}

	*OLDERR = *OLDERR; # cease -w
	open(OLDERR, ">&STDERR") or die;
	my $diag_file = File::Spec->tmpdir . "/bbbike-miscsrc.test";
	open(STDERR, ">$diag_file") or die "Can't write to $diag_file: $!";

	my $can_w = 1;
	if ($f =~ m{^( miscsrc/BBBikeOsmUtil\.pm
		    |  miscsrc/CombineTrainStreetNets\.pm
		    |  miscsrc/TrafficLightCircuitGPSTracking\.pm
		    |  miscsrc/TelbuchDBApprox\.pm
		   )$}x) {
	    $can_w = 0;
	}
	$can_w = 0 if $] < 5.006; # too many additional warnings

	system($^X, ($can_w ? "-w" : ()), "-c", @add_opts, "./$f");
	close STDERR;
	open(STDERR, ">&OLDERR") or die;
	die "Signal caught" if $? & 0xff;

	my $diag;
	if (open(DIAG, $diag_file)) {
	    local $/ = undef;
	    $diag = <DIAG>;
	    close DIAG;
	}

	is($?, 0, "Check $f")
	    or do {
		require Text::Wrap;
		print Text::Wrap::wrap("# ", "# ", $diag), "\n";
	    };

	if (defined $diag && $diag ne "") {
	    my $warn = "";
	    for (split /\n/, $diag) {
		next if / syntax OK/;
		$warn .= $_;
	    }
	    is($warn, "", "Warnings " . ($can_w ? "" : "(only mandatory) ") . "in $f");
	}

	unlink $diag_file;
    }
}

if ($has_skips) {
    diag <<EOF;

There were skips because of missing modules or other prerequisites. You can
rerun this test with

    $^X $0 -noskip

to see failing tests because of these modules.
EOF
}

__END__
