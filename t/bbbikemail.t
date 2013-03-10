#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

BEGIN {
    if (!eval q{
	use URI;
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More, and/or URI modules\n";
	exit;
    }
}

plan tests => 2;

use Getopt::Long;

use BBBikeMail;

my $do_interactive;
my $body_length;
GetOptions(
	   "interactive" => \$do_interactive,
	   "body-length=i" => \$body_length,
	  )
    or die "usage: $0 [-interactive] [-body-length bytes]\n";

my @test_args = (
		 'test@example.org',
		 'subject',
		 ($body_length ? _generate_body($body_length): 'body'),
		 CC => 'testcc@example.org',
		);

{
    my $url = BBBikeMail::create_mailto_url(@test_args);
    my $u = URI->new($url);
    is $u->scheme, 'mailto';
}

SKIP: {
    skip "Interactive tests only with -interactive switch", 1
	if !$do_interactive;

    BBBikeMail::send_mail_via_browser(@test_args);
    pass "sent mail via browser (maybe)";
}

sub _generate_body {
    my $length = shift;

    # Using a good string here is tricky: a space is transformed into
    # a URI-escaped "%20" sequence and takes therefore more bytes than
    # wished. A "-" is OK, because it's not escaped, but the text is
    # still wrapped in the mail editor window. (But that is not true
    # everywhere, e.g. I saw only one line in thunderbird running on
    # Windows)
    my $s = 'Lorem-ipsum-';

    my $times = int($length/length($s)) - 1;
    my $body = '';
    if ($times > 0) {
	$body .= $s x $times;
    }
    $body .= 'x' x ($length - length($body));
    $body;
}

__END__

=head1 NOTES

=head2 Maximum C<-body-length> in B<BBBikeMail::send_mail_via_browser>

this is limited by things like maximum cmdline length or so. Some
research showed the following numbers:

=over

=item * FreeBSD 9.0, with firefox configured to start thunderbird

Maximum is about 32K. If the body is larger, then it's cropped.

=item * Debian/wheezy, with iceweasel configured to start icedove

Maximum is about 32K. If the body is larger, then it's cropped.

=item * Windows XP, with thunderbird 2.0.0.18 (20081105)

Maximum is somewhere beetween 1900 Bytes and 2000 Bytes. If the body
is larger, then the mail program does not start at all.

=back

=head2 Supported configurations for B<BBBikeMail::send_mail_via_browser>

Firefox (at least the version which comes with FreeBSD 9.0) shows some
alternatives to use for the C<mailto:> protocol: Opera, GMail, Yahoo,
and an own application. I tried Yahoo, but the C<mailto:> URL was not
properly handled; the whole URL (including the "mailto:" scheme)
appeared in the "To" field. Using B<thunderbird> as an application
worked fine.

=cut
