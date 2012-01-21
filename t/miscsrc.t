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

my @files = grep { !m{\.el$} && !m{\.sh$} && !m{\.xslt$} } bsd_glob("miscsrc/*");

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
