# -*- perl -*-

#
# $Id: Multi.pm,v 1.7 2003/09/02 12:42:35 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use Getopt::Long qw(GetOptions);
BEGIN {
    if (!eval q{ use File::Temp qw(tempfile); 1; }) {
	*tempfile = sub {
	    my $f = "/tmp/plzmulti.$$";
	    open(TEMP, ">$f") or die $!;
	    (\*TEMP, $f);
        };
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

    my $need_seen_hash;
    for (@files) {
	if (ref $_ && UNIVERSAL::isa($_, "Strassen")) {
	    $need_seen_hash = 1;
	}
    }

    my @cachefile_names;
    my %seen;
    for (@files) {
	if (!ref $_) {
	    # make $_ an absolute pathname
	    if (!File::Spec->file_name_is_absolute($_)) {
		for my $dir (@Strassen::datadirs) {
		    my $f = File::Spec->catfile($dir, $_);
		    if (-r $f) {
			$_ = $f;
			push @cachefile_names, basename($_);
			last;
		    }
		}
	    }

	    my $f = $_;
	    if ($need_seen_hash) {
		local $_; # just to make sure...
		my $plz = PLZ->new($f);
		$plz->load;
		%seen = (%seen,
			 %{
			     $plz->make_any_hash(PLZ::FILE_NAME(),
						 PLZ::FILE_CITYPART())
			 });
	    }
	}
    }

    # 2nd pass: .bbd files
    for (@files) {
	if (ref $_ && UNIVERSAL::isa($_, "Strassen")) {
	    # convert into PLZ file
	    require Strassen::Strasse;
	    my($fh, $filename) = tempfile(UNLINK => 1);
	    my $s = $_;
	    $s->init;
	    while(1) {
		my $r = $s->next;
		last if !@{ $r->[Strassen::COORDS()] };
		my $middle = $r->[Strassen::COORDS()]->[$#{ $r->[Strassen::COORDS()] }/2];
		my($str, @cityparts) = Strasse::split_street_citypart($r->[Strassen::NAME()]);
		if (!@cityparts) {
		    if (!$seen{$str}) {
			print $fh "$str|||$middle\n";
		    }
		} else {
		    for my $citypart (@cityparts) {
			if (!$seen{$str}{$citypart}) {
			    print $fh "$str|$citypart||$middle\n";
			}
		    }
		}
	    }
	    close $fh;
	    push @cachefile_names, $_->file;
	    $_ = $filename;
	}
    }

    my $combined;

    my $cachetoken = "multiplz_" .
	             join("_", map { basename $_ } @cachefile_names);
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
