# -*- perl -*-

#
# $Id: Telefonbuch.pm,v 1.32 2003/01/06 02:46:19 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998,1999 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# experimentell
package Telefonbuch;
require Exporter;

use Telefonbuch99;
use Telefonbuch2001;
use BBBikeUtil;
use Karte::GIS;
use strict;
use vars qw($VERBOSE $cdromdir $maxrec_str $maxrec_tel @EXPORT_OK @ISA
	    $no_start_ziel $force $default_img_fmt

	    $cgi_host $cgi_port $cgi_path
	   );

@ISA = qw(Exporter);
@EXPORT_OK = qw(tk_str_dialog tk_tel_dialog);

*my_die = (defined &main::status_message
	   ? sub { main::status_message($_[0], "die") }
	   : sub { die $_[0] }
	  );

*my_warn = (defined &main::status_message
	    ? sub { main::status_message($_[0], "info") }
	    : sub { warn $_[0] }
	   );

use constant pagesize => 0x2000;

use vars qw($Telefonbuch);
$Telefonbuch = "Telefonbuch99";
#$Telefonbuch = "Telefonbuch2001";

my(@strasse_hist, @nachname_hist, @vorname_hist);

my $str_base = "bstrd";
my $tel_base = "btp1d";

my %old_linear;
my %l_found;
my %res;

my($map_toplevel, $map_canvas, $map_map, $map_mapx, $map_mapy);


$cgi_host = ($main::cabulja ? "localhost" : "user.cs.tu-berlin.de")
    unless defined $cgi_host;
$cgi_port = 80 unless defined $cgi_port;
$cgi_path = "/~eserte/bbbike/cgi/berlinmap.cgi" unless defined $cgi_path;

#warn join("\n", map { join(", ", @$_) } search_string($search)), "\n";

sub exists {
    my @cdrom_drives;
    if ($^O =~ /mswin32/i) {
	require Win32Util;
	@cdrom_drives = Win32Util::get_cdrom_drives();
	if (!@cdrom_drives) {
	    @cdrom_drives = qw(D: E: F:);
	}
    } else {
	require UnixUtil;
	@cdrom_drives = UnixUtil::get_cdrom_drives();
	if (!@cdrom_drives) {
	    @cdrom_drives = qw(/cdrom /mnt/cdrom /cd /CDROM);
	}
    }
    if (defined $cdromdir) {
	unshift @cdrom_drives, $cdromdir;
    }
    my @datadirs;
    push @datadirs, map { ("$_/database", "$_/32Bit/database") } @cdrom_drives;

    foreach (@datadirs) {
	if (-d $_) {
	    if (-f "$_/${str_base}d00") {
		$Telefonbuch = "Telefonbuch98";
	    } elsif (-f "$_/" . $Telefonbuch99::strdbbasefile) {
		$Telefonbuch = "Telefonbuch99";
		$Telefonbuch->set_dbroot($_);
	    } elsif (-f "$_/" . $Telefonbuch2001::strdbbasefile) {
		$Telefonbuch = "Telefonbuch2001";
		$Telefonbuch->set_dbroot($_);
	    }
	    return $_;
	}
    }

    my_warn("Unrecognized database files...");

    undef;
}

sub check_exists {
    my($top) = @_;
    if (!Telefonbuch::exists() && !$force) {
	while (1) {
	    # cdmount: meine eigene Spezialität
	    my $has_cdmount = (is_in_path("cdmount"));
	    require Tk::Dialog;
	    my $ans = $top->Dialog
	      (-title => 'Fehler',
	       -text  => 'Die Telefonbuch-CD-ROM ist anscheinend nicht '
	       . (defined $main::os and $main::os eq 'win'
		  ? 'eingelegt' : 'gemountet') . '.' .
	       "\nUnterstützte CD-ROMs: Berlin 1999/2000, Berlin 2000/2001 mit Spezialprogramm",
	       -bitmap => 'error',
	       -buttons => ['Weiter', ($has_cdmount ? ('CD einlegen') : ()), 'Abbrechen'],
	      )->Show;
	    if ($ans eq 'Abbrechen') {
		return undef;
	    } elsif ($ans eq 'Weiter') {
		return 1;
	    }
	    system("cdmount e");
	    my $t = $top->Toplevel(-title => 'Warte auf CD...');
	    my $abbruch = 0;
	    $t->bind('<Escape>' => sub { $abbruch = 1 });
	    $t->Button(-text => 'Abbruch',
		       -command => sub { $abbruch = 1 })->pack;
	    my $r = undef;
	    foreach (1..10) {
		system("cdmount");
		if (Telefonbuch::exists()) {
		    $r = 1;
		    last;
		}
		$t->update;
		if ($abbruch) {
		    last;
		}
	    }
	    $t->destroy;
	    return $r;
	}
    } else {
	1;
    }
}

my %start_button;
my %ziel_button;
my(%found_x, %found_y);

# erzeugt ein Frame (ungepackt) für die Start/Ziel-Auswahl
# $type: 'str' oder 'tel'
sub start_ziel_frame {
    my($top, $type) = @_;
    my $f = $top->Frame(-bd => 2,
			-relief => 'ridge',
		       );
    $f->Label(-text => 'Als ')->pack(-side => 'left');
    $start_button{$type} = $f->Button
      (-text => 'Start',
       -command => sub { set_start_ziel($f, $type, 'start') },
       #XXX -state => 'disabled',
      )->pack(-side => 'left');
    $f->Label(-text => ' / ')->pack(-side => 'left');
    $ziel_button{$type} = $f->Button
      (-text => 'Ziel',
       -command => sub { set_start_ziel($f, $type, 'ziel') },
       #XXX -state => 'disabled',
      )->pack(-side => 'left');
    $f->Label(-text => 'markieren')->pack(-side => 'left');
    $f;
}

# erzeugt ein Frame (ungepackt) für CGI- und Tk-Map-Auswahl
sub map_frame {
    my($t, $type) = @_;
    my $f = $t->Frame(-bd => 2,
		      -relief => 'ridge',
		     );
    $f->Label(-text => "Karte zeigen:")->pack(-side => "left");
    cgi_map_frame($f, $type)->pack(-side => "left", -fill => "x");
    tk_map_frame($f, $type)->pack(-side => "left", -fill => "x");
    $f;
}

# erzeugt ein Frame (ungepackt) für die CGI-Map-Auswahl
# $type: 'str' oder 'tel'
sub cgi_map_frame {
    my($top, $type) = @_;

    # check for existing HTTP-Server on $cgi_host:$cgi_port
    require IO::Socket;
    my $inet = new IO::Socket::INET(PeerAddr => $cgi_host,
				    PeerPort => $cgi_port,
				    Proto    => 'tcp');
    if ($inet) {
	$inet->close;
	$top->Button(-text => 'CGI',
		   -command => sub { show_cgi_map($top, $type) },
		  )->pack(-side => 'left');
    }
    $top;
}

sub tk_map_frame {
    my($top, $type) = @_;
    $top->Button(-text => 'Tk',
		 -command => sub { show_tk_map($top, $type) },
		)->pack(-side => 'left');
    $top;
}

# XXX besser: vorhandene Objekte benutzen
sub new_kreuzungen {
    require Strassen;
    my $str;
    if ($main::str_obj{'s'}) {
	$str = $main::str_obj{'s'};
    } else {
	$str = new Strassen $main::str_file{'s'};
    }
    my($crossings) = $str->all_crossings(RetType => 'hash',
					 UseCache => 1);
    my $kr = new Kreuzungen Hash => $crossings;
    # $kr->make_grid ist nicht mehr nötig
    $kr;
}

sub adjust_x_y {
    my $type = 'str';
    if (defined $l_found{$type}->curselection &&
	ref $res{$type} eq 'ARRAY'
       ) {
	my($i) = $l_found{$type}->curselection;
	($found_x{$type}, $found_y{$type}) = ($res{$type}->[$i][4],
					      $res{$type}->[$i][5]);
    }
}

sub set_start_ziel {
    my($top, $type, $start_ziel) = @_;
    adjust_x_y() if $type eq 'str';
    if (!defined $found_x{$type} || !defined $found_y{$type}) {
	require Tk::Dialog;
	$top->Dialog
	  (-title => 'Fehler',
	   -text  =>
	   'Es kann kein ' . ucfirst($start_ziel) . 'punkt ausgewählt werden.',
	   -bitmap => 'error')->Show;
	return undef;
    }
    my $kr = new_kreuzungen();
    my(@nearest) = $kr->nearest($found_x{$type}, $found_y{$type});
    if (@nearest) {
	if ($start_ziel eq 'start') {
	    main::set_route_start($nearest[0]);
	} else {
	    main::set_route_ziel($nearest[0]);
	}
    } else {
	undef;
    }
}

sub show_cgi_map {
    my($top, $type) = @_;
    adjust_x_y() if $type eq 'str';
    if (!defined $found_x{$type} || !defined $found_y{$type}) {
	require Tk::Dialog;
	$top->Dialog
	  (-title => 'Fehler',
	   -text  =>
	   'Es kann kein Karte angezeigt werden.',
	   -bitmap => 'error')->Show;
	return undef;
    }
    require Karte::Berlinmap1996;
    # XXX lib muß in @INC sein
    require WWWBrowser;
    my($mapx, $mapy, $mapxx, $mapyy) = $Karte::Berlinmap1996::obj->coord
      ($Karte::Berlinmap1996::obj->standard2map($found_x{$type},
						$found_y{$type}));
    WWWBrowser::start_browser
      ("http://$cgi_host:${cgi_port}$cgi_path?x=$mapx&xx=$mapxx&y=$mapy&yy=$mapyy");
    1;
}

sub set_tk_map {
    my($c, $mapx, $mapy) = @_;
    if (!(defined $map_mapx and $map_mapx eq $mapx and
	  defined $map_mapy and $map_mapy eq $mapy)) {
	if (defined $map_map) {
	    $map_map->delete;
	    undef $map_map;
	}
	$map_map =
	    $c->Photo(-file => $Karte::Berlinmap1996::obj->filename
		      ($mapx, $mapy));
	$map_mapx = $mapx;
	$map_mapy = $mapy;
	$c->itemconfigure('map', -image => $map_map);
	$c->bind
	    ('map', '<ButtonPress-1>' =>
	     sub {
		 my $c = shift;
		 my $e = $c->XEvent;
		 my($x, $y) = ($c->canvasx($e->x), $c->canvasy($e->y));
		 if ($x < 105) {
		     $mapx = $Karte::Berlinmap1996::obj->incx($mapx, -1);
		 } elsif ($x > 745) {
		     $mapx = $Karte::Berlinmap1996::obj->incx($mapx, 1);
		 }
		 if ($y < 105) {
		     $mapy = $Karte::Berlinmap1996::obj->incy($mapy, -1);
		 } elsif ($y > 705) {
		     $mapy = $Karte::Berlinmap1996::obj->incy($mapy, 1);
		 }
		 $c->coords('flag', 0, 0);
		 $map_toplevel->Busy;
		 eval {
		     set_tk_map($c, $mapx, $mapy);
		 };
		 my_warn($@) if $@;
		 $map_toplevel->Unbusy;
	     }
            );
    }
}

sub show_tk_map {
    my($top, $type) = @_;
    adjust_x_y() if $type eq 'str';
    # XXX lib und images muß in @INC sein
    require Karte::Berlinmap1996;
    my($mapx, $mapy, $mapxx, $mapyy);
    if (!defined $found_x{$type} || !defined $found_y{$type}) {
	($mapx, $mapy) = (13, 'o'); # ungefähr die Mitte Berlins
    } else {
	($mapx, $mapy, $mapxx, $mapyy) = $Karte::Berlinmap1996::obj->coord
	    ($Karte::Berlinmap1996::obj->standard2map($found_x{$type},
						      $found_y{$type}));
    }
    if (!Tk::Exists($map_toplevel)) {
	$map_toplevel = $top->Toplevel(-title => 'Berlinmap');
	$map_toplevel->geometry("830x850");
	$map_canvas = $map_toplevel->Canvas->pack(-expand => 1,
						  -fill => 'both');
	$map_canvas->createImage(0,0,-anchor => 'nw', -tags => 'map');
	eval {
	    my $Photo = ($main::default_img_fmt eq 'xpm' ? "Pixmap" : "Photo");
	    my $flag = $map_canvas->$Photo
	      (-file => Tk::findINC("images/flag2_bl." . $main::default_img_fmt));
	    $map_canvas->createImage($mapxx-5, $mapyy-16, -anchor => 'nw',
				     -image => $flag, -tags => 'flag')
		if defined $mapxx and defined $mapyy;
	};
	my_warn($@) if $@;
    }
    $map_toplevel->deiconify;
    $map_toplevel->raise;
    $map_toplevel->Busy;
    eval {
	set_tk_map($map_canvas, $mapx, $mapy);
	$map_canvas->coords('flag',$mapxx-5, $mapyy-16)
	    if defined $mapxx and defined $mapyy;
	$map_canvas->raise("flag");
    };
    my_warn($@) if $@;
    $map_toplevel->Unbusy;

    1;
}

sub tk_str_dialog {
    my($top, $mark_sub, $get_coord_sub) = @_;
    return if !check_exists($top);
    my $entry_widget;
    eval { require Tk::HistEntry };
    if ($@) {
	$entry_widget = 'Entry';
    } else {
	$entry_widget = 'HistEntry';
    }
    $maxrec_str = 2000; # Suche begrenzen
    my $t = $top->Toplevel(-title => 'Telefonbuch-CD-ROM');
    $t->transient($top) if $main::transient;

    my($str, $hnr, $zip);
    my $f = $t->Frame->pack(-fill => 'x');
    $f->Label(-text => "Straße")->grid(-row => 0, -column => 0,
				       -sticky => 'e');
    my $e_str = $f->$entry_widget(-textvariable => \$str
				 )->grid(-row => 0, -column => 1,
					 -sticky => 'w');
    if ($e_str->can('history')) {
	$e_str->history(\@strasse_hist);
	$e_str->OnDestroy(sub { @strasse_hist = $e_str->history});
    }

    $f->Label(-text => 'Hausnummer')->grid(-row => 1, -column => 0,
					   -sticky => "e");
    my $e_hnr = $f->Entry(-width => 6,
			  -textvariable => \$hnr
			 )->grid(-row => 1, -column => 1, -sticky => 'w');

### not yet...
#      $f->Label(-text => 'PLZ')->grid(-row => 2, -column => 0,
#  				    -sticky => "e");
#      my $e_zip = $f->Entry(-width => 6,
#  			  -textvariable => \$zip
#  			 )->grid(-row => 2, -column => 1, -sticky => 'w');

    my $b_search =
      $t->Button
	(-text => 'Suchen',
	 -command => sub {
	     $t->Busy;
	     eval {
		 if ($e_str->can('historyAdd')) {
		     $e_str->historyAdd;
		 }
		 $str =~ s/^\s+//; $str =~ s/\s+$//;
		 $hnr =~ s/^\s+//; $hnr =~ s/\s+$//;

#XXX		 $res{'str'} = get_from_db($str, $hnr);
		 if (!defined $res{'str'} || ref $res{'str'} ne 'ARRAY'
		     || !@{ $res{'str'} }) {
		     $res{'str'} = $Telefonbuch->search_street_hnr($str, $hnr);
use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([\%res],[]); # XXX

		 }
		 if ((!defined $res{'str'} || ref $res{'str'} ne 'ARRAY'
		      || !@{ $res{'str'} }) &&
		     $Telefonbuch->can('search_street_nearest_hnr')) {
		     $res{'str'} = $Telefonbuch->search_street_nearest_hnr($str, $hnr);
		 }
		 $l_found{'str'}->delete(0, 'end');
		 undef $found_x{'str'};
		 undef $found_y{'str'};
		 if (!defined $res{'str'} || ref $res{'str'} ne 'ARRAY') {
		     $l_found{'str'}->insert('end', 'Nichts gefunden');
		     return;
		 }
		 my $first = 1;
		 foreach my $item (@{$res{'str'}}) {
		     my($str0, $hnr0, $plz, $ort, $x, $y) = @{ $item };
		     if ($first) {
			 if ($mark_sub) {
			     warn "Mark $str0 $hnr0 ($x,$y)\n"
			       if $VERBOSE;
			     $mark_sub->($x, $y);
			 }
#XXX not needed			 if ($get_coord_sub) {
			     ($found_x{'str'}, $found_y{'str'}) = ($x, $y);
#			      $found_y{'str'}) = $get_coord_sub->($x, $y);
#			 }
			 $first = 0;
		     }
		     if (defined $plz) {
			 $l_found{'str'}->insert('end' => "$str0 $hnr0 ($plz)");
		     } elsif (defined $ort) {
			 $l_found{'str'}->insert('end' => "$str0 $hnr0 ($ort)");
		     } else {
			 $l_found{'str'}->insert('end' => "$str0 $hnr0");
		     }
		 }
	     };
	     $t->Unbusy;
	 })->pack;
    $l_found{'str'} = $t->Scrolled('Listbox',# -height => 5,
				   -scrollbars => 'osoe',
				  )->pack(-fill => 'both', -expand => 1);
    #$t->afterIdle(sub { $l_found{'str'}->GeometryRequest(-1, 5*12); }); #XXX
    start_ziel_frame($t, 'str')->pack(-fill => 'x')
	unless $no_start_ziel;
    if ($main::advanced) {
	map_frame($t, 'str')->pack(-fill => 'x');
    }
    $t->Button(-text => 'Schließen',
	       -command => sub { $t->destroy })->pack(-fill => 'x');

    if ($mark_sub) {
	$l_found{'str'}->bind
	  ('<Double-1>' => sub {
	       # XXX warum stand hier früher res{'res'} statt res{'str'}?
	       return if !defined $res{'str'} || ref $res{'str'} ne 'ARRAY';
	       my($str0, $hnr0, $plz, $ort, $x, $y) 
		 = @{ $res{'str'}->[$l_found{'str'}->index('active')] };
	       $mark_sub->($x, $y);
	   });
    }

    $e_str->tabFocus if $e_str->can('tabFocus');
    $e_str->bind('<Return>' => sub {
		     $e_hnr->tabFocus if $e_hnr->can('tabFocus');
		 });
    $e_hnr->bind('<Return>' => sub { $b_search->invoke });
    $t->bind('<Escape>' => sub { $t->destroy });
    $t;
}

# Rückgabe: ein Array von Items, jeweils im
# [Straße, Hausnummer, PLZ, Ort, X, Y]-Format
sub Telefonbuch98::search_street_hnr {
    my($tel, $str, $hnr, $plz) = @_;
    my(%search_args) = (-spec => 'street',
			-maxrec => $maxrec_str,
		       );
    my @res = search_string($str, $str_base, 0, [0], %search_args);
    my @ret;
    my %street_hash;

    # Überprüfung der PLZ, falls gegeben
    if (defined $plz) {
	my @ret ;
	foreach my $item (@res) {
	    if ($item->[2] == $plz) {
		push @ret, $item;
	    }
	}
	@res = @ret;
    }

    # Überprüfung mit Hausnummer
    if (@res && defined $hnr && $hnr ne '') {
	foreach my $item (@res) {
	    if ($item->[1] eq $hnr) {
		if (!exists $street_hash{$item->[0]}) {
		    $street_hash{$item->[0]}++;
		    $item->[0] = cp850__latin1($item->[0]);
		    convert_street($item);
		    push @ret, $item;
		}
	    }
	}
    }
    return \@ret if (@ret);

    # keine Hausnummer hat gepasst bzw. keine wurde angegeben =>
    # alle Straßen ausgeben
    if (@res) {
	foreach my $item (@res) {
	    if (!exists $street_hash{$item->[0]}) {
		$street_hash{$item->[0]}++;
		$item->[0] = cp850__latin1($item->[0]);
		convert_street($item);
		push @ret, $item;
	    }
	}
	return \@ret;
    }

    # keine Treffer
    ();
}

sub convert_street {
    my $data_ref = shift;
    ($data_ref->[4], $data_ref->[5]) =
      $Karte::GIS::obj->map2standard($data_ref->[4], $data_ref->[5]);
}

sub convert_tel {
    my $data_ref = shift;
    ($data_ref->[3], $data_ref->[4]) =
      $Karte::GIS::obj->map2standard($data_ref->[3], $data_ref->[4]);
}

sub tk_tel_dialog {
    my($top, $mark_sub, $get_coord_sub) = @_;
    return if !check_exists($top);
    my $entry_widget;
    eval { require Tk::HistEntry };
    if ($@) {
	require Tk::LabEntry;
	$entry_widget = 'LabEntry';
    } else {
	$entry_widget = 'HistEntry';
    }
    $maxrec_tel = 200; # Suche begrenzen
    my $t = $top->Toplevel(-title => 'Telefonbuch-CD-ROM');
    $t->transient($top) if $main::transient;
    my($nn, $vn);
    my %search_args;
    $search_args{-exact} = 1;
    $ {$search_args{-oldlinear}} = undef;
    my $e_nn = $t->$entry_widget
      (-label => 'Nachname',
       -labelPack => [-side => 'left'],
       -textvariable => \$nn)->pack(-anchor => 'w');
    my $e_vn = $t->$entry_widget
      (-label => 'Vorname',
       -labelPack => [-side => 'left'],
       -textvariable => \$vn)->pack(-anchor => 'w');
    if ($e_nn->can('history') and $e_vn->can('history')) {
	$e_nn->history(\@nachname_hist);
	$e_vn->history(\@vorname_hist);
	$e_nn->OnDestroy(sub { @nachname_hist = $e_nn->history});
	$e_vn->OnDestroy(sub { @vorname_hist  = $e_vn->history});
    }

    $t->Checkbutton(-text => 'Exakt',
		    -variable => \$search_args{-exact},
		   )->pack(-anchor => 'w');
    $t->LabEntry(-label => 'Max. Treffer:',
		 -labelPack => [-side => 'left'],
		 -width => 6,
		 -textvariable => \$maxrec_tel)->pack(-anchor => 'w');
    my $l_found;
    my($b_prev, $b_next, $b_weiter);
    my @res;
    my $res_i = 0;

    my $show_sub = sub {
	my(%args) = @_;
	my $nolabel = delete $args{-nolabel};
	my $fast    = delete $args{-fast} || 0;
	if ($res_i > $#res) {
	    warn "Adjusting index from $res_i to $#res";
	    $res_i = $#res;
	}
	if (ref $res[$res_i] ne 'ARRAY') {
	    warn "Not an array reference (index $res_i)";
	    return;
	}
	my(@data) = @{ $res[$res_i] };
	if ($VERBOSE && !$fast) {
	    warn join("||", @data), "\n";
	}
	if (!$fast) {
	    $b_prev->configure(-state => 
			       ($res_i == 0 ? 'disabled' : 'normal'));
	    $b_next->configure(-state => 
			       ($res_i == $#res ? 'disabled' : 'normal'));
	}
	if ($Telefonbuch eq 'Telefonbuch2001') {
	    my($x, $y) = ($data[4], $data[5]);
	    my $addtag = "$data[7] $data[6], $data[8], $data[0] $data[1]";
	    if (defined $mark_sub) {
		eval {
		    $mark_sub->($x, $y,
				-addtag => $addtag,
			       );
		};
	    }
	    ($found_x{'tel'}, $found_y{'tel'}) = ($x, $y);
	    $l_found->configure(-text => $addtag);
	} elsif (defined $data[3] && $data[3] ne '') {
	    if ($Telefonbuch eq 'Telefonbuch98') {
		convert_tel(\@data);
	    }
	    my($x, $y) = ($data[3], $data[4]);
	    if ($VERBOSE && !$fast) {
		warn "Mark $x/$y\n";
	    }
	    if ($Telefonbuch eq 'Telefonbuch98') {
		$args{-addtag} = ["$data[12] $data[21], $data[20]",
				  "$data[13] $data[14]"];
	    } else {
		$args{-addtag} = [join(" ", @data[5..$#data])];
	    }
	    if (defined $mark_sub) {
		eval {
		    $mark_sub->($x, $y, %args);
		};
	    }
	    ($found_x{'tel'}, $found_y{'tel'}) = ($x, $y);
	}
	if (!$nolabel && $Telefonbuch ne 'Telefonbuch2001') {
	    my $text;
	    if ($Telefonbuch eq 'Telefonbuch98') {
		$text = $data[18];
	    } else {
		$text = join(" ", @data[5..$#data]);
	    }
	    $text =~ s/<tr>/\n/g;
	    $text =~ s/<[^>]+>/ /g;
	    $l_found->configure(-text => $text);
	}
    };

    my $b_f = $t->Frame->pack(-anchor => 'w');
    my $b_search =
      $b_f->Button(-text => 'Suchen',
		   -command => sub {
		       $t->Busy;
		       eval {
			   if ($e_nn->can('historyAdd')) {
			       $e_nn->historyAdd;
			   }
			   if ($e_vn->can('historyAdd')) {
			       $e_vn->historyAdd;
			   }
			   $ {$search_args{-oldlinear}} = undef;
			   my($res) = $Telefonbuch->search_name
			     ($nn, $vn, %search_args);
			   @res = @$res;
			   if (!@res || ref $res[0] ne 'ARRAY') {
			       $l_found->configure(-text => 'Nichts gefunden');
			       $b_weiter->configure(-state => 'disabled');
			       return;
			   }
			   $b_weiter->configure
			     (-state => (defined $ {$search_args{-oldlinear}}
					 ? 'normal'
					 : 'disabled'));
			   $res_i = 0;
			   $show_sub->();
		       };
		       $t->Unbusy;
		   })->pack(-side => 'left');
    $b_weiter =
      $b_f->Button(-text => 'Weiter',
		   -command => sub {
		       $t->Busy;
		       eval {
			   my $res = $Telefonbuch->search_name
			     ($nn, $vn, %search_args);
			   @res = @$res;
			   if (!@res || ref $res[0] ne 'ARRAY') {
			       $l_found->configure(-text => 'Nichts gefunden');
			       $b_weiter->configure(-state => 'disabled');
			       return;
			   }
			   $b_weiter->configure
			     (-state => (defined $ {$search_args{-oldlinear}}
					 ? 'normal'
					 : 'disabled'));
			   $res_i = 0;
			   $show_sub->();
		       };
		       $t->Unbusy;
		   })->pack(-side => 'left');
    eval { require Tk::FireButton;
	   Tk::FireButton->VERSION(0.04);
       };
    my $firebutton = (!$@ ? 'FireButton' : 'Button');
    $b_f->Button(-text => '|<',
		 -command => sub {
		     return if !@res;
		     $res_i = 0;
		     $show_sub->();
		 },
		 -padx => 0,
		 -pady => 0,
		)->pack(-side => 'left');
    $b_prev = $b_f->$firebutton(-text => '<' . '<',
				-command => sub {
				    return if !@res;
				    return if $res_i-1 < 0;
				    $res_i--;
				    $show_sub->();
				},
				-padx => 0,
				-pady => 0,
			       )->pack(-side => 'left');
    $b_next = $b_f->$firebutton(-text => '>>',
				-command => sub {
				    return if !@res;
				    return if $res_i+1 > $#res;
				    $res_i++;
				    $show_sub->();
				},
				-padx => 0,
				-pady => 0,
			       )->pack(-side => 'left');
    $b_f->Button(-text => '>|',
		 -command => sub {
		     return if !@res;
		     $res_i = $#res;
		     $show_sub->();
		 },
		 -padx => 0,
		 -pady => 0,
		)->pack(-side => 'left');
    $b_f->Button(-text => 'Alle',
		 -command => sub {
		     return if !@res;
		     $t->Busy;
		     eval {
			 for($res_i = 0; $res_i <= $#res; $res_i++) {
			     $show_sub->(-dont_delete_old => 1,
					 -dont_center => 1,
					 -nolabel => 1,
					 -fast => 1);
			 }
		     };
		     $t->Unbusy;
		 })->pack(-side => 'left');
    if (is_in_path("dial")) {
	$b_f->Button(-text => 'Wählen',
		     -command => sub {
			 my $telnr = $res[$res_i]->[20];
			 if (defined $telnr && $telnr ne '') {
			     warn "Wähle $telnr...\n";
			     system("dial $telnr");
			 }
		     })->pack(-side => 'left');
    }

    $l_found = $t->Label(-wraplength => 320,
			 -width => 40,
			 -justify => 'left')->pack;

    start_ziel_frame($t, 'tel')->pack(-fill => 'x')
	unless $no_start_ziel;
    if ($main::advanced) {
	map_frame($t, 'tel')->pack(-fill => 'x');
    }

    $e_nn->tabFocus if $e_nn->can('tabFocus');
    $e_nn->bind('<Return>' => sub {
		    $e_vn->tabFocus if $e_vn->can('tabFocus');
		});
    $e_vn->bind('<Return>' => sub { $b_search->invoke });
    $t->bind('<Escape>' => sub { $t->destroy });
    $t;
}

sub Telefonbuch98::search_name {
    my($nn, $vn, %search_args) = @_;
    $search_args{'-tocmp'} = \&tocmp2;
    $search_args{'-maxrec'} = $maxrec_tel;
    my @res = search_string($nn, $tel_base,
			    [26, 12], [12, 13, 18, 21],
			    %search_args);
    if (@res && defined $vn && $vn ne '') {
	my @newres;
	$vn = tocmp2($vn);
	foreach (@res) {
	    if (tocmp2($_->[21]) eq $vn) {
		push @newres, $_;
	    }
	}
	return @newres;
    }
    if (@res) {
	return @res;
    }
    undef;
}

sub search_string {
    my($search, $base, $key, $convertref, %search_args) = @_;

    my $tocmp = (defined $search_args{'-tocmp'}
		 ? $search_args{'-tocmp'}
		 : \&tocmp);
    my $maxrec = $search_args{-maxrec};

    $search = $tocmp->($search); # für exakte (lineare) Suche
    my $search2 = $search;
    if (defined $search_args{-spec} &&
	$search_args{-spec} eq 'street') {
	$search2 =~ s/\s*\(.*\)\s*$//; # Bezirk abschneiden, für lineare Suche
	# "straße" normieren... ß ist bereits zu s geworden
	$search  =~ s/strase$/str/g;
	$search2 =~ s/strase$/str/g;
    }
    my $fakesearch = $search2; # für binäre Suche
    my $ch = substr($fakesearch, length($fakesearch)-1, 1);
    $ch = chr(ord($ch)-1);
    $fakesearch =~ s/.$/$ch/;
    $fakesearch .= ("\xff" x 10);
    warn "FAKESEARCH: $fakesearch\n" if $VERBOSE;
    my @res;

    my $dir = Telefonbuch::exists();
    if (!defined $dir) {
	my_die("Das Telefonbuch-Verzeichnis konnte nicht gefunden werden!
Vielleicht ist die CD-ROM nicht eingelegt?");
    }

    my $datafile    = "$dir/${base}d00";
    my $indexfile   = "$dir/${base}i00";

    open(I, $indexfile)   or my_die("$indexfile: $!");
    binmode I;
    open(D, $datafile)    or my_die("$datafile: $!");
    binmode D;

    my $begin = 8;
    my $middle;
    seek(I, 0, 2) or die "Can't seek: $!";
    my $end = tell I;
    my $last_middle = -1;

    my $do_linear = 0;

    if (exists $search_args{-oldlinear} &&
	defined $ {$search_args{-oldlinear}}) {
	warn "Continue linear search\n" if $VERBOSE;
	$do_linear = 1;
	$middle = $ {$search_args{-oldlinear}};
    }

    while (1) {
	if (!$do_linear) {
	    $middle = int(($end-$begin)/4/2)*4 + $begin;

	    if ($middle == $last_middle) {
		$do_linear = 1;
		warn "Switch to linear search\n" if $VERBOSE;
		$middle += 4;
	    }
	} else {
	    $middle += 4;
	}

	my $buf;

	seek(I, $middle, 0) or die "Can't seek: $!";
	defined read(I, $buf, 4) or die "Can't read: $!";
	my $seek = unpack("V", $buf);
	seek(D, $seek, 0) or die "Can't seek: $!";
	defined read(D, $buf, 4) or die "Can't read: $!";
	my($ds, $extra_offset) = unpack("v2", $buf); # Anzahl der Datensätze
	my $curr_seek = $seek + 4;
	my(@ds, @ds2, @ds3);
	for(my $i = 0; $i < $ds; $i++) {
	    if (int($curr_seek / pagesize) != int(($curr_seek+3) / pagesize)) {
		# next file page
		$curr_seek = (int($curr_seek / pagesize)+1)*pagesize;
		seek(D, $curr_seek, 0) or die "Can't seek: $!";
	    }
	    defined read(D, $buf, 4) or die "Can't read: $!";
	    my($index, $offset) = unpack("v2", $buf);
# 	    if ($index < 0 || $index > $ds) {
# 		warn "*** ERROR\n";
# 		warn sprintf("Invalid index: $index at 0x%x\n", $seek);
# 		exit 1;
# 	    }
#           $ds[$index] = $offset; # XXX
	    $ds[$i] = $offset;
	    $ds2[$i] = $index;
	    $ds3[$index] = $i;
#warn "*** $ds3[$index]\n";
	    $curr_seek += 4;
	}
	$ds[$ds] = 0; # Ende markieren
	my(@data, @data2);
	for(my $i = 0; $i < $ds; $i++) {
	    seek(D, $seek-$ds[$i]-$extra_offset, 0) or die "Can't seek: $!";
	    defined read(D, $buf, $ds[$i]-$ds[$i+1]) or die "Can't read: $!";
	    push @data, $buf;
	    $data2[$ds2[$i]] = $buf;
	}
#warn ">", join("|| ", map { if (ref $_ eq 'ARRAY') { join("|", @$_)} else { $_ } } @data2), "\n" if $VERBOSE;

	my $k;
	if (ref $key eq 'ARRAY') {
	    foreach my $kk (@$key) {
		if (defined $ds3[$kk] && $data[$ds3[$kk]] ne '') {
		    $k = $ds3[$kk];
		    last;
		}
	    }
	} else {
	    $k = $ds3[$key];
	}
	if (!defined $k) {
	    die "No valid key?! (seek $seek)";
	}
	$data[$k] = cp850__latin1($data[$k]);
	my $cmpdata = $tocmp->($data[$k]);
	warn ">", join(", ", @data), "\n" if $VERBOSE;

	if ($do_linear) {
	    if (defined $convertref) {
		foreach my $i (@$convertref) {
		    next if $i == $k; # bereits convertiert
		    $data2[$i] = cp850__latin1($data2[$i]);
		}
	    }
#warn "$cmpdata <=> $search exact:$search_args{-exact}\n";
	    if ((!$search_args{-exact} && $cmpdata =~ /^\Q$search\E/i) ||
		($search_args{-exact}  && $cmpdata =~ /^\Q$search\E$/i)) {
		push @res, [@data2];
		if (defined $maxrec && @res > $maxrec) {
		    warn "Über $maxrec Datensätze gefunden!\n"
		      if $VERBOSE;
		    if (exists $search_args{'-oldlinear'}) {
			$ {$search_args{'-oldlinear'}} = $middle;
		    }
		    last;
		}
#warn "pushing $data2[0]";
	    } else {
#warn "last";
		if (exists $search_args{'-oldlinear'}) {
		    $ {$search_args{'-oldlinear'}} = undef;
		}
		last if ($cmpdata !~ /^$search2/i);
	    }
	} else {
	    my $cmp = ($cmpdata cmp $fakesearch);
#warn "$cmpdata $cmp $search";
	    if ($cmp < 0) {
		$begin = $middle;
	    } elsif ($cmp > 0) {
		$end = $middle;
	    } else {
		$do_linear = 1;
		next;
	    }
	    $last_middle = $middle;
	}
    }

    close D;
    close I;

    return @res;
}

sub cp850__latin1 {
    $_ = $_[0];
    if (defined $_) {
	tr/\200\201\202\203\204\205\206\207\210\211\212\213\214\215\216\217\220\221\222\223\224\225\226\227\230\231\232\233\234\235\236\237\240\241\242\243\244\245\246\247\250\251\252\253\254\255\256\257\260\261\262\263\264\265\266\267\270\271\272\273\274\275\276\277\300\301\302\303\304\305\306\307\310\311\312\313\314\315\316\317\320\321\322\323\324\325\326\327\330\331\332\333\334\335\336\337\340\341\342\343\344\345\346\347\350\351\352\353\354\355\356\357\360\361\362\363\364\365\366\367\370\371\372\373\374\375\376\377/\307\374\351\342\344\340\345\347\352\353\350\357\356\354\304\305\311\346\306\364\366\362\373\371\377\326\334\370\243\330\327F\341\355\363\372\361\321\252\272\277\256\254\275\274\241\253\273\.\:\?\|\+\301\302\300\251\+\|\+\+\242\245\+\+\+\+\+\-\+\343\303\+\+\+\+\+\=\+\244\360\320\312\313\310i\315\316\317\+\+FL\246\314T\323\337\324\322\365\325\265\336\376\332\333\331\375\335\-\264\255\261\=\276\266\247\367\270\260\250\'\271\263\262f\240/;
    }
    $_;
}

sub tocmp {
    my $a = shift;
    $a =~ tr/äöüÄÖÜß/aouAOUs/;
    lc($a);
}

sub tocmp2 {
    my $a = shift;
    if (defined $a) {
	$a =~ s/ä/ae/g;
	$a =~ s/ö/oe/g;
	$a =~ s/ü/ue/g;
	$a =~ s/Ä/Ae/g;
	$a =~ s/Ö/Oe/g;
	$a =~ s/Ü/Ue/g;
	$a =~ s/ß/ss/g;
	return lc($a);
    }
}

# Bekommt einen String der Form "Straße Hausnummer" und teilt ihn
# in Straße und Hausnummer auf. Genauer genommen ist die Rückgabe:
#  (strasse, hausnummer_complete, hausnummer)
# wobei hausnummer_complete die komplette Hausnummer ist
sub parse_str_number {
    my $str = shift;
    if ($str =~ /^(.*)\s+((\d+)([a-z])?)$/i) {
	return ($1, $2, $3);
    } elsif ($str =~ m|^(.*)\s+((\d+)[a-z]?[-/]\d+[a-z]?)|i) {
	return ($1, $2, $3);
    } else {
	return ($str);
    }
}

sub get_from_db {
    my($str, $hnr) = @_;
    my @res;
    eval {
	push @INC, "$FindBin::RealBin/miscsrc",
	           "/home/e/eserte/src/bbbike/miscsrc";
	require TelbuchDBApprox;
	my $approx = TelbuchDBApprox->new;
	$str .= " $hnr" if defined $hnr;
	@res = $approx->search($str);
	@res = map { [$_->{Street}, $_->{Nr}, undef, $_->{Citypart}, split(/,/, $_->{Coord})] } @res;
    }; my_warn($@) if $@;
    \@res;
}

{ # Execute simple test if run as a script
  package main; no strict;
  $INC{'Telefonbuch.pm'} = 1;
  eval join('',<main::DATA>) || die("$@ $main::DATA") unless caller();
}

1;

__END__

use FindBin;
use lib ("$FindBin::RealBin/lib", "$FindBin::RealBin");
use Tk;
use strict;
# Hier stehen die "emulierten" Variablen, die auch im BBBike-Hauptprogramm
# vorkommen.
use vars qw($advanced $os $transient $devel_host $default_img_fmt);
use Getopt::Long;

$os = ($^O eq 'MSWin32' ? 'win' : 'unix');
$advanced = 1;
$transient = 1;
$devel_host = 1;
$Telefonbuch::cgi_host = "localhost"; # weil $cgi_host schon gesetzt ist
$default_img_fmt = "gif";

GetOptions("maproot=s" => \$Karte::map_root,
	   "force!"    => \$Telefonbuch::force);

#$Telefonbuch::VERBOSE=1; # XXX

$Telefonbuch::no_start_ziel = 1;

my $top = tkinit;
$top->withdraw;

# for debugging...
$top->bind("all", "<Control-d>" => sub { $top->WidgetDump });

my $str_t = Telefonbuch::tk_str_dialog($top);
my $tel_t = Telefonbuch::tk_tel_dialog($top);
$str_t->OnDestroy(sub {
    if (!Tk::Exists($tel_t)) {
	$top->destroy;
    }
});
$tel_t->OnDestroy(sub {
    if (!Tk::Exists($str_t)) {
	$top->destroy;
    }
});

MainLoop;

1;
