# -*- perl -*-

#
# $Id: Multi.pm,v 1.1 2003/07/14 06:37:01 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package PLZ::Multi;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use Getopt::Long qw(GetOptions);
use File::Temp qw(tempfile);
use File::Copy qw(move);
use File::Basename qw(basename);
use File::Spec::Functions qw(file_name_is_absolute catfile);

use PLZ;
use Strassen::Core;
use Strassen::Util;

sub new {
    my($class, @files_and_args) = @_;
    local @ARGV = @files_and_args;
    my %args;
    if (!GetOptions(\%args, "cache=i")) {
	die "usage!";
    }
    my @files = @ARGV;
    if (!@files) {
	die "No files specified";
    }

    for (@files) {
	if (!file_name_is_absolute($_)) {
	    for my $dir (@Strassen::datadirs) {
		my $f = catfile($dir, $_);
		if (-r $f) {
		    $_ = $f;
		    last;
		}
	    }
	}
    }

    my $combined;

    my $cachetoken = "multiplz_" . join("_", map { basename $_ } @files);
    my $cachefile = Strassen::Util::get_cachefile($cachetoken);
    if ($args{cache}) {
	if (Strassen::Util::valid_cache($cachetoken, \@files)) {
	    $combined = $cachefile;
	}
    }

    if (!defined $combined) {
	my($fh, $temp) = tempfile(UNLINK => 1);
	system("cat @files | sort > $temp");
	if ($args{cache}) {
	    $combined = $cachefile;
	    move($temp, $combined);
	} else {
	    $combined = $temp;
	}
    }

    PLZ->new($combined);
}

1;

__END__
