#!/usr/bin/perl
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/..";

use Test::More;

BEGIN {
    if (!eval q{ use IPC::Run qw(run); 1 }) {
	plan skip_all => 'IPC::Run not available';
    }
}

use BBBikeUtil qw(is_in_path);

my @el_files = <miscsrc/*.el>;
plan skip_all => 'no .el files available'
    if !@el_files;
plan skip_all => 'no emacs available for testing .el files'
    if !is_in_path 'emacs';
plan tests => scalar(@el_files);

for my $el_file (@el_files) {
    my @cmd = ('emacs', '--batch',
	       '--eval', '(setq byte-compile-verbose nil)',
	       '--eval', '(batch-byte-compile "'.$el_file.'")',
	      );
    my $success = run \@cmd, '>', \my $output, '2>&1';
    ok $success, "byte compiling emacs lisp file '$el_file' was successful"
	or diag "Output:\n$output";
}

__END__
