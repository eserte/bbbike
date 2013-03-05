#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

use File::Temp qw(tempfile);
use Test::More;

use BBBikeProcUtil qw(double_fork double_forked_exec);
use BBBikeUtil qw(is_in_path);

plan tests => 7;

double_fork { 1+1 };
pass 'done double_fork call with simple subroutine';

{
    my($tmpfh,$tmpfile) = tempfile(UNLINK => 1, SUFFIX => "_bbbikeprocutil.tmp")
	or die $!;
    double_fork {
	print $tmpfh "This is the forked process $$\n";
	close $tmpfh
	    or die $!;
    };
 WAIT_FOR_TMPFILE: {
	my $starttime = time;
	my $maxwait = 10;
	while (time-$starttime < $maxwait) {
	    if (-s $tmpfile) {
		open my $ifh, $tmpfile or die $!;
		my $line = <$ifh>;
		like $line, qr{^This is the forked process \d+}, 'Found trace from forked process';
		last WAIT_FOR_TMPFILE;
	    }
	    select undef,undef,undef,0.05;
	}
	fail "Did not find anything for $maxwait s...";
    }
}

SKIP: {
    skip "no 'true' command available", 2
	if !is_in_path 'true';

    double_fork { exec 'true' };
    pass 'done double_fork call with exec';

    double_forked_exec 'true';
    pass 'done double_forked_exec call with "true" command';
}

double_fork {
    if (eval { require File::Spec; 1 }) {
	open STDERR, ">", File::Spec->devnull;
    }
    exec 'this_command_does_not_exist_really';
};
pass 'done double_fork call with non-existing command';

{
    local $SIG{__WARN__} = sub { };
    double_forked_exec 'this_command_does_not_exist_really';
    pass 'double_forked_exec with non-existing command';
}

{
    # Two notes:
    # - the die() is translated into a warn() for "exit"ing reasons
    # - the parent process cannot inspect the value of the warn()
    local $SIG{__WARN__} = sub { };
    double_fork { die "This is dieing" };
}
pass 'done double_fork call with die';

__END__
