#!/usr/bin/perl
# -*- perl -*-

#
# $Id: wap_test.pl,v 1.2 2003/06/23 22:04:48 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Online Office Berlin. All rights reserved.
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# testet bike_and_movie auf WAP-Konformance etc.

BEGIN { $Devel::Trace::TRACE = 0 }

use strict;

use FindBin;
use lib ("$FindBin::RealBin/../miscsrc",
	 "$FindBin::RealBin/../lib");

use Getopt::Long;

use BrowserInfo;

use URI::Escape;
use Tk; # only for timeofday

# init
my $dtd_file = "$FindBin::RealBin/../misc/wml_1.1.xml";
my $wml_generator = "$FindBin::RealBin/../miscsrc/bike_and_movie.cgi";
my @wml_generator = ($^X, $wml_generator);
my $wml_generator_url = "http://mom/~eserte/bbbike/miscsrc/bike_and_movie.cgi";
my $berlin_data = "$FindBin::RealBin/../data/Berlin.coords.data";
my $kino_db = "$FindBin::RealBin/../tmp/kino_data.db";
my $test_dir = "/tmp/wap_test";

my $verbose = 1;

my @street_data;
my $kino_data;

my @stats_good;
my @stats_bad;

my $ua;
my $xv_pid;
my $stopit = 0;
my $use_www;

if (!GetOptions("v!" => \$verbose,
		"www!" => \$use_www)) {
    die "usage";
}

my $wml_generator_sub = ($use_www
			 ? \&wml_generator_www
			 : \&wml_generator_prog);

$SIG{INT} = sub { $stopit = 1; print STDERR "please wait...\n"; };

if (!-f $dtd_file) {
    die "Can't read DTD file for WML: $dtd_file";
}

random_emulate_wap();
test_start_page();
while (1) {
    random_emulate_wap();
    test_movielist_page();
    last if $stopit;
    test_result_page();
    last if $stopit;
    test_image_page();
    last if $stopit;
}

print "Good:\n";
foreach (@stats_good) {
    print join(" ", @$_), "\n";
}

print "-" x 70, "\n";
print "Bad:\n";
foreach (@stats_bad) {
    print join(" ", @$_), "\n";
}

sub test_start_page {
    my $start_time = timeofday();
    my $wml = get_wml("");
    my $duration = timeofday()-$start_time;
    my $ret = test_xml_conformance($wml);
    stats($ret, $duration, "start");
}

sub test_movielist_page {
    my($street, $bezirk) = get_random_street();
    my $movie = get_random_movie();
    my $params = "startname=" . uri_escape($street);
    if (defined $bezirk) {
	$params .= "&startbezirk=" . uri_escape($bezirk);
    }
    $params .= "&movie=" . uri_escape($movie);
    my $start_time = timeofday();
    my $wml = get_wml($params);
    my $duration = timeofday()-$start_time;
    my $ret = test_xml_conformance($wml);
    stats($ret, $duration, "movielist", $street, $bezirk, $movie);
}

sub test_result_page { test_result_image_page() }
sub test_image_page { test_result_image_page(1) }

sub test_result_image_page {
    my $image = shift;
    my($from) = get_random_coords();
    my($to) = get_random_coords();
    my $vehicle = get_random_vehicle();
    my $params = "startcoord=" . uri_escape($from)
	. "&zielcoord=" . uri_escape($to)
	. "&testing=1"
	. "&vehicle=$vehicle";
    if ($image) {
	$params .= "&image=1";
    }

    my $start_time = timeofday();
    my $data = get_wml($params);
    my $duration = timeofday()-$start_time;
    if ($image) {
	require GD;
	my $ret = test_wbmp_conformance($data);
	stats($ret, $duration, "image", $from, $to, $vehicle);
    } else {
	my $ret = test_xml_conformance($data);
	stats($ret, $duration, "result", $from, $to, $vehicle);
    }
}

sub wml_generator_prog {
    my($params) = @_;
    open(WML, "-|") || do {
	$SIG{INT} = 'IGNORE';
	if (!@wml_generator) {
	    @wml_generator = $wml_generator;
	}
	exec @wml_generator, $params;
	die;
    };
    1;
}

sub wml_generator_www {
    my($params) = @_;
    init_lwp();
    $ua->agent($ENV{HTTP_USER_AGENT});
    my $req = HTTP::Request->new(GET => "$wml_generator_url?$params");
    my $res = $ua->request($req, "$test_dir/test_www.wml");
    if (!$res->is_success) {
	return 0;
    }
    open(WML, "$test_dir/test_www.wml") or die $!;
    1;
}

sub init_lwp {
    return if defined $ua;
    require LWP::UserAgent;
    $ua = LWP::UserAgent->new;
    $ua->env_proxy;
    $ua;
}

sub get_wml {
    my($params) = @_;

    return "" unless $wml_generator_sub->($params);

    my $skip_header = !$use_www;
    my $out = "";
    while(<WML>) {
	if ($skip_header) {
	    if ($_ eq "\015\012") {
		$skip_header = 0;
	    }
	} else {
	    $out =~ s|"http://www.wapforum.org/DTD/wml_1.1.xml"|"wml_1.1.xml"|;
	    $out .= "$_";
	}
    }
    close WML;
    $out;
}

sub init_berlin_data {
    return if @street_data;
    open(B, $berlin_data) or die "Can't open $berlin_data: $!";
    while(<B>) {
	chomp;
	push @street_data, [ split(/\|/, $_) ];
    }
    close B;
}

sub init_kino_data {
    return if $kino_data;
    require CommonMLDBM;
    $kino_data = CommonMLDBM::open(-Filename => $kino_db);
    die "Can't open $kino_db" if !$kino_data;
}

sub get_random_street {
    init_berlin_data();
    my $with_bezirk = int(rand(2));
    my $line = $street_data[rand($#street_data+1)];
    my @ret = ($line->[0]);
    if ($with_bezirk) {
	push @ret, $line->[1];
    }
    my $strip = rand(10) < 8;
    if ($strip) {
	my $length = int(rand(length($ret[0])));
	$ret[0] = substr(lc($ret[0]), 0, $length);
	if ($with_bezirk) {
	    my $length = int(rand(length($ret[1])));
	    $ret[1] = substr(lc($ret[1]), 0, $length);
	}
    }
    @ret;
}

sub get_random_coords {
    init_berlin_data();
    my $with_bezirk = int(rand(2));
    my $line = $street_data[rand($#street_data+1)];
    $line->[3];
}

sub get_random_movie {
    init_kino_data();
    my(@movies) = keys %$kino_data;
    $movies[rand($#movies+1)];
}

sub get_random_vehicle {
    my(@vehicles) = (qw/bike car oepnv/, "");
    $vehicles[rand($#vehicles+1)];
}

sub init_xml_conformance {
    if (!-d $test_dir || !-w $test_dir) {
	require File::Path;
	File::Path::mkpath([$test_dir], 1, 0775);
	if (!-d $test_dir || !-w $test_dir) {
	    die "Can't create/write $test_dir";
	}
    }
    require File::Basename;
    my $dtd_base = File::Basename::basename($dtd_file);
    if (!-f "$test_dir/$dtd_base") {
	require File::Copy;
	File::Copy::cp($dtd_file, "$test_dir/$dtd_base");
	if (!-f "$test_dir/$dtd_base") {
	    die "Can't copy $dtd_file to $test_dir";
	}
    }

    if (!is_in_path("rxp")) {
	die "rxp executable not available. Please install";
    }
}

sub test_xml_conformance {
    my($xml_string) = @_;
    init_xml_conformance();
    open(XML, ">$test_dir/test.xml") or die $!;
    print XML $xml_string;
    close XML;

    system("rxp", "-s", "-V", "$test_dir/test.xml");
    $? == 0;
}

# XXX well...
sub test_wbmp_conformance {
    my($wbmp_string) = @_;

    my $img = "$test_dir/test.wbmp";
    eval {
	open(WBMP, ">$img") or die $!;
	print WBMP $wbmp_string;
	close WBMP;

	$img = "$test_dir/test.pbm";
	unlink $img;
	open(PBM, "| wbmptopbm > $img");
	print PBM $wbmp_string;
	close PBM;

	if (!-e $img || !-s $img) {
	    die "Image $img is not an image";
	}
    };
    if ($@) {
	warn $@ if $@;
	return 0;
    }

    if ($verbose) {
	my $old_xv_pid = $xv_pid;
	$xv_pid = fork;
	if ($xv_pid == 0) {
	    $SIG{INT} = undef;
	    if (defined $old_xv_pid) {
		kill 9 => $old_xv_pid;
	    }

	    exec qw/xv -geometry +0+0 -wait 60 -quit/, $img;
	    exit;
	}
    }

    return 1;

}

sub stats {
    my($ret, $time, @args) = @_;
    if ($ret) {
	push @stats_good, [sprintf("%.3f", $time), @args];
	warn "*** GOOD: " . join(" ", @{$stats_good[-1]}) . "\n" if $verbose;
    } else {
	push @stats_bad, [sprintf("%.3f", $time), @args];
	warn "*** BAD: " . join(" ", @{$stats_bad[-1]}) . "\n" if $verbose;
    }
}

sub timeofday {
    Tk::timeofday;
}

sub random_emulate_wap {
    my @waps = (qw/Nokia7110 Nokia6210 Nokia6250 nokia-wap-toolkit/,
		'SIE-C3I/1.0 UP/4.1.8c UP.Browser/4.1.8c-XXXX UP.Link/4.1.0.6',
	       );
    $ENV{HTTP_USER_AGENT} = $waps[rand($#waps+1)];
}

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 1aa226739da7a8178372aa9520d85589

=head2 is_in_path($prog)

=for category File

Return the pathname of $prog, if the program is in the PATH, or undef
otherwise.

DEPENDENCY: file_name_is_absolute

=cut

sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	return "$_/$prog" if -x "$_/$prog";
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 a77759517bc00f13c52bb91d861d07d0

=head2 file_name_is_absolute($file)

=for category File

Return true, if supplied file name is absolute. This is only necessary
for older perls where File::Spec is not part of the system.

=cut

sub file_name_is_absolute {
    my $file = shift;
    my $r;
    eval {
        require File::Spec;
        $r = File::Spec->file_name_is_absolute($file);
    };
    if ($@) {
	if ($^O eq 'MSWin32') {
	    $r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	} else {
	    $r = ($file =~ m|^/|);
	}
    }
    $r;
}
# REPO END

__END__
