#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin", "$FindBin::RealBin/..");

use Cwd qw(getcwd);
use File::Glob qw(bsd_glob);
use File::Spec qw();
use Getopt::Long;

use BBBikeUtil qw(is_in_path);

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
my $cwd = getcwd;

my @files = grep { -f $_ && !m{\.el$} && !m{\.sh$} && !m{\.xslt$} & !m{\.py$} } bsd_glob("miscsrc/*");

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

my %symlinks_on_windows;
if ($^O eq 'MSWin32' && is_in_path('git')) {
    # git & symlinks do not work good on Windows systems
    # See https://stackoverflow.com/questions/5917249/git-symbolic-links-in-windows

    if ($ENV{APPVEYOR}) {
	# It seems that on appveyor a git-checkout without a .git directory
	# is done, so the code below does not work. For now hardcode known
	# symlinks (XXX better solution needed!)
	$symlinks_on_windows{'miscsrc/any2gpsman'} = 1;
    } else {
	# Find all symlinks in miscsrc to skip them later
	# Don't use list form on pipe open, test should be runnable on older perls:
	# https://metacpan.org/dist/perl/view/pod/perl5220delta.pod#List-form-of-pipe-open-implemented-for-Win32
	if (open my $fh, 'git ls-files -s miscsrc |') {
	    while(<$fh>) {
		chomp;
		my @F = split /\s+/, $_, 4;
		if ($F[0] eq '120000') {
		    $symlinks_on_windows{$F[3]} = 1;
		}
	    }
	}
    }
}

for my $f (@files) {
 SKIP: {
	skip "Using non-standard NetPBM modules", 1
	    if $f =~ m{/tilemap$};
	skip "Symlinks may not work on Windows ($f is a symlink)", 1
	    if $symlinks_on_windows{$f};
	myskip "$f works only with installed mod_perl (1 or 2)", 1
	    if $f =~ m{/FixRemoteAddrHandler\.pm$} && !eval { require Apache2::Const; 1 } && !eval { require Apache::Constants; 1 };
	myskip "$f works only with installed Tk::Zinc", 1
	    if $f =~ m{/tkzincbbbike$} && !eval { require Tk::Zinc; 1 };
	myskip "$f works only with installed Tk", 1
	    if $f =~ m{/( bbbike_chooser.pl
		       |  tk-bbbike-grep
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
	    if $f =~ m{/( bvg_disruptions_format.pl
		       |  cvsdiffbbd
		       |  docker-bbbike
		       |  parse_mvt_sequences\.pl
		       |  fragezeichen2org\.pl
		       |  mudways-enriched-to-handicap\.pl
		       |  temp_blockings_tasks
		       |  VMZTool\.pm
		       )$}x && $] < 5.010;
	myskip "$f works only with perl >= 5.14.0", 1
	    if $f =~ m{/( mudways-enrich.pl
		       )$}x && $] < 5.014;
	myskip "$f works only with installed Algorithm::Diff", 1
	    if $f =~ m{/diffbbd$} && !eval { require Algorithm::Diff; 1 };
	myskip "$f works only with installed DateTime::Format::ISO8601", 1
	    if $f =~ m{/exif2gpsman$} && !eval { require DateTime::Format::ISO8601; 1 };
	skip "$f works only if ~/src/Doit exists", 1
	    if $f =~ m{/copy-doit.pl$} && !-d "$ENV{HOME}/src/Doit";
	myskip "$f works only with newer List::Util (>= 1.45, impl of 'uniqstr', and >= 1.33, impl of 'any')", 1
	    if $f =~ m{/bvg_disruptions_format.pl$} && !eval q{ use List::Util 1.45; 1 };
	myskip "$f works only with newer List::Util (>= 1.33, impl of 'any')", 1
	    if $f =~ m{/VMZTool\.pm$} && !eval q{ use List::Util 1.33; 1 };
	myskip "$f works only with installed List::MoreUtils", 1
	    if $f =~ m{/bvg_disruptions_diff.pl$} && !eval q{ use List::MoreUtils; 1 };
	myskip "$f works only with installed Text::CSV_XS", 1
	    if $f =~ m{/( vbb-stops-to-bbd.pl
                       |  mudways-enrich.pl
		       )$}x && !eval { require Text::CSV_XS; 1 };
	myskip "$f works only with installed Time::Moment", 1
	    if $f =~ m{/( bvg_disruptions_format.pl
		       |  mapillary-v4-fetch                  
		       )$}x && !eval { require Time::Moment; 1 };

	my @add_opts;
	if ($f =~ m{\.pm$}) {
	    push @add_opts, "-I$cwd", "-I$cwd/lib", "-I$cwd/miscsrc";
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

	my @cmd = ($^X, ($can_w ? "-w" : ()), "-c", @add_opts, "./$f");
	system(@cmd);
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
		diag("While running '@cmd':\n" . Text::Wrap::wrap("# ", "# ", $diag));
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
    require BBBikeTest;
    BBBikeTest::noskip_diag();
}

__END__
