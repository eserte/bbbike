#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);

use Data::Dumper;
use Getopt::Long;

use BBBikeTest qw(check_cgi_testing);
use BBBikeUtil qw(is_in_path);

check_cgi_testing;

BEGIN {
    if (($ENV{USER}||'') ne 'eserte' || do { require Sys::Hostname; Sys::Hostname::hostname() !~ m{cvrsnica}}) {
	print "1..0 # skip Should not be used everywhere...\n";
	exit;
    }
    if (!eval q{
	use Test::More;
	use LWP::UserAgent;
	use URI;
	use URI::QueryParam ();

	use W3C::LogValidator::LinkChecker 1.005;
	1;
    }) {
	print "1..0 # skip no Test::More, LWP::UserAgent, URI and/or W3C::LogValidator modules\n";
	exit;
    }

    if (!is_in_path("checklink")) {
	print "1..0 # skip W3C::LogValidator::LinkChecker needs the checklink program\n";
	exit;
    }
}

my %config = ("verbose" => 0,
	      AuthorizedExtensions => ".html .xhtml .phtml .htm .shtml .php .svg .xml / .cgi",
	     );
GetOptions(\%config, "verbose|v+", "rooturl=s")
    or die <<EOF;
usage: $0 [-v [-v ...]] [-rooturl url]

Use -rooturl http://bbbike.de/cgi-bin for testing
real URL.
EOF
my $rooturl = delete $config{rooturl} || "http://bbbike.dyndns.org/bbbike/cgi";

my @uri_defs = (
		{ uri => "$rooturl/bbbike.cgi", accepted_html_errors => 1 },
		{ uri => "$rooturl/bbbike.cgi?start=heerstr&starthnr=&startcharimg.x=&startcharimg.y=&startmapimg.x=&startmapimg.y=&via=&viahnr=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=simplonstr&zielhnr=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=&scope=", accepted_html_errors => 3 },
		{ uri => "$rooturl/bbbike.cgi?startname=Heerstr.+%28Spandau%2C+Charlottenburg%29&startplz=14052%2C+14055&startc=1381%2C11335&zielname=Simplonstr.&zielplz=10245&zielc=14752%2C11041&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&pref_green=&scope=", accepted_html_errors => 1 },
		{ uri => "$rooturl/bbbike.cgi?startname=Heerstr.%20(Spandau%2C%20Charlottenburg);startplz=14052%2C%2014055;startc=1381%2C11335;zielname=Simplonstr.;zielplz=10245;zielc=14752%2C11041;pref_seen=1;pref_speed=20;pref_cat=;pref_quality=;pref_green=;scope=;output_as=print", accepted_html_errors => 1 },
		{ uri => "$rooturl/bbbike.cgi?all=1", accepted_html_errors => 1 },
		{ uri => "$rooturl/bbbike.cgi?info=1", accepted_html_errors => 1 },
	   );

plan tests => 1 + 2 * scalar(@uri_defs);

my %validator_urls = (
		      html => 'http://validator.w3.org/check',
		      css  => 'http://jigsaw.w3.org/css-validator/validator',
		     );
my $ua = LWP::UserAgent->new;

{
    my $validator = W3C::LogValidator::LinkChecker->new(\%config);
    $validator->uris(map { $_->{uri} } @uri_defs);
    my %results = $validator->process_list;
    is(scalar(@{$results{trows}}), 0, "Link checking")
	or diag Dumper(\%results) . "\nTry http://validator.w3.org/checklink for more information";
}

# {
#     my $validator = W3C::LogValidator::CSSValidator->new(\%config);
#     $validator->uris(map { $_->{uri} } @uri_defs);
#     my %results = $validator->process_list;
#     is($validator->valid_err_num, 0, "No CSS validation errors")
# 	or diag Dumper(\%results);
# }

for my $uri_def (@uri_defs) {
    any_validate('css', $uri_def);
}

for my $uri_def (@uri_defs) {
    any_validate('html', $uri_def);
}

sub any_validate {
    my($type, $uri_def) = @_;
    die "Invalid type '$type'" if $type !~ m{^(html|css)$};
    my($uri, $accepted_errors) = @{$uri_def}{'uri', 'accepted_'.$type.'_errors'};
    my $testname = "$type validation for $uri";
    my $validate_uri_obj = URI->new($validator_urls{$type});
    $validate_uri_obj->query_form_hash({ uri => $uri });
    my $resp = $ua->head($validate_uri_obj->as_string);
    if (!$resp->is_success) {
	local $TODO = "no successful response from w3c validator, maybe network problems";
	fail $testname;
    } else {
	my $validator_status = $resp->header('X-W3C-Validator-Status');
	if ($validator_status eq 'Abort') {
	    local $TODO = "w3c validator returns Abort, maybe network problems";
	    fail $testname;
	} elsif ($validator_status eq 'Valid') {
	    pass $testname;
	} elsif ($validator_status eq 'Invalid') {
	    my $validator_errors = $resp->header('X-W3C-Validator-Errors');
	    if ($validator_errors <= $accepted_errors) {
		local $TODO = "currently $accepted_errors known error(s) on page (sizes attribute)";
		fail $testname;
	    } else {
		is $validator_errors, 0, "$testname (number of errors is zero)";
	    }
	}
    }
}

__END__
