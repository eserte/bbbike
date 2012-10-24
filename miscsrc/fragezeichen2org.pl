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

use strict;
use utf8;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use Cwd qw(realpath);
use Getopt::Long;
use List::Util qw(min);
use POSIX qw(strftime);
use Time::Local qw(timelocal);

use BBBikeUtil qw(int_round);
use Strassen::Util ();
use StrassenNextCheck;

my $with_dist = 1;
my $centerc;
GetOptions(
	   "with-dist!" => \$with_dist,
	   "centerc=s" => \$centerc,
	  )
    or die "usage: $0 [--nowith-dist] [--centerc X,Y] bbdfile ...";

if ($with_dist && !$centerc) {
    my $config_file = "$ENV{HOME}/.bbbike/config";
    if (!-e $config_file) {
	warn "WARNING: disabling --with-dist option, $config_file does not exist.\n";
	$with_dist = 0;
    } else {
	require Safe;
	my $config = Safe->new->rdo($config_file);
	if (!$config) {
	    warn "WARNING: disabling --with-dist option, cannot load $config_file.\n";
	    $with_dist = 0;
	} else {
	    if (!$config->{centerc}) {
		warn "WARNING: disabling --with-dist option, no centerc option in $config_file set.\n";
		$with_dist = 0;
	    } else {
		$centerc = $config->{centerc};
	    }
	}
    }
}

my @files = @ARGV
    or die "Please specify bbd file(s)";

my @records;

for my $file (@files) {
    my $abs_file = realpath $file;
    my $s = StrassenNextCheck->new_stream($file);
    $s->read_stream_nextcheck_records
	(sub {
	     my($r, $dir) = @_;
	     if ($dir->{_nextcheck_date} && $dir->{_nextcheck_date}[0] && (my($y,$m,$d) = $dir->{_nextcheck_date}[0] =~ m{^(\d{4})-(\d{2})-(\d{2})$})) {
		 my $epoch = eval { timelocal 0,0,0,$d,$m-1,$y };
		 if ($@) {
		     warn "ERROR: Invalid day '$dir->{_nextcheck_date}[0]' ($@) in file '$file', line '" . $r->[Strassen::NAME] . "', skipping...\n";
		 } else {
		     my $wd = [qw(Su Mo Tu We Th Fr Sa)]->[(localtime($epoch))[6]];
		     my $date = "$y-$m-$d";
		     my $subject = $r->[Strassen::NAME] || "(" . $file . "::$.)";
		     my $dist_tag = '';
		     if ($centerc) {
			 my $dist = min map { int_round(Strassen::Util::strecke_s($_, $centerc)/1000) } @{ $r->[Strassen::COORDS] };
			 $dist_tag = ":${dist}km:";
		     }
		     my $body = <<EOF;
** TODO <$date $wd> $subject $dist_tag
   : $r->[Strassen::NAME]\t$r->[Strassen::CAT] @{$r->[Strassen::COORDS]}
   [[${abs_file}::$.]]
EOF
		     push @records, [$date, $body];
		 }
	     } else {
		 warn "ERROR: Cannot parse date '$dir->{_nextcheck_date}[0]' (file $file), skipping...\n";
	     }
	 });
}

@records = sort { $b->[0] cmp $a->[0] } @records;

binmode STDOUT, ':utf8';
print "fragezeichen/nextcheck\t\t\t-*- mode:org; coding:utf-8 -*-\n\n";

my $today = strftime "%Y-%m-%d", localtime;

my $today_printed = 0;
for my $record (@records) {
    if (!$today_printed && $record->[0] lt $today) {
	print "** ---------- TODAY ----------\n";
	$today_printed = 1;
    }
    print $record->[1];
}

print <<'EOF';
** settings
# Local variables:
# compile-command: "(cd ../data && make ../tmp/fragezeichen-nextcheck.org)"
# End:
EOF

__END__

=head1 NAME

fragezeichen2org - create org-mode file from date-based fragezeichen records

=head1 SYNOPSIS

    ./miscsrc/fragezeichen2org.pl data/*-orig tmp/bbbike-temp-blockings-optimized.bbd > tmp/fragezeichen-nextcheck.org

=cut
