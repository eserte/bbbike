# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

package BBBikePrefsWidget;

use strict;
use base qw(Tk::Derived Tk::Toplevel);

Construct Tk::Widget 'BBBikePrefsWidget';

BEGIN {
    if (!eval '
use Msg qw(frommain);
1;
') {
	#warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

use Tk::Optionmenu;

sub Populate {
    my($w, $args) = @_;

    my $gf = $w->Frame->pack(-fill => "both", -expand => 1);

    my $speed_e;
    {
	my $f = $gf->Frame;

	my $NumEntry = 'Entry';
	my @NumEntryArgs = ();
	if (eval { require Tk::NumEntry }) {
	    $NumEntry = "NumEntry";
	    @NumEntryArgs = (-minvalue => 1, -maxvalue => 50);
	}
	$speed_e = $f->$NumEntry(-width => 3, @NumEntryArgs)->pack(-side => "left");
	$gf->Advertise(Speed => $speed_e);

	$f->Label(-text => 'km/h')->pack(-side => "left"); # XXX Meilen erlauben?

	Tk::grid($gf->Label(-text => M"Bevorzugte Geschwindigkeit"),
		 $f,
		 -sticky => 'w');
    }

    {
	# Die Verwendung von $name2inx ist nur ein Workaround...
	# Eigentlich würde ich die [Name => Wert]-Notation von
	# Optionmenu verwenden wollen, aber das geht nicht :-(
	my $name2inx =
	    {M"Nur Hauptstraßen" => 0,
	     M"Hauptstraßen bevorzugen" => 1,
	     M"Alle Straßen berücksichtigen" => 2,
	     M"Nebenstraßen bevorzugen" => 3,
	     M"Nur Nebenstraßen" => 4,
	    };
	my $default = M"Alle Straßen berücksichtigen";

 	my $o = $gf->Optionmenu
	    (-options => [sort { $name2inx->{$a} <=> $name2inx->{$b} } keys %$name2inx],
	     -variable => \$default,
	    );

	Tk::grid($gf->Label(-text => M"Bevorzugter Straßentyp"),
		 $o,
		 -sticky => 'w');
    }

    {
	my $name2inx =
	    {M"egal" => 0,
	     M"Kopfsteinpflaster und schlechte Fahrbahnen vermeiden" => 1,
	     M"nur sehr gute Beläge bevorzugen (rennradtauglich)" => 2,
	    };
	my $default = M"egal";
	my $o = $gf->Optionmenu
	    (-options => [sort { $name2inx->{$a} <=> $name2inx->{$b} } keys %$name2inx],
	     -variable => \$default,
	    );

	Tk::grid($gf->Label(-text => M"Bevorzugter Straßenbelag"),
		 $o,
		 -sticky => 'w');
    }

    {
	Tk::grid($gf->Label(-text => "Ampeln vermeiden"),
		 $gf->Checkbutton,
		 -sticky => 'w');
    }

    {
	Tk::grid($gf->Label(-text => "Unbeleuchtete Wege vermeiden"),
		 $gf->Checkbutton,
		 -sticky => 'w');
    }

    {
	my $name2inx =
	    {M"egal" => 0,
	     M"bevorzugen" => 1,
	     M"stark bevorzugen" => 2,
	    };
	my $default = M"egal";
	my $o = $gf->Optionmenu
	    (-options => [sort { $name2inx->{$a} <=> $name2inx->{$b} } keys %$name2inx],
	     -variable => \$default,
	    );

	Tk::grid($gf->Label(-text => M"Grüne Wege"),
		 $o,
		 -sticky => 'w');
    }

    {
	my $name2inx =
	    {M"nichts weiter" => 0,
	     M"Anhänger" => 1,
	     M"Kindersitz mit Kind" => 2,
	    };
	my $default = M"nichts weiter";
	my $o = $gf->Optionmenu
	    (-options => [sort { $name2inx->{$a} <=> $name2inx->{$b} } keys %$name2inx],
	     -variable => \$default,
	    );

	Tk::grid($gf->Label(-text => M"Unterwegs mit"),
		 $o,
		 -sticky => 'w');
    }

    {
	Tk::grid($gf->Label(-text => "Fähren benutzen"),
		 $gf->Checkbutton,
		 -sticky => 'w');
    }

    {
	Tk::grid($gf->Label(-text => "Unbekannte Straßen mit einbeziehen"),
		 $gf->Checkbutton,
		 -sticky => 'w');
    }

    my $bf = $w->Frame->pack(-fill => "x");
    $bf->Button(Name => 'cancel',
		-command => sub { $w->destroy },
	       )->pack(-side => 'right');
    $bf->Button(Name => 'apply',
		-command => sub { die "NYI apply" },
	       )->pack(-side => 'right');
    $bf->Button(Name => 'ok',
		-command => sub { die "NYI apply"; $w->destroy },
	       )->pack(-side => 'right');
 
    $w->ConfigSpecs(
		    -title   => ['METHOD'],
		    -speed   => [{-text => $speed_e}],
		    -strtype => ['PASSIVE'], # XXX ? how to set optionmenu?
		    -strqual => ['PASSIVE'], # XXX ? how to set optionmenu?
		    # XXX weitere Optionen?
		   );
}

# XXX Wie präsentiere ich dieses Widget am besten? Vielleicht kann
# auch die Perl/Tk-Version eine Art Wizard haben?

# Könnte ich hiermit einfach verschiedene "Profile" (e.g. Rennrad,
# Normal, Familienausflug...) handhaben?

# XXX Kann ich hier existierenden Code (Menü, bestehender
# Optionseditor) teilen?

# XXX wenn osm_data verwendet wird, dann sollten vielleicht einige
# Features nicht gesetzt werden können? Prüfen!

# XXX Wie auslesen? Evtl. eine Convenience-Funktion schreiben, die die
# Variablen etc. in bbbike-main setzt?

# Bevorzugte Geschwindigkeit: falls ActiveSpeed gesezt ist, dann
# diesen Wert ändern. Ansonsten (ActivePower ist gesetzt): aussuchen,
# welcher der beiden Werte näher dran ist, dann (ggfs.) den Wert
# ändern, und ActiveSpeed setzen. Oder besser:
# change_active_speed_power anpassen?

# Bevorzugter Straßentyp: %strcat_speed setzen, wie in
# enter_opt_preferences. Vorher Refactoring notwendig: das Setzen von
# strcat_speed soll, falls die nicht-freie Eingabe gewählt ist, erst
# kurz vor der Routensuche aktualisiert werden.

# Bevorzugter Straßenbelag: %qualitaet_s_speed setzen, wie in
# enter_opt_preferences. Auch hier gilt der Refactoring-Hinweis.

# Ampeln vermeiden: $ampel_optimierung auf 0..1 setzen

# Unbeleuchtete Wege vermeiden: $unlit_streets_optimization auf 0..1 setzen

# Grüne Wege: $green_optimization auf 0..2 setzen

# Unterwegs mit: 

1;
