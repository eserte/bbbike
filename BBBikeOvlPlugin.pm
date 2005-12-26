#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: BBBikeOvlPlugin.pm,v 2.10 2004/12/30 13:32:19 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

# Description (en): draw .ovl files
# Description (de): .ovl-Dateien zeichnen
package BBBikeOvlPlugin;
use base qw(BBBikePlugin);

use strict;
use vars qw($button_image $del_button_image);

use GPS::Ovl;

# Plugin register method
sub register {

    if (!defined $button_image) {
	$button_image = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhDwAPAMIAAP8AAAAAANfX1////21tbf///////////yH5BAEAAAcALAAAAAAPAA8A
AANHeACnGiCE5hy7R2Zme5Ychn1g1ISLJAmDoKpUE7Q068aZXQ9TPOuvYADYIByMBIKE1kMe
lTne85nszQLOZJUiyWp7MiEslgAAOw==
EOF
    }

    if (!defined $del_button_image) {
	$del_button_image = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhDwAPAMIAAP8AAAAAANfX1////21tbf///////////yH5BAEAAAcALAAAAAAPAA8A
AAMneACnzq1BRl20td757IbYco1kaZJilKITWGqnsprLzErup9rSWF8JADs=
EOF
    }

    add_buttons();
}

sub add_buttons {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    return unless defined $mf;

    my $b = $mf->Button
	(main::image_or_text($button_image, 'Open OVL'),
	 -command => sub {
	     my $f = $main::top->getOpenFile
		 (-filetypes =>
		  [
		   ["OVL-Dateien", ['.ovl', '.OVL']],
		   ["Alle Dateien", '*'],
		  ]
		 );
	     if (defined $f) {
		 bbbike_draw_symbols($f);
	     }
	 });
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_open');
    $main::balloon->attach($b, -msg => "Open OVL file")
	if $main::balloon;

    my $b2 = $mf->Button
	(main::image_or_text($del_button_image, 'Del OVL'),
	 -command => sub {
	     bbbike_del_ovl();
	 });
    BBBikePlugin::replace_plugin_widget($mf, $b2, __PACKAGE__.'_del');
    $main::balloon->attach($b2, -msg => "Del OVL")
	if $main::balloon;
}

sub draw_symbols {
    my($self, $c, $transpose, %args) = @_;
    my @create_args;
    my @tags;
    if ($args{-tags}) {
	push @tags, (UNIVERSAL::isa($args{-tags}, 'ARRAY')
		     ? @{ $args{-tags} }
		     : $args{-tags}
		    );
    }

    my @first_coord;
    foreach my $sym (@{$self->{Symbols}}) {
	if ($sym->{Coords} && @{ $sym->{Coords} }) {
	    @first_coord = $transpose->(@{ $sym->{Coords}[0] });
	}
    }

    foreach my $sym (@{$self->{Symbols}}) {
	next unless $sym->{Coords};
	my @tags = @tags;
	if (defined $sym->{Balloon}) {
	    push @tags, $sym->{Balloon};
	}
	if ($sym->{Text}) {
	    (my $text = $sym->{Text}) =~ s/\x0d\x0a/\n/g;
	    $c->createText($transpose->(@{$sym->{Coords}[0]}),
			   -text => $text,
			   -anchor => "w",
			   @create_args,
			   (@tags ? (-tags => \@tags) : ()),
			  );
	} elsif ($sym->{Label}) {
	    $c->createText($transpose->(@{$sym->{Coords}[0]}),
			   -text => $sym->{Label},
			   #-anchor => "w", (center???)
			   @create_args,
			   (@tags ? (-tags => \@tags) : ()),
			  );
	} elsif (@{$sym->{Coords}} == 1) {
	    my($tx,$ty) = $transpose->(@{$sym->{Coords}[0]});
	    $c->createLine($tx,$ty,$tx+1,$ty,-width => 3,
			   @create_args,
			   (@tags ? (-tags => \@tags) : ()),
			  );
	} else {
	    my @tc;
	    foreach (@{$sym->{Coords}}) {
		push @tc, $transpose->(@$_);
	    }
	    $c->createLine(@tc, @create_args,
			   (defined $sym->{Color} ? (-fill => $sym->{Color}) : ()),
			   (@tags ? (-tags => \@tags) : ()),
			  );
	}
    }

    if (@first_coord && $c->can("see")) {
	$c->see(@first_coord);
    }
}

sub bbbike_del_ovl {
    $main::c->delete("ovl");
}

sub bbbike_draw_symbols {
    my($file) = @_;
    my $ovl = GPS::Ovl->new($file);
    $ovl->read;
    require Karte;
    require Karte::Polar;
    $Karte::Polar::obj=$Karte::Polar::obj;
    my $transpose;
    if ($main::coord_system_obj) {
	$transpose = sub { main::transpose($Karte::Polar::obj->map2map($main::coord_system_obj, @_)) };
    } else {
	$transpose = sub { main::transpose($Karte::Polar::obj->map2standard(@_)) };
    }
    draw_symbols($ovl, $main::c, $transpose, -tags => 'ovl');
}

return 1 if caller();

package main;

require Tk;
require Tk::CanvasUtil;
use vars qw($c);
my $file = shift || die "ovl file is missing";
my $top = MainWindow->new;
*transpose = sub { ($_[0], -$_[1]) };
$c = $top->Scrolled("Canvas")->pack(-expand => 1, -fill => "both");
$c->update;
BBBikeOvlPlugin::bbbike_draw_symbols($file);
my @bbox = $c->bbox("all");
if (@bbox) {
    $c->configure(-scrollregion => \@bbox);
} else {
    warn "Nothing drawn?";
}
Tk::MainLoop();

__END__
