# -*- perl -*-

#
# $Id: Wizards.pm,v 1.4 2002/11/14 15:28:55 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use strict;
# globale Variablen aus bbbike
use vars qw($top $bp_obj %font $want_wind $proxy $do_www);
# Modul-globale Variablen in Wizards
use vars qw($img_f $text_f $but_f $wiz_balloon);
use vars qw($back_b $gap_l1 $forw_b $gap_l2 $end_b);
use vars qw($proxy_host $proxy_port);
use vars qw($gewicht $gewicht_rad $a_c);

use vars qw($devel_host);
if (0 && !defined $devel_host) { # debugging
    warn "Debugging...";
    $font{'verylarge'}
    = "-*-helvetica-medium-r-normal--*-240-75-75-*-iso8859-1";
    $proxy = 'http://127.0.0.1:80/';
    $do_www = 1;
    $want_wind = 0;
    require BikePower;
    $bp_obj = new BikePower;
}

sub config_wizard {
    my $t = $top->Toplevel(-title => 'Konfigurations-Wizard');
# XXX warum geht Balloon nicht?????????
    require Tk::Balloon;
    local $wiz_balloon = $t->Balloon;
    my $weiter = 0;
    $t->geometry("640x480");
    $t->grab;
    $t->gridRowconfigure(0, -weight => 1);
    for (0 .. 1) {
	$t->gridColumnconfigure($_, -weight => 1, -minsize => 300);
    }
    local $img_f = $t->Frame->grid(-row => 0, -column => 0,
				   -sticky => 'nesw');
    local $text_f = $t->Frame->grid(-row => 0, -column => 1,
				    -sticky => 'nesw');

# XXX URI::URL verwenden, wenn vorhanden
    if ($proxy =~ m|//([^:]+):(\d+)|) {
	($proxy_host, $proxy_port) = ($1, $2);
    }
    if (!$proxy_port) { $proxy_port = 80 }

    if ($bp_obj) {
	$gewicht     = $bp_obj->weight_cyclist;
	$gewicht_rad = $bp_obj->weight_machine;
	$a_c         = $bp_obj->A_c;
    }

    my $ende_sub = sub {
	$weiter = 1;
    };
    my @wizard_chain = (\&config_wizard_start,
			\&config_wizard_wind,
			\&config_wizard_bikepower,
			\&config_wizard_end);
    my $wizard_index = 0;

    local $but_f = $t->Frame->grid(-row => 1, -column => 0, -columnspan => 2,
				   -sticky => 'e');
    local $back_b = $but_f->Button(-text => '<< Zurück',
				   -command => sub {
				       $wizard_index--;
				       $weiter = 1;
				   },
				  )->pack(-side => 'left');
    local $gap_l1 = $but_f->Label->pack(-side => 'left');
    local $forw_b = $but_f->Button->pack(-side => 'left');
    my $fg_color = $forw_b->cget(-foreground);
    local $gap_l2 = $but_f->Label->pack(-side => 'left');
    local $end_b = $but_f->Button->pack(-side => 'left');

    my $do_save = 1;
    while($wizard_index <= $#wizard_chain) {
	# auch verhindern, dass man zur Startseite zurückkommt
	$back_b->configure(-state =>
			   ($wizard_index <= 1 ? 'disabled' : 'normal'));
	if ($wizard_index == $#wizard_chain) {
	    $gap_l1->configure(-text => '  ');
	    $gap_l2->configure(-text => '');
	    $forw_b->configure(-text => 'Nein',
			       -foreground => 'red',
			       -command => sub {
				   $wizard_index++;
				   $do_save = 0;
				   $weiter = 1;
			       });
	    $end_b->configure(-text => 'Ja',
			      -foreground => 'green4',
			      -command => sub {
				  $wizard_index++;
				  $weiter = 1;
			      },
			     )
	} else {
	    $gap_l2->configure(-text => '  ');
	    $gap_l1->configure(-text => '');
	    $forw_b->configure(-text => 'Weiter >>',
			       -foreground => $fg_color,
			       -command => sub {
				   $wizard_index++;
				   $weiter = 1;
			       });
	    $end_b->configure(-text => 'Beenden',
			      -foreground => 'red',
			      -command => sub {
				  $wizard_index = $#wizard_chain;
				  $weiter = 1;
			      },
			     )
	}
	# XXX letztes Fenster braucht Sonderbehandlung
	# (Sichern ja/nein)
	$wizard_chain[$wizard_index]->();
	$t->waitVariable(\$weiter);
	$weiter = 0;
    }

#XXX set_proxy verwenden (wetterbericht2::proxy!!!!)
    $proxy = "http://$proxy_host:$proxy_port/";
    if ($bp_obj) {
	$bp_obj->weight_cyclist($gewicht);
	$bp_obj->weight_machine($gewicht_rad);
	$bp_obj->A_c($a_c);
    }

    if ($do_save) {
	warn "sicjer";
    }

    $t->grabRelease;
    $t->destroy;
}

sub config_wizard_start {
    _destroy_children($img_f);
    _destroy_children($text_f);

    $text_f->Label(-text => 'Konfigurations-Wizard',
		   -font => $font{'verylarge'},
		   -wraplength => 300)->pack(-pady => 5);
    $text_f->Label(-text => 'Mit diesem Wizard können die persönlichen Einstellungen für BBBike konfiguriert und für spätere Sitzungen gespeichert werden.',
		   -wraplength => 300)->pack(-pady => 5);

}

sub config_wizard_wind {
    _destroy_children($img_f);
    _destroy_children($text_f);
    $text_f->Label(-text => 'Wind', -font => $font{'verylarge'})->pack(-pady => 5);

    my $want_wind_f = $text_f->Frame(-relief => 'ridge',
				     -bd => 2)->pack(-fill => 'x',
						     -expand => 1,
						     -anchor => 'n',
						     -padx => 3,
						     -pady => 2);
    {
	$want_wind_f->Label(-text => 'Soll die Windrichtung und -geschwindigkeit bei der Leistungsberechnung beachtet werden?',
			    -wraplength => 300, -justify => 'left')->pack;
	my $f1 = $want_wind_f->Frame->pack;
	$f1->Radiobutton(-text => 'Ja',
			 -variable => \$want_wind,
			 -value => 1,
			)->pack(-side => 'left');
	$f1->Radiobutton(-text => 'Nein',
			 -variable => \$want_wind,
			 -value => 0)->pack(-side => 'left');
    }

    my $wetter_f = $text_f->Frame(-relief => 'ridge',
				  -bd => 2)->pack(-fill => 'x',
						  -expand => 1,
						  -anchor => 'n',
						  -padx => 3,
						  -pady => 2);
    {
	$wetter_f->Label(-text => 'Soll der Wetterbericht für die Windrichtung und -geschwindigkeit automatisch beim Start von BBBike über das Internet gezogen werden?',
			 -wraplength => 300, -justify => 'left')->pack;
	my $f1 = $wetter_f->Frame->pack;
	$f1->Radiobutton(-text => 'Ja',
			 -variable => \$do_www,
			 -value => 1,
			)->pack(-side => 'left');
	$f1->Radiobutton(-text => 'Nein',
			 -variable => \$do_www,
			 -value => 0)->pack(-side => 'left');
    }

    my $proxy_f = $text_f->Frame(-relief => 'ridge',
				 -bd => 2)->pack(-fill => 'x',
						 -expand => 1,
						 -anchor => 'n',
						 -padx => 3,
						 -pady => 2);
    {
	$proxy_f->Label(-text => 'Welcher HTTP-Proxy soll bei der Internetverbindung verwendet werden? Falls direkte Verbindungen möglich und erwünscht sind, muss kein Proxy angegeben werden.',
			-wraplength => 300, -justify => 'left')->pack;
	my $f1 = $proxy_f->Frame->pack;
	require Tk::LabEntry;
	$f1->LabEntry(-label => 'Proxy-Server',
		      -labelPack => [-side => 'left'],
		      -textvariable => \$proxy_host,
		     )->pack(-side => 'left');
	$f1->LabEntry(-label => 'Port',
		      -labelPack => [-side => 'left'],
		      -textvariable => \$proxy_port,
		     )->pack(-side => 'left');
    }

}

sub config_wizard_bikepower {
    require BikePower;
    require BikePower::Tk;
    _destroy_children($img_f);
    _destroy_children($text_f);
    $text_f->Label(-text => 'Bikepower', -font => $font{'verylarge'}
		  )->pack(-pady => 5);

    my $mensch_f = $text_f->Frame(-relief => 'ridge',
				  -bd => 2)->pack(-fill => 'x',
						  -expand => 1,
						  -anchor => 'n',
						  -padx => 3,
						  -pady => 2);
    {
	$mensch_f->Label(-text => 'Für die Leistungsberechnung wird das Gewicht des Radfahrers und des Fahrrads benötigt.',
			 -wraplength => 300, -justify => 'left')->pack;
	my $f1 = $mensch_f->Frame->pack(-anchor => 'w');
	$f1->Label(-text => 'Gewicht des Radfahrers:',
		   -wraplength => 300, -justify => 'left'
		  )->pack(-side => 'left');
	$f1->Entry(-textvariable => \$gewicht,
		   -width => 3,
		  )->pack(-side => 'left');
	$f1->Label(-text => 'kg',
		  )->pack(-side => 'left');

	my $f2 = $mensch_f->Frame->pack(-anchor => 'w');
        $f2->Label(-text => 'Gewicht von Rad und Kleidung:',
		   -wraplength => 300, -justify => 'left'
		  )->pack(-side => 'left');
	$f2->Entry(-textvariable => \$gewicht_rad,
		   -width => 3,
		  )->pack(-side => 'left');
	$f2->Label(-text => 'kg',
		  )->pack(-side => 'left');
    }

    my $luftw_f = $text_f->Frame(-relief => 'ridge',
				  -bd => 2)->pack(-fill => 'x',
						  -expand => 1,
						  -anchor => 'n',
						  -padx => 3,
						  -pady => 2);
    {
	$luftw_f->Label(-text => 'Vorderfläche beim Radfahren (Luftwiderstand)',
		      -wraplength => 300, -justify => 'left'
		     )->pack;
	my $f1 = $luftw_f->Frame->pack;
	my $gridy = 0;
	my $gridx = 0;
	BikePower::Tk::load_air_resistance_icons($top);
	foreach (@BikePower::air_resistance_order) {
	    my $text = $_;
	    my $icon = $BikePower::air_resistance{$_}->{'icon'};
	    my $rb = $f1->Radiobutton
	      (-indicator => 0,
	       (defined $icon ? (-image => $icon) : (-text => $text)),
	       -variable => \$a_c,
	       -value => $BikePower::air_resistance{$_}->{'A_c'},
	      )->grid(-row => $gridy,
		      -column => $gridx);
	    $wiz_balloon->attach
	      ($rb, -msg => $BikePower::air_resistance{$_}->{'text_de'});
	    $gridx++;
	    if ($gridx > 3) { $gridx = 0; $gridy++ }
	}
#XXX falls nicht ausgewählt, nächsten Wert auswählen
    }

    my $roll_f = $text_f->Frame(-relief => 'ridge',
				  -bd => 2)->pack(-fill => 'x',
						  -expand => 1,
						  -anchor => 'n',
						  -padx => 3,
						  -pady => 2);
    {
	$roll_f->Label(-text => 'Rollwiderstand der Reifen')->pack;
	my $lb = $roll_f->Scrolled('Listbox', -scrollbars => 'osoe'
				  )->pack(-fill => 'x');

	my @choices;
	foreach my $r (@BikePower::rolling_friction) {
	    push @choices, sprintf("%-6s ", $r->{'R'}) 
	      . "(" . $r->{"text_de"} . ")";
	}

	$lb->insert('end', @choices);
	# XXX vorselektieren, auslesen
    }
}



sub config_wizard_end {
    _destroy_children($img_f);
    _destroy_children($text_f);

    $text_f->Label(-text => 'Soll die Konfiguration gesichert werden?',
		   -font => $font{'verylarge'},
		   -wraplength => 300)->pack(-pady => 5);

}

sub _destroy_children {
    my $f = shift;
    foreach ($f->children) { $_->destroy }
}

1;

# konfigurierbar:
# * was am Anfang gezeichnet werden soll
# * Lieblingsgeschwindigkeit/-leistung
# * Ampeloptimierung einschalten
# * Qualitätsoptimierung
# * Tragen vermeiden
# * beim Starten auf ... Zentrieren
# * Canvas-Balloon
# * hörbarer Klick
