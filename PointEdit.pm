# -*- perl -*-

#
# $Id: PointEdit.pm,v 1.3 1999/04/13 13:39:43 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package PointEdit;
# Modul für das Editieren von "MasterPunkte"
use MasterPunkte;
use strict;
use Tk::Arrow;

sub new {
    my($class, %args) = @_;
    my $self = {};
    $self->{P}   = $args{'MasterPunkte'} || die "MasterPunkte fehlt!";
    $self->{Net} = $args{'Net'};
    $self->{Crossings} = $args{'Crossings'};
    $self->{Top} = $args{'Top'} || die "Top fehlt!";
    bless $self, $class;
    $self->{Toplevel} = $self->point_editor();
    $self->{Toplevel}->withdraw;
    $self;
}

# Setzt den Editor auf die angegebene Koordinate "$x,$y"
sub set {
    my($self, $coord) = @_;
    $self->{ArrowFrame}->deactivate if $self->{ArrowFrame};

    my $o = $self->{P}->get_point($coord);
    if (!$o) {
	warn "No point object for coordinate $coord";
	$o = new MasterPunkt $coord;
    }
    $self->{Coord} = $coord;
    $self->{O}     = $o;

    $self->arrow_frame;

    my $global_c = $self->{ArrowGlobal};
    fillin($self, $global_c);
    $global_c->activate;

    $self->{Toplevel}->deiconify;
    $self->{Toplevel}->raise;
}

# Löscht den Editor
sub delete {
    my $self = shift;
    $self->{ArrowFrame}->deactivate if $self->{ArrowFrame};
    $self->{Toplevel}->destroy;
}

# Erzeugt das linke Frame mit den Pfeilen. Wird normalerweise nur von set()
# aufgerufen.
sub arrow_frame {
    my $self = shift;
    my $arrowf = $self->{ArrowFrame};
    foreach ($arrowf->children) {
	$_->destroy;
    }
    my $o = $self->{O};

    my $gridy = 0;
    my $select = 0;
    if (ref $o->{Global} ne 'HASH') {
	$o->{Global} = {};
    } else {
	$select = 1;
    }
    my $global_c = $arrowf->Arrow
      (-command => sub { fillin($self, @_) },
       '-deactivate' => sub { save_values($self, @_) },
       -id => $o->{Global},
       -select => $select,
      )->grid(-row => $gridy, -column => 0);
    $global_c->draw_arrow($o->{Coord});
    $gridy++;

    $self->{ArrowGlobal} = $global_c;

    my(@add_coords);
    if ($self->{Net}) {
	my @x = keys %{$self->{Net}{Net}{$o->{Coord}}};
	for(my $i = 0; $i <= $#x; $i++) {
	    for(my $j = $i+1; $j <= $#x; $j++) {
		push @add_coords, [$x[$i], $x[$j]];
	    }
	}
    } else {
	@add_coords = $o->get_neighbours;
    }

    foreach (@add_coords) {
	my($c1, $c2) = @$_;
	my $gridx = 0;
	foreach my $arrow ('both', 'last', 'first') {
	    my $select = 1;
	    my $oo;
	    if ($arrow eq 'both') {
		if (ref $o->{Line}{$c1}{$c2} ne 'HASH') {
		    $o->{Line}{$c1}{$c2} = {};
		}
		$oo = $o->{Line}{$c1}{$c2};
	    } elsif ($arrow eq 'last') {
		if (ref $o->{Vector}{$c1}{$c2} ne 'HASH') {
		    $o->{Vector}{$c1}{$c2} = {};
		}
		$oo = $o->{Vector}{$c1}{$c2};
	    } else {
		if (ref $o->{Vector}{$c2}{$c1} ne 'HASH') {
		    $o->{Vector}{$c2}{$c1} = {};
		}
		$oo = $o->{Vector}{$c2}{$c1};
	    }
	    if (keys %$oo == 0) {
		$select = 0;
	    }

	    my $c = $arrowf->Arrow
	      (-command => sub { fillin($self, @_) },
	       '-deactivate' => sub { save_values($self, @_) },
	       -id => $oo,
	       -select => $select,
	      )->grid(-row => $gridy, -column => $gridx);
	    $c->draw_arrow($o->{Coord}, $c1, $c2, $arrow);
	    $gridx++;
	}
	$gridy++;
    }
}

# Erzeugt den Editor. Wird normalerweise nur von new() aufgerufen.
sub point_editor {
    my($self) = @_;
    my $top = $self->{Top};
#    my $o = $self->{O};

    my $t = $top->Toplevel(-title => 'Point Editor'); ### XXX use redisplay_top
    $t->transient($top);
    my $arrowf = $t->ArrowContainer->pack(-side => 'left',
					  -anchor => 'nw');
    my $inputf = $t->Frame->pack(-side => 'left',
				 -anchor => 'nw');
    $self->{ArrowFrame} = $arrowf;

    my $pe = {};
    $self->{Entries} = $pe;

    my $gridy = 0;
    $inputf->Label(-text => 'Coord:'
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 0, -columnspan => 2);
    $inputf->Label(-textvariable => \$pe->{'coord'}
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 2, -columnspan => 2);
    $gridy++;

    $inputf->Label(-text => 'Straßen:'
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 0, -columnspan => 2);
    $inputf->Label(-textvariable => \$pe->{'strassen'},
		   -anchor => 'w',
		   -width => 20,
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 2, -columnspan => 2);
    $gridy++;
    
    $inputf->Label(-text => 'Höhe:'
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 0, -columnspan => 2);
    $inputf->Entry(-textvariable => \$pe->{'hoehe'},
		   -width => 5,
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 2);
    $inputf->Label(-text => 'm',
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 3);
    $gridy++;
    
    $inputf->Label(-text => 'Vorfahrt:'
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 0);
    $inputf->Checkbutton(-variable => \$pe->{'vorfahrt'},
			)->grid(-row => $gridy, -sticky => 'w',
				-column => 1);
    $inputf->Entry(-textvariable => \$pe->{'vorfahrt_comment'}
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 2, -columnspan => 2);
    $gridy++;

    $inputf->Label(-text => 'Sperrung:'
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 0);
    $inputf->Checkbutton(-variable => \$pe->{'sperrung'},
			)->grid(-row => $gridy, -sticky => 'w',
				-column => 1);
    $inputf->Entry(-textvariable => \$pe->{'sperrung_comment'}
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 2, -columnspan => 2);
    $gridy++;
    
    $inputf->Label(-text => 'Penalty:'
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 0, -columnspan => 2);
    $inputf->Entry(-textvariable => \$pe->{'penalty'},
		   -width => 5,
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 2, -columnspan => 2);
    $gridy++;
    
    $inputf->Label(-text => 'Tragen:'
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 0);
    $inputf->Checkbutton(-variable => \$pe->{'tragen'},
			)->grid(-row => $gridy, -sticky => 'w',
				-column => 1);
    $inputf->Entry(-textvariable => \$pe->{'tragen_comment'}
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 2, -columnspan => 2);
    $gridy++;

    $inputf->Label(-text => 'Ampel:'
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 0);
    $inputf->Checkbutton(-variable => \$pe->{'ampel'},
			)->grid(-row => $gridy, -sticky => 'w',
				-column => 1);
    $inputf->Entry(-textvariable => \$pe->{'ampel_comment'}
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 2, -columnspan => 2);
    $gridy++;

    $inputf->Label(-text => 'Fuß.-Ampel:'
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 0);
    $inputf->Checkbutton(-variable => \$pe->{'fuss_ampel'},
			)->grid(-row => $gridy, -sticky => 'w',
				-column => 1);
    $inputf->Entry(-textvariable => \$pe->{'fuss_ampel_comment'}
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 2, -columnspan => 2);
    $gridy++;

    $inputf->Label(-text => 'Bahnübergang:'
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 0);
    $inputf->Checkbutton(-variable => \$pe->{'bahnuebergang'},
			)->grid(-row => $gridy, -sticky => 'w',
				-column => 1);
    $inputf->Entry(-textvariable => \$pe->{'bahnuebergang_comment'}
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 2, -columnspan => 2);
    $gridy++;

    $inputf->Label(-text => 'Fragezeichen:'
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 0);
    $inputf->Checkbutton(-variable => \$pe->{'fragezeichen'},
			)->grid(-row => $gridy, -sticky => 'w',
				-column => 1);
    $inputf->Entry(-textvariable => \$pe->{'fragezeichen_comment'},
		  )->grid(-row => $gridy, -sticky => 'w',
			  -column => 2, -columnspan => 2);
    $gridy++;

    my $bf = $inputf->Frame->grid(-row => $gridy, -sticky => 'e',
				  -column => 0, -columnspan => 4);
    $bf->Button(-text => 'OK',
		-command => sub { save_values($self) },
	       )->pack(-side => 'left');
    $bf->Button(-text => 'Cancel',
		-command => sub { $t->withdraw },
	       )->pack(-side => 'left');
    
    $t->protocol('WM_DELETE_WINDOW', sub { save_values($self);
					   $t->withdraw });
    $t;
}

# Füllt das rechte Frame mit den Daten des aktuellen Punktes.
sub fillin {
    my($self, @args) = @_;
    my $o = $self->{O};
    my $pe = $self->{Entries};

    # init
    $pe->{'coord'} = $o->{Coord};
    if ($self->{Crossings}) {
	$pe->{'strassen'} = join("/", @{$self->{Crossings}{$o->{Coord}}});
    } else {
	$pe->{'strassen'} = "";
    }
    foreach (qw(hoehe vorfahrt_comment sperrung_comment penalty
		tragen_comment ampel_comment fuss_ampel_comment
		bahnuebergang_comment fragezeichen_comment)) {
	$pe->{$_} = '';
    }
    foreach (qw(vorfahrt sperrung tragen ampel fuss_ampel
		bahnuebergang fragezeichen)) {
	$pe->{$_} = 0;
    }

    my $h = $args[0]->cget(-id); # get Global/Line/Vector-Hash
    
    while(my($k,$v) = each %$h) {
	if ($k eq MasterPunkt::Hoehe) {
	    $pe->{'hoehe'} = $v;
	} elsif ($k eq MasterPunkt::Vorfahrt) {
	    $pe->{'vorfahrt'} = 1;
	    if ($v ne "1") {
		$pe->{'vorfahrt_comment'} = $v;
	    }
	} elsif ($k eq MasterPunkt::Sperrung) {
	    $pe->{'sperrung'} = 1;
	    if ($v ne "1") {
		$pe->{'sperrung_comment'} = $v;
	    }
	} elsif ($k eq MasterPunkt::Tragen) {
	    $pe->{'tragen'} = 1;
	    if ($v ne "1") {
		$pe->{'tragen_comment'} = $v;
	    }
	} elsif ($k eq MasterPunkt::Penalty) {
	    $pe->{'penalty'} = $v;
	} elsif ($k eq MasterPunkt::Ampel) {
	    $pe->{'ampel'} = 1;
	    if ($v ne "1") {
		$pe->{'ampel_comment'} = $v;
	    }
	} elsif ($k eq MasterPunkt::Fussgaengerampel) {
	    $pe->{'fuss_ampel'} = 1;
	    if ($v ne "1") {
		$pe->{'fuss_ampel_comment'} = $v;
	    }
	} elsif ($k eq MasterPunkt::Bahnuebergang) {
	    $pe->{'bahnuebergang'} = 1;
	    if ($v ne "1") {
		$pe->{'bahnuebergang_comment'} = $v;
	    }
	} elsif ($k eq MasterPunkt::Fragezeichen) {
	    $pe->{'fragezeichen'} = 1;
	    if ($v ne "1") {
		$pe->{'fragezeichen_comment'} = $v;
	    }
	} else {
	    warn "Unbekanntes Attribut $k";
	}
    }
}

sub _set_value {
    my($pe, $pekey, $h, $k) = @_;
    if ($pe->{$pekey} ne "") {
	$h->{$k} = $pe->{$pekey};
    } else { 
	delete $h->{$k};
    }
}

sub _set_value_comment {
    my($pe, $pekey, $h, $k) = @_;
    if ($pe->{$pekey}) {
	if ($pe->{$pekey . '_comment'} eq "") {
	    $h->{$k} = 1;
	} else {
	    $h->{$k} = $pe->{$pekey . '_comment'};
	}
    } else {
	delete $h->{$k};
    }
}

# Sichert die Daten des rechten Frames sofort in die Datenbank.
sub save_values {
    my($self, @args) = @_;
    my $o = $self->{O};
    $args[0] = $self->{ArrowFrame}->{'active'} if !$args[0];
    my $h = $args[0]->cget(-id); # get Global/Line/Vector-Hash
    my $pe = $self->{Entries};

    _set_value($pe, 'hoehe', $h, MasterPunkt::Hoehe);
    _set_value_comment($pe, 'vorfahrt', $h, MasterPunkt::Vorfahrt);
    _set_value_comment($pe, 'sperrung', $h, MasterPunkt::Sperrung);
    _set_value_comment($pe, 'tragen',   $h, MasterPunkt::Tragen);
    _set_value($pe, 'penalty',   $h, MasterPunkt::Penalty);
    _set_value_comment($pe, 'ampel',   $h, MasterPunkt::Ampel);
    _set_value_comment($pe, 'fuss_ampel',   $h, MasterPunkt::Fussgaengerampel);
    _set_value_comment($pe, 'bahnuebergang',   $h, MasterPunkt::Bahnuebergang);
    _set_value_comment($pe, 'fragezeichen',   $h, MasterPunkt::Fragezeichen);
    
    my $s = $o->as_string;
    warn $s;
    if ($s ne "") {
	my $p = $self->{P};
	$p->set_point($o);
    }
}

# XXX
sub draw_canvas {
    my($self, $c) = @_;
    my $mps = $self->{P};
    while(my($coord,$mp) = each %{$mps->{Data}}) {
	# XXX
    }
}

sub clear_canvas {
    my($self, $c) = @_;
    # XXX
}

return 1 if caller();

{
    require Tk;
    package main;
    no strict;
    my $p = new MasterPunkte "/tmp/test";
    $p->read;
    $top = MainWindow->new;
    $top->withdraw;
    my $pe = new PointEdit MasterPunkte => $p, Top => $top;
    #my $t = $pe->point_editor($top);
    $pe->set("1,1");
    $pe->{Toplevel}->OnDestroy(sub { exit() }) unless $Tk::VERSION < 800;
    Tk::MainLoop();
}


__END__
