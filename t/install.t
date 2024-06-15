#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

use Test::More 'no_plan';

use IPC::Run qw(run);

use BBBikeUtil qw(bbbike_root);

chdir bbbike_root
    or die "Can't chdir to bbbike root directory: $!";

my @cmd;
if ($^O eq 'MSWin32') {
    @cmd = ('.\install.bat');
} else {
    @cmd = ('./install.pl');
}
push @cmd, '-show', '-notk';

my $stdout;
my $stderr;
ok run(\@cmd, '>', \$stdout, '2>', \$stderr), "run '@cmd'";

unlike $stderr, qr{WARNING}, 'no warnings detected';
is $stdout, '', 'empty stdout (everything goes to stderr)';

diag $stderr;

__END__
