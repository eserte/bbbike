# -*- perl -*-

use strict;
use warnings;

use File::Temp qw(tempfile);
use Getopt::Long;

use Test::More tests => 20;

use VirtArray;

#$VirtArray::VERBOSE = 1;
my $do_benchmark = 0;
my $do_memory_check = 0;
my $v = 0;

if (!GetOptions("benchmark!" => \$do_benchmark,
		"memory!"    => \$do_memory_check,
		"v!" => \$v,
	       )) {
    die "usage!";
}

pass "module loaded";

my @tmpfile;
for (0 .. 6) {
    (undef, $tmpfile[$_]) = tempfile(UNLINK => 1)
	or die "Cannot create tempfile: $!";
}

my @mmaparray;
my(@a, @fixed);
for(0..1000) {
    push @a, $_;
    push @fixed, pack("l", $_);
}

###

{
    VirtArray::store(\@fixed, $tmpfile[2]);
    my @fixed_b = @{VirtArray::retrieve($tmpfile[2])};
    is_deeply \@fixed_b, \@fixed, 'store-retrieve roundtrip (packed elements)';
}

{
    my $o = tie my @fixed_c, 'VirtArray', $tmpfile[2];
    ok tied(@fixed_c), 'variable is tied';

    $o->printinfo if $v;

    is $o->FETCHSIZE, scalar(@fixed), 'same lengths';
    is_deeply \@fixed_c, \@fixed, 'same contents through tied variable';
}

###

{
    VirtArray::store(\@a, $tmpfile[0]);
    my @b = @{VirtArray::retrieve($tmpfile[0])};

    is_deeply \@b, \@a, 'store-retrieve roundtrip (integers)';
}

{
    my $o = tie my @c, 'VirtArray', $tmpfile[0];
    ok tied(@c), 'variable is tied';

    $o->printinfo if $v;

    is $o->FETCHSIZE, scalar(@a), 'same lengths';
    is_deeply \@c, \@a, 'same contents through tied variable';

if ($do_benchmark) {
    my %c;
    for (0..1000) {
	$c{$_} = $_;
    }
    VirtArray::set_default($o);
    make_tie_mmaparray();
    require Benchmark;
    Benchmark::timethese
      (-1,
       {
	'Array' => sub { for(my $i=0; $i<=$#a; $i++) { my $x = $a[$i] } },
	'VirtArray' => sub { for(my $i=0; $i<=$#a; $i++) { my $x = $c[$i] } },
	'VirtArray->FETCH' => sub { for(my $i=0; $i<=$#a; $i++) { my $x = $o->FETCH($i)} },
	'VirtArray::FETCH' => sub { for(my $i=0; $i<=$#a; $i++) { my $x = VirtArray::FETCH($o, $i)} },
	'VirtArray::fast_fetch' => sub { for(my $i=0; $i<=$#a; $i++) { my $x = VirtArray::fast_fetch($i)} },
	'VirtArray::fast_fetch_var' => sub { for(my $i=0; $i<=$#a; $i++) { my $x = VirtArray::fast_fetch_var($i)} },
	'Hash' => sub { for(my $i=0; $i<=$#a; $i++) { my $x = $c{$i} } },
#XXX using for (0..$#mmaparray) seems to generate an endless loop?
	(@mmaparray ? ('Tie::MmapArray' => sub { for(my $i=0; $i<=$#a; $i++) { my $x = $mmaparray[$i]; } }) : ()),
       }
      );
}

}

###

{
    my @d = ("aaa"); # used to start with an empty string, but see below
    for(1..100) {
	push @d, pack("l$_", ($_)x$_);
    }

    VirtArray::store(\@d, $tmpfile[3]);
    my @d2 = @{VirtArray::retrieve($tmpfile[3])};

    is_deeply \@d2, \@d, 'store-retrieve roundtrip (variable length)';

    my $o = tie my @d3, 'VirtArray', $tmpfile[3];
    ok tied(@d3), 'variable is tied';

    is_deeply \@d3, \@d, 'same contents through tied variable';

    is $o->fetch_list_var(50), unpack("l50", $d[50]), 'fetch_list_var call';

    if ($do_benchmark) {
	no warnings 'void';
	require Benchmark;
	Benchmark::timethese
		(-1,
		 {
		  'Array' => sub {
		      for(0 .. 100) {
			  unpack("l$_", $d[$_]);
		      }
		  },
		  'VirtArray' => sub {
		      for(0 .. 100) {
			  $o->fetch_list_var($_);
		      }
		  },
		 }
		);
    }
}

###

{
    my @d = ("", "abc");

    VirtArray::store(\@d, $tmpfile[6]);
    my @d2 = @{VirtArray::retrieve($tmpfile[6])};

    is_deeply \@d2, \@d, 'store-retrieve roundtrip (array with empty strings)';

    my $o = tie my @d3, 'VirtArray', $tmpfile[6];
    ok tied(@d3), 'variable is tied';

    local $TODO = "It seems that VirtArray cannot handle empty strings properly";

    is_deeply \@d3, \@d, 'same contents through tied variable';
    is $o->fetch_list_var(0), "";
    is $o->fetch_list_var(1), "abc";
}

###

{
    my @a;
    for(0..100) {
	push @a, [$_, $_+1, {'x' => $_+2}];
    }
    VirtArray::store(\@a, $tmpfile[5]);
    my @a2 = @{VirtArray::retrieve($tmpfile[5])};

    is_deeply \@a2, \@a, 'complex data';

    my $o = tie my @a3, 'VirtArray', $tmpfile[5];

    is_deeply \@a3, \@a, 'tied complex data';
}

###

if ($do_memory_check) {
    my $max = 150000;
    require Storable;
    {
	my @e;
	for my $i (0..$max) {
	    push @e, pack("l2", $i, $max-$i);
	}

	VirtArray::store(\@e, $tmpfile[4]);
	Storable::store(\@e, $tmpfile[4].".store");
    }

    my $emptymem = get_proc_memory();
    warn "Memory while empty: $emptymem\n";

    # make two loops ... to check whether the OS will reuse memory
    for my $loop (1..2) {
	my $o3 = tie my @e, 'VirtArray', $tmpfile[4];

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

    my @e = @{Storable::retrieve($tmpfile[4].".store")};

    my $mem = get_proc_memory();
    warn "Memory while normal Array: $mem (+" . ($mem-$emptymem) . ")\n";

    unlink $tmpfile[4].".store";
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
