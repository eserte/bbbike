#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
no warnings 'qw';
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use Getopt::Long;

use Strassen::Core;
use Strassen::StrassenNetz;

# Important: to avoid clashes with cached original data
# This is the same prefix as in cgi/bbbike-test.cgi.config
$Strassen::Util::cacheprefix = "test_b_de";

plan tests => 13;

my $do_bbd;
GetOptions("bbd" => \$do_bbd)
    or die "usage: $0 [-bbd]";

use_ok 'Strassen::SimpleSearch', 'simple_search';

my $s = Strassen->new("$FindBin::RealBin/data/strassen");
my $net = StrassenNetz->new($s);
$net->make_net;

{
    my $name = 'Duden -> Yorck';
    my $res = simple_search_and_dump($name, '9229,8785', ['8097,9650', '7938,9694']);
    is_deeply($res->{route},
	      [qw(9229,8785 9076,8783 8982,8781 8763,8780 8594,8777 8598,9074 8598,9264 8595,9495 8192,9619 8097,9650)],
	      $name,
	     );
    is_approx($res->{dist}, 1874, 1);
}

{
    my $name = 'Wilhelmshoehe -> Methfessel';
    my $res = simple_search_and_dump($name, '9149,8961', ['9111,9036']);
    is_deeply($res->{route},
	      [qw(9149,8961 9155,9029 9186,9107 9225,9111 9248,9350 9211,9354 9170,9206 9150,9152 9115,9046 9111,9036)],
	      $name,
	     );
    is_approx($res->{dist}, 802, 4);
}

{
    my $name = 'center -> corners';
    my $res = simple_search_and_dump($name, '8969,9320', ['9409,10226', '7938,9694', '8209,8773', '9229,8785']);
    is_deeply($res->{route},
	      [qw(8969,9320 9133,9343 9211,9354 9248,9350 9225,9111 9224,9053 9225,9038 9227,8890 9229,8785)],
	      $name,
	     );
    is_approx($res->{dist}, 847, 1);
}

{
    my $callback_counter = 0;
    my $name = 'callback';
    my $res = simple_search_and_dump
	($name, '8969,9320', ['9211,9354'],
	 callback => sub {
	     return if $callback_counter;
	     my($new_act_coord, $new_act_dist, $act_coord, $PRED, $CLOSED, $OPEN) = @_;
	     is(ref $OPEN, 'HASH', 'Found probably all arguments in callback');
	     is($act_coord, '8969,9320', 'expected $act_coord');
	     $callback_counter++;
	 });
    is_deeply($res->{route},
	      [qw(8969,9320 9133,9343 9211,9354)],
	      $name);
    is_approx($res->{dist}, 244, 1);
}

{
    my $name = 'adjustdist';
    my $res = simple_search_and_dump
	($name, '8969,9320', ['9133,9343'],
	 adjustdist => sub {
	     my($dist, $prev_coord, $this_coord) = @_;
	     if ($prev_coord eq '8969,9320' && $this_coord eq '9133,9343') {
		 return Strassen::Util::infinity(); # blocked!
	     }
	     $dist;
	 });
    is_deeply($res->{route},
	      [qw(8969,9320 8769,9290 8598,9264 8595,9495 8648,9526 8777,9601 9002,9731 9043,9745 9334,9670 9280,9476 9248,9350 9211,9354 9133,9343)],
	      $name);
    is_approx($res->{dist}, 1867, 4);
}

sub simple_search_and_dump {
    my($test_name, @args) = @_;
    my $res = simple_search($net, @args);
    res_to_bbd($res, $test_name);
    $res;
}

sub res_to_bbd {
    my($res, $name) = @_;
    if ($do_bbd && $res) {
	my $line;
	$line .= $name if defined $name;
	$line .= "\tX ";
	$line .= join ' ', @{ $res->{route} };
	$line .= "\n";
	diag $line;
    }
}

sub is_approx {
    my($got, $expected, $delta, $testname) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    cmp_ok(abs($got - $expected), "<=", $delta, $testname);
}

__END__
