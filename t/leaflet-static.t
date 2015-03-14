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
	 $FindBin::RealBin,
	);
use IO::Pipe ();
use Test::More 'no_plan';

use BBBikeTest qw(tidy_check like_html libxml_parse_html eq_or_diff);

use BBBikeLeaflet::Template;

ok !eval { BBBikeLeaflet::Template->new(invalid_option => 1) };
like $@, qr{Unhandled arguments: invalid_option};

my $blt = BBBikeLeaflet::Template->new;
isa_ok $blt, 'BBBikeLeaflet::Template';

my $html;
open my $ofh, ">", \$html or die $!;
$blt->process($ofh);
like_html $html, qr{<title>.*</title>};
tidy_check $html;
libxml_parse_html($html);
pass 'no error while trying to parse with XML::LibXML';

my $html2;
my $script = "$FindBin::RealBin/../miscsrc/static_leaflethtml.pl";
my $ofh2 = IO::Pipe->new->reader($^X, $script, '-rooturl', '', '--no-show-feature-list')
    or die $!;
while(<$ofh2>) {
    $html2 .= $_;
}
if ($^O eq 'MSWin32') {
    $html2 =~ s{\r}{}g;
}

eq_or_diff $html2, $html, 'Result from static_leaflethtml.pl is the same';

my $html3 = $blt->as_string;
eq_or_diff $html3, $html, 'as_string output is the same';

{
    my $blt2 = BBBikeLeaflet::Template->new(shortcut_icon => "images/my_favicon.png");
    my $html = $blt2->as_string;
    like_html $html, qr{shortcut icon.*href="images/my_favicon.png"}, 'shortcut icon ref found';
}

__END__
