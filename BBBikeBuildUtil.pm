# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2017,2018,2021,2022,2023,2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeBuildUtil;

use strict;
use vars qw($VERSION @EXPORT_OK);
$VERSION = '0.10';

use Exporter 'import';
@EXPORT_OK = qw(get_pmake run_pmake module_path module_version get_modern_perl monkeypatch_manifind is_system_perl);

use File::Glob qw(bsd_glob);

use BBBikeUtil qw(is_in_path module_path);

# Get a BSD make
sub get_pmake (;@) {
    my %opt = @_;
    my $fallback = exists $opt{fallback} ? delete $opt{fallback} : 1;
    my $canV = exists $opt{canV} ? delete $opt{canV} : 0; # -V option can compute value
    die "Unhandled args: " . join(" ", %opt) if %opt;

    return 'make'           if $^O =~ m{bsd}i;                           # standard BSD make
    return 'bsdmake'        if $^O eq 'darwin' && is_in_path('bsdmake'); # homebrew bsdmake package
    return 'fmake'          if is_in_path('fmake');                      # debian jessie .. buster (package freebsd-buildutils)
    return 'freebsd-make'   if is_in_path('freebsd-make');               # debian wheezy and earlier
    my $not_fully_capable;
    if ($canV && (is_in_path('bmake') || -x '/usr/bin/pmake') && !$fallback) {
	die "No fully capable BSD make found on this system --- try to install fmake or freebsd-make"
    }
    return 'bmake'          if is_in_path('bmake');                      # debian jessie and later (package bmake; -V cannot expand)
    return '/usr/bin/pmake' if -x '/usr/bin/pmake';                      # debian jessie and later (package bmake, just a symlink to bmake; -V cannot expand)
    if (!$fallback) {
	die "No BSD make found on this system --- try to install bsdmake, fmake, freebsd-make, bmake, pmake, or something similar"
    }
    return 'pmake'; # self-compiled BSD make, maybe. Note that pmake may also be a script that comes with the CPAN module Make.pm, which is not a BSD make
}

# Use like this:
#    cd .../bbbike/data
#    perl -I.. -MBBBikeBuildUtil=run_pmake -e 'run_pmake'
#    perl -I.. -MBBBikeBuildUtil=run_pmake -e 'run_pmake' slow-checks -j4
sub run_pmake {
    my $pmake = get_pmake(fallback => 0);
    my @cmd = ($pmake, @ARGV);
    exec @cmd;
    die "Failed to run '@cmd': $!";
}

# Return module version without loading the module
# (may fail in some situations)
sub module_version {
    my($module) = @_;
    require ExtUtils::MakeMaker;
    MM->parse_version(module_path($module));
}

sub get_modern_perl (;@) {
    my %opt = @_;
    my %required_modules;
    if (exists $opt{required_modules}) {
	%required_modules = %{ delete $opt{required_modules} };
    }
    my $fallback = exists $opt{fallback} ? delete $opt{fallback} : 1;
    my $opt_debug = delete $opt{debug};
    die "Unhandled args: " . join(" ", %opt) if %opt;

    my $debug = $opt_debug ? sub ($) {
	warn $_[0], "\n";
    } : sub ($) {};

    # Convention: perls are available as /opt/perl-5.X.Y/bin/perl
    # Do not use bleadperl or RCs.
    # The required modules check is quite rudimentary and
    # tries to avoid actually running code or loading modules.
    my @perldir_candidates =
	map { $_->[1] } 
	sort { $b->[0] cmp $a->[0] }
	map { [ do {
	    if (m{/perl-(5)\.(\d+)\.(\d+)$}) {
		$1 + $2/1000 + $3/1_000_000;
	    } else {
		0;
	    }
	}, $_] }
	grep { m{/perl-5\.(\d+)\.\d+$} && $1 % 2 == 0 }
	bsd_glob("/opt/perl-5.*.*");
    my $min_missing;
    my $fallback_perlpath = $^X;
 PERL_CANDIDATE:
    for my $perldir_candidate (@perldir_candidates) {
	$debug->("Check perl candidate $perldir_candidate...");
	my $perlpath = "$perldir_candidate/bin/perl";
	if (-x $perlpath) {
	    my $missing = 0;
	    for my $required_module (keys %required_modules) {
		local @INC = grep { -d } (
					  bsd_glob("$perldir_candidate/lib/site_perl/*/*$^O*"),
					  bsd_glob("$perldir_candidate/lib/site_perl/*"),
					 ); # only check for site_perl here
		if (!module_path($required_module)) {
		    $debug->("... module $required_module not available.");
		    $missing++;
		}
	    }
	    if ($missing) {
		if ($missing != scalar(keys %required_modules) && $fallback) {
		    if (!defined $min_missing || $min_missing > $missing) {
			$debug->("... use as possible fallback perl (missing: $missing)");
			$fallback_perlpath = $perlpath;
			$min_missing = $missing;
		    }
		}
		next PERL_CANDIDATE;
	    }
	    $debug->("... candidate is sufficient.");
	    return $perlpath;
	} else {
	    $debug->("... no .../bin/perl found.");
	}
    }
    if ($fallback) {
	$debug->("Use $fallback_perlpath as fallback.");
	return $fallback_perlpath;
    } else {
	$debug->("No matching perl found, and fallback is disabled.");
	return undef;
    }
}

# See
#   https://github.com/Perl-Toolchain-Gang/ExtUtils-Manifest/issues/5
#   https://github.com/Perl-Toolchain-Gang/ExtUtils-Manifest/issues/6
#   https://github.com/Perl-Toolchain-Gang/ExtUtils-Manifest/issues/16
sub monkeypatch_manifind {
    my(%opts) = @_;
    my $v = delete $opts{v};
    die 'Unhandled options: ' . join(' ', %opts) if %opts;

    if (eval { require ExtUtils::Manifest; $ExtUtils::Manifest::VERSION < 1.66 }) {
	if ($v) {
	    warn "INFO: no need to monkey-patch ExtUtils::Manifest::manifind.\n";
	}
    } else {
	# This is a simplified version of manifind without VMS & MacOS
	# support, but containing the follow_skip patch.
	my $new_manifind = sub {
	    my $found = {};
	    no warnings 'once'; # because of $File::Find::name
	    my $wanted = sub {
		return if -d $_;
		(my $name = $File::Find::name) =~ s{^./}{};
		$found->{$name} = "";
	    };
	    File::Find::find({wanted => $wanted, follow_fast => 1, follow_skip => 2}, '.');
	    $found;
	};
	no warnings 'redefine', 'once';
	*ExtUtils::Manifest::manifind = $new_manifind;
	if ($v) {
	    warn "INFO: monkey-patched ExtUtils::Manifest::manifind.\n";
	}
    }
}

# not exported
sub is_same_file ($$) {
    my($file1, $file2) = @_;
    return 1 if $file1 eq $file2;

    my @stat1 = stat($file1) or do { warn "Cannot stat $file1: $!"; return 0 };
    my @stat2 = stat($file2) or do { warn "Cannot stat $file2: $!"; return 0 };

    if ($stat1[0] == $stat2[0] && $stat1[1] == $stat2[1]) {
	return 1; # hardlinked
    } elsif (-l $file1 && readlink($file1) eq $file2) {
	return 1; # symlinked
    } elsif (-l $file2 && readlink($file2) eq $file1) {
	return 1; # symlinked
    } else {
	return 0;
    }
}

sub is_system_perl (;$) {
    my($check_perl) = @_;
    $check_perl = $^X if !defined $check_perl;
    my $system_perl = $^O =~ /bsd/i ? '/usr/local/bin/perl' : '/usr/bin/perl';
    is_same_file($check_perl, $system_perl);
}

1;

__END__
