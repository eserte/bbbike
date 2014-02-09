# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2000,2002,2003,2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

# Cloning menus is expensive (tkMenu.c: CloneMenu and Tk/Menu.pm:
# MenuDup). Exactly this is what is happening in this module: cloning
# menus from the symbol icon bar to the standard menu bar. This takes
# some two seconds from overall 16 seconds startup time on a 466MHz
# Celeron running FreeBSD 4.6, perl 5.8.0 and Tk 800.024. Starting
# with "./bbbike -nomenu" disables the standard menu. All menus are
# also accessible from the standard menu bar, so no functionality is
# lost.

package BBBike::Menubar;

=head1 NAME

BBBike::Menubar - optional conventional menubar for bbbike

=cut

# keine echte OO_Klasse!

#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
#use blib qw(/home/e/eserte/src/perl/legacy);
#use legacy qw(encoding);
#use encoding 'iso-8859-1';
#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

BEGIN {
    if (!eval '
use Msg qw(frommain);
1;
') {
	warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

use vars qw($file_menu $additional_layer_menu $plugins_menu);

sub new {
    my($class, $context) = @_;
    my $self = {};
    while(my($k,$v) = each %$context) {
	$self->{$k} = $v;
    }
    bless $self, $class;
}

sub bbbike_context {
    +{Top        => $main::top,
      MiscFrame  => $main::misc_frame,
      MiscFrame2 => $main::misc_frame2,

      OpenCommand  => sub { main::load_save_route(0) },
      SaveCommand  => sub { main::load_save_route(1) },
      PrintCommand => \&main::print_function,
      OptionsCommand => sub { main::optedit() },
      SearchCommand => sub {
	  require BBBikeAdvanced;
	  main::search_anything();
      },
      ExitCommand  => \&main::exit_app,
     };
}

sub menubar {
    my $self = shift;
    my $top = $self->{Top} || die "Top missing in context";
    my $mb = $top->cget(-menu);
    # existiert bereits:    my $file_menu = $mb->cascade(-label => 'Datei');
    $file_menu->command(-label => M("Ö~ffnen")." ...",
			-command => $self->{OpenCommand});
    my $open_menu = $file_menu->cascade(-label => M"~zuletzt geöffnete Dateien");
    $file_menu->command(-label => M("~Speichern")." ...",
			-command => $self->{SaveCommand});
    my $save_menu = $file_menu->cascade(-label => M"~Exportieren");
    $file_menu->command(-label => M("~Drucken")." ...",
			-command => $self->{PrintCommand});
    my $print_menu = $file_menu->cascade(-label => M"D~ruckeinstellungen");
    $file_menu->command(-label => M"Volltextsuche",
			-accelerator => "Ctrl-F",
			-command => $self->{SearchCommand});
    $file_menu->command(-label => M"~Beenden",
			-accelerator => "Ctrl-Q",
			-command => $self->{ExitCommand});

    my $layer_menu = $mb->cascade(-label => M"~Kartenebenen");
    $layer_menu->cget(-menu)->configure(-title => M"Kartenebenen");

    foreach my $c ($self->{MiscFrame}->children,
		   $self->{MiscFrame2}->children
		  ) {
	if ($c->isa('Tk::Menubutton')) {
	    my $menu = $c->cget(-menu);
	    my $menulabel =
		$menu->{BBBike_Menulabel} ||
		eval q{$menu->entrycget(1, -label)};
	    my $special = $menu->{BBBike_Special};
	    if (defined $special) {
		if ($special eq 'OPEN') {
		    $open_menu->configure(-menu => $menu);
		} elsif ($special eq 'SAVE') {
		    $save_menu->configure(-menu => $menu);
		} elsif ($special eq 'PRINT') {
		    $print_menu->configure(-menu => $menu);
		} elsif ($special eq 'LAYER') {
		    $layer_menu->cascade(-menu => $menu,
					 -label => $menulabel);
		} elsif ($special eq 'OPTIONS') {
		    # Plugin-Menu vor Einstellungen
		    plugin_menu($mb);
		    $mb->cascade(-menu => $menu,
				 -label => $menulabel);
		    # XXX unfortunately, this affects also the menuarrow
		    # menu
		    my $inx = $menu->type(0) eq 'tearoff' ? 1 : 0;
		    $menu->insert($inx, 'command',
				  -label => M"Optionseditor",
				  -command => $self->{OptionsCommand});
		} else {
		    die "Unknown -special: $special";
		}
	    } elsif (defined $menulabel) {
		$mb->cascade(-menu => $menu,
			     -label => $menulabel);
	    } else {
		warn "no menulabel defined for $c";
	    }
	}
    }

    for $mb ($open_menu, $save_menu, $print_menu, $layer_menu) {
	my $m = $mb->cget(-menu);
	if ($m->can('UnderlineAll')) {
	    $m->UnderlineAll;
	}
    }

    if ($additional_layer_menu) {
	$layer_menu->cascade
	    (-menu  => $additional_layer_menu,
	     -label => $additional_layer_menu->{BBBike_Menulabel},
	    );
    }

#XXX nicht nötig??? DEL:    $top->configure(-menu => $mb);
}

sub Set {
    my $bmb = new BBBike::Menubar bbbike_context();
    $bmb->menubar;
}

# erstellt Menubar und reserviert Platz...
# XXX evtl. set_temporary_state aus dem repository verwenden
sub EmptyMenubar {
    my $top = bbbike_context()->{Top};
    my $menu = $top->Menu(-title => "BBBike-Menu");
    $file_menu = $menu->cascade(-label => M"~Datei");
    $file_menu->cget(-menu)->configure(-title => M"Datei");
    $top->configure(-menu => $menu);
}

sub plugin_menu {
    my($mb) = @_;
    my $menulabel = M("~Plugins"); # with underline marker
    (my $menutitle = $menulabel) =~ s{~}{}; # without underline marker
    $plugins_menu = $mb->Menu(-title => $menutitle);
    main::plugin_menu($plugins_menu);
    $mb->cascade(
		 -menu  => $plugins_menu,
		 -label => $menulabel,
		);
}

1;

__END__
