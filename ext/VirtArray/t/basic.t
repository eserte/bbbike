# -*- perl -*-

use VirtArray;
use File::Temp qw(tempfile);
use Test;
use Getopt::Long;
BEGIN { plan tests => 28 }


#$VirtArray::VERBOSE = 1;
$do_benchmark = 0;
$do_memory_check = 0;
$v = 0;
$^W = 1;

if (!GetOptions("benchmark!" => \$do_benchmark,
		"memory!"    => \$do_memory_check,
		"v!" => \$v,
	       )) {
    die "usage!";
}

ok(1);

for (0 .. 5) {
    (undef, $tmpfile[$_]) = tempfile(UNLINK => 1)
	or die "Cannot create tempfile: $!";
}

for(0..1000) {
    push @a, $_;
    push @fixed, pack("l", $_);
}

###

VirtArray::store(\@fixed, $tmpfile[2]);
@fixed_b = @{VirtArray::retrieve($tmpfile[2])};

ok($#fixed == $#fixed_b, 1, "Different lengths: $#fixed vs. $#fixed_b");

{
    my $ok = 1;

    for($i=0; $i<=$#fixed; $i++) {
	if ($fixed[$i] ne $fixed_b[$i]) {
	    $ok = 0;
	    last;
	}
    }

    ok($ok);
}

### now it's stored...
if (@ARGV && $ARGV[0] eq '-memorycheck') {
    goto MEMORYCHECK;
}

$o = tie @fixed_c, 'VirtArray', $tmpfile[2];
ok(tied(@fixed_c));

$o->printinfo if $v;

ok(scalar @fixed == $o->FETCHSIZE, 1,
   "Different lengths: " . scalar(@fixed) . " vs. " . $o->FETCHSIZE);

{
    my $ok = 1;

    for($i=0; $i<=$#fixed; $i++) {
	if ($fixed[$i] ne $fixed_c[$i]) {
	    print STDERR "Index $i: $fixed[$i] $fixed_c[$i]\n";
	    $ok = 0;
	    last;
	}
    }

    ok($ok);
}
undef $o;
untie @fixed_c;

###

VirtArray::store(\@a, $tmpfile[0]);
@b = @{VirtArray::retrieve($tmpfile[0])};

ok($#a == $#b, 1, "Different lengths: $#a vs. $#b");

{
    my $ok = 1;

    for($i=0; $i<=$#a; $i++) {
	if ($a[$i] ne $b[$i]) {
	    $ok = 0;
	    last;
	}
    }

    ok($ok);
}

$o2 = tie @c, 'VirtArray', $tmpfile[0];
ok(tied(@c));

ok(scalar @a == $o2->FETCHSIZE, 1,
   "Different lengths: " . scalar(@a) . " vs. " . $o2->FETCHSIZE);

{
    my $ok = 1;

    for($i=0; $i<=$#a; $i++) {
	if ($a[$i] ne $c[$i]) {
	    print STDERR "Index $i: $a[$i] <$c[$i]>\n";
	    $ok = 0;
	    last;
	}
    }

    ok($ok);
}

###

for(0..100) {
    push @d, pack("l$_", ($_)x$_);
}

VirtArray::store(\@d, $tmpfile[3]);
@d2 = @{VirtArray::retrieve($tmpfile[3])};

ok($#d == $#d2, 1, "Different lengths: $#d vs. $#d2");

$o3 = tie @d3, 'VirtArray', $tmpfile[3];
ok(tied(@d3));

{
    no warnings 'once';
    *VirtArray::fetch_list = \&VirtArray::fetch_list_var;
}

ok(unpack("l50", $d[50]), $o3->fetch_list(50));

###

my(@a);
for(0..100) {
    push @a, [$_, $_+1, {'x' => $_+2}];
}
VirtArray::store(\@a, $tmpfile[5]);
my(@a2) = @{VirtArray::retrieve($tmpfile[5])};

ok($#a == $#a2, 1, "Different lengths: $#a vs. $#a2");
ok(ref $a2[50], 'ARRAY', "Wrong data in \@a");
ok(scalar @{$a2[50]}, 3, "Wrong length of array element in \@a");
ok(ref $a2[50]->[2], 'HASH', "Wrong data in 3rd element of array element in \@a");
ok($a2[50]->[0], 50, "Wrong value in first element");
ok($a2[50]->[1], 51, "Wrong value in second element");
ok($a2[50]->[2]{'x'}, 52, "Wrong value in third element");

my(@a3);
$o4 = tie @a3, 'VirtArray', $tmpfile[5];
ok(tied(@a3));
ok(ref $a3[50], 'ARRAY', "Wrong data in \@a");
ok(scalar @{$a3[50]}, 3, "Wrong length of array element in \@a");
ok(ref $a3[50]->[2], 'HASH', "Wrong data in 3rd element of array element in \@a");
ok($a3[50]->[0], 50, "Wrong value in first element");
ok($a3[50]->[1], 51, "Wrong value in second element");
ok($a3[50]->[2]{'x'}, 52, "Wrong value in third element");
undef $o4;
untie @a3;

###

if ($do_benchmark) {
    no warnings 'void';
    require Benchmark;
    Benchmark::timethese
      (-2,
       {
	'Array' => sub {
	    for(0 .. 100) {
		unpack("l$_", $d[$_]);
	    }
	},
	'VirtArray' => sub {
	    for(0 .. 100) {
		$o3->fetch_list_var($_);
	    }
	},
	'VirtArray2' => sub {
	    for(0 .. 100) {
		$o3->fetch_list($_);
	    }
	},
       }
      );
}

undef $o3;
untie @d3;

###

if ($do_benchmark) {
    for (0..1000) {
	$c{$_} = $_;
    }
    VirtArray::set_default($o2);
    make_tie_mmaparray();
    require Benchmark;
    Benchmark::timethese
      (-2,
       {
	'Array' => sub { for($i=0; $i<=$#a; $i++) { $x = $a[$i] } },
	'VirtArray' => sub { for($i=0; $i<=$#a; $i++) { $x = $c[$i] } },
	'VirtArray->FETCH' => sub { for($i=0; $i<=$#a; $i++) { $x = $o2->FETCH($i)} },
	'VirtArray::FETCH' => sub { for($i=0; $i<=$#a; $i++) { $x = VirtArray::FETCH($o2, $i)} },
	'VirtArray::fast_fetch' => sub { for($i=0; $i<=$#a; $i++) { $x = VirtArray::fast_fetch($i)} },
	'VirtArray::fast_fetch_var' => sub { for($i=0; $i<=$#a; $i++) { $x = VirtArray::fast_fetch_var($i)} },
	'Hash' => sub { for($i=0; $i<=$#a; $i++) { $x = $c{$i} } },
#XXX using for (0..$#mmaparray) seems to generate an endless loop?
	(@mmaparray ? ('Tie::MmapArray' => sub { for($i=0; $i<=$#a; $i++) { $x = $mmaparray[$i]; } }) : ()),
       }
      );
}

undef $o2;
untie @c;

###

MEMORYCHECK:

if ($do_memory_check) {
    my @e;
    my $max = 150000;
    require Storable;
    if (!-e $tmpfile[4] && !-e $tmpfile[4].".store") {
	for(my $i = 0; $i <= $max; $i++) {
	    push @e, pack("l2", $i, $max-$i);
	}

	VirtArray::store(\@e, $tmpfile[4]);
	Storable::store(\@e, $tmpfile[4].".store");

	undef @e;
    }

    my $emptymem = get_proc_memory();
    warn "Memory while empty: $emptymem\n";

    # make two loops ... to check whether the OS will reuse memory
    for my $loop (1..2) {
	my $o3 = tie @e, 'VirtArray', $tmpfile[4];

	my $mem = get_proc_memory();
	warn "Memory while VirtArray ($loop): $mem (+" . ($mem-$emptymem) . ")\n";

	for(my $i=0; $i<$max;$i++) {
	    my($x,$y) = $o3->fetch_list_fixed($i);
	}

	# Should grow to last memory usage + size of mmap'ed file
	$mem = get_proc_memory();
	warn "Memory after fetching values from VirtArray ($loop): $mem (+" . ($mem-$emptymem) . ")\n";

	undef $o3;
	untie @e;

	# XXX Should shrink again, but it does not...
	$mem = get_proc_memory();
	warn "Memory while empty again ($loop): $mem (+" . ($mem-$emptymem) . ")\n";
	$emptymem = $mem;
    }

    @e = @{Storable::retrieve($tmpfile[4].".store")};

    my $mem = get_proc_memory();
    warn "Memory while normal Array: $mem (+" . ($mem-$emptymem) . ")\n";

}

sub make_tie_mmaparray {
    if (eval q{ require Tie::MmapArray; 1}) {
	tie @mmaparray, 'Tie::MmapArray', $tmpfile[2],
	    { template => 'i',
	      mode => "rw",
	    }
		or die "Can't Tie::MmapArray: $!";
    }
}

sub get_proc_memory {
    return "???" if $^O !~ /(bsd$|linux)/; # XXX
    open(PS, "ps -o pid,rss|");
    my $mem;
    while(<PS>) {
	if (/^\s*$$\s+(\d+)/) {
	    $mem = $1;
	    last;
	}
    }
    close PS;
    $mem;
}
