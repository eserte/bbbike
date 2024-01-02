#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

# Tests for static and semi-static content under BBBike/data and
# BBBike/html (resp. bbbike/data and bbbike/html)

use strict;

use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

BEGIN {
    if ($] < 5.006) {
	$INC{"warnings.pm"} = 1;
	*warnings::import = sub { };
	*warnings::unimport = sub { };
    }
}

BEGIN {
    if (!eval q{
	use Test::More;
	use LWP::ConnCache;
	use LWP::UserAgent;
	use Image::Info;
	use HTTP::Date qw(time2str);
	use Time::HiRes;
	use Digest::MD5;
	1;
    }) {
	print "1..0 # skip no Test::More, Image::Info, HTTP::Date, LWP::ConnCache, LWP::UserAgent, Time::HiRes and/or Digest::MD5 module\n";
	exit;
    }
}

use Getopt::Long;
use Image::Info qw(image_info);

use BBBikeUtil qw(bbbike_root);
use Strassen::Core;

use BBBikeTest qw(check_cgi_testing checkpoint_apache_errorlogs output_apache_errorslogs eq_or_diff);

check_cgi_testing;

plan 'no_plan'; # possible variable number of files in data, especially in -long mode

if (!defined &note) { *note = \&diag } # old Test::More compat

my $htmldir   = $ENV{BBBIKE_TEST_HTMLDIR} || 'http://localhost/bbbike';
my $long_test = $ENV{BBBIKE_LONG_TESTS};
my %test_ua;
GetOptions("htmldir=s" => \$htmldir,
	   "live"      => sub {
	       require BBBikeVar;
	       no warnings 'once';
	       $htmldir = $BBBike::BBBIKE_UPDATE_WWW;
	   },
	   "pps"       => sub {
	       $htmldir = 'http://bbbike-pps-jessie/BBBike';
	   },
	   "long"      => \$long_test,
	   'add-inc=s@' => sub {
	       unshift @INC, $_[1];
	   },
	   'ua=s@'      => sub {
	       $test_ua{$_[1]} = 1;
	   },
	  ),
    or die "usage: $0 [-htmldir ... | -live | -pps] [-ua ...] [-long] [-v]";

# load after --add-inc processing
require Http;

my $datadir = "$htmldir/data";

my $is_local_server = $htmldir =~ m{^https?://localhost[:/]};

# Setup user agents
my $conn_cache = LWP::ConnCache->new(total_capacity => 10);

my $ua_lwp = LWP::UserAgent->new(conn_cache => $conn_cache);
$ua_lwp->parse_head(0); # too avoid confusion with Content-Type in http header and meta tags
$ua_lwp->agent('BBBike-Test/1.0');
$ua_lwp->env_proxy;
# Don't use compression unless bbbike itself turns compression on in Update.pm

my $ua_lwp_316 = LWP::UserAgent->new(conn_cache => $conn_cache);
$ua_lwp_316->parse_head(0);
$ua_lwp_316->agent("bbbike/3.16 (LWP::UserAgent/$LWP::VERSION) ($^O) BBBike-Test/1.0");
$ua_lwp_316->env_proxy;
# For simulating older bbbike agents, never turn on compression.

my $ua_http = bless {}, 'Http'; # dummy object
my $ua_http_agent_fmt = "bbbike/%s (Http/$Http::VERSION) ($^O) BBBike-Test/1.0";

my %contents;         # url => [{md5 => ..., ua_label => ..., accept_gzip => ...}, ...]
my %compress_results; # $accept_gzip => { $content_type => { $got_gzipped => $count } }
my @bench_results;
my %done_filesystem_comparison;
my @diags;
my $warned_on_400_with_Http_pm;

if (!%test_ua) {
    $test_ua{LWP} = 1;
    $test_ua{Http} = 1;
    if (eval { require HTTP::Tiny; 1 }) {
	$test_ua{'HTTP::Tiny'} = 1;
    }
}

{
    my %valid_ua = map { ($_,1) } qw(LWP Http HTTP::Tiny);
    for (keys %test_ua) {
	die "Invalid --ua: $_" if !$valid_ua{$_};
    }
}

for my $do_accept_gzip (0, 1) {
    my @ua_defs;
    if ($test_ua{LWP}) {
	push @ua_defs, {ua => $ua_lwp,     ua_label => 'LWP',        content_compare => 1};
	push @ua_defs, {ua => $ua_lwp_316, ua_label => 'LWP (3.16)', bbbike_version => 3.16};
    }
    if ($test_ua{Http} &&
	($Http::http_defaultheader =~ /gzip/ &&  $do_accept_gzip) ||
	($Http::http_defaultheader !~ /gzip/ && !$do_accept_gzip)
       ) {
	push @ua_defs, {ua => $ua_http, ua_label => 'Http (3.18)', content_compare => 1}; # bbbike_version => 3.18 is default, see below
	push @ua_defs, {ua => $ua_http, ua_label => 'Http (3.16)', bbbike_version => 3.16};
    }
    if ($test_ua{'HTTP::Tiny'} && !$do_accept_gzip) {
	require HTTP::Tiny;
	my $ua_tiny = HTTP::Tiny->new(agent => "bbbike/3.18 (HTTP::Tiny/$HTTP::Tiny::VERSION) ($^O) BBBike-Test/1.0");
	push @ua_defs, {ua => $ua_tiny, ua_label => 'HTTP::Tiny (3.18)', content_compare => 1};
    }
    for my $ua_def (@ua_defs) {
	run_test_suite(accept_gzip => $do_accept_gzip, %$ua_def);
    }
}

my $has_mismatches;
for my $url (sort keys %contents) {
    my $v = $contents{$url};
    my $calc_ua_sig = sub {
	my($i) = @_;
	join(", ", map { "$_=$v->[$i]->{$_}" } grep { !/^md5$/ } sort keys %{ $v->[$i] });
    };
    for my $i (1..$#$v) {
	is $v->[$i]->{md5}, $v->[0]->{md5}, "Digest check for $url"
	    or do {
		my $sig1 = $calc_ua_sig->($i);
		my $sig0 = $calc_ua_sig->(0);
		diag "Mismatch for\n  $sig1 vs\n  $sig0";
		$has_mismatches++;
	    };
    }
}
if ($has_mismatches) {
    diag <<EOF;

Running

    (cd @{[ bbbike_root ]}/data && ./doit.pl old_bbbike_data)

may help to fix the problem.
EOF
}

{
    # Compression results, mostly diagnostics
    my @errors;
    while(my($k,$v) = each %{ $compress_results{0} }) {
	if ($v->{1}) {
	    push @errors, "Unexpected compression while no compression was requested (content type: $k)";
	}
    }
    ok !@errors, "Compression check"
	or diag join("\n", @errors);

    my %compressed_ct;
    my %uncompressed_ct;
    while(my($k,$v) = each %{ $compress_results{1} }) {
	if ($v->{0}) {
	    $uncompressed_ct{$k} = 1;
	}
	if ($v->{1}) {
	    $compressed_ct{$k} = 1;
	}
    }
    my %mixed_compression_ct;
    for my $k (keys %uncompressed_ct) {
	if ($compressed_ct{$k}) {
	    delete $uncompressed_ct{$k};
	    delete $compressed_ct{$k};
	    $mixed_compression_ct{$k} = 1;
	}
    }
    if (%compressed_ct) {
	note "The following Content-Types are compressed: " . join(", ", sort keys %compressed_ct);
    }
    if (%uncompressed_ct) {
	note "The following Content-Types are uncompressed: " . join(", ", sort keys %uncompressed_ct);
    }
    if (%mixed_compression_ct) {
	note "The following Content-Types are sometimes compressed, sometimes uncompressed: " . join(", ", sort keys %mixed_compression_ct);
    }
}

if ($long_test) {
    diag "Timings:";
    for (@bench_results) {
	diag "  $_";
    }
}

for my $diag (@diags) {
    diag $diag;
}

sub run_test_suite {
    my(%args) = @_;
    my $do_accept_gzip  = delete $args{accept_gzip};
    my $ua              = delete $args{ua};
    my $ua_label        = delete $args{ua_label};
    my $bbbike_version  = delete $args{bbbike_version} || '3.18';
    my $content_compare = delete $args{content_compare};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    my $basic_tests = sub {
	my($url, %args) = @_;
	my $simulate_unmodified = delete $args{simulate_unmodified};
	my $allow_empty_content = delete $args{allow_empty_content};
	my $is_historical       = delete $args{is_historical};
	if (%args) { die "Unhandled arguments: " . join(" ", %args) }

	my %lwp_headers;
	my $last_modified; # seconds since epoch
	my @expect_status;
	if ($simulate_unmodified) {
	    my $resp = $ua_lwp->head($url, 'User-Agent' => ($ua->can('agent') ? $ua->agent : "bbbike/$bbbike_version BBBike-Test/1.0"));
	    $last_modified = $resp->last_modified;
	    if (!$last_modified) {
		if ($url =~ m{/label$}) {
		    # may be missing
		} else {
		    diag "Cannot get last-modified for $url, expect failures...";
		}
	    }
	    @expect_status = (304);
	} else {
	    $last_modified = 0;
	    @expect_status = $is_historical ? (200, 304) : (200);
	}
	$lwp_headers{'If-Modified-Since'} = time2str($last_modified);

	my $resp;
	my $got_gzipped;
	my $dt;
	checkpoint_apache_errorlogs if $is_local_server;
	if ($ua->isa('Http')) {
	    no warnings 'once';
	    local $Http::user_agent = sprintf $ua_http_agent_fmt, $bbbike_version;
	    my $t0 = Time::HiRes::time;
	    my %ret = Http::get(url => $url, time => $last_modified);
	    $dt = Time::HiRes::time - $t0;
	    $got_gzipped = ($ret{headers}->{'content-encoding'}||'') =~ m{\bgzip\b} ? 1 : 0;
	    delete $ret{headers}->{'content-encoding'}; # fake for HTTP::Response
	    $resp = HTTP::Response->new($ret{error}, undef, HTTP::Headers->new(%{ $ret{headers} || {} }), $ret{content});
	    if ($resp->code == 400 && !grep { 400 == $_ } @expect_status) {
		if (!$warned_on_400_with_Http_pm++) {
		    push @diags, <<EOF;

=== ADDITIONAL DIAGNOSTICS ===

Status code 400 encountered --- maybe the webserver is in strict mode?
For Apache for example, this problem can be workarounded by setting

    HttpProtocolOptions Unsafe

==============================

EOF
		}
	    }
	} else {
	    if ($ua->isa('HTTP::Tiny')) {
		my $t0 = Time::HiRes::time;
		my $ret = $ua->get($url, { headers => \%lwp_headers });
		$dt = Time::HiRes::time - $t0;
		$resp = HTTP::Response->new($ret->{status}, $ret->{reason}, HTTP::Headers->new(%{ $ret->{headers} || {} }), $ret->{content});
	    } else {
		my $t0 = Time::HiRes::time;
		$resp = $ua->get($url, ($do_accept_gzip ? ('Accept-Encoding' => 'gzip') : ()), %lwp_headers);
		$dt = Time::HiRes::time - $t0;
	    }
	    $got_gzipped = ($resp->header('content-encoding')||'') =~ m{\bgzip\b} ? 1 : 0;
	}

	ok((grep { $resp->code == $_ } @expect_status),
	   "Expected status code (@expect_status) for GET $url with simulated ua $ua_label " .
	   ($do_accept_gzip ? "(accept gzipped)" : "(accept uncompressed)") . " " .
	   ($got_gzipped    ? "(got gzipped)"    : "(got uncompressed)")
	  )
	    or do {
		if ($resp->request) {
		    diag "== Request ==\n" . $resp->request->headers->as_string;
		} else {
		    diag "== Request URL== " . $url;
		}
		diag "== Response == \n" . $resp->status_line . "\n" . $resp->headers->as_string;
		output_apache_errorslogs if $is_local_server;
	    };

	my($content_type) = $resp->content_type; # list context!
	my $content;
	if ($resp->code != 304) {
	    $compress_results{$do_accept_gzip}->{$content_type}->{$got_gzipped}++;
	    $content = $resp->decoded_content(charset => 'none');
	    if (!$allow_empty_content) {
		ok(length $content, "Non-empty content");
	    }

	    # Store digest for later comparisons
	    if ($content_compare) {
		push @{ $contents{$url} }, {accept_gzip => $do_accept_gzip, ua_label => $ua_label, md5 => Digest::MD5::md5_hex($content) }; # remember for later checks
	    }

	    # Compare with local file
	    if ($is_local_server && $content_compare && !$done_filesystem_comparison{$url}) {
		my $bbbike_root = bbbike_root();
		(my $local_file = $url) =~ s{.*/(data|html)/}{$bbbike_root/$1/};
	    SKIP: {
		    open my $fh, $local_file
			or skip "Cannot get local file '$local_file': $!";
		    local $/;
		    my $local_contents = <$fh>;
		    eq_or_diff $content, $local_contents, "Contents in local filesystem and from remote match for $url";
		}
		$done_filesystem_comparison{$url} = 1;
	    }
	}

	($resp, $content, $dt);
    };

    # data/.modified
    my @data_defs;
    {
	my $url = "$datadir/.modified";
	my($resp, $content) = $basic_tests->($url);

	my @malformed_modified_lines;
	for my $line (split /\n/, $content) {
	    if ($line !~ m{^data/\S+\s+\d+\s+[a-fA-F0-9]+$}) {
		push @malformed_modified_lines, $line;
	    }
	}
	is_deeply \@malformed_modified_lines, [], 'all lines in .modified are OK';

	@data_defs = map {
	    my($file) = split /\s+/, $_;
	    +{ file => $file };
	} split /\n/, $content;

	ok((grep { $_->{file} eq 'data/strassen' } @data_defs), 'Found data/strassen in .modified');
	ok((grep { $_->{file} eq 'data/sehenswuerdigkeit_img/fernsehturm.gif' } @data_defs), 'Found data/sehenswuerdigkeit_img/fernsehturm.gif in .modified');
    }

    if (!$long_test) {
	@data_defs = grep { $_->{file} =~ m{^data/(strassen|sehenswuerdigkeit_img/fernsehturm.gif)$} } @data_defs;
	is @data_defs, 2, 'assert size of @data_defs';
    }

    # Files not anymore in recent .modified, but used to be shipped at
    # some point in bbbike's history.
    #
    # In case it's delivered in the current .modified (and thus
    # physically available), still set is_historical to true --- the
    # mod_perl handler may unconditionally deliver a 304 Not Modified
    # even if the file is on disk.
    for my $historical_file ('data/label') {
    FOUND_FILE: {
	    for my $data_def (@data_defs) {
		if ($data_def->{file} eq $historical_file) {
		    $data_def->{is_historical} = 1;
		    last FOUND_FILE;
		}
	    }
	    push @data_defs, { file => $historical_file, is_historical => 1 };
	}
    }

    # Simulate not-modified mode
    {
	my $runtime = 0;
	for my $data_def (@data_defs) {
	    my $file = $data_def->{file};
	    my($resp, undef, $dt) = $basic_tests->("$htmldir/$file", simulate_unmodified => 1);
	    $runtime += $dt;
	}
	push @bench_results, "Check all data files (ua=$ua_label, gzip=$do_accept_gzip): " . sprintf '%.6fs', $runtime;
    }

    # Simulate modified mode
    {
	my $runtime = 0;
	for my $data_def (@data_defs) {
	    my($file, $is_historical) = @{$data_def}{qw(file is_historical)};
	    my $allow_empty_content = $file =~ m{^data/gesperrt_[urs]$};
	    my($resp, $content, $dt) = $basic_tests->(
						      "$htmldir/$file",
						      allow_empty_content => $allow_empty_content,
						      simulate_unmodified => 0,
						      is_historical => $is_historical,
						     );
	    $runtime += $dt;

	    if ($resp->code == 304) {
		# no content checks possible here
	    } elsif ($file =~ m{^data/
			   (
			     Berlin\.coords\.data
			   | Potsdam\.coords\.data
			   | README
			   | oldnames
			   | umsteigebhf
			   | temp_blockings/bbbike-temp-blockings-optimized\.pl
			   )$}x) {
		# neither a bbd file nor an image
	    } elsif ($file =~ m{^data/[^/]+$}) {
		# content tests for bbd files
		ok(Strassen->syntax_check_on_data_string($content), "$file: No error while parsing bbd data");

		my $expected_min_lines = 1;
		if ($allow_empty_content) {
		    $expected_min_lines = 0;
		} elsif ($file eq 'data/strassen') {
		    $expected_min_lines = 100;
		}
		my $s = Strassen->new_from_data_string($content);
		cmp_ok(@{$s->data}, ">=", $expected_min_lines, "Reasonable number of lines found in data (" . scalar @{$s->data} . ")");

		if ($file eq 'data/strassen') {
		    if ($bbbike_version eq '3.16') { # Simulate old BBBike application
			local $TODO;
			$TODO = "Works only with modperl and plack" if $ENV{BBBIKE_TEST_SKIP_MODPERL} && $ENV{BBBIKE_TEST_SKIP_PLACK};

			my $count_NH = 0;
			$s->init;
			while () {
			    my $ret = $s->next;
			    last if !@{ $ret->[Strassen::COORDS] };
			    $count_NH++ if $ret->[Strassen::CAT] eq 'NH';
			}
			is $count_NH, 0, 'No cat=NH found for old client';
			is $resp->header('X-BBBike-Hacks'), 'NH', 'NH hack in HTTP header'
			    or diag <<EOF;
Make sure that the mod_perl handler BBBikeDataDownloadCompat is activated
in the bbbike-specific httpd.conf. If you cannot run mod_perl or even
do not run Apache at all, then define the environment variable
BBBIKE_TEST_SKIP_MODPERL to skip this test.
EOF
		    }
		}
	    } elsif ($file =~ m{^data/sehenswuerdigkeit_img}) {
		# content tests for image files
		my $image_info = image_info(\$content);
		ok !$image_info->{error}, "No error detected while looking at image content";
		is $image_info->{file_media_type}, $resp->header("Content-Type"), "Expected mime type";
		like $resp->header("content-encoding")||'', qr{^(|identity)$}, 'No compression for images' # note: LWP::Protocol::Net::Curl may return "identity"
		    or do {
			if (!our $deflate_img_warning_seen++) {
			    diag <<'EOF';
If mod_deflate is used, then something like

     SetEnvIfNoCase Request_URI \.(?:gif|jpe?g|png)$ no-gzip dont-vary

should be put into the Apache configuration for
the bbbike/data location; or an equivalent solution
for other systems is necessary.
EOF
			}
		    };
	    } else {
		diag "No content check for $file defined";
	    }

	}
	push @bench_results, "Fetch all data files (ua=$ua_label, gzip=$do_accept_gzip): " . sprintf '%.6fs', $runtime;
    }

    # other files in html
    {
	my $url = "$htmldir/html/newstreetform.html";
	my($resp, $content) = $basic_tests->($url);
	like($content, qr{<html}, "Could be html content");
	# Note that HTTP header (usually without charset) and meta
	# value (usually with) may contradict, but this is probably no
	# issue. See also parse_head setting above.
	like($resp->header("content-type"), qr{^text/html(;\s*charset=iso-8859-1)?$}, "Content-type check")
	    or diag($resp->as_string);
    }

}

__END__
