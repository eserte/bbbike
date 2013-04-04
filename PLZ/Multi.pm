# -*- perl -*-

#
# $Id: Multi.pm,v 1.19 2008/04/21 21:28:51 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package PLZ::Multi;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.19 $ =~ /(\d+)\.(\d+)/);

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

#XXX caching funktioniert anscheinend nicht richtig!
sub new {
    my($class, @files_and_args) = @_;
    local @ARGV = @files_and_args;
    my %args;
    if (!GetOptions(\%args, "cache=i", "addindex=i", "preferfirst=i", "usefmtext!")) {
	die "usage!";
    }
    my $preferfirst = $args{preferfirst};
    my @in = @ARGV;
    if (!@in) {
	die "No files or strassen objects specified";
    }

    my $need_seen_hash;
    my @files;
    for (@in) {
	if (ref $_ && UNIVERSAL::isa($_, "Strassen")) {
	    $need_seen_hash = 1;
	    push @files, $_->dependent_files;
	} else {
	    # make $_ an absolute pathname
	    if (!File::Spec->file_name_is_absolute($_)) {
		for my $dir (@Strassen::datadirs) {
		    my $f = File::Spec->catfile($dir, $_);
		    if (-r $f) {
			$_ = $f;
		    }
		}
	    }
	    push @files, $_;
	}
    }

    my $combined;
    my $cachetoken = "multiplz_" .
	             join("_", map { basename $_ } @files);
    my $cachefile = Strassen::Util::get_cachefile($cachetoken);
    if ($args{cache}) {
	if (Strassen::Util::cache_is_recent($cachefile, \@files)) {
	    $combined = $cachefile;
	    goto FINISH;
	}
    }

    my %seen;
    for (@in) {
	if (!ref $_) {
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
    for (@in) {
	if (ref $_ && UNIVERSAL::isa($_, "Strassen")) {
	    # convert into PLZ file
	    require Strassen::Strasse;
	    my($fh, $filename) = tempfile(UNLINK => 1);
	    my $s = $_;
	    $s->init;
	    while(1) {
		my $r = $s->next;
		last if !@{ $r->[Strassen::COORDS()] };
		my $markant_point = $r->[Strassen::COORDS()]->[$preferfirst ? 0 : $#{ $r->[Strassen::COORDS()] }/2];
		my($str, @cityparts) = Strasse::split_street_citypart($r->[Strassen::NAME()]);
		if (!@cityparts) {
		    if (!$seen{$str}) {
			print $fh "$str|||$markant_point\n";
		    }
		} else {
		    for my $citypart (@cityparts) {
			if (!$seen{$str}{$citypart}) {
			    print $fh "$str|$citypart||$markant_point\n";
			}
		    }
		}
	    }
	    close $fh;
	    $_ = $filename;
	}
    }

    if (!defined $combined) {
	my($fh, $temp) = tempfile(UNLINK => 1);
	#system("cat @in | sort -u > $temp"); # XXX what on non-Unix?
	merge_and_sort(-src => \@in, -dest => $temp, -addindex => $args{addindex}, -usefmtext => !!$args{usefmtext});
	close $fh; # needed for Windows
	if ($args{cache}) {
	    $combined = $cachefile;
	    move($temp, $combined);
	} else {
	    $combined = $temp;
	}
    }

 FINISH:
    PLZ->new($combined);
}

sub merge_and_sort {
    my(%args) = @_;
    my @in_files = @{ $args{-src} };
    my $out_file =    $args{-dest};
    my $addindex =    $args{-addindex};
    my $usefmtext =   $args{-usefmtext};
    my @lines;
    {
	my $in_file_i = -1;
	for my $in_file (@in_files) {
	    $in_file_i++;
	    open(IN, $in_file) or die "Can't open $in_file: $!";
	    while (<IN>) {
		if ($addindex) {
		    if ($usefmtext) {
			my $seps = tr/|/|/;
			my $add_seps = $seps < PLZ::FILE_EXT()+1 ? "|" x (PLZ::FILE_EXT()+1-$seps) : "";
			s{$}{$add_seps|i=$in_file_i};
		    } else {
			s{$}{|$in_file_i};
		    }
		}
		push @lines, $_;
	    }
	    close IN;
	}
    }
    my %seen;
    for my $line (@lines) {
	$seen{$line} = 1;
    }
    open(OUT, "> $out_file") or die "Can't write to $out_file: $!";
    for my $line (sort keys %seen) {
	print OUT $line;
    }
    close OUT;
}

1;

__END__
