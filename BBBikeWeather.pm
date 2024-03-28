# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2003,2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

package BBBikeWeather;

$VERSION = '1.10';

package main;
use strict;
use BBBikeGlobalVars;

##### Wind & Wetter ##############################################

# Gibt 1 zur�ck, falls ein lokales Verzeichnis mit Wetterdaten existiert
sub BBBikeWeather::wetter_dir_exists {
    foreach my $dir (@wetter_dir) {
	if (-d $dir && -x $dir) {
	    $wetter_dir = $dir;
	    return 1;
	}
    }
    0;
}

# Ignoriert die Wind- und Wettereinstellungen und zeichnet die Route
# ggfs. neu.
### AutoLoad Sub
sub BBBikeWeather::ignore_weather {
    BBBikeWeather::reset_wind();
    if ($wetter_route_update) {
	redraw_path();
	updatekm();
    }
}

### AutoLoad Sub
sub BBBikeWeather::reset_wind {
    $wind_v_max = 0;
    $wind_v = 0;
    $winddate = '';
    $act_value{Windlabel} = M"Wind";
    $act_value{Wind} = M"Keine Daten";
    $wind = 0;
}

### AutoLoad Sub
sub BBBikeWeather::require_wettermeldung {
    # hack, um wettermeldung2 perl4-kompatibel zu lassen
    $wettermeldung2::module = 1;
    $wettermeldung2::tk_widget = $top;
    require "wettermeldung2";
    ## This smells like a perl bug, maybe only in 5.10.0 (seen on
    ## debian). After the require, TMPDIR is undefined which is not
    ## good for some programs, e.g. iceweasel
    ## (WWWBrowser::start_browser does not work anymore). So be safe
    ## and delete it.
    if (exists $ENV{TMPDIR} && !defined $ENV{TMPDIR}) { delete $ENV{TMPDIR} }
}

# Laden der Wetterinformationen. Abh�ngig von den aktuellen Einstellungen
# passiert das lokal oder �ber das WWW.
### AutoLoad Sub
sub BBBikeWeather::update_weather {
    my $force_update = shift;
    return unless $force_update;

    IncBusy($top);

    eval {
	my @station;
	my($act_line, $act_station);
	if ($wetter_station =~ m{metar-(\S+)}) {
	    my $site_code = $1;
	    # only needed for indexes (?)
	    BBBikeWeather::require_wettermeldung();
	    $act_line = `$FindBin::RealBin/miscsrc/icao_metar.pl -sitecode $site_code -wettermeldung`;
	    $act_station = $wetter_station;
	} else {
	    if ($wetter_station eq 'uptodate') {
		# Dahlem2 hat keine mittlere Windgeschwindigkeit
		@station = ('dahlem1',
			    #'tempelhof'
			   );
	    } else {
		@station = ($wetter_station);
	    }

	    my @source;
	    foreach (keys %wetter_source) {
		push @source, $_ if $wetter_source{$_};
	    }
	    #  	if (!@source) {
	    #  	    push @source, 'www' unless $really_no_www;
	    #  	}
	    if (!@source) {
		die M("Es wurde keine Quelle f�r den Empfang der Wetterdaten angegeben.")."\n";
	    }

	    BBBikeWeather::require_wettermeldung();

	    my $station;
	    foreach $station (@station) {
		my $source;
		foreach $source (@source) {
		    warn Mfmt("Versuche %s mit %s...\n", $station, $source)
			if $verbose;
		    my $line;
		    if ($source eq 'www') {
			$wettermeldung2::local = 0;
			$line = wettermeldung2::parse($station);
		    } elsif ($source eq 'db') {
			my $file = "$wetter_dir/$wetter_zuordnung{$station}";
			next if !-r $file;
			$line = wettermeldung2::tail_1($file);
		    } elsif ($source eq 'local') {
			$wettermeldung2::local = 1;
			$line = wettermeldung2::parse($station);
		    } else {
			die Mfmt("Unbekannte Quelle %s", $source);
		    }
		    next if !defined $line || $line =~ /^\s*$/;
		    if (!defined $act_line ||
			&wettermeldung2::date_cmp($act_line, $line) < 0) {
			$act_line    = $line;
			$act_station = $station;
		    }
		}
	    }
	}

	if (!defined $act_line || $act_line =~ /^\s*$/) {
	    die M("Der Wetterbericht kann nicht empfangen werden.\n" .
		  "M�glicher Grund: es konnte keine Internet-Verbindung aufgebaut werden.\n");
	}

	warn Mfmt("Ergebnis von `%s' wird geparst\n", $act_station) if $verbose;
	my @wetterline = parse_wetterline($act_line, $act_station);
	analyze_wind(@wetterline[$wettermeldung2::FIELD_DATE,
				 $wettermeldung2::FIELD_TIME,
				 $wettermeldung2::FIELD_WIND_DIR,
				 $wettermeldung2::FIELD_WIND_MAX,
				 $wettermeldung2::FIELD_WIND_AVG],
		     -station => $act_station);

	if ($bp_obj &&
	    defined $wetterline[$wettermeldung2::FIELD_TEMP] &&
	    $wetterline[$wettermeldung2::FIELD_TEMP] !~ /^\s*$/) {
	    $bp_obj->temperature($wetterline[$wettermeldung2::FIELD_TEMP]);
	}
	if ($wetter_route_update) {
	    redraw_path();
	    updatekm();
	}
    };
    if ($@) {
	status_message($@, 'err');
    }
    DecBusy($top);
}

# Eine lokal vorhandene Wetterdatenbank, falls vorhanden, wird angezeigt.
# Der Benutzer kann einen Eintrag ausw�hlen, der dann diese Daten f�r
# die aktuellen Wetterdaten nimmt.
# Return reference to newly created Toplevel
### AutoLoad Sub
sub BBBikeWeather::show_weather_db {
    my($type, $filename) = @_;
    $filename = $wetter_zuordnung{$type} if !defined $filename;
    if (!defined $filename) { $filename = 'wetter-full' }
    if ($filename !~ m|^/|) { $filename = "$wetter_dir/$filename" }
    if (!-e $filename) {
	# append current year
	$filename .= "-" . (((localtime)[5])+1900);
	if (!-e $filename) {
	    $filename .= ".emergency"; # XXX hack for data from 2023 and newer
	}
    }

    my $t = redisplay_top($top, "weather_db-$filename",
			  -title => $filename);
    return if !defined $t;

    if (!open(DB, $filename)) {
	if (! -f "$filename.gz" || !open(DB, "zcat $filename.gz|")) {
	    status_message
	      (Mfmt("Die Datei %s kann nicht ge�ffnet werden: %s",
		    $filename, $!), 'warn');
	    return undef;
	}
    }

    require Tk::HList;
    BBBikeWeather::require_wettermeldung();

    IncBusy($top);
    eval {
	my @data;
	my $fullwetter = $wetter_full{$type};
	my $select_sub = sub {
	    eval {
		my @wetterline = parse_wetterline($data[$_[0]],
						  $type);
		analyze_wind(@wetterline[$wettermeldung2::FIELD_DATE,
					 $wettermeldung2::FIELD_TIME,
					 $wettermeldung2::FIELD_WIND_DIR,
					 $wettermeldung2::FIELD_WIND_MAX,
					 $wettermeldung2::FIELD_WIND_AVG],
			     -station => $type);
		redraw_path();
		updatekm();
	    };
	};
	my $f = $t->Frame->pack(-fill => 'x', -side => "bottom");
	my $cols = ($type eq 'dahlem1' ? 6 : 5);
	my $lb = $t->Scrolled('HList',
			      -header => 1,
			      -columns => $cols,
			      -selectmode => 'single',
			      -scrollbars => 'osoe',
			      -width => 50,
			      -command => $select_sub,
			     )->pack(-expand => 1, -fill => 'both');
	$top->Advertise(List => $lb);
	eval {
	    require Tk::ItemStyle;
	    require Tk::ResizeButton;
	    my $headerstyle = $lb->ItemStyle('window', -padx => 0, -pady => 0);
	    my @header;
	    my $i = 0;
	    my $scr_hlist = $lb->Subwidget('scrolled');#XXX
	    for (qw(Datum Uhrzeit Temp Windri.)) {
		$header[$i] = $lb->ResizeButton
		  (-text => $_,
		   -relief => 'flat', -pady => 0,
		   -widget => \$scr_hlist,
		   -command => sub {},
		   -column => $i);
		$i++;
	    }
	    for (0 .. 3) {
		$lb->header('create', $_, -itemtype => 'window',
			    -widget => $header[$_], -style => $headerstyle);
	    }
	};
	if ($@) {
	    warn __LINE__ . ": $@" if $verbose;
	    $lb->header('create', 0, -text => M"Datum");
	    $lb->header('create', 1, -text => M"Uhrzeit");
	    $lb->header('create', 2, -text => M"Temp");
	    $lb->header('create', 3, -text => M"Windri.");
	}
	{
#XXX resizeButton auch hier verwenden
	    my $col = 4;
	    if ($type ne 'tempelhof') {
		$lb->header('create', $col, -text => M"max. Wind");
		$col++;
	    }
	    if ($type ne 'dahlem2') {
		$lb->header('create', $col, -text => M"mitt. Wind");
	    }
	}
	my $i = 0;
	my $code .= <<'EOF';
	while(<DB>) {
	    chomp;
	    push @data, $_;
	    my @a = split /\|/o;
	    $lb->add($i, -text => $a[$wettermeldung2::FIELD_DATE]);
	    $lb->itemCreate($i, 1, -text => $a[$wettermeldung2::FIELD_TIME]);
	    $lb->itemCreate($i, 2, -text => $a[$wettermeldung2::FIELD_TEMP]);
	    $lb->itemCreate($i, 3, -text => $a[$wettermeldung2::FIELD_WIND_DIR]);
	    $lb->itemCreate($i, 4, -text => $a[$wettermeldung2::FIELD_WIND_MAX]);
EOF
        if ($type eq 'dahlem1') {
	    $code .= '$lb->itemCreate($i, 5, -text => $a[$wettermeldung2::FIELD_WIND_AVG]);';
	}
	$code .= <<'EOF';
	    $i++;
	}
EOF
	eval $code;
	warn __LINE__ . ": $@" if $@;
	close DB;
	$lb->idletasks; $lb->see($i-1);
	$lb->anchorSet($i-1);
	$lb->focus;
	$f->Button(Name => 'apply',
		   -command => sub { my $i = $lb->info('anchor');
				     return unless defined $i;
				     $select_sub->($i) },
		  )->pack(-side => 'left');
	my $cb = $f->Button(Name => 'end',
			    -command => sub { $t->destroy },
			   )->pack(-side => 'left');
	$t->bind('<<CloseWin>>' => sub { $cb->invoke });
    };
    DecBusy($top);
    $top;
}

# Parset eine Zeile mit Wetterdaten, die entweder aus dem Web oder aus der
# lokalen Datenbank stammt. Zur�ckgegeben wird ein Array mit den folgenden
# Elementen:
#   Datum, Uhrzeit, Temperatur, Luftdruck, Windrichtung, Windst�rke etc.
### AutoLoad Sub
sub BBBikeWeather::parse_wetterline {
    my($wetterline, $source) = @_;
    my $fullwetter = $wetter_full{$source};
    my $wind_is_in_m_s = $fullwetter || $source =~ m{^metar};
    my(@wetterline) = split(/\|/, $wetterline);
    $wetterline[$wettermeldung2::FIELD_WIND_DIR] = lc($wetterline[$wettermeldung2::FIELD_WIND_DIR]);
    if (!exists $BBBikeCalc::wind_dir{$wetterline[$wettermeldung2::FIELD_WIND_DIR]}) {
	$wind = 0;
	die "Can't parse wind direction ($wetterline[$wettermeldung2::FIELD_WIND_DIR]) from " . join("|", @wetterline);
    }
    if ($source !~ m{^metar}i && $wetterline[$wettermeldung2::FIELD_WIND_MAX] !~ /^[\d\.]+$/) {
	$wind = 0;
	die "Can't parse max wind speed ($wetterline[$wettermeldung2::FIELD_WIND_MAX]) from " . join("|", @wetterline);
    }
    if ($fullwetter && $wetterline[$wettermeldung2::FIELD_WIND_AVG] !~ /^[\d\.]+$/) {
	$wind = 0;
	die "Can't parse average wind speed ($wetterline[$wettermeldung2::FIELD_WIND_AVG]) from " . join("|", @wetterline);
    }
    status_message("");
    $temperature = $wetterline[$wettermeldung2::FIELD_TEMP];
    $act_value{Temp} = $temperature . "�C";
    if (!$wind_is_in_m_s) { # Windst�rke ist in Beaufort statt m/s
	require Met::Wind;
	import Met::Wind;
	$wetterline[$wettermeldung2::FIELD_WIND_AVG] = wind_velocity([$wetterline[$wettermeldung2::FIELD_WIND_MAX], 'beaufort'], 'm/s');
	$wetterline[$wettermeldung2::FIELD_WIND_MAX] = undef;
    }
    @wetterline;
}

# Setzt die angegebenen Wetterdaten f�r globale Variablen.
### AutoLoad Sub
sub BBBikeWeather::analyze_wind {
    my($date, $time, $dir, $maxv, $v, %args) = @_;
    ($winddir) = BBBikeCalc::analyze_wind_dir($dir);
    $wind_v_max = $maxv;
    $wind_v     = $v;
    if (defined $date && defined $time) {
	$winddate = join(", ", $date, $time);
##XXX zu wenig Platz im Label
#  	if ($args{-station}) {
#  	    $winddate .= ", $args{-station}";
#  	}
    } else {
	$winddate = '';
    }
    $act_value{Windlabel} = M("Wind")." ".($winddate ne "" ? "($winddate)" : "");
    $act_value{Wind} = "\U$winddir\E,  $wind_v m/s";
    if (defined $wind_v_max && $wind_v_max ne '') {
	$act_value{Wind} .= " (max: $wind_v_max m/s)";
    }
    $wind = 1;
}


1;

__END__
