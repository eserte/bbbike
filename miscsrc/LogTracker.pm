#
# LogTracker.pm
#
# -*- perl -*-

#
# $Id: LogTracker.pm,v 1.5 2003/06/02 23:01:17 eserte Exp $
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
	    $do_search_route $ua $safe
            $logfile $tracking $tail_pid $bbbike_cgi);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use URI::Escape;
use Strassen::Core;
use CGI ();

$bbbike_cgi = "http://localhost/bbbike/cgi/bbbike.cgi"
    if !defined $bbbike_cgi;

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
              [Button => "Set defaults",
               -command => sub {
                   my $t = $main::top->Toplevel(-title => "LogTracker");
                   require Tk::PathEntry;
		   my $e;
                   Tk::grid($t->Label(-text => "Logfile"),
                            $e = $t->PathEntry(-textvariable => \$logfile),
                           );
                   Tk::grid($t->Label(-text => "BBBike CGI"),
                            $t->PathEntry(-textvariable => \$bbbike_cgi),
                           );
		   my $return = sub {
		       stop_parse_tail_log();
		       #parse_tail_log();
		       $t->destroy;
		   };
		   $e->bind("<Return>" => $return);
		   my $f;
                   Tk::grid($f = $t->Frame, -columnspan => 2);
		   Tk::grid($f->Button(-text => "Ok",
				      -command => $return),
			    $f->Button(-text => "Close",
                                       -command => sub { $t->destroy }),
                           );
		   $t->Popup(@main::popup_style);
		   $e->focus;
               }],
	      [Checkbutton => "Replay route search",
	       -variable => \$do_search_route,
	       -command => sub {
		   if ($do_search_route) {
		       if (!$ua) {
			   require LWP::UserAgent;
			   require Safe;
			   $ua = LWP::UserAgent->new;
			   $safe = Safe->new;
		       }
		   }
	       },
	      ],
              [Checkbutton => "Tracking",
	       -variable => \$tracking,
               -command => sub {
		   if ($tracking) {
		       parse_tail_log();
		   } else {
		       stop_parse_tail_log();
		   }
               }],
	      [Button => 'AccessLog today',
	       -command => sub {
		   parse_accesslog_today();
	       },
	      ],
	      [Button => 'AccessLog yesterday',
	       -command => sub {
		   parse_accesslog_yesterday();
	       },
	      ],
	      [Button => 'AccessLog for date',
	       -command => sub {
		   parse_accesslog_for_date();
	       },
	      ],
	      [Button => 'Preference statistics',
	       -command => sub {
		   pref_statistics();
	       },
	      ],
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
    my $fh = shift;
    warn "Free layer: $layer\n";
    @accesslog_data = ();
    if (!$fh) {
	open($fh, $logfile) or die "Can't open $logfile: $!";
    }
    while(<$fh>) {
	chomp;
	my @d = parse_line($_);
	push @accesslog_data, @d if @d;
    }
    close $fh;
    draw_accesslog_data();
}

sub draw_accesslog_data {
    my $s = Strassen->new_from_data_ref(\@accesslog_data);
    $s->write("/tmp/x.bbd");
    main::plot("str", $layer, -draw => 1, Filename => "/tmp/x.bbd");
    $main::str_obj{$layer} = $s; # for LayerEditor
}

sub _today {
    require Date::Calc;
    my($y,$m,$d) = Date::Calc::Today();
    $m = _number_monthabbrev($m);
    sprintf "%02d/%s/%04d", $d, $m, $y;
}

sub _yesterday {
    require Date::Calc;
    my($y,$m,$d) = Date::Calc::Add_Delta_Days(Date::Calc::Today(), -1);
    $m = _number_monthabbrev($m);
    sprintf "%02d/%s/%04d", $d, $m, $y;
}

sub parse_accesslog_today {
    parse_accesslog_any_day(_today);
}

sub parse_accesslog_yesterday {
    parse_accesslog_any_day(_yesterday);
}

sub parse_accesslog_for_date {
    my $t = $main::top->Toplevel(-title => "AccessLog for date");
    require Tk::Date;
    my $dw = $t->Date(-fields => "date", -value => "now")->pack;
    my $weiter = 0;
    $t->Button(-text => "OK", -command => sub { $weiter = 1 })->pack;
    $t->protocol(WM_DELETE_WINDOW => sub { $weiter = -1 });
    $t->waitVariable(\$weiter);
    my $dmy;
    if ($weiter == 1 && Tk::Exists($dw)) {
	$dmy = sprintf "%02d/%s/%04d", $dw->get("%d"), _number_monthabbrev(int($dw->get("%m"))), $dw->get("%Y");
	warn $dmy;
    }
    $t->destroy if Tk::Exists($t);
    if ($dmy) {
	parse_accesslog_any_day($dmy);
    }
}

sub parse_accesslog_any_day {
    my $rx = shift;
    require File::ReadBackwards;
    tie *BW, 'File::ReadBackwards', $logfile or die $!;
    @accesslog_data = ();
    my $gather = 0;
    while(<BW>) {
	if (!$gather) {
	    if (index($_, $rx) != -1) {
		$gather = 1;
	    } else {
		next;
	    }
	}
	last if index($_, $rx) == -1;
	chomp;
	my(@d) = parse_line($_);
	push @accesslog_data, @d if @d;
    }
    untie *BW;
    draw_accesslog_data();
}

sub kill_tail {
    if (defined $tail_pid) {
	kill 9 => $tail_pid;
	undef $tail_pid;
    }
}

sub parse_tail_log {
    kill_tail();
    $tail_pid = open FH, "-|";
    if (!$tail_pid) {
        exec "tail", "-f", $logfile;
        die $!;
    };
    warn "Start parsing file $logfile...\n";
    $tracking = 1;
    $main::top->fileevent(\*FH, "readable", \&fileevent_read_line);
}

sub stop_parse_tail_log {
    $tracking = 0;
    kill_tail();
    $main::top->fileevent(\*FH, "readable", "");
    close FH;
    warn "Stopped parsing log...\n";
}

sub fileevent_read_line {
    if (eof(FH)) {
	$tracking = 0;
	kill_tail();
        $main::top->fileevent(\*FH, "readable", "");
	close FH;
        return;
    }
    my $line = <FH>;
    my(@d) = parse_line($line);
    if (@d) {
	push @accesslog_data, @d;
	eval {
	    my $s = Strassen->new_from_data_ref(\@accesslog_data);
	    $s->write("/tmp/x.bbd");
	    main::plot("str", $layer, -draw => 1, Filename => "/tmp/x.bbd");
	    $main::str_obj{$layer} = $s; # for LayerEditor
	    my $last = $s->get($s->count-1);
	    if ($last && $last->[Strassen::COORDS()]->[-1]) {
		main::mark_point
			(-point =>  join(",", main::transpose(split /,/, $last->[Strassen::COORDS()]->[-1])),
			 -dont_center => 1);
	    }
	};
	if ($@) {
	    main::status_message($@, "warn");
	}
    }
}

sub parse_line {
    my $line = shift;
    my $lastcoords;
    if ($line =~ m{GET\s+(?:/~eserte/bbbike/cgi/bbbike.cgi|/cgi-bin/bbbike\.cgi)\?(.*)\s+HTTP}) {
	my $query_string = $1;
	if ($query_string =~ m{coords=([^&; ]+)}) {
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
	    my $bbdline = "$routename [$date] " .
		_prepare_qs_dump(\$query_string) .
		    "\t" . $colors[$colors_i] . " $coords\n";
	    $colors_i++; $colors_i %= scalar @colors;

	    return ($bbdline);
	} else {
	    my(@bbdlines);
	    my %has;
	    for my $type (qw(start via ziel)) {
		if ($query_string =~ /${type}c=([^&; ]+)/) {
		    my $coords = uri_unescape(uri_unescape($1));
		    my $name = "$coords";
		    if ($type =~ /(?:start|ziel)/) {
			$has{$type}++;
		    }
		    if ($line =~ /${type}name=([^&; ]+)/) {
		        $name = uri_unescape(uri_unescape($1));
		    }
	            my $date = "???";
	            if ($line =~ m{(\d+/[a-z]+/\d+:\d+:\d+:\d+)}i) {
			$date = $1;
		    }
	            my $bbdlines = "$name [$date] " .
			_prepare_qs_dump(\$query_string) .
			    "\t" . $colors[$colors_i] . " $coords\n";
	            $colors_i++; $colors_i %= scalar @colors;
	            push @bbdlines, $bbdlines;
	        }
	    }
	    if ($do_search_route && $has{start} && $has{ziel}) {
		my $url = "$bbbike_cgi?output_as=perldump&" . uri_unescape($query_string);
		warn "Send URL $url...\n";
		my $resp = $ua->get($url);
		if ($resp->is_success && $resp->header("Content-Type") =~ m|^text/plain|) {
		    warn "... OK\n";
		    my $route = $safe->reval($resp->content);
		    if ($route) {
			my $coords = join(" ", @{ $route->{Path} });
			push @bbdlines, $route->{Route}[0]{Strname} . " - " . $route->{Route}[-1]{Strname} . " " . _prepare_qs_dump(\$query_string) . "\t" . $colors[$colors_i] . " " . $coords . "\n";
		    } else {
			warn "No route in response";
		    }
		} else {
		    warn $resp->error_as_HTML;
		}
	    }
            return @bbdlines;
        }
    }
    ();
}

sub pref_statistics {
    if (fork == 0) {
	open(AL, $logfile) or die $!;
	my %pref;
	while(<AL>) {
	    print STDERR "$. \r" if $.%1000 == 0;
	    if (/GET.*bbbike.cgi\?(.*) HTTP\//) {
		my $qs = $1;
		next if ($qs !~ /pref_/);
		my $q = CGI->new($qs);
		for my $key ($q->param) {
		    if ($key =~ /^pref_(.*)/) {
			$pref{$1}{$q->param($key)}++;
		    }
		}
	    }
	}
	close AL;
	require Data::Dumper;
	my $res = Data::Dumper->new([\%pref],[])->Sortkeys(1)->Indent(1)->Useqq(1)->Dump;
	warn $res;
	my $txt = $main::top->Toplevel->Scrolled("Text", -scrollbars => "oe")->pack;
	$txt->insert("end", $res);
	CORE::exit(0);
    }
}

sub _number_monthabbrev {
    my $mon = shift;
    +{'1' => 'Jan',
      '2' => 'Feb',
      '3' => 'Mar',
      '4' => 'Apr',
      '5' => 'May',
      '6' => 'Jun',
      '7' => 'Jul',
      '8' => 'Aug',
      '9' => 'Sep',
      '10' => 'Oct',
      '11' => 'Nov',
      '12' => 'Dec',
     }->{$mon};
}

sub _prepare_qs_dump {
    my $query_string_ref = shift;
    my $q = CGI->new($$query_string_ref);
    for (qw(coords interactive
	    startname startc startcharimg.x startcharimg.y startplz
	    startmapimg.x startmapimg.y
	    vianame viac viacharimg.x viacharimg.y viaplz
	    viamapimg.x viamapimg.y
	    zielname zielc zielcharimg.x zielcharimg.y zielplz
	    zielmapimg.x zielmapimg.y
	    windrichtung windstaerke)) {
	$q->delete($_);
    }
    my @p;
    for my $p ($q->param) {
	push @p, "$p=" . $q->param($p);
    }
    join(" ", @p);
}

return 1 if caller;

__END__

