#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/..");

BEGIN {
    if (!eval q{
	use JSON::XS;
	use LWP::UserAgent;
	use Test::More;
	1;
    }) {
	print "1..0 # skip no JSON::XS, LWP::UserAgent and/or Test::More module(s)\n";
	exit;
    }
}

use BBBikeTest qw($cgidir);

plan tests => 12;

my $ua = LWP::UserAgent->new;
$ua->agent('BBBikeTest/1.0');

my $cgiurl = "$cgidir/bbbike-test.cgi";

{
    my $data = do_revgeocode_api_call(8.4704348, 49.6046202, 'outside scope (Mannheim)');
    is_deeply($data, {crossing  => undef,
		      bbbikepos => undef,
		      origlon => 8.4704348,
		      origlat => 49.6046202,
		     });
}

{
    my $data = do_revgeocode_api_call(13.460589, 52.507395, undef, cleanorig => 1);
    is_deeply($data, {crossing  => "Simplonstr./Seumestr.", # "Niemannstr." intentionally stripped in API
		      bbbikepos => '14252,11368'});
}

{
    my $data = do_revgeocode_api_call(13.459998, 52.509047, 'umlauts in result', cleanorig => 1);
    is_deeply($data, {crossing  => 'Wühlischstr./Gärtnerstr. (Friedrichshain)',
		      bbbikepos => '14211,11552'});
}

{
    my $data = do_revgeocode_api_call(13.422158, 52.495352, 'find really nearest crossing', cleanorig => 1);
    is_deeply($data, {crossing => 'Maybachufer/Kottbusser Damm',
		      bbbikepos => '11543,10015'});
}

{
    my $data = do_revgeocode_api_call(13.456276, 52.509924, 'coord at beginning of street', cleanorig => 1);
    is_deeply($data, {crossing  => 'Wühlischstr./Gärtnerstr. (Friedrichshain)',
		      bbbikepos => '14211,11552'});
}

{
    my $data = do_revgeocode_api_call(13.468140, 52.507088, 'coord at end of street', cleanorig => 1);
    is_deeply($data, {crossing  => 'Seumestr./Wühlischstr.',
		      bbbikepos => '14305,11514'});
}

sub do_revgeocode_api_call {
    my($lon,$lat,$testname,%opts) = @_;
    my $cleanorig = delete $opts{cleanorig};
    my $url = $cgiurl . "?api=revgeocode;lon=$lon;lat=$lat";
    my $resp = $ua->get($url);
    ok($resp->is_success, "revgeocode API call" . (defined $testname ? ", $testname" : ''))
	or diag $resp->as_string;
    my $data = decode_json $resp->decoded_content(charset => 'none');
    if ($cleanorig) {
	delete $data->{$_} for (qw(origlon origlat));
    }
    $data;
}


__END__
