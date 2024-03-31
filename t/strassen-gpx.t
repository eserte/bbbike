#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);
use Data::Dumper;
use File::Spec qw();
use File::Temp qw(tempfile tempdir);
use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

if (!eval { require Encode; 1 }) {
    diag "Encode is not available, some failures are expected";
}

use BBBikeTest qw(gpxlint_string eq_or_diff xml_eq);

use GPS::GpsmanData::Any;
use Route;

sub keep_file ($$);
sub load_from_file_and_check ($$);
sub xpath_checks ($$&);

my $v;
my @variants = ("XML::LibXML", "XML::Twig");
my $new_strassen_gpx_tests = 5;
my $tests_per_variant = 176 + $new_strassen_gpx_tests;
my $do_long_tests = !!$ENV{BBBIKE_LONG_TESTS};
my $bbdfile;
my $bbdfile_with_lines = "comments_scenic";
my $do_keep_files;

GetOptions("v" => \$v,
	   "libxml!" => sub {
	       if (!$_[1]) {
		   @variants = grep {!/XML::LibXML/} @variants;
	       }
	   },
	   "twig!" => sub {
	       if (!$_[1]) {
		   @variants = grep {!/XML::Twig/} @variants;
	       }
	   },
	   "long!" => \$do_long_tests,
	   "bbdfile=s" => \$bbdfile,
	   "keepfiles!" => \$do_keep_files,
	  )
    or die <<EOF;
usage: $0 [-v] [-[no]libxml] [-[no]twig] [-long] [-bbdfile file] [-keepfiles]
EOF

if (!defined $bbdfile) {
    $bbdfile = $do_long_tests ? "strassen": "obst";
}

plan tests => 5 + scalar(@variants) * $tests_per_variant;

use Strassen::GPX;
my $s = Strassen::GPX->new;
isa_ok($s, "Strassen::GPX");
isa_ok($s, "Strassen");

my $tempdir;
if ($do_keep_files) {
    $tempdir = tempdir(CLEANUP => 0);
}

my %parsed_rte;
my $do_not_compare_variants = @variants != 2;

for my $use_xml_module (@variants) {
 SKIP: {
	$do_not_compare_variants = 1,
	    skip("$use_xml_module variant missing", $tests_per_variant)
		if !eval qq{ require $use_xml_module; 1 };

	$Strassen::GPX::use_xml_module = $Strassen::GPX::use_xml_module if 0; # peacify -w
	$Strassen::GPX::use_xml_module = $use_xml_module;

	pass("****** Trying $use_xml_module backend ******");

	# Track file
	{
	    # Parsing from string
	    my $gpx_sample = gpx_sample_trk();
	    my $s = Strassen::GPX->new;
	    $s->gpxdata2bbd($gpx_sample);
	    $s->init;
	    my $r = $s->next;
	    is($r->[Strassen::NAME()], "0723", "Check name from track");
	    is(scalar(@{ $r->[Strassen::COORDS()] }), 2);

	    my $xml_res = $s->bbd2gpx;
	    like($xml_res, qr{^<(\?xml|gpx)}, "Looks like XML");
	    gpxlint_string($xml_res, "xmllint for bbd2gpx output (track)");

	    my $s2 = Strassen::GPX->new;
	    $s2->gpxdata2bbd($xml_res);
	    deep_strassen_check($s, $s2, $xml_res);

	    # Parsing from file
	    my($ofh, $ofilename) = tempfile(UNLINK => 1, SUFFIX => "_strassen_gpx.gpx");
	    print $ofh $gpx_sample;
	    close $ofh;

	    my $s3 = Strassen::GPX->new;
	    $s3->gpx2bbd($ofilename);
	    is $s3->file, $ofilename;
	    is "@{[ $s3->dependent_files ]}", $ofilename;
	    is_deeply($s3->data, $s->data, "File loading OK");

	    load_from_file_and_check $ofilename, $s3;

	    # Parsing from string, overriding name and cat
	    my $s4 = Strassen::GPX->new;
	    $s4->gpxdata2bbd($gpx_sample, name => "My Name", cat => "MYCAT");
	    $s4->init;
	    my $r4 = $s4->next;
	    is($r4->[Strassen::NAME()], "My Name", "Check overridden name");
	    is($r4->[Strassen::CAT()], "MYCAT", "Check overriden category");

	    # Parsing from file, overriding name and cat
	    my $s5 = Strassen::GPX->new;
	    $s5->gpx2bbd($ofilename, name => "My Name", cat => "MYCAT");
	    is $s5->file, $ofilename;
	    is "@{[ $s5->dependent_files ]}", $ofilename;
	    is_deeply($s5->data, $s4->data, "Check overriden data in files");

	    # Parsing from string, fallback name, ineffective
	    my $s6 = Strassen::GPX->new;
	    $s6->gpxdata2bbd($gpx_sample, fallbackname => "Fallback name");
	    $s6->init;
	    my $r6 = $s6->next;
	    is($r6->[Strassen::NAME()], "0723", "Fallback name not used");

	    # Parsing from string, fallback name, effective
	    my $s7 = Strassen::GPX->new;
	    $s7->gpxdata2bbd(gpx_sample_trk_without_name(), fallbackname => "Fallback name");
	    $s7->init;
	    my $r7 = $s7->next;
	    is($r7->[Strassen::NAME()], "Fallback name", "Fallback name is used");
	}

	# Waypoint file
	{
	    # Parsing from string
	    my $gpx_sample = gpx_sample_wpt();
	    my $s = Strassen::GPX->new;
	    $s->gpxdata2bbd($gpx_sample);
	    $s->init;
	    my $r = $s->next;
	    is($r->[Strassen::NAME()], "011", "Check name from waypoint");
	    is($r->[Strassen::COORDS()][0], "10387,6488");
	    is($s->count, 2);

	    my $xml_res = $s->bbd2gpx;
	    like($xml_res, qr{^<(\?xml|gpx)}, "Looks like XML");
	    gpxlint_string($xml_res, "xmllint for bbd2gpx output (waypoint)");

	    my $s2 = Strassen::GPX->new;
	    $s2->gpxdata2bbd($xml_res);
	    deep_strassen_check($s, $s2, $xml_res);

	    # Parsing from file
	    my($ofh, $ofilename) = tempfile(UNLINK => 1, SUFFIX => "_strassen_gpx.gpx");
	    print $ofh $gpx_sample;
	    close $ofh;

	    my $s3 = Strassen::GPX->new;
	    $s3->gpx2bbd($ofilename);
	    is $s3->file, $ofilename;
	    is "@{[ $s3->dependent_files ]}", $ofilename;
	    is_deeply($s->data, $s3->data, "File loading OK");

	    load_from_file_and_check $ofilename, $s3;

	    # Parsing from string, overriding name and cat
	    my $s4 = Strassen::GPX->new;
	    $s4->gpxdata2bbd($gpx_sample, name => "My Name", cat => "MYCAT");
	    $s4->init;
	    my $r4 = $s4->next;
	    is($r4->[Strassen::NAME()], "My Name", "Check overridden name");
	    is($r4->[Strassen::CAT()], "MYCAT", "Check overriden category");

	    # Parsing from file, overriding name and cat
	    my $s5 = Strassen::GPX->new;
	    $s5->gpx2bbd($ofilename, name => "My Name", cat => "MYCAT");
	    is $s5->file, $ofilename;
	    is "@{[ $s5->dependent_files ]}", $ofilename;
	    is_deeply($s5->data, $s4->data, "Check overriden data in files");

	    # Parsing from string, fallback name, ineffective
	    my $s6 = Strassen::GPX->new;
	    $s6->gpxdata2bbd($gpx_sample, fallbackname => "Fallback wpt name");
	    $s6->init;
	    my $r6 = $s6->next;
	    is($r6->[Strassen::NAME()], "011", "Fallback wpt name not used");

	    # Parsing from string, fallback name, effective
	    my $s7 = Strassen::GPX->new;
	    $s7->gpxdata2bbd(gpx_sample_wpt_without_name(), fallbackname => "Fallback wpt name");
	    $s7->init;
	    my $r7 = $s7->next;
	    is($r7->[Strassen::NAME()], "Fallback wpt name", "Fallback wpt name is used");
	}

	# Rte file
	{
	    my $gpx_sample = gpx_sample_rte();
	    {
		my $s = Strassen::GPX->new;
		$s->gpxdata2bbd($gpx_sample);
		cmp_ok($s->count, ">=", 10, "A lot of data found in route file");

		my $r = $s->next;
		is($r->[Strassen::NAME()], "Althoffstr. (A)", "Route name");

		$parsed_rte{$use_xml_module} = $s->as_string;
	    }

	    {
		my $s = Strassen::GPX->new;
		$s->gpxdata2bbd($gpx_sample, name => 'My route');
		my $r = $s->next;
		is($r->[Strassen::NAME()], "My route", "Route name explicitly set");
	    }

	    {
		my $s = Strassen::GPX->new;
		$s->gpxdata2bbd($gpx_sample, fallbackname => 'Fallback route name');
		my $r = $s->next;
		is($r->[Strassen::NAME()], "Althoffstr. (A)", "Fallback route name ineffective");
	    }

	    {
		my $s = Strassen::GPX->new;
		$s->gpxdata2bbd(gpx_sample_rte_without_name(), fallbackname => 'Fallback route name');
		my $r = $s->next;
		is($r->[Strassen::NAME()], "Fallback route name", "Fallback route name effective");
	    }
	}

	SKIP:
	{
	    # See also http://www.freebsd.org/cgi/query-pr.cgi?pr=174917
	    # and https://rt.cpan.org/Ticket/Display.html?id=83037
	    skip "Possible segfault with large files", 3
		if (
		    $do_long_tests                 # fails only with large files (20_000 or 100_000 build nodes)
		    && $] < 5.016                     # does not fail with perl 5.16.x
		    && $use_xml_module eq 'XML::Twig' # does not fail with libxml2
		   );

	    # Data file with points only
	    my $data_file = File::Spec->file_name_is_absolute($bbdfile) ? $bbdfile : "$FindBin::RealBin/../data/$bbdfile";
	    my $s0 = Strassen->new($data_file);
	    my $s = Strassen::GPX->new($s0);
	    isa_ok($s, "Strassen::GPX");
	    my $xml_res = $s->Strassen::GPX::bbd2gpx;
	    like($xml_res, qr{^<(\?xml|gpx)}, "Looks like XML");

	    gpxlint_string($xml_res, "xmllint for bbd2gpx output ($bbdfile)");
	}

	{
	    # Data file with also lines
	    my $data_file = File::Spec->file_name_is_absolute($bbdfile_with_lines) ? $bbdfile_with_lines : "$FindBin::RealBin/../data/$bbdfile_with_lines";
	    my $s0 = Strassen->new($data_file);
	    my $s = Strassen::GPX->new($s0);
	    isa_ok($s, "Strassen::GPX");
	    my $xml_res = $s->Strassen::GPX::bbd2gpx;
	    like($xml_res, qr{^<(\?xml|gpx)}, "Looks like XML");

	    gpxlint_string($xml_res, "xmllint for bbd2gpx output ($bbdfile_with_lines)");
	}

	{
	    # unicode data > codepoint 128
	    my $s0 = Strassen->new_from_data_string(<<EOF);
foo���	X 1,1 2,2
EOF
	    my $s = Strassen::GPX->new($s0);
	    isa_ok($s, "Strassen::GPX");
	    my $xml_res = $s->Strassen::GPX::bbd2gpx;
	    like($xml_res, qr{^<(\?xml|gpx)}, "Looks like XML");

	    gpxlint_string($xml_res, "xmllint for bbd2gpx output (string data with unicode > 128 < 256)");
	    xpath_checks $xml_res, 1,
		sub {
		    my $doc = shift;
		    my $name = $doc->findvalue("//name");
		    is($name, 'foo���', "Unicode parsed correctly");
		};
	}

	{
	    # unicode data > codepoint 255
	    my $data = <<EOF;
#: encoding: utf-8
foo\x{20ac}\x{0107}	X 1,1 2,2
EOF
	    $data = Encode::encode("utf-8", $data);
	    my $s0 = Strassen->new_from_data_string($data);
	    my $s = Strassen::GPX->new($s0);
	    isa_ok($s, "Strassen::GPX");
	    my $xml_res = $s->Strassen::GPX::bbd2gpx;
	    like($xml_res, qr{^<(\?xml|gpx)}, "Looks like XML");

	    gpxlint_string($xml_res, "xmllint for bbd2gpx output (string data with unicode > 255)");
	    xpath_checks $xml_res, 1,
		sub {
		    my $doc = shift;
		    my $name = $doc->findvalue("//name");
		    is($name, "foo\x{20ac}\x{0107}", "Unicode parsed correctly");
		};
	}

	{ # empty bbd file
	    my $s0 = Strassen->new_from_data("");
	    my $s = Strassen::GPX->new($s0);
	    my $xml_res = $s->Strassen::GPX::bbd2gpx;
	    gpxlint_string($xml_res, "empty gpx file");
	}

	# Problematic file
	{
	    # Parsing from string
	    my $gpx_sample = problematic_gpx();
	    my $s = Strassen::GPX->new;
	    $s->gpxdata2bbd($gpx_sample);
	    is($s->count, 2, "Ignored first (empty) entry");
	    $s->init; $s->next;
	    my $rec = $s->next;
	    unlike($rec->[Strassen::NAME()], qr{\n}, "No newline in name");
	    is(scalar(@{ $rec->[Strassen::COORDS()] }), 1, "Found a coord in second record");
	}

	# polar map (WGS84, DDD)
	{
	    my $s0 = Strassen->new_from_data_string(<<EOF);
#: map: polar
#:
Brandenburger Tor	X 52.516216,13.377315
EOF
	    my $s = Strassen::GPX->new($s0);
	    isa_ok($s, "Strassen::GPX");
	    my $xml_res = $s->Strassen::GPX::bbd2gpx;
	    like($xml_res, qr{^<(\?xml|gpx)}, "Looks like XML");
	    gpxlint_string($xml_res, "xmllint for bbd2gpx output (with polar map)");
	    like($xml_res, qr{lat="13\.377315"}, "Found unchanged latitude");
	    like($xml_res, qr{lon="52\.516216"}, "Found unchanged longitude");

	    my $s_gpx = Strassen::GPX->new;
	    $s_gpx->Strassen::GPX::gpxdata2bbd($xml_res);
	    pass("gpxdata2bbd back was successful");

	    my $conv = $s->get_conversion;
	    my($sx,$sy) = split /,/, $conv->($s->get(0)->[Strassen::COORDS()]->[0]);
	    my($gotx,$goty) = split /,/, $s_gpx->get(0)->[Strassen::COORDS()]->[0];
	    cmp_ok(abs($sx-$gotx), "<", 2, "Back conversion with expected x coordinate")
		or diag("Got $gotx/$goty");
	    cmp_ok(abs($sy-$goty), "<", 2, "Back conversion with expected y coordinate")
		or diag("Got $gotx/$goty");
	}

	# Trip extensions
	{
	    my $s0 = Strassen->new_from_data_string(<<EOF);
#: map: polar
#:
TestAstr.	X 13.377315,52.516216
TestBstr.	X 13.380722,52.516467
TestCstr.	X 13.389209,52.514702
EOF
	    my $s = Strassen::GPX->new($s0);
	    my $xml_res = $s->Strassen::GPX::bbd2gpx(-withtripext => 1, -as => 'route');
	    like($xml_res, qr{^<(\?xml|gpx)}, "Looks like XML");
	    gpxlint_string($xml_res, "xmllint for bbd2gpx output (with polar map)");
	    xpath_checks $xml_res, 7,
		sub {
		    my $doc = shift;
		    require XML::LibXML::XPathContext;
		    $doc = XML::LibXML::XPathContext->new($doc);
		    $doc->registerNs('trp', Strassen::GPX::TRIP_EXT_NS);
		    my @rtept = $doc->findnodes('//rtept');
		    is @rtept, 3, 'three route points';
		    ok !$doc->exists('.//trp:ShapingPoint', $rtept[0]), 'first point is not a shaping point';
		    ok  $doc->exists('.//trp:ViaPoint',     $rtept[0]), '... but a via point';
		    ok  $doc->exists('.//trp:ShapingPoint', $rtept[1]), 'middle point is a shaping point';
		    ok !$doc->exists('.//trp:ViaPoint',     $rtept[1]), '... and no via point';
		    ok !$doc->exists('.//trp:ShapingPoint', $rtept[2]), 'goal is not a shaping point, again';
		    ok  $doc->exists('.//trp:ViaPoint',     $rtept[2]), '... and also a via point';
		};
	}

	# Generate route/track with many meta data
	{
	    my $route_data = <<EOF;
Start	X 100,100
Via	X 200,200
Goal	X 300,300
EOF
	    my $track_data = <<EOF;
Start - Goal	X 100,100 200,200 300,300
EOF
	    for my $def (['track', $track_data],
			 ['multi-tracks', $track_data],
			 ['route', $route_data],
			) {
		my($as, $data) = @$def;
		my $s0 = Strassen->new_from_data_string($data);
		my $s = Strassen::GPX->new($s0);
		isa_ok($s, "Strassen::GPX");
		my $xml_res = $s->Strassen::GPX::bbd2gpx(-as => $as,
							 -meta => { name   => "Name of route",
								    cmt	   => "Some comment",
								    desc   => "Description",
								    src	   => "Source?",
								    link   => { text => "web page", href => "http://bbbike.de" },
								    number => 1,
								    type   => "type",
								  },
							);
		pass("Created as $as");
		gpxlint_string($xml_res, "xmllint for bbd2gpx route output");
		like($xml_res, qr{<name>Name of route}, "Found name element");
		like($xml_res, qr{<cmt>Some comment}, "Found comment element");
		like($xml_res, qr{<desc>Description}, "Found description element");
		like($xml_res, qr{<src>Source}, "Found src element");
		like($xml_res, qr{<link href="http://bbbike.de"><text>web page}, "Found link element + href attribute");
		like($xml_res, qr{<number>1}, "Found number element");
		like($xml_res, qr{<type>type}, "Found type element");
		if ($as eq 'route') {
		    like($xml_res, qr{<name>$_}, "Found '$_' text") for (qw(Start Via Goal));
		} else {
		    unlike($xml_res, qr{<name>$_}, "Expected no occurence of '$_' text") for (qw(Start Via Goal));
		}
		keep_file("as_${as}_with_${use_xml_module}.xml", $xml_res);
	    }
	}

	# Generate route with given -name
	{
	    my $route_data = <<EOF;
Start	X 100,100
Goal	X 300,300
EOF
	    my $s0 = Strassen->new_from_data_string($route_data);
	    my $s = Strassen::GPX->new($s0);
	    my $xml_res = $s->Strassen::GPX::bbd2gpx(-as => 'route', -name => 'This is the route name');
	    gpxlint_string($xml_res, 'xmllint for bbd2gpx with -name option');
	    xpath_checks $xml_res, 3,
		sub {
		    my $doc = shift;
		    {
			my @nodes = $doc->findnodes('//rte/name');
			is scalar(@nodes), 1, 'exactly one rte/name node';
			is $nodes[0]->textContent, 'This is the route name', 'expected route name';
		    }
		    {
			my @nodes = $doc->findnodes('//metadata');
			is scalar(@nodes), 0, 'no metadata node generated by default';
		    }
		};
	}

	# Generate route with automatic metadata
	{
	    my $route_data = <<EOF;
Start	X 100,100
Goal	X 300,300
EOF
	    my $s0 = Strassen->new_from_data_string($route_data);
	    my $s = Strassen::GPX->new($s0);
	    my $xml_res = $s->Strassen::GPX::bbd2gpx(-as => 'route', -name => 'This is the route name', -autometadata => 1);
	    gpxlint_string($xml_res, 'xmllint for bbd2gpx with -autometadata option');
	    xpath_checks $xml_res, 4,
		sub {
		    my $doc = shift;
		    {
			my @nodes = $doc->findnodes('//metadata/name');
			is scalar(@nodes), 1, 'exactly one metadata/name node';
			is $nodes[0]->textContent, 'This is the route name', 'expected route name in metadata';
		    }
		    {
			my @nodes = $doc->findnodes('//metadata/link');
			is scalar(@nodes), 1, 'exactly one metadata/link node';
			like $nodes[0]->getAttribute('href'), qr{bbbike\.de}, 'link href contains bbbike.de';
		    }
		};
	}

	# Name from global directive -title (latin1 and utf8)
	for my $utf8 (0, 1) {
	    my $route_data = <<EOF;
#: title: Global directive title with ���
#:
Start	X 100,100
Goal	X 300,300
EOF
	    if ($utf8) {
		$route_data = "#: encoding: utf-8\n" . Encode::encode("utf-8", $route_data);
	    }

	    my $s0 = Strassen->new_from_data_string($route_data);
	    my $s = Strassen::GPX->new($s0);
	    {
		my $xml_res = $s->Strassen::GPX::bbd2gpx(-as => 'route');
		gpxlint_string($xml_res, "xmllint for bbd2gpx on bbd with global directive, utf8=$utf8");
		xpath_checks $xml_res, 2,
		    sub {
			my $doc = shift;
			my @nodes = $doc->findnodes('//rte/name');
			is scalar(@nodes), 1, 'exactly one rte/name node';
			is $nodes[0]->textContent, 'Global directive title with ���', 'route name from global directive in bbd file';
		    };
	    }
	    {
		my $xml_res = $s->Strassen::GPX::bbd2gpx(-as => 'route', -name => "overriding title");
		gpxlint_string($xml_res, 'xmllint for bbd2gpx with overridden title');
		xpath_checks $xml_res, 2,
		    sub {
			my $doc = shift;
			my @nodes = $doc->findnodes('//rte/name');
			is scalar(@nodes), 1, 'exactly one rte/name node';
			is $nodes[0]->textContent, 'overriding title', 'option has precedence over global directive';
		    };
	    }
	}

	{
	    # preserve WGS84 coordinates
	    my $gpx_string = <<'EOF';
<gpx><trk><name>Testtrk</name><trkseg><trkpt lat="52.525729" lon="13.370012" /><trkpt lat="52.525748" lon="13.370018" /><trkpt lat="52.525770" lon="13.370019" /></trkseg></trk></gpx>
EOF
	    my $expected_bbd_string = <<'EOF';
#: map: polar
#:
Testtrk	X 13.370012,52.525729 13.370018,52.525748 13.370019,52.525770
EOF

	    {
		my $s = Strassen::GPX->new;
		$s->set_global_directive(map => 'polar');
		$s->gpxdata2bbd($gpx_string);
		eq_or_diff $s->as_string, $expected_bbd_string, 'preserve WGS84 coordinates in gpxdata2bbd';
	    }

	    {
		my($tmpfh,$tmpfile) = tempfile(SUFFIX => '_strassen.gpx', UNLINK => 1);
		print $tmpfh $gpx_string;
		close $tmpfh or die $!;

		my $s = Strassen::GPX->new;
		$s->set_global_directive(map => 'polar');
		$s->gpx2bbd($tmpfile);
		eq_or_diff $s->as_string, $expected_bbd_string, 'preserve WGS84 coordinates in gpx2bbd';
	    }
	}

	{
	    # -as => "multi-tracks"
	    my $bbd = <<'EOF';
#: map: polar
#:
Track1	X 13.4,52.5 13.5,52.6
Track2	X 13.5,52.6 13.6,52.7
EOF
	    my $s0 = Strassen->new_from_data_string($bbd);
	    my $s = Strassen::GPX->new($s0);
	    my $xml_res = $s->Strassen::GPX::bbd2gpx(-as => 'multi-tracks');
	    xpath_checks $xml_res, 5,
		sub {
		    my $doc = shift;
		    my @trks = $doc->findnodes('//trk');
		    is scalar(@trks), 2, 'created two tracks for multi-tracks';
		    is $trks[0]->findvalue('./name'), 'Track1', 'expected first track name';
		    is $trks[1]->findvalue('./name'), 'Track2', 'expected second track name';
		    is $trks[0]->findvalue('./trkseg/trkpt[position()=1]/@lat'), '52.5', 'expected latitude of first coordinate';
		    is $trks[1]->findvalue('./trkseg/trkpt[position()=2]/@lon'), '13.6', 'expected longitude of last coordinate';
		};
	}

	{
	    # -as => "multi-tracks" and fallback name
	    my $bbd = <<'EOF';
#: map: polar
#:
	X 13.4,52.5 13.5,52.6
	X 13.5,52.6 13.6,52.7
EOF
	    my $s0 = Strassen->new_from_data_string($bbd);
	    my $s = Strassen::GPX->new($s0);
	    my $xml_res = $s->Strassen::GPX::bbd2gpx(-as => 'multi-tracks');
	    xpath_checks $xml_res, 3,
		sub {
		    my $doc = shift;
		    my @trks = $doc->findnodes('//trk');
		    is scalar(@trks), 2, 'created two tracks for multi-tracks';
		    is $trks[0]->findvalue('./name'), 'Track 1', 'expected 1st fallback track name';
		    is $trks[1]->findvalue('./name'), 'Track 2', 'expected 2nd fallback track name';
		};
	}

	{
	    # bbd2gpx as route with single coordinates per bbd line
	    my $bbd = <<'EOF';
#: map: polar
#:
Street1	X 13.4,52.5
Street2	X 13.5,52.6
Street3	X 13.6,52.7
EOF
	    my $s0 = Strassen->new_from_data_string($bbd);
	    my $s = Strassen::GPX->new($s0);
	    my $xml_res = $s->bbd2gpx(-as => 'route');
	    gpxlint_string($xml_res);
	    xml_eq($xml_res, qq{<gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" creator="Strassen::GPX $Strassen::GPX::VERSION __normalized_creator_module__ - http://www.bbbike.de" version="1.1" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"><rte><rtept lat="52.5" lon="13.4"><name>Street1</name></rtept><rtept lat="52.6" lon="13.5"><name>Street2</name></rtept><rtept lat="52.7" lon="13.6"><name>Street3</name></rtept></rte></gpx>},
		   'bbd2gps as route with single coords',
		   ignore => ['//*[local-name()="gpx"]/@creator'], # contains implementor module like XML::Twig or XML::LibXML
		  );
	}

	{
	    # bbd2gpx as route with multiple coordinates per bbd line
	    my $bbd = <<'EOF';
#: map: polar
#:
StreetA	X 13.40,52.50 13.41,52.51 13.42,52.52 13.43,52.53 13.44,52.54 13.45,52.55 13.46,52.56 13.47,52.57 13.48,52.58 13.49,52.59
StreetB	X 13.6,52.7
EOF
	    my $s0 = Strassen->new_from_data_string($bbd);
	    my $s = Strassen::GPX->new($s0);
	    my $xml_res = $s->bbd2gpx(-as => 'route');
	    gpxlint_string($xml_res);
	    xml_eq($xml_res, qq{<gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" creator="Strassen::GPX $Strassen::GPX::VERSION __normalized_creator_module__ - http://www.bbbike.de" version="1.1" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"><rte><rtept lat="52.50" lon="13.40"><name>StreetA01</name></rtept><rtept lat="52.51" lon="13.41"><name>StreetA02</name></rtept><rtept lat="52.52" lon="13.42"><name>StreetA03</name></rtept><rtept lat="52.53" lon="13.43"><name>StreetA04</name></rtept><rtept lat="52.54" lon="13.44"><name>StreetA05</name></rtept><rtept lat="52.55" lon="13.45"><name>StreetA06</name></rtept><rtept lat="52.56" lon="13.46"><name>StreetA07</name></rtept><rtept lat="52.57" lon="13.47"><name>StreetA08</name></rtept><rtept lat="52.58" lon="13.48"><name>StreetA09</name></rtept><rtept lat="52.59" lon="13.49"><name>StreetA10</name></rtept><rtept lat="52.7" lon="13.6"><name>StreetB</name></rtept></rte></gpx>},
		  'bbd2gps as route with multiple coords',
		   ignore => ['//*[local-name()="gpx"]/@creator'], # contains implementor module like XML::Twig or XML::LibXML
		  );
	}
    }
}

SKIP: {
    skip("one or more variants not testable, cannot compare variants", 1)
	if $do_not_compare_variants;
    is($parsed_rte{"XML::LibXML"}, $parsed_rte{"XML::Twig"}, "Both variants same result");
}

{
    my($fh,$file) = tempfile(SUFFIX => "_strassen_gpx.gpx", UNLINK => 1);
    print {$fh} gpx_sample_trk();
    close $fh;

    if ($v) {
	$main::verbose = $main::verbose = 2;
    }
    my $route = Route::load($file, {}, -fuzzy => 1);
    is($route->{Type}, "GPX", "Route recognized as GPX");
    is(scalar(@{$route->{RealCoords}}), 2, "Two coordinates found");
}

if ($tempdir) {
    warn "*** Result files are in $tempdir.\n";
}

sub deep_strassen_check {
    my($s1, $s2, $xml_res) = @_;
    # Do not check coords, because off-by-one meter is expected!
    is_deeply([map({ [$_->[Strassen::NAME()], $_->[Strassen::CAT()]] } $s1->get_all)],
	      [map({ [$_->[Strassen::NAME()], $_->[Strassen::CAT()]] } $s2->get_all)],
	     )
	or diag "XML was $xml_res\nStrassen dumps: " . Dumper([$s->get_all, $s2->get_all]);
}

sub gpx_sample_trk {
    <<'EOF';
<?xml version="1.0" encoding="ISO-8859-1" standalone="yes"?>
<gpx
 version="1.0"
 creator="GPSMan" 
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xmlns="http://www.topografix.com/GPX/1/0"
 xmlns:topografix="http://www.topografix.com/GPX/Private/TopoGrafix/0/2"
 xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd http://www.topografix.com/GPX/Private/TopoGrafix/0/2 http://www.topografix.com/GPX/Private/TopoGrafix/0/2/topografix.xsd">
 <author>an author</author>
 <email>an_email@somewhere</email>
 <url>an_url</url>
 <urlname>a_url_name</urlname>
<time>2006-07-24T19:03:31Z</time>
<trk>
<name>0723</name>
<trkseg>
<trkpt lat="52.5328254327" lon="13.3285581786">
  <ele>24.6510009766</ele>
  <time>2006-07-23T07:14:24Z</time>
</trkpt>
<trkpt lat="52.5330141094" lon="13.3285904489">
  <ele>24.1702880859</ele>
  <time>2006-07-23T07:14:32Z</time>
</trkpt>
</trkseg></trk>
</gpx>
EOF
}

sub gpx_sample_trk_without_name {
    my $gpx = gpx_sample_trk();
    $gpx =~ s{<name>.*?</name>}{}g; # dirty
    $gpx;
}

sub gpx_sample_wpt {
    <<'EOF';
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<gpx xmlns="http://www.topografix.com/GPX/1/1" creator="MapSource 6.11.1" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">

  <metadata>
    <link href="http://www.garmin.com">
      <text>Garmin International</text>
    </link>
    <time>2006-07-25T15:56:32Z</time>
    <bounds maxlat="52.753318" maxlon="13.624997" minlat="52.341700" minlon="13.232372"/>
  </metadata>

  <wpt lat="52.464161" lon="13.402240">
    <ele>38.818604</ele>
    <name>011</name>
    <cmt>17-JUL-06 14:58:30</cmt>
    <desc>17-JUL-06 14:58:30</desc>
    <sym>Residence</sym>
    <extensions>
      <gpxx:WaypointExtension xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www.garmin.com/xmlschemas/GpxExtensions/v3/GpxExtensionsv3.xsd">
        <gpxx:DisplayMode>SymbolAndName</gpxx:DisplayMode>
      </gpxx:WaypointExtension>
    </extensions>
  </wpt>

  <wpt lat="52.516176" lon="13.281016">
    <ele>38.097656</ele>
    <name>AgentArb</name>
    <cmt>20-JUN-06 13:50:01</cmt>
    <desc>20-JUN-06 13:50:01</desc>
    <sym>Building</sym>
    <extensions>
      <gpxx:WaypointExtension xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www.garmin.com/xmlschemas/GpxExtensions/v3/GpxExtensionsv3.xsd">
        <gpxx:DisplayMode>SymbolAndName</gpxx:DisplayMode>
      </gpxx:WaypointExtension>
    </extensions>
  </wpt>
</gpx>
EOF
}

sub gpx_sample_wpt_without_name {
    my $gpx = gpx_sample_wpt();
    $gpx =~ s{<name>.*?</name>}{}g; # dirty
    $gpx;
}

sub gpx_sample_rte {
    <<'EOF';
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<gpx xmlns="http://www.topografix.com/GPX/1/1" creator="GPS TrackMaker" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1
http://www.topografix.com/GPX/1/1/gpx.xsd"><metadata><link href="http://www.gpstm.com"><text>Geo Studio Tecnology Ltd</text></link><time>2006-09-04T22:56:11Z</time><bounds minlat="52.386254" minlon="13.090528" maxlat="52.392324" maxlon="13.122877"/></metadata><wpt lat="52.392098000" lon="13.103797000"><ele>0.000000</ele><name>Ampel</name><cmt>Ampel</cmt><desc>Ampel</desc><sym>Danger Area</sym></wpt><rte><name>Althoffstr. (A)</name><rtept lat="52.389263000" lon="13.099393000"><ele>0.000000</ele><name>R1-1</name><cmt>R1-1</cmt><desc>R1-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389430000" lon="13.100719000"><ele>0.000000</ele><name>R1-2</name><cmt>R1-2</cmt><desc>R1-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.389430000" lon="13.100719000"><ele>0.000000</ele><name>R1-3</name><cmt>R1-3</cmt><desc>R1-3</desc><sym>Waypoint</sym></rtept></rte><rte><name>Heide (leicht Kopf)</name><rtept lat="52.389603000" lon="13.101458000"><ele>0.000000</ele><name>R2-1</name><cmt>R2-1</cmt><desc>R2-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.388971000" lon="13.101809000"><ele>0.000000</ele><name>R2-2</name><cmt>R2-2</cmt><desc>R2-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.388470000" lon="13.102458000"><ele>0.000000</ele><name>R2-3</name><cmt>R2-3</cmt><desc>R2-3</desc><sym>Waypoint</sym></rtept><rtept lat="52.388195000" lon="13.103039000"><ele>0.000000</ele><name>R2-4</name><cmt>R2-4</cmt><desc>R2-4</desc><sym>Waypoint</sym></rtept><rtept lat="52.388007000" lon="13.103915000"><ele>0.000000</ele><name>R2-5</name><cmt>R2-5</cmt><desc>R2-5</desc><sym>Waypoint</sym></rtept><rtept lat="52.388007000" lon="13.103915000"><ele>0.000000</ele><name>R2-6</name><cmt>R2-6</cmt><desc>R2-6</desc><sym>Waypoint</sym></rtept></rte><rte><name>Blumenweg (A)</name><rtept lat="52.387384000" lon="13.108086000"><ele>0.000000</ele><name>R3-1</name><cmt>R3-1</cmt><desc>R3-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390022000" lon="13.109474000"><ele>0.000000</ele><name>R3-2</name><cmt>R3-2</cmt><desc>R3-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.389977000" lon="13.109473000"><ele>0.000000</ele><name>R3-3</name><cmt>R3-3</cmt><desc>R3-3</desc><sym>Waypoint</sym></rtept><rtept lat="52.389977000" lon="13.109546000"><ele>0.000000</ele><name>R3-4</name><cmt>R3-4</cmt><desc>R3-4</desc><sym>Waypoint</sym></rtept></rte><rte><name>Paul-N. (A)</name><rtept lat="52.387479000" lon="13.107501000"><ele>0.000000</ele><name>R4-1</name><cmt>R4-1</cmt><desc>R4-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.386254000" lon="13.113566000"><ele>0.000000</ele><name>R4-2</name><cmt>R4-2</cmt><desc>R4-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.386254000" lon="13.113566000"><ele>0.000000</ele><name>R4-3</name><cmt>R4-3</cmt><desc>R4-3</desc><sym>Waypoint</sym></rtept></rte><rte><name>Paul-N.(leicht Kopf)</name><rtept lat="52.389880000" lon="13.105431000"><ele>0.000000</ele><name>R5-1</name><cmt>R5-1</cmt><desc>R5-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.387479000" lon="13.107501000"><ele>0.000000</ele><name>R5-2</name><cmt>R5-2</cmt><desc>R5-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Althoffstr (A)</name><rtept lat="52.389429000" lon="13.100793000"><ele>0.000000</ele><name>R6-1</name><cmt>R6-1</cmt><desc>R6-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389654000" lon="13.100798000"><ele>0.000000</ele><name>R6-2</name><cmt>R6-2</cmt><desc>R6-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.390158000" lon="13.104630000"><ele>0.000000</ele><name>R6-3</name><cmt>R6-3</cmt><desc>R6-3</desc><sym>Waypoint</sym></rtept></rte><rte><name>Heide (A)</name><rtept lat="52.387960000" lon="13.104135000"><ele>0.000000</ele><name>R7-1</name><cmt>R7-1</cmt><desc>R7-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.387349000" lon="13.107057000"><ele>0.000000</ele><name>R7-2</name><cmt>R7-2</cmt><desc>R7-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Stephen (A)</name><rtept lat="52.390600000" lon="13.100601000"><ele>0.000000</ele><name>R8-1</name><cmt>R8-1</cmt><desc>R8-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.391149096" lon="13.104208058"><ele>0.000000</ele><name>R8-2</name><cmt>R8-2</cmt><desc>R8-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Paul-N. (A)</name><rtept lat="52.391781000" lon="13.104010000"><ele>0.000000</ele><name>R9-1</name><cmt>R9-1</cmt><desc>R9-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389972000" lon="13.105286000"><ele>0.000000</ele><name>R9-2</name><cmt>R9-2</cmt><desc>R9-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Stephen (leicht Kopf</name><rtept lat="52.390131000" lon="13.097799000"><ele>0.000000</ele><name>R10-1</name><cmt>R10-1</cmt><desc>R10-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390555000" lon="13.100527000"><ele>0.000000</ele><name>R10-2</name><cmt>R10-2</cmt><desc>R10-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Anhalter (leicht Kop</name><rtept lat="52.391366000" lon="13.100327000"><ele>0.000000</ele><name>R11-1</name><cmt>R11-1</cmt><desc>R11-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390600000" lon="13.100528000"><ele>0.000000</ele><name>R11-2</name><cmt>R11-2</cmt><desc>R11-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.390600000" lon="13.100528000"><ele>0.000000</ele><name>R11-3</name><cmt>R11-3</cmt><desc>R11-3</desc><sym>Waypoint</sym></rtept></rte><rte><name>Anhalter (A)</name><rtept lat="52.390465000" lon="13.100525000"><ele>0.000000</ele><name>R12-1</name><cmt>R12-1</cmt><desc>R12-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389699000" lon="13.100799000"><ele>0.000000</ele><name>R12-2</name><cmt>R12-2</cmt><desc>R12-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Paul-N. (leicht Kopf</name><rtept lat="52.391826000" lon="13.104011000"><ele>0.000000</ele><name>R13-1</name><cmt>R13-1</cmt><desc>R13-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.392324000" lon="13.103656000"><ele>0.000000</ele><name>R13-2</name><cmt>R13-2</cmt><desc>R13-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Kopern. (leicht Kopf</name><rtept lat="52.390824000" lon="13.095833000"><ele>0.000000</ele><name>R14-1</name><cmt>R14-1</cmt><desc>R14-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390593000" lon="13.096488000"><ele>0.000000</ele><name>R14-2</name><cmt>R14-2</cmt><desc>R14-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Kopern (leicht Kopf)</name><rtept lat="52.389355000" lon="13.099102000"><ele>0.000000</ele><name>R15-1</name><cmt>R15-1</cmt><desc>R15-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389080000" lon="13.099682000"><ele>0.000000</ele><name>R15-2</name><cmt>R15-2</cmt><desc>R15-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Route 16</name><rtept lat="52.389344000" lon="13.095502000"><ele>0.000000</ele><name>R16-1</name><cmt>R16-1</cmt><desc>R16-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389612000" lon="13.095656000"><ele>0.000000</ele><name>R16-2</name><cmt>R16-2</cmt><desc>R16-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Kopern (Kopf)</name><rtept lat="52.388623000" lon="13.100552000"><ele>0.000000</ele><name>R17-1</name><cmt>R17-1</cmt><desc>R17-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.387248000" lon="13.103382000"><ele>0.000000</ele><name>R17-2</name><cmt>R17-2</cmt><desc>R17-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Watt (Kopf)</name><rtept lat="52.390969000" lon="13.094661000"><ele>0.000000</ele><name>R18-1</name><cmt>R18-1</cmt><desc>R18-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389182000" lon="13.093589000"><ele>0.000000</ele><name>R18-2</name><cmt>R18-2</cmt><desc>R18-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Benzstr (A)</name><rtept lat="52.391103000" lon="13.094738000"><ele>0.000000</ele><name>R19-1</name><cmt>R19-1</cmt><desc>R19-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.391457000" lon="13.100256000"><ele>0.000000</ele><name>R19-2</name><cmt>R19-2</cmt><desc>R19-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.391874000" lon="13.103718000"><ele>0.000000</ele><name>R19-3</name><cmt>R19-3</cmt><desc>R19-3</desc><sym>Waypoint</sym></rtept><rtept lat="52.391300000" lon="13.112150000"><ele>0.000000</ele><name>R19-4</name><cmt>R19-4</cmt><desc>R19-4</desc><sym>Waypoint</sym></rtept><rtept lat="52.391424000" lon="13.122877000"><ele>0.000000</ele><name>R19-5</name><cmt>R19-5</cmt><desc>R19-5</desc><sym>Waypoint</sym></rtept></rte><rte><name>Schul (A)</name><rtept lat="52.391061000" lon="13.094443000"><ele>0.000000</ele><name>R20-1</name><cmt>R20-1</cmt><desc>R20-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390154000" lon="13.090528000"><ele>0.000000</ele><name>R20-2</name><cmt>R20-2</cmt><desc>R20-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Route 21</name><rtept lat="52.390641000" lon="13.096122000"><ele>0.000000</ele><name>R21-1</name><cmt>R21-1</cmt><desc>R21-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389702000" lon="13.095658000"><ele>0.000000</ele><name>R21-2</name><cmt>R21-2</cmt><desc>R21-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Route 22</name><rtept lat="52.389255000" lon="13.095427000"><ele>0.000000</ele><name>R22-1</name><cmt>R22-1</cmt><desc>R22-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.388807000" lon="13.095269000"><ele>0.000000</ele><name>R22-2</name><cmt>R22-2</cmt><desc>R22-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Siemens (Kopf)</name><rtept lat="52.388818000" lon="13.098941000"><ele>0.000000</ele><name>R23-1</name><cmt>R23-1</cmt><desc>R23-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389432000" lon="13.095725000"><ele>0.000000</ele><name>R23-2</name><cmt>R23-2</cmt><desc>R23-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Siemens (Kopf)</name><rtept lat="52.389481000" lon="13.095285000"><ele>0.000000</ele><name>R24-1</name><cmt>R24-1</cmt><desc>R24-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389716000" lon="13.094116000"><ele>0.000000</ele><name>R24-2</name><cmt>R24-2</cmt><desc>R24-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Siemens (Kopf)</name><rtept lat="52.389898000" lon="13.093900000"><ele>0.000000</ele><name>R25-1</name><cmt>R25-1</cmt><desc>R25-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390667000" lon="13.093332000"><ele>0.000000</ele><name>R25-2</name><cmt>R25-2</cmt><desc>R25-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>H.-v.-K (leicht Kopf</name><rtept lat="52.389174000" lon="13.099317000"><ele>0.000000</ele><name>R26-1</name><cmt>R26-1</cmt><desc>R26-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.388101000" lon="13.098703000"><ele>0.000000</ele><name>R26-2</name><cmt>R26-2</cmt><desc>R26-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Kopernikus (A)</name><rtept lat="52.388623000" lon="13.100552000"><ele>0.000000</ele><name>R27-1</name><cmt>R27-1</cmt><desc>R27-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389035000" lon="13.099755000"><ele>0.000000</ele><name>R27-2</name><cmt>R27-2</cmt><desc>R27-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Kopernikus (A)</name><rtept lat="52.389356000" lon="13.099028000"><ele>0.000000</ele><name>R28-1</name><cmt>R28-1</cmt><desc>R28-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390041000" lon="13.097797000"><ele>0.000000</ele><name>R28-2</name><cmt>R28-2</cmt><desc>R28-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.390547000" lon="13.096561000"><ele>0.000000</ele><name>R28-3</name><cmt>R28-3</cmt><desc>R28-3</desc><sym>Waypoint</sym></rtept></rte><rte><name>Kopernikus (A)</name><rtept lat="52.390779000" lon="13.095832000"><ele>0.000000</ele><name>R29-1</name><cmt>R29-1</cmt><desc>R29-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.391058000" lon="13.094810000"><ele>0.000000</ele><name>R29-2</name><cmt>R29-2</cmt><desc>R29-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Pestalozzi (A)</name><rtept lat="52.390064000" lon="13.105068000"><ele>0.000000</ele><name>R30-1</name><cmt>R30-1</cmt><desc>R30-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.387201000" lon="13.103675000"><ele>0.000000</ele><name>R30-2</name><cmt>R30-2</cmt><desc>R30-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Anhalter (leicht Kop</name><rtept lat="52.391952000" lon="13.100121000"><ele>0.000000</ele><name>R31-1</name><cmt>R31-1</cmt><desc>R31-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.391412000" lon="13.100254000"><ele>0.000000</ele><name>R31-2</name><cmt>R31-2</cmt><desc>R31-2</desc><sym>Waypoint</sym></rtept></rte></gpx>
EOF
}

sub gpx_sample_rte_without_name {
    my $gpx = gpx_sample_rte();
    $gpx =~ s{<rte><name>.*?</name>}{<rte>}; # dirty
    $gpx;
}

sub problematic_gpx {
    # Newline in first name
    # First track has no coordinates
    <<EOF;
<?xml version="1.0"?>
<gpx
 version="1.0"
creator="GPSBabel - http://www.gpsbabel.org"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xmlns="http://www.topografix.com/GPX/1/0"
xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd">
<time>2006-09-12T17:28:57Z</time>
<trk>
  <name>Spreeradweg_sachsen
</name>
<trkseg>
</trkseg>
</trk>
<trk>
  <name>track</name>
<trkseg>
<trkpt lat="51.524421700" lon="14.400062600">
  <ele>112.000000</ele>
<time>2002-06-12T23:00:20Z</time>
</trkpt>
<trkpt lat="51.522651700" lon="14.402491600">
  <ele>112.000000</ele>
<time>2002-06-12T23:00:04Z</time>
</trkpt>
</trkseg>
</trk>
<trk>
  <name>Spreeradweg_sachsen2
</name>
<trkseg>
<trkpt lat="51.524421700" lon="14.400062600">
  <ele>112.000000</ele>
<time>2002-06-12T23:00:20Z</time>
</trkpt>
</trkseg>
</trk>
</gpx>
EOF
}

sub keep_file ($$) {
    return if !$tempdir;
    my($file_name, $data) = @_;
    $file_name =~ s{:}{_}g; # invalid under Windows
    my $outfile = File::Spec->catfile($tempdir, $file_name);
    if (open FH, "> " . $outfile) {
	print FH $data;
	close FH;
    } else {
	warn "Cannot write to $outfile: $!";
    }
}

# 12 tests
# Try the different constructor variants
sub load_from_file_and_check ($$) {
    my($gpxfile, $check_against) = @_;

    my $s_gpx = do {
	my $s = Strassen::GPX->new($gpxfile);
	isa_ok $s, "Strassen";
	isa_ok $s, "Strassen::GPX";
	$s;
    };

    my $s = do {
	my $s = Strassen->new($gpxfile);
	isa_ok $s, "Strassen";
	isa_ok $s, "Strassen::GPX";
	$s;
    };

    my $s_magic = do {
	my $s = Strassen->new_by_magic($gpxfile);
	isa_ok $s, "Strassen";
	isa_ok $s, "Strassen::GPX";
	$s;
    };

    my $s_suffix = do {
	my $s = Strassen->new_by_suffix($gpxfile);
	isa_ok $s, "Strassen";
	isa_ok $s, "Strassen::GPX";
	$s;
    };

    is_deeply $s->data, $check_against->data, "Loading gpx with factory";
    is_deeply $s_gpx->data, $check_against->data, "Loading gpx explicitely with Strassen::GPX";
    is_deeply $s_magic->data, $check_against->data, "Loading gpx with magic check";
    is_deeply $s_suffix->data, $check_against->data, "Loading gpx with suffix check";
}

# one test + specified number of $tests
sub xpath_checks ($$&) {
    my($xml_res, $tests, $testcode) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
 SKIP: {
	skip("No XML::LibXML parser available for checking", $tests + 1)
	    if !eval { require XML::LibXML; 1 };
	my $p = XML::LibXML->new;
	my $doc = eval { $p->parse_string($xml_res) };
	ok($doc, "XML::LibXML was available to parse result");
    SKIP: {
	    skip "Document was not parsed correctly, skip reamining subtests...", $tests
		if !$doc;

	    $doc->documentElement->setNamespaceDeclURI('',''); # remove ns for easier xpath expressions

	    local $Test::Builder::Level = $Test::Builder::Level + 1;
	    $testcode->($doc);
	}
    }
}

__END__
