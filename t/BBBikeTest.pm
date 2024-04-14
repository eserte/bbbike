# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2004,2006,2008,2012,2013,2014,2015,2016,2017,2018,2019,2020,2021,2023,2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

package BBBikeTest;

use vars qw(@opt_vars);
BEGIN {
    @opt_vars = qw($logfile $do_xxx $do_display $pdf_prog $debug
		   $cgiurl $cgidir $htmldir $mapserverurl $mapserverstaticurl $wapurl
		   $simulate_skips
		  );
}

use strict;
use vars qw(@EXPORT);
use vars (@opt_vars);
use vars qw($can_tidy $can_xmllint $shown_gpx_schema_warning $shown_kml_schema_warning $can_pdfinfo);

use vars qw($BBBIKE_TEST_CGIDIR
	    $BBBIKE_TEST_CGIURL
	    $BBBIKE_TEST_HTMLDIR
	    $BBBIKE_TEST_MAPSERVERURL
	    $BBBIKE_TEST_MAPSERVERSTATICURL
	    $BBBIKE_TEST_WAPURL
	  );

use base 'Test::Builder::Module';

use Exporter 'import';

use File::Basename qw(dirname);
use File::Spec     qw();
use Cwd            qw(realpath);

BEGIN {
    my $bbbike_root = realpath(dirname(__FILE__) . "/..");
    no warnings 'uninitialized';
    if (!grep { -d $_ && realpath($_) eq $bbbike_root } @INC) {
        push @INC, $bbbike_root;
    }
}

use BBBikeBuildUtil qw(get_pmake);
use BBBikeProcUtil qw(double_forked_exec);
use BBBikeUtil qw(bbbike_root is_in_path);

@EXPORT = (qw(get_std_opts set_user_agent do_display tidy_check
	      libxml_parse_html libxml_parse_html_or_skip
	      xmllint_string xmllint_file gpxlint_string gpxlint_file kmllint_string xml_eq
	      validate_bbbikecgires_xml_string validate_bbbikecgires_yaml_string validate_bbbikecgires_json_string validate_bbbikecgires_data
	      eq_or_diff is_long_data like_long_data unlike_long_data
	      like_html unlike_html is_float is_number isnt_number using_bbbike_test_cgi using_bbbike_test_data
	      check_cgi_testing check_gui_testing check_network_testing check_devel_cover_testing
	      on_author_system maybe_skip_mail_sending_tests
	      get_pmake image_ok zip_ok create_temporary_content static_url
	      get_cgi_config selenium_diag noskip_diag
	      pdfinfo
	      checkpoint_apache_errorlogs output_apache_errorslogs
	      my_note
	    ),
	   @opt_vars);

$logfile = ($ENV{HOME}||'').'/www/log/bbbike.hosteurope2017/bbbike.de_access.log';

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

if ($BBBIKE_TEST_MAPSERVERSTATICURL) {
    $mapserverstaticurl = $BBBIKE_TEST_MAPSERVERSTATICURL;
} elsif (defined $ENV{BBBIKE_TEST_MAPSERVERSTATICURL}) {
    $mapserverstaticurl = $ENV{BBBIKE_TEST_MAPSERVERSTATICURL};
} else {
    if ($htmldir =~ m{/bbbike$}) {
	$mapserverstaticurl = "$htmldir/mapserver";
    } else {
	$mapserverstaticurl = dirname($htmldir) . '/mapserver'; # typically -> http://$HOSTNAME/mapserver
    }
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
		    "simulate-skips!" => \$simulate_skips,
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
    my $test_ua = 'BBBike-Test/1.0';
    if ($ua->isa('WWW::Mechanize::PhantomJS')) {
	$ua->eval_in_phantomjs(<<'JS', $test_ua);
    this.settings.userAgent= arguments[0]
JS
	# XXX equivalent to env_proxy missing
    } else {
	$ua->agent($test_ua);
	$ua->env_proxy;
    }
}

# $htmldir is actually a mis-namer
sub static_url () { $htmldir }

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
	if (is_in_path("display")) {
	    double_forked_exec('display', $filename);
	} elsif (is_in_path('eog')) {
	    double_forked_exec('eog', $filename);
	} else {
	    warn "Can't display $filename";
	}
    } elsif ($imagetype eq 'pdf') {
	if (defined $pdf_prog) {
	    double_forked_exec($pdf_prog, $filename);
	} elsif (is_in_path("evince")) {
	    double_forked_exec('xpdf', $filename);
	} elsif (is_in_path("xpdf")) {
	    double_forked_exec('xpdf', $filename);
	} elsif ($^O eq 'MSWin32') {
	    system($filename);
	} elsif ($^O eq 'darwin') {
	    system("open", $filename); # runs in background
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
	    double_forked_exec('xv', $filename);
	} elsif (is_in_path("display")) {
	    double_forked_exec('display', $filename);
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
	Test::More::skip("simulate skips", $no_of_tests) if $simulate_skips;
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

{
    my $p; # cached parser

    sub libxml_parse_html ($) {
	return undef if defined $p && !$p;

	my $content = shift;

	$p = eval {
	    require XML::LibXML;
	    XML::LibXML->new;
	};
	if (!$p) {
	    $p = 0; # false but defined
	    return undef;
	}

	$p->parse_html_string($content);
    }

    sub libxml_parse_html_or_skip ($$) {
	my($skip_count, $content) = @_;

	if ($skip_count !~ m{^\d+$}) {
	    die "'$skip_count' does not look like a skip count";
	}

	Test::More::skip("simulate skips", $skip_count) if $simulate_skips;

	my $doc = libxml_parse_html $content;
	Test::More::skip("Cannot parse content as html", $skip_count) if !$doc;
	$doc;
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
	Test::More::skip("simulate skips", $no_of_tests) if $simulate_skips;
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

my $warned_no_XML_LibXML;
# only usable with Test::More, generates one test
sub gpxlint_string {
    my($content, $test_name, %args) = @_;

    my $schema_version;
    if (defined $args{schema_version}) {
	$schema_version = delete $args{schema_version};
    } else {
	# Try to autodetect the GPX schema version.
	my $root_ns;
	if (!eval {
	    require XML::LibXML;
	    $root_ns = XML::LibXML->new->parse_string($content)->documentElement->namespaceURI;
	}) {
	    my($err) = $@ =~ m{^(.*)}; # only first line;
	    if (!$warned_no_XML_LibXML) {
		warn "INFO: cannot detect GPX version using XML::LibXML, using fallback ($err...)\n";
		$warned_no_XML_LibXML = 1;
	    }
	    ($root_ns) = $content =~ m{xmlns="(.*?)"};
	}
	if ($root_ns) {
	    if ($root_ns =~ m{^\Qhttp://www.topografix.com/GPX/\E(\d+)/(\d+)$}) {
		$schema_version = "$1.$2";
	    }
	}
	if (!defined $schema_version) {
	    warn "INFO: cannot auto-detect GPX version, fallback to 1.1 (may be wrong)\n";
	    $schema_version = '1.1';
	}
    }

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

# generates one test
sub xml_eq {
    my($left, $right, $test_name, %args) = @_;
    my $ignore = delete $args{ignore};
    die 'Unhandled arguments: ' . join(' ', %args) if %args;

    local $Test::Builder::Level = $Test::Builder::Level+1;
 SKIP: {
	my $no_of_tests = 1;
	Test::More::skip("Needs XML::LibXML for normalization", $no_of_tests)
		if !eval { require XML::LibXML; 1 };
	for ($left, $right) {
	    my $dom = XML::LibXML->new->parse_string($_);
	    if ($ignore) {
		for my $ignore_xpath (@$ignore) {
		    $_->unbindNode for $dom->findnodes($ignore_xpath);
		}
	    }
	    $_ = $dom->toStringC14N;
	}
	eq_or_diff($left, $right, $test_name);
    }
}

{
    my $schema_file;
    # only usable with Test::More, generates one test
    sub validate_bbbikecgires_xml_string {
	my($content, $test_name) = @_;
	local $Test::Builder::Level = $Test::Builder::Level+1;
    SKIP: {
	    Test::More::skip("simulate skips", 1) if $simulate_skips;
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

	    if (!$schema_file) {
		Test::More::skip("skipping schema tests", 1);
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

{
    my $schema;

    sub _get_kwalify_schema {
	if (!defined $schema) {
	    my $schema_file = "$testdir/../misc/bbbikecgires.kwalify";
	    $schema = 0; # false but defined
	    if (eval { require Kwalify; 1 }) {
		if (eval { require BBBikeYAML; 1 }) {
		    $schema = BBBikeYAML::LoadFile($schema_file);
		} else {
		    Test::More::diag("BBBikeYAML (uses YAML::XS) needed for loading $schema_file, but cannot be loaded.");
		}
	    } else {
		Test::More::diag("Kwalify needed for validating with $schema_file, but not available.");
	    }
	}
	$schema;
    }

    # only usable with Test::More, generates one test
    sub validate_bbbikecgires_data {
	my($data, $test_name) = @_;
	local $Test::Builder::Level = $Test::Builder::Level+1;
      SKIP: {
	  my $schema = _get_kwalify_schema();
	  Test::More::skip("simulate skips", 1) if $simulate_skips;
	  Test::More::skip('schema file not available', 1)
	      if !$schema;

	  if (!eval { Kwalify::validate($schema, $data) }) {
	      Test::More::fail("validation with Kwalify - $test_name");
	      Test::More::diag($@);
	  } else {
	      Test::More::pass("validation with Kwalify - $test_name");
	  }
	}
    }

    # only usable with Test::More, generates one test
    sub validate_bbbikecgires_yaml_string {
	my($content, $test_name) = @_;
	local $Test::Builder::Level = $Test::Builder::Level+1;

      SKIP: {
	  Test::More::skip("simulate skips", 1) if $simulate_skips;
	  Test::More::skip('BBBikeYAML cannot be loaded (YAML::XS not available?)', 1)
	      if !eval { require BBBikeYAML; 1 };

	  my $data = eval { BBBikeYAML::Load($content) };
	  if (!$data) {
	      Test::More::fail("Can't load YAML content: $@");
	  } else {
	      validate_bbbikecgires_data($data, $test_name);
	  }
	}
    }

    # only usable with Test::More, generates one test
    sub validate_bbbikecgires_json_string {
	my($content, $test_name) = @_;
	local $Test::Builder::Level = $Test::Builder::Level+1;

      SKIP: {
	  Test::More::skip("simulate skips", 1) if $simulate_skips;
	  Test::More::skip('JSON::XS not available', 1)
	      if !eval { require JSON::XS; 1 };

	  my $data = eval { JSON::XS::decode_json($content) };
	  if (!$data) {
	      Test::More::fail("Can't load JSON content: $@");
	  } else {
	      validate_bbbikecgires_data($data, $test_name);
	  }
	}
    }
}

sub _failed_long_data {
    my($got, $expected, $testname, $suffix, $is_negative) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    require File::Temp;
    require Data::Dumper;
    my($fh, $filename) = File::Temp::tempfile(SUFFIX => ".bbbike_test" . ($suffix ? $suffix : ""));
    my $dump;
    my $embedded_testname = defined $testname ? " <$testname>" : "";
    if ($suffix) {
	$dump = $got;
	Test::More::fail("Test$embedded_testname failed, <$expected> " . ($is_negative ? 'unexpected' : 'expected') . ", see <$filename> for got contents");
    } else {
	$dump = Data::Dumper->new([$got, $expected],[qw(got expected)])->Indent(1)->Useqq(0)->Dump;
	Test::More::fail("Test$embedded_testname failed, see <$filename> for more information");
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
	    _failed_long_data($got, $expected, $testname, $suffix, 0);
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
	    _failed_long_data($got, $expected, $testname, $suffix, 0);
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
	    _failed_long_data($got, $expected, $testname, $suffix, 1);
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
	    Test::More::skip("simulate skips", 1) if $simulate_skips;
	    Test::More::is_deeply($a, $b, $info);
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

sub _number_check {
    my($val, $is, $testname) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 2;
 SKIP: {
	Test::More::skip("YAML::XS required for is_number", 1)
		if !eval { require YAML::XS; 1 };
	my $serialized = YAML::XS::Dump([$val]);
	$serialized =~ s{\A---\n- }{};
	$serialized =~ s{\n\z}{};
	if ($is) {
	    Test::More::is($serialized, $val, $testname);
	} else {
	    Test::More::isnt($serialized, $val, $testname);
	}
    }
}

sub is_number ($;$) {
    my($val, $testname) = @_;
    _number_check($val, 1, $testname);
}

sub isnt_number ($;$) {
    my($val, $testname) = @_;
    _number_check($val, 0, $testname);
}

sub _update_bbbike_test_data () {
    my $make = get_pmake;

    local $ENV{MAKEFLAGS}; # protect from gnu make brain damage (MAKEFLAGS is set to "w" in recursive calls)

    my $lock_fh;
    eval {
	require Fcntl;
	open $lock_fh, "$testdir/data-test/BSDmakefile"
	    or die "Opening BSDmakefile failed: $!";
	flock $lock_fh, Fcntl::LOCK_EX
	    or die "Locking failed: $!";
    };
    warn "Problems while acquire a lock: $@\n" if $@;

    # -f BSDmakefile needed for old pmake (which may be found in Debian)
    my $cmd = "cd $testdir/data-test && $make -f BSDmakefile PERL=$^X MISCSRCDIR=" . bbbike_root . "/miscsrc";
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

sub check_gui_testing () {
    unless ($ENV{BBBIKE_TEST_GUI}) {
	print "1..0 # skip Please set BBBIKE_TEST_GUI to test gui functionality.\n";
	exit 0;
    }
}

sub check_network_testing () {
    if ($ENV{BBBIKE_TEST_NO_NETWORK}) {
	print "1..0 # skip Requested to not run network tests.\n";
	exit 0;
    }
}

sub check_devel_cover_testing () {
    if ($INC{"Devel/Cover.pm"}) {
	print "1..0 # skip Do not run tests under Devel::Cover.\n";
	exit 0;
    }
}

{
    my $fqdn;
    sub _get_fqdn () {
	return $ENV{BBBIKE_SIMULATE_FQDN} if $ENV{BBBIKE_SIMULATE_FQDN};
	return $fqdn if defined $fqdn;
	require Sys::Hostname;
	my $_fqdn = Sys::Hostname::hostname();
	if ($_fqdn !~ m{\.}) {
	    # short hostname, probably on Linux
	    chomp($_fqdn = `hostname -f`);
	    if (!length $_fqdn) {
		my $warn_msg = "Cannot determine fqdn of this host";
		if (defined &Test::More::diag) {
		    Test::More::diag($warn_msg);
		} else {
		    warn "$warn_msg\n";
		}
		return undef;
	    }
	}
	$fqdn = $_fqdn;
	return $fqdn;
    }
}

sub _is_author_system () {
    my $fqdn = _get_fqdn;
    defined $fqdn && $fqdn =~ m{\.(rezic|herceg)\.de$},
}

sub _is_live_system () {
    my $fqdn = _get_fqdn;
    defined $fqdn && (
		      $fqdn =~ m{^lvps.*\Q.dedicated.hosteurope.de\E$}
		     );
}

sub on_author_system () {
    if (!_is_author_system) {
	print "1..0 # skip Live server tests only activated on author systems.\n";
	exit 0;
    }
}

sub maybe_skip_mail_sending_tests (;$) {
    my $test_no = shift || 1;
    Test::More::skip("Do not run mail-sending tests here", $test_no)
	    if !_is_author_system && !_is_live_system;
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

    Test::More::skip("simulate skips", 2) if $simulate_skips;

    my $fails = 0;

    if (0) { # some png images cannot be read (see t/images.t), wbmp support missing
    SKIP: {
	    Test::More::skip("Imager does not handle .wbmp files yet", 2)
		    if $in =~ /\.wbmp$/;
	    my $mod = $in =~ /\.xpm$/ ? 'Imager::Image::Xpm' : $in =~ /\.xbm/ ? 'Imager::Image::Xbm' : 'Imager';
	    Test::More::skip("$mod needed for better image testing", 2)
		    if !eval qq{ require $mod; 1 };
	    my $full_testlabel = (ref $in ? "content" : "file '$in'") . "$testlabel";
	    my $img = $mod->new((ref $in ? (data => $$in) : (file => $in)));
	    Test::More::ok($img, "load ok - $full_testlabel")
		    or Test::More::diag(Imager->errstr());
	    Test::More::skip("image needed for next test", 1) if !$img;
	    Test::More::cmp_ok($img->getwidth, ">", 0, "image has a width - $full_testlabel");
	}
    } elsif (0) { # anytopnm does not return with non-zero on problems
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
	    Test::More::skip("Image::Info 1.31 or better needed for better image testing", 2)
		    if !eval { require Image::Info; Image::Info->VERSION(1.31) }; # support for .ico files and better .xbm detection
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
				  ICO  => (is_in_path("winicontopam") ? "winicontopam" : "winicontoppm"),
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

# largely taken from examples/zipcheck.pl in Archive-Zip
sub zip_ok {
    my($zip_name, %args) = @_;

    my $tb = __PACKAGE__->builder;

    require Archive::Zip;

    # instead of stack dump:
    Archive::Zip::setErrorHandler( sub { warn shift() } );

    my $nullFileName = File::Spec->devnull;
    my $zip = Archive::Zip->new;
    eval {
	my $status = $zip->read($zip_name);
	die "Status while reading $zip_name is not AZ_OK" if $status != Archive::Zip::AZ_OK();
    };
    if ($@) {
	$tb->ok(0, "Checking $zip_name in read phase");
	$tb->diag($@);
	if ($^O ne 'MSWin32') { # pipe open might be unimplemented, no ls available
	    my $ls = do {
		open my $fh, '-|', 'ls', '-al', $zip_name
		    or die $!;
		local $/;
		<$fh>;
	    };
	    $tb->diag($ls);
	}
	return 0;
    }

    my %member_checks;
    if ($args{-memberchecks}) {
	%member_checks = map {($_,1)} @{$args{-memberchecks}};
    }

    eval {
	for my $member ($zip->members) {
	    my $buffer;

	    # workaround for a bug in perl 5.8.x: a warning
	    # "Use of uninitialized value in open at .../src/bbbike/t/BBBikeTest.pm line 914."
	    # is emitted for all but the first iteration
	    if ($] <= 5.010) { $buffer = '' }

	    open my $fh, ">", \$buffer or die;

	    if ($member->can('isSymbolicLink') # undocumented, at least until 1.86
		&& $member->isSymbolicLink) {
		# extractToFileHandle would create the symlink in this case, something we don't want to do here
		next;
	    }

	    my $status = $member->extractToFileHandle($fh);
	    if ($status != Archive::Zip::AZ_OK()) {
		die "Extracting " . $member->fileName() . " from $zip_name failed";
	    }
	    for my $member_check (keys %member_checks) {
		if ($member->fileName =~ $member_check) {
		    delete $member_checks{$member_check};
		}
	    }
	}
    };
    if ($@) {
	$tb->ok(0, "Test extracting members from $zip_name");
	$tb->diag($@);
	return 0;
    }

    if (keys %member_checks) {
	$tb->ok(0, "Member checks in $zip_name are OK");
	$tb->diag("The following file(s) are missing: " . join(", ", sort keys %member_checks));
	return 0;
    }

    $tb->ok(1, "Zip file $zip_name looks OK");
    1;
}

sub create_temporary_content ($;%) {
    my($content, %file_temp_args) = @_;
    my $encoding = delete $file_temp_args{encoding};
    require File::Temp;
    my($tmpfh, $tmpfile) = File::Temp::tempfile(UNLINK => 1, SUFFIX => "_bbbike_test.tmp", %file_temp_args);
    if ($encoding) {
	binmode $tmpfh, ":encoding($encoding)";
    }
    print $tmpfh $content;
    close $tmpfh
	or die "Failed to create temporary file: $!";
    ($tmpfh, $tmpfile);
}

sub get_cgi_config (;@) {
    my(%opts) = @_;
    my $_cgiurl = delete $opts{cgiurl} || $cgiurl;
    my $ua = delete $opts{ua};
    if (!$ua) {
	require LWP::UserAgent;
	$ua = LWP::UserAgent->new;
	$ua->default_header('Accept-Encoding' => scalar HTTP::Message::decodable());
	set_user_agent($ua);
    }
    my $respref = delete $opts{resp};
    die "Unhandled options: " . join(" ", %opts) if %opts;

    my $decode_json = eval { require JSON::XS; \&JSON::XS::decode_json };
    $decode_json    = eval { require JSON::PP; \&JSON::PP::decode_json } if !$decode_json;
    if (!$decode_json) {
	die "Neither JSON::XS nor JSON::PP available, cannot decode bbbike.cgi config";
    }

    my $url = $_cgiurl . "?api=config";
    my $resp = $ua->get($url);
    if ($respref) { $$respref = $resp }
    my $data = $decode_json->($resp->decoded_content(charset => 'none'));
    $data;
}

sub selenium_diag () {
    Test::More::diag(<<EOF);

ERROR: Please remember to start the Selenium server first, e.g.

    java -jar ~/Downloads/selenium-server-standalone-3.0.1.jar

or an older version (selenium 3 requires java 8):

    java -jar ~/Downloads/selenium-server-standalone-2.53.1.jar

To download selenium check

    http://www.seleniumhq.org/download/

EOF
}

sub noskip_diag () {
    require Config;
    Test::More::diag(<<EOF);

There were skips because of missing modules or other prerequisites. You can
rerun this test with

    $Config::Config{scriptdir}/prove $0 :: -noskip

or

    $^X $0 -noskip

to see failing tests because of these modules.
EOF
}

sub pdfinfo ($) {
    my($pdffile) = @_;
    if (!defined $can_pdfinfo) {
	$can_pdfinfo = is_in_path('pdfinfo');
    }
    return if !$can_pdfinfo;

    my @cmd = ('pdfinfo', $pdffile);
    my %info;
    open my $fh, "-|", @cmd
	or die "Error running @cmd: $!";
    while(<$fh>) {
	chomp;
	my($k,$v) = split /:\s+/, $_, 2;
	$info{$k} = $v;
    }
    close $fh
	or die "Error running @cmd: $!";

    \%info;
}

{
    # Show apache errorlog contents on failures.
    #
    # Usually used like this:
    #
    #    checkpoint_apache_errorlogs;
    #    my $resp = $ua->get(...); # a possibly failing LWP call
    #    $resp->is_success or output_apache_errorslogs;
    #
    # This of course only works if the current user has read
    # access to the apache logs, which is often not the case
    # (e.g. on debian systems only members of the adm group
    # may read the logs)
    #
    # Also this does not work if the logfiles are named
    # differently than <something>error.log, or are in a
    # non-default location (on debian-like systems in
    # /var/log/apache2).

    my %seek_pos;
    my @remember_checkpoint_errors;

    sub checkpoint_apache_errorlogs () {
	%seek_pos = ();
	@remember_checkpoint_errors = ();
	my @log_files;
	require File::Glob;
	if ($^O eq 'linux') { # actually matches only for Debian-like distributions
	    @log_files = File::Glob::bsd_glob("/var/log/apache2/*error.log");
	} elsif ($^O eq 'freebsd') {
	    @log_files = File::Glob::bsd_glob("/var/log/httpd*error.log");
	} else {
	    push @remember_checkpoint_errors, "No apache errorlog checkpoint support for $^O";
	    return;
	}
	if (!@log_files) {
	    push @remember_checkpoint_errors, "Cannot find any matching apache errorlogs";
	} else {
	    for my $log_file (@log_files) {
		$seek_pos{$log_file} = -s $log_file;
	    }
	}
    }

    sub output_apache_errorslogs () {
	if (@remember_checkpoint_errors) {
	    Test::More::diag(join("\n", @remember_checkpoint_errors));
	    return;
	}

	for my $log_file (keys %seek_pos) {
	    if (-e $log_file && -s $log_file > $seek_pos{$log_file}) {
		if (open my $fh, "<", $log_file) {
		    if (seek $fh, $seek_pos{$log_file}, 0) {
			local $/ = undef;
			my $log = <$fh>;
			Test::More::diag("New contents in $log_file:\n$log\n----------------------------------------------------------------------");
		    } else {
			Test::More::diag("Cannot seek in $log_file: $!");
		    }
		} else {
		    Test::More::diag("Cannot open $log_file: $!");
		}
	    }
	}
    }
}

sub my_note (@) {
    my(@notes) = @_;
    if (defined &Test::More::note) {
	Test::More::note(@notes);
    } else {
	Test::More::diag(@notes);
    }
}

# Report values on failures and unclean exits. Especially useful if
# random values are used and unclean exits are possible. (E.g.
# the pdfinfo function may fail with a die(), which is an unclean exit)
#
# A little bit complicated. We have to detect
# - normal exits (through the use of an END block) --- normally no debugging required
# - a failed test suite (through Test::Builder::is_passing)
# - and provide the possibility to supply a debug variable reference, to always run the debugging output
{
    package
	BBBikeTest::Cleanup;
    sub new { bless $_[1], $_[0] }
    sub DESTROY { $_[0]->() }
}
{
    my $normal_exit;
    END { $normal_exit = 1 }
    my @cleanups;
    sub report_on_error {
	my $debug_var_ref = \0;
	if (ref $_[0] eq 'HASH') {
	    my(%opts) = %{ shift @_ };
	    $debug_var_ref = delete $opts{debug};
	    die "debug must be a SCALAR ref" if ref $debug_var_ref ne 'SCALAR';
	    die "Unhandled options: " . join(" ", %opts) if %opts;
	}
	my(%kv) = @_;
	my $cleanup = BBBikeTest::Cleanup->new(sub {
						   if ($$debug_var_ref || !Test::Builder->new->is_passing || !$normal_exit) {
						       Test::More::diag(Test::More::explain(\%kv));
						   }
					       });
	push @cleanups, $cleanup;
    }
}

1;
