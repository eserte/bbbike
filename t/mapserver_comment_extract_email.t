#!/usr/bin/perl
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;

BEGIN {
    my @errors;
    for my $check (
		   q{use Test::More; 1},
		   q{defined &done_testing},
		  ) {
	if (!eval $check) {
	    push @errors, $check;
	}
    }
    if (@errors) {
	print "1..0 # skip the following prereq(s) were not met: " . join(", ", map { "q<$_>" } @errors) . "\n";
	exit;
    }
}

require "$FindBin::RealBin/../cgi/mapserver_comment.cgi";

my @warnings;
local $SIG{__WARN__} = sub { push @warnings, @_ };
local $^W = 1;

is extract_email(undef), undef, 'undefined argument';

for my $pass_s (
    'user@example.com',
    'foo.bar+tag@sub.domain.org',
    'x@x.de',
) {
    is extract_email($pass_s), $pass_s, "valid e-mail $pass_s";
    is extract_email("   $pass_s   "), $pass_s, "valid e-mail $pass_s (trim spaces)";
    is extract_email("\t$pass_s\n"), $pass_s, "valid e-mail $pass_s (trim whitespace)";
}

is extract_email('some text example@example.com another text second@email.com'), 'example@example.com', 'extracts only first email from text';

for my $fail_s (
    'plainaddress',
    'user@example',
    '@example.com',
    #'user@.example.com',
    #'user@example..com',
) {
    is extract_email($fail_s), undef, "invalid email $fail_s";
}

is_deeply \@warnings, [], 'no warnings';

done_testing;

__END__
