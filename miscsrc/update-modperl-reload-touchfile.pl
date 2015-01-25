#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2015 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Getopt::Long;
use Term::ANSIColor qw(colored);

use BBBikeUtil qw(bbbike_root);

sub my_die ($);

my @modperl_relevant_files =
    (
     'BBBikeApacheSessionCounted.pm',
     'BBBikeApacheSessionCountedHandler.pm',
     'BBBikeDataDownloadCompat.pm',
    );

my $reload_touchfile = bbbike_root . '/tmp/reload_modules';

my $do_touch;
GetOptions('touch' => \$do_touch)
    or my_die "usage?";

my $need_touch;
my $max_mtime;

my $reload_touchfile_mtime = (stat($reload_touchfile))[9];
if (!defined $reload_touchfile_mtime) {
    print colored ['yellow on_black'], "The reload touchfile '$reload_touchfile' does not exist -- first-time run?\n";
    $need_touch = 1;
}
for my $modperl_relevant_file (@modperl_relevant_files) {
    my $path = bbbike_root . '/'. $modperl_relevant_file;
    if (!-e $path) {
	my_die "UNEXPECTED ERROR: file '$path' does not exist";
    }
    my $mtime = (stat($path))[9];
    my_die "UNEXPECTED ERROR: cannot stat '$path'" if !defined $mtime;
    if (!defined $reload_touchfile_mtime || $mtime > $reload_touchfile_mtime) {
	$need_touch = 1;
	if (defined $reload_touchfile_mtime) {
	    print "The file '$path' was modified.\n";
	}
	if (!defined $max_mtime || $mtime > $max_mtime) {
	    $max_mtime = $mtime;
	}
    }
}

if ($need_touch) {
    if ($do_touch) {
	open my $ofh, ">", $reload_touchfile
	    or my_die "ERROR: Can't create '$reload_touchfile': $!";
	close $ofh;
	utime $max_mtime, $max_mtime, $reload_touchfile
	    or my_die "ERROR: Can't change mtime of '$reload_touchfile': $!";
	print colored ['yellow on_black'], 'reload touchfile touched, modperl will reload modules.', "\n";
    } else {
	print colored ['red on_black'], 'modperl modules need a reload --- please re-run with --touch option:', "\n";
	print <<EOF;

    $^X $0 --touch

EOF
    }
} else {
    print colored ['green on_black'], 'modperl modules are up-to-date.', "\n";
}

sub my_die ($) {
    my $msg = shift;
    die colored ['red on_black'], $msg, "\n";
}

__END__
