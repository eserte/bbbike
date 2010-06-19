# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..15\n"; }
END {print "not ok 1\n" unless $loaded;}
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Met::Wind;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

$num = 2;
foreach ([text_de => 'Stille', beaufort => 0],
	 [text_de => 'Stille', 'm/s'    => 0.1],
	 ['m/s'   => 17.2,     beaufort => 8],
	 ['km/h'  => 117.4,    text_de  => 'orkanartiger Sturm'],
	 ['m/s'   => 10,       'km/h'   => 36],
	 ['mi/h'  => 1,        'km/h'   => 1.609344],
	 ['km/h'  => 1852,     'sm/h'   => 1000],
	 ['km/h'  => 36,       'm/s'    => 10],
	) {
    if (wind_velocity([$_->[1], $_->[0]], $_->[2]) ne $_->[3]) {
	print "not ";
    }
    print "ok $num\n";
    $num++;
    if ($_->[0] !~ /^text/) {
	if (wind_velocity("$_->[1] $_->[0]", $_->[2]) ne  $_->[3]) {
	    print "not ";
	}
	print "ok $num\n";
	$num++;
    }
}

if (0) {
    warn "Beaufort:\n";
    for (0 .. 17) {
	my($de_text, $ms, $kmh, $mih, $kn) =
	  (wind_velocity([$_, 'beaufort'], 'text_de'),
	   wind_velocity([$_, 'beaufort'], 'm/s'),
	   wind_velocity([$_, 'beaufort'], 'km/h'),
	   wind_velocity([$_, 'beaufort'], 'mi/h'),
	   wind_velocity([$_, 'beaufort'], 'kn'),
	  );
	warn "$_: $de_text, $ms m/s, $kmh km/h, $mih mi/h, $kn kn\n";
    }
    warn "\nText:\n";
    foreach (@Met::Wind::wind_table) {
	my $de_text = $_->[1];
	my($bft, $ms, $kmh, $mih, $kn) =
	  (wind_velocity([$de_text, 'text_de'], 'beaufort'),
	   wind_velocity([$de_text, 'text_de'], 'm/s'),
	   wind_velocity([$de_text, 'text_de'], 'km/h'),
	   wind_velocity([$de_text, 'text_de'], 'mi/h'),
	   wind_velocity([$de_text, 'text_de'], 'kn'),
	  );
	warn "$de_text: $bft, $ms m/s, $kmh km/h, $mih mi/h, $kn kn\n";
    }
    warn "\nKn:\n";
    for(my $kn = 0; $kn <= 120; $kn += ($kn > 100 ? 10 : 2)) {
	my($bft, $text_de, $ms, $kmh, $mih) =
	  (wind_velocity([$kn, 'sm/h'], 'beaufort'),
	   wind_velocity([$kn, 'sm/h'], 'text_de'),
	   wind_velocity([$kn, 'sm/h'], 'm/s'),
	   wind_velocity([$kn, 'sm/h'], 'km/h'),
	   wind_velocity([$kn, 'sm/h'], 'mi/h'),
	  );
	warn "$kn: $bft, $text_de, $ms m/s, $kmh km/h, $mih mi/h\n";	
    }
}

if (0) {
    open(W, ">/tmp/windchill") or die $!;
    for my $wv (0 .. 100) {
	for my $temp (-30 .. 10) {
	    my $wc = wind_chill("$wv km/h", $temp, 'tsp');
	    if (defined $wc) {
		print W "$temp $wv $wc\n";
	    }
	}
    }
    close W;
}

use Tk;
$top = new MainWindow;
$tl = Met::Wind::beaufort_table($top);
$tl2 = Met::Wind::beaufort_table($top,
				 -popover => undef,
				 -command => sub { warn "@_" });
$tl->update;
unless ($ENV{INTERACTIVE}) {
    $top->destroy;
}
MainLoop;
