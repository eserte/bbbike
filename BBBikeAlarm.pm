# -*- perl -*-

#
# $Id: BBBikeAlarm.pm,v 1.43 2009/02/14 11:34:40 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000, 2006, 2008, 2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

package BBBikeAlarm;

use FindBin;
use vars qw($VERSION
	    $can_leave $can_at $can_tk $can_palm $can_s25_ipaq $can_ical
	    $can_bluetooth
	    $alarms_file
	    @baddr
	   );
use strict;
use lib "$FindBin::RealBin/lib";

BEGIN {
    if (!eval '
use Msg qw(frommain);
1;
') {
	#warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

# XXX
my $install_datebook_additions = 1;

use File::Basename qw(basename);
use Time::Local;

$VERSION = sprintf("%d.%02d", q$Revision: 1.43 $ =~ /(\d+)\.(\d+)/);

# XXX S25 Termin (???)
# XXX Terminal-Alarm unter Windows? Linux?
# XXX Leave funktioniert nur für max. 12 Stunden (testen!)

sub my_die ($) {
    my $msg = shift;
    if (defined &main::status_message) {
	main::status_message($msg, "die");
    } else {
	require Carp;
	Carp::croak($msg);
    }
}

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
	if (defined $args{-location} && eval { require Astro::Sunrise; Astro::Sunrise->VERSION(0.85); 1 }) {
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

	    my $diff = $end_zeit_epoch - time;
	    my $diff_text = sprintf "(in %d:%02d h)", $diff/3600, ($diff%3600)/60;

	    $ab_l->configure(-text => sprintf("%02d:%02d $diff_text", $l[2], $l[1]));
	    return $end_zeit;
	};

	if ($Tk::VERSION > 800.016) { # XXX ca. for -validation
	    foreach my $w ($e, $vb_e) {
		$w->configure
		    (-vcmd =>
		     sub {
			 my $adjust_subset_choice; $adjust_subset_choice = 1
			     if ($_[4] == 0 || $_[4] == 1) && $w eq $e; # INSERT or DELETE
			 $w->after(10, sub {
					 $get_end_zeit->(0);
					 if ($adjust_subset_choice) {
					     $sunset_choice = "";
					     $om->setOption("","")
						 if $om;
					 }
				     });
			 1;
		     },
		     -validate => "all");
	    }
	}

	my $row = 4;

	capabilities();

	my($use_tk, $use_leave, $use_palm, $use_s25_ipaq, $use_at, $use_ical,
	   $use_bluetooth);
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
	} elsif ($can_bluetooth) {
	    $use_bluetooth = 1;
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

	if ($can_bluetooth) {
	    $t->Checkbutton(-text => "VCal via Bluetooth",
			    -variable => \$use_bluetooth)->grid(-row => $row++,
								-column => 0,
								-columnspan => 2,
								-sticky => "w");
	} else {
	    $use_bluetooth = 0;
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

	{
	    $t->Button(-padx => 1, -pady => 1,
		       -text => "emacs org-mode date",
		       -command => sub {
			   $get_end_zeit->();
			   emacs_org_mode_date(-toplevel => $t,
					       -text => $text,
					       -dtstart => $ankunft_epoch,
					       -alarmdelta => $pre_alarm_seconds,
					      );
		       },
		      )->grid(-row => $row++, -column => 0, -columnspan => 2,
			      -sticky => 'w');
	}

	my $f = $t->Frame->grid(-row => $row++, -column => 0,
				-columnspan => 2, -sticky => "ew");
	$f->Button(-text => M"Alarm setzen",
		   -command => sub {
		       my $end_zeit = $get_end_zeit->(1);
		       if (!defined $end_zeit) {
			   $t->messageBox(-message => "Die Ankunftszeit ist nicht definiert.",
					  -icon => "error",
					  -type => "OK",
					 );
			   return;
		       }

		       tk_leave($end_zeit, -text => $text)
			   if $use_tk;
		       grabbing_leave($end_zeit, -text => $text)
			   if $use_leave;
		       grabbing_at($end_zeit, -text => $text)
			   if $use_at;
		       palm_leave($ankunft_epoch, $pre_alarm_seconds,
				  -text => $text)
			   if $use_palm;
		       s25_ipaq_leave($abfahrt_epoch, $ankunft_epoch, $pre_alarm_seconds)
			   if $use_s25_ipaq;
		       bluetooth_leave($top, $abfahrt_epoch, $ankunft_epoch, $vorbereitung_s)
			   if $use_bluetooth;
		       add_ical_entry($abfahrt_epoch, $text, -prealarm => $vorbereitung_s)
			   if $use_ical;
		       $do_close = 1;
		       $t->destroy;
		   })->pack(-side => "left", -fill => "x", -expand => 1);
	$f->Button(Name => "close",
		   -text => M"Schließen",
		   -command => sub {
		       $do_close = 1;
		       $t->destroy;
		   })->pack(-side => "left", -fill => "x", -expand => 1);

	if ($args{-dialog}) {
	    $t->waitVariable(\$do_close);
	}
    }
}

sub enter_alarm_small_dialog {
    my($top, %args) = @_;
    my $t = $top->Toplevel(-title => "Alarm");
    $t->transient($top) if $main::transient;
    my $row = 0;
    my $time;
    my $text = "Leave";
    $t->Label(-text => "Time (HH:MM)")->grid(-column => 0, -row => $row,
					     -sticky => "w");
    my @e;
    push @e, $t->Entry(-textvariable => \$time,
		       -width => 6,
		      )->grid(-row => $row, -column => 1,
			      -sticky => "we");
    $e[0]->focus;
    $row++;

    if ($args{-withtext}) {
	$t->Label(-text => "Alarm text")->grid(-column => 0, -row => $row,
					       -sticky => "w");
	push @e, $t->Entry(-textvariable => \$text,
			   -width => 20,
			  )->grid(-row => $row, -column => 1,
				  -sticky => "we");
	$row++;
    }

    my $weiter;
    my $bf = $t->Frame->grid(-row => $row, -column => 0, -columnspan => 2);
    my $okb =
	$bf->Button(-text => "OK",
		    -command => sub {
			my($h_a, $m_a);
			if (my($delta_h, $delta_m) = $time =~ /(?:^|\s)\+(\d{1,2})[:.]?(\d{2})(?:$|\s)/) {
			    my @l = localtime;
			    $m_a = $l[1] + $delta_m;
			    if ($m_a >= 60) {
				$m_a %= 60;
				$delta_h++;
			    }
			    $h_a = $l[2] + $delta_h;
			    if ($h_a >= 24) {
				$h_a %= 24;
				# overflows are hopefully handled by tk_leave
			    }
			} else {
			    ($h_a, $m_a) = $time =~ /(?:^|\s)(\d{1,2})[:.]?(\d{2})(?:$|\s)/;
			}
			if (!defined $h_a || !defined $m_a) {
			    $top->messageBox(-message => "Wrong time format, should be HH:MM or +HH:MM",
					     -icon => "error",
					     -type => "OK");
			    $e[0]->focus;
			    return undef;
			}
			tk_leave(sprintf("%02d%02d", $h_a, $m_a),
				 -text => $text);
			$weiter = 1;
		    })->grid(-row => 0, -column => 0);
    for my $e_i (0 .. $#e-1) {
	$e[$e_i]->bind("<Return>" => [ sub { my $i = $_[1]; $e[$i]->focus }, $e_i+1]);
    }
    $e[-1]->bind("<Return>" => sub { $okb->invoke });
    my $cb = $bf->Button(-text => "Cancel",
			 -command => sub {
			     $weiter = 1;
			 })->grid(-row => 0, -column => 1);
    $t->bind("<Escape>" => sub { $cb->invoke });
    $t->Popup(-popover => "cursor");
    $t->OnDestroy(sub { $weiter = 1 });
    $t->waitVariable(\$weiter);
    $t->destroy if Tk::Exists($t);
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
	my_die "No tty found for current user!";
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
	my_die "No tty found for current user!";
    }
    system(qq{echo 'echo "$time: $text" | tee @tty' | at $time});
}

sub tk_leave {
    my($time, %args) = @_;
    my $end_time = $args{-epoch} || end_time($time);
    my $text = $args{-text};
    $text = "Leave" if !defined $text || $text eq "";
    bg_system($^X, "$FindBin::RealBin/BBBikeAlarm.pm", "-tk", "-time", $end_time, "-text", $text, "-encoding", "utf-8");
}

sub palm_leave {
    return unless $main::devel_host;
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
    open(F, ">$leave_file") or my_die "Can't write to $leave_file: $!";
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
    close F
	or my_die "While closing $leave_file: $!";

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
    return unless $main::devel_host;
    my($abfahrt_epoch, $ankunft_epoch, $pre_alarm_seconds, %args) = @_;

    my $vcal_entry = create_vcalendar_entry($abfahrt_epoch, $ankunft_epoch, $pre_alarm_seconds);

    # create ical file on the ipaq
    my $ical_file = "/tmp/s25_cal.ical";
    open(CAT, '| ssh -l root ipaq "cat > ' . $ical_file . '"');
    print CAT $vcal_entry;
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

sub bluetooth_leave {
    return unless $main::devel_host; # XXX vorerst, geht nur unter FreeBSD
    my($top, $abfahrt_epoch, $ankunft_epoch, $vorbereitung_s, %args) = @_;
    select_baddr_and_send
	($top,
	 sub {
	     my($baddr) = @_;

	     my $vcal_entry = create_vcalendar_entry($abfahrt_epoch, $ankunft_epoch, $vorbereitung_s);
	     require File::Temp;
	     my($fh,$file) = File::Temp::tempfile(UNLINK => 1, SUFFIX => ".vcs");
	     print $fh $vcal_entry;
	     close $fh;

	     my $status;
	     my @cmd;
	     if (is_in_path("obexapp")) {
		 # 9 should not be hardcoded
		 @cmd = ("obexapp", "-C", 9, "-c", "-a", $baddr, "-n", "put", $file);
		 system @cmd;
		 $status = $?;
	     } elsif (is_in_path("ussp-push")) {
		 # 9 should not be hardcoded
		 @cmd = ("ussp-push", $baddr . '@' . 9, $file, basename($file));
		 system @cmd;
		 $status = $?;
	     } else {
		 my_die "Neither obexapp nor ussp-push are available";
	     }

	     unlink $file;
	     if ($status != 0) {
		 my_die "Obex command <@cmd> failed with $status";
	     }
	 },
	);
}

sub select_baddr_and_send {
    my($top, $ok_cb) = @_;
    my $t = $top->Toplevel(-title => "Bluetooth devices");
    my $lb = $t->Scrolled("Listbox", -selectmode => "single")->pack(-fill => "both");
    load_baddr_cache();
    fill_baddr_lb($lb);
    {
	my $f = $t->Frame->pack(-fill => "x");
	$f->Button(-text => "Inquiry",
		   -command => sub {
		       $t->Busy(-recurse => 1,
				sub {
				    bluetooth_inquiry();
				});
		       fill_baddr_lb($lb);
		   })->pack(-side => "left");
	$f->Button(-text => "Send VCAL",
		   -command => sub {
		       my(@inx) = $lb->curselection;
		       $t->destroy;
		       if (@inx) {
			   my $baddr_entry = $baddr[$inx[0]];
			   my $baddr = $baddr_entry->{baddr};
			   for my $i (0 .. $#baddr) {
			       if ($i == $inx[0]) {
				   $baddr[$i]->{sel} = '+';
			       } else {
				   $baddr[$i]->{sel} = '-';
			       }
			   }
			   $top->Busy(-recurse => 1,
				      sub {
					  $ok_cb->($baddr);
				      });
		       } else {
			   $t->messageBox(-message => "Please select a device");
		       }
		   })->pack(-side => "left");
	$f->Button(-text => "Cancel",
		   -command => sub {
		       $t->destroy;
		   })->pack(-side => "left");
    }
}

sub bluetooth_inquiry {
    if (is_in_path("hccontrol")) {
	@baddr = bluetooth_inquiry_hccontrol();
    } elsif (is_in_path("hcitool")) {
	@baddr = bluetooth_inquiry_hcitool();
    } else {
	my_die "Either hccontrol (BSD) or hcitool (Linux) is necessary for bluetooth inquiry";
    }
    save_baddr_cache();
}

sub bluetooth_inquiry_hccontrol {
    my $cmd = "hccontrol inquiry";
    my(@result) = `$cmd`;
    my_die "$cmd failed with $?" if $? != 0;
    my @_baddr;
    for (@result) {
	if (/^\s+BD_ADDR:\s+([0-9a-f:]+)/i) {
	    push @_baddr, $1;
	}
    }

    my @__baddr;
    for my $baddr (@_baddr) {
	my $cmd = "hccontrol Remote_Name_Request $baddr";
	my(@result) = `$cmd`;
	my_die "$cmd failed with $?" if $? != 0;
	for (@result) {
	    if (/^Name:\s+(.*)/) {
		my $name = $1;
		push @__baddr, {name  => $name,
				sel   => '-',
				baddr => $baddr,
			       };
	    }
	}
    }

    @__baddr;
}

sub bluetooth_inquiry_hcitool {
    my $cmd = "hcitool scan 2>&1";
    my(@result) = `$cmd`;
    my_die "$cmd failed with $?" if $? != 0;
    my @_baddr;
    for (@result) {
	if (/^\s+([0-9a-f:]+)\s+(.*)/i) {
	    my $name = $2;
	    my $baddr = $1;
	    push @_baddr, { name  => $name,
			    sel   => '-',
			    baddr => $baddr,
			  };
	}
    }

    @_baddr;
}

sub fill_baddr_lb {
    my($lb) = @_;
    my $sel_done = 0;
    $lb->delete(0,"end");
    for my $baddr (@baddr) {
	my($sel, $baddr, $name) = @{$baddr}{qw(sel baddr name)};
	$lb->insert("end", sprintf "%-20s (%s)", $name, $baddr);
	if (!$sel_done && $sel eq '+') {
	    $lb->selectionClear;
	    $lb->selectionSet("end");
	    $sel_done = 1;
	}
    }
}

sub get_baddr_cache_file {
    $main::bbbike_configdir = $main::bbbike_configdir if 0;
    my $dir = $main::bbbike_configdir;
    if (!$dir || !-d $dir || !-w $dir) {
	$dir = "/tmp";
    }
    $dir . "/baddr_cache";
}

sub load_baddr_cache {
    my $f = get_baddr_cache_file();
    @baddr = ();
    if (open BADDR, $f) {
	while(<BADDR>) {
	    chomp;
	    my($sel) = $_ =~ m{^(.)};
	    s{^.}{};
	    my($baddr, $name) = split /\s+/, $_, 2;
	    push @baddr, {sel   => $sel,
			  baddr => $baddr,
			  name  => $name,
			 };
	}
	close BADDR;
    }
    @baddr;
}

sub save_baddr_cache {
    my $f = get_baddr_cache_file();
    open BADDR, "> $f"
	or my_die "Can't write to $f: $!";
    for my $baddr (@baddr) {
	my($sel, $baddr, $name) = @{$baddr}{qw(sel baddr name)};
	$sel = '-' if !$sel;
	print BADDR "$sel$baddr $name\n"
    }
    close BADDR
	or my_die "While closing $f: $!";
}

sub create_vcalendar_entry {
    my($begintime, $endtime, $vorbereitung_s, $subject, $descr, $cat) = @_;

    require POSIX;
    my $dtstart = POSIX::strftime("%Y%m%dT%H%M%S", localtime $begintime);
    my $dtend   = POSIX::strftime("%Y%m%dT%H%M%S", localtime $endtime);
    my $alarm   = POSIX::strftime("%Y%m%dT%H%M%S", localtime ($begintime-$vorbereitung_s));

    my @search_route;

    if (!defined $subject) {
	$subject = "Fahrradfahrt (BBBike)";
	if (defined &main::get_act_search_route) {
	    @search_route = @{ main::get_act_search_route() };
	    if (@search_route) {
		$subject = $search_route[-1][StrassenNetz::ROUTE_NAME()] . " (Fahrradfahrt)";
	    }
	}
    }

    if (!defined $descr && @search_route) {
	require BBBikeUtil;
	require Strassen::Strasse;
	$descr = join("\n", map {
	    my $hop = Strasse::strip_bezirk($_->[StrassenNetz::ROUTE_NAME()]);
	    $hop .= " [" . BBBikeUtil::m2km($_->[StrassenNetz::ROUTE_DIST()]);
	    if (defined $_->[StrassenNetz::ROUTE_ANGLE()] && $_->[StrassenNetz::ROUTE_ANGLE()] >= 30) {
		$hop .= ", " . uc($_->[StrassenNetz::ROUTE_DIR()]);
	    }
	    $hop .= "]";
	} @search_route);
    }

    #my $cat = "MISCELLANEOUS";
    $cat = "MEETING" if !defined $cat;

    my $this_host = _get_host();
    my $uid = POSIX::strftime("%Y%m%d%H%M%S-$this_host", localtime);

    #(my $descr_escaped = $descr) =~ s{\n}{\\N}g; # XXX Does not work with my N95, neither with \n nor with \N
    (my $descr_escaped = $descr) =~ s{\n}{ - }g;
    <<EOF;
BEGIN:VCALENDAR
VERSION:1.0
BEGIN:VEVENT
UID:$uid
CATEGORIES:$cat
DALARM:$alarm
DTSTART:$dtstart
DTEND:$dtend
SUMMARY:$subject
DESCRIPTION:$descr_escaped
END:VEVENT
END:VCALENDAR
EOF
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
	if ($] >= 5.008) {
	    eval q{binmode F, ':utf8';};
	    my_die $@ if $@;
	}
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
    open(F, ">$file") or my_die "Can't write to $file: $!";
    if ($] >= 5.008) {
	eval q{binmode F, ':utf8';};
	my_die $@ if $@;
    }
    print F $ical_data
	or my_die "Can't print to $file: $!";
    close F
	or my_die "While closing $file: $!";
}

sub emacs_org_mode_date {
    my(%args) = @_;
    my $toplevel      = delete $args{-toplevel};
    my $text          = delete $args{-text};
    my $dtstart_epoch = delete $args{-dtstart};
    my $alarm_delta   = delete $args{-alarmdelta};
    die "Unhandled arguments: " . join(" ", %args) if %args;
    my $t = $toplevel->Toplevel(-title => "Emacs org-mode date");
    $t->transient($toplevel) if $main::transient;
    my $txt = $t->Scrolled("ROText",
			   -scrollbars => 'osoe',
			   -height => 2,
			   -width => 60,
			  )->pack(qw(-fill both -expand 1));
    # XXX Taken from ical2org
    my $alarm_delta_spec;
    if ($alarm_delta % 3600 == 0) {
	$alarm_delta_spec = ($alarm_delta/3600).'h';
    } elsif ($alarm_delta % 60 == 0) {
	$alarm_delta_spec .= ($alarm_delta/60).'min';
    } else {
	$alarm_delta_spec .= $alarm_delta.'s';
    }

    require POSIX;
    my $org_date = POSIX::strftime("%Y-%m-%d %a %H:%M", localtime $dtstart_epoch) . " -" . $alarm_delta_spec;
    $txt->insert("end", "** $text <$org_date>");
    $txt->selectAll;
    $t->Button(Name => "close",
	       -text => M"Schließen",
	       -command => sub {
		   $t->destroy;
	       })->pack(-side => "right", -fill => "x");
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

    $Tk::platform = $Tk::platform; # peacify -w
    if ($Tk::platform eq 'unix') {
	my($wrapper) = $top->wrapper;
	# set sticky flag for gnome and fvwm2
	eval q{
	    $top->property('set','_WIN_STATE','CARDINAL',32,[1],$wrapper); # sticky
	    $top->property('set','_WIN_LAYER','CARDINAL',32,[6],$wrapper); # ontop
	};
	warn $@ if $@;
    }

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
	    (-title => M"Alarm setzen?",
	     -icon => "question",
	     -message => Mfmt("Alarm auf %s setzen?", scalar localtime $end_time),
	     -type => "YesNo") =~ /no/i) {
	    return;
	}
    }

    my $cb =
	$top->Button(-text => M("Verlassen"),
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
	my $ack_t = $top->Toplevel(-title => M"Alarm gesetzt");
	my $wait = int($wait/60);
	$ack_t->Button(-text => Mfmt("Alarm in %s %s gesetzt", $wait, $wait==1 ? M"Minute" : M"Minuten"),
		       -command => sub { $ack_t->destroy },
		      )->pack;
	$ack_t->after(10*1000, sub { $ack_t->destroy });
	$ack_t->Popup;
    }

    {
	(my $esc_text = $text) =~ s/\t/ /g;
	add_tk_alarm($$, $end_time, $esc_text);
    }

    $top->after
	($wait*1000, sub {
	     $top->deiconify;
	     $top->raise;
	     if ($Tk::platform eq 'unix') {
		 system(qw(xset s reset));
	     }

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
			   -text => "$text\n" .
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

use constant LIST_HOST    => 0;
use constant LIST_PID     => 1;
use constant LIST_TIME    => 2;
use constant LIST_RELTIME => 3;
use constant LIST_DESC    => 4;
use constant LIST_STATE   => 5;

use constant COL_HOST    => 0;
use constant COL_PID     => 1;
use constant COL_TIME    => 2;
use constant COL_RELTIME => 3;
use constant COL_DESC    => 4;
use constant COL_STATE   => 5;

sub _get_host {
    eval 'require Sys::Hostname; Sys::Hostname::hostname();';
}

{
    my($w, $this_host, $top, $show_all_timer);

    sub tk_show_all_init {
	$w = shift;
	require Tk;
	require Tk::HList;
	$this_host = _get_host();
	if ($w) {
	    $top = $w->Toplevel;
	} else {
	    $top = MainWindow->new;
	}
	$top->title(M("Alarmprozesse"));
    }

    sub tk_show_all_do {
	my $hl;
	$this_host = $this_host; # hmmm ... needed so the hlist command closure may see this lexical...
	$hl = $top->Scrolled("HList", -header => 1,
			     -columns => 6, -scrollbars => "osoe",
			     -width => 65,
			     -command => sub {
				 my $entry = shift;
				 my $data = $hl->entrycget($entry, -data);
				 if ($data->[LIST_HOST] eq $this_host &&
				     $hl->messageBox(-message => Mfmt("Prozess %s abbrechen?", $data->[LIST_PID]),
						     -type => "YesNo",
						    ) =~ /yes/i) {
				     kill 9 => $data->[LIST_PID];
				     del_tk_alarm($data->[LIST_PID]);
				     $hl->destroy;
				     tk_show_all_do();
				 }
			     },
			    )->pack(-fill => "both", -expand => 1);
	$hl->headerCreate(COL_HOST,    -text => M"Rechner");
	$hl->headerCreate(COL_PID,     -text => M"Pid");
	$hl->headerCreate(COL_TIME,    -text => M"Zeit");
	$hl->headerCreate(COL_RELTIME, -text => M"Verbl. Zeit");
	$hl->headerCreate(COL_DESC,    -text => M"Beschr.");
	$hl->headerCreate(COL_STATE,   -text => M"Status");

	if ($show_all_timer) {
	    $show_all_timer->cancel;
	}
	$show_all_timer = $hl->repeat(60*1000, sub { tk_show_all_update($hl) });
	tk_show_all_update($hl);
    }

    sub tk_show_all_update {
	my($hl) = @_;
	if (!Tk::Exists($hl)) {
	    if ($show_all_timer) {
		$show_all_timer->cancel;
		undef $show_all_timer;
	    }
	    return;
	}

	my @result = show_all();
	my $i = 0;
	$hl->delete("all");
	foreach my $result (@result) {
	    $hl->add($i, -text => $result->[LIST_HOST], -data => $result);
	    $hl->itemCreate($i, COL_PID, -text => $result->[LIST_PID]);
	    $hl->itemCreate($i, COL_TIME, -text => scalar localtime $result->[LIST_TIME]);
	    $hl->itemCreate($i, COL_RELTIME, -text => $result->[LIST_RELTIME]);
	    $hl->itemCreate($i, COL_DESC, -text => $result->[LIST_DESC]);
	    $hl->itemCreate($i, COL_STATE, -text => $result->[LIST_STATE]);
	    $i++;
	}

    }

    sub tk_show_all {
	my $w = shift;
	tk_show_all_init($w);
	tk_show_all_do();
	Tk::MainLoop();
    }

}

sub open_dbm {
    my(%args) = @_;
    my $readonly = delete $args{-readonly} || 0;
    if (keys %args) {
	my_die "Unhandled arguments " . join " ", %args;
    }
    my $pids;
    if (!eval {
	require DB_File;
	require Fcntl;
	my $flags = $readonly ? &Fcntl::O_RDONLY : &Fcntl::O_RDWR|&Fcntl::O_CREAT;
	tie %$pids, 'DB_File', get_alarms_file(), $flags, 0600
	    or my_die "Can't tie DB_File " . get_alarms_file() . ": $!";
    }) {
	require SDBM_File;
	require Fcntl;
	my $flags = $readonly ? &Fcntl::O_RDONLY : &Fcntl::O_RDWR|&Fcntl::O_CREAT;
	tie %$pids, 'SDBM_File', get_alarms_file(), $flags, 0600
	    or my_die "Can't tie SDBM_File " . get_alarms_file() . ": $!";
    }
    $pids;
}

sub restart_alarms {
    eval {
	my $pids = open_dbm(-readonly => 1);
	my $this_host = _get_host();
	while(my($k,$v) = each %$pids) {
	    my(@l) = split /\t/, $v;
	    my($host, $pid, $time, $desc) = @l;
	    $desc = _decode_desc($desc);
	    my $state = "unknown";
	    if ($host eq $this_host) {
		if (!kill(0 => $pid)) {
		    warn "Restart process $pid at " . scalar(localtime $time) . " ...\n";
		    tk_leave(undef, -epoch => $time, -text => $desc); # XXX use_tk?
		    delete $pids->{$k};
		}
	    }
	}
	untie %$pids;
    };
    warn $@ if $@;
}

sub show_all {
    my @result;
    my $this_host = _get_host();

    eval {
	my $pids = open_dbm(-readonly => 1);
	while(my($k,$v) = each %$pids) {
	    my(@l) = split /\t/, $v;
	    my($host, $pid, $time, $desc) = @l;
	    $l[3] = _decode_desc($desc);
	    my $state = "unknown";
	    if ($host eq $this_host) {
		$state = (kill(0 => $pid) ? M("läuft") : M("läuft nicht"));
	    }
	    push @l, $state;

	    my $reltime;
	    my $min = ($time-time)/60;
	    if ($min < 0) {
		$reltime = M"überfällig";
	    } else {
		$reltime = sprintf "%d:%02d h", $min/60, abs($min)%60;
	    }

	    splice @l, LIST_RELTIME, 0, $reltime;

	    push @result, [@l];
	}
	untie %$pids;
    };
    warn $@ if $@;

    @result;
}

sub add_tk_alarm {
    my($pid, $time, $desc) = @_;
    if (!defined $pid) { $pid = $$ }
    my $this_host = _get_host();

    eval {
	my $pids = open_dbm(-readonly => 0);
	my $desc_octets = _encode_desc($desc);
	$pids->{$this_host.":".$pid} = join("\t", $this_host, $pid, $time, $desc_octets);
	untie %$pids;
    };
    warn $@ if $@;
}

sub del_tk_alarm {
    my($this_pid) = @_;
    if (!defined $this_pid) { $this_pid = $$ }
    my $this_host = _get_host();

    eval {
	my $pids = open_dbm(-readonly => 0);
	delete $pids->{$this_host.":".$this_pid};
	my @to_del;
	while(my($k, $string) = each %$pids) {
	    if ($this_host eq (split /\t/, $string)[LIST_HOST]) {
		my $time = (split /\t/, $string)[LIST_TIME];
		my $pid = (split /\t/, $string)[LIST_PID];
		if (!kill 0 => $pid || $time < time) {
		    push @to_del, $k;
		}
	    }
	}
	delete $pids->{$_} foreach @to_del;
	untie %$pids;
    };
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
	    my_die "Strange: time is wrong";
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
    if ($main::devel_host) {
	$can_s25_ipaq = 1;
    }
    if (is_in_path("ical")) {
	$can_ical = 1;
    }
    if ($main::devel_host) {
	if (is_in_path("obexapp")) {
	    $can_bluetooth = 1; # FreeBSD
	} elsif (is_in_path("ussp-push")) {
	    $can_bluetooth = 1; # Linux
	}
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

sub _decode_desc {
    my $v = shift;
    if (eval { require Encode; 1 }) {
	$v = Encode::decode('utf-8', $v);
    }
    $v;
}

sub _encode_desc {
    my $v = shift;
    if (eval { require Encode; 1 }) {
	$v = Encode::encode('utf-8', $v);
    }
    $v;
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
    my(@args) = @_;
    if ($^O eq 'MSWin32') {
	for (@args) {
	    s/[\"\\]//g; # XXX quote properly
	}
	system 1, "@args";
    } else {
	my $pid1 = fork;
	die "Cannot fork: $!" if !defined $pid1;
	if (!$pid1) {
	    my $pid2 = fork;
	    if (!defined $pid2) {
		warn "Cannot fork: $!";
		CORE::exit(1);
	    }
	    if (!$pid2) {
		exec @args;
		warn "Cannot exec @args: $!";
		CORE::exit(2);
	    }
	    CORE::exit(0);
	}
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
my $interactive_small;
my $ask;
my $show_all;
my $restart;
my $encoding;
require Getopt::Long;
if (!Getopt::Long::GetOptions("-tk!" => \$use_tk,
			      "-time=s" => \$time,
			      "-text=s" => \$text,
			      "-interactive!" => \$interactive,
			      "-interactive-small!" => \$interactive_small,
			      "-ask!" => \$ask,
			      "-encoding=s" => \$encoding,
			      "showall|list" => \$show_all,
			      "restart" => \$restart,
			     )) {
    die "Usage $0 [-tk [-ask]] [-time hh:mm] [-text message]
		  [-interactive | -interactive-small]
                  [-showall|-list] [-restart] [-encoding ...]
";
}

$time = BBBikeAlarm::time2epoch($time) if defined $time;
if (defined $text && defined $encoding) {
    require Encode;
    $text = Encode::decode($encoding, $text);
}

if ($interactive || $interactive_small) {
    require Tk;
    my $mw = MainWindow->new;
    $mw->withdraw;
    if ($interactive_small) {
	BBBikeAlarm::enter_alarm_small_dialog($mw, -withtext => 1);
    } else {
	$time = do { @_ = localtime; sprintf "%02d:%02d", $_[3], $_[2] };
	BBBikeAlarm::enter_alarm($mw, \$time, -dialog => 1);
    }
} elsif ($use_tk) {
    if ($show_all) {
	BBBikeAlarm::tk_show_all();
    } else {
	BBBikeAlarm::tk_interface($time, $text, -ask => $ask);
    }
} elsif ($show_all) {
    print join("\n", map { join "\t", @$_ } BBBikeAlarm::show_all()), "\n";
} elsif ($restart) {
    BBBikeAlarm::restart_alarms();
} else {
    die "Can't set alarm: type e.g. -tk missing";
}

# peacify -w
$main::tmpdir = $main::tmpdir if 0;
$main::top = $main::top if 0;

__END__

=head1 NAME

BBBikeAlarm - setting alarms

=head1 SYNOPSIS

From cmdline:

    perl BBBikeAlarm.pm [-tk [-ask]] [-time hh:mm] [-text message]
		  [-interactive | -interactive-small]
                  [-showall|-list] [-restart] [-encoding ...]

From script:

    use BBBikeAlarm;
    use Tk;
    BBBikeAlarm::enter_alarm_small_dialog(MainWindow->new)

=head1 BUGS

The pid list of running alarm processes is maintained in a Berkeley DB
file F<~/.bbbikealarm.pids>, if L<DB_File> is available. Berkeley DB
is a highly instable format. It is possible that updates to the
underlying library makes the old db file unreadable (often seen on
Debian systems). In this case, just remove the mentioned file.

=head1 TODO

    sollte ich evtl. verwenden für die Liste der Alarme:
    http://reefknot.sourceforge.net/
    Date::ICal, Net::ICal

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<DB_File>, L<Astro::Sunrise>, L<BBBikePalm>.

=cut
