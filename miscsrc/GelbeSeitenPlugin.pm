#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: GelbeSeitenPlugin.pm,v 1.8 2004/01/13 18:34:08 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): visualize the search result from www.gelbe-seiten.de
# Description (de): Das Suchergebnis von www.gelbe-seiten.de visualisieren
package GelbeSeitenPlugin;
use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use IO::Handle; # for autoflush
use POSIX ":sys_wait_h";
use HTML::TableExtract;

sub M ($) { $_[0] } # XXX

use strict;
use vars qw($DEBUG);
$DEBUG = 0;

sub register {
    # XXX make image
    add_button();
}

sub add_button {
    my $mf  = $main::top->Subwidget("ModePluginFrame");
    return unless defined $mf;
    my $b = $mf->Button
	(#XXX main::image_or_text($button_image, 'YP'),
	 -text => "YP",
	 -command => \&gelbe_seiten,
	);
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_on');
    $main::balloon->attach($b, -msg => "www.gelbe-seiten.de")
	if $main::balloon;
}

### AutoLoad Sub
sub gelbe_seiten {
    my $t = $main::top->Toplevel(-title => M("Gelbe-Seiten-URL"));
    $t->transient($main::top) if $main::transient;

    my $url = "";
    eval {
	$url = $t->SelectionGet('-selection' =>
				($main::os eq 'win' ? "CLIPBOARD" : "PRIMARY"));
	$url =~ s/\n.*//s;
    };
    my $e;
    Tk::grid($t->Label(-justify => "left",
		       -text => M("URL des Suchergebnisses\nvon www.gelbe-seiten.de\neinfügen:")), "-");
    Tk::grid($t->Label(-text => M("URL")),
	     $e = $t->Entry(-textvariable => \$url)
	    );
    $e->focus;

    my $branche;
    Tk::grid($t->Label(-justify => "left",
		       -text => M("Falls das Ergebnis permanent\ngespeichert werden soll")), "-");
    Tk::grid($t->Label(-text => M("Branche")),
	     $t->Entry(-textvariable => \$branche)
	    );
    my $f;
    Tk::grid($f = $t->Frame, "-");

    my $status;
    my $realstatus;
    require Tk::ROText;
    Tk::grid($status = $f->Scrolled("ROText", -scrollbars => "soe", -width => 40, -height => 4),
	     -sticky => "w", -columnspan => 2);
    $realstatus = $status->Subwidget("scrolled");

    my $okb;
    Tk::grid($okb = $f->Button
	     (Name => "ok",
	      -command => sub {
		  if (defined $branche && $branche ne "" &&
		      $branche =~ /[^a-z0-9_-]/) {
		      $t->messageBox(-message => M("Keine Sonderzeichen und Umlaute für Branche erlaubt"),
				     -icon => "error");
		      return;
		  }
		  my $outfile = "/tmp/gelbeseiten.bbd"; # XXX better file name

		  if (defined $main::os && $main::os eq 'win') { # lose
		      system("$FindBin::RealBin/miscsrc/gelbeseiten.pl " . ($DEBUG ? "-test " : "") . qs($url) . " > $outfile");
		      do_plot($t, $outfile, $branche);
		      return;
		  }

		  # the ipc stuff is hackish...
		  pipe(PARENT_RDR, CHILD_WTR);
		  CHILD_WTR->autoflush();
		  my $pid = fork;
		  if ($pid == 0) { # child
		      open(STDOUT, ">$outfile");
		      open(STDERR, ">&CHILD_WTR");
		      exec("$FindBin::RealBin/miscsrc/gelbeseiten.pl", ($DEBUG ? ("-test") : ()), $url);
		      warn $!;
		      CORE::exit(1);
		  }
		  my $end_child = sub {
		      $SIG{CHLD} = 'IGNORE';
		      $okb->fileevent(\*PARENT_RDR, 'readable', "");
		      do_plot($t, $outfile, $branche);
		  };
		  $SIG{CHLD} = $end_child;
		  $okb->fileevent
		      (\*PARENT_RDR, 'readable',
		       sub {
			   if (eof(PARENT_RDR) || waitpid($pid,&WNOHANG) > 0) {
			       $end_child->();
			   } else {
			       my $mess = scalar <PARENT_RDR>;
			       warn $mess;
			       $realstatus->insert("end", $mess);
			       $realstatus->see("end");
			   }
		       });
		  $t->Busy(-recurse => 1);
	      }),
	     $f->Button(Name => "cancel",
			-command => sub { $t->destroy }
		       )
	    );
}

sub do_plot {
    my($t,$outfile,$branche) = @_;
    my $plotfile = $outfile;
    if (defined $branche && $branche ne "") {
	require File::Copy;
	$plotfile = "$FindBin::RealBin/misc/gelbeseiten/branche_${branche}.bbd";
	File::Copy::cp($outfile, $plotfile);
    }
    main::plot_layer('p', $plotfile);
    $t->after(5*1000, sub { $t->destroy }); # to see the error messages...
}

# REPO BEGIN
# REPO NAME qs /home/e/eserte/src/repository 
# REPO MD5 a6bf14672c63041f27d653eeb60c995e
sub qs {
    join(" ", map {
	my $s = $_;
	$s =~ s/\'/\'\"\'\"\'/g;
	"'${s}'";
    } @_);
}
# REPO END

1;

__END__
