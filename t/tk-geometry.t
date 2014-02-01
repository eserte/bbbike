#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";

use Test::More 'no_plan';

use Tk::GeometryCalc qw(crop_geometry parse_geometry_string);

{
    my $top = MockTkToplevel->new(screenwidth => 1920, screenheight => 1080);
    my @max_extends = (0,0,$top->screenwidth-10,$top->screenheight-24);

    {
	my @want_extends = parse_geometry_string('1894x1053+0+0');
	crop_geometry($top, \@want_extends, \@max_extends);
	is_deeply(\@want_extends, ["+0","+0",1894,1053], "no-op");
    }

    {
	local $TODO = "negative x/y coordinates not handled correctly";

	my @want_extends = parse_geometry_string('800x600-0-0');
	crop_geometry($top, \@want_extends, \@max_extends);
	is_deeply(\@want_extends, [1120,480,800,600], "negative x/y coordinates");
    }

    {
	my @want_extends = parse_geometry_string('1914x1053+1920+0');
	crop_geometry($top, \@want_extends, \@max_extends);
	is_deeply(\@want_extends, ["0","+0",1910,1053], "handle exceeded x coordinate");
    }
}

{
    package
	MockTkToplevel;
    sub new { my($class, %args) = @_; bless { %args }, $class }
    sub screenwidth  { shift->{screenwidth} }
    sub screenheight { shift->{screenheight} }
}

__END__
