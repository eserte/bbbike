# -*- perl -*-

#
# $Id: Tk.pm,v 1.9 2004/10/02 08:21:47 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright: see BikePower.pm
#
# Mail: slaven@rezic.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use strict;

package Tie::Lang;

sub TIEHASH {
    my($pkg, $lang_def_ref, $lang) = @_;
    my $self = {};
    bless $self, $pkg;
    $self->{LangDef} = $lang_def_ref;
    $self->set_lang($lang || 'en');
    $self;
}

sub FETCH {
    my($self, $key) = @_;
    if (exists $self->{LangDef}{$self->{Lang}}{$key}) {
	$self->{LangDef}{$self->{Lang}}{$key};
    } else {
	$key;
    }
}

sub STORE  { die }
sub DELETE { die }

sub set_lang {
    my($self, $newlang) = @_;
    $self->{Lang} = $newlang;
}

package BikePower::Tk;
use BikePower;
use vars qw($VERSION @interfaces %icons);
$VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

# language strings
my $lang_s =
  {'en' =>
   {
   },
   'de' =>
   {
    'File' => 'Datei',
    'New' => 'Neu',
    'Clone' => 'Klonen',
    'Close' => 'Schließen',
    'Settings' => 'Einstellungen',
    'Load defaults' => 'Voreinstellung laden',
    'Load...' => 'Laden...',
    'Save as default' => 'Als Voreinstellung sichern',
    'Save as...' => 'Sichern als...',
    'Apply' => 'Anwenden',
    'Warning' => 'Warnung',
    'Overwrite existing file <%s>?' => 'Bereits vorhandene Datei <%s> überschreiben?',
    'No' => 'Nein',
    'Yes' => 'Ja',
    'Help' => 'Hilfe',
    'About...' => 'Über...',
    'Reference...' => 'Referenz...',
    'Temperature' => 'Temperatur',
    'Velocity of headwind' => 'Gegenwind',
    'toggle headwind and backwind' => 'zwischen Gegen- und Rückenwind umschalten',
    'Crosswind' => 'Seitenwind',
    'Grade of hill' => 'Steigung',
    'toggle up and down hill' => 'zwischen Steigung und Gefälle umschalten',
    'Frontal area' => 'Vorderfläche (Luftwiderstand)',
    'set air resistance' => 'Luftwiderstand setzen',
    'Transmission efficiency' => 'Effizienz der Übertragung',
    'Rolling friction' => 'Rollwiderstand',
    'Weight of cyclist' => 'Fahrergewicht',
    'Weight of bike+clothes' => 'Gewicht von Rad+Kleidung',
    'Resolve for' => 'Lösen für',
    'first' => 'Erster Wert',
    'first value in table' => 'erster Wert in der Tabelle',
    'increment' => 'Erhöhung',
    'velocity' => 'Geschwindigkeit',
    'power' => 'Leistung',
    'consumption' => 'Verbrauch',
    'Calc' => 'Berechnen',
    'start calculation' => 'Berechnung starten',
    'automatic' => 'automatisch',
    'immediate calculation when values change' => 'sofortige Berechnung bei Wertänderung',
    'total force resisting forward motion' => 'Gesamtkraft entgegen der Vorwärtsbewegung',
    'power output to overcome air resistance' => 'Leistung zum Überwinden des Luftwiderstands',
    'power output to overcome rolling friction' => 'Leistung zum Überwinden des Rollwiderstands',
    'power output to climb grade' => 'Leistung zum Überwinden der Steigung',
    'power loss due to drivetrain inefficiency' => 'Leistungsverlust durch Übertragungsineffizienz',
    'total power output' => 'Gesamtleistung',
    'total power output [hp]' => 'Gesamtleistung [PS]',
    'power wasted due to human inefficiency' => 'Leistungsverlust durch körperl. Ineffizienz',
    #'basal metabolism' => 'XXX',
    'total power consumption' => 'Gesamtleistungsverbrauch',
   },
  };

sub tk_output {
    my($self) = @_;
    $self->_init_output;

    my $entry;
    for ($entry = 0; $entry < $self->N_entry; $entry++) {
	$self->calc();
	my $out;
	foreach $out (@BikePower::out) {
	    $self->{'_lab'}{$out}->[$entry]->configure
	      (-text => sprintf($BikePower::fmt{$out},
				$self->{'_out'}{$out}));
	}
	$self->_incr_output;
    }
}

sub load_air_resistance_icons {
    my $f = shift;
    my $air_r;
    foreach $air_r (keys %BikePower::air_resistance) {
	if (!defined $BikePower::air_resistance{$air_r}->{'icon'}) {
	    eval {
		$BikePower::air_resistance{$air_r}->{'icon'} =
		  $f->MainWindow->Pixmap(-file =>
					 Tk::findINC("BikePower/$air_r.xpm"));
	    };
	}
    }
}

sub tk_interface {
    my($self, $parent, %args) = @_;

    my $lang = $args{'-lang'} || 'en';
    my $savedefaultshook = $args{'-savedefaultshook'};
    my $applyhook = $args{'-applyhook'}; # also creates "Apply" menu entry
    my %s;
    tie %s, 'Tie::Lang', $lang_s, $lang;

    require Tk::Balloon;
    require FindBin;
    push(@INC, $FindBin::Bin);

    my $entry = 'Entry';
    eval { require Tk::NumEntry;
	   Tk::NumEntry->VERSION(1.02);
	   require Tk::NumEntryPlain;
	   Tk::NumEntryPlain->VERSION(0.05);
       };
    if (!$@) { $entry = 'NumEntry' }

    my $automatic = 0;

    my $top = $parent->Toplevel(-title => 'Bikepower');
    $self->{'_top'} = $top;
    push(@interfaces, $top);

    $top->optionAdd("*font" => '-*-helvetica-medium-r-*-14-*',
		    'startupFile');

    require Tk::Menubar;
    my $menuframe = $top->Menubar(-relief => 'raised',
				  -borderwidth => 2,
				 );
    #my $menuframe = $top->Frame(-relief => 'raised',#
				#-borderwidth => 2,
			       #);
    #$menuframe->pack(-fill => 'x');

    my $mb_file = $menuframe->Menubutton(-text => $s{'File'},
					 -underline => 0);
    $mb_file->pack(-side => 'left') if $Tk::VERSION < 800;
    $mb_file->command(-label => $s{'New'},
		      -underline => 0,
 		      -command => sub {
			  eval {
			      $top->Busy;
			      my $bp = new BikePower;
			      $bp->tk_interface($parent);
			      $top->Unbusy;
			  };
			  warn $@ if $@;
		      });
    $mb_file->command(-label => $s{'Clone'},
		      -underline => 1,
 		      -command => sub {
 		          eval {
 		              $top->Busy;
 		              my $bp = clone BikePower $self;
			      $bp->tk_interface($parent, %args);
			      $top->Unbusy;
			  };
			  warn $@ if $@;
		      });
    $mb_file->command(-label => $s{'Close'},
		      -underline => 0,
 		      -command => sub { $top->destroy });

    my $mb_set = $menuframe->Menubutton(-text => $s{'Settings'},
					-underline => 0);
    $mb_set->pack(-side => 'left') if $Tk::VERSION < 800;
    $mb_set->command
      (-label => $s{'Load defaults'},
       -underline => 5,
       -command => sub { $self->load_defaults });
    $mb_set->command
      (-label => $s{'Load...'},
       -underline => 0,
       -command => sub {
	   my $file;
	   eval { 
	       $file = $top->getOpenFile
		 (-defaultextension => '*.pl');
	   };
	   if ($@) {
	       require Tk::FileSelect;
	       $self->{'_load_fd'} =
		 $top->FileSelect(-create => 0,
				  -filter => "*.pl");
	       $file = $self->{'_load_fd'}->Show;
	   }
	   if (defined $file) {
	       $self->load_defaults($file);
	   }
       });
    $mb_set->command
      (-label => $s{'Save as default'},
       -underline => 5,
       -command => sub {
	   $self->save_defaults;
	   if ($savedefaultshook) {
	       $savedefaultshook->($self, "savedefaultshook");
	   }
       });
    $mb_set->command
      (-label => $s{'Save as...'},
       -underline => 0,
       -command => sub {
	   my $file;
	   eval { 
	       $file = $top->getSaveFile
		 (-defaultextension => '*.pl');
	   };
	   if ($@) {
	       require Tk::FileSelect;
	       $self->{'_save_fd'} = 
		 $top->FileSelect(-create => 1,
				  -filter => "*.pl");
	       $file = $self->{'_save_fd'}->Show;
	       if ($file) {
		   if ($file !~ /\.pl$/) {
		       $file .= ".pl";
		   }
		   if (-e $file) {
		       require Tk::Dialog;
		       my $d = $top->Dialog
			 (-title => $s{'Warning'},
			  -text  => sprintf($s{'Overwrite existing file <%s>?'}, $file),
			  -default_button => $s{'No'},
			  -buttons => [$s{'Yes'}, $s{'No'}],
			  -popover => 'cursor');
		       return if $d->Show ne $s{'Yes'};
		   }
	       }
	   }
	   if (defined $file) {
	       $self->save_defaults($file);
	   }
       });
    if ($applyhook) {
	$mb_set->separator;
	$mb_set->command
	    (-label => $s{'Apply'},
	     -command => sub { $applyhook->($self, "applyhook") },
	    );
    }

    my $mb_help = $menuframe->Menubutton(-text => $s{'Help'},
					 -underline => 0);
    $mb_help->pack(-side => 'right') if $Tk::VERSION < 800;
    $mb_help->command
      (-label => $s{'About...'},
       -underline => 0,
       -command => sub { 
	   require Tk::Dialog;
	   $top->Dialog(-text =>
			"BikePower.pm $BikePower::VERSION\n" .
			"(c) 1997,1998 Slaven Rezic")->Show;
       },
      );
    $mb_help->command
      (-label => $s{'Reference...'},
       -underline => 0,
       -command => sub { 
	   eval {
	       require Tk::Pod;
	       Tk::Pod->Dir($FindBin::Bin);
	       $top->Pod(-file => 'BikePower.pm');
	   };
	   if ($@) {
	       require Tk::Dialog;
	       $top->Dialog(-text => "Error: $@")->Show;
	   }
       });


    my $f = $top->Frame->pack;
    my $balloon = $f->Balloon;

    load_air_resistance_icons($f);
    {
	my $icon;
	foreach $icon ('up_down', 'change_wind') {
	    if (!defined $icons{$icon}) {
		eval { 
		    $icons{$icon} =
		      $f->Pixmap(-file => Tk::findINC("BikePower/$icon.xpm"));
		};
	    }
	}
    }

    my $row = 0;

    my $calc_button;
    my $autocalc = sub {
	$calc_button->invoke if $automatic;
    };

    my $labentry = sub {
	my($top, $row, $text, $varref, $unit, %a) = @_;
	my $entry = ($a{-forceentry} ? 'Entry' : $entry);
	$top->Label(-text => $text)->grid(-row => $row,
					  -column => 0,
					  -sticky => 'w');
	my $w;
	if (exists $a{-choices}) {
	    require Tk::BrowseEntry;
	    $w = $top->BrowseEntry(-variable => $varref,
				   ($Tk::VERSION >= 800
				    ? (-browsecmd => $autocalc)
				    : ()
				   ),
				  )->grid(-row => $row,
					  -column => 1,
					  -columnspan => 2,
					  -sticky => 'w');
	    $w->insert("end", @{$a{-choices}});
	} else {
	    # only a spacer for alignment with BrowseEntry's
	    $top->Label->grid(-row => $row, -column => 1);
	    $w = $top->$entry(-textvariable => $varref,
			      ($entry eq 'NumEntry' && exists $a{-resolution}
			       && $Tk::NumEntryPlain::VERSION >= 1.05
			       ? (-increment => $a{-resolution},
				  -command => $autocalc,
				 )
			       : ()
			      ),
			     )->grid(-row => $row,
				     -column => 2,
				     -sticky => 'w');
	}
	$w->bind('<FocusOut>' => $autocalc);
	if (defined $unit) {
	    $top->Label(-text => $unit)->grid(-row => $row,
					      -column => 3,
					      -sticky => 'w');
	}
    };

    &$labentry($f, $row, $s{'Temperature'} . ':', \$self->{'T_a'}, '°C');
    $row++;

    &$labentry($f, $row, $s{'Velocity of headwind'} . ':',
	       \$self->{'H'}, 'm/s');
    if (defined $icons{'change_wind'}) {
 	my $btn = $f->Button(-image => $icons{'change_wind'},
			     -command => sub { $self->{'H'} = -$self->{'H'};
					       &$autocalc;
					   },
			    )->grid(-row => $row,
				    -column => 4,
				    -sticky => 'w',
				    -padx => 3);
	$balloon->attach($btn, -msg => $s{'toggle headwind and backwind'});
    }
    $row++;
    $f->Checkbutton(-text => $s{'Crosswind'},
		    -variable => \$self->{'cross_wind'},
		    -command => $autocalc,
		   )->grid(-row => $row,
			   -column => 0,
			   -sticky => 'w',
			   -ipady => 0,
			  ); $row++;

    &$labentry($f, $row, $s{'Grade of hill'} . ':', \$self->{'G'}, 'm/m',
	       -resolution => 0.01);
    if (defined $icons{'up_down'}) {
 	my $btn =$f->Button(-image => $icons{'up_down'},
			    -command => sub { $self->{'G'} = -$self->{'G'};
					      &$autocalc;
					  },
			   )->grid(-row => $row,
				   -column => 4,
				   -sticky => 'w',
				   -padx => 3);
	$balloon->attach($btn, -msg => $s{'toggle up and down hill'});
    }
    $row++;

    &$labentry($f, $row, $s{'Weight of cyclist'} . ':',
	       \$self->{'Wc'}, 'kg');
    $row++;
    &$labentry($f, $row, $s{'Weight of bike+clothes'} . ':',
	       \$self->{'Wm'}, 'kg');
    $row++;

    my @std_a_c =
      map { $BikePower::air_resistance{$_}->{'A_c'} . " (" .
	      $BikePower::air_resistance{$_}->{"text_$lang"}
	    . ")"
	} @BikePower::air_resistance_order;
    &$labentry($f, $row, '', \$self->{'A_c'}, 'm²',
	       -choices => \@std_a_c);
    my $ac_frame = $f->Frame(-relief => 'raised',
			     -borderwidth => 2)->grid(-row => $row,
						      -column => 0,
						      -sticky => 'w'); $row++;
    my $ac_mb = $ac_frame->Menubutton(-text => $s{'Frontal area'} . ':',
					-padx => 0,
					-pady => 0)->pack;
    $balloon->attach($ac_mb, -msg => $s{'set air resistance'});
    {
	my $i = 0;
	my $air_r;
	foreach $air_r (@BikePower::air_resistance_order) {
	    {
		my $i = $i; # wegen des Closures...
		my $icon = $BikePower::air_resistance{$air_r}->{'icon'};
		$ac_mb->command
		  ((defined $icon ? (-image => $icon) : (-label => $air_r)),
		   -command => sub { $self->{'A_c'} = $std_a_c[$i];
				     &$autocalc;
				 });
	    }
	    $i++;
	}
	if ($Tk::VERSION >= 800.010) {
	    $balloon->attach
	      ($ac_mb->cget(-menu),
	       -msg => ['',
			map { $BikePower::air_resistance{$_}->{"text_$lang"} }
			@BikePower::air_resistance_order]);
	}
    }

    {
	my @choices;
	foreach my $r (@BikePower::rolling_friction) {
	    push @choices, sprintf("%-6s ", $r->{'R'}) 
	      . "(" . $r->{"text_$lang"} . ")";
	}
	&$labentry($f, $row, $s{'Rolling friction'} . ':', \$self->{'R'},
		   undef,
		   -choices => \@choices); $row++;
    }

    &$labentry($f, $row, $s{'Transmission efficiency'} . ':',
	       \$self->{'T'}, undef,
	       -resolution => 0.01); $row++;

    my $res_frame = $top->Frame(-bg => 'yellow')->pack(-fill => 'x',
						       -ipady => 5);
    # XXX But the entries should still be grey or white depending on the
    # windowing system
    $res_frame->optionAdd('*' . substr($res_frame->PathName, 1) . "*background"
			  => 'yellow', 'userDefault');
    $row = 0;
    $res_frame->Label(-text => $s{'Resolve for'} . ':'
		     )->grid(-row => $row,
			     -column => 0,
			     -sticky => 'w');
    my $first_label = $res_frame->Label(-text => $s{'first'}
				       )->grid(-row => $row,
					       -column => 1);
    $balloon->attach($first_label, -msg => $s{'first value in table'});
    $res_frame->Label(-text => $s{'increment'})->grid(-row => $row,
							-column => 2);

    my $w;

    $row++;
    $res_frame->Radiobutton(-text => $s{'velocity'},
			    -variable => \$self->{'given'},
			    -value => 'v',
			    -command => $autocalc,
			   )->grid(-row => $row,
				   -column => 0,
				   -sticky => 'w');
    $w = $res_frame->$entry(-textvariable => \$self->{'first_V'},
			    -width => 8,
			   )->grid(-row => $row,
				   -column => 1,
				   -sticky => 'w');
    $w->bind('<FocusOut>' => $autocalc);
    $w = $res_frame->$entry(-textvariable => \$self->{'V_incr'},
			    -width => 8,
			   )->grid(-row => $row,
				   -column => 2,
				   -sticky => 'w');
    $w->bind('<FocusOut>' => $autocalc);
    $row++;
    $res_frame->Radiobutton(-text => $s{'power'},
			    -variable => \$self->{'given'},
			    -value => 'P',
			    -command => $autocalc,
			   )->grid(-row => $row,
				   -column => 0,
				   -sticky => 'w');
    $w = $res_frame->$entry(-textvariable => \$self->{'first_P'},
			    -width => 8,
			   )->grid(-row => $row,
				   -column => 1,
				   -sticky => 'w');
    $w->bind('<FocusOut>' => $autocalc);
    $w = $res_frame->$entry(-textvariable => \$self->{'P_incr'},
			    -width => 8,
			   )->grid(-row => $row,
				   -column => 2,
				   -sticky => 'w');
    $w->bind('<FocusOut>' => $autocalc);
    $row++;
    $res_frame->Radiobutton(-text => $s{'consumption'},
			    -variable => \$self->{'given'},
			    -value => 'C',
			    -command => $autocalc,
			   )->grid(-row => $row,
				   -column => 0,
				   -sticky => 'w');
    $w = $res_frame->$entry(-textvariable => \$self->{'first_C'},
			    -width => 8,
			   )->grid(-row => $row,
				   -column => 1,
				   -sticky => 'w');
    $w->bind('<FocusOut>' => $autocalc);
    $w = $res_frame->$entry(-textvariable => \$self->{'C_incr'},
			    -width => 8,
			   )->grid(-row => $row,
				   -column => 2,
				   -sticky => 'w');
    $w->bind('<FocusOut>' => $autocalc);
    $row++;
    $calc_button = $res_frame->Button
      (-text => $s{'Calc'} . '!',
       -fg => 'white',
       -bg => 'red',
       -command => sub { tk_output($self) },
      )->grid(-row => 1,
	      -rowspan => 2,
	      -column => 5,
	      -padx => 5);
    $top->bind($top, "<Return>" => $autocalc);
    $balloon->attach($calc_button, -msg => $s{'start calculation'});

    my $auto_calc_check = $res_frame->Checkbutton
      (-text => $s{'automatic'},
       -variable => \$automatic,
       -command => sub {
	   $calc_button->invoke if $automatic;
       },
      )->grid(-row => 3,
	      -column => 5,
	      -padx => 5);
    $balloon->attach($auto_calc_check,
	       -msg => $s{'immediate calculation when values change'});
    my $output_frame = $top->Frame(-bg => '#ffdead')->pack(-fill => 'x');
    for (0 .. 11) {
        $output_frame->gridColumnconfigure($_, -weight => 1);
    }
    my $output_frame_name = '*' . substr($output_frame->PathName, 1);
    $output_frame->optionAdd($output_frame_name . "*background"
			     => '#ffdead', 'userDefault');
    $output_frame->optionAdd($output_frame_name . "*relief"
			     => 'ridge', 'userDefault');
    $output_frame->optionAdd($output_frame_name . "*borderWidth"
			     => 1, 'userDefault');
    my $col = 0;
    my $v_label = $output_frame->Label(-text => 'v',
				       -width => 5,
				      )->grid(-row => 0,
					      -column => $col,
					      -sticky => 'ew'); $col++;
    $balloon->attach($v_label, -msg => $s{'velocity'} . ' [km/h]');
    my $F_label = $output_frame->Label(-text => 'F',
				       -width => 4,
				      )->grid(-row => 0,
					      -column => $col,
					      -sticky => 'ew'); $col++;
    $balloon->attach($F_label, -msg => $s{'total force resisting forward motion'} . ' [kg]');
    my $Pa_label = $output_frame->Label(-text => 'Pa',
					-width => 4,
				       )->grid(-row => 0,
					       -column => $col,
					       -sticky => 'ew'); $col++;
    $balloon->attach($Pa_label,
	       -msg => $s{'power output to overcome air resistance'} . ' [W]');
    my $Pr_label = $output_frame->Label(-text => 'Pr',
					-width => 4,
				       )->grid(-row => 0,
					       -column => $col,
					       -sticky => 'ew'); $col++;
    $balloon->attach($Pr_label,
	       -msg => $s{'power output to overcome rolling friction'} . ' [W]');
    my $Pg_label = $output_frame->Label(-text => 'Pg',
					-width => 5,
				       )->grid(-row => 0,
					       -column => $col,
					       -sticky => 'ew'); $col++;
    $balloon->attach($Pg_label, -msg => $s{'power output to climb grade'} . ' [W]');
    my $Pt_label = $output_frame->Label(-text => 'Pt',
					-width => 4,
				       )->grid(-row => 0,
					       -column => $col,
					       -sticky => 'ew'); $col++;
    $balloon->attach($Pt_label,
	       -msg => $s{'power loss due to drivetrain inefficiency'} . ' [W]');
    my $P_label = $output_frame->Label(-text => 'P',
				       -width => 5,
				      )->grid(-row => 0,
					      -column => $col,
					      -sticky => 'ew'); $col++;
    $balloon->attach($P_label, -msg => $s{'total power output'} . ' [W]');
    my $hp_label = $output_frame->Label(-text => 'hp',
					-width => 5,
				       )->grid(-row => 0,
					       -column => $col,
					       -sticky => 'ew'); $col++;
    $balloon->attach($hp_label, -msg => $s{'total power output [hp]'});
    my $heat_label = $output_frame->Label(-text => 'heat',
					  -width => 5,
					 )->grid(-row => 0,
						 -column => $col,
					         -sticky => 'ew'); $col++;
    $balloon->attach($heat_label,
	       -msg => $s{'power wasted due to human inefficiency'} . ' [W]');
    my $BM_label = $output_frame->Label(-text => 'BM',
					-width => 3,
				       )->grid(-row => 0,
					       -column => $col,
					       -sticky => 'ew'); $col++;
    $balloon->attach($BM_label, -msg => $s{'basal metabolism'} . ' [W]');
    my $C_label = $output_frame->Label(-text => 'C',
				       -width => 5,
				      )->grid(-row => 0,
					      -column => $col,
					      -sticky => 'ew'); $col++;
    $balloon->attach($C_label, -msg => $s{'total power consumption'} . ' [W]');
    my $kJh_label = $output_frame->Label(#-text => 'kJ/h',
					 -text => 'cal/h',
					 -width => 5,
					)->grid(-row => 0,
						-column => $col,
					        -sticky => 'ew'); $col++;
    $balloon->attach($kJh_label, -msg => #'total power consumption [kJ/h]'
	       $s{'total power consumption'} . ' [cal/h]');

    {
	my $entry;
	for($entry = 0; $entry < $self->{'N_entry'}; $entry++) {
	    $col = 0;
	    my $out;
	    foreach $out (@BikePower::out) {
		$self->{'_lab'}{$out}->[$entry] = $output_frame->Label;
		$self->{'_lab'}{$out}->[$entry]->grid
		  (-row => 1 + $entry,
		   -column => $col,
		   -sticky => 'ew'); $col++;
	    }
	}
    }

    $top;
}

1;

