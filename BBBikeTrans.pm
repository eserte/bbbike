# -*- perl -*-

#
# $Id: BBBikeTrans.pm,v 1.4 2002/11/06 15:47:30 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use strict;
use vars qw($scale $small_scale $medium_scale $verbose);

######################################################################
#
# Tranpose-Funktionen
#

# Transponiert die Daten (y-Achse vertauschen etc.) und setzt das 
# Zentrum auf die Berliner Innenstadt.
# Diese Funktion bildet praktisch von realcoords (die vermessenen) auf 
# @coords (im canvas) ab.
# XXX Problem!!!
# new_create_transpose_subs funktioniert nur im Normalmodus, aber nicht
# im Editmodus!
# Kein Autoload-Sub wegen Parsing-Problemen von make_autoload
sub new_create_transpose_subs {
    my(%args) = @_;
    my $x_delta = $args{-xdelta} || -200;
    my $y_delta = $args{-ydelta} || 600;
    my $x_mount = $args{-xmount} || 1;
    my $y_mount = $args{-ymount} || -1;
    my $scale   = $args{-scale}  || $scale;
    my $small_scale   = $args{-smallscale}  || $small_scale;
    my $medium_scale  = $args{-mediumscale} || $medium_scale;
    local($^W) = undef;
    my $code = "
sub transpose_ls_slow {
    (int(($x_delta+($x_mount)*" . '$_[0]' . "/25)*$scale),
     int(($y_delta+($y_mount)*" . '$_[1]' . "/25)*$scale));
}
sub transpose_pt {
    (int((  $y_delta +($y_mount)*" . '$_[1]' . "/25)*$scale),
     int((-($x_delta)-($x_mount)*" . '$_[0]' . "/25)*$scale));
}
# wie transpose_ls, nur für das Overview-Fenster (Verkleinerung: $small_scale)
sub transpose_ls_small {
    (int(($x_delta+($x_mount)*" . '$_[0]' . "/25)*$small_scale),
     int(($y_delta+($y_mount)*" . '$_[1]' . "/25)*$small_scale));
}
sub transpose_pt_small {
    (int((  $y_delta +($y_mount)*" . '$_[1]' . "/25)*$small_scale),
     int((-($x_delta)-($x_mount)*" . '$_[0]' . "/25)*$small_scale));
}
# wie transpose_ls, nur für das Overview-Fenster (Verkleinerung: $medium_scale)
sub transpose_ls_medium {
    (int(($x_delta+($x_mount)*" . '$_[0]' . "/25)*$medium_scale),
     int(($y_delta+($y_mount)*" . '$_[1]' . "/25)*$medium_scale));
}
sub transpose_pt_medium {
    (int((  $y_delta +($y_mount)*" . '$_[1]' . "/25)*$medium_scale),
     int((-($x_delta)-($x_mount)*" . '$_[0]' . "/25)*$medium_scale));
}
# wie transpose_ls, nur ohne x und y_delta. Für das Berechnen von Breiten
# und Höhen geeignet
sub transpose_ls_abs {
    (int((" . '$_[0]' . "/25)*$scale),
     int((" . '$_[1]' . "/25)*$scale));
}
# Diese Funktion bildet von coords (im canvas) auf realcoords ab.
sub anti_transpose_ls {
    (int(($x_mount*" . '$_[0]' . "/$scale-($x_delta))*25),
     int(($y_mount*" . '$_[1]' . "/$scale+($y_delta))*25));
}
sub anti_transpose_pt {
    (int((-($x_delta)-($x_mount)*" . '$_[1]' . "/$scale)*25),
     int((  $y_delta +($y_mount)*" . '$_[0]' . "/$scale)*25));
}
";
#XXX anti_transpose_ls_medium etc. missing
    warn $code if $verbose;
    eval $code;
    warn $@ if $@;
}

# old static transpose/anti_transpose functions
# Wird verwendet!!!
# kann gelöscht werden, wenn new_create_transpose_subs auch im Edit-Modus
# funktioniert.
# dann kann new_create_transpose_subs nach create_transpose_subs
# umbenannt und die symbolische Referenz für create_transpose_subs
# gelöscht werden.
my $create_transpose_subs_created = 0; # nur einmal erzeugen
# Kein Autoload-Sub wegen Parsing-Problemen von make_autoload
sub old_create_transpose_subs {
    return if ($create_transpose_subs_created);
    $create_transpose_subs_created++;
    my $code = '
sub transpose_ls_slow {
    (int((-200+$_[0]/25)*$scale), int((600-$_[1]/25)*$scale));
}
sub transpose_pt {
    (int((600-$_[1]/25)*$scale), int((200-$_[0]/25)*$scale));
}
# wie transpose_ls, nur für das Overview-Fenster (Verkleinerung: $small_scale)
sub transpose_ls_small {
    (int((-200+$_[0]/25)*$small_scale), int((600-$_[1]/25)*$small_scale));
}
sub transpose_pt_small {
    (int((600-$_[1]/25)*$small_scale), int((200-$_[0]/25)*$small_scale));
}
# wie transpose_ls, nur für das Overview-Fenster (Verkleinerung: $medium_scale)
sub transpose_ls_medium {
    (int((-200+$_[0]/25)*$medium_scale), int((600-$_[1]/25)*$medium_scale));
}
sub transpose_pt_medium {
    (int((600-$_[1]/25)*$medium_scale), int((200-$_[0]/25)*$medium_scale));
}
# wie transpose_ls, nur ohne x und y_delta. Für das Berechnen von Breiten
# und Höhen geeignet
sub transpose_ls_abs {
    (int(($_[0]/25)*$scale), int(($_[1]/25)*$scale));
}
# Diese Funktion bildet von coords (im canvas) auf realcoords ab.
sub anti_transpose_ls {
    (int(($_[0]/$scale+200)*25), int((600-$_[1]/$scale)*25));
}
sub anti_transpose_pt {
    (int((200-$_[1]/$scale)*25), int((600-$_[0]/$scale)*25));
}
# wie anti_transpose_ls, nur für das Overview-Fenster (Verkleinerung: $small_scale)
sub anti_transpose_ls_small {
    (int(($_[0]/$small_scale+200)*25), int((600-$_[1]/$small_scale)*25));
}
sub anti_transpose_pt_small {
    (int((200-$_[1]/$small_scale)*25), int((600-$_[0]/$small_scale)*25));
}
# wie anti_transpose_ls, nur für das Overview-Fenster (Verkleinerung: $medium_scale)
sub anti_transpose_ls_medium {
    (int(($_[0]/$medium_scale+200)*25), int((600-$_[1]/$medium_scale)*25));
}
sub anti_transpose_pt_medium {
    (int((200-$_[1]/$medium_scale)*25), int((600-$_[0]/$medium_scale)*25));
}
';
    warn $code if $verbose;
    eval $code;
    warn $@ if $@;
}

# Besser, da nicht mit ints gearbeitet wird (vor allem beim Reinzoomen!).
# Könnte auf Maschinen ohne FPU langsamer sein.
my $create_transpose_subs_no_int_created = 0;
sub old_create_transpose_subs_no_int {
    return if ($create_transpose_subs_no_int_created);
    warn "XXX Using old_create_transpose_subs_no_int ...\n";
    $create_transpose_subs_no_int_created++;
    my $code = '
sub transpose_ls_slow {
    ((-200+$_[0]/25)*$scale, (600-$_[1]/25)*$scale);
}
sub transpose_pt {
    ((600-$_[1]/25)*$scale, (200-$_[0]/25)*$scale);
}
# wie transpose_ls, nur für das Overview-Fenster (Verkleinerung: $small_scale)
sub transpose_ls_small {
    ((-200+$_[0]/25)*$small_scale, (600-$_[1]/25)*$small_scale);
}
sub transpose_pt_small {
    ((600-$_[1]/25)*$small_scale, (200-$_[0]/25)*$small_scale);
}
# wie transpose_ls, nur für das Overview-Fenster (Verkleinerung: $medium_scale)
sub transpose_ls_medium {
    ((-200+$_[0]/25)*$medium_scale, (600-$_[1]/25)*$medium_scale);
}
sub transpose_pt_medium {
    ((600-$_[1]/25)*$medium_scale, (200-$_[0]/25)*$medium_scale);
}
# wie transpose_ls, nur ohne x und y_delta. Für das Berechnen von Breiten
# und Höhen geeignet
sub transpose_ls_abs {
    (($_[0]/25)*$scale, ($_[1]/25)*$scale);
}
# Diese Funktion bildet von coords (im canvas) auf realcoords ab.
sub anti_transpose_ls {
    (($_[0]/$scale+200)*25, (600-$_[1]/$scale)*25);
}
sub anti_transpose_pt {
    ((200-$_[1]/$scale)*25, (600-$_[0]/$scale)*25);
}
# wie anti_transpose_ls, nur für das Overview-Fenster (Verkleinerung: $small_scale)
sub anti_transpose_ls_small {
    (($_[0]/$small_scale+200)*25, (600-$_[1]/$small_scale)*25);
}
sub anti_transpose_pt_small {
    ((200-$_[1]/$small_scale)*25, (600-$_[0]/$small_scale)*25);
}
# wie anti_transpose_ls, nur für das Overview-Fenster (Verkleinerung: $medium_scale)
sub anti_transpose_ls_medium {
    (($_[0]/$medium_scale+200)*25, (600-$_[1]/$medium_scale)*25);
}
sub anti_transpose_pt_medium {
    ((200-$_[1]/$medium_scale)*25, (600-$_[0]/$medium_scale)*25);
}
';
    warn $code if $verbose;
    eval $code;
    warn $@ if $@;
}

# Transponiert die übergebene Liste und gibt sie zurück.
# ([x1,y1],[x2,y2],...) => ([tx1,ty1],[tx2,ty2],...)
sub transpose_all {
    my @res;
    foreach (@_) {
	push @res, [transpose(@$_)];
    }
    @res;
}

# Transponiert die übergebene Liste zurück und gibt sie zurück.
# ([x1,y1],[x2,y2],...) => ([tx1,ty1],[tx2,ty2],...)
sub anti_transpose_all {
    my @res;
    foreach (@_) {
	push @res, [anti_transpose(@$_)];
    }
    @res;
}

1;

__END__
