# -*- perl -*-

#
# $Id: MasterStrassen.pm,v 1.3 2005/04/05 22:32:33 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# neues Strassen-Format
# Straßenname TAB Kommentar SPC Punkt1 SPC
# Attribute<->;Attribute->;Attribute<- SPC Punkt2 SPC ...
# Points: 0, 2, ... (alle geraden): Koordinaten
#         1, 3, ... (alle ungeraden): Attribute

use strict;

{
    package MasterStrasse;

    use constant Radweg               => 'r';
    use constant RadwegPflicht        => 'R';
    use constant Radspur              => 's';
    use constant Busspur              => 'b';
    use constant Verkehrsberuhigt     => 'v';
    use constant Gehweg               => 'g';

    use constant Gesperrt             => 'x';
    use constant GesperrtKfz          => 'X';

    use constant Unbekannt            => '?';

    use constant Qualitaet0           => '0';
    use constant Qualitaet1           => '1';
    use constant Qualitaet2           => '2';
    use constant Qualitaet3           => '3';

    use constant KaumVerkehr          => '6';
    use constant Ruhig                => '7';
    use constant MittlererVerkehr     => '8';
    use constant StarkerVerkehr       => '9';

    use constant Kopfsteinpflaster    => 'k';
    use constant WaldFeldweg          => 'f';
    use constant Asphalt              => 'a';

    use constant RadwegQualitaet0     => 'W';
    use constant RadwegQualitaet1     => 'X';
    use constant RadwegQualitaet2     => 'Y';
    use constant RadwegQualitaet3     => 'Z';

    use constant KeinMIVStrasse       => 'n';
    use constant Nebenstrasse         => 'N';
    use constant Hauptstrasse         => 'h';
    use constant WichtigeHauptstrasse => 'H';
    use constant Bundesstrasse        => 'B';

    my $can_fields;
    eval q{
	use fields qw(Name Comment Points);
	# XXX warum muß hier der volle Name stehen?
	$MasterStrasse::can_fields = 1;
    };

    no strict 'refs';

    sub new {
	my($class, $line) = @_;
	my $self = ($can_fields ? [\%{"$class\::FIELDS"}] : {});
	push @$self, parse($line);
	bless $self, $class;
    }

    sub parse {
	my $line = shift;
	if (defined $line and $line ne '') {
	    my($name, $comment);
	    ($name, $comment, $line) = split(/\t/, $line, 3);
	    my @s = split(/\s+/, $line);
	    ($name, $comment, \@s);
	} else {
	    ();
	}
    }

    sub category {
	my($self, $inx) = @_;
	$inx = 1 if !defined $inx;
	my $cat = substr($self->{Points}[$inx], 0 , 1);
	my %catconv = (&KeinMIVStrasse => 'NN',
		       &Nebenstrasse => 'N',
		       &Hauptstrasse => 'H',
		       &WichtigeHauptstrasse => 'HH',
		       &Bundesstrasse => 'B',
		      );
	$catconv{$cat};
    }

    sub coords_list {
	my $self = shift;
	my @coords;
	for(my $i = 0; $i <= $#{$self->{Points}}; $i+=2) {
	    push @coords, $self->{Points}[$i];
	}
	@coords;
    }

    sub multi_coords_list {
	my $self = shift;
	my @multi_coords;
	my $old_cat = "";
	my @coords;
	for(my $i = 2; $i <= $#{$self->{Points}}; $i+=2) {
	    my $cat = $self->category($i-1);
	    if ($old_cat ne $cat) { 
		if (@coords) {
		    push @multi_coords, [$old_cat, @coords];
		    @coords = ();
		}
		push @coords, $self->{Points}[$i-2];
		$old_cat = $cat;
	    }
	    push @coords, $self->{Points}[$i];
	}
	push @multi_coords, [$old_cat, @coords];
	@multi_coords;
    }

=head2 selfcheck

Überprüft den Konstantenteil auf Konflikte. Aufruf:

   perl5.00502 -MMasterStrassen -e 'MasterStrasse::selfcheck()'

=cut

    sub selfcheck {
	open(M, "MasterStrassen.pm") or die;
	my $found_pkg;
	my %used;
	while(<M>) {
	    if ($found_pkg && /use\s+constant\s+(\S+).*'(.)'/) {
		if (exists $used{$2}) {
		    warn "$2 wird bereits von $1 verwendet!";
		} else {
		    $used{$2} = $1;
		}
	    } elsif ($found_pkg && /package\s+/) {
		last;
	    } elsif (/package\s+MasterStrasse/) {
		$found_pkg = 1;
	    }
	}
	close M;
	warn "Done.\n";
    }
}

package MasterStrassen;

#use BBBikeUtil;
#use AutoLoader 'AUTOLOAD';
use DB_File;
use vars qw(@datadirs $VERBOSE); # XXX $OLD_AGREP 

if (!defined $FindBin::RealBin) {
    require FindBin;
    import FindBin;
}

@datadirs = ("$FindBin::RealBin/data", './data');
foreach (@INC) {
    push @datadirs, "$_/data";
}

sub new {
    my($class, $filename, %arg) = @_;
    my @filenames;
    if (defined $filename) {
	push @filenames, $filename, map { "$_/$filename" } @datadirs;
    }
    my $self = {};
    bless $self, $class;

    if (@filenames) {
      TRY: {
	    foreach my $file (@filenames) {
		if (-f $file and -r _) {
		    my @a;
		    my $db =
		      tie @a, 'DB_File', $file, O_RDONLY, 0644, $DB_RECNO;
		    if ($db) {
			$self->{DB} = $db;
			last TRY;
		    }
		}
	    }
	    die "Can't open ", join(", ", @filenames);
	}
    }

    $self->{Pos} = -1;

    $self;
}

# initialisiert für next() und gibt *keinen* Wert zurück
sub init {
    my $self = shift;
    $self->{Pos} = -1;
}

sub nextlines {
    my $self = shift;
    while (++($self->{Pos}) < $self->{DB}->length) {
	my $line;
	$self->{DB}->get($self->{Pos}, $line);
	if ($line !~ /^\s*($|\#)/) {
	    my $o = new MasterStrasse $line;
	    my(@multi_coords) = $o->multi_coords_list;
	    my @ret;
	    foreach (@multi_coords) {
		push @ret, $o->{Name} . "\t" . join(" ", @$_);
	    }
	    return @ret;
	}
    }
    ();
}


return 1 if caller();

package main;
my $s = new MasterStrassen "/tmp/masterstrassen-orig";
$s->init;
while(1) {
    my(@l) = $s->nextlines;
    last if !@l;
    print join("\n", @l), "\n";
}
    
__END__
package main;
require Data::Dumper;
require Benchmark;
require Strassen;
Benchmark::timethese
  (1,
   {'str' => sub {
	my $s = new Strassen "strassen";
	$s->init;
	while(1) {
	    my $o = $s->next;
	    last if (!@{$o->[1]});
	    #    print Data::Dumper->Dumpxs([$o], ['o']) , "\n";
	}
    },
    'strobj' => sub {
	my $s = new Strassen "strassen";
	$s->init;
	while(1) {
	    my $o = $s->next_obj;
	    last if $o->is_empty;
	    #    print Data::Dumper->Dumpxs([$o], ['o']) , "\n";
	}
    },
    'master' => sub {
	my $s = new MasterStrassen "misc/masterstrassen";
	$s->init;
	while(1) {
	    my $o = $s->next;
	    last if (!$o);
	    #    print Data::Dumper->Dumpxs([$o], ['o']) , "\n";
	}
    }
   });

__END__
