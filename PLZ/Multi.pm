# -*- perl -*-

#
# $Id: Multi.pm,v 1.5 2003/08/08 19:17:23 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use Getopt::Long qw(GetOptions);
BEGIN {
    if (!eval q{ use File::Temp qw(tempfile); 1; }) {
	*tempfile = sub { (undef, "/tmp/plzmulti.$$") };
    }
}
use File::Copy qw(move);
use File::Basename qw(basename);
use File::Spec;

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
	if (ref $_ && UNIVERSAL::isa($_, "Strassen")) {
	    # convert into PLZ file
	    require Strassen::Strasse;
	    require File::Temp;
	    my($fh, $filename) = File::Temp::tempfile(UNLINK => 1);
	    my $s = $_;
	    $s->init;
	    while(1) {
		my $r = $s->next;
		last if !@{ $r->[Strassen::COORDS()] };
		my $middle = $r->[Strassen::COORDS()]->[$#{ $r->[Strassen::COORDS()] }/2];
		my($str, @cityparts) = Strasse::split_street_citypart($r->[Strassen::NAME()]);
		if (!@cityparts) {
		    print $fh "$str|||$middle\n";
		} else {
		    for my $citypart (@cityparts) {
			print $fh "$str|$citypart||$middle\n";
		    }
		}
	    }
	    close $fh;
	    $_ = $filename;
	} elsif (!File::Spec->file_name_is_absolute($_)) {
	    for my $dir (@Strassen::datadirs) {
		my $f = File::Spec->catfile($dir, $_);
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
	system("cat @files | sort -u > $temp"); # XXX what on non-Unix?
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
