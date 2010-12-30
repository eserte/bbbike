#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");

use CGI qw();
use Encode qw(decode);
use JSON::XS qw(encode_json);

my $q = CGI->new;
print $q->header(-type => "application/json");

my $action = $q->param('action') || die 'action is missing';
if ($action eq 'crossings') {
    my $str = decode("utf-8", $q->param('str')) || die 'str is missing';
    my $type = $q->param('type') || die 'type is missing';
    require Strassen::Core;
    my $s = Strassen->new('strassen'); # XXX landstrassen e.g. for Potsdam?
    $s->init;
    my @coords;
    while() {
	my $r = $s->next;
	my @c = @{ $r->[Strassen::COORDS()] };
	last if !@c;
	if ($r->[Strassen::NAME()] eq $str) {
	    push @coords, @c;
	}
    }
    if (@coords == 1) {
	print encode_json({coords => $coords[0]});
    } else {
	require Strassen::Strasse;
	my $crossings = $s->all_crossings(RetType => 'hash', UseCache => 1);
	my @crossings;
	my @ret_crossings;
	for my $c (@coords) {
	    if (exists $crossings->{$c}) {
		my @kreuzung_name;
		for (@{ $crossings->{$c} }) {
		    if ($_ ne $str) {
			push @kreuzung_name, $_;
		    }
		}
		if (@kreuzung_name == 0) {
		    @kreuzung_name = '...';
		}
		my $kreuzung_name = join '/', map { Strasse::strip_bezirk($_) } @kreuzung_name;
		push @ret_crossings, [$kreuzung_name, $c];
	    }
	}
	#print encode_json({crossings => \%ret_crossings});
	my $html = join("\n", map { qq{<option value="} . CGI::escapeHTML($_->[1]) . qq{">} . CGI::escapeHTML($_->[0]) . qq{</option>} } @ret_crossings);
	print encode_json({type => $type, html => $html});
    }
} else {
    die "Unknown action '$action'";
}

__END__
