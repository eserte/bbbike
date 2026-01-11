use strict;
use warnings;

BEGIN {
    for my $mod (qw(Test::More Plack::Test HTTP::Request::Common)) {
	if (!eval qq{ use $mod; 1 }) {
	    print "1..0 # skip no $mod available\n";
	    exit;
	}
    }
}

use FindBin;
use lib (
    "$FindBin::RealBin",
    "$FindBin::RealBin/..",
    "$FindBin::RealBin/../cgi",
);

use BBBikeTest qw(check_cgi_testing);
use Getopt::Long;

GetOptions("doit" => \my $doit)
    or die "usage: $0 [--doit]\n";
plan skip_all => 'Please set --doit to run tests' if !$doit; # XXX currently creating directories/files in /tmp, would be better if a temporary directory could be provided for tests

plan 'no_plan';

my $app = do "$FindBin::RealBin/../cgi/bbbike-asch.psgi";
is ref $app, 'CODE', 'loaded bbbike-asch.psgi app';

test_psgi $app, sub {
    my $cb = shift;

    {
	my @warnings;
	local $SIG{__WARN__} = sub { push @warnings, @_ };
	my $res = $cb->(GET '');
	is $res->code, 404, 'missing query string';
	like "@warnings", qr{Cannot load old session};
	like "@warnings", qr{Cannot tie session with id  at};
    }

    {
	my @warnings;
	local $SIG{__WARN__} = sub { push @warnings, @_ };
	my $res = $cb->(GET '?abcdef0123456789');
	is $res->code, 404, 'provided session id does not exist';
	like "@warnings", qr{A:S:Counted: Could not open file .*/ab/cdef0123456789 for reading: No such file or directory};
    }
};
