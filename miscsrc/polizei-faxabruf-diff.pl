#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: polizei-faxabruf-diff.pl,v 1.8 2005/11/16 01:28:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004, 2005 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;

use constant SIMILARITY_THRESHOLD => 0.5;

my $old_file = shift || "/home/e/eserte/cache/misc/polizei-faxabruf.php~";
my $new_file = shift || "/home/e/eserte/cache/misc/polizei-faxabruf.php";

my @events_old = parse_table($old_file);
my @events_new = parse_table($new_file);

sub parse_table {
    my $file = shift;
    use HTML::TableExtract;
    my $te = new HTML::TableExtract();
    my $html_string = do { local $/; open(FH, $file) or die "$file: $!"; <FH> }; close FH;
    $te->parse($html_string);

    my @events;
    my $state;
 PARSE_TABLE:
    foreach my $ts ($te->table_states) {
	foreach my $row ($ts->rows) {
	    last PARSE_TABLE
		if (grep { /Verkehrsbehinderungen aufgelöst/ } @$row);
	    if (grep { /Kurzfristige Verkehrsbehinderungen/ } @$row) {
		$state = "kurzfristig";
		next;
	    }
	    if (grep { /Langfristige Verkehrsbehinderungen/ } @$row) {
		$state = "langfristig";
		next;
	    }
	    for (@$row) { s/^\s+//; s/\s+$//; s/\s+/ /g; }
	    next
		if $row->[1] eq "";
	    next
		if $row->[1] =~ /^A\d+/; # Autobahnen interessieren nicht
	    next
		if $row->[1] =~ /Ampeln ausgefallen/;
	    next
		if $row->[1] =~ /Fahrbahn auf (einen|zwei) Fahrstreifen verengt/;
	    push @events, {
			   Date => $row->[0],
			   Description => $row->[1],
			   State => $state,
			  };
	}
    }
    @events;
}

#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\@events_old, \@events_new],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

use String::Similarity;
my @similarity;
my @flat;
for my $i (0 .. $#events_old) {
    for my $j (0 .. $#events_new) {
	$similarity[$i][$j] = similarity $events_old[$i]->{Description}, $events_new[$j]->{Description}, SIMILARITY_THRESHOLD;
	push @flat, [$similarity[$i][$j], $i, $j];
    }
}

use Text::Wrap;
local $Text::Wrap::columns = 60;
use Text::Tabs;
local $tabstop = 8;

@flat = sort { $b->[0] <=> $a->[0] } @flat;
my %seen_old;
my %seen_new;
print "Changed:\n";
for (@flat) {
    my($factor, $index_old, $index_new) = @$_;
    next if $seen_old{$index_old} || $seen_new{$index_new};
    if ($factor < 1) {
	my @lines_new = expand split /\n/, wrap("", "", as_string($index_new, "new"));
	my @lines_old = expand split /\n/, wrap("", "", as_string($index_old, "old"));
	if (@lines_new < @lines_old) {
	    push @lines_new, ("") x (@lines_old-@lines_new);
	} elsif (@lines_new > @lines_old) {
	    push @lines_old, ("") x (@lines_new-@lines_old);
	}

	@lines_new = map {
	    if (length $_ < $Text::Wrap::columns) {
		$_ .= " "x($Text::Wrap::columns-length$_);
	    }
	    $_;
	} @lines_new;

	for my $i (0 .. $#lines_new) {
	    print "$lines_new[$i]    $lines_old[$i]\n";
	}
	print "-"x10, sprintf("Similarity: %.3f", $factor), "\n";
	print "-"x70, "\n";
    }
    $seen_old{$index_old}++;
    $seen_new{$index_new}++;
}

print "Added:\n";
for my $i (0 .. $#events_new) {
    next if $seen_new{$i};
    print wrap("", "", as_string($i, "new")), "\n";
    print "-"x70, "\n";
}

print "Removed:\n";
for my $i (0 .. $#events_old) {
    next if $seen_old{$i};
    print wrap("", "", as_string($i, "old")), "\n";
    print "-"x70, "\n";
}

sub as_string {
    my($i, $type) = @_;
    my $event;
    if ($type eq 'old') {
	$event = $events_old[$i];
    } else {
	$event = $events_new[$i];
    }
    $event->{Date} .
	($event->{State} eq 'kurzfristig' ? " (" . $event->{State} . ")" : "") .
	    ":\t" . $event->{Description};
}

__END__
