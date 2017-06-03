#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

BEGIN {
    if (!eval q{
	use LWP::UserAgent;
	use Test::More;
	1;
    }) {
	print "1..0 # skip no LWP::UserAgent, and/or Test::More modules\n";
	exit;
    }
}

use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/..");

use CGI qw();

use BBBikeTest qw(check_cgi_testing $cgidir image_ok);

check_cgi_testing;

plan 'no_plan';

my $qrcode_cgi = "$cgidir/qrcode.cgi";
my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent("BBBike-Test/1.0");
$ua->env_proxy;

{
    my $resp = $ua->get("$qrcode_cgi/bbbike.cgi?info=1");
    ok $resp->is_success;
    is $resp->content_type, 'image/png';
    my $data = $resp->decoded_content;
    image_ok(\$data);
}

{
    my $resp = $ua->get("$qrcode_cgi/.l/bbbike.cgi?info=1");
    ok $resp->is_success, 'forcing live host';
    # In the error log should appear (if $DEBUG is on):
    #     Requested change of host to 'bbbike.de'
    is $resp->content_type, 'image/png';
    my $data = $resp->decoded_content;
    image_ok(\$data);
}

__END__
