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
use Getopt::Long;
use KSx::Simple;

sub usage () {
    die <<EOF;
usage: $0 -index
       $0 searchterm
EOF
}

my $do_index;
my $index_dir = "/tmp/bbbike-kinosearch";
my $bbbike_datadir = "$FindBin::RealBin/../data";

GetOptions("index" => \$do_index)
    or usage;

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
	my $fh;
	open $fh, $file;
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
