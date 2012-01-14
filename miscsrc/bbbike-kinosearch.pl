#!/usr/local/bin/perl5.12.4 -w
#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use autodie;
use strict;
use FindBin;

use File::Basename 'basename';
use File::Temp 'tempfile';
use Getopt::Long;
use KSx::Simple;

sub usage () {
    die <<EOF;
usage: $0 -index
       $0 searchterm
EOF
}

my $do_index;
my $only_berlin;

my $bbbike_rootdir = "$FindBin::RealBin/..";
my $bbbike_datadir = "$bbbike_rootdir/data";
my $restrict_bbd = "$bbbike_rootdir/miscsrc/restrict_bbd_data.pl";

GetOptions(
	   "index" => \$do_index,
	   "berlin" => \$only_berlin,
	  )
    or usage;

my $index_dir = "$bbbike_rootdir/tmp/bbbike-kinosearch" . ($only_berlin ? "-berlin" : "-all");

mkdir $index_dir if !-d $index_dir;
my $index = KSx::Simple->new(
			     path     => $index_dir,
			     language => 'de',
			    );

if ($do_index) {
    if (@ARGV) {
	usage;
    }

    my $fh;
    open $fh, "$bbbike_datadir/Berlin.coords.data";
    warn "Berlin.coords.data...\n";
    while(<$fh>) {
	chomp;
	my($str,$citypart) = split /\|/;
	$index->add_doc({ title => "$str $citypart",
			  content => "$str $citypart",
			});
    }

    for my $file (glob("$bbbike_datadir/*-orig")) {
	my $basename = basename $file;
	$basename =~ s{-orig$}{};
	warn "$basename...\n";
	my $work_file = $file;
	my $tmpfile;
	if ($only_berlin) {
	    # Files which are completely outside berlin
	    next if $basename =~ m{^( comments_cyclepath
				   |  deutschland
				   |  grenzuebergaenge
				   |  handicap_l
				   |  landstrassen
				   |  landstrassen2
				   |  orte
				   |  orte2
				   |  orte_city # uninteresting
				   |  ortsschilder
				   |  potsdam
				   |  potsdam_ortsteile
				   |  qualitaet_l
				   |  wasserumland
				   |  wasserumland2
				   )$}x;
	DO_RESTRICT: {
		# Files which are completely inside berlin
		last DO_RESTRICT if $basename =~ m{^( handicap_s
						   |  qualitaet_s
						   |  radwege
						   |  strassen
						   |  ubahn    # keine U-Bahnen in Brandenburg
						   |  ubahnhof # "
						   |  wasserstrassen
						   )$}x;

		(my($tmpfh),$tmpfile) = tempfile(UNLINK => 1, SUFFIX => '.bbd')
		    or die $!;
		warn "   (restrict to berlin)\n";
		system $restrict_bbd, '-strdata' => $file, '-polygon-bbd' => "$bbbike_datadir/berlin", '-o' => $tmpfile;
		$work_file = $tmpfile;
	    }
	}

	my $fh;
	open $fh, $file;
	warn "   (reading and indexing)\n";
	while(<$fh>) {
	    chomp;
	    if (m{^#\s*(.*)}) {
		my $comment = $1;
		$index->add_doc({ title => "$comment $basename",
				  content => $comment,
				});
	    } elsif (my($str) = $_ =~ m{^([^\t]+)}) {
		$index->add_doc({ title => "$str $basename",
				  content => $str,
			    });
	    }
	}

	if ($tmpfile) {
	    unlink $tmpfile; # do it as early as possible, to keep /tmp small
	}
    }

} else {
    my $query_string = "@ARGV"
	or usage;

    my $total_hits = $index->search( 
				    query      => $query_string,
				    offset     => 0,
				    num_wanted => 10,
				   );

    print "Total hits: $total_hits\n";
    while ( my $hit = $index->next ) {
	print "$hit->{title}\n",
    }
}

__END__
