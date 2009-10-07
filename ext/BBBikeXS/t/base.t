# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

use strict;
use vars qw($x_delta $y_delta);

use Test::More;
my $tk_tests = 29;
plan tests => 10 + $tk_tests;

BEGIN {
    eval {
	require Devel::Leak;
	import Devel::Leak;
    };
    if ($@) {
	warn "\nDevel::Leak not found, memory leak tests not activated.\n";
    }
}

BEGIN {
    # Don't use "use lib", so we are sure that the real BBBikeXS.pm/so is
    # loaded first
    push @INC, qw(../.. ../../lib);
}
use Strassen;

BEGIN {
    $x_delta = 100; # wrong value, expect warn
    $y_delta = 600; # right value
    # expect warns for x/y_mount
}

{
    package MyStrassenNetz;
    @MyStrassenNetz::ISA = qw(StrassenNetz);
}

use BBBikeXS;
#use Data::Dumper;
use Getopt::Long;
use Benchmark;

my $datadir = "../../data";
my $imgdir = "../../images";
push(@Strassen::datadirs, $datadir);
my $leaktest = 1;

ok(1, "loaded module");

# test if functions are available
ok(defined &main::set_canvas_scale_XS, "Subroutine definitions...");
ok(defined &main::transpose_ls_XS);
ok(defined &Strassen::to_koord1_XS);
ok(defined &Strassen::to_koord_XS);
ok(defined &Strassen::to_koord_f1_XS);
ok(defined &Strassen::to_koord_f_XS);
ok(defined &StrassenNetz::make_net_XS);
ok(defined &BBBike::fast_plot_str);
ok(defined &BBBike::fast_plot_point);

# which tests to perform:
my $test_tk        = 1;
my $test_make_net  = 1;
my $test_to_koord1 = 0;
my $test_to_koord  = 0;
my $test_transpose = 0;
my $repeat         = -2;
my $v;

if (!GetOptions("tk!"        => \$test_tk,
		"makenet!"   => \$test_make_net,
		"tokoord1!"  => \$test_to_koord1,
		"tokoord!"   => \$test_to_koord,
		"transpose!" => \$test_transpose,
		"repeat=f"   => \$repeat,
		"leaktest!"  => \$leaktest,
		"all" => sub { $test_tk = $test_make_net = $test_to_koord1 =
				   $test_to_koord = $test_transpose = 1},
		"v+" => \$v,
	       )) {
    die "usage!";
}

if (defined $v && $v > 0) {
    Strassen::set_verbose(1);
}

SKIP: {
    skip "Tk tests not enabled", $tk_tests if !$test_tk;
    skip "Tk not available", $tk_tests if !eval { require Tk; 1 };
    my $top = eval { Tk::tkinit() };
    skip "Cannot create MainWindow", $tk_tests if !$top;

    my $c = $top->Canvas(-width => 1000,
			 -height => 700)->pack;
    use vars qw($andreaskr_klein_photo $ampel_klein_photo $zugbruecke_klein_photo);
    $andreaskr_klein_photo
      = $top->Photo(-file => "$imgdir/andreaskr.gif");
    $ampel_klein_photo 
      = $top->Photo(-file => "$imgdir/ampel.gif");
    $zugbruecke_klein_photo 
      = $top->Photo(-file => "$imgdir/zugbruecke.gif");

    sub get_symbol_scale {
	my $p = {"lsa-X" => $ampel_klein_photo,
		 "lsa-B" => $andreaskr_klein_photo,
		 "lsa-Zbr" => $zugbruecke_klein_photo,
		}->{$_[0]};
	$p;
    }

    {
	my $progress = MyProgress->new;
	BBBike::fast_plot_point($c, "lsa", ["$datadir/ampeln"], $progress);
	$progress->update_expected;
    }
    $c->delete("lsa");

    # again:
    checkpoint1();
    checktime1();
    {
	my $progress = MyProgress->new;
	BBBike::fast_plot_point($c, "lsa", ["$datadir/ampeln"], $progress);
	$progress->update_expected;
    }
    
    checktime2();
    checkpoint2();

 TODO: {
	local $TODO;
	$TODO = "Strange behaviour ... perl or Tk problem?" # only seen with SuSE's perl 5.8.1 and a self-compiled Tk 800.025, but not with Tk 804.027
	    if $Tk::VERSION < 804;
	for my $abk (qw(B X Zbr)) {
	    my(@tags) = $c->find(withtag => "lsa-$abk-fg");
	    ok(scalar @tags > 0, "Tags for $abk");
	}
    }

    use vars qw(%str_outline %category_color);
    $str_outline{"s"} = 1;
    my @restr = ('HH', 'H', 'N', 'NN');
    my $category_width = {'HH' => 6, 'H' => 4, 'N' => 2, 'NN' => 1};
    %category_color = ('N'  => 'grey99',
		       'NN' => '#bdffbd',
		       'H'  => 'yellow',
		       'HH' => 'yellow2',
		      );
    {
	my $progress = MyProgress->new;
	BBBike::fast_plot_str($c, "s", ["$datadir/strassen"], $progress, \@restr, $category_width);
	$progress->update_expected;
    }
    $c->delete("s");

    # again:
    checkpoint1();
    checktime1();
    {
	my $progress = MyProgress->new;
	BBBike::fast_plot_str($c, "s", ["$datadir/strassen"], $progress, \@restr, $category_width);
	$progress->update_expected;
    }
    checktime2();
    checkpoint2();

    my @ignore = ('Q0');
    $category_width = {'Q0' => 10, 'Q1' => 2, 'Q2' => 2, 'Q3' => 2};
    $category_color{'Q0'} = 'black';
    $category_color{'Q1'} = 'green';
    $category_color{'Q2'} = 'yellow';
    $category_color{'Q3'} = 'red';
    {
	my $progress = MyProgress->new;
	BBBike::fast_plot_str($c, "qs", ["$datadir/qualitaet_s","$datadir/qualitaet_l"], $progress, undef, $category_width, \@ignore);
	$progress->update_expected;
    }

    # check object mode of dast_plot_str
    {
	$category_color{$_} = 'green4' for (qw(S SA SB SC));
	$category_width->{$_} = 3        for (qw(S SA SB SC));
	my $s = Strassen->new("$datadir/sbahn");
	my $progress = MyProgress->new;
	BBBike::fast_plot_str($c, "b", $s, $progress, undef, $category_width);
	# no: less than 150 items in sbahn, Update(Float) is never called: $progress->update_float_expected;
    }

    $top->after(5000, sub { $top->destroy;});
    Tk::MainLoop();
    ok(1);
}

my $s = new Strassen "strassen";

if ($test_make_net) {
    print "# Test make_net\n";

    checkpoint1();
    for my $pass (1 .. 3) {
	print "# pass $pass...\n";
	checktime1();
	my $n = new StrassenNetz $s;
	$n->make_net();
	#open(F1, ">/tmp/f1"); print F1 Data::Dumper->Dumpxs([$n], ['n']); close F1;

	checktime2();
    }
    checkpoint2(10);

    # subclass test
    {
	my $n2 = MyStrassenNetz->new($s);
	$n2->make_net;
    }

    {
	print "# Test slow make_net\n";
	my $n = new StrassenNetz $s;
	checktime1();
	$n->make_net_slow_1;
	checktime2();
	#open(F2, ">/tmp/f2"); print F2 Data::Dumper->Dump([$n], ['n']); close F2;
    }

    # set_scale(2);
    # for (1..30000) {
    # #    my($x, $y) = (int(rand(10000)), int(rand(10000)));
    #     my($x, $y) = ($_, $_);
    #     my($tx, $ty) = transpose($x, $y);
    #     my($ax, $ay) = anti_transpose($tx, $ty);
    #     $sum += abs($x-$ax) + abs($y-$ay);
    #     warn "$x == $ax, $y == $ay ($tx $ty)";
    # }

    # warn "$sum\n";
}

######################################################################

if ($test_to_koord1) {
    print "# Test to_koord1\n";
    checkpoint1();
    print join("", map "#$_\n", split /\n/, $@)."\n" if $@;
    $s->init;
    while(1) {
	my $ret = $s->next;
	my(@k) = @{$ret->[1]};
	last if !@k;
	foreach (@k) {
	    my(@slow) = @{Strassen::to_koord1_slow($_)};
	    my(@fast) = @{Strassen::to_koord1_XS($_)};
	    if ($slow[0] != $fast[0] || $slow[1] != $fast[1]) {
		die "$ret->[0]: @slow != @fast\n";
	    }
	}
    }
    checkpoint2();

    print "# Test performance\n";
    print "# Fast version of to_koord1:\n";
    checktime1();
    $s->init;
    while(1) {
	my $ret = $s->next;
	my(@k) = @{$ret->[1]};
	last if !@k;
	foreach (@k) {
	    for my $i (1 .. 10) {
		my(@fast) = @{Strassen::to_koord1_XS($_)};
	    }
	}
    }
    checktime2();

    print "# Slow version of to_koord1:\n";
    checktime1();
    $s->init;
    while(1) {
	my $ret = $s->next;
	my(@k) = @{$ret->[1]};
	last if !@k;
	foreach (@k) {
	    for my $i (1 .. 10) {
		my(@slow) = @{Strassen::to_koord1_slow($_)};
	    }
	}
    }
    checktime2();
}

######################################################################

if ($test_to_koord) {
    print "# Test to_koord\n";
    checkpoint1();
    $s->init;
    while(1) {
	my $ret = $s->next;
	my(@k) = @{$ret->[1]};
	last if !@k;
	my $slow = Strassen::to_koord_slow(\@k);
	my $fast = Strassen::to_koord_XS(\@k);
	if ($slow->[0][0] != $fast->[0][0] ||
	    $slow->[0][1] != $fast->[0][1]) {
	    die "Return values different:
$slow->[0][0] != $fast->[0][0] ||
$slow->[0][1] != $fast->[0][1]";
	}
	if ($#{$slow} != $#{$fast}) {
	    die "Return values differ in length: " . $#{$slow} . "!=" . $#{$fast};
	}
    }
    checkpoint2();

    print "# Test performance\n";
    print "# Fast version of to_koord:\n";
    checktime1();
    $s->init;
    while(1) {
	my $ret = $s->next;
	my(@k) = @{$ret->[1]};
	last if !@k;
	my $x = Strassen::to_koord_XS(\@k);
    }
    checktime2();

    print "# Slow version of to_koord:\n";
    checktime1();
    $s->init;
    while(1) {
	my $ret = $s->next;
	my(@k) = @{$ret->[1]};
	last if !@k;
	my $x = Strassen::to_koord_slow(\@k);
    }
    checktime2();
}

######################################################################

my $scale = 0.5;
sub transpose_ls_slow {
    (int((-200+$_[0]/25)*$scale), int((600-$_[1]/25)*$scale));
}

if ($test_transpose) {
    my(@data_slow, @data_fast);
    my @example;
    my $max = 100000;
    for(my $i = 0; $i<$max; $i++) {
	push @example, int(rand(8000))-4000, int(rand(8000))-4000;
    }

    timethese($repeat,
	      { 'slow' => sub {
		    undef @data_slow;
		    for(my $i = 0; $i<$max; $i+=2) {
			push @data_slow, transpose_ls_slow(@example[$i,$i+1]);
		    }
		},
		'fast' => sub {
		    undef @data_fast;
		    set_canvas_scale_XS($scale);
		    for(my $i = 0; $i<$max; $i+=2) {
			push @data_fast, transpose_ls_XS(@example[$i,$i+1]);
		    }
		},
	      });

    for(my $i = 0; $i<$max; $i++) {
	print "# Data is not the same: $i: $data_slow[$i] != $data_fast[$i]\n"
	    . "# Diff is " . ($data_slow[$i] - $data_fast[$i])
		if abs($data_slow[$i] - $data_fast[$i]) > 1;
    }
}

my $count1;
my $count2;
my $handle;

sub checkpoint1 {
    if ($leaktest) {
	eval {
	    $count1 = quiet_stderr(sub { Devel::Leak::NoteSV($handle) });
	};
    }

}

sub checkpoint2 {
    my($tolerated_difference) = shift || 0;
    if ($leaktest) {
	eval {
	    $count2 = quiet_stderr(sub { Devel::Leak::CheckSV($handle) });
	    if ($count1 != $count2-$tolerated_difference) {
		diag "" . ($count2-$count1) . " new scalars since last checkpoint\n";
	    }
	};
    }
}

my $checktime;
my $newtime;

sub checktime1 {
    if (defined &Tk::timeofday) {
	$checktime = &Tk::timeofday;
    } else {
	$checktime = time;
    }
}

sub checktime2 {
    my $newtime;
    if (defined &Tk::timeofday) {
	$newtime = &Tk::timeofday;
    } else {
	$newtime = time;
    }
    print "# ", $newtime-$checktime, "s\n";
}

{
    package MyProgress;
    sub new { bless {
		     CalledUpdate => 0,
		     CalledUpdateFloat => 0,
		     Min => undef,
		     Max => undef,
		     StrictMonotonic => 1,
		    }, shift }
    sub Update {
	my($p, $val) = @_;
	$p->{CalledUpdate}++;
	if (!defined $p->{Min}) {
	    $p->{Min} = $val;
	} elsif ($val < $p->{Min}) {
	    $p->{StrictMonotonic} = 0;
	}
	if (!defined $p->{Max}) {
	    $p->{Max} = $val;
	} elsif ($val <= $p->{Max}) {
	    $p->{StrictMonotonic} = 0;
	} else {
	    $p->{Max} = $val;
	}
    }

    sub UpdateFloat {
	shift->{CalledUpdateFloat}++;
    }

    # five tests
    sub update_expected {
	my($progress) = @_;
	Test::More::ok($progress->{CalledUpdate}, "Update called");
	Test::More::ok(!$progress->{CalledUpdateFloat}, "UpdateFloat not called");
	Test::More::ok($progress->{StrictMonotonic}, "Monotonic");
	Test::More::cmp_ok($progress->{Min}, ">=", 0);
	Test::More::cmp_ok($progress->{Max}, "<=", 1);
    }

    # two tests
    sub update_float_expected {
	my($progress) = @_;
	Test::More::ok(!$progress->{CalledUpdate}, "Update not called");
	Test::More::ok($progress->{CalledUpdateFloat}, "UpdateFloat called");
    }
}

sub quiet_stderr {
    my($code) = @_;
    if (!$v) {
	*OLDERR = *OLDERR; # peacify -w
	open OLDERR, ">&STDERR" or die $!;
	open STDERR, "> ". File::Spec->devnull or die $!;
    }
    my $ret;
    eval {
	$ret = $code->();
    };
    my $err = $@;
    close STDERR;
    open STDERR, ">&OLDERR" or die $!;
    if ($err) {
	die $err;
    }
    $ret;
}
