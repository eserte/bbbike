# -*- perl -*-

#
# $Id: BBBikeAlarm.pm,v 1.24 2003/05/30 21:31:20 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package BBBikeAlarm;

# XXX sollte ich evtl. verwenden für die Liste der Alarme:
# XXX http://reefknot.sourceforge.net/
# XXX Date::ICal, Net::ICal

use FindBin;
use vars qw($VERSION
	    $can_leave $can_at $can_tk $can_palm $can_s25_ipaq $can_ical
	    $alarms_file);
use strict;
use lib "$FindBin::RealBin/lib";

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

# XXX
my $install_datebook_additions = 1;

use Time::Local;

$VERSION = sprintf("%d.%02d", q$Revision: 1.24 $ =~ /(\d+)\.(\d+)/);

# XXX S25 Termin (???)
# XXX Terminal-Alarm unter Windows? Linux?
# XXX Leave funktioniert nur für max. 12 Stunden (testen!)

sub enter_alarm {
    my($top, $time_ref, %args) = @_;
    my $time = $$time_ref;
    if ($time =~ /(\d+):(\d+)/) {
	my($h,$m) = ($1,$2);
	my $t = $top->Toplevel(-title => "Alarm");
	$t->transient($top) if $main::transient;
	my $do_close = 0;

	# XXX Tk::Date verwenden?
	my $ankunft;
	my $ankunft_epoch;
	my $abfahrt_epoch;
	my $pre_alarm_seconds;
	my $end_zeit_epoch;
	my $vorbereitung = "00:10"; # XXX BBBike-Option
	my $vorbereitung_s;
	my $text = "";
	$text = main::get_route_description()
	    if defined &main::get_route_description;

	$t->Label(-text => M("Ankunft").":")->grid(-row => 0, -column => 0,
					     -sticky => "e");
	my $sunset_choice;
	my $om;
	my $e = $t->Entry(-textvariable => \$ankunft,
			  -width => 6,
			 )->grid(-row => 0, -column => 1,
				 -sticky => "w");
	$e->focus;
	if (defined $args{-location} && eval { require Astro::Sunrise; 1 }) {
	    my($px,$py) = (ref $args{-location} eq 'ARRAY'
			   ? @{ $args{-location} }
			   : split /,/, $args{-location}
			  );
	    my $get_sun_set = sub {
		my $alt = shift;
		Astro::Sunrise::sun_set($px,$py, $alt);
	    };
	    my $sunset_real      = $get_sun_set->();
	    my $sunset_civil     = $get_sun_set->(-6);
	    $om = $t->Optionmenu
		(-variable => \$sunset_choice,
		 -options => [["" => ""],
			      ["Sonnenuntergang" => $sunset_real],
			      ["Ende der bürgerl. Dämmerung" => $sunset_civil],
			     ],
		 -command => sub {
		     $ankunft = $sunset_choice
			 if $sunset_choice ne "";
		 },
		)->grid(-row => 0, -column => 2);
	}

	$t->Label(-text => M("Abfahrt").":")->grid(-row => 1, -column => 0,
					     -sticky => "e");
	my $ab_l = $t->Label->grid(-row => 1, -column => 1,
				   -sticky => "w");

	$t->Label(-text => M("Vorbereitung").":")->grid(-row => 2, -column => 0,
						  -sticky => "e");
	my $vb_e = $t->Entry(-textvariable => \$vorbereitung,
			     -width => 6,
			    )->grid(-row => 2, -column => 1,
				    -sticky => "w");

	$t->Label(-text => M("Alarmtext").":")->grid(-row => 3, -column => 0,
					       -sticky => "e");
	$t->Entry(-textvariable => \$text,
		 )->grid(-row => 3, -column => 1, -sticky => "w");

	my $get_end_zeit = sub {
	    my $check_errors = shift;
	    return undef if !defined $ankunft || $ankunft eq "";
	    if (!defined $vorbereitung || $vorbereitung eq "") {
		$vorbereitung = "00:00";
	    }

	    my($h_a, $m_a) = $ankunft =~ /(\d{1,2})[:.](\d{2})/;
	    if (!defined $h_a || !defined $m_a) {
		if ($check_errors) {
		    $top->messageBox(-message => "Wrong time format (ankunft)",
				     -icon => "error",
				     -type => "OK");
		}
		return undef;
	    }

	    my($h_vb, $m_vb) = $vorbereitung =~ /(\d{1,2})[:.](\d{2})/;
	    $vorbereitung_s = 0;
	    if (defined $h_vb && defined $m_vb) {
		$vorbereitung_s = $h_vb*60*60 + $m_vb*60;
	    }

	    my @l = localtime;
	    $l[1] = $m_a;
	    $l[2] = $h_a;
	    $ankunft_epoch = timelocal(@l);
	    if ($ankunft_epoch <= time) {
		# adjust to next day
		$ankunft_epoch+=86400; # XXX Sommerzeit
	    }

	    my $fahrzeit = $h*60*60 + $m*60;
	    $pre_alarm_seconds = $fahrzeit + $vorbereitung_s;
	    $abfahrt_epoch = $ankunft_epoch - $fahrzeit;
	    $end_zeit_epoch = $ankunft_epoch - $pre_alarm_seconds;
	    # XXX Abzug vorbereitung?
	    @l = localtime $end_zeit_epoch;
	    my $end_zeit = sprintf("%02d%02d", $l[2], $l[1]);

	    $ab_l->configure(-text => sprintf("%02d:%02d", $l[2], $l[1]));
	    return $end_zeit;
	};

	if ($Tk::VERSION > 800.016) { # XXX ca. for -validation
	    foreach my $w ($e, $vb_e) {
		$w->configure
		    (-vcmd =>
		     sub {
			 my $adjust_subset_choice = 1
			     if ($_[4] == 0 || $_[4] == 1) && $w eq $e; # INSERT or DELETE
			 $w->after(10, sub {
					 $get_end_zeit->(0);
					 if ($adjust_subset_choice) {
					     $sunset_choice = "";
					     $om->setOption("","");
					 }
				     });
			 1;
		     },
		     -validate => "all");
	    }
	}

	my $row = 4;

	capabilities();

	my($use_tk, $use_leave, $use_palm, $use_s25_ipaq, $use_at, $use_ical);
	if ($can_tk) {
	    $use_tk = 1;
	} elsif ($can_leave) {
	    $use_leave = 1;
	} elsif ($can_at) {
	    $use_at = 1;
	} elsif ($can_palm) {
	    $use_palm = 1;
	} elsif ($can_s25_ipaq) {
	    $use_s25_ipaq = 1;
	} elsif ($can_ical) {
	    $use_ical = 1;
	}

	if ($can_tk) {
	    $t->Checkbutton(-text => "Tk",
			    -variable => \$use_tk)->grid(-row => $row++,
							 -column => 0,
							 -columnspan => 2,
							 -sticky => "w");
	} else {
	    $use_tk = 0;
	}

	if ($can_leave) {
	    $t->Checkbutton(-text => "Console (leave)",
			    -variable => \$use_leave)->grid(-row => $row++,
							    -column => 0,
							    -columnspan => 2,
							    -sticky => "w");
	} else {
	    $use_leave = 0;
	}

	if ($can_at) {
	    $t->Checkbutton(-text => "Console (at)",
			    -variable => \$use_at)->grid(-row => $row++,
							 -column => 0,
							 -columnspan => 2,
							 -sticky => "w");
	} else {
	    $use_at = 0;
	}

	if ($can_palm) {
	    $t->Checkbutton(-text => "Palm",
			    -variable => \$use_palm)->grid(-row => $row++,
							   -column => 0,
							   -columnspan => 2,
							   -sticky => "w");
	} else {
	    $use_palm = 0;
	}

	if ($can_s25_ipaq) {
	    $t->Checkbutton(-text => "S25 via iPAQ",
			    -variable => \$use_s25_ipaq)->grid(-row => $row++,
							       -column => 0,
							       -columnspan => 2,
							       -sticky => "w");
	} else {
	    $use_s25_ipaq = 0;
	}

	if ($can_ical) {
	    $t->Checkbutton(-text => "ical",
			    -variable => \$use_ical)->grid(-row => $row++,
							   -column => 0,
							   -columnspan => 2,
							   -sticky => "w");
	} else {
	    $use_ical = 0;
	}

	my $f = $t->Frame->grid(-row => $row++, -column => 0,
				-columnspan => 2, -sticky => "ew");
	$f->Button(-text => M"Alarm setzen",
		   -command => sub {
		       my $end_zeit = $get_end_zeit->(1);
		       return if !defined $end_zeit;

		       tk_leave($end_zeit, -text => $text)
			   if $use_tk;
		       grabbing_leave($end_zeit, -text => $text)
			   if $use_leave;
		       grabbing_at($end_zeit, -text => $text)
			   if $use_at;
		       palm_leave($ankunft_epoch, $pre_alarm_seconds,
				  -text => $text)
			   if $use_palm;
		       s25_ipaq_leave($ankunft_epoch, $pre_alarm_seconds)
			   if $use_s25_ipaq;
		       add_ical_entry($abfahrt_epoch, $text, -prealarm => $vorbereitung_s)
			   if $use_ical;
		       $do_close = 1;
		       $t->destroy;
		   })->pack(-side => "left", -fill => "x", -expand => 1);
	$f->Button(Name => "close",
		   -command => sub {
		       $do_close = 1;
		       $t->destroy;
		   })->pack(-side => "left", -fill => "x", -expand => 1);

	if ($args{-dialog}) {
	    $t->waitVariable(\$do_close);
	}
    }
}

sub get_all_terms {
    my @tty;
    my $who_am_i = (getpwuid($<))[0];
    open(WHO, "who|");
    while(<WHO>) {
	chomp;
	my($user, $tty) = split /\s+/;
	if ($user eq $who_am_i) {
	    push @tty, "/dev/$tty"; # XXX use _PATH_DEV
	}
    }
    close WHO;
    @tty;
}

sub grabbing_leave {
    my($time, %args) = @_;
    # -text is ignored in leave
    my @tty = get_all_terms();
    if (!@tty) {
	die "No tty found for current user!";
    }
    system("leave $time | tee @tty &");
}

sub grabbing_at {
    my($time, %args) = @_;
    # -text is ignored in leave
    my $text = $args{-text} || "Alarm!";
    $time = substr($time,0,2) . ":" . substr($time,2,2);
    my @tty = get_all_terms();
    if (!@tty) {
	die "No tty found for current user!";
    }
    system(qq{echo 'echo "$time: $text" | tee @tty' | at $time});
}

sub tk_leave {
    my($time, %args) = @_;
    my $end_time = end_time($time);
    my $text = $args{-text};
    $text = "Leave" if $text eq "";
    $text =~ s/[\"\\]//g; # XXX quote properly
    bg_system("$^X $FindBin::RealBin/BBBikeAlarm.pm -tk -time $end_time -text \"$text\"");
}

sub palm_leave {
    return unless $main::cabulja;
    my($ankunft_epoch, $pre_alarm_seconds, %args) = @_;
    my $tmpdir = $main::tmpdir;
    $tmpdir = "/tmp" if !defined $tmpdir || !-d $tmpdir;
    my $leave_file = "$tmpdir/BBBikeAlarm.txt";

    my(@begin) = localtime $ankunft_epoch;
    my(@end)   = localtime $ankunft_epoch + 60*60; # 1 hour default length
    my $alarm_min = $pre_alarm_seconds/60;

    my $now = time;
    my $gm_offset = $now - timelocal(gmtime $now);
    my $gm_offset_h = int($gm_offset/3600);
    if ($gm_offset_h >= 0) {
	$gm_offset_h = "+" . $gm_offset_h;
    }
    my $gm_offset_m = ($gm_offset/60)%60;
    $gm_offset_m = sprintf "%02d", $gm_offset_m;

    my $time_format = "%04d/%02d/%02d %02d:%02d:%02d GMT" . $gm_offset_h . $gm_offset_m;

    $begin[4]++;
    $begin[5]+=1900;
    my $begin = sprintf($time_format, @begin[5,4,3,2,1,0]);

    $end[4]++;
    $end[5]+=1900;
    my $end = sprintf($time_format, @end[5,4,3,2,1,0]);

    my $text = "BBBike datebook entry";
    $text = $args{-text} if $args{-text} ne "";
    open(F, ">$leave_file") or die "Can't write to $leave_file: $!";
    print F "$begin\t$end\t" . $alarm_min . "m\t$text";
    if ($install_datebook_additions && defined &main::get_act_search_route) {
	print F "\t";
	print F join(" - ", map {
	    $_->[0] . {"l" => " - links",
		       "r" => " - rechts" ,
		       ""  => ""}->{$_->[3]}
	} @{ main::get_act_search_route() });
    }
    print F "\n";
    close F;

    # pilot-xfer 0.9.3's install-datebook is buggy!!!!
    # use fixed executable XXX

    require BBBikePalm;
    if (-x "/usr/local/src/pilot-link.0.9.3/install-datebook") {
	# XXX kill old processes...
	system("killall", "install-datebook");
	system("/usr/local/src/pilot-link.0.9.3/install-datebook $ENV{PILOTPORT} $leave_file &");
	#    system("install-datebook", $ENV{PILOTPORT}, $leave_file);#&
	BBBikePalm::hot_sync_message($main::top);
    } else {
	warn "Sorry, no patched install-datebook on your system...";
    }
    unlink $leave_file;
}

sub s25_ipaq_leave {
    # A lot of prerequisites are needed:
    # - a working ppp connection to the ipaq
    # - ipaq named "ipaq" in /etc/hosts
    # - ssh connection to the ipaq possible
    # - scmxx installed on the ipaq
    return unless $main::cabulja;
    my($ankunft_epoch, $pre_alarm_seconds, %args) = @_;

    require POSIX;
    my $dtstart = POSIX::strftime("%Y%m%dT%H%M%S", localtime $ankunft_epoch-$pre_alarm_seconds);

    my $descr = "BBBike";
    if (defined &main::get_act_search_route) {
	my @search_route = @{ main::get_act_search_route() };
	$descr = $search_route[-1][StrassenNetz::ROUTE_NAME()];
    }

    my $ical_file = "/tmp/s25_cal.ical";
    #my $cat = "MISCELLANEOUS";
    my $cat = "MEETING";

    # create ical file on the ipaq
    open(CAT, '| ssh -l root ipaq "cat > ' . $ical_file . '"');
    print CAT <<EOF;
BEGIN:VCALENDAR
VERSION:1.0
BEGIN:VEVENT
CATEGORIES:$cat
DALARM:$dtstart
DTSTART:$dtstart
DESCRIPTION:$descr
END:VEVENT
END:VCALENDAR
EOF
    close CAT;

    # now send the ical file to the s25
    my $enable_irda = 'ifconfig irda0 up ; echo 1 > /proc/sys/net/irda/discovery';
    my $disable_irda = 'ifconfig irda0 down ; echo 0 > /proc/sys/net/irda/discovery';
    my $ssh_cmd = $enable_irda.'; scmxx -f ' . $ical_file . ' -s -C; '.$disable_irda;
    warn "Send cmd $ssh_cmd to ipaq...\n";
    if (fork == 0) { # fork because this can block...
	system('ssh -n -l root ipaq "'.$ssh_cmd.'"');
	warn "OK, sent!\n";
	CORE::exit();
    }
}

#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX not yet ready
sub add_palm_datebook_entry {
    require BBBikePalm;
    #use Palm::PDB;
    #use Palm::Datebook;
    #require Palm::StdAppInfo;
    my $pdb = new Palm::PDB;
    $pdb->Load("/home/e/eserte/private/palm/bak/DatebookDB.pdb");
   use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([$pdb],[]); # XXX

    $pdb->Write("/tmp/DB.pdb");
}

sub add_ical_entry {
    my($abfahrt_epoch, $text, %args) = @_;
    my $file = $args{-file};
    if (!defined $file) {
	$file = "$ENV{HOME}/.calendar.ical.bbbikealarm"; # XXX dos file name?
    }
    my @pre_alarm_minutes = (0);
    if (exists $args{-prealarm}) {
	push @pre_alarm_minutes, int($args{-prealarm}/60);
    } else {
	push @pre_alarm_minutes, 10;
    }
    my $pre_alarm = join(" ", @pre_alarm_minutes);

    my @l = localtime($abfahrt_epoch);
    my $start = $l[1]+$l[2]*60;
    my $length = 30; # XXX make changeable
    my($day,$month,$year) = ($l[3], $l[4]+1, $l[5]+1900);
    my $owner = eval { ((getpwuid($<))[0]) } || "unknown";
    # XXX escape text
    # XXX rewrite to use locking etc.
    my $ical_data = "";
    my $uid = 0;
    if (open(F, $file)) {
	while(<F>) {
	    $ical_data .= $_;
	    if (/Uid\s+\[bbbikealarm_(\d+)\]/i) {
		my $new_uid = $1;
		if ($new_uid > $uid) {
		    $uid = $new_uid;
		}
	    }
	}
	close F;
    } else {
	$ical_data = "Calendar [v2.0]\n";
    }
    $uid++;
    $ical_data .= <<EOF;
Appt [
Start [$start]
Length [$length]
Alarms [$pre_alarm]
Uid [bbbikealarm_$uid]
Owner [$owner]
Contents [$text]
Remind [1]
Hilite [always]
Dates [Single $day/$month/$year End
]
]
EOF
    open(F, ">$file") or die "Can't write to $file: $!";
    print F $ical_data;
    close F;
}

# called from outer world
sub tk_interface {
    my($end_time, $text, %args) = @_;
    $text = "Leave" if $text eq "";
    require Tk;
##XXX balloon geht nicht...
#    require Tk::Balloon;
    my $top = MainWindow->new;
#    my $balloon = $top->Balloon;
    $top->title($text);
    $top->withdraw;

    $top->optionAdd("*font", "Helvetica 24 bold");
    $top->optionAdd("*padX", 20);
    $top->optionAdd("*padY", 20);
    $top->optionAdd("*background", "#ff0000");
    $top->optionAdd("*foreground", "white");
    $top->optionAdd("*activeBackground", "#ff8080");
    $top->optionAdd("*activeForeground", "white");

    if ($args{-ask}) {
	if ($top->messageBox
	    (-title => "Set alarm?",
	     -icon => "question",
	     -text => "Set alarm to @{[ scalar localtime $end_time]}?",
	     -type => "YesNo") =~ /no/i) {
	    return;
	}
    }

    my $cb =
	$top->Button(-text => "Leave",
		     -command => sub { $top->destroy },
		    )->pack;
#    $balloon->attach($cb, -msg => $text);
    my $red = 0xff;
    my $dir = -1;
    CenterWindow($top);
    my $wait = $end_time - time;
    if ($wait < 0) {
	warn "Wait time is smaller than 0\n";
	$wait = 0;
    }

    {
	my $ack_t = $top->Toplevel(-title => "Alarm set");
	my $wait = int($wait/60);
	$ack_t->Button(-text => "Alarm set in $wait minute".($wait!=1?"s":""),
		       -command => sub { $ack_t->destroy },
		      )->pack;
	$ack_t->after(10*1000, sub { $ack_t->destroy });
	$ack_t->Popup;
    }

    add_tk_alarm($$, $end_time, "leave");

    $top->after
	($wait*1000, sub {
	     $top->deiconify;
	     $top->raise;
	     system(qw(xset s reset));

	     del_tk_alarm($$);

	     my $raise_after;
	     $top->bind("<Visibility>" => sub {
			    return if $raise_after;
			    $raise_after = $top->after
				(500, sub { $top->raise; undef $raise_after });
			});
	     $top->repeat
		 (50, sub {
		      my @l = localtime;
		      $cb->configure
			  (-bg => sprintf("#%02x%02x%02x", $red,0,0),
			   -activebackground => sprintf("#%02x%02x%02x", $red,0,0),
			   -text => "Leave\n" .
			            sprintf("%02d:%02d", $l[2], $l[1]),
			  );
		      $red+=(8*$dir);
		      if ($red < 0x80) {
			  $dir = 1;
		      } elsif ($red > 0xff) {
			  $red = 0xff;
			  $dir = -1;
		      }
		  });

	      });
    Tk::MainLoop();
}

sub get_alarms_file {
    if (!defined $alarms_file) {
	$alarms_file = "$ENV{HOME}/.bbbikealarm.pids";
    }
    $alarms_file;
}

use enum qw(:LIST_ HOST PID TIME RELTIME DESC STATE);

sub _get_host {
    eval 'require Sys::Hostname; Sys::Hostname::hostname();';
}

sub tk_show_all {
    my $w = shift;
    my @result = show_all();
    require Tk;
    require Tk::HList;
    my $this_host = _get_host();
    my $top;
    if ($w) {
	$top = $w->Toplevel;
    } else {
	$top = MainWindow->new;
    }
    $top->title("Alarm processes");
    my $hl;
    $hl = $top->Scrolled("HList", -header => 1,
			 -columns => 6, -scrollbars => "osoe",
			 -width => 50,
			 -command => sub {
			     my $entry = shift;
			     my $data = $hl->entrycget($entry, -data);
			     if ($data->[LIST_HOST] eq $this_host &&
				 $hl->messageBox(-text => "Kill process $data->[LIST_PID]?",
						 -type => "YesNo",
						) =~ /yes/i) {
				 kill 9 => $data->[LIST_PID];
				 del_tk_alarm($data->[LIST_PID]);
				 $top->destroy;
				 tk_show_all();
			     }
			 },
			)->pack(-fill => "both", -expand => 1);
    $hl->headerCreate(LIST_HOST,    -text => "Host");
    $hl->headerCreate(LIST_PID,     -text => "Pid");
    $hl->headerCreate(LIST_TIME,    -text => "Time");
    $hl->headerCreate(LIST_RELTIME, -text => "Rel Time");
    $hl->headerCreate(LIST_DESC,    -text => "Desc");
    $hl->headerCreate(LIST_STATE,   -text => "State");
    my $i=0;
    foreach my $result (@result) {
	$hl->add($i, -text => $result->[LIST_HOST], -data => $result);
	$hl->itemCreate($i, LIST_PID, -text => $result->[LIST_PID]);
	$hl->itemCreate($i, LIST_TIME, -text => scalar localtime $result->[LIST_TIME]);
	my $min = ($result->[LIST_TIME]-time)/60;
	if ($min < 0) {
	    $hl->itemCreate($i, LIST_RELTIME, -text => "overdue");
	} else {
	    $hl->itemCreate($i, LIST_RELTIME, -text => sprintf "%d:%02d h", $min/60, abs($min)%60);
	}
	$hl->itemCreate($i, LIST_DESC, -text => $result->[LIST_DESC]);
	$hl->itemCreate($i, LIST_STATE, -text => $result->[LIST_STATE]);
	$i++;
    }
    Tk::MainLoop();
}

sub show_all {
    my @result;
    my $this_host = _get_host();

    eval <<'EOF';
    use DB_File;
    tie my %pids, 'DB_File', get_alarms_file(), O_RDONLY, 0600
	or die "Can't tie DB_File " . get_alarms_file() . ": $!";
    while(my($k,$v) = each %pids) {
	my(@l) = split /\t/, $v;
	my($host, $pid, $time, $desc) = @l;
	my $state = "unknown";
	if ($host eq $this_host) {
	    $state = (kill(0 => $pid) ? "running" : "not running");
	}
	push @result, [@l, $state];
    }
    untie %pids;
EOF
    warn $@ if $@;

    @result;
}

sub add_tk_alarm {
    my($pid, $time, $desc) = @_;
    if (!defined $pid) { $pid = $$ }
    my $this_host = _get_host();

    eval <<'EOF';
    use DB_File;
    tie my %pids, 'DB_File', get_alarms_file(), O_RDWR|O_CREAT, 0600
	or die "Can't tie DB_File " . get_alarms_file() . ": $!";
    $pids{$this_host.":".$pid} = join("\t", $this_host, $pid, $time, $desc);
    untie %pids;
EOF
    warn $@ if $@;
}

sub del_tk_alarm {
    my($this_pid) = @_;
    if (!defined $this_pid) { $this_pid = $$ }
    my $this_host = _get_host();

    eval <<'EOF';
    use DB_File;
    tie my %pids, 'DB_File', get_alarms_file(), O_RDWR, 0600
	or die "Can't read DB_File " . get_alarms_file() . ": $!";
    delete $pids{$this_host.":".$this_pid};
    my @to_del;
    while(my($k, $string) = each %pids) {
	if ($this_host eq (split /\t/, $string)[LIST_HOST]) {
	    my $time = (split /\t/, $string)[LIST_TIME];
	    my $pid = (split /\t/, $string)[LIST_PID];
	    if (!kill 0 => $pid || $time < time) {
		push @to_del, $k;
	    }
	}
    }
    delete $pids{$_} foreach @to_del;
    untie %pids;
EOF
    warn $@ if $@;
}

# return number of seconds to wait
sub end_time {
    my($time) = @_;
    my $now = time;
    if ($time =~ /^\+(..)(..)$/) { # relative time
	$now += $1*60*60 + $2*60;
	return $now;
    }

    # absolute time
    my @l = localtime $now;
    my @l2 = @l;
    ($l2[2], $l2[1]) = $time =~ /^(..)(..)$/;
    my $time_epoch = timelocal(@l2);
    if ($time_epoch < $now) {
	$time_epoch+=86400;
	if ($time_epoch < $now) {
	    die "Strange: time is wrong";
	}
    }
    $time_epoch;
}

sub capabilities {
    if (is_in_path("leave") && is_in_path("who") && is_in_path("tee")) {
	$can_leave = 1;
    }
    if (is_in_path("at") && is_in_path("who") && is_in_path("tee")) {
	my $out = `at -V 2>&1`;
	$can_at = ($out !~ /\bno.*\bpermission\b/i);
    }
    eval {
	require Tk;
	$can_tk = 1;
    };
    if (is_in_path("install-datebook") &&
	defined $ENV{PILOTPORT}) {
	$can_palm = 1;
    }
    if ($main::cabulja) {
	$can_s25_ipaq = 1;
    }
    if (is_in_path("ical")) {
	$can_ical = 1;
    }
}

sub time2epoch {
    my($time) = @_;
    if ($time =~ /^\+(\d{2}):?(\d{2})$/) {
	my($H,$M) = ($1, $2);
	time + $H*3600 + $M*60;
    } elsif ($time =~ /^(\d{2}):?(\d{2})$/) {
	require Time::Local;
	my($H,$M) = ($1, $2);
	my @l = localtime;
	my $HM     = sprintf "%02d%02d", $H, $M;
	my $HM_now = sprintf "%02d%02d", $l[2], $l[1];
	$l[1] = $M;
	$l[2] = $H;
	my $new_time = Time::Local::timelocal(@l);
	if ($HM < $HM_now) {
	    $new_time += 86400;
	}
	$new_time;
    } else {
	$time;
    }
}

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 1aa226739da7a8178372aa9520d85589
sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	return "$_/$prog" if -x "$_/$prog";
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 a77759517bc00f13c52bb91d861d07d0
sub file_name_is_absolute {
    my $file = shift;
    my $r;
    eval {
        require File::Spec;
        $r = File::Spec->file_name_is_absolute($file);
    };
    if ($@) {
	if ($^O eq 'MSWin32') {
	    $r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	} else {
	    $r = ($file =~ m|^/|);
	}
    }
    $r;
}
# REPO END

# REPO BEGIN
# REPO NAME center_window /home/e/eserte/src/repository 
# REPO MD5 3d08d84d7a8e609eedbd70f901f5b5ef

sub CenterWindow {
####################################################
# Args: (0) window to center
#       (1) [optional] desired width
#       (2) [optional] desired height
#
# Returns: *nothing*
####################################################
    my($window, $width, $height) = @_;

    $window->idletasks;
    $width  = $window->reqwidth  unless $width;
    $height = $window->reqheight unless $height;
    my $x = int(($window->screenwidth  / 2) - ($width  / 2));
    my $y = int(($window->screenheight / 2) - ($height / 2));
    $window->geometry($width . "x" . $height . "+" . $x . "+" . $y);
}
# REPO END

# REPO BEGIN
# REPO NAME bg_system /home/e/eserte/src/repository 
# REPO MD5 aa3191a2004671b54fd024be12389d0d
sub bg_system {
    my($cmd) = @_;
    #warn "cmd=$cmd\n";
    if ($^O eq 'MSWin32') {
	system 1, $cmd;
    } else {
	system "$cmd &";
    }
}
# REPO END

return 1 if caller;

######################################################################

package main;

my $use_tk;
my $time;
my $text;
my $interactive;
my $ask;
my $show_all;
require Getopt::Long;
if (!Getopt::Long::GetOptions("-tk!" => \$use_tk,
			      "-time=s" => \$time,
			      "-text=s" => \$text,
			      "-interactive!" => \$interactive,
			      "-ask!" => \$ask,
			      "showall|list" => \$show_all,
			     )) {
    die "Usage $0 [-tk [-ask]] [-time hh:mm] [-text message] [-interactive]
                  [-showall|-list]
";
}

$time = BBBikeAlarm::time2epoch($time) if defined $time;

if ($interactive) {
    require Tk;
    my $mw = MainWindow->new;
    $mw->withdraw;
    $time = do { @_ = localtime; sprintf "%02d:%02d", $_[3], $_[2] };
    BBBikeAlarm::enter_alarm($mw, \$time, -dialog => 1);
} elsif ($use_tk) {
    if ($show_all) {
	BBBikeAlarm::tk_show_all();
    } else {
	BBBikeAlarm::tk_interface($time, $text, -ask => $ask);
    }
} elsif ($show_all) {
    print join("\n", map { join "\t", @$_ } BBBikeAlarm::show_all()), "\n";
} else {
    die "Can't set alarm: type e.g. -tk missing";
}

__END__
