# -*- perl -*-

#
# $Id: BBBikeEditUtil.pm,v 1.5 2003/01/08 18:47:01 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeEditUtil;
use strict;
use vars qw(%file2base);

sub base {
    my $datadir = shift || $main::datadir;
    open(BASE, "$datadir/BASE") or die "Can't open $datadir/BASE: $!";
    while(<BASE>) {
	chomp;
	my($file, $base) = split(/\s+/, $_);
	$file2base{$file} = $base;
    }
    close BASE;
    %file2base;
}

# XXX maybe should not return just the basenames...
sub get_orig_files {
    my $datadir = shift || $main::datadir;
    my @files;
    opendir(DIR, $datadir) or die "Can't opendir $datadir: $!";
    my $f;
    while(defined(my $f = readdir DIR)) {
	if (-f "$datadir/$f" && $f =~ /-orig$/) {
	    push @files, $f;
	}
    }
    closedir DIR;
    my $fr_file = "$FindBin::RealBin/misc/fragezeichen-orig";
    if (-e $fr_file) {
 	push @files, $fr_file;
    }
    sort @files;
}

1;

__END__
