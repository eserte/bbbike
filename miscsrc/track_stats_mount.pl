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
use FindBin;

use File::Temp qw(tempfile);
use IPC::Run qw(run);
use Storable qw(lock_retrieve lock_nstore);
use Tie::IxHash ();

my $track_stats_script = "$FindBin::RealBin/track_stats.pl";

my(undef,$state1_file) = tempfile(UNLINK => 1, SUFFIX => "_state1", EXLOCK => 0) or die $!;
my(undef,$state2_file) = tempfile(UNLINK => 1, SUFFIX => "_state2", EXLOCK => 0) or die $!;
my(undef,$state_res_file) = tempfile(UNLINK => 1, SUFFIX => "_res_state", EXLOCK => 0) or die $!;
unlink $_ for ($state1_file, $state2_file, $state_res_file);

my @args_1 = ('-stage', 'begin', '-state' => $state1_file, @ARGV);
my @args_2 = ('-stage', 'begin', '-state' => $state2_file, '-reverse', @ARGV);
my @args_res = ('-stage', 'statistics', '-state' => $state_res_file, @ARGV);

my($stdout, $stderr);

warn "forth...\n";
run [$track_stats_script, @args_1], ">", \$stdout, "2>", \$stderr
    or die "Command <$track_stats_script @args_1> failed ($stderr)";

warn "back...\n";
run [$track_stats_script, @args_2], ">", \$stdout, "2>", \$stderr
    or die "Command <$track_stats_script @args_2> failed ($stderr)";

warn "merge...\n";
my $state1 = lock_retrieve $state1_file;
my $state2 = lock_retrieve $state2_file;

# Combine things into $state1
while(my($key,$val) = each %{ $state2->{count_per_device} }) {
    $state1->{count_per_device}->{$key} += $val;
}
# ignore "included" XXX correct?
while(my($key,$val) = each %{ $state2->{seen_device} }) {
    $state1->{seen_device}->{$key} = 1;
}
for my $result (@{ $state2->{results} }) {
    $result->{'!file'} .= " (rev)";

    $result->{mount} *= -1;
    $result->{'!mount'} = format_mount($result->{mount});

    $result->{diffalt} *= -1;
    $result->{'!diffalt'} = format_diffalt($result->{diffalt});

    push @{ $state1->{results} }, $result;
}

warn "statistics and output...\n";
lock_nstore $state1, $state_res_file;
run [$track_stats_script, @args_res],
    or die "Command <$track_stats_script @args_res> failed";

{ # XXX duplicated from track_stats.pl!
    no warnings 'uninitialized';
    sub format_diffalt  { defined $_[0] ? sprintf "%.1f", $_[0] : undef }
    sub format_mount    { defined $_[0] ? sprintf "%.1f", $_[0] : undef }
}

__END__

=pod

Example usage:

    ./track_stats_mount.pl -coordsys standard -sortby file -- 12495,12917 12541,12963 : 12660,12745 12723,12799

NOTE: don't use the -stage, -state and -reverse options here!

=cut
