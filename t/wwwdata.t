#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

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
	1;
    }) {
	print "1..0 # skip no Test::More, Image::Info, HTTP::Date, LWP::ConnCache and/or LWP::UserAgent module\n";
	exit;
    }
}

use Getopt::Long;
use Image::Info qw(image_info);

use Strassen::Core;

use BBBikeTest qw(check_cgi_testing);

check_cgi_testing;

if (!defined &note) { *note = \&diag }

plan tests => 48;

my $htmldir = $ENV{BBBIKE_TEST_HTMLDIR};
if (!$htmldir) {
    $htmldir = "http://localhost/bbbike";
}

GetOptions("htmldir=s" => \$htmldir,
	   "live" => sub {
	       require BBBikeVar;
	       no warnings 'once';
	       $htmldir = $BBBike::BBBIKE_UPDATE_WWW;
	   }),
    or die "usage: $0 [-htmldir ... | -live]";

my $conn_cache = LWP::ConnCache->new(total_capacity => 10);

my $ua = LWP::UserAgent->new(conn_cache => $conn_cache);
$ua->parse_head(0); # too avoid confusion with Content-Type in http header and meta tags
$ua->agent('BBBike-Test/1.0');
$ua->env_proxy;

my $ua316 = LWP::UserAgent->new(conn_cache => $conn_cache);
$ua316->parse_head(0);
$ua316->agent('bbbike/3.16 (Http/4.01) BBBike-Test/1.0');
$ua316->env_proxy;

my $datadir = "$htmldir/data";

my %contents;

my %compress_results;

for my $do_accept_gzip (0, 1) {
    my $basic_tests = sub {
	my($url, %args) = @_;
	my $ua = $args{ua} || $ua;
	my $contentcompare = exists $args{contentcompare} ? $args{contentcompare} : 1;
	$ua->default_header('Accept-Encoding' => $do_accept_gzip ? "gzip" : undef);
	my $resp = $ua->get($url);
	my $got_gzipped = ($resp->header('content-encoding')||'') =~ m{\bgzip\b} ? 1 : 0;
	my($content_type) = $resp->content_type;
	$compress_results{$do_accept_gzip}->{$content_type}->{$got_gzipped}++;
	ok($resp->is_success,
	   "GET $url " .
	   ($do_accept_gzip ? "(accept gzipped)" : "(accept uncompressed)") . " " .
	   ($got_gzipped ? "(got gzipped)" : "(got uncompressed)")
	  )
	    or diag $resp->status_line;
	my $content = $resp->decoded_content;
	ok(length $content, "Non-empty content");
	if ($contentcompare) {
	    $contents{$url}{$do_accept_gzip} = $content; # remember for later checks
	}
	($resp, $content);
    };

    {
	my $url = "$datadir/.modified";
	my($resp, $content) = $basic_tests->($url);
	my @error_lines;
	for my $line (split /\n/, $content) {
	    if ($line !~ m{^data/\S+\s+\d+\s+[a-fA-F0-9]+$}) {
		push @error_lines, $line;
	    }
	}
	is(@error_lines, 0, "Check data in .modified")
	    or diag "Found unexpected lines in .modified\n@error_lines[0..9]";
    }

    {
	my $url = "$datadir/strassen";
	my($resp, $content) = $basic_tests->($url);
	my $s = eval { Strassen->new_from_data_string($content) };
	is($@, "", "No error while parsing bbd data");
	cmp_ok(@{$s->data}, ">=", 100, "Reasonable number of lines found in data (" . scalar @{$s->data} . ")");
    }

    {
	my $url = "$datadir/sehenswuerdigkeit_img/fernsehturm.gif";
	my($resp, $content) = $basic_tests->($url);
	my $image_info = image_info(\$content);
	ok(!$image_info->{error}, "No error detected while looking at image content");
	is($image_info->{file_media_type}, $resp->header("Content-Type"), "Expected mime type");
	is $resp->header("content-encoding")||'', '', 'No compression for images'
	    or diag <<'EOF';
If mod_deflate is used, then something like

     SetEnvIfNoCase Request_URI \.(?:gif|jpe?g|png)$ no-gzip dont-vary

should be put into the Apache configuration for
the bbbike/data location; or an equivalent solution
for other systems is necessary.
EOF
    }

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

    # Simulate old BBBike application
    {
	my $url = "$datadir/strassen";
	my($resp, $content) = $basic_tests->($url,
					     ua => $ua316,
					     contentcompare => 0, # do not check data/strassen twice
					    );
	my $s = eval { Strassen->new_from_data_string($content) };
	is($@, "", "No error while parsing bbd data");
	my $count_NH = 0;
	$s->init;
	while () {
	    my $ret = $s->next;
	    last if !@{ $ret->[Strassen::COORDS] };
	    $count_NH++ if $ret->[Strassen::CAT] eq 'NH';
	}
	is $count_NH, 0, 'No cat=NH found for old client';
	is $resp->header('X-BBBike-Hacks'), 'NH', 'NH hack in HTTP header';
    }
}

{
    # Plack::Middleware::ConditionalGET is unfortunately lazy
    # and does an explicite 'eq' in the If-Modified-Since. It's
    # even allowed by RFC 2616 14.25, it seems. So use the
    # real modtime of the data/label file, and if this fails for
    # some reason (data/label not included anymore), then fallback
    # to "now".
    my $modtime = (stat("$FindBin::RealBin/../data/label"))[9];    
    my $resp = $ua316->get("$datadir/label", 'If-Modified-Since' => time2str($modtime || time));
    ok $resp->code==304, 'Probably data/label hack'
	or diag $resp->as_string;
}

while(my($url,$v) = each %contents) {
    ok $v->{0} eq $v->{1}, "Same contents for $url";
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
	note "The following Content-Type are sometimes compressed, sometimes uncompressed: " . join(", ", sort keys %mixed_compression_ct);
    }
}

__END__
