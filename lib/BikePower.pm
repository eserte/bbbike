#!/usr/local/bin/perl
# -*- perl -*-

#
# $Id: BikePower.pm,v 2.5.1.15 2001/10/13 14:28:41 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright: see at bottom of file
#
# Mail: slaven@rezic.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use strict;

package BikePower;

use vars qw($m_s__per__mi_h $m_s__per__km_h $Nt__per__lb $kg__per__Nt
	    $Watts__per__Cal_hr $Watts__per__horsepower
	    $NOSAVE
	    @out %fmt @air_density %members
	    %air_resistance @air_resistance_order
	    @rolling_friction
	    @ISA $VERSION $has_xs
 	   );

require DynaLoader;
@ISA     = qw(DynaLoader);
$VERSION = '0.34';

eval {
    bootstrap BikePower $VERSION;
    $has_xs = 1 unless $@;
};

if ($has_xs) {
    *calc = \&calcXS;
} else {
    *calc = \&calc_slow;
}

# Conversion factors
$m_s__per__mi_h         = 0.44704; # meters/second per miles/hour
$m_s__per__km_h         = (1000.0 / 3600.0); # m/s per km/h
$Nt__per__lb            = 4.4482;
$kg__per__Nt            = 0.102;
$Watts__per__Cal_hr     = 1.163; # Watts per dietary Calories/hour
# 1 dietary Calorie == 1000 calories
$Watts__per__horsepower = 745.700;

$NOSAVE = 1 << 0;

# Air Density table for dry air between -30 to +44 degrees C
#
# Taken from the Handbook of Chemistry and Physics, Thirtieth
# Edition
#
# This table does not include the changes for air pressure or
# humity.
@air_density =
  (1.5147, 1.5083, 1.5019, 1.4955, 1.4892, # -30°C 3.6°F
   1.4829, 1.4767, 1.4706, 1.4645, 1.4584, # -25 
   1.3951, 1.3896, 1.3841, 1.3787, 1.3734, # -20 
   1.3680, 1.3628, 1.3575, 1.3523, 1.3472, # -15 
   1.3420, 1.3370, 1.3319, 1.3269, 1.3219, # -10 
   1.3170, 1.3121, 1.3072, 1.3024, 1.2977, # - 5 
   1.2929, 1.2882, 1.2835, 1.2789, 1.2742, #   0 
   1.2697, 1.2651, 1.2606, 1.2561, 1.2517, #   5 
   1.2472, 1.2428, 1.2385, 1.2342, 1.2299, #  10 
   1.2256, 1.2214, 1.2171, 1.2130, 1.2088, #  15 
   1.2047, 1.2006, 1.1965, 1.1925, 1.1885, #  20 
   1.1845, 1.1805, 1.1766, 1.1727, 1.1688, #  25 
   1.1649, 1.1611, 1.1573, 1.1535, 1.1498, #  30 
   1.1460, 1.1423, 1.1387, 1.1350, 1.1314, #  35 
   1.1277, 1.1242, 1.1206, 1.1170, 1.1135  #  40°C 138.6°F 
  );

# members
# maybe accessed by hash or by method
%members =
  ('imperial'    => [[], 0, 'metric/imperial flag', undef],
   'T_a'         => [['temperature'], 20, 'temperature [°C]', undef],
   'given'       => [[], 'v', 'resolve for v/P/C', undef],
   'first_C'     => [[], 500, 'consumption [cal/h]', undef],
   'first_V'     => [[], 30,  'velocity [km/h]', undef],
   'first_P'     => [[], 200, 'power output [Watts]', undef],
   'V_incr'      => [[], 2,   'velocity increment in table', undef],
   'P_incr'      => [[], 25,  'power increment in table', undef],
   'C_incr'      => [[], 100.0, 
		     'consumed_power increment in table', undef],
   'N_entry'     => [[], 10,  'number of entries in table', undef],
   'C_a'         => [[], 0.90, 'air resistance coefficient', undef],
   'A1'          => [[], 0,   'linear coefficient of air resistance', undef],
   'A2'          => [[], undef,
		     'quadratic coefficient of air resistance', $NOSAVE],
   'A_c'         => [[], 0.3080527, 'frontal area of the cyclist in meters^2',
		     undef],
   'T'           => [['transmission_efficiency'], 0.95,
		     'transmission efficiency of bicycle drivetrain', undef],
   'E'           => [['human_efficiency'], 0.249,
		     'efficiency of human in cycling', undef],
   'H'           => [['headwind'], 0.0,
		     'velocity of headwind [meters/second]', undef],
   'R'           => [['rolling_friction'], 0.0047,
		     'coefficient of rolling friction', undef],
   'G'           => [['grade'], 0, 'grade of hill', undef],
   'Wc'          => [['weight_cyclist'], 77, 'weight of cyclist [kg]', undef],
   'Wm'          => [['weight_machine'], 10,
		     'weight of machine and clothing [kg]', undef],
   'BM_rate'     => [[], 1.4, 
		     'basal metabolism rate [Watts/kg of body weight]', undef],
   'cross_wind'  => [[], 0, 'the wind given is a cross wind', undef],

   'P'           => [['power'], undef, 'power in Watts', $NOSAVE],
   'V'           => [['velocity'], undef, 'velocity in m/s', $NOSAVE],
   'C'           => [['consumption'], undef, 'consumption in Cal/hr', $NOSAVE],
  );

%air_resistance =
  (
   'standing',   => {'A_c'     => 0.6566873,
		     'text_en' => 'standing',
		     'text_de' => 'stehend',
		    },
   'upright'     => {'A_c'     => 0.4925155,
		     'text_en' => 'upright',
		     'text_de' => 'aufrecht',
		    },
   'crouch'      => {'A_c'     => 0.4297982,
		     'text_en' => 'crouch',
		     'text_de' => 'geduckt',
		    },
   'racing'      => {'A_c'     => 0.3080527,
		     'text_en' => 'racing crouch',
		     'text_de' => 'geduckt in Rennhaltung',
		    },
   'tuck'        => {'A_c'     => 0.2674709,
		     'text_en' => 'full downhill tuck',
		     'text_de' => 'Abfahrtshaltung',
		    },
   'pack_end'    => {'A_c'     => 0.2213353,
		     'text_en' => 'end of pack of 1 or more riders',
		     'text_de' => 'am Ende eines Verbandes',
		    },
   'pack_middle' => {'A_c'     => 0.1844627,
		     'text_en' => 'in the middle of a pack',
		     'text_de' => 'in der Mitte eines Verbandes',
		    },
  );
@air_resistance_order = sort { $air_resistance{$b}->{A_c} <=>
				 $air_resistance{$a}->{A_c}
			   } keys %air_resistance;

@rolling_friction =
  ({'R' => 0.004,
    'text_en' => 'narrow tubular tires, lowest',
    'text_de' => 'schmale röhrenförmige Reifen, niedrigster Wert',
   },
   {'R' => 0.0047,
    'text_en' => '26 x 1.125 inch tires',
    'text_de' => '26 x 1.125"-Reifen',
   },
   {'R' => 0.0051,
    'text_en' => '27 x 1.25 inch tires',
    'text_de' => '27 x 1.25"-Reifen',
   },
   {'R' => 0.0055,
    'text_en' => 'narrow tubular tires, highest',
    'text_de' => 'schmale röhrenförmige Reifen, höchster Wert',
   },
   {'R' => 0.0066,
    'text_en' => '26 x 1.375 inch tires',
    'text_de' => '26 x 1.375"-Reifen',
   },
   {'R' => 0.0120,
    'text_en' => 'mountain bike tires',
    'text_de' => 'Mountainbike-Reifen',
   },
  );

my $member;
my $i=0;
foreach $member (keys %members) {
    foreach ($member, @{$members{$member}->[0]}) {
	my $sub = q#sub # . $_ . q# {
    my($self, $val) = @_;
    if (defined $val) {
	$self->{'# . $member . q#'} = $val;
    } else {
	$self->{'# . $member . q#'};
    }
}#;
        eval $sub;
    }
}

# output variables
@out = qw(V F Pa Pr Pg Pt P hp heat B C kJh);
# format for printf
%fmt = qw(V	%5.1f
	  F	%4.1f
	  Pa	%4.0f
	  Pr	%4.0f
	  Pg	%5.0f
	  Pt	%4.0f
	  P	%5.0f
	  hp	%5.2f
	  heat	%5.0f
	  B	%3.0f
	  C	%5.0f
	  kJh	%5.0f);

## XXX vielleicht sollten die Werte im Hash die echten SI-Werte
## sein. FETCH und STORE machen dann anhand von metric die
## Umwandlung. Funktioniert es mit -variable und Tk?
sub TIEHASH {
    my($class, %a) = @_;
    $class = (ref $class ? ref $class : $class);

    my $s = {};
    bless $s, $class;

    if ($a{'-no-ini'} || !$s->load_defaults) {
	if (!$a{'-no-default'}) {
	    $s->default;
	}
    }
    $s->set_values(%a);
    if (!$s->given && !$a{'-no-default'}) { $s->given('v') }

    $s;
}

sub new { shift->TIEHASH(@_) }

#sub DESTROY { }

sub _nosave {
    my($k) = @_;
    return 1 if !exists $members{$k};
    my $v = $members{$k};
    return 0 if !defined $v->[3];
    return $v->[3] & $NOSAVE;
}

sub clone {
    my($class, $old);
    if (ref $_[0] and $_[0]->isa('BikePower')) {
	# Syntax: $clone = $object->clone(%args);
	$old = shift;
	$class = ref $old;
    } else {
	# Syntax: $clone = clone BikePower $object, %args;
	$class = shift;
	$old = shift;
    }
    my(%args) = @_;
    $args{'-no-ini'} = $args{'-no-default'} = 1;
    my $new = $class->new(%args);
    my($k, $v);
    while(($k, $v) = each %members) {
	next if _nosave($k) || !defined $old->{$k} || $old->{$k} eq '';
	$new->{$k} = $old->{$k};
    }
    $new;
}

sub default {
    my($self) = @_;
    my($k, $v);
    while(($k, $v) = each %members) {
	next if _nosave($k);
	$self->{$k} = $v->[1];
    }
    $self;
}

sub set_values {
    my($self, %a) = @_;
    my($k, $v);
    while(($k, $v) = each %a) {
	if ($k !~ /^[_\-]/ && defined $v && $v ne '') {
	    $self->{$k} = $v;
	}
    }
}

sub _default_filename {
    my $home;
    if ($^O eq 'MSWin32') {
        eval {
            require Win32Util; # XXX private module
            $home = Win32Util::get_user_folder();
            if (defined $home) {
                $home .= "/bikepwr.rc";
            }
        };
    }
    if (!defined $home) {
        $home = eval { local $SIG{__DIE__};
		       (getpwuid($<))[7];
		   } || $ENV{'HOME'} || '';
        $home .= ($^O eq 'MSWin32' ? "/bikepwr.rc" : "/.bikepowerrc");
    }
    $home;
}

sub load_defaults {
    my($self, $file) = @_;
    $file = _default_filename unless $file;
    if (! -r $file) {
	return undef;
    }
    eval 'package BikePower::ConfigFile; do "$file"';
    if ($@) {
	warn $@;
	return undef;
    }
    return undef if (!defined $BikePower::ConfigFile::x ||
		     !ref $BikePower::ConfigFile::x);
    my($k, $v);
    while(($k, $v) = each %$BikePower::ConfigFile::x) {
	$self->{$k} = $v;
    }
    1;
}

sub save_defaults {
    my($self, $file) = @_;
    $file = _default_filename unless $file;
    my $x;
    my($k, $v);
    while(($k, $v) = each %$self) {
	if ($k !~ /^[_\-]/ && !_nosave($k) && $v ne '' ) {
	    $x->{$k} = $v;
	}
    }
    if (!open(FILE, ">$file")) {
	warn "Can't open file: $!";
	return undef;
    }
    eval { require Data::Dumper };
    if (!$@) {
	print FILE Data::Dumper->Dump([$x], ['x']), "\n";
    } else {
	print FILE "\$x = {\n";
	while(($k, $v) = each %$x) {
	    print FILE $k, "=> '", $v, "',\n";
	}
	print FILE "}\n";
    }
    close FILE;
    1;
}

sub FETCH {
    my($self, $key) = @_;
    $self->{$key};
}

sub STORE {
    my($self, $key, $value) = @_;
    $self->{$key} = $value;
}

sub _numify {
    my($s) = @_;
    if ($s =~ /^\s*(\S+)/) {
	$1;
    } else {
	$s;
    }
}

sub weight_cyclist_N { $_[0]->weight_cyclist / $kg__per__Nt }
sub weight_machine_N { $_[0]->weight_machine / $kg__per__Nt }
sub total_weight     { $_[0]->weight_cyclist + $_[0]->weight_machine }
sub total_weight_N   { $_[0]->weight_cyclist_N + $_[0]->weight_machine_N }
sub velocity_kmh     { $_[0]->velocity / $m_s__per__km_h }
sub V_incr_ms        { $_[0]->V_incr * $m_s__per__km_h }
sub air_density      { $air_density[int($_[0]->temperature + 30)] }
sub calc_A2          {
    my $self = shift;
    if (defined $self->A2) {
	$self->A2;
    } else {
	($self->C_a * $self->air_density / 2) * _numify($self->A_c);
    }
}
sub BM               { $_[0]->BM_rate  * $_[0]->weight_cyclist }
sub C_incr_W_cal_hr  { $_[0]->C_incr * $Watts__per__Cal_hr }

sub sqr { $_[0] * $_[0] }

sub calc_slow {
    my $self = shift;
    # effective Headwind
    my $eff_H = $self->headwind * ($self->cross_wind ? .7 : 1);
    my $A_c   = _numify($self->A_c);
    my $R     = _numify($self->rolling_friction);
    my $A2    = $self->calc_A2;
    my($F_a);

    if ($self->given eq 'P' || $self->given eq 'C') {
	# Given P, solve for V by bisection search
	# True Velocity lies in the interval [V_lo, V_hi].
	my $P_try;
	my $V_lo = 0;
	my $V    = 64;
	my $V_hi = 128;
	while ($V - $V_lo > 0.001) {
	    $F_a = $A2 * sqr($V + $eff_H) + $self->A1 * ($V + $eff_H);
	    if ($V + $eff_H < 0) {
		$F_a *= -1;
	    }
	    $P_try = ($V / $self->transmission_efficiency) 
	      * ($F_a + ($R + $self->grade) * $self->total_weight_N);
	    if ($P_try < $self->power) {
		$V_lo = $V;
	    } else {
		$V_hi = $V;
	    }
	    $V = 0.5 * ($V_lo + $V_hi);
	}
	$self->velocity($V);
    }
    
    # Calculate the force (+/-) of the air
    $F_a = $A2 * sqr($self->velocity + $eff_H) 
      + $self->A1 * ($self->velocity + $eff_H);
    if ($self->velocity + $eff_H < 0) {
	$F_a *= -1;
    }

    # Calculate the force or rolling restance
    my $F_r  =  $R * $self->total_weight_N;

    # Calculate the force (+/-) of the grade
    my $F_g  =  $self->grade * $self->total_weight_N;

    # Calculate the total force
    my $F  =  $F_a + $F_r + $F_g;

    # Calculate Power in Watts
    $self->power($self->velocity * $F / $self->transmission_efficiency);

    my $P_t;
    # Calculate Calories and drivetrain loss
    if ($self->power > 0) {
	$self->consumption($self->power / $self->human_efficiency + $self->BM);
	$P_t  =  (1.0 - $self->transmission_efficiency) * $self->power;
    } else {
	$self->consumption($self->BM);
	$P_t  =  0.0;
    }

    $self->{_out}{'Pa'}   = $self->velocity * $F_a;
    $self->{_out}{'Pr'}   = $self->velocity * $F_r;
    $self->{_out}{'Pg'}   = $self->velocity * $F_g;
    $self->{_out}{'Pt'}   = $P_t;
    $self->{_out}{'P'}    = $self->power;
    $self->{_out}{'hp'}   = $self->power / $Watts__per__horsepower;
    $self->{_out}{'heat'} = $self->consumption - ($self->BM + $self->power);
    $self->{_out}{'C'}    = $self->consumption;
    $self->{_out}{'B'}    = $self->BM;
    if (!$self->imperial) {
	$self->{_out}{'V'}    = $self->velocity_kmh;
	$self->{_out}{'F'}    = $kg__per__Nt * $F;
#	$self->{_out}{'kJh'}  = (3600.0 / 1000.0) * $self->consumption;
	$self->{_out}{'kJh'}  = $self->consumption / $Watts__per__Cal_hr; # really Cal/hr
    } else {
	$self->{_out}{'V'}    = $self->velocity / $m_s__per__mi_h;
	$self->{_out}{'F'}    = $F / $Nt__per__lb;
	$self->{_out}{'kJh'}  = $self->consumption / $Watts__per__Cal_hr; # really Cal/hr
    }
}

sub display_parameters {
    my($self) = @_;
    if (!$self->imperial) {
	printf
	  "grade of hill = %5.1f%%                    headwind = %4.1f km/h\n",
	  100.0 * $self->grade, $self->headwind / $m_s__per__km_h;
	printf
	  "weight:  cyclist %5.1f + machine %4.1f  =  total %5.1f kg\n",
	  $self->weight_cyclist, $self->weight_machine, $self->total_weight;
    } else {
	printf
	  "grade of hill = %5.1f%%                    headwind = %4.1f mi/h\n",
	  100.0 * $self->grade, $self->headwind / $m_s__per__mi_h;
	printf
	  "weight:  cyclist %5.1f + machine %4.1f  =  total %5.1f lb\n"; # XXX
    }
    printf
      "rolling friction coeff = %6.4f           BM rate = %5.2f W/kg\n",
      _numify($self->rolling_friction), $self->BM_rate;
    printf
      "air resistance coeff =  (%6.4f, %g)\n",
      $self->calc_A2, $self->A1;
    printf
      "efficiency:  transmission = %5.1f%%        human = %4.1f%%\n",
      100.0 * $self->transmission_efficiency,
      100.0 * $self->human_efficiency;
    print "\n";
}

sub _init_output {
    my($self) = @_;
    if ($self->given eq 'C') {
	$self->power($self->human_efficiency * 
		     ($self->first_C * $Watts__per__Cal_hr - $self->BM));
	$self->P_incr($self->human_efficiency * $self->C_incr_W_cal_hr);
    } elsif ($self->given eq 'P') {
	$self->power($self->first_P);
    } else {
	$self->velocity($self->first_V * $m_s__per__km_h); # m/s
    }
}

sub _incr_output {
    my($self) = @_;
    if ($self->given eq 'P' || $self->given eq 'C') {
	$self->power($self->power + $self->P_incr);
    } else {
	$self->velocity($self->velocity + $self->V_incr_ms);
    }
}

sub output {
    my($self) = @_;

    if (!$self->imperial) {
	print
	  "  kph  F_kg   P_a  P_r   P_g  P_t    P    hp   heat   " .
#	    "BM     C    kJ/hr \n";
	    "BM     C    Cal/hr\n";
    } else {
	print
	  "  mph  F_lb   P_a  P_r   P_g  P_t    P    hp   heat   " .
	    "BM     C    Cal/hr\n";
    }
    $self->_init_output;
    my $entry;
    for ($entry = 0; $entry < $self->N_entry; $entry++) {
	$self->calc();
	printf
	  "$fmt{'V'}  $fmt{'F'}  $fmt{'Pa'} $fmt{'Pr'} $fmt{'Pg'} $fmt{'Pt'} ".
	    "$fmt{'P'} $fmt{'hp'} $fmt{'heat'}  $fmt{'B'}  $fmt{'C'}   ".
	      "$fmt{'kJh'}\n",
	      map { $self->{'_out'}{$_} } @out;
	$self->_incr_output;
    }
}

sub tk_interface {
    require BikePower::Tk;
    BikePower::Tk::tk_interface(@_);
}

1;

__END__

=head1 NAME

BikePower - bicycle power-output calculator with command-line and Tk interface

=head1 SYNOPSIS

    use Tk;
    use BikePower;
    $top = new MainWindow;
    BikePower::tk_interface($top);

or

    use BikePower;
    BikePower::output();

=head1 DESCRIPTION

B<BikePower> calculates power output and power consumption for
bicycling. You give it things like riding speed, body weight, hill
grade, and wind speed. The module returns power output and power
consumption, broken out in various ways.

This module is meant for inclusion in own programs. There are two perl
scripts in the distribution, B<bikepwr> and B<tkbikepwr>, for use as
stand-alone programs.

=head1 CONSTRUCTOR

A new BikePower object is constructed with

    $bpwr = new BikePower [options];

Here is a list of possible options, which are supplied in a
key-value-notion (e.g.

    $bpwr = new BikePower '-no-ini' => 1, 'V_first' => 20;

).

=over 4

=item -no-ini

If set to true, do not use the defaults from ~/.bikepower.pl.

=item -no-default

If set to true, do not use any defaults (all parameters are left
undefined).

=item imperial

Metric/imperial flag. If set, use imperial rather than metric units.

=item T_a

Temperature in °C.

=item given

Resolve for v (velocity), P (power) or C (consumption).

=item first_C

First consumption (Cal/hr) in table or other output.

=item first_V

First velocity (km/h) in table or other output.

=item first_P

First power output (Watts) in table or other output.

=item V_incr

Velocity increment in table.

=item P_incr

Power increment in table.

=item C_incr

Consumed_power increment in table.

=item N_entry

Number of entries in table, default: 10.

=item C_a

Air resistance coefficient.

=item A1

Linear coefficient of air resistance.

=item A2

Quadratic coefficient of air resistance.

=item A_c

Frontal area of the cyclist in meters^2.

=item T

Transmission efficiency of bicycle drivetrain.

=item E

Efficiency of human in cycling.

=item H

Velocity of headwind [meters/second].

=item R

Coefficient of rolling friction.

=item G

Grade of hill.

=item Wc

Weight of cyclist [kg].

=item Wm

Weight of machine and clothing [kg].

=item BM_rate

Basal metabolism rate [Watts/kg of body weight].

=item cross_wind

The wind given is a cross wind.

=back

=head1 METHODS

=over 4

=item calc

Resolve for velocity, power output or consumption (as stated in the
"given" parameter) for the first_V, first_P or first_C parameter. The
calculated values may be get with $bpwr->velocity, $bwpr->power or
$bpwr->consumption.

=item output

Calculate and print a table with the supplied values.

=back

=head1 INI FILE

The easiest way to create the ini file is to use B<tkbikepwr> and
clicking on the menu item "Save as default". The ini file is evaled as
a perl script and should contain the variable C<$x> as a reference to
a hash. For example:

    $x = {
           'V_incr' => 2,
           'C_a' => '0.9',
           'A_c' => '0.4925155 (upright)',
           'Wm' => 19,
           'E' => '0.249',
           'G' => '0',
           'H' => '0',
           'first_C' => 500,
           'C_incr' => 100,
           'A1' => '0',
           'R' => '0.0066 (26 x 1.375)',
           'T_a' => 20,
           'T' => '0.95',
           'first_P' => 50,
           'given' => 'v',
           'Wc' => 68,
           'BM_rate' => '1.4',
           'P_incr' => 50,
           'cross_wind' => '0',
           'first_V' => 16,
           'N_entry' => 10
         };

=head1 TODO

    + better POD!

=head1 SEE ALSO

L<BikePower::Tk(3)|BikePower::Tk>, L<bikepwr(1)|bikepwr>,
L<tkbikepwr(1)|tkbikepwr>

=head1 AUTHOR

Slaven Rezic (slaven@rezic.de)

Original program bike_power.c by Ken Roberts
(roberts@cs.columbia.edu), Dept of Computer Science, Columbia
University, New York and co-author Mark Grennan (markg@okcforum.org).

Copyright (c) 1997,1998,1999,2000 Slaven Rezic. All rights reserved.
This package is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

