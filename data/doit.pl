#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use FindBin;
use lib "$FindBin::RealBin/../lib";
use Doit;
use Doit::Log;
use Getopt::Long;
use Cwd 'realpath';

my $perl = $^X;
my $valid_date = 'today';

my $bbbikedir        = realpath "$FindBin::RealBin/..";
my $miscsrcdir       = "$bbbikedir/miscsrc";
my $persistenttmpdir = "$bbbikedir/tmp";

my $convert_orig_file  = "$miscsrcdir/convert_orig_to_bbd";
my @convert_orig       = ($perl, $convert_orig_file);
my @grepstrassen       = ($perl, "$miscsrcdir/grepstrassen");
my @grepstrassen_valid = (@grepstrassen, '-valid', $valid_date, '-preserveglobaldirectives');
my @replacestrassen    = ($perl, "$miscsrcdir/replacestrassen");

sub _need_rebuild ($@) {
    my($dest, @srcs) = @_;
    return 1 if !-e $dest;
    for my $src (@srcs) {
	if (!-e $src) {
	    warning "$src does not exist";
	} else {
	    return 1 if -M $src < -M $dest;
	}
    }
    return 0;
}

sub _make_writable ($@) {
    my($d, @files) = @_;
    $d->chmod(0644, grep { -e } @files);
}

sub _make_readonly ($@) {
    my($d, @files) = @_;
    $d->chmod(0444, @files);
}

sub _empty_file_error ($) {
    my $f = shift;
    error "Generated file $f is empty" if !-s $f;
}

sub _commit_dest ($$) {
    my($d, $f) = @_;
    _make_writable($d, $f);
    $d->rename("$f~", $f);
    _make_readonly($d, $f);
}

sub action_files_with_tendencies {
    my $d = shift;

    # qualitaet
    for my $suffix (qw(s l)) {
	my $dest = "$persistenttmpdir/qualitaet_$suffix";
	my $src = "qualitaet_$suffix-orig";
	if (_need_rebuild $dest, $src) {
	    $d->run(
		    [@convert_orig, qw(-keep-directive valid), $src],
		    '|',
		    [@grepstrassen_valid],
		    '>', "$dest~"
		   );
	    _empty_file_error "$dest~";
	    _commit_dest $d, $dest;
	}
    }

    # handicap
    for my $def (
		 ['s', 'inner', 'routing_helper-orig'],
		 ['l', 'outer', undef],
		) {
	my($suffix, $side_berlin, $routing_helper_orig) = @$def;
	my $dest = "$persistenttmpdir/handicap_$suffix";
	my $src = "handicap_$suffix-orig";
	if (_need_rebuild $dest, $src, 'berlin', "$persistenttmpdir/gesperrt-with-handicaps", ($routing_helper_orig ? $routing_helper_orig : ())) {
	    $d->run(
		    [@convert_orig, qw(-keep-directive valid), $src],
		    '|',
		    [@grepstrassen_valid],
		    '>', "$dest~"
		   );
	    _empty_file_error "$dest~";
	    $d->run(
		    [@grepstrassen, '-catrx', '1s?:q\d'], '<', "$persistenttmpdir/gesperrt-with-handicaps",
		    '|',
		    [@grepstrassen, "-$side_berlin", 'berlin'],
		    '|',
		    [@replacestrassen, '-noglobaldirectives',
		     '-catexpr', 's/.*:(q\d)/$1::igndisp;/', 
		     '-nameexpr', 's/(.*)/$1: gegen die Einbahnstraßenrichtung, ggfs. schieben/'],
		    '>>', "$dest~"
		   );
	    $d->run(
		    [@grepstrassen, '-catrx', '2s?:q\d'], '<', "$persistenttmpdir/gesperrt-with-handicaps",
		    '|',
		    [@grepstrassen, "-$side_berlin", 'berlin'],
		    '|',
		    [@replacestrassen, '-noglobaldirectives',
		     '-catexpr', 's/.*:(q\d)/$1::igndisp/',
		     '-nameexpr', 's/(.*)/$1: gesperrt, ggfs. schieben/'],
		    '>>', "$dest~"
		   );
	    if ($routing_helper_orig) {
		$d->run(
			[@grepstrassen, qw(-ignoreglobaldirectives -ignorelocaldirectives), '-catrx', '^q\d+;$', $routing_helper_orig],
			'|',
			[@replacestrassen, '-catexpr', 's/;/::igndisp;/'],
			'>>', "$dest~"
		       );
	    }
	    _commit_dest $d, $dest;
	}
    }
}

sub action_all {
    my $d = shift;
    action_files_with_tendencies($d);
}

return 1 if caller;

my $d = Doit->init;

GetOptions or die "usage: $0 [--dry-run] action ...\n";

my @actions = @ARGV;
if (!@actions) {
    @actions = ('all');
}
for my $action (@actions) {
    my $sub = "action_$action";
    if (!defined &$sub) {
	die "Action '$action' not defined";
    }
    no strict 'refs';
    &$sub($d);
}

__END__
