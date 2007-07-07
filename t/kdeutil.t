#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: kdeutil.t,v 1.4 2007/07/07 16:42:15 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }

    if ($^O eq 'MSWin32') {
	print "1..0 # skip: test meaningless on Windows\n";
	exit;
    }
}

plan tests => 33;

use_ok("KDEUtil");

my $k = KDEUtil->new;
isa_ok($k, "KDEUtil");

for my $path_type (qw(xdgconf-menu xdgdata-apps xdgdata-dirs)) {
    my($lp,$gp) = $k->get_kde_path($path_type);
    ok($lp, "Got path type <$path_type> (user)");
    ok(-d $lp, "Directory for <$path_type> exists");
    ok($gp, "Got path type <$path_type> (global)");
    ok(-d $gp, "Directory for <$path_type> exists");

    my($lp2,$gp2) = $k->get_kde_path($path_type);
    is($lp,$lp2, "2nd call (cached)");
    is($gp,$gp2, "2nd call (cached)");

    my($ip) = $k->get_kde_install_path($path_type);
    ok($ip, "Got install directory for path type <$path_type>");
    ok(-d $ip, "Install directory <$ip> is an existing directory");
    #is($ip, $gp, "Matches 2nd element of get_kde_path result"); # This is not true
}

for my $path_type (qw(exe)) {
    my $p = $k->get_kde_install_path($path_type);
    ok($p, "Got install directory for path type <$path_type>");
    ok(-d $p, "Install directory <$p> is an existing directory");
}

for my $path_type (qw(desktop document)) {
    my $p = $k->get_kde_user_path($path_type);
    ok($p, "Got user directory for path type <$path_type>");
    ok(-d $p, "User directory <$p> is an existing directory");
}

{
    my($p) = $k->get_kde_path("non-existing-path-type");
    ok(!$p, "Tried to get non existing path type")
	or diag("Got <$p>");
}


__END__
