#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2004,2010,2016,2024,2026 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../data",
	);
use BBBikeUtil qw(bbbike_root bbbike_aux_dir);
use Strassen;
eval 'use BBBikeXS';
#use Hash::Util qw(lock_keys);
use Getopt::Long;
use Fcntl qw(LOCK_EX LOCK_NB);

my $miscsrc = bbbike_root . "/miscsrc";
my $datadir = bbbike_root . "/data";

my $do_display = 0;
my $one_instance = 0;
my $winter_hardness = 'snowy';
my $as_json;
my $destdir;
my $add_uid;

if (!GetOptions("display" => \$do_display,
		"one-instance" => \$one_instance,
		"destdir=s" => \$destdir,
		"add-uid" => \$add_uid,
		"winter-hardness=s" => \$winter_hardness,
		"as-json" => \$as_json,
	       )) {
    die "usage: $0 [-display] [-one-instance] [-destdir ...] [-add-uid] [-as-json] [-winter-hardness snowy|very_snowy|dry_cold]\n";
}

if ($as_json) {
    require JSON::XS;
} else {
    require Storable;
}

# compat for old integers
if ($winter_hardness eq '1') {
    $winter_hardness = 'snowy';
} elsif ($winter_hardness eq '2') {
    $winter_hardness = 'very_snowy';
}

my %usability_desc;
my %usability_descs =
    (
	# generic scenarios
	'light_snowy' => {
	    cat_to_usability => { NN => 2,
				  N  => 4,
				  NH => 6,
				  H  => 6,
				  HH => 6,
				  B  => 6,
			      },
	    do_kfz_adjustment    => 1,
	    do_living_street_opt => 1,
	    do_cycleroad_opt     => 1, # upgrade to NH usability (guessed)
	    do_busroute_opt      => 1,
	    do_cobblestone_opt   => 0,
	    do_tram_opt          => 0,
	    do_green_NN_opt      => 0,
	},
	'snowy' => { # XXX not reviewed
	    cat_to_usability => { NN => 1,
				  N  => 3,
				  NH => 4,
				  H  => 5,
				  HH => 6,
				  B  => 6,
			      },
	    do_kfz_adjustment  => 1, # use -2/-1/+1/+2 adjustment from comments_kfzverkehr
	    do_cobblestone_opt => 1,
	    do_tram_opt        => 1,
	},
	'very_snowy' => { # XXX not reviewed
	    cat_to_usability => { NN => 1,
				  N  => 2,
				  NH => 4,
				  H  => 5,
				  HH => 6,
				  B  => 6,
			      },
	    do_kfz_adjustment  => 1, # use -2/-1/+1/+2 adjustment from comments_kfzverkehr
	    do_cobblestone_opt => 1,
	    do_tram_opt        => 1,
	},
	'dry_cold' => { # XXX not reviewed
	    cat_to_usability => { NN => 1, # dry but icy cyclepaths
				  N  => 6,
				  NH => 6,
				  H  => 6,
				  HH => 6,
				  B  => 6,
			      },
	    do_kfz_adjustment  => 0,
	    do_cobblestone_opt => 0,
	    do_tram_opt        => 0,
	},
	'grade1' => { # XXX not reviewed: frischer Schnee: nur HH gut befahrbar, H und NH mit Abstufungen
	    cat_to_usability => { NN => 1,
				  N  => 1,
				  NH => 2,
				  H  => 2,
				  HH => 6,
				  B  => 6,
			      },
	},
	'grade2' => { # XXX not reviewed: nach 2-3 Tagen: HH, H, NH, Bus gut befahrbar
	    cat_to_usability => { NN => 1,
				  N  => 1,
				  NH => 6,
				  H  => 6,
				  HH => 6,
				  B  => 6,
			      },
	    do_busroute_opt     => 1,
	},
	'grade3' => { # XXX not reviewed: nach 3-4 Tagen: HH, H, NH, N gut befahrbar (außer RW6)
	    cat_to_usability => { NN => 1,
				  N  => 6,
				  NH => 6,
				  H  => 6,
				  HH => 6,
				  B  => 6,
			      },
	    do_busroute_opt      => 1,
	    do_living_street_opt => 1,
	},
	# experiments
	'XXX_busroute' => {
	    cat_to_usability => { NN => 1,
				  N  => 1,
				  NH => 6,
				  H  => 6,
				  HH => 6,
				  B  => 6,
			      },
	    do_busroute_opt     => 1,
	},
	# special scenarios
	'jan_2026' => { # some snowy days, freezing rain
	    cat_to_usability => { NN => 1,
				  N  => 4,
				  NH => 6,
				  H  => 6,
				  HH => 6,
				  B  => 6,
			      },
	    do_kfz_adjustment    => 1,
	    do_living_street_opt => 1,
	    do_busroute_opt      => 1,
	    do_cobblestone_opt   => 0,
	    do_tram_opt          => 0,
	},
	'feb_2026' => { # icy paths, fresh snow, updated several times
	    #                               -04 -05 -06 07- 10- 11-
	    cat_to_usability => { NN => 2, # 1   1   1   1   1   2
				  N  => 6, # 3   2   2   4   5   6
				  NH => 6, # 6   4   6   6   6   6
				  H  => 6, # 6   5   6   6   6   6
				  HH => 6, # 6   5   6   6   6   6
				  B  => 6, # 6   5   6   6   6   6
			      },
	    do_kfz_adjustment    => 0,
	    do_living_street_opt => 0,
	    do_cycleroad_opt     => 1, # upgrade to NH usability
	    do_busroute_opt      => 1,
	    do_cobblestone_opt   => 0,
	    do_tram_opt          => 0,
	    do_green_NN_opt      => 1,
	    exceptions_file      => 'winteroptimization_exceptions_2026_02.bbd',
	}
    );
if ($winter_hardness eq 'feb_2026_b') {
    %usability_desc = %{ $usability_descs{light_snowy} };
    $usability_desc{exceptions_file} = 'winteroptimization_exceptions_2026_02.bbd';
} elsif (exists $usability_descs{$winter_hardness}) {
    %usability_desc = %{ $usability_descs{$winter_hardness} };
} else {
    die "Unknown winter-hardness '$winter_hardness'. Valid values are: " . join(',', sort keys %usability_descs) . "\n"
}
my %cat_to_usability   = %{ $usability_desc{cat_to_usability} };
my $do_cobblestone_opt =    $usability_desc{do_cobblestone_opt};
my $do_kfz_adjustment  =    $usability_desc{do_kfz_adjustment};
my $do_tram_opt        =    $usability_desc{do_tram_opt};
my $do_busroute_opt    =    $usability_desc{do_busroute_opt};
my $do_cyclepath_opt   = 0; # Bei Winterwetter können Radwege komplett ignoriert werden
my $do_bridge_opt      = 0; # I don't think anymore bridges are critical (and mostly if you have to use one, then usually you cannot avoid it at all)
my $do_living_street_opt =  $usability_desc{do_living_street_opt};
my $do_cycleroad_opt   =    $usability_desc{do_cycleroad_opt};
my $do_green_NN_opt    =    $usability_desc{do_green_NN_opt};

my $exceptions_file;
if ($usability_desc{exceptions_file}) {
    my @candidates = (
	bbbike_aux_dir . '/bbd/' . $usability_desc{exceptions_file},
	bbbike_root . "/tmp/" . $usability_desc{exceptions_file},
    );
    my $f;
    for my $candidate (@candidates) {
	if (-r $candidate && -s $candidate) {
	    $f = $candidate;
	    last;
	}
    }
    if (!defined $f) {
	warn "WARNING: the specified exceptions file does not exist, checked in '@candidates', continue without!\n";
    } else {
	$exceptions_file = $f;
    }
}

$destdir = bbbike_root . "/tmp" if !$destdir;
my $outfile = "$destdir/winter_optimization." . $winter_hardness . "." . ($add_uid ? "$<." : "") . ($as_json ? 'json' : 'st');

my $lock_file = "/tmp/winter_optimization." . ($add_uid ? "$<." : ""). "lck";
if ($one_instance) {
    open(LCK, "> $lock_file");
    if (!flock LCK, LOCK_EX|LOCK_NB) {
	warn "winter_optimization process running, waiting for lock...\n";
	flock LCK, LOCK_EX;
	if (!-e $outfile) {
	    die "$outfile was not built?";
	}
	warn "release lock, assume $outfile is built\n";
	exit 0;
    }
}

my $strassen_orig = "$datadir/strassen-orig";

my %str;
if (-r $strassen_orig) {
    my($strassen_with_NH_file) = create_strassen_with_NH();
    $str{"s"} = Strassen->new($strassen_with_NH_file);
} else {
    $str{"s"} = Strassen->new("strassen");
}

if ($do_bridge_opt) {
    $str{"br"} = Strassen->new("brunnels");
}
$str{"qs"} = Strassen->new("qualitaet_s");
if ($do_cyclepath_opt || $do_cycleroad_opt || $do_living_street_opt) {
    $str{"rw"} = Strassen->new("radwege_exact");
}
if ($do_kfz_adjustment) {
    $str{"kfz"} = Strassen->new("comments_kfzverkehr");
}
if ($do_tram_opt) {
    $str{"tram"} = Strassen->new("comments_tram");
}
if ($do_busroute_opt) {
    my($busroute_file) = create_busroute();
    $str{"busroute"} = Strassen->new($busroute_file);
}
if ($do_green_NN_opt) {
    $str{"green"} = Strassen->new("green");
}
if (defined $exceptions_file) {
    $str{"exceptions"} = Strassen->new($exceptions_file);
}
#lock_keys %str;

my %net;
for my $type (keys %str) {
    $net{$type} = StrassenNetz->new($str{$type});
    my %args = (-usecache => 1);
    if ($type =~ /^(s|qs|exceptions)$/) {
	$args{-net2name} = 1;
    }
    if ($type eq 's') {
	$args{-multiple} = 1;
    }
    if ($type eq 'rw') {
	$args{-obeydir} = 1;
    }
    $net{$type}->make_net_cat(%args);
}
#lock_keys %net;

my $net = {};

if ($do_display) {
    print <<EOF;
#: title: Winteroptimization (type $winter_hardness)
#: line_arrow: last
#: line_do_offset: 1
#:
# 
EOF
}

while(my($k1,$v) = each %{ $net{"s"}->{Net} }) {
    while(my($k2,$cat) = each %$v) {
	#my($xxx) = $net{"s"}->get_street_record($k1, $k2); next if $xxx->[Strassen::NAME] !~ /admiralbrücke/i;#XXX

        my $res = 99999;
	my @reason;

    CALC: {

	    if (defined $exceptions_file) {
		my $final_res = $net{'exceptions'}->{Net}{$k1}{$k2};
		if (defined $final_res) {
		    my $rec = $net{'exceptions'}->get_street_record($k1, $k2);
		    (my $name = $rec->[Strassen::NAME]) =~ s{^.*?:\s*}{};
		    $res = $final_res;
		    push @reason, $name;
		    last CALC;
		}
	    }

	    my $quality_penalty = 0;
	    if ($do_cobblestone_opt) {
		my $q = $net{"qs"}->{Net}{$k1}{$k2};
		if (defined $q) {
		    if ($q =~ /^Q(\d+)/) {
			my $cat = $1;
			my $rec = $net{"qs"}->get_street_record($k1, $k2);
			if ($rec->[Strassen::NAME] =~ /(kopfstein|verbundstein)/i) {
			    if ($cat =~ /^3/) {
				$res = 0;
				push @reason, "Schlechtes Kopfsteinpflaster";
				last CALC;
			    } else {
				$res = 1;
				push @reason, "Kopfsteinpflaster";
			    }
			} elsif ($cat ne "0") {
			    $quality_penalty = 1;
			    push @reason, "Quality penalty";
			}
		    }
		}
	    }

	    if ($do_cyclepath_opt) {
		my $rw = $net{"rw"}->{Net}{$k1}{$k2};
		if (defined $rw) {
		    if ($rw =~ /^RW(2|8|)$/) {
			$res = 1;
			push @reason, "benutzungspflichtiger Radweg";
		    }
		}
	    }

	    if ($do_living_street_opt) {
		my $rw = $net{"rw"}->{Net}{$k1}{$k2};
		if (defined $rw) {
		    if ($rw =~ /^RW6$/) {
			$res = 1;
			push @reason, "verkehrsberuhigter Bereich";
		    }
		}
	    }

	    my $main_cat;
	    my $is_bridge;
	    for (@$cat) {
		next if $_ eq 'Pl';
		if ($do_bridge_opt && $_ eq 'Br') {
		    $is_bridge = 1;
		} elsif (defined $main_cat) {
		    my $rec = $net{"s"}->get_street_record($k1, $k2);
		    require Data::Dumper;
		    print STDERR Data::Dumper->new([$rec,"$k1 $k2"],[])->Indent(1)->Useqq(1)->Dump;
		    warn "Multiple main categories found: $_ vs. $main_cat";
		} else {
		    $main_cat = $_;
		}
	    };
	    next if !defined $main_cat; # may happen for "Pl"

	    my $cat_num = $cat_to_usability{$main_cat};
	    if (!defined $cat_num) {
		my $rec = $net{"s"}->get_street_record($k1, $k2);
		require Data::Dumper;
		print STDERR Data::Dumper->new([$rec,"$k1 $k2"],[])->Indent(1)->Useqq(1)->Dump;
		warn "Category $main_cat unhandled...\n";
		last CALC;
	    }

	    if ($do_green_NN_opt && $main_cat eq 'NN') {
		my $green = $net{"green"}->{Net}{$k1}{$k2};
		if (!defined $green) {
		    push @reason, 'keine Grünanlage';
		    $cat_num = $cat_to_usability{N}; # upgrade to N
		}
		# XXX. evtl noch weitere Indikatoren benutzen, z.B. "Grünanlage/Grünanlagenschild" in handicap_s-orig beachten, im Namen bzw. in der note-Direktive
	    }

	    if (!$is_bridge && defined $net{"br"}->{Net}{$k1}{$k2} && $net{"br"}->{Net}{$k1}{$k2} eq 'Br') {
		$is_bridge = 1;
	    }

	    my $kfz = $net{"kfz"}->{Net}{$k1}{$k2};
	    if ($do_kfz_adjustment && defined $kfz && $kfz != 0) {
		if ($kfz >= +2) {
		    $cat_num = $cat_to_usability{adjust_cat($main_cat, +1)};
		} elsif ($kfz == +1) {
		    my $higher_cat_num = $cat_to_usability{adjust_cat($main_cat, +1)};
		    $cat_num = ($cat_num + $higher_cat_num)/2;
		} elsif ($kfz == -1) {
		    my $lower_cat_num = $cat_to_usability{adjust_cat($main_cat, -1)};
		    $cat_num = ($cat_num + $lower_cat_num)/2;
		} elsif ($kfz <= -2) {
		    $cat_num = $cat_to_usability{adjust_cat($main_cat, -1)};
		} else {
		    warn "Should not happen: kfz '$kfz' unhandled...";
		    # continue with unchanged $cat_num
		}
		push @reason, $main_cat . $kfz;
	    } else {
		push @reason, $main_cat;
	    }

	    if ($do_cycleroad_opt) {
		# upgrade cycleroads to at least NH roads
		my $rw = $net{"rw"}->{Net}{$k1}{$k2};
		if (defined $rw && $rw =~ /^RW7$/) {
		    my $maybe_catnum = $cat_to_usability{NH};
		    if ($maybe_catnum > $cat_num) {
			$cat_num = $maybe_catnum;
			push @reason, "Fahrradstraße";
		    }
		}
	    }

	    $res = $cat_num if $cat_num < $res;

	    if ($is_bridge) {
		$res -= 2;
		push @reason, "Brücke";
	    }

	    $res -= $quality_penalty;

	    if ($do_tram_opt) {
		my $tram = $net{"tram"}->{Net}{$k1}{$k2};
		if (defined $tram) {
		    $res -= 1;
		    push @reason, "Tram";
		}
	    }

	    if ($do_busroute_opt) {
		my $busroute = $net{"busroute"}->{Net}{$k1}{$k2};
		if (defined $busroute && $res < $cat_to_usability{B}) { # assume B has always the highest usability
		    $res = $cat_to_usability{B};
		}
	    }

	    if    ($res < 0) { $res = 0 }
	    elsif ($res > 6) { $res = 6 }
	}

	if (defined $res) {
	    $cat = $res;
	} else {
	    $cat = 0;
	}

	my $out_cat = int($cat/6*100);
	$net->{"$k1,$k2"} = $out_cat;

	if ($do_display) {
	    my $color = ['#a00000',
			 '#ff4400',
			 '#ffaa00',
			 '#f6ff00',
			 '#60c000',
			 '#00c000',
			 '#0000ff',
			]->[$cat];
	    print "$cat ($out_cat%) " . join(", ", @reason) . "\t$color; $k1 $k2\n";
	}
    }
}

if ($as_json) {
    my $json = JSON::XS->new->ascii->encode($net);
    open my $ofh, ">", "$outfile.$$~"
	or die "Cannot write to $outfile.$$~: $!";
    print $ofh $json;
    close $ofh or die $!;
} else {
    Storable::nstore($net, "$outfile.$$~");
}
chmod 0644, "$outfile.$$~";
rename "$outfile.$$~", $outfile
    or die "Can't rename from $outfile.$$~ to $outfile: $!";

# The data/Makefile rules .strassen.tmp and strassen,
# without the NH replacement
sub create_strassen_with_NH {
    use File::Temp qw(tempfile);
    use IPC::Run qw(run);
    my($tmpfh,$tmpfile) = tempfile(SUFFIX => ".bbd", UNLINK => 1);
    run(["$miscsrc/convert_orig_to_bbd", "-keep-directive", "alias",
	 $strassen_orig],
	">", $tmpfile) or die $!;
    run(["$miscsrc/grepstrassen", "-v", "--namerx", ' \(Potsdam\)', 'plaetze'],
	">>", $tmpfile) or die $!;
    run(["$miscsrc/grepstrassen", "-ignoreglobaldirectives", "-catrx", ".", "routing_helper-orig"],
	"|",
	["$miscsrc/replacestrassen", "-catexpr", 's/.*/NN::igndisp/'],
	">>", $tmpfile) or die $!;
    $tmpfile
}

sub create_busroute {
    my $cmo = "$datadir/comments_misc-orig";
    -r $cmo or die "Cannot read $cmo";
    use File::Temp qw(tempfile);
    use IPC::Run qw(run);
    my($tmpfh,$tmpfile) = tempfile(SUFFIX => ".bbd", UNLINK => 1);
    run(["$miscsrc/grepstrassen", "-catrx", '^busroute_N', $cmo],
	">", $tmpfile) or die $!;
    $tmpfile;
}

sub adjust_cat {
    my($cat, $direction) = @_;
    return $cat if !$direction;
    my @order = qw(NN N NH H HH B);
    for my $cat_i (0 .. $#order) {
	if ($cat eq $order[$cat_i]) {
	    if ($direction < 0) {
		if ($cat_i > 0) {
		    return $order[$cat_i-1];
		} else {
		    return $cat;
		}
	    } elsif ($direction > 0) {
		if ($cat_i < $#order) {
		    return $order[$cat_i+1];
		} else {
		    return $cat;
		}
	    }
	}
    }
    warn "Should not happen: did not found category '$cat' in '@order'";
    $cat;
}

__END__

=head1 NAME

winter_optimization.pl - create a penalty net for the winter

=head1 SYNOPSIS

Very snowy, useful for the first days with snow:

   winter_optimization.pl -winter-hardness very_snowy

Somewhat snowy, useful when more streets are already cleared:

   winter_optimization.pl -winter-hardness snowy

Dry cold, but all streets are cleared, no ice expected except
footpaths and cyclepaths:

   winter_optimization.pl -winter-hardness dry_cold

=head1 DESCRIPTION

=head2 CGI

Note that currently the winter hardness has to be set in the config
file F<bbbike.cgi.config> as variable C<$winter_hardness>. Winter
optimization is turned on only if C<$use_winter_optimization> is set
to true. Usually this could be done automatically for the winter
months, see F<../cgi/bbbike2-test.cgi.config> for an example.

=head2 Perl/Tk application

After calling this script there is a penalty file created in the
directory F<.../bbbike/tmp> with name
F<winter_optimization.I<$hardness>.st>, where I<$hardness> is the
winter hardness used in the script call.

Choose then in the Perl/Tk application the menu item Sucheinstellungen
-> Penalty -> Penalty für Net/Storable-Datei and choose the created
file in the file dialog.

To create a bbd file with the calculated penalties, which then may be
displayed in the Perl/Tk version:

   winter_optimization.pl -winter-hardness ... -display > wi.bbd

=head1 BUGS

This comment is not completely true:

    $do_cyclepath_opt   = 0; # Bei Winterwetter können Radwege komplett ignoriert werden

Because of the exceptions:

=over

=item oneway streets with a cyclepath in opposite direction 

Should probably be treated as a NN way.

=item a side street along a main street (e.g. Heerstr., Straße des 17. Juni)

In this case the street has to be treated as a N street, maybe even with an additional kfz_adjustment of -1 or -2

=item cycle lanes

Often cycle lanes have to get a penalty, as snow patches are often still on the cycle lane.
This may be problematic for secondary and higher-grade streets.

=back

=head1 AUTHOR

Slaven Rezic

=cut
