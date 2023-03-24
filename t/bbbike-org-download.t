#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

# NOTE: this test is controlled by three environment variables:
#
# - BBBIKE_TEST_NO_NETWORK: if set to a perl-true value,
#   then this test is completely skipped
#
# - BBBIKE_LONG_TESTS: if set to a perl-true value,
#   then a random city will be chosen for download (which may
#   result in loading big data files)
#
# - BBBIKE_TEST_SLOW_NETWORK: if set to a perl-true value,
#   then always a quite small city will be downloaded,
#   regardless of the BBBIKE_LONG_TESTS setting

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../miscsrc", # for BBBikeOrgDownload.pm
	 $FindBin::RealBin,
	);

use Getopt::Long;
use File::Temp qw(tempdir);
use IPC::Open3 qw(open3);
use Symbol qw(gensym);

use BBBikeUtil qw(is_in_path);
use Strassen::Core ();

use BBBikeTest qw(check_network_testing);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

check_network_testing;

#plan skip_all => 'Mysterious download fails' if $ENV{APPVEYOR}; # for example: https://ci.appveyor.com/project/eserte/bbbike/build/1.0.65#L270
plan 'no_plan';

my $city;
# Enable debugging by default on Windows, because of download problems
# seen in appveyor environment.
my $debug = ($^O eq 'MSWin32');
GetOptions(
    'city=s' => \$city,
    'debug!' => \$debug,
)
    or die "usage: $0 [-city ...] [-[no]debug]\n";

my $download_script = "$FindBin::RealBin/../miscsrc/bbbike.org_download.pl";

ok -e $download_script, 'Download script exists';

my @debug_opts = $debug ? ('-debug'): ();

my @urls = (undef); # test default
if ($ENV{BBBIKE_LONG_TESTS}) {
    require BBBikeOrgDownload;
    (my $https_url = BBBikeOrgDownload::DEFAULT_ROOT_URL()) =~ s{^http:}{https:};
    if ($https_url ne BBBikeOrgDownload::DEFAULT_ROOT_URL()) {
	push @urls, $https_url;
    } else {
	diag "DEFAULT_ROOT_URL looks like a https URL, adding it to \@urls is not necessary anymore";
    }
}

for my $url (@urls) {

    my @url_opts        = defined $url ? ('-url' => $url) : ();
    my $testname_append = defined $url ? " (using url $url)" : '';

    my @listing;
    {
	if ($^O eq 'MSWin32') { # XXX somehow the IPC::Open3 code does not work on Windows, so use the old approach, without the ability to check for openssl errors
	    chomp(@listing = `$^X $download_script @debug_opts @url_opts`);
	} else {
	    # Need also stderr here but don't want to rely on IPC::Run,
	    # so use IPC::Open3 instead (sigh):
	    my($rdr,$errfh);
	    $errfh = gensym;
	    my $pid = open3(undef, $rdr, $errfh, $^X, $download_script, @debug_opts, @url_opts);
	    while(<$rdr>) {
		chomp;
		push @listing, $_;
	    }
	    my $stderr = join("", <$errfh>);
	    if (!@listing) {
		if ($stderr =~ /probably openssl is too old/ && ($ENV{TRAVIS}||'') eq 'true' && ($ENV{CODENAME}||'') =~ m{^(precise|trusty)$}) {
		    diag "Known failure on precise+trusty (openssl problem), skip rest of tests";
		    exit 0;
		} else {
		    diag "Command failed: $stderr";
		}
	    }
	}

	# 2012-03-16: there are 231 cities available + original bbbike data
	cmp_ok scalar(@listing), ">=", 100, "More than 100 cities found$testname_append";
    
	ok ((grep { $_ eq 'Wien' } @listing), "Found Wien in listing$testname_append");
    }

    {
	my $random = $ENV{BBBIKE_TEST_SLOW_NETWORK} ? 0 : $ENV{BBBIKE_LONG_TESTS} ? 1 : 0;

	my($dir) = tempdir("bbbike.org_download_XXXXXXXX", CLEANUP => 1, TMPDIR => 1)
	    or die "Cannot create temporary directory: $!";
	my $city = $city || ($random ? $listing[rand(@listing)] : 'UlanBator'); # size of Ulan Bator dataset on 2016-04-03: 311.9K
	system($^X, $download_script, @debug_opts, @url_opts, "-city", $city, "-o", $dir, "-agentsuffix", " (testing)");
	is $?, 0, "Downloading city '$city'";
	ok -d "$dir/$city", "Directory $dir/$city exists";
	ok -f "$dir/$city/strassen", "strassen found for $city";
    SKIP: {
	    skip "No 'meta.yml' expected in '$city' file", 1
		if $city eq 'data';
	    ok -f "$dir/$city/meta.yml", "meta.yml found for $city";
	}

	my $s = Strassen->new("$dir/$city/strassen");
	isa_ok $s, 'Strassen';
    }
}

SKIP: {
    # Simulate broken downloads
    my $wget_path = is_in_path('wget');
    skip "wget needed for simulation", 1 if !$wget_path;
    skip "IPC::Run needed for simulation", 1 if !eval { require IPC::Run; 1 };
    my @wget_options;
    # Detect problematic wget because of
    # https://letsencrypt.org/docs/dst-root-ca-x3-expiration-september-2021/
    {
	my $no_check_certificate;
	if ($^O eq 'linux' && is_in_path('ldd')) {
	    my $ldd_output = `ldd $wget_path`;
	    if ($ldd_output =~ m{(\Qlibgnutls-deb0.so.28\E|\Qlibssl.so.1.0.0\E)}) {
		$no_check_certificate = 1;
	    } elsif ($ldd_output =~ m{\Qlibgnutls.so.30\E}) {
		# check for problematic versions
		my $cmd = q{dpkg -s libgnutls30 | perl -nle 'm/^Version:\s+(\S+)/ and print $1'};
		chomp(my $libgnutls_version = `$cmd`);
		if ($libgnutls_version =~ m{^3\.5\.8-5\+deb9u[0-5]$}) {
		    $no_check_certificate = 1;
		}
	    }
	}
	if ($no_check_certificate) {
	    push @wget_options, '--no-check-certificate';
	    diag "Run wget with --no-check-certificate";
	}
    }

    require BBBikeOrgDownload;

    my($dir) = tempdir("bbbike.org_download_XXXXXXXX", CLEANUP => 1, TMPDIR => 1)
	or die "Cannot create temporary directory: $!";
    my $city = 'UlanBator';
    my $url = BBBikeOrgDownload->new->get_city_url($city);
    my $stderr;
    my $success = do {
	local $ENV{LC_ALL} = 'C';
	IPC::Run::run(['wget', @wget_options, "-O$dir/$city.tbz", $url], '2>', \$stderr);
    };
    if (!$success) {
	if ($stderr =~ /Unable to establish SSL connection/) {
	    # may happen for older wget -> skip in this case
	    diag "Error running wget:\n$stderr";
	    skip "Skipping wget simulation because of SSL problems (old wget?)", 1;
	}
	fail "Downloading $url failed: $stderr";
    } else {
	mkdir "$dir/extract";
	my $size = -s "$dir/$city.tbz";
	truncate "$dir/$city.tbz", $size-100;
	{
	    my $success = IPC::Run::run([$^X, $download_script, @debug_opts, '-url', 'file://'.$dir, '-city', $city, '-o', "$dir/extract"], '2>', \my $stderr);
	    ok !$success, "Simulate downloading truncated tarball for city '$city', Archive::Tar or tar";
	    like $stderr, qr{Error while extracting(.*\Q$city\E.*with Archive::Tar| using tar xfj.*\Q$city\E)};
	}
    SKIP: {
	    skip "No Devel::Hide available", 2 if !eval { require Devel::Hide; 1 };
	    my $success = IPC::Run::run([$^X, "-MDevel::Hide=Archive::Tar", $download_script, @debug_opts, '-url', 'file://'.$dir, '-city', $city, '-o', "$dir/extract"], '2>', \my $stderr);
	    ok !$success, "Simulate downloading truncated tarball for city '$city', force tar";
	    like $stderr, qr{Error while extracting using tar xfj.*\Q$city\E};
	}
    }
}

__END__
