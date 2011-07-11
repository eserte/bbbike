#
# LogTracker.pm
#
# -*- perl -*-

#
# $Id: LogTracker.pm,v 1.23 2009/01/10 10:23:06 eserte Exp $
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

BEGIN {
    *M    = \&BBBikePlugin::M;
    *Mfmt = \&BBBikePlugin::Mfmt;
}

use strict;
use vars qw($VERSION $lastcoords
            @types %layer @colors $colors_i %accesslog_data
	    $do_search_route %show
	    $error_checks $ua $safe
            $remoteuser $remotehost $logfile $ssh_cmd $tracking $tail_pid $bbbike_cgi
	    $last_parselog_call $session_dir_prefix
	   );
$VERSION = sprintf("%d.%02d", q$Revision: 1.23 $ =~ /(\d+)\.(\d+)/);

# XXX replace all %layer, %show etc. with @layer, @show...
use constant ROUTES => 0;
use constant MAPSERVER => 1;

use URI::Escape;
use Strassen::Core;
use CGI ();
use Storable qw(thaw);

$bbbike_cgi = "http://localhost/bbbike/cgi/bbbike.cgi"
    if !defined $bbbike_cgi;
$logfile = "/tmp/AccessLog"
    if !defined $logfile;
$show{routes} = 1
    if !defined $show{routes};
$show{mapserver} = 1
    if !defined $show{mapserver};
$ssh_cmd = "ssh"
    if !defined $ssh_cmd;
$session_dir_prefix = "/tmp/bbbike-sessions-1000-"
    if !defined $session_dir_prefix;

@types = qw(routes mapserver);

sub register {
    my(@plugin_args) = @_;
    # XXX %switch is a misnomer: it's actually no switch, but takes an argument
    my %switch = map {($_=>1)} qw(logfile remoteuser remotehost bbbike_cgi
				  error_checks ssh_cmd);
    for(my $i=0; $i<$#plugin_args; $i+=2) {
	my($k,$v) = @plugin_args[$i..$i+2];
	if    (exists $switch{$k}) {
	    no strict 'refs';
	    $ {$k} = $v;
	}
	elsif ($k eq 'tracking') { $tracking = $v; parse_tail_log() if $v } # XXX
	elsif ($k eq 'replay_route_search') {
	    $do_search_route = $v;
	    if ($do_search_route) {
		init_search_route();
	    }
	}
	elsif ($k eq 'show_routes') { $show{routes} = $v }
	elsif ($k eq 'show_mapserver') { $show{mapserver} = $v }
	else {
	    warn "Ignore unknown plugin parameter $k";
	}
    }
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
    BBBikePlugin::remove_menu_button(__PACKAGE__."_menu");
    delete $BBBikePlugin::plugins{$pkg};
}

sub add_button {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $mmf = $main::top->Subwidget("ModeMenuPluginFrame");
    return unless defined $mf;

    my $b;
    $b = $mf->Label
        (-text => "Log",
        );
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_on');
    $main::balloon->attach($b, -msg => "LogTracker")
        if $main::balloon;

    BBBikePlugin::place_menu_button
            ($mmf,
             [
              [Button => "Set preferences",
               -command => sub {
                   my $t = $main::top->Toplevel(-title => "LogTracker");
		   $t->gridColumnconfigure($_, -weight => 1) for 1; # don't expand col 0
                   require Tk::PathEntry;
		   my $e;
                   Tk::grid($t->Label(-text => "Logfile"),
                            $e = $t->PathEntry(-textvariable => \$logfile),
			    -sticky => "ew",
                           );
		   Tk::grid($t->Label(-text => "Remote SSH user"),
			    $e = $t->Entry(-textvariable => \$remoteuser),
			    -sticky => "ew",
                           );
		   Tk::grid($t->Label(-text => "Remote host"),
			    $e = $t->Entry(-textvariable => \$remotehost),
			    -sticky => "ew",
                           );
		   Tk::grid($t->Label(-text => "SSH command"),
			    $e = $t->Entry(-textvariable => \$ssh_cmd),
			    -sticky => "ew",
                           );
                   Tk::grid($t->Label(-text => "BBBike CGI"),
                            $t->PathEntry(-textvariable => \$bbbike_cgi),
			    -sticky => "ew",
                           );
		   my $return = sub {
		       stop_parse_tail_log();
		       warn "Stopped parsing log...\n";
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
		       init_search_route();
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
		       warn "Stopped parsing log...\n";
		   }
               }],
              [Checkbutton => "Error checks",
	       -variable => \$error_checks,
	      ],
	      '-',
              [Checkbutton => "Show bbbike routes",
	       -variable => \$show{routes},
	       -command => sub { update_view("routes") },
	      ],
              [Checkbutton => "Show mapserver tiles",
	       -variable => \$show{mapserver},
	       -command => sub { update_view("mapserver") },
	      ],
	      '-',
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
	      [Button => 'Complete AccessLog',
	       -command => sub {
		   parse_accesslog();
	       },
	      ],
	      [Button => 'Preference statistics',
	       -command => sub {
		   pref_statistics();
	       },
	      ],
	      '-',
	      [Button => 'New online tracking',
	       -command => sub {
		   setup_new_online_tracking();
	       },
	      ],
	      [Button => 'Stop new online tracking',
	       -command => sub {
		   stop_new_online_tracking();
	       },
	      ],
	      "-",
	      [Button => 'Replay accesslog',
	       -command => sub {
		   replay_accesslog();
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
	     __PACKAGE__."_menu",
	     -title => "Log Tracker",
            );
}

######################################################################

init();
init_gui() if caller;

sub init {
    $colors_i = 0;
    @colors = ('#000080', '#0000a0', '#0000c0', '#0000f0',
               '#0080f0', '#8000f0', '#6000c0', '#4000a0',
              );
    for my $l (@types) {
	$accesslog_data{$l} = [];
    }
}

sub init_gui {
    for my $l (@types) {
	$layer{$l} = main::next_free_layer();
	$main::layer_active_color{$layer{$l}} = 'red';
	$main::layer_post_enter_command{$layer{$l}} = sub {
	    $main::c->raise("current")
	};
	$main::layer_post_leave_command{$layer{$l}} = sub {
	    $main::c->lower("current", $layer{$l})
	};
	$main::occupied_layer{$layer{$l}} = 1;
	main::fix_stack_order($layer{$l});
    }
}

sub parse_accesslog {
    my $fh = shift;
    $last_parselog_call = ['parse_accesslog']; # XXX can't store $fh...
    for my $l (@types) {
	$accesslog_data{$l} = [];
    }
    if (!$fh) {
	$fh = _open_log();
    }
    my $error_txt = "";
    while(<$fh>) {
	chomp;
	my %d;
	eval {
	    ($d{routes}, $d{mapserver}) = parse_line($_);
	};
	if ($@) {
	    $error_txt .= $@;
	}
	for my $l (@types) {
	    push @{$accesslog_data{$l}}, @{$d{$l}} if @{$d{$l}};
	}
    }
    close $fh;
    draw_accesslog_data();
    show_errors($error_txt);
}

sub draw_accesslog_data {
    for my $l (@types) {
	if (@{ $accesslog_data{$l} }) {
	    my $s = Strassen->new_from_data_ref($accesslog_data{$l});
	    $s->write("/tmp/LogTracker-$l.bbd");
	    main::plot("str", $layer{$l},
		       -lazy => 0,
		       -draw => 1,
		       FastUpdate => 1,
		       Filename => "/tmp/LogTracker-$l.bbd");
	    $main::str_obj{$layer{$l}} = $s; # for LayerEditor
	}
    }
}

sub date_to_apachedate {
    my($y,$m,$d) = @_;
    $m = _number_monthabbrev($m);
    sprintf "%02d/%s/%04d", $d, $m, $y;
}

sub _today {
    eval {
	require Date::Pcalc;
	Date::Pcalc->import(qw(Today));
    };
    if ($@) {
	require Date::Calc;
	Date::Calc->import(qw(Today));
    };
    date_to_apachedate(Today());
}

sub _yesterday {
    eval {
	require Date::Pcalc;
	Date::Pcalc->import(qw(Today Add_Delta_Days));
    };
    if ($@) {
	require Date::Calc;
	Date::Calc->import(qw(Today Add_Delta_Days));
    }
    date_to_apachedate(Add_Delta_Days(Today(), -1));
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
    $last_parselog_call = ['parse_accesslog_any_day', $rx];
    for my $l (@types) {
	$accesslog_data{$l} = [];
    }
    my($bw, $is_tied) = _open_any_log();
    my $gather = 0;
    my $error_txt = "";
    while(<$bw>) {
	if (!$gather) {
	    if (index($_, $rx) != -1) {
		$gather = 1;
	    } else {
		next;
	    }
	}
	last if index($_, $rx) == -1;
	chomp;
	my %d;
	eval {
	    ($d{routes}, $d{mapserver}) = parse_line($_);
	};
	if ($@) {
	    $error_txt .= $@;
	}
	for my $l (@types) {
	    push @{$accesslog_data{$l}}, @{$d{$l}} if @{$d{$l}};
	}
    }
    untie *BW if $is_tied;
    draw_accesslog_data();
    show_errors($error_txt);
}

sub kill_tail {
    if (defined $tail_pid) {
	kill 9 => $tail_pid;
	undef $tail_pid;
    }
}

sub parse_tail_log {
    stop_parse_tail_log();
    $tail_pid = open FH, "-|";
    if (!$tail_pid) {
	_tail_log();
    };
    warn "Start parsing file $logfile " .
	(defined $remotehost && $remotehost ne '' ? "on $remotehost " : "") .
	    "...\n";
    _maybe_gunzip(\*FH);
    $tracking = 1;
    $main::top->fileevent(\*FH, "readable", \&fileevent_read_line);
}

sub stop_parse_tail_log {
    $tracking = 0;
    if (fileno(FH)) {
	$main::top->fileevent(\*FH, "readable", "");
	close FH;
    }
    kill_tail();
}

sub _tail_log {
    if (!defined $remotehost || $remotehost eq '') {
	exec "tail", "-f", $logfile;
	die $!;
    } else {
	my @ssh_cmd = _get_ssh_cmd();
	push @ssh_cmd, "tail", "-f", $logfile;
	exec @ssh_cmd;
	die $!;
    }
}

sub _get_coords_session {
    my($filename) = @_;
    my @ssh_cmd = _get_ssh_cmd();
    push @ssh_cmd, "cat", $filename;
    open my $fh, "-|", @ssh_cmd
	or die "Can't execute @ssh_cmd: $!";
    local $/ = undef;
    my $buf = <$fh>;
    eval { thaw $buf };
}

sub _get_ssh_cmd {
    my @ssh_cmd;
    if ($ssh_cmd =~ /\s+/) {
	@ssh_cmd = split /\s+/, $ssh_cmd;
    } else {
	@ssh_cmd = $ssh_cmd;
    }
    push @ssh_cmd, "-n", (defined $remoteuser && $remoteuser ne ""
			  ? ("-l", $remoteuser) : ()
			 ), $remotehost;
    @ssh_cmd;    
}

sub _open_any_log {
    my $bw;
    my $is_tied = 0;
    if ($logfile =~ /\.gz$/ || (defined $remotehost && $remotehost ne "")) {
	# Can't read backwards
	$bw = _open_log();
    } else {
	require File::ReadBackwards;
	tie *BW, 'File::ReadBackwards', $logfile
	    or main::status_message(Mfmt("Kann die Datei %s nicht öffnen: %s",
					 $logfile, $!), "die");
	$bw = \*BW;
	$is_tied++;
    }
    ($bw, $is_tied);
}

sub _open_log {
    my $fh;
    if (!defined $remotehost || $remotehost eq '') {
	open($fh, $logfile)
	    or main::status_message(Mfmt("Kann die Datei %s nicht öffnen: %s",
					 $logfile, $!), "die");
    } else {
	open($fh, "$ssh_cmd " . (defined $remoteuser && $remoteuser ne ""
			    ? "-l $remoteuser " : "")
	     . "$remotehost cat $logfile | ");
    }
    _maybe_gunzip($fh);
    $fh;
}

sub fileevent_read_line {
    if (eof(FH)) {
	$tracking = 0;
	stop_parse_tail_log();
        return;
    }
#XXXXXXXXXXX Blocks on FreeBSD?!
#warn "about to read line...";
#     my $line = "";
#     while(sysread(FH, $line, 1, length($line)) == 1) {
# 	last if $line =~ /\n\z/;
#     }
    my $line = <FH>;
#warn "ok...";
    my %d;
    eval {
	($d{routes}, $d{mapserver}) = parse_line($line);
    };
    if ($@) {
	show_errors($@);
    }
    for my $l (@types) {
	if ($d{$l} && @{$d{$l}}) {
	    push @{$accesslog_data{$l}}, @{$d{$l}};
	    eval {
		my $s = Strassen->new_from_data_ref($accesslog_data{$l});
		$s->write("/tmp/LogTracker-$l.bbd");
		main::plot("str", $layer{$l}, -draw => 1,
			   -lazy => 0,
			   FastUpdate => 1,
			   Filename => "/tmp/LogTracker-$l.bbd");
		$main::str_obj{$layer{$l}} = $s; # for LayerEditor
		my $last = $s->get($s->count-1);
		if ($last && $last->[Strassen::COORDS()]->[-1]) {
		    main::mark_street
			    (-coords => [[ map { main::transpose(split /,/, $_) } @{$last->[Strassen::COORDS()]} ]],
			     -dont_center => 1);
		}
	    };
	    if ($@) {
		main::status_message($@, "warn");
	    }
	}
    }
}

sub parse_line {
    my $line = shift;
    my $lastcoords;
    if ($show{routes} &&
	$line =~ m{GET\s+
		   (?:
		    /~eserte/bbbike/cgi/bbbike\.cgi |
		    /cgi-bin/bbbike\.cgi            |
		    /bbbike/cgi/bbbike\.cgi
		   )\?(.*)\s+HTTP[^"]+"\s(\d+)}x
       ) {
	my $query_string = $1;
	my $status_code = $2;
	if ($error_checks && $status_code =~ /^[45]/) {
	    die "Status $status_code $line\n";
	}

	my $date = "???";
	my $tz_add;
	if ($line =~ m{(\d+/[a-z]+/\d+:\d+:\d+:\d+)(\s+(?:[+-])?\d{2}\d{2})}i) {
	    $date = $1;
	    $tz_add = $2;
	}

	my $coords;
	if ($query_string =~ m{coords=([^&; ]+)}) {
	    $coords = uri_unescape(uri_unescape($1));
	} elsif ($query_string =~ m{coordssession=([^&; ]+)}) {
	    my $coords_session = uri_unescape($1); # XXX twice?
	    my($sess1,$sess2) = split /_/, $coords_session;
	    $sess1 =~ s{^:}{};
	    my $time = apache2epoch("$date$tz_add");
	    my @l = localtime $time;
	    $l[4]++;
	    $l[5]+=1900;
	    my $session_file = $session_dir_prefix . sprintf("%04d-%02d-%02d", @l[5,4,3]) . "/$sess1";
	    my $session = _get_coords_session($session_file);
	    if (!$session) {
		warn "Cannot get session from $session_file, skipping";
	    } else {
		$coords = $session->{routestringrep} || undef;
	    }
	}

	if (defined $coords) {
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
		return ([],[]);
	    }
	    if ($coords =~ /^\s*$/) {
		return ([],[]);
	    }
	    $lastcoords = $coords;
	    my $bbdline = "$routename [$date] " .
		_prepare_qs_dump(\$query_string) .
		    "\t" . $colors[$colors_i] . " $coords\n";
	    $colors_i++; $colors_i %= scalar @colors;

	    return ([$bbdline],[]);
	} else {
	    my(@bbdlines);
	    my %has;
	    for my $type (qw(start via ziel)) {
		if ($query_string =~ /${type}c=([^&; ]+)/) {
		    my $coords = uri_unescape(uri_unescape($1));
		    next if $coords =~ /^\s*$/;
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
            return (\@bbdlines,[]);
        }
    }

    elsif ($show{mapserver} &&
	   $line =~ m{GET\s+
		      (?:
		       /~eserte/cgi/mapserv\.cgi |
		       /cgi-bin/mapserv
		      )\?(.*)\s+HTTP[^"]+"\s(\d+)}x
		     ) {
	my $query_string = $1;
	my $status_code = $2;
	if ($error_checks && $status_code =~ /^[45]/) {
	    die "Status $status_code $line\n";
	}
#XXX zZt wird immer der *letzte* Quadrant dargestellt. Der *nächste* berechnet sich aus imgext, zoomdir, usw.
	if ($query_string =~ /imgext=([\d\.\+\- ]+)/) {
	    my $imgext = $1;
	    $imgext =~ s/\+/ /g;
	    my @imgext = map { int } split /\s+/, uri_unescape($imgext);
	    my $coords;
	    {
		local $" = ",";
		$coords = "@imgext[0,1] @imgext[2,1] @imgext[2,3] @imgext[0,3] @imgext[0,1]";
	    }

	    my $date = "???";
	    if ($line =~ m{(\d+/[a-z]+/\d+:\d+:\d+:\d+)}i) {
		$date = $1;
	    }

	    my $bbdline = "Mapserver [$date] " .
		_prepare_ms_qs_dump(\$query_string) .
		    "\t" . $colors[$colors_i] . " $coords\n";
	    $colors_i++; $colors_i %= scalar @colors;
	    return ([],[$bbdline]);
	}
    }

    # else { warn "Can't match <$line>\n" }
    ([],[]);
}

sub pref_statistics {
    pipe(RDR,WTR);
    if (fork == 0) {
	close RDR;
	open(AL, $logfile)
	    or do {
		print WTR Mfmt("Kann die Datei %s nicht öffnen: %s",
			       $logfile, $!);
		close WTR;
		CORE::exit(1);
	    };

	my %pref;
	my $pref_count = 0;
	my %image;
	my $image_count = 0;
	my %first_appearance;

	while(<AL>) {
	    print STDERR "$. \r" if $.%1000 == 0;
	    if (/GET.*bbbike.cgi\?(.*) HTTP\//) {
		my $qs = $1;
		if ($qs =~ /pref_/) {
		    $pref_count++;
		    my $q = CGI->new($qs);
		    for my $key ($q->param) {
			if ($key =~ /^pref_(.*)/) {
			    my $key_stripped = $1;
			    my $val = $q->param($key);
			    $pref{$key_stripped}{$val}++;
			    if (!exists $first_appearance{$key_stripped}) {
				$first_appearance{$key_stripped}{$val} = $pref_count;
			    }
			}
		    }
		} elsif ($qs =~ /imagetype/) {
		    $image_count++;
		    my $q = CGI->new($qs);
		    for my $key ($q->param) {
			if ($key =~ /^(imagetype|scope|geometry|outputtarget)$/) {
			    my $val = $q->param($key);
			    $image{$key}{$val}++;
			    $first_appearance{$key}{$val} = $image_count
				if !exists $first_appearance{$key}{$val};
			} elsif ($key eq 'draw') {
			    for my $val ($q->param($key)) {
				$image{$key}{$val}++;
				$first_appearance{$key}{$val} = $image_count
				    if !exists $first_appearance{$key}{$val};
			    }
			}
		    }
		}
	    }
	}
	close AL;

	if ($pref_count) {
	    while(my($k,$v) = each %pref) {
		while(my($val,$count) = each %$v) {
		    my $since_first_appearance = $pref_count-$first_appearance{$k}{$val}+1;
		    $v->{$val} = [$count,
				  sprintf("%.1f%%", 100*$count/$pref_count),
				  sprintf("%.1f%% ($since_first_appearance)", 100*$count/($since_first_appearance)),
				 ];
		}
	    }
	}
	if ($image_count) {
	    while(my($k,$v) = each %image) {
		while(my($val,$count) = each %$v) {
		    my $since_first_appearance = $image_count-$first_appearance{$k}{$val}+1;
		    $v->{$val} = [$count,
				  sprintf("%.1f%%", 100*$count/$image_count),
				  sprintf("%.1f%% ($since_first_appearance)", 100*$count/($since_first_appearance)),
				 ];
		}
	    }
	}

	my $res;
	if (eval { require YAML; 1 }) {
	    local $YAML::UseHeader = 0;
	    local $YAML::Indent = 8;
	    $res = "Preferences:\n" . YAML::Dump(\%pref) .
		"\nImage:\n" . YAML::Dump(\%image);
	} else {
	    require Data::Dumper;
	    $res = Data::Dumper->new([\%pref],[])
		->Sortkeys(sub { [ sort { $a <=> $b } keys %{$_[0]} ] } )
		    ->Indent(1)->Useqq(1)->Dump;
	}
	warn $res;
	print WTR $res, "\n";
	close WTR;
	CORE::exit(0);
    }
    close WTR;

    my $t = $main::top->Toplevel;
    $t->title("Preference statistics");
    my $txt = $t->Scrolled("ROText", -scrollbars => "oe"
			  )->pack(-expand => 1,
				  -fill => "both");
    $t->fileevent
	(\*RDR, "readable", sub {
	     if (eof(RDR)) {
		 $t->fileevent(\*RDR, "readable", "") if Tk::Exists($t);
		 close RDR;
		 return;
	     }
	     my $line = <RDR>;
	     $txt->insert("end", $line) if Tk::Exists($txt);
	 });
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

sub _prepare_ms_qs_dump {
    my $query_string_ref = shift;
    my $q = CGI->new($$query_string_ref);
    for (qw(map mode zoomdir zoomsize orig_mode orig_zoomdir imgxy
	    imgext savequery program bbbikeurl bbbikemail startc coordset
	    img.x img.y ref.x ref.y)) {
	$q->delete($_);
    }
    my @p;
    for my $p ($q->param) {
	push @p, "$p=" . join(",",$q->param($p));
    }
    join(" ", @p);
}

sub _maybe_gunzip {
    my $fh = shift;
    if (eval { require PerlIO::gzip }) {
	binmode $fh, ":gzip(autopop)";
    } else {
	warn "Harmless for normal files: $@";
    }
}

sub init_search_route {
    if (!$ua) {
	require LWP::UserAgent;
	require Safe;
	$ua = LWP::UserAgent->new;
	$safe = Safe->new;
    }
}

sub show_errors {
    my $errors = shift;
    return if !defined $errors || $errors eq '';
    my $winname = "LogTracker-errors";
    my $t = main::redisplay_top($main::top, $winname, -title => "Errors");
    my $txt;
    if (!defined $t) {
	$txt = $main::toplevel{$winname}->Subwidget("Log");
	$txt->insert("end", ("-"x70) . "\n");
    } else {
	require Tk::ROText;
	$txt = $t->Scrolled("ROText", -scrollbars => "eos"
			   )->pack(-fill => "both", -expand => 1);
	$t->Advertise(Log => $txt);
    }
    $txt->insert("end", $errors);
}

sub update_view {
    my $l = shift;
warn "update $l";
    if ($main::c->find(withtag => $layer{$l})) {
	$main::c->itemconfigure($layer{$l}, -state => $show{$l} ? "normal" : "hidden");
    } elsif ($show{$l}) {
	if ($last_parselog_call) {
	    local(%show) = %show;
	    for (@types) {
		$show{$_} = 0 if $_ ne $l;
	    }
	    require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$last_parselog_call, \%show],[])->Indent(1)->Useqq(1)->Dump; # XXX

	    my $sub = shift @$last_parselog_call;
	    no strict 'refs';
	    &{$sub}(@$last_parselog_call);
	} else {
	    warn "Can't draw $l, no last_parselog_call variable set";
	}
    }
}

sub percent_over_airdist {
    my $r = shift;
    require Strassen::Util;
    my $c = $r->[Strassen::COORDS()];
    return undef if @$c < 2;
    my $dist = 0;
    for my $i (1 .. $#$c) {
	$dist += Strassen::Util::strecke_s($c->[$i-1], $c->[$i]);
    }
    my $air_dist = Strassen::Util::strecke_s($c->[0], $c->[-1]);
    return undef if !$air_dist;
    my $perc = $dist/$air_dist*100;
    return $perc;
}

# Can be called from command line:
sub worst_routes_of_the_day {
    my @worstof;
    my %seen;
    require Strassen::Core;
    require Strassen::Util;
    require Term::Cap;
    my $terminal = Tgetent Term::Cap { TERM => undef, OSPEED => 9600 };
    my $clear = $terminal->Tputs("cl");
    my $rows = 23;
    # old: $logfile = "$ENV{HOME}/www/log/radzeit.de-access_log";
    $logfile = "$ENV{HOME}/www/log/radzeit.combined_log";
    my($bw, $is_tied) = _open_any_log();
    my $today = _today();
    my $today_rx = qr{\Q$today};
 LOOP: while(<$bw>) {
	my($routes, undef) = parse_line($_);
	next unless @$routes;
	for my $route (@$routes) {
	    my($r) = Strassen::parse($route);
	    next if $r->[Strassen::NAME()] =~ /^\s*$/;
	    last LOOP if $r->[Strassen::NAME()] !~ $today_rx;
	    my $perc = percent_over_airdist($r);
	    next if !defined $perc;
	    my $c = $r->[Strassen::COORDS()];
	    my $ident = "$perc $c->[0] $c->[-1]";
	    if (!$seen{$ident} && (!@worstof || $perc > $worstof[-1]->[0])) {
	    TRY: {
		    $seen{$ident} = 1;
		    for my $inx (0 .. $#worstof) {
			if ($perc > $worstof[$inx]->[0]) {
			    splice @worstof, $inx, 0, [$perc, $r];
			    last TRY;
			}
		    }
		    push @worstof, [$perc, $r];
		}
		splice @worstof, $rows;
		print $clear;
		for (@worstof) {
		    (my $name = $_->[1][Strassen::NAME()]) =~ s/\[.*//;
		    my $c = $_->[1][Strassen::COORDS()];
		    $name = "$c->[0] $c->[-1] $name";
		    $name = substr($name,0,70) if length $name > 70;
		    printf "%3d%% %s\n", $_->[0], $name;
		}
	    }
	}
    }
    untie *BW if $is_tied;
}

######################################################################
# New tracker XXX currently only a hack

use vars qw($SETUP_NEW_ONLINE_TRACKING_TEST $LOG_TRACKER_SSH $LOG_TRACKER_FH);
$SETUP_NEW_ONLINE_TRACKING_TEST=0;

sub setup_new_online_tracking {
    if ($LOG_TRACKER_SSH) {
	stop_online_tracking();
    }
    require Net::OpenSSH;
    $LOG_TRACKER_SSH = Net::OpenSSH->new(
					 $SETUP_NEW_ONLINE_TRACKING_TEST ? 'localhost' : 'bbbike.de',
					 master_stdout_discard => 1, # does not work together with ptksh
					 master_stderr_discard => 1,
					);
    $LOG_TRACKER_SSH->error
	and die "Couldn't establish SSH connection: " . $LOG_TRACKER_SSH->error;
    ($LOG_TRACKER_FH, my($pid)) = $LOG_TRACKER_SSH->pipe_out($SETUP_NEW_ONLINE_TRACKING_TEST
							     ? 'echo "/tmp/coordssession/ CLOSE_WRITE,CLOSE 01000000_0aa6e7661e8cfe43"'
							     : 'inotifywait -m -e close_write /tmp/coordssession'
							    )
	or die "pipe out failed: " . $LOG_TRACKER_SSH->error;
    $main::top->fileevent($LOG_TRACKER_FH, 'readable', sub { new_online_tracking() });
}

sub stop_new_online_tracking {
    if ($LOG_TRACKER_FH) {
	$main::top->fileevent($LOG_TRACKER_FH, 'readable', '');
	close $LOG_TRACKER_FH;
    }
    undef $LOG_TRACKER_FH;
    undef $LOG_TRACKER_SSH;
}

sub new_online_tracking {
    my($fh,$ssh) = ($LOG_TRACKER_FH, $LOG_TRACKER_SSH);
    if (eof($fh)) {
	stop_new_online_tracking();
	main::status_message('Stopped tracker...', 'infodlg');
	return;
    }
    chomp(my $inotify_line = <$fh>);
    my(undef,undef,$session_file) = split /\s+/, $inotify_line, 3;
    $ssh->scp_get({}, "/tmp/coordssession/$session_file", "/tmp/remote_session_file");
    open my $ifh, "-|", "$FindBin::RealBin/miscsrc/coordssession2bbd", "-allow-test", "/tmp/remote_session_file"
	or die $!;
    open my $ofh, ">>", '/tmp/LogTracker2.bbd'
	or die $!;
    if (tell($ofh) == 0) { # new file?
	print $ofh <<'EOF';
#: category_color.X: blue
#:
EOF
    }
    while(<$ifh>) {
	print $ofh $_;
    }
    close $ofh or die $!;
    close $ifh;

    my $s = Strassen->new('/tmp/LogTracker2.bbd');
    main::plot("str", $layer{routes}, -draw => 1,
	       -lazy => 0,
	       FastUpdate => 1,
	       Filename => "/tmp/LogTracker2.bbd");
    $main::str_obj{$layer{routes}} = $s; # for LayerEditor
    my $last = $s->get($s->count-1);
    if ($last && $last->[Strassen::COORDS()]->[-1]) {
	main::mark_street
		(-coords => [[ map { main::transpose(split /,/, $_) } @{$last->[Strassen::COORDS()]} ]],
		 -dont_center => 1);
    }
}

sub replay_accesslog {
    my $file = $main::top->getOpenFile;
    return if !defined $file;
    open my $fh, $file
	or main::status_message("Can't open $file: $!", 'die');
    # convert to inotifywait-styled file
    require File::Temp;
    my($ofh,$ofile) = File::Temp::tempfile(SUFFIX => "_inotify.log", UNLINK => 1)
	or main::status_message("Can't create temporary file: $!", 'die');
    my $found_lines = 0;
    while(<$fh>) {
	if (m{coordssession=([^& ]+)}) {
	    print $ofh "/tmp/coordssession/ CLOSE_WRITE,CLOSE $1\n";
	    $found_lines++;
	}
    }
    close $fh;
    close $ofh
	or main::status_message("Problem while writing $ofile: $!");
    $found_lines
	or do {
	    main::status_message("No coordssession lines found in logfile", "warn");
	    return;
	};

    open $LOG_TRACKER_FH, $ofile
	or main::status_message("Can't open temporary file $ofile: $!", 'die');

    if ($LOG_TRACKER_SSH) {
	stop_online_tracking();
    }
    require Net::OpenSSH;
    $LOG_TRACKER_SSH = Net::OpenSSH->new(
					 $SETUP_NEW_ONLINE_TRACKING_TEST ? 'localhost' : 'bbbike.de',
					 master_stdout_discard => 1, # does not work together with ptksh
					 master_stderr_discard => 1,
					);
    $LOG_TRACKER_SSH->error
	and die "Couldn't establish SSH connection: " . $LOG_TRACKER_SSH->error;
    $main::top->fileevent($LOG_TRACKER_FH, 'readable', sub { new_online_tracking() });
}

######################################################################
# REPO BEGIN
# REPO NAME apache2epoch /home/e/eserte/work/srezic-repository 
# REPO MD5 e3d19a71595fe57b8b1200c8fd1cc60d

=head2 apache2epoch($time)

=for category Date

Given an apache accesslog date/time (21/Jul/2003:21:30:19 +0200)
return a Unix epoch time. Return undef if not parseable.

=cut

sub apache2epoch {
    my $str = shift;
    my($d,$m,$y,$H,$M,$S,$tzsig,$tzh,$tzm) = $str =~ m[(\d{1,2})/(...)/(\d{4}):(\d{2}):(\d{2}):(\d{2})\s+([+-])?(\d{2})(\d{2})];
    if (defined $d) {
	$m = {qw(Jan 0 Feb 1 Mar 2 Apr 3 May 4 Jun 5
		 Jul 6 Aug 7 Sep 8 Oct 9 Nov 10 Dec 11)}->{$m};
	require Time::Local;
	my $tz_offset = $tzm*60 + $tzh*3600;
	$tz_offset *= -1 if $tzsig eq '-';
	my $epoch = Time::Local::timegm($S,$M,$H,$d,$m,$y);
	$epoch -= $tz_offset;
	$epoch;
    } else {
	undef;
    }
}
# REPO END

END {
    stop_parse_tail_log();
}

return 1 if caller;

require Getopt::Long;
Getopt::Long::GetOptions("worstroutes" => sub { worst_routes_of_the_day() }) or die;

__END__

