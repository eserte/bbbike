# -*- perl -*-

#
# $Id: BBBikeMail.pm,v 1.14 2006/08/20 18:56:27 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998,2000,2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

package BBBikeMail;
use strict;
use vars qw($top @popup_style
	    $can_send_mail $can_send_fax
	    $cannot_send_mail_reason $cannot_send_fax_reason);

$top = $main::top;
*redisplay_top  = \&main::redisplay_top;
*status_message = \&main::status_message;

sub enter_send_mail {
    enter_send_anything('mail', @_);
}

sub enter_send_fax {
    enter_send_anything('fax', @_);
}

sub enter_send_anything {
    my($type, $subject, %args) = @_;
    my $data = $args{-data};
    my $to   = $args{-to};
    my $typename = ($type eq 'mail' ? 'Mail' : 'FAX');

    capabilities();

    if (($type eq 'mail' && !$can_send_mail) ||
	($type eq 'fax'  && !$can_send_fax)) {
	my $reason = ($type eq 'mail' ? $cannot_send_mail_reason : $cannot_send_fax_reason);
	$top->messageBox
	    (-icon => "error",
	     -message => "Kann keine " .
	     ($type eq 'mail' ? 'Mails' : 'Faxe') . ' versenden' .
	     (defined $reason && $reason ne '' ?
	      ". Grund: $reason" : ""),
	    );
	return;
    }

    my $t = redisplay_top($top, $type, -title => $typename);
    return if !defined $t;
    my $row = 0;
    $t->Label(-text => "$typename an" . ($type eq 'fax' ? " (Faxnummer)" : "")
	      . ":")->grid(-row => $row,
			   -column => 0,
			   -sticky => "e");
    my $e;
    if ($type eq 'mail') {
	my $mail_alias;
	eval {
	    require Mail::Alias;
	    require Tk::BrowseEntry;
	    $mail_alias = new Mail::Alias::Ucbmail;
	    $mail_alias->read("$ENV{HOME}/.mailrc");
	};
	if (!$@ && $mail_alias) {
	    $e = $t->BrowseEntry(-textvariable => \$to);
	    my @alias;
	    while(my($k,$v) = each %$mail_alias) {
		foreach (@$v) {
		    push @alias, @{ $mail_alias->expand($_) }
		}
	    }
	    $e->insert("end", sort { lc($a) cmp lc($b) } @alias);
	}
    }
    if (!$e) {
	$e = $t->Entry(-textvariable => \$to);
    }
    $e->grid(-row => $row,  -column => 1, -sticky => "w");
    $e->tabFocus;
    $row++;
    my $comment_txt;
    if ($type ne 'fax') {
	$t->Label(-text => "Subject")->grid(-row => $row,
					    -column => 0,
					    -sticky => "e");
	$t->Entry(-textvariable => \$subject)->grid(-row => $row,
						    -column => 1,
						    -sticky => "w");

	$row++;
	$t->Label(-text => "zusätzlicher Text:")->grid(-row => $row,
						       -column => 0,
						       -sticky => "ne");
	$comment_txt = $t->Scrolled('Text', -scrollbars => "osoe",
				    -width => 40,
				    -height => 5,
				   )->grid(-row => $row,
					   -column => 1);
    }
    my $close_window = sub { $t->destroy;};
    my $apply_window = sub {
	if ($type eq 'mail') {
	    if (defined $to && $to ne '' &&
		defined $subject && $subject ne '') {
		if ($comment_txt) {
		    $data = $data . "\n" . $comment_txt->get("1.0", "end");
		}
		send_mail($to, $subject, $data);
	    }
	} else {
	    if (defined $to && $to ne '') {
		send_fax($to, undef, $data);
	    }
	}
    };
    my $ok_window    = sub {
	&$apply_window;
	&$close_window;
    };
    $row++;
    my $bf = $t->Frame->grid(-row => $row, -column => 0,
			     -columnspan => 2);
    my $okb = $bf->Button
      (Name => 'ok',
       -command => $ok_window)->grid(-row => 0, -column => 0,
				     -sticky => 'ew');
    my $cb = $bf->Button
      (Name => 'cancel',
       -command => $close_window)->grid(-row => 0, -column => 1,
					-sticky => 'ew');

    $t->bind('<Return>' => sub { $okb->invoke });
    $t->bind('<Escape>' => sub { $cb->invoke });

    $t->Popup(@popup_style);
}

sub send_mail {
    my($to, $subject, $data, %args) = @_;
    my $cc = delete $args{CC};
    warn "Extra arguments: " . join(" ", %args) if %args;
    eval {
	require Mail::Send;
	require Mail::Mailer;
	Mail::Mailer->VERSION(1.53);
	my $msg = new Mail::Send Subject => $subject, To => $to;
	$msg->add("MIME-Version", "1.0");
	$msg->add("Content-Type", "text/plain; charset=ISO-8859-1");
	$msg->add("Content-Transfer-Enconding", "8bit");
	$msg->add("CC", $cc) if $cc;
	my $fh = $msg->open;
	print $fh $data;
	$fh->close;
    };
    if ($@) {
	$top->bell;
	status_message("Fehler: $@\nMöglicherweise ist kein Mailprogramm vorhanden.\nFür das Versenden von Mails ist das Modul Mail::Send erforderlich.\n", 'error');
    }
}

sub send_fax {
    my($to, $subject, $data) = @_;
    eval {
	require Fax::Send;
	my $msg = new Fax::Send
	  -recipients => $to,
	  -data => $data;
	$msg->send;
    };
    if ($@) {
	$top->bell;
	status_message("Fehler: $@\nMöglicherweise ist kein Faxprogramm vorhanden.\nFür das Versenden von FAXen XXX ist das Modul Fax::Send\nund ein Faxprogramm wie hylafax oder mgetty+sendfax erforderlich.\n", 'error');
    }
}

sub capabilities {
    eval {
	require Mail::Send;
	require Mail::Mailer;
	Mail::Mailer->VERSION(1.53); # previous versions were unreliable
	$can_send_mail = 1;
    };
    if (!$can_send_mail) {
	$cannot_send_mail_reason = $@;
    }
    eval {
	require Fax::Send;
	$can_send_fax  = 1;
    };
    if (!$can_send_fax) {
	$cannot_send_fax_reason = $@;
    }
}

# peacify -w
$main::top = $main::top if 0;

1;
