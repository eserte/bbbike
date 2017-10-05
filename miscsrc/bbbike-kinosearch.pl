#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012,2017 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use autodie;
use strict;
use FindBin;
my $bbbike_rootdir;
BEGIN { $bbbike_rootdir = "$FindBin::RealBin/.." }
use lib ($bbbike_rootdir, "$bbbike_rootdir/lib");

use File::Basename 'basename';
use File::Temp 'tempfile';
use Getopt::Long;

use Karte;
use Karte::Standard;
use Karte::Polar;
use Strassen::Core;

sub usage () {
    die <<EOF;
usage: $0 -index
       $0 searchterm
EOF
}

my $do_index;
my $only_berlin;

my $bbbike_datadir = "$bbbike_rootdir/data";
my $restrict_bbd = "$bbbike_rootdir/miscsrc/restrict_bbd_data.pl";

GetOptions(
	   "index" => \$do_index,
	   "berlin" => \$only_berlin,
	  )
    or usage;

my $index_dir = "$bbbike_rootdir/tmp/bbbike-kinosearch" . ($only_berlin ? "-berlin" : "-all");

mkdir $index_dir if !-d $index_dir;


if ($do_index) {
    if (@ARGV) {
	usage;
    }

    require Lucy::Plan::Schema;
    require Lucy::Plan::FullTextType;
    require Lucy::Plan::StringType;
    require Lucy::Analysis::PolyAnalyzer;
    require Lucy::Index::Indexer;

    my $schema = do {
	my $_schema = Lucy::Plan::Schema->new;
	my $polyanalyzer = Lucy::Analysis::PolyAnalyzer->new(language => 'de');
	my $type = Lucy::Plan::FullTextType->new(analyzer => $polyanalyzer);
	my $noindex_type = Lucy::Plan::StringType->new(indexed => 0);
	$_schema->spec_field(name => 'title',   type => $type);
	$_schema->spec_field(name => 'content', type => $type);
	$_schema->spec_field(name => 'cat',     type => $noindex_type);
	$_schema->spec_field(name => 'coords',  type => $noindex_type);
	$_schema;
    };

    my $indexer = Lucy::Index::Indexer->new
	(
	 index    => $index_dir,
	 schema   => $schema,
	 create   => 1,
	 truncate => 1,
	);

    my $fh;
    open $fh, "$bbbike_datadir/Berlin.coords.data";
    warn "Berlin.coords.data...\n";
    while(<$fh>) {
	chomp;
	my($str,$citypart,undef,$coords) = split /\|/;
	$indexer->add_doc({ title => "$str $citypart",
			    content => "$str $citypart",
			    cat => 'X',
			    $coords ? (coords => _translate_coords($coords)) : (),
			});
    }

    for my $file (glob("$bbbike_datadir/*-orig")) {
	my $basename = basename $file;
	$basename =~ s{-orig$}{};
	next if $basename eq 'ampelschaltung'; # not in bbd format, and useless anyway in fulltext index
	warn "$basename...\n";
	my $work_file = $file;
	if ($basename eq 'plz') {
	    $work_file =~ s{-orig}{}; # plz-orig has some strange B_ON/B_OFF stuff in the coords
	}
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

	my $s = Strassen->new_stream($work_file, UseLocalDirectives => 1);
	warn "   (reading and indexing)\n";
	$s->read_stream
	    (sub {
		 my($rec, $dir, $line) = @_;
		 my $str = $rec->[Strassen::NAME];
		 my @text = $str;
		 while(my($k,$v) = each %$dir) {
		     push @text, @$v;
		 }
		 my $coords = join(" ", _translate_coords(@{ $rec->[Strassen::COORDS] }));
		 my $title = "$str $basename:$line";
		 $indexer->add_doc({
				    title   => $title,
				    content => join(" ", @text),
				    cat     => $rec->[Strassen::CAT],
				    coords  => $coords
				   });
	     });

	if ($tmpfile) {
	    unlink $tmpfile; # do it as early as possible, to keep /tmp small
	}
    }

    $indexer->commit;
} else {
    my $query_string = "@ARGV"
	or usage;

    require Lucy::Search::IndexSearcher;
    
    my $searcher = Lucy::Search::IndexSearcher->new(index => $index_dir);
    my $hits = $searcher->hits( 
			       query      => $query_string,
			       offset     => 0,
			       num_wanted => 10,
			      );

    print "#: map: polar\n#: \n";
    print "# Total hits: " . $hits->total_hits . "\n";
    while (my $hit = $hits->next) {
	print "$hit->{title}\t$hit->{cat} $hit->{coords}\n",
    }
}

sub _translate_coords {
    my(@coords) = @_;
    map { join ",", $Karte::Polar::obj->standard2map(split /,/) } grep { $_ ne '*' } @coords; 
}

__END__

=head1 NAME

bbbike-kinosearch.pl - a full text over BBBike data

=head1 SYNOPSIS

Create index (takes some 30s or so):

    ./bbbike-kinosearch.pl -index

Search something

    ./bbbike-kinosearch.pl dudenstr

=head1 SEE ALSO

L<Lucy> (the successor to L<KinoSearch>).

=cut
