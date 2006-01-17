#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgi-validator.t,v 1.4 2006/01/16 23:19:28 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use Data::Dumper;
use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test::More;
        use W3C::LogValidator::HTMLValidator;
        use W3C::LogValidator::CSSValidator;
	use W3C::LogValidator::LinkChecker 1.005;
	1;
    }) {
	print "1..0 # skip: no Test::More and/or W3C::LogValidator modules\n";
	exit;
    }
}

BEGIN { plan tests => 3 }

my %config = ("verbose" => 0,
	      AuthorizedExtensions => ".html .xhtml .phtml .htm .shtml .php .svg .xml / .cgi",
	     );
GetOptions(\%config, "v!", "rooturl=s") or die "usage!";
my $rooturl = delete $config{rooturl} || "http://bbbike.dyndns.org";

my @uris = ("$rooturl/bbbike/cgi/bbbike.cgi",
	    "$rooturl/bbbike/cgi/bbbike.cgi?start=heerstr&starthnr=&startcharimg.x=&startcharimg.y=&startmapimg.x=&startmapimg.y=&via=&viahnr=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=simplonstr&zielhnr=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=&scope=",
	    "$rooturl/bbbike/cgi/bbbike.cgi?startname=Heerstr.+%28Spandau%2C+Charlottenburg%29&startplz=14052%2C+14055&startc=1381%2C11335&zielname=Simplonstr.&zielplz=10245&zielc=14752%2C11041&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&pref_green=&scope=",
	    "$rooturl/bbbike/cgi/bbbike.cgi?startname=Heerstr.%20(Spandau%2C%20Charlottenburg);startplz=14052%2C%2014055;startc=1381%2C11335;zielname=Simplonstr.;zielplz=10245;zielc=14752%2C11041;pref_seen=1;pref_speed=20;pref_cat=;pref_quality=;pref_green=;scope=;output_as=print",
	    "$rooturl/bbbike/cgi/bbbike.cgi?all=1",
	    "$rooturl/bbbike/cgi/bbbike.cgi?info=1",
	   );

{
    local $TODO = "A test fails --- why?";
    my $validator = W3C::LogValidator::LinkChecker->new(\%config);
    $validator->uris(@uris);
    my %results = $validator->process_list;
    is(scalar(@{$results{trows}}), 0, "Link checking")
	or diag Dumper(\%results);
}

{
    my $validator = W3C::LogValidator::CSSValidator->new(\%config);
    $validator->uris(@uris);
    my %results = $validator->process_list;
    ok($validator->valid, "CSS validation")
	or diag Dumper(\%results);
}

{
    my $validator = W3C::LogValidator::HTMLValidator->new(\%config);
    $validator->uris(@uris);
    my %results = $validator->process_list;
    ok($validator->valid, "HTML validation")
	or diag Dumper(\%results);
}

__END__
