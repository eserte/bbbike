# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

# XXX switch to Test.pm (low priority)

BEGIN {
    eval {
	require Devel::Leak;
	import Devel::Leak;
    };
    if ($@) {
	warn "Devel::Leak not found, memory leak tests not activated.\n";
    }
}
BEGIN { $| = 1; print "1..8\n"; $ok = 0;}
END {print "not ok 1\n" unless $loaded;}
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

$loaded = 1;
print "ok @{[++$ok]}\n";

# test if functions are available
print "not " unless defined &main::set_canvas_scale_XS; print "ok @{[++$ok]}\n";
print "not " unless defined &main::transpose_ls_XS; print "ok @{[++$ok]}\n";

print "not " unless defined &Strassen::to_koord1_XS; print "ok @{[++$ok]}\n";
print "not " unless defined &Strassen::to_koord_XS; print "ok @{[++$ok]}\n";

print "not " unless defined &StrassenNetz::make_net_XS; print "ok @{[++$ok]}\n";

print "not " unless defined &BBBike::fast_plot_str; print "ok @{[++$ok]}\n";
print "not " unless defined &BBBike::fast_plot_point; print "ok @{[++$ok]}\n";

# which tests to perform:
$test_tk        = 1;
$test_make_net  = 1;
$test_to_koord1 = 0;
$test_to_koord  = 0;
$test_transpose = 0;
$repeat         = -2;

if (!GetOptions("tk!"        => \$test_tk,
		"makenet!"   => \$test_make_net,
		"tokoord1!"  => \$test_to_koord1,
		"tokoord!"   => \$test_to_koord,
		"transpose!" => \$test_transpose,
		"repeat=f"   => \$repeat,
		"leaktest!"  => \$leaktest,
		"all" => sub { $test_tk = $test_make_net = $test_to_koord1 =
				   $test_to_koord = $test_transpose = 1},
	       )) {
    die "usage!";
}

if ($test_tk) {
    require Tk;
    $top=Tk::tkinit();
    $c = $top->Canvas(-width => 1000,
		      -height => 700)->pack;
    $andreaskr_klein_photo
      = $top->Photo(-file => "$imgdir/andreaskr.gif");
    $ampel_klein_photo 
      = $top->Photo(-file => "$imgdir/ampel.gif");
    BBBike::fast_plot_point($c, "lsa", ["$datadir/ampeln"], 0);
    $c->delete("lsa");

    # again:
    checkpoint1();
    checktime1();
    BBBike::fast_plot_point($c, "lsa", ["$datadir/ampeln"], 0);
    checktime2();
    checkpoint2();

    $str_outline{"s"} = 1;
    @restr = ('HH', 'H', 'N', 'NN');
    $category_width = {'HH' => 6, 'H' => 4, 'N' => 2, 'NN' => 1};
    %category_color = ('N'  => 'grey99',
		       'NN' => '#bdffbd',
		       'H'  => 'yellow',
		       'HH' => 'yellow2',
		      );
    BBBike::fast_plot_str($c, "s", ["$datadir/strassen"], 0, \@restr, $category_width);
    $c->delete("s");

    # again:
    checkpoint1();
    checktime1();
    BBBike::fast_plot_str($c, "s", ["$datadir/strassen"], 0, \@restr, $category_width);
    checktime2();
    checkpoint2();

    my @ignore = ('Q0');
    $category_width = {'Q0' => 10, 'Q1' => 2, 'Q2' => 2, 'Q3' => 2};
    $category_color{'Q0'} = 'black';
    $category_color{'Q1'} = 'green';
    $category_color{'Q2'} = 'yellow';
    $category_color{'Q3'} = 'red';
    BBBike::fast_plot_str($c, "qs", ["$datadir/qualitaet_s"], 0, undef, $category_width, \@ignore);

    # check object mode of dast_plot_str
    {
	$category_color{$_} = 'green4' for (qw(S SA SB SC));
	$category_width{$_} = 3        for (qw(S SA SB SC));
	my $s = Strassen->new("$datadir/sbahn");
	BBBike::fast_plot_str($c, "b", $s, 0, undef, $category_width);
    }

    $top->after(5000, sub { $top->destroy });
    Tk::MainLoop();
}

$s = new Strassen "strassen";

if ($test_make_net) {
    print "# Test make_net\n";
    $StrassenNetz::VERBOSE = 1;

    checkpoint1();
    for $pass (1 .. 3) {
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
	    for $i (1 .. 10) {
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
	    for $i (1 .. 10) {
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

$scale = 0.5;
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

sub checkpoint1 {
    if ($leaktest) {
	eval {
	    $count1 = Devel::Leak::NoteSV($handle);
	};
    }

}

sub checkpoint2 {
    my($tolerated_difference) = shift || 0;
    if ($leaktest) {
	eval {
	    $count2 = Devel::Leak::CheckSV($handle);
	    if ($count1 != $count2-$tolerated_difference) {
		warn "" . ($count2-$count1) . " new scalars since last checkpoint\n";
	    }
	};
    }
}

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
