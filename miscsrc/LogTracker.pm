#
# LogTracker.pm
#
# -*- perl -*-

#
# $Id: LogTracker.pm,v 1.1.1.1 2003/05/20 17:14:58 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Real time display of bbbike AccessLogs
# Description (de): Echtzeitanzeige der BBBike-Accesslogs
package LogTracker;
use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION $lastcoords
            $layer @colors $colors_i @accesslog_data
            $logfile);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1.1.1 $ =~ /(\d+)\.(\d+)/);

use URI::Escape;
use Strassen::Core;

sub register {
    my $pkg = __PACKAGE__;
    $BBBikePlugin::plugins{$pkg} = $pkg;
    add_button();
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $subw = $mf->Subwidget($pkg . '_on');
    if (Tk::Exists($subw)) { $subw->destroy }
    delete $BBBikePlugin::plugins{$pkg};
}

sub add_button {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $mmf = $main::top->Subwidget("ModeMenuPluginFrame");
    return unless defined $mf;

    my $b;
    $b = $mf->Label
        (-text => "Log",
        )->pack(-side => "left", -anchor => 'sw');
    $mf->Advertise(__PACKAGE__ . '_on' => $b);
    $main::balloon->attach($b, -msg => "LogTracker")
        if $main::balloon;

    BBBikePlugin::place_menu_button
            ($mmf,
             [
              [Button => "Start tracker",
               -command => sub {
                   parse_tail_log();
               }],
              [Button => "Stop tracker",
               -command => sub {
                   stop_parse_tail_log();
               }],
              [Button => "Set defaults",
               -command => sub {
                   my $t = $main::top->Toplevel(-title => "LogTracker");
                   require Tk::PathEntry;
		   my $e;
                   Tk::grid($t->Label(-text => "Logfile"),
                            $e = $t->PathEntry(-textvariable => \$logfile),
                           );
                   Tk::grid($t->Button(-text => "Close",
                                       -command => sub { $t->destroy }),
                           );
		   $t->Popup(@main::popup_style);
		   $e->focus;
		   $e->bind("<Return>" => sub {
				stop_parse_tail_log();
				parse_tail_log();
				$t->destroy;
			    });
               }],
              "-",
              [Button => "Delete this menu",
               -command => sub {
                   $mmf->after(100, sub {
                                   unregister();
                               });
               }],
             ],
             $b,
            );
}

######################################################################

init();

sub init {
    $colors_i = 0;
    @colors = ('#000080', '#0000a0', '#0000c0', '#0000f0',
               '#0080f0', '#8000f0', '#6000c0', '#4000a0',
              );
    $layer = main::next_free_layer();
    @accesslog_data = ();
#    $logfile = "/home/e/eserte/www/AccessLog";
    $logfile = "/tmp/AccessLog" if !defined $logfile;
}

sub parse_accesslog {
    warn "Free layer: $layer\n";
    @accesslog_data = ();
    open(AL, $logfile) or die "Can't open $logfile: $!";
    while(<AL>) {
        chomp;
        my(@d) = parse_line($_);
	push @accesslog_data, @d if @d;
    }
    close AL;
    my $s = Strassen->new_from_data_ref(\@accesslog_data);
    $s->write("/tmp/x.bbd");
    main::plot("str", $layer, -draw => 1, Filename => "/tmp/x.bbd");
    $main::str_obj{$layer} = $s; # for LayerEditor
}

sub parse_tail_log {
    open FH, "-|" or do {
        exec "tail", "-f", $logfile;
        die $!;
    };
    warn "Start parsing file $logfile...\n";
    $main::top->fileevent(\*FH, "readable", \&fileevent_read_line);
}

sub stop_parse_tail_log {
    $main::top->fileevent(\*FH, "readable", "");
    warn "Stopped parsing log...\n";
}

sub fileevent_read_line {
    if (eof(FH)) {
        $main::top->fileevent(\*FH, "readable", "");
        return;
    }
    my $line = <FH>;
    my(@d) = parse_line($line);
    push @accesslog_data, @d if @d;
    if (@d) {
        push @accesslog_data, @d;
        my $s = Strassen->new_from_data_ref(\@accesslog_data);
	$s->write("/tmp/x.bbd");
        main::plot("str", $layer, -draw => 1, Filename => "/tmp/x.bbd");
        $main::str_obj{$layer} = $s; # for LayerEditor
	my $last = $s->get($s->count-1);
	main::mark_point(-point => $last->[Strassen::COORDS()]->[-1],
			 -dont_center => 1)
		if $last;
    }
}

sub parse_line {
    my $line = shift;
    my $lastcoords;
    if ($line =~ m{GET\s+(?:/~eserte/bbbike/cgi/bbbike.cgi|/cgi-bin/bbbike\.cgi)\?.*coords=([^&; ]+)}) {
        my $coords = uri_unescape(uri_unescape($1));
        my $date = "???";
        if ($line =~ m{(\d+/[a-z]+/\d+:\d+:\d+:\d+)}i) {
            $date = $1;
        }

        my($startname, $vianame, $zielname);
        if ($line =~ m{startname=([^&; ]+)}) {
            ($startname = $1) =~ s/\+/ /g;
            $startname = uri_unescape(uri_unescape($startname));
        }
        if ($line =~ m{vianame=([^&; ]+)}) {
            ($vianame = $1) =~ s/\+/ /g;
            $vianame = uri_unescape(uri_unescape($vianame));
        }
        if ($line =~ m{zielname=([^&; ]+)}) {
            ($zielname = $1) =~ s/\+/ /g;
            $zielname = uri_unescape(uri_unescape($zielname));
        }
        my $routename;
        if ($startname) { $routename  = $startname }
        if ($vianame)   { $routename .= " - $vianame" }
        if ($zielname)  { $routename .= " - $zielname" }

        $coords =~ s/[!;]/ /g;
        if (defined $lastcoords && $coords eq $lastcoords) {
            return ();
        }
        $lastcoords = $coords;
        my $ret = "$routename [$date]\t" . $colors[$colors_i] . " $coords\n";
        $colors_i++; $colors_i %= scalar @colors;
        return ($ret);
    } else {
	my(@ret);
	for my $type (qw(start via ziel)) {
	    if ($line =~ /${type}c=([^&; ]+)/) {
		my $coords = uri_unescape(uri_unescape($1));
		my $name = "$coords";
		if ($line =~ /${type}name=([^&; ]+)/) {
		    $name = uri_unescape(uri_unescape($1));
		}
		my $date = "???";
		if ($line =~ m{(\d+/[a-z]+/\d+:\d+:\d+:\d+)}i) {
		    $date = $1;
		}
		my $ret = "$name [$date]\t" . $colors[$colors_i] . " $coords\n";
		$colors_i++; $colors_i %= scalar @colors;
		push @ret, $ret;
	    }
	}
	return @ret;
    }
}

1;

__END__

