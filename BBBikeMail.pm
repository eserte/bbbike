# -*- perl -*-

#
# $Id: BBBikeMail.pm,v 1.21 2008/01/20 22:43:25 eserte Exp $
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
	    $can_send_mail $can_send_mail_via_Mail_Mailer $can_send_fax
	    $cannot_send_mail_via_Mail_Mailer
	    $cannot_send_mail_reason $cannot_send_fax_reason);

*top = \$main::top;
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

    if ($type eq 'mail' && $args{-to}) {
	# Note that send_mail_via_browser does not always work very
	# well if -to is missing.
 	if ($^O eq 'MSWin32' || !$can_send_mail_via_Mail_Mailer) {
 	    send_mail_via_browser($args{-to}, $subject, $args{-data});
 	    return;
 	}
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
		return 1; # usually cannot check send_mail success
	    } else {
		main::status_message("Bitte Empfänger und Subject angeben!", "err");
		return 0;
	    }
	} else {
	    if (defined $to && $to ne '') {
		send_fax($to, undef, $data);
		return 1; # XXX is it possible to check send_fax return value?
	    } else {
		main::status_message("Bitte Empfänger angeben!", "err");
		return 0;
	    }
	}
    };
    my $ok_window    = sub {
	my $success = &$apply_window;
	&$close_window if $success;
    };
    $row++;
    my $bf = $t->Frame->grid(-row => $row, -column => 0,
			     -columnspan => 2);
    my $okb = $bf->Button
      (Name => 'ok',
       -command => $ok_window)->grid(-row => 0, -column => 0,
				     -sticky => 'ew');
    if ($Tk::VERSION >= 800) {
	$okb->configure(-default => "disabled");
    }
    my $cb = $bf->Button
      (Name => 'cancel',
       -command => $close_window)->grid(-row => 0, -column => 1,
					-sticky => 'ew');

    ## No! Otherwise it's not possible to use <Return> in the
    ## text field!
    #$t->bind('<Return>' => sub { $okb->invoke });
    $t->bind('<Escape>' => sub { $cb->invoke });

    $t->Popup(@popup_style);
}

sub send_mail {
    my(@args) = @_;
    capabilities();
    if ($^O eq 'MSWin32' || !$can_send_mail_via_Mail_Mailer) {
	send_mail_via_browser(@args);
    } else {
	send_mail_via_Mail_Mailer(@args);
    }
}

sub send_mail_via_Mail_Mailer {
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
	$msg->add("Comments", "generated by BBBikeMail.pm BBBike/$BBBike::VERSION"
		  . (defined $main::PROG_REVISION ? " (prog revision " .$main::PROG_REVISION.")" : "")
		  . " (OS=$^O)"
		 );
	my $fh = $msg->open;
	print $fh $data;
	$fh->close;
    };
    if ($@) {
	$top->bell;
	status_message("Fehler: $@\nMöglicherweise ist kein Mailprogramm vorhanden.\nFür das Versenden von Mails ist das Modul Mail::Send erforderlich.\n", 'error');
    }
}

sub send_mail_via_browser {
    # Tested with linux-mozilla 1.7 and FreeBSD's seamonkey 1.0.5
    my($to, $subject, $data, %args) = @_;
    require WWWBrowser;
    require CGI;
    CGI->import('-oldstyle_urls');
    my $url = "mailto:";
    $url .= $to if defined $to && $to !~ m{^\s*$};
    $url .= "?" . CGI->new({subject=>$subject,
			    body=>$data,
			    ($args{CC} ? (cc=>$args{CC}) : ()),
			   })->query_string;
    $main::devel_host = $main::devel_host if 0; # cease -w
    if ($main::devel_host) {
	warn "Sende URL <$url> zum Browser...\n";
    }
    WWWBrowser::start_browser($url);
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
    $can_send_mail = 1; # via browser
    eval {
	die "Specified to not use Mail::Mailer via variable \$cannot_send_mail_via_Mail_Mailer"
	    if $cannot_send_mail_via_Mail_Mailer;
	require Mail::Send;
	require Mail::Mailer;
	Mail::Mailer->VERSION(1.53); # previous versions were unreliable
	$can_send_mail_via_Mail_Mailer = 1;
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
