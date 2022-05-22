# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2017,2018,2021,2022 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeBuildUtil;

use strict;
use vars qw($VERSION @EXPORT_OK);
$VERSION = '0.06';

use Exporter 'import';
@EXPORT_OK = qw(get_pmake module_path module_version get_modern_perl monkeypatch_manifind);

use File::Glob qw(bsd_glob);
use version ();

use BBBikeUtil qw(is_in_path);

# Get a BSD make
sub get_pmake (;@) {
    my %opt = @_;
    my $fallback = exists $opt{fallback} ? delete $opt{fallback} : 1;
    die "Unhandled args: " . join(" ", %opt) if %opt;

    (
     $^O =~ m{bsd}i                             ? "make"         # standard BSD make
     : $^O eq 'darwin' && is_in_path('bsdmake') ? 'bsdmake'      # homebrew bsdmake package
     : is_in_path("bmake")			? 'bmake'        # debian jessie and later (package bmake)
     : is_in_path("fmake")                      ? "fmake"        # debian jessie .. buster (package freebsd-buildutils)
     : is_in_path("freebsd-make")               ? "freebsd-make" # debian wheezy and earlier
     : -x '/usr/bin/pmake'			? '/usr/bin/pmake' # debian jessie and later (package bmake, just a symlink to bmake)
     : !$fallback                               ? die "No BSD make found on this system --- try to install bsdmake, bmake, fmake, pmake, or something similar"
     : "pmake"                                                   # self-compiled BSD make, maybe. Note that pmake may also be a script that comes with the CPAN module Make.pm, which is not a BSD make
    );
}

# REPO BEGIN
# REPO NAME module_path /home/eserte/src/srezic-repository 
# REPO MD5 ac5f3ce48a524d09d92085d12ae26e8c
sub module_path {
    my($filename) = @_;
    $filename =~ s{::}{/}g;
    $filename .= ".pm";
    foreach my $prefix (@INC) {
	my $realfilename = "$prefix/$filename";
	if (-r $realfilename) {
	    return $realfilename;
	}
    }
    return undef;
}
# REPO END

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
    die "Unhandled args: " . join(" ", %opt) if %opt;

    # Convention: perls are available as /opt/perl-5.X.Y/bin/perl
    # Do not use bleadperl or RCs.
    # The required modules check is quite rudimentary and
    # tries to avoid actually running code or loading modules.
    my @perldir_candidates =
	map { $_->[1] } 
	sort { $b->[0] cmp $a->[0] }
	map { [ do {
	    if (m{/perl-(5\.\d+\.\d+)$}) {
		version->new($1);
	    } else {
		0;
	    }
	}, $_] }
	grep { m{/perl-5\.(\d+)\.\d+$} && $1 % 2 == 0 }
	bsd_glob("/opt/perl-5.*.*");
 PERL_CANDIDATE:
    for my $perldir_candidate (@perldir_candidates) {
	my $perlpath = "$perldir_candidate/bin/perl";
	if (-x $perlpath) {
	    for my $required_module (keys %required_modules) {
		local @INC = grep { -d } (
					  bsd_glob("$perldir_candidate/lib/site_perl/*/*$^O*"),
					  bsd_glob("$perldir_candidate/lib/site_perl/*"),
					 ); # only check for site_perl here
		if (!module_path($required_module)) {
		    next PERL_CANDIDATE;
		}
	    }
	    return $perlpath;
	}
    }
    return $^X;
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

1;

__END__
