use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";

use Test::More;
my $tk_tests = 2;
plan tests => 23 + $tk_tests;

use_ok 'Met::Wind', 'wind_velocity';

foreach ([text_de => 'Stille', beaufort => 0],
	 [text_de => 'Stille', 'm/s'    => 0.1],
	 [text_en => 'calm',   beaufort => 0],
	 [text_en => 'calm',  'm/s'    => 0.1],
	 [text_de => 'Sturm',  beaufort => 9],
	 [text_de => 'Sturm', 'km/h'    => 81.15], # Mitte des Bereichs 74.5..87.8
	 [text_en => 'strong gale', beaufort => 9],
	 [text_en => 'strong gale', 'km/h'   => 81.15],
	 ['m/s'   => 17.2,     beaufort => 8],
	 ['km/h'  => 117.4,    text_de  => 'orkanartiger Sturm'],
	 ['km/h'  => 117.4,    text_en  => 'violent storm'],
	 ['m/s'   => 10,       'km/h'   => 36],
	 ['mi/h'  => 1,        'km/h'   => 1.609344],
	 ['km/h'  => 1852,     'sm/h'   => 1000],
	 ['km/h'  => 36,       'm/s'    => 10],
	) {
    is wind_velocity([$_->[1], $_->[0]], $_->[2]), $_->[3],
	"Check for $_->[1] $_->[0]] => $_->[2]";
    if ($_->[0] !~ /^text/) {
	is wind_velocity("$_->[1] $_->[0]", $_->[2]), $_->[3],
	    "Check for $_->[1] $_->[0]] => $_->[2]";
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
    no warnings 'once';
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

SKIP: {
    skip "Tk is required for this test", $tk_tests
	if !eval { require Tk; 1 };
    my $mw = eval { MainWindow->new };
    skip "Cannot create main window", $tk_tests
	if !$mw;
    $mw->geometry('+0+0');
    my $tl = Met::Wind::beaufort_table($mw);
    ok(Tk::Exists($tl), 'Beaufort table window exists');
    my $tl2 = Met::Wind::beaufort_table($mw,
					-popover => undef,
					-command => sub { warn "@_" });
    ok(Tk::Exists($tl2), 'Other beaufort table window exists');
    $tl->update;
    unless ($ENV{INTERACTIVE}) {
	$mw->destroy;
    }
    Tk::MainLoop();
}
