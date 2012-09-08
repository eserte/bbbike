# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2004,2006,2008,2012 Slaven Rezic. All rights reserved.
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
	      validate_bbbikecgires_xml_string
	      eq_or_diff is_long_data like_long_data unlike_long_data
	      like_html unlike_html is_float using_bbbike_test_cgi using_bbbike_test_data check_cgi_testing
	      get_pmake image_ok
	    ),
	   @opt_vars);

$logfile = ($ENV{HOME}||'').'/www/log/bbbike.hosteurope2012/bbbike.de_access.log';

my $testdir = dirname(File::Spec->rel2abs(__FILE__));

# load test config file
my $config_file = "$testdir/test.config";
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
	} elsif ($^O eq 'MSWin32') {
	    system($filename);
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
	} elsif ($^O eq 'MSWin32') {
	    system($filename);
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
    $test_name = "xmllint check" if !$test_name;
    local $Test::Builder::Level = $Test::Builder::Level+1;
 SKIP: {
	my $no_of_tests = 1;
	if (eval {
	    require XML::LibXML;
	    if ($schema && $schema =~ m{^https://}) {
		require LWP::UserAgent;
	    }
	    1;
	}) {
	    _xmllint_string_with_XML_LibXML($content, $test_name, %args, -schema => $schema);
	} else {
	    if (!defined $can_xmllint) {
		$can_xmllint = is_in_path("xmllint");
	    }
	    if ($can_xmllint) {
		_xmllint_string_with_xmllint($content, $test_name, %args, -schema => $schema);
	    } else {
		Test::More::skip("xmllint is not available", $no_of_tests) if !$can_xmllint;
	    }
	}
    }
}

sub _xmllint_string_with_XML_LibXML {
    my($content, $test_name, %args) = @_;
    my $schema = delete $args{-schema};
    local $Test::Builder::Level = $Test::Builder::Level+1;

    my @errors;

    my $p = XML::LibXML->new;
    my $doc = eval { $p->parse_string($content) };
    if (!$doc || $@) {
	push @errors, "XML document is not well-formed:\n$@";
    } elsif ($schema) {
	my @schema_args;
	if ($schema =~ m{^https://}) {
	    my $ua = LWP::UserAgent->new;
	    my $resp = $ua->get($schema);
	    if (!$resp->is_success) {
		push @errors, "Can't fetch $schema with LWP: " . $resp->message;
	    } else {
		@schema_args = (string => $resp->decoded_content);
	    }
	} else {
	    @schema_args = (location => $schema);
	}
	if (@schema_args) {
	    my $xmlschema = XML::LibXML::Schema->new(@schema_args);
	    if (!eval { $xmlschema->validate($doc); 1 }) {
		push @errors, "XML document has validation errors:\n$@";
	    }
	}
    }

    my $ok = Test::More::ok(!@errors, $test_name) or do {
	my $diag = "Errors:\n" . join("\n", @errors) . "\nXML:\n" . $content;
	if (length $diag > 1024) {
	    require File::Temp;
	    my($tempfh,$tempfile) = File::Temp::tempfile(SUFFIX => ".xml",
							 UNLINK => 0);
	    print $tempfh $diag;
	    close $tempfh;
	    Test::More::diag("Please look at <$tempfile> for the tested XML content");
	} else {
	    Test::More::diag($diag);
	}
    };
    $ok;
}

sub _xmllint_string_with_xmllint {
    my($content, $test_name, %args) = @_;
    my $schema = delete $args{-schema};
    local $Test::Builder::Level = $Test::Builder::Level+1;

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
	undef $gpx_schema;
    }
    xmllint_string($content, $test_name, %args, ($gpx_schema ? (-schema => $gpx_schema) : ()));
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
	if (0) {
	    # since 2012-02-28 the schema file is located on a https URL
	    # https://developers.google.com/kml/schema/kml21.xsd
	    # which xmllint cannot handle
	    if (!$shown_kml_schema_warning) {
		Test::More::diag("Local KML schema $kml_schema cannot be found, continue with schema-less checks...");
		$shown_kml_schema_warning = 1;
	    }
	    undef $kml_schema;
	} else {
	    if (!$shown_kml_schema_warning) {
		Test::More::diag("Local KML schema $kml_schema cannot be found, fallback to remote schema...");
		$shown_kml_schema_warning = 1;
	    }
	    ## The old location, now a redirect:
	    #$kml_schema = "http://code.google.com/apis/kml/schema/kml21.xsd";
	    ## Use the redirected location, so the heuristics can detect that
	    ## this a https URL is used.
	    $kml_schema = "https://developers.google.com/kml/schema/kml21.xsd";
	}
    }
    xmllint_string($content, $test_name, %args, ($kml_schema ? (-schema => $kml_schema) : ()));
}

{
    my $schema_file;
    # only usable with Test::More, generates one test
    sub validate_bbbikecgires_xml_string {
	my($content, $test_name) = @_;
    SKIP: {
	    if (!defined $schema_file) {
		if (!is_in_path('rnv')) {
		    $schema_file = ''; # defined but false
		    Test::More::skip('rnv needed for XML schema validation, but not available', 1);
		} else {
		    $schema_file = "$testdir/../misc/bbbikecgires.rnc";
		    if (!-r $schema_file) {
			$schema_file = '';
			Test::More::skip("schema file $schema_file is missing", 1);
		    }
		}
	    }

	    require File::Temp;
	    my($tmpfh,$tmpfile) = File::Temp::tempfile(SUFFIX => ".xml", UNLINK => 1)
		or die $!;
	    print $tmpfh $content
		or die $!;
	    close $tmpfh
		or die $!;
	    my @cmd = (qw(rnv -q), $schema_file, $tmpfile);
	    system @cmd;
	    Test::More::ok(($? == 0), $test_name);
	}
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

# Taken from Tk
sub is_float ($$;$) {
    my($value, $expected, $testname) = @_;
    require POSIX;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    my @value    = split /[\s,]+/, $value;
    my @expected = split /[\s,]+/, $expected;
    my $ok = 1;
    for my $i (0 .. $#value) {
	if ($expected[$i] =~ /^[\d+-]/) {
	    if (abs($value[$i]-$expected[$i]) > &POSIX::DBL_EPSILON) {
		$ok = 0;
		last;
	    }
	} else {
	    if ($value[$i] ne $expected[$i]) {
		$ok = 0;
		last;
	    }
	}
    }
    if ($ok) {
	Test::More::pass($testname);
    } else {
	Test::More::is($value, $expected, $testname); # will fail
    }
}

sub get_pmake () {
    $^O =~ m{bsd}i ? "make" : is_in_path("freebsd-make") ? "freebsd-make" : "pmake";
}

sub _update_bbbike_test_data () {
    my $make = get_pmake;
    # -f BSDmakefile needed for old pmake (which may be found in Debian)
    my $cmd = "cd $testdir/data-test && $make -f BSDmakefile";
    system $cmd;
    Test::More::diag("Error running '$cmd', expect test failures...") if $? != 0;
}

# Call this function whenever you make use of the data set in t/data.
sub using_bbbike_test_data () {
    _update_bbbike_test_data;
    # Note: no local here!
    $Strassen::Util::cacheprefix = "test_b_de";
    @Strassen::datadirs = ("$testdir/data-test");
    if (0) { # cease -w
	$Strassen::Util::cacheprefix = $Strassen::Util::cacheprefix;
	@Strassen::datadirs = @Strassen::datadirs;
    }
}

# Call this function whenever you make use of the bbbike-test.cgi script.
sub using_bbbike_test_cgi () {
    _update_bbbike_test_data;
}

sub check_cgi_testing () {
    if ($ENV{BBBIKE_TEST_NO_CGI_TESTS}) {
	print "1..0 # skip Requested to not test cgi functionality.\n";
	exit 0;
    }
}

# Two tests. Call with either an image filename or a stringref
# containing image content. Returns false if any of the tests failed,
# otherwise true.
sub image_ok ($;$) {
    my($in, $testlabel) = @_;
    if ($testlabel) {
	$testlabel = " ($testlabel)";
    } else {
	$testlabel = "";
    }
    local $Test::Builder::Level = $Test::Builder::Level+1;

    my $fails = 0;

    if (0) { # anytopnm does not return with non-zero on problems
    SKIP: {
	    Test::More::skip("IPC::Run needed for better image testing", 2)
		    if !eval { require IPC::Run; 1 };
	    Test::More::skip("anytopnm needed for better image testing", 2)
		    if !is_in_path('anytopnm');
	    
	    my $out;
	    my $full_testlabel = "anytopnm runs fine with image " . (ref $in ? "content" : "file '$in'") . "$testlabel";
	    Test::More::ok(IPC::Run::run(['anytopnm'], '<', $in, '>', \$out), $full_testlabel)
		    or $fails++;
	    Test::More::like(substr($out,0,2), qr{^P\d+}, "Output looks like a netpbm file$testlabel")
		    or $fails++;
	}
    } else {
    SKIP: {
	    Test::More::skip("IPC::Run needed for better image testing", 2)
		    if !eval { require IPC::Run; 1 };
	    Test::More::skip("Image::Info needed for better image testing", 2)
		    if !eval { require Image::Info; 1 };
	    my $ret = Image::Info::image_type($in);
	    if ($ret->{error} && !ref $in && $in =~ m{\.wbmp$}) { # wbmp cannot be detected by Image::Info
		$ret = {file_type => "WBMP" };
	    }
	    if ($ret->{error}) {
		Test::More::fail($ret->{error} . $testlabel) for (1..2);
		$fails = 2;
	    } else {
		my $converter = { GIF  => "giftopnm",
				  PNG  => "pngtopnm",
				  JPEG => "jpegtopnm",
				  ICO  => "winicontoppm",
				  XPM  => "xpmtoppm",
				  XBM  => "xbmtopbm",
				  WBMP => "wbmptopbm",
				}->{$ret->{file_type}};
		if (!$converter) {
		    Test::More::diag("No converter for '$ret->{file_type}' found, fallback to 'anytopnm'");
		    $converter = 'anytopnm';
		}
		Test::More::skip("Converter '$converter' not available", 2)
			if !is_in_path($converter);
		my $out;
		my $full_testlabel = "$converter runs fine with image " . (ref $in ? "content" : "file '$in'") . "$testlabel";
		Test::More::ok(IPC::Run::run([$converter], '<', $in, '2>', '/dev/null', '>', \$out), $full_testlabel)
		    or $fails++;
		Test::More::like(substr($out,0,2), qr{^P\d+}, "Output looks like a netpbm file$testlabel")
		    or $fails++;
	    }
	}
    }

    $fails ? 0 : 1;
}

1;
