# -*- perl -*-

#
# $Id: BBBikeGSMSender.pm,v 1.2 2003/01/08 20:17:07 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeGSMSender;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

package Tk::Babybike;

sub gsmsender {
    my($gsmbbd);
    my(@gsmsender_dir) = qw(/tmp /home/e/eserte/src/hh /usr/local/gsm);
    $mw->Busy(-recurse => 1);
    eval {
	if (!defined &Gsmsender::set) {
	    foreach my $test (@gsmsender_dir) {
		if (-r "$test/CLF.pm") {
		    push @INC, $test;
		}
	    }
	TRY: {
		foreach my $test (@gsmsender_dir) {
		    if (-r "$test/gsmsender") {
			do "$test/gsmsender";
			die $@ if $@;
			last TRY;
		    }
		}
		die "Can't locate gsmsender in @gsmsender_dir";
	    }
	}
	if ($^O =~ /freebsd/i) { # test
	    Gsmsender::set_test(qw(8D22 3008 26201));
	}
	my $grep_prg = "grep";
	foreach my $d (@gsmsender_dir, "/usr/local/BBBike/data",
		       "$moduledir/data") {
	    my $test_f = "$d/blnbb.bbd";
	    if (-r $test_f) {
		$gsmbbd = $test_f;
		last;
	    }
	    $test_f = "$d/blnbb.bbd.gz";
	    if (-r $test_f) {
		$gsmbbd = $test_f;
		$grep_prg = "zgrep";
		last;
	    }
	}
	if (!defined $gsmbbd) {
	    die "No blnbb.bbd found";
	}
	my $code = Gsmsender::get();
	die "Can't get sender" if $code eq '';
	chomp $code;
	my $line;
	if ($grep_prg eq 'zgrep') {
	    # no zgrep on iPAQ
	    $line = `gzip -dc $gsmbbd | grep -F "[$code]"`;
	} else {
	    $line = `$grep_prg -F "[$code]" $gsmbbd`;
	}
	if ($line eq '') {
	    $se->delete(0, 'end');
	    $se->insert(0, $code);
	} else {
	    chomp $line;
	    if ($line =~ /^(.*)\t\S+\s+(.*)$/) {
		my($street, $coord) = ($1, $2);
		# XXX also exact_streetchooser...
		my $kr = $routing->init_crossings;
		my $nearest_coord = (($kr->nearest_loop(split /,/, $coord))[0]);
		set_street_coord('start', $street, $nearest_coord);
		my($tx,$ty) = $transpose->(split /,/, $coord);
		$c->delete("gsm");
		$c->createLine($tx,$ty,$tx,$ty, -capstyle => 'round', -width => 6, -fill => 'red', -tags => 'gsm');
		$c->createLine($tx,$ty,$tx,$ty, -capstyle => 'round', -width => 3, -fill => 'blue4', -tags => 'gsm');
		set_mark($tx,$ty);
		_set_active_entry($ze) unless $continue_search;
	    } else {
		die "Can't parse line $line";
	    }
	}
    };
    my $err = $@;
    $mw->Unbusy;
    die $err if $err;
}

1;

__END__
