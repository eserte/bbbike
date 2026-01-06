#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2003-2011,2026 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

use strict;
use vars qw($realbin);
use Cwd qw(realpath);
use File::Basename;
BEGIN { # taint fixes
    ## FindBin does not work with modperl
    #($realbin) = $FindBin::RealBin =~ /^(.*)$/;
    ($realbin) = dirname(realpath($0)) =~ /^(.*)$/;
    $ENV{PATH} = "/usr/bin:/usr/sbin:/bin:/sbin";
}
# from bbbike.cgi
use lib (grep { -d }
	 (#"/home/e/eserte/src/bbbike",
	  "$realbin/..", # falls normal installiert
	  "$realbin/../BBBike", # falls in .../cgi-bin/... installiert
	  "$realbin/BBBike", # weitere Alternative
	 )
	);
use BBBikeVar;
use BBBikeCGI::Util qw();
use Data::Dumper;
use CGI ();
use CGI::Carp;
use vars qw($debug $bbbike_url $bbbike_root $bbbike_html $use_cgi_bin_layout
	    @MIME_Lite_send $email_module);

eval {
    local $SIG{'__DIE__'};
    #warn "$0.config";
    do "$realbin/bbbike.cgi.config";
};
warn $@ if $@;

use vars qw($to $cc $comment);

sub newstreetform_extra_html ($$);

if (!defined $email_module) {
    $email_module = 'MIME::Lite';
}

return 1 if caller;

my $q;

eval {
    undef $to;
    undef $cc;
    undef $comment;

    $q = CGI->new;

    {
	my $f = "$realbin/Botchecker_BBBike.pm";
	if (-r $f) {
	    eval {
		local $SIG{'__DIE__'};
		do $f;
		Botchecker_BBBike::run($q);
	    };
	    warn $@ if $@;
	}
    }

    # from bbbike.cgi:
    $bbbike_url = BBBikeCGI::Util::my_url($q);
    ($bbbike_root = $bbbike_url) =~ s|[^/]*/[^/]*$|| if !defined $bbbike_root;
    if (!defined $bbbike_html) {
	$bbbike_html   = "$bbbike_root/" . ($use_cgi_bin_layout ? "BBBike/" : "") .
	    "html";
    }

    $to = $BBBike::EMAIL;
    # no $cc needed by default, I have the logfile
    my $mscgi_remote = $BBBike::BBBIKE_MAPSERVER_URL;
    my $mscgi_local  = "http://www/~eserte/cgi/mapserv.cgi";
    my $msadrcgi_remote = dirname($BBBike::BBBIKE_MAPSERVER_URL) . "/mapserver_address.cgi";
    my $msadrcgi_local = "http://www/~eserte/bbbike/cgi/mapserver_address.cgi";

    if ($debug) {
	require Sys::Hostname;
	if (Sys::Hostname::hostname() =~ /herceg\.de$/) {
	    $to = "eserte\@smtp.herceg.de";
	    $cc = "slaven\@smtp.herceg.de";
	}
    }

    my $encoding = $q->param("encoding");
    if ($encoding && $encoding !~ m{^(utf-8|iso-8859-1)$}) {
	undef $encoding;
    }
    if ($encoding && eval { require Encode; 1 }) {
	for my $key ($q->param) {
	    $q->param($key, Encode::decode($encoding, scalar $q->param($key)));
	}
    }

    my $email  = $q->param('email');
    my $author = $q->param('author');
    my $by     = $author || $email;
    my $by_long = $author ? $author . ($email ? " <$email>" : "") : $email ? $email . ($author ? " ($author)" : "") : "unknown";

    my $subject = $q->param("subject") || "BBBike-Kommentar";
    if ($by) {
	$subject .= " von $by";
    }

    my $mapx = $q->param("mapx");
    my $mapy = $q->param("mapy");

    my($link1, $link2);
    if ($q->param("routelink")) {
	$link1 = $q->param("routelink");
	($link2 = $link1) =~ s{^http://[^/]+/cgi-bin/}{http://localhost/bbbike/cgi/}; # guess local link for bbbikegooglemap, may be wrong
    } elsif (defined $mapx && defined $mapy) {
	my $coords_esc = CGI::escape(join(",", map { int } ($mapx, $mapy)));
	$link1 = "$msadrcgi_remote?coords=$coords_esc";
	$link2 = "$msadrcgi_local?coords=$coords_esc";
    }

    my $plain_body = "";
    my $add_html_body;
    my $add_bbd;

    {
	my @add_bbd;
	for my $key ($q->param) {
	    if ($key =~ m{^wpt\.\d+}) {
		my($comment, $xy) = split /!/, $q->param($key);
		$comment =~ s{[\t\n]}{ }g;
		push @add_bbd, "$comment\tWpt $xy";
	    }
	}
	if ($q->param("route")) {
	    my(@points) = split / /, $q->param("route");
	    my $bbd_comment = $q->param("comment") || "<no comment>";
	    $bbd_comment =~ s{[\t\n]}{ }g;
	    push @add_bbd, "$bbd_comment\tRte @points";
	}
	if (@add_bbd) {
	    unshift @add_bbd,
		("#: map: polar",
		 "#: encoding: utf-8",
		 "#: category_color.Wpt: #ff0000",
		 "#: category_color.Rte: #0000ff",
		 "#:",
		 "#: by: $by_long vvv",
		);
	    push @add_bbd,
		("#: by: ^^^");
	    $add_bbd = join("\n", @add_bbd) . "\n";
	}
    }

    if ($q->param("formtype") && $q->param("formtype") =~ /^(newstreetform|fragezeichenform)$/) {
	open(BACKUP, ">>/tmp/newstreetform-backup-$<")
	    or warn "Cannot write backup data for newstreetform: $!";
	print BACKUP "-" x 70, "\n";
	print BACKUP scalar localtime;
	print BACKUP "\n";
	my $data = {};
	for my $param ($q->param) {
	    my @val = BBBikeCGI::Util::my_multi_param($param);
	    if (@val == 1) {
		$data->{$param} = $val[0];
	    } else {
		$data->{$param} = \@val;
	    }
	    next if (@val == 0 || (@val == 1 && $val[0] eq '') && $param !~ /^supplied/);
	    my $dump = Data::Dumper->new([$data->{$param}],[$param])->Indent(1)->Useqq(1)->Dump;
	    print BACKUP $dump;
	    $plain_body .= $dump;
	}
	my $dump = Data::Dumper->new([\%ENV],['ENV'])->Indent(1)->Useqq(1)->Dump;
	print BACKUP $dump;
	$plain_body .= $dump;
	close BACKUP;

	{
	    no warnings 'uninitialized'; # strname may be empty
	    if ($data->{strname} !~ m{^\s*$}) {
		$subject .= ": $data->{strname}";
	    }
	}
	$subject = substr($subject, 0, 70) . "..." if length $subject > 70;

	my $is_spam = length $q->param('url');
	$subject = "SPAM: $subject" if $is_spam;

	eval {

	    my $extra_html = newstreetform_extra_html
		($data, {Subject => $subject,
			 To => $email,
			});

	    require Template;
	    my $t = Template->new({ RELATIVE => 1,
				    ABSOLUTE => 1,
				  });
	    my $vars = { data => $data,
			 extra_html => $extra_html,
			 bbbikecss => "http://bbbike.de/BBBike/html/bbbike.css",
		       };
	    my $htmltpl = "$realbin/../html/newstreetform.tpl.html";
	    die "Can't read <$htmltpl>" if !-r $htmltpl;
	    $t->process($htmltpl, $vars, \$add_html_body)
		or die $t->error;
	};
	if ($@) {
	    $plain_body .= "\nERROR processing template: $@";
	}

    } elsif ($q->param("formtype") && $q->param("formtype") eq 'bbbikeroute') { # note: this was planned to be used by bbbike_comment.cgi, which does not exist
	$comment =
	    "Von: $by_long\n" .
	    "An:  $to\n\n" .
	    "Kommentar:\n" .
	    $q->param("comment") . "\n" .
	    "Query: " . $q->param("query") . "\n";
	$plain_body .= $comment . "\n";
	$link1 = $bbbike_url . "?" . $q->param("query");
	$link2 = "http://www/bbbike/cgi/bbbike.cgi?" . $q->param("query");
	$plain_body .= "Remote: " . $link1 . "\n";
	$plain_body .= "Lokal:  " . $link2 . "\n";
	$plain_body .= "\n" . Data::Dumper->new([\%ENV],['ENV'])->Indent(1)->Useqq(1)->Dump;

	my $is_spam = length param('url');
	$subject = "SPAM: $subject" if $is_spam;
    } elsif (
	     $q->request_method() eq 'OPTIONS' &&
	     ($q->http('origin')||'') =~ m{^https?://localhost(:\d+)?}
	    ) {
	# CORS handling, part one - a Preflighted request
	print $q->header(
		         -Access_Control_Allow_Origin => $q->http('origin'),
		         -Access_Control_Allow_Methods => 'POST, GET, OPTIONS',
		        );
	exit;
    } else {
	my $comment_param = $q->param("comment");
	$comment_param = '' if !defined $comment_param;
	if (!$author && !$email && $comment_param eq '' && !$add_bbd) {
	    empty_msg(); # exits
	}
	$comment =
	    "Von: $by_long\n" .
	    "An:  $to\n\n" .
	    (defined $mapx ? "Kartenkoordinaten: " . int($mapx) . "," . int($mapy) . "\n\n" : "") .
	    "Kommentar:\n" .
	    $comment_param . "\n";
	$plain_body .= $comment . "\n";
	$plain_body .= "Remote: " . $link1 . "\n" if defined $link1;
	$plain_body .= "Lokal:  " . $link2 . "\n" if defined $link2;
	$plain_body .= "\n" . Data::Dumper->new([\%ENV],['ENV'])->Indent(1)->Useqq(1)->Dump;
	if ($q->request_method eq 'POST') {
	    $plain_body .= "\nPOST Vars:\n";
	    for my $key ($q->param) {
		$plain_body .= Data::Dumper->new([BBBikeCGI::Util::my_multi_param($key)],[$key])->Indent(1)->Useqq(1)->Dump;
	    }
	}

	no warnings 'uninitialized'; # url param may be undef
	my $is_spam = length $q->param('url');
	$subject = "SPAM: $subject" if $is_spam;
    }

    my $mailout = $q->param('mailout');

    my $is_multipart = ((defined $add_html_body && $add_html_body ne "") ||
			(defined $add_bbd       && $add_bbd ne ""));
    $subject = substr($subject, 0, 70) . "..." if length $subject > 70;

    my($subject_mime, $to_mime, $cc_mime, $encoded_plain_body) =
	($subject, $to, $cc, $plain_body);
    my $charset = "iso-8859-1";
    if (eval { require Encode; 1 }) {
	for ($subject_mime) {
	    $_ = Encode::encode("MIME-B", $_)
		if defined $_;
	}
	if (defined $plain_body) {
	    $encoded_plain_body = Encode::encode("utf-8", $encoded_plain_body);
	    $charset = "utf-8";
	}
    }
    my $email_mime = extract_email($email);

    my $add_html_body_bytes;
    if (defined $add_html_body && $add_html_body ne "") {
	if (eval { require Encode; 1 }) {
	    $add_html_body_bytes = Encode::encode("utf-8", $add_html_body);
	} else {
	    $add_html_body_bytes = $add_html_body;
	}
    }

    my $add_bbd_bytes;
    if (defined $add_bbd && $add_bbd ne "") {
	if (eval { require Encode; 1 }) {
	    $add_bbd_bytes = Encode::encode("utf-8", $add_bbd);
	} else {
	    $add_bbd_bytes = $add_bbd;
	}
    }

    if ($email_module eq 'Email::MIME') {
	require Email::MIME;
	require Email::Sender::Simple;

	my @parts = (
	    Email::MIME->create(
		attributes => {
		    content_type => "text/plain",
		    charset      => $charset,
		    encoding     => 'quoted-printable',
		},
		body => $encoded_plain_body,
	    ),
	);
	if (defined $add_html_body_bytes) {
	    push @parts, Email::MIME->create(
		attributes => {
		    content_type => 'text/html',
		    charset      => 'utf-8',
		    filename     => 'newstreetform.html',
		    encoding     => 'quoted-printable',
		},
		body => $add_html_body_bytes,
	    );
	}
	if (defined $add_bbd_bytes) {
	    push @parts, Email::MIME->create(
		attributes => {
		    content_type => 'application/x-bbbike-data',
		    filename     => 'comment.bbd',
		    Encoding     => 'quoted-printable',
		},
		body => $add_bbd_bytes,
	    );
	}

	my $email = Email::MIME->create(
	    header_str => [
		Subject => $subject,
		To      => $to,
		(defined $cc ? (Cc => $cc) : ()),
		From    => $to,
		Comments => 'Generated by ' . basename($0) . ' (Email::MIME)',
	    ],
	    parts => [ @parts ],
	);

	if ($mailout) {
	    binmode STDERR;
	    print STDERR $email->as_string;
	} else {
	    Email::Sender::Simple->send($email);
	}
    } else {
	require MIME::Lite;

	my $msg = MIME::Lite->new(Subject => $subject_mime,
				  To      => $to_mime,
				  (defined $cc_mime ? (Cc => $cc_mime) : ()),
				  ($email_mime ? ("Reply-To" => $email_mime) : ()),
				  ($is_multipart
				   ? (Type => "multipart/mixed")
				   : (Type => "text/plain; charset=$charset",
				      Data => $encoded_plain_body,
				     )
			          ),
				  Sender   => $to_mime, # to satisfy some mailers like exim
				  Comments => 'Generated by ' . basename($0) . ' (MIME::Lite)',
			         );
	if (!$msg) {
	    die "Kann kein MIME::Lite-Objekt erzeugen. Body war:\n$plain_body\n";
	}

	if ($is_multipart) {
	    $msg->attach(Type => "text/plain; charset=$charset",
			 Data => $encoded_plain_body,
		     );
	    if (defined $add_html_body_bytes) {
		$msg->attach(Type => "text/html; charset=utf-8",
			     Data => $add_html_body_bytes,
			     Filename => "newstreetform.html",
			     Encoding => 'quoted-printable',
			 );
	    }
	    if (defined $add_bbd_bytes) {
		$msg->attach(Type => "application/x-bbbike-data",
			     Data => $add_bbd_bytes,
			     Filename => "comment.bbd",
			     Encoding => "quoted-printable",
			 );
	    }
	}

	if ($mailout) {
	    binmode STDERR;
	    print STDERR $msg->as_string;
	} else {
	    my @send_args = @MIME_Lite_send;
	    $msg->send(@send_args)
		or die "Can't send mail with args <@send_args>. Body was:\n$plain_body\n";
	}
    }

    my $cookie = $q->cookie(
			-name => 'mapserver_comment',
			-value => { email => $email,
				    author => $author,
				  },
			-path => "/",
			-expires => "+1y",
		       );
    if ($q->param("formtype") && $q->param("formtype") =~ /^(newstreetform|fragezeichenform)$/) {
	my $dir = defined $bbbike_html ? $bbbike_html : "..";
	my $url = "$dir/newstreetform.html";
	my $bbbikegooglemapsurl;
	if ($q->param("supplied_coord")) {
	    $bbbikegooglemapsurl = "$BBBike::BBBIKE_GOOGLEMAP_URL?" .
		CGI->new({
		    wpt         => scalar $q->param("supplied_coord"),
		    coordsystem => "bbbike",
		    maptype     => "hybrid",
		    mapmode     => "addroute",
		    zoom        => 17,
		})->query_string;
	}
	print $q->header(-cookie => $cookie),
	    $q->start_html(-title=>"Neue Straße für BBBike",
		           -style=>{'src'=>"$bbbike_html/bbbike.css"}),
	    "Danke, die Angaben wurden an ", $q->a({-href => "mailto:$to"}, $to), " gesendet.",$q->br(),$q->br(),
	    (defined $bbbikegooglemapsurl ?
	     ($q->a({-href => $bbbikegooglemapsurl}, "Weitere Kommentare zu dieser Straße auf einer Karte eintragen"),$q->br(),$q->br()) :
	     ()
	    ),
	    $q->a({-href => $url}, "Weitere Straße eintragen"),
	    $q->end_html;
    } else {
	my $origin = $q->http('origin');
	print $q->header
	    	    (
		     -cookie => $cookie,
		     # CORS handling, part two
		     ($origin && $origin =~ m{^https?://localhost(:\d+)?} ? (-Access_Control_Allow_Origin => $origin) : ()),
		    ),
	    $q->start_html(-title=>"Kommentar abgesandt",
		           -style=>{'src'=>"$bbbike_html/bbbike.css"}),
	    "Danke, der folgende Kommentar wurde an " . BBBikeCGI::Util::my_escapeHTML($to) . " gesendet:",$q->br(),$q->br(),
	    $q->pre(BBBikeCGI::Util::my_escapeHTML($comment)),
	    $q->end_html;
    }
};
if ($@) {
    warn "Could not send mail: $@\nMail content:\n$comment\n";
    error_msg($@);
}

sub error_msg {
    print($q->header,
	  $q->start_html(-title=>"Fehler beim Versenden",
		         -style=>{'src'=>"$bbbike_html/bbbike.css"}),
	  "Der Kommentar konnte wegen eines internen Fehlers nicht abgesandt werden. Bitte stattdessen eine Mail an ",
	  $q->a({-href=>"mailto:$to?" . CGI->new({subject => "BBBike-Kommentar (fallback)",
					      body=>$comment})->query_string},$to),
	  " mit dem folgenden Inhalt versenden:",$q->br(),$q->br(),
	  $q->pre($comment),
	  $q->end_html,
	 );
    exit;
}

sub empty_msg {
    print($q->header,
	  $q->start_html(-title=>'Fehler beim Versenden',
		         -style=>{'src'=>"$bbbike_html/bbbike.css"}),
	  "Bitte einen Kommentar angeben.",$q->br(),
	  $q->a({-href=>'javascript:history.back()'},'Zurück'),
	  $q->end_html,
	 );
    exit;
}

sub newstreetform_extra_html ($$) {
    my($data, $header) = @_;
    my $extra_html = "";

    my $strname = $data->{supplied_strname} || "";
    my $name = $data->{author};
    if (!$name) {
	($name = $data->{email}) =~ s{\@.*}{...};
    }
    if (!$name) {
	$name = "anonymous";
    }
    my $cat_text = $data->{Qdesc_1} || "";
    my $cat = $data->{Qcat_1} || "";
    my $bbd_suggestion = <<EOF;
#: by: $name:
$strname: $cat_text\t$cat 
EOF

    $extra_html .= "<textarea rows='4' cols='80'>" . BBBikeCGI::Util::my_escapeHTML($bbd_suggestion) . "</textarea><br>";

    my $reply_to = $header->{To};
    my $cc = $BBBike::EMAIL;
    my $body =<<EOF;
Hallo $name,

danke für deinen Eintrag. Die Straße "$strname" wird demnächst bei BBBike verfügbar sein.

Gruß,

EOF
    my $subject = "Re: $header->{Subject}";
    $extra_html .= <<EOF;
<hr>Antwort-Mail:<br>
EOF
    my $mailto_link = "mailto:$reply_to?";
    CGI->import('-oldstyle_urls');
    $body =~ s{\n}{ \r\n}g; # really?
    # This hack is needed for Mozilla Mail
    require Encode;
    Encode::from_to($body, "iso-8859-1", "utf-8");
    Encode::from_to($subject, "iso-8859-1", "utf-8");
    my $q = CGI->new({subject => $subject,
		      ($cc ? (cc => $cc) : ()),
		      body => $body,
		     });
    $mailto_link .= $q->query_string;

    $extra_html .= <<EOF;
<div><a href="$mailto_link">Mail per Browser-Mailprogramm eingeben und senden</a></div>
EOF
    $extra_html;
}

# Simple extractor, may extract invalid email addresses,
# main point is to strip possible whitespace and keep
# only ascii-like characters.
sub extract_email {
    my($text) = @_;
    $text =~ /([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})/ ? $1 : undef;
}

=head1 NAME

mapserver_comment.cgi - send comments about BBBike

=head1 SYNOPSIS

none

=head1 DESCRIPTION

Send comments about BBBike data via email. The receiver is the
C<$EMAIL> address in L<BBBikeVar>.

In former days, this script was meant only for Mapserver comments, but
in the meantime it is used in all parts of the BBBike ecosystem: still
it's used for comments created in BBBike's Mapserver interface, but
also for comments about routes created in the bbbikegooglemap CGI, and
comments created in the "newstreet" and "fragezeichen" forms.

=head2 CGI parameters

The following CGI parameters are processed:

=over

=item email

The e-mail address of the sender.

=item author

The full name of the sender.

=item subject

The subject for the Mail. It defaults to "BBBike-Kommentar".

=item mapx

=item mapy

The coordinates for which point the comment applies as BBBike standard
coordinates.

=item routelink

A link to the bbbikegooglemap CGI with a route definition. This takes
precedence over mapx/mapy.

=item route

The space-separated coordinates of a route. Will be usually appended
to the mail as an attachment in B<bbd> format.

=item formtype (optional)

May be B<newstreetform> (if coming from the newstreetform.html
formular), B<fragezeichenform> (if coming from the
fragezeichenform.html formular), B<bbbikeroute> (if coming from
bbbike_comment.cgi, not yet used), or nothing.

=item comment

The actual comment.

=item encoding (optional)

May be B<iso-8859-1> or B<utf-8>. If set, then this is the encoding of
all CGI parameters.

=item

=back

Further parameters will be dumped to a local file if the formtype is
either B<newstreetform> or B<fragezeichenform>.

=head2 Configuration

To define the mail sending method, set the C<@MIME_Lite_send>
variable in C<bbbike.cgi.config>. The value of this variable is the
same as the arguments of the C<send> method of L<MIME::Lite>. To
define an SMTP server, use the following:

    @MIME_Lite_send = ("smtp", "mail.example.com");

By default L<MIME::Lite> uses system's L<sendmail(8)>.

=head1 AUTHOR

Slaven Rezic

=cut
