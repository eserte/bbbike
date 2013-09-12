#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2008,2013 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Getopt::Long;

use PLZ;
use Strassen::Core;

my $incl_fragezeichen = 1;
GetOptions("fz!" => \$incl_fragezeichen)
    or die "usage: $0 [-[no]fz]";

my %seen_street_with_bezirk;
my %seen_street;

my $s = Strassen->new("$FindBin::RealBin/../data/strassen"); # includes plaetze-orig
if ($incl_fragezeichen) {
    my $fz = Strassen->new("$FindBin::RealBin/../data/fragezeichen-orig"); # use -orig, because known unconnected streets are missing in non-orig
    $fz->init;
    while(1) {
	my $r = $fz->next;
	my $c = $r->[Strassen::COORDS];
	last if !@$c;
	$r->[Strassen::NAME] =~ s{:.*}{};
	$s->push($r);
    }
}

$s->init;
while(1) {
    my $r = $s->next;
    my $c = $r->[Strassen::COORDS];
    last if !@$c;
    my($name, $bezirk) = $r->[Strassen::NAME] =~ m{^(.*)\s+\((.*)\)$};
    if (defined $name) {
	my @bezirk = split /\s*,\s*/, $bezirk;
	for my $bezirk (@bezirk) {
	    $seen_street_with_bezirk{$name}->{$bezirk}++;
	}
    } else {
	$seen_street{$r->[Strassen::NAME]}++;
    }
}

my %missing_by_bezirk;

my $plz = PLZ->new;
$plz->load;
foreach my $rec (@{ $plz->{Data} }) {
    my($str, $bezirk) = ($rec->[PLZ::FILE_NAME],
			 $rec->[PLZ::FILE_CITYPART],
			);
    my $type = $plz->get_street_type($rec);
    next if $type ne 'street';
    next if $str =~ m{^Jagen\s\d+}; # XXX decide later
    next if $str eq 'Im Jagen' && $bezirk eq 'Wannsee'; # XXX decide later
    next if $str eq 'Rote-Kreuz-Str.'; # XXX Besonderheit ist in landstrassen-orig erklärt
    if (exists $seen_street_with_bezirk{$str}->{$bezirk}) {
    } elsif (exists $seen_street{$str}) {
    } else {
	push @{ $missing_by_bezirk{$bezirk} }, $str;
    }
}

if (%missing_by_bezirk) {
    #use BBBikeYAML qw(Dump);
    binmode STDOUT, ':encoding(iso-8859-1)';
    for my $key (sort { scalar(@{$missing_by_bezirk{$a}}) <=> scalar(@{$missing_by_bezirk{$b}}) } keys %missing_by_bezirk) {
	print "$key (" . scalar(@{$missing_by_bezirk{$key}}) . ")\n";
	for my $str (@{ $missing_by_bezirk{$key} }) {
	    print "  $str\n";
	}
	print "\n";
	#    my %dump_hash = ("$key (" . scalar(@{$missing_by_bezirk{$key}}) . ")" => $missing_by_bezirk{$key});
	#    print Dump(\%dump_hash);
    }
    #print Dump(\%missing_by_bezirk);
    #require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\%missing_by_bezirk],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX
    exit 1;
} else {
    exit 0;
}

__END__

=pod

Show number of missing streets per bezirk:

     ./missing_streets.pl | grep '^[A-Z]' | sort

=cut
