# -*- perl -*-

#
# $Id: TelefonbuchAny.pm,v 1.1 2003/04/26 19:51:59 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Using:
# http://www-zeuthen.desy.de/~friebel/telefon/telecd

package TelefonbuchAny;

use strict;

my %straverz_fields;

my $str_name_key = exists $straverz_fields{"str"} ? "str" : "str_name";
my $str_hnr_key  = exists $straverz_fields{"hnr"} ? "hnr" : "str_hnr";

sub make_telecd_args {
    my(%args) = @_;
    my @args;
    # force str to be on front
    for my $k (sort { if ($a eq $str_name_key) { -1 } else { 0 } } keys %args) {
	my $v = $args{$k};
	if ($k =~ /^(f)$/) {
	    $k = "-$k";
	    push @args, $k, $v;
	} else {
	    push @args, "$k=$v";
	}
    }
    @args;
}

sub check_cd_version {
    my $parse_fields;
    foreach my $l (`telecd -f straverz`) {
	if ($parse_fields) {
	    my(@l) = split /\s+/, $l;
	    for my $field (@l) {
		$field =~ s/^\*//;
		$straverz_fields{$field}++;
	    }
	} elsif ($l =~ /In der Datenbank/) {
	    $parse_fields = 1;
	}
    }

    $str_name_key = exists $straverz_fields{"str"} ? "str" : "str_name";
    $str_hnr_key  = exists $straverz_fields{"hnr"} ? "hnr" : "str_hnr";
}

sub call_telecd {
    my(%args) = @_;
    my @lines;
    open(TCD, "-|") or do {
	my @args = make_telecd_args(%args);
	warn "@args\n"; # XXX
	exec "telecd", @args;
	die $!;
    };
    chomp(@lines = <TCD>);
    close TCD;
    if (!@lines) {
	$args{$str_name_key} .= ".*";
	open(TCD, "-|") or do {
	    my @args = make_telecd_args(%args);
	    warn "@args\n"; # XXX
	    exec "telecd", @args;
	    die $!;
	};
	chomp(@lines = <TCD>);
	close TCD;
	if (!@lines) {
	    require Data::Dumper;
	    die "Nothing found for " . Data::Dumper->new([\%args],[])->Indent(1)->Useqq(1)->Dump;
	}
    }
    my @res;
    foreach my $l (@lines) {
	if ($l =~ /^-+$/) {
	    push @res, {};
	} elsif (@res) {
	    my($k,$v) = split /\s*:\s*/, $l, 2;
	    $res[-1]->{$k} = $v;
	}
    }
require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\@res],[])->Indent(1)->Useqq(1)->Dump; # XXX

}

return 1 if caller;

my $str = shift;
my $hnr = shift;

check_cd_version();

call_telecd($str_name_key, $str,
	    (defined $hnr ? ($str_hnr_key => $hnr) : ()),
	    f => "straverz",
	   );
