# -*- perl -*-

#
# $Id: BBBikeTest.pm,v 1.21 2007/01/08 23:28:50 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004,2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeTest;

use vars qw(@opt_vars);
BEGIN {
    @opt_vars = qw($logfile $do_xxx $do_display $pdf_prog $cgiurl $debug
		   $cgidir
		  );
}

use strict;
use vars qw(@EXPORT);
use vars (@opt_vars);
use vars qw($can_tidy);

use base qw(Exporter);

use BBBikeUtil qw(is_in_path);

@EXPORT = (qw(get_std_opts set_user_agent do_display tidy_check eq_or_diff
	      is_long_data like_long_data unlike_long_data),
	   @opt_vars);

# Old logfile
#$logfile = "$ENV{HOME}/www/log/radzeit.de-access_log";
# New logfile since 2004-09-28 ca.
#$logfile = "$ENV{HOME}/www/log/radzeit.combined_log";
# Again the old name since 2005-06-XX ca.
$logfile = "$ENV{HOME}/www/log/radzeit.de-access_log";

if (defined $ENV{BBBIKE_TEST_CGIURL}) {
    $cgiurl = $ENV{BBBIKE_TEST_CGIURL};
} elsif (defined $ENV{BBBIKE_TEST_CGIDIR}) {
    $cgiurl = $ENV{BBBIKE_TEST_CGIDIR} . "/bbbike.cgi";
} else {
    $cgiurl = 'http://www/bbbike/cgi/bbbike.cgi';
}

if (defined $ENV{BBBIKE_TEST_CGIDIR}) {
    $cgidir = $ENV{BBBIKE_TEST_CGIDIR};
} else {
    $cgidir = 'http://www/bbbike/cgi';
}

sub get_std_opts {
    my(@what) = @_;
    my %std_opts = ("cgiurl=s"  => \$cgiurl,
		    "cgidir=s"  => \$cgidir,
		    "xxx"       => \$do_xxx,
		    "display!"  => \$do_display,
		    "debug!"    => \$debug,
		    "pdfprog=s" => \$pdf_prog,
		   );
    my %opts;
 OPT: for (@what) {
	keys %std_opts; # reset iterator
	while(my($k,$v) = each %std_opts) {
	    if ($k !~ /^(\w+[-\w|]*)?(!|[=:][infse][@%]?)?$/) {
		die "Error in option spec: \"", $k, "\"\n";
	    }
	    my($o,$type) = ($1,$2);
	    $type = "" if !defined $type;
	    if ($o eq $_) {
		$opts{"$o$type"} = $v;
		next OPT;
	    }
	}
	die "This is not a standard option: $_";
    }
    %opts;
}

sub set_user_agent {
    my($ua) = @_;
    $ua->agent("BBBike-Test/1.0");
    $ua->env_proxy;
}

# $filename_or_scalar: may be a filename or a scalar ref to the image contents
# $imagetype: the image type like "svg" or "pdf". May be omitted if supplying a filename
# with proper extension.
# The pseudo image format "http.html" can be used to start a WWW browser.
sub do_display {
    my($filename_or_scalar, $imagetype) = @_;

    my $filename;
    if (ref $filename_or_scalar eq 'SCALAR') {
	require File::Temp;
	my $fh;
	($fh, $filename) = File::Temp::tempfile(SUFFIX => ".$imagetype",
						UNLINK => !$debug,
					       );
	print $fh $$filename_or_scalar;
    } else {
	$filename = $filename_or_scalar;
    }

    if (!defined $imagetype && $filename =~ m{\.([^\.]+)}) {
	$imagetype = $1;
    }

    if ($imagetype eq 'svg') {
	# prefer ImageMagick (needs at least version 6) over Mozilla
	if (is_in_path("display")) {
	    system("display $filename &");
	} elsif (is_in_path("mozilla")) {
	    system("mozilla -noraise -remote 'openURL(file:$filename,new-tab)' &");
	} else {
	    warn "Can't display $filename";
	}
    } elsif ($imagetype eq 'pdf') {
	if (defined $pdf_prog) {
	    system("$pdf_prog $filename &");
	} elsif (is_in_path("xpdf")) {
	    system("xpdf $filename &");
	} else {
	    warn "Can't display $filename";
	}
    } elsif ($imagetype =~ /http\.html$/) { # very pseudo image type
	# XXX strip HTTP header from $filename!
	if (eval { require WWWBrowser; 1}) {
	    WWWBrowser::start_browser("file:$filename");
	} else {
	    warn "Can't find a browser to display $filename";
	}
    } else {
	if (is_in_path("xv")) {
	    system("xv $filename &");
	} elsif (is_in_path("display")) {
	    system("display $filename &");
	} else {
	    warn "Can't display $filename";
	}
    }
}

# only usable with Test::More, generates one test
sub tidy_check {
    my($content, $test_name, %args) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
 SKIP: {
	my $no_of_tests = 1;
	if (!defined $can_tidy) {
	    $can_tidy = is_in_path("tidy");
	}
	Test::More::skip("tidy is not available", $no_of_tests) if !$can_tidy;
	if (UNIVERSAL::isa($content, "HTTP::Message")) {
	    Test::More::skip("No html output", $no_of_tests)
		    if $content->headers->content_type ne "text/html";
	    $content = $content->content;
	}
	require File::Temp;
	my($fh, $filename) = File::Temp::tempfile(SUFFIX => ".html",
						  UNLINK => 1);
	if ($args{-charset}) {
	    eval 'binmode($fh, ":encoding($args{-charset})");';
	    warn $@ if $@;
	}
	print $fh $content;
	system("tidy", "-f", "/tmp/tidy.err", "-q", "-e", $filename);
	Test::More::cmp_ok($?>>8, "<", 2, $test_name)
		or do {
		    my $diag = "";
		    if ($args{-uri}) {
			$diag .= "$args{-uri}: ";
		    }
		    open(DIAG, "/tmp/tidy.err") or die;
		    local $/ = undef;
		    $diag .= <DIAG>;
		    close DIAG;
		    Test::More::diag($diag);
		};
    }
}

sub failed_long_data {
    my($got, $expected, $testname, $suffix) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    require File::Temp;
    require Data::Dumper;
    my($fh, $filename) = File::Temp::tempfile(SUFFIX => ".bbbike_test" . ($suffix ? $suffix : ""));
    my $dump;
    if ($suffix) {
	$dump = $got;
	Test::More::fail("Test <$testname> failed, <$expected> expected, see <$filename> for got contents");
    } else {
	$dump = Data::Dumper->new([$got, $expected],[qw(got expected)])->Indent(1)->Useqq(0)->Dump;
	Test::More::fail("Test <$testname> failed, see <$filename> for more information");
    }
    print $fh $dump;
    close $fh;
    0;
}

sub is_long_data {
    my($got, $expected, $testname, $suffix) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    if (!defined $got || !defined $expected) {
	Test::More::is($got, $expected, $testname);
    } else {
	my $eq = $got eq $expected;
	if ($eq) {
	    Test::More::pass($testname);
	} else {
	    failed_long_data($got, $expected, $testname, $suffix);
	}
    }
}

sub like_long_data {
    my($got, $expected, $testname, $suffix) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    if (!defined $got || !defined $expected) {
	Test::More::like($got, $expected, $testname);
    } else {
	my $matches = $got =~ $expected;
	if ($matches) {
	    Test::More::pass($testname);
	} else {
	    failed_long_data($got, $expected, $testname, $suffix);
	}
    }
}

sub unlike_long_data {
    my($got, $expected, $testname, $suffix) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    if (!defined $got || !defined $expected) {
	Test::More::unlike($got, $expected, $testname);
    } else {
	my $matches = $got !~ $expected;
	if ($matches) {
	    Test::More::pass($testname);
	} else {
	    failed_long_data($got, $expected, $testname, $suffix);
	}
    }
}

if (!eval {
    require Test::Differences;
    import Test::Differences;
    1;
}) {
    *eq_or_diff = sub {
	my($a, $b, $info) = @_;
	local $Test::Builder::Level = $Test::Builder::Level+1;

    SKIP: {
	    $@ = "";
	    eval {
		no warnings 'numeric'; # cease Argument "2.121_08" isn't numeric in subroutine entry
		require Data::Dumper;
		Data::Dumper->VERSION(2.12); # Sortkeys
	    };
	    if ($@) {
		Test::More::skip("Need recent Data::Dumper (2.12, Sortkeys)", 1);
	    }

	    local $Data::Dumper::Sortkeys = $Data::Dumper::Sortkeys = 1;
	    Test::More::is(Data::Dumper->new([$a],[])->Useqq(1)->Dump,
			   Data::Dumper->new([$b],[])->Useqq(1)->Dump,
			   $info);
	}
    };
}

1;
