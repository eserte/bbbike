# -*- perl -*-

#
# $Id: BBBikeTest.pm,v 1.38 2008/02/20 23:04:06 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004,2006,2008 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeTest;

use vars qw(@opt_vars);
BEGIN {
    @opt_vars = qw($logfile $do_xxx $do_display $pdf_prog $debug
		   $cgiurl $cgidir $htmldir $mapserverurl $wapurl
		  );
}

use strict;
use vars qw(@EXPORT);
use vars (@opt_vars);
use vars qw($can_tidy $can_xmllint $shown_gpx_schema_warning $shown_kml_schema_warning);

use vars qw($BBBIKE_TEST_CGIDIR
	    $BBBIKE_TEST_CGIURL
	    $BBBIKE_TEST_HTMLDIR
	    $BBBIKE_TEST_MAPSERVERURL
	    $BBBIKE_TEST_WAPURL
	  );

use base qw(Exporter);

use File::Basename qw(dirname);
use File::Spec     qw();

use BBBikeUtil qw(is_in_path);

@EXPORT = (qw(get_std_opts set_user_agent do_display tidy_check
	      xmllint_string xmllint_file gpxlint_string gpxlint_file kmllint_string
	      eq_or_diff is_long_data like_long_data unlike_long_data
	      like_html unlike_html),
	   @opt_vars);

# Old logfile
#$logfile = "$ENV{HOME}/www/log/radzeit.de-access_log";
# New logfile since 2004-09-28 ca.
#$logfile = "$ENV{HOME}/www/log/radzeit.combined_log";
# Again the old name since 2005-06-XX ca.
#$logfile = "$ENV{HOME}/www/log/radzeit.de-access_log";
# New server since 2009-12-XX
$logfile = "$ENV{HOME}/www/log/bbbike.hosteurope/bbbike.de_access.log";

# load test config file
my $config_file = dirname(File::Spec->rel2abs(__FILE__)) . "/test.config";
#$config_file.=".example";#XXX!
if (-e $config_file) {
    require $config_file;
}

if ($BBBIKE_TEST_CGIDIR) {
    $cgidir = $BBBIKE_TEST_CGIDIR;
} elsif (defined $ENV{BBBIKE_TEST_CGIDIR}) {
    $cgidir = $ENV{BBBIKE_TEST_CGIDIR};
} else {
    $cgidir = 'http://localhost/bbbike/cgi';
}

if ($BBBIKE_TEST_CGIURL) {
    $cgiurl = $BBBIKE_TEST_CGIURL;
} elsif (defined $ENV{BBBIKE_TEST_CGIURL}) {
    $cgiurl = $ENV{BBBIKE_TEST_CGIURL};
} elsif ($cgidir) {
    $cgiurl = "$cgidir/bbbike.cgi";
} else {
    $cgiurl = 'http://localhost/bbbike/cgi/bbbike.cgi';
}

if ($BBBIKE_TEST_HTMLDIR) {
    $htmldir = $BBBIKE_TEST_HTMLDIR;
} elsif (defined $ENV{BBBIKE_TEST_HTMLDIR}) {
    $htmldir = $ENV{BBBIKE_TEST_HTMLDIR};
} else {
    $htmldir = dirname $cgidir;
}

if ($BBBIKE_TEST_MAPSERVERURL) {
    $mapserverurl = $BBBIKE_TEST_MAPSERVERURL;
} elsif (defined $ENV{BBBIKE_TEST_MAPSERVERURL}) {
    $mapserverurl = $ENV{BBBIKE_TEST_MAPSERVERURL};
} else {
    $mapserverurl = "http://localhost/cgi-bin/mapserv";
}

if ($BBBIKE_TEST_WAPURL) {
    $wapurl = $BBBIKE_TEST_WAPURL;
} elsif (defined $ENV{BBBIKE_TEST_WAPURL}) {
    $wapurl = $ENV{BBBIKE_TEST_WAPURL};
} elsif ($cgidir) {
    $wapurl = "$cgidir/wapbbbike.cgi";
} else {
    $wapurl = "http://localhost/bbbike/cgi/wapbbbike.cgi";
}

sub get_std_opts {
    my(@what) = @_;
    my %std_opts = ("cgiurl=s"  => \$cgiurl,
		    "cgidir=s"  => \$cgidir,
		    "htmldir=s" => \$htmldir,
		    "mapserverurl=s" => \$mapserverurl,
		    "wapurl=s"  => \$wapurl,

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
# with proper extension or if the fallback viewer (display or xv) may determine the type
# by magic.
# The pseudo image format "http.html" can be used to start a WWW browser.
sub do_display {
    my($filename_or_scalar, $imagetype) = @_;

    my $filename;
    if (ref $filename_or_scalar eq 'SCALAR') {
	require File::Temp;
	my $fh;
	($fh, $filename) = File::Temp::tempfile(SUFFIX => (defined $imagetype ? ".$imagetype" : ".image"),
						UNLINK => !$debug,
					       );
	print $fh $$filename_or_scalar;
    } else {
	$filename = $filename_or_scalar;
    }

    if (!defined $imagetype && $filename =~ m{\.([^\.]+)}) {
	$imagetype = $1;
    }
    $imagetype = "" if !defined $imagetype; # avoid warnings

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
	if (eval { require WWWBrowser; 1}) {
	    require File::Temp;
	    my($ofh,$ofilename) = File::Temp::tempfile(SUFFIX => ".html",
						       UNLINK => !$debug,
						      );
	    {
		open my $ifh, $filename or die "Can't open $filename: $!";
		my $in_http_header = 1;
		while(<$ifh>) {
		    if ($in_http_header) {
			if (/^\r?$/) {
			    $in_http_header = 0;
			    local $/ = \8192;
			}
			next;
		    }
		    print $ofh $_;
		}
	    }
	    close $ofh
		or die "While closing $ofilename: $!";
	    WWWBrowser::start_browser("file:$ofilename");
	} else {
	    warn "Can't find a browser to display $filename";
	}
    } else {
	if (is_in_path("xv") && $imagetype ne "wbmp") {
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
						  UNLINK => 0);
	my(undef, $errfilename) = File::Temp::tempfile(SUFFIX => "_tidy.err",
						       UNLINK => 1);
	if ($args{-charset}) {
	    eval 'binmode($fh, ":encoding($args{-charset})");';
	    warn $@ if $@;
	}
	print $fh $content;
	system("tidy", "-f", $errfilename, "-q", "-e", $filename);
	my $ok = Test::More::cmp_ok($?>>8, "<", 2, $test_name)
	    or do {
		my $diag = "";
		if ($args{-uri}) {
		    $diag .= "$args{-uri}: ";
		}
		open(DIAG, $errfilename)
		    or die "Can't $errfilename: $!";
		local $/ = undef;
		$diag .= <DIAG>;
		close DIAG;
		$diag .= "\nHTML file is in: $filename\n";
		Test::More::diag($diag);
	    };
	if ($ok) {
	    unlink $filename;
	}
	unlink $errfilename;
	$ok;
    }
}

# only usable with Test::More, generates one test
sub xmllint_string {
    my($content, $test_name, %args) = @_;
    my $schema = delete $args{-schema};
    local $Test::Builder::Level = $Test::Builder::Level+1;
 SKIP: {
	my $no_of_tests = 1;
	if (!defined $can_xmllint) {
	    $can_xmllint = is_in_path("xmllint");
	}
	Test::More::skip("xmllint is not available", $no_of_tests) if !$can_xmllint;

	$test_name = "xmllint check" if !$test_name;

	require File::Temp;
	my($errfh,$errfile) = File::Temp::tempfile(SUFFIX => ".log",
						   UNLINK => 1);
	my $cmd = "xmllint --noout";
	if ($schema) {
	    $cmd .= " --schema $schema";
	}
	$cmd .= " - ";
	if ($^O ne 'MSWin32') {
	    $cmd .= "2>$errfile";
	}
	warn $cmd if $debug;
	open(my $XMLLINT, "| $cmd")
	    or die "Error while opening xmllint: $!";
	binmode $XMLLINT;
	print $XMLLINT $content; # do not check for die
	close $XMLLINT; # do not check for die, check $? later
	my $ok = Test::More::is($?, 0, $test_name) or do {
	    seek($errfh,0,0);
	    my $errorcontent = do { local $/; <$errfh> };
	    $content = "Errors:\n$errorcontent\nXML:\n$content";
	    if (length($content) > 1024) {
		require File::Temp;
		my($tempfh,$tempfile) = File::Temp::tempfile(SUFFIX => ".xml",
							     UNLINK => 0);
		print $tempfh $content;
		close $tempfh;
		Test::More::diag("Please look at <$tempfile> for the tested XML content");
	    } else {
		Test::More::diag($content);
	    }
	};
	unlink $errfile;
	$ok;
    }
}

# only usable with Test::More, generates one test
sub xmllint_file {
    my($file, $test_name, %args) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    my $string = do { open my $fh, $file or die "Can't open $file: $!"; local $/; <$fh> };
    xmllint_string($string, $test_name, %args);
}

# only usable with Test::More, generates one test
sub gpxlint_string {
    my($content, $test_name, %args) = @_;
    my $schema_version = delete $args{schema_version} || '1.1';
    local $Test::Builder::Level = $Test::Builder::Level+1;
    my $gpx_schema = File::Spec->catfile(dirname(dirname(File::Spec->rel2abs(__FILE__))),
					 "misc",
					 ($schema_version eq '1.1' ? 'gpx.xsd' : 'gpx10.xsd')
					);
    if (!-r $gpx_schema) {
	if (!$shown_gpx_schema_warning) {
	    Test::More::diag("GPX schema file <$gpx_schema> not found or not readable, continue with schema-less checks...");
	    $shown_gpx_schema_warning = 1;
	}
	xmllint_string($content, $test_name, %args);
    } else {
	xmllint_string($content, $test_name, %args, -schema => $gpx_schema);
    }
}

# only usable with Test::More, generates one test
sub gpxlint_file {
    my($file, $test_name, %args) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    my $string = do { open my $fh, $file or die "Can't open $file: $!"; local $/; <$fh> };
    gpxlint_string($string, $test_name, %args);
}

# only usable with Test::More, generates one test
sub kmllint_string {
    my($content, $test_name, %args) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    my $kml_schema = File::Spec->catfile(dirname(dirname(File::Spec->rel2abs(__FILE__))),
 					 "misc",
 					 "kml21.xsd");
    if (!-r $kml_schema) {
	if (!$shown_kml_schema_warning) {
	    Test::More::diag("Local KML schema $kml_schema cannot be found, fallback to remote schema...");
	    $shown_kml_schema_warning = 1;
	}
	$kml_schema = "http://code.google.com/apis/kml/schema/kml21.xsd";
    }
    xmllint_string($content, $test_name, %args, -schema => $kml_schema);
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

sub like_html {
    my($got, $expected, $testname) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    like_long_data($got, $expected, $testname, '.html');
}

sub unlike_html {
    my($got, $expected, $testname) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    unlike_long_data($got, $expected, $testname, '.html');
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
