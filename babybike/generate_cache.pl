#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: generate_cache.pl,v 1.4 2003/08/24 23:29:56 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# pre-generate caches

use strict;
use FindBin;
# No RealBin here --- make it possible to use from other directories too
use lib ("$FindBin::Bin", "$FindBin::Bin/lib");
use BBBikeRouting;
use Strassen::Core;
use Getopt::Long;

my $v = 1;
my $algorithm = 'C-A*';
my $usexs = 0;
my $scopes = "city,region";

if (!GetOptions("v!" => \$v,
		"algorithm=s" => \$algorithm,
		"usexs!" => \$usexs,
		"scopes=s" => \$scopes,
	       )) {
    die "usage: $0 [-[no]v] [-algorithm algorithm] [-[no]usexs] [-scopes scope1,scope2,...]"
}

Strassen::set_verbose($v);

my $routing = BBBikeRouting->new->init_context;
my $context = $routing->Context;
$context->Algorithm($algorithm);
$context->UseNetServer(0);
$context->UseCache(1);
$context->UseXS(0); # see comment in tkbabybike
$context->PreferCache(1);

for my $scope (split /,/, $scopes) {
    my $pid = fork;
    if ($pid == 0) {
	warn "Building for scope $scope...\n";
	$context->Scope($scope);
	$routing->init_net;
	$routing->init_zip;
	$routing->init_crossings;
	$routing->init_str->make_grid(UseCache => 1, Exact => 1);
	warn "... scope $scope done\n";
	exit 0;
    }
    waitpid($pid, 0);
}

__END__
