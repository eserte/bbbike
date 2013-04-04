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

use File::Temp qw(tempfile);
use Test::More 'no_plan';

use PLZ ();
use PLZ::Multi ();

{
    my($tmpfh,$tmpfile) = tempfile(UNLINK => 1, SUFFIX => "_plzext")
	or die $!;
    print $tmpfh <<EOF;
Auerbachstr.|Grunewald|14193|723,8753||
Auerbacher Str.|Grunewald|14193|723,8753||type=oldname|ref=Auerbachstr.
EOF
    close $tmpfh
	or die $!;

    {
	my $plz = PLZ->new($tmpfile);

	{
	    my($res) = $plz->look('Auerbacher Str.');
	    is $res->[PLZ::LOOK_NAME()], 'Auerbacher Str.', 'result from look()';
	    is $plz->get_street_type($res), 'street';
	    is $plz->get_extfield($res, 'type'), 'oldname';
	    is $plz->get_extfield($res, 'ref'), 'Auerbachstr.';
	    is $plz->get_extfield($res, 'does-not-exist'), undef;
	    is_deeply [$plz->get_extfields($res, 'ref')], ['Auerbachstr.'], 'get_extfields';
	    is_deeply [$plz->get_extfields($res, 'does-not-exist')], [], 'empty result for get_extfields';
	}

	{
	    my($res) = $plz->look_loop('Auerbacher Str.');
	    $res = $res->[0];
	    is $res->[PLZ::LOOK_NAME()], 'Auerbacher Str.', 'result from look_loop()';
	    is $plz->get_street_type($res), 'street';
	    is $plz->get_extfield($res, 'type'), 'oldname';
	    is $plz->get_extfield($res, 'ref'), 'Auerbachstr.';
	    is $plz->get_extfield($res, 'does-not-exist'), undef;
	    is_deeply [$plz->get_extfields($res, 'ref')], ['Auerbachstr.'], 'get_extfields';
	    is_deeply [$plz->get_extfields($res, 'does-not-exist')], [], 'empty result for get_extfields';
	}
    }

    {
	my $multiplz = PLZ::Multi->new($tmpfile, -cache => 0, -addindex => 1, '-usefmtext');
	isa_ok $multiplz, 'PLZ';
	$multiplz->load;

	{
	    my($res) = $multiplz->look('Auerbacher Str.');
	    is $res->[PLZ::LOOK_NAME()], 'Auerbacher Str.', 'result from look() on PLZ::Multi object';
	    is $multiplz->get_street_type($res), 'street';
	    is $multiplz->get_extfield($res, 'type'), 'oldname';
	    is $multiplz->get_extfield($res, 'ref'), 'Auerbachstr.';
	    is $multiplz->get_extfield($res, 'i'), 0, 'file index';
	    is $multiplz->get_extfield($res, 'does-not-exist'), undef;
	    is_deeply [$multiplz->get_extfields($res, 'ref')], ['Auerbachstr.'], 'get_extfields';
	    is_deeply [$multiplz->get_extfields($res, 'does-not-exist')], [], 'empty result for get_extfields';
	}
    }
}

__END__
