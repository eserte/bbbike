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
use PLZ::Result ();

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
	    my $res2 = $plz->make_result($res);
	    my($res3) = $plz->look('Auerbacher Str.', AsObjects=>1);
	    $res = PLZ::Result->new($plz, $res);
	    isa_ok $res, 'PLZ::Result';
	    is_deeply $res, $res2, 'No difference between make_result and direct construction';
	    is_deeply $res, $res3, 'No difference when using AsObjects=>1';
	    is $res->get_name, 'Auerbacher Str.', 'result from look()';
	    is $res->get_street_type, 'street';
	    is $res->get_field('type'), 'oldname';
	    is $res->get_field('ref'), 'Auerbachstr.';
	    is $res->get_field('does-not-exist'), undef;
	    $res->add_field('new-field','new-field-value');
	    is $res->get_field('new-field'),'new-field-value', 'freshly added value';
	}

	{
	    my($res_array) = $plz->look_loop('Auerbacher Str.', AsObjects=>1);
	    my $res = $res_array->[0];
	    isa_ok $res, 'PLZ::Result';
	    is $res->get_name, 'Auerbacher Str.', 'look_loop with AsObjects=>1 result';
	}

	{
	    my($res_array) = $plz->look_loop_best('Auerbacher Str.', AsObjects=>1);
	    my $res = $res_array->[0];
	    isa_ok $res, 'PLZ::Result';
	    is $res->get_name, 'Auerbacher Str.', 'look_loop_best with AsObjects=>1 result';
	}
    }

    {
	my $multiplz = PLZ::Multi->new($tmpfile, -cache => 0, -addindex => 1, '-usefmtext');
	$multiplz->load;

	{
	    my($res) = $multiplz->look('Auerbacher Str.');
	    $res = $multiplz->make_result($res);
	    is $res->get_name, 'Auerbacher Str.', 'result from look() on PLZ::Multi object';
	    is $res->get_street_type($res), 'street';
	    is $res->get_field('type'), 'oldname';
	    is $res->get_field('ref'), 'Auerbachstr.';
	    is $res->get_field('i'), 0, 'file index';
	    is $res->get_field('does-not-exist'), undef;
	}
    }

}

__END__
