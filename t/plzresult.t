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
	    my($res0) = $plz->look('Auerbacher Str.');
	    my $res2 = $plz->make_result($res0);
	    my($res3) = $plz->look('Auerbacher Str.', AsObjects=>1);
	    my $res = PLZ::Result->new($plz, $res0);
	    isa_ok $res, 'PLZ::Result';
	    is_deeply $res->as_arrayref, $res0, 'roundtrip';
	    is_deeply $res, $res2, 'No difference between make_result and direct construction';
	    is_deeply $res, $res3, 'No difference when using AsObjects=>1';
	    is $res->get_name, 'Auerbacher Str.', 'result from look()';
	    is $res->get_street_type, 'street';
	    is $res->get_field('type'), 'oldname';
	    is $res->get_field('ref'), 'Auerbachstr.';
	    is $res->get_field('does-not-exist'), undef;

	    my $cloned_res = $res->clone;
	    is_deeply $cloned_res, $res, 'clone';
	    is_deeply $cloned_res->as_arrayref, $res0, 'roundtrip of cloned object';

	    # changing fields
	    $res->add_field('new-field','new-field-value');
	    is $res->get_field('new-field'),'new-field-value', 'freshly added value';
	    $res->set_citypart('OtherCitypart');
	    is $res->get_citypart, 'OtherCitypart';
	    is $cloned_res->get_citypart, 'Grunewald', 'clone is still unchanged';

	    is_deeply $res->as_arrayref, ["Auerbacher Str.", "OtherCitypart", 14193, "723,8753", "", "type=oldname", "ref=Auerbachstr.", "new-field=new-field-value"], 'arrayref after chaning';
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

	{
	    my $res = ['Heerstr.', [qw(Staaken Westend Wilhelmstadt)], [qw(13591 13593 13595 14052 14055)], '-5531,12291'];
	    $res = PLZ::Result->new($plz, $res);
	    my $combined_res = $res->combined_elem_to_string_form;
	    is $combined_res->get_name, 'Heerstr.';
	    is $combined_res->get_citypart, 'Staaken, Westend, Wilhelmstadt';
	    is $combined_res->get_zip, '13591, 13593, 13595, 14052, 14055';
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
