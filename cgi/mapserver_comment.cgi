#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2003-2010 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
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
use BBBikeCGIUtil qw();
use Data::Dumper;
use MIME::Lite;
use CGI qw(:standard -no_xhtml);
use CGI::Carp;
use vars qw($debug $bbbike_url $bbbike_root $bbbike_html $use_cgi_bin_layout
	    @MIME_Lite_send);

eval {
    local $SIG{'__DIE__'};
    #warn "$0.config";
    do "$realbin/bbbike.cgi.config";
};
warn $@ if $@;

use vars qw($to $cc $comment);

sub newstreetform_extra_html ($$);

eval {
    undef $to;
    undef $cc;
    undef $comment;

    # from bbbike.cgi:
    $bbbike_url = BBBikeCGIUtil::my_url(CGI->new);
    ($bbbike_root = $bbbike_url) =~ s|[^/]*/[^/]*$|| if !defined $bbbike_root;
    if (!defined $bbbike_html) {
	$bbbike_html   = "$bbbike_root/" . ($use_cgi_bin_layout ? "BBBike/" : "") .
	    "html";
    }

    $to = $BBBike::EMAIL;
    #$cc = 'eserte@web.de'; 
    #$cc = 'newstreet@bbbike.de'; # XXX not valid anymore
    # no $cc needed by default, I have the logfile
    my $mscgi_remote = $BBBike::BBBIKE_MAPSERVER_URL;
    my $mscgi_local  = "http://www/~eserte/cgi/mapserv.cgi";
    my $msadrcgi_remote = dirname($BBBike::BBBIKE_MAPSERVER_URL) . "/mapserver_address.cgi";
    my $msadrcgi_local = "http://www/~eserte/bbbike/cgi/mapserver_address.cgi";

    if ($debug) {
	require Sys::Hostname;
	if (Sys::Hostname::hostname() =~ /herceg\.de$/) {
	    require Config;
	    if ($Config::Config{archname} =~ /amd64/) {
		#$to = "slaven\@rezic.de";
		#$cc = "slaven\@rezic.de";
		$to = "eserte";
		$cc = "eserte";
	    } else {
		$to = "eserte\@smtp.herceg.de";
		$cc = "slaven\@smtp.herceg.de";
	    }
	}
    }

    my $encoding = param("encoding");
    if ($encoding && $encoding !~ m{^(utf-8|iso-8859-1)$}) {
	undef $encoding;
    }
    if ($encoding && eval { require Encode; 1 }) {
	for my $key (param) {
	    param($key, Encode::decode($encoding, param($key)));
	}
    }

    my $email  = param('email');
    my $author = param('author');
    my $by     = $author || $email;
    my $by_long = $author ? $author . ($email ? " <$email>" : "") : $email ? $email . ($author ? " ($author)" : "") : "unknown";

    my $subject = param("subject") || "BBBike-Kommentar";
    if ($by) {
	$subject .= " von $by";
    }

    my $mapx = param("mapx");
    my $mapy = param("mapy");

    my($link1, $link2);

    if (0) {
	# XXX link query is different for remote server
	# XXX supply also the image extents?
	my $link_query = "mapxy=" . CGI::escape("$mapx $mapy") . "&layer=qualitaet&layer=handicap&layer=radwege&layer=bahn&layer=gewaesser&layer=flaechen&layer=grenzen&layer=orte&layer=route&mode=nquery&map=%2Fhome%2Fe%2Feserte%2Fsrc%2Fbbbike%2Fmapserver%2Fbrb%2Fbrb.map&program=%2F%7Eeserte%2Fcgi%2Fmapserv.cgi";

	my($map_width,$map_height) = (4000, 4000); # meters
	my($img_width,$img_height) = (550, 550); # pixels

	my($minx,$maxx,$miny,$maxy) = ($mapx-$map_width/2, $mapx+$map_width/2,
				       $mapy-$map_height/2, $mapy+$map_height/2);
	$link_query="map=%2Fhome%2Fe%2Feserte%2Fsrc%2Fbbbike%2Fmapserver%2Fbrb%2Fbrb.map&mode=browse&zoomdir=0&zoomsize=2&imgxy=" . CGI::escape($img_width/2 . " " . $img_height/2) . "&imgext=" . CGI::escape("$minx $miny $maxx $maxy") . "&program=%2F%7Eeserte%2Fcgi%2Fmapserv.cgi";

	$link1 = "$mscgi_remote?$link_query";
	$link2 = "$mscgi_local?$link_query";
    } else {
	if (defined $mapx && defined $mapy) {
	    my $coords_esc = CGI::escape(join(",", map { int } ($mapx, $mapy)));
	    $link1 = "$msadrcgi_remote?coords=$coords_esc";
	    $link2 = "$msadrcgi_local?coords=$coords_esc";
	}
    }
    if (param("routelink")) {
	$link1 = param("routelink");
	($link2 = $link1) =~ s{http://[^/]+/cgi-bin/}{http://localhost/bbbike/cgi/}; # guess local link for bbbikegooglemap, may be wrong
    }

    my $plain_body = "";
    my $add_html_body;
    my $add_bbd;
    my $need_bbbike_css = 0;

    {
	my @add_bbd;
	for my $key (param) {
	    if ($key =~ m{^wpt\.\d+}) {
		my($comment, $xy) = split /!/, param($key);
		$comment =~ s{[\t\n]}{ }g;
		push @add_bbd, "$comment\tWpt $xy";
	    }
	}
	if (param("route")) {
	    my(@points) = split / /, param("route");
	    my $bbd_comment = param("comment") || "<no comment>";
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

    if (param("formtype") && param("formtype") =~ /^(newstreetform|fragezeichenform)$/) {
	open(BACKUP, ">>/tmp/newstreetform-backup")
	    or warn "Cannot write backup data for newstreetform: $!";
	print BACKUP "-" x 70, "\n";
	print BACKUP scalar localtime;
	print BACKUP "\n";
	my $data = {};
	for my $param (param) {
	    my $val = param($param);
	    $data->{$param} = $val;
	    next if $val eq '' && $param !~ /^supplied/;
	    my $dump = Data::Dumper->new([$val],[$param])->Indent(1)->Useqq(1)->Dump;
	    print BACKUP $dump;
	    $plain_body .= $dump;
	}
	my $dump = Data::Dumper->new([\%ENV],['ENV'])->Indent(1)->Useqq(1)->Dump;
	print BACKUP $dump;
	$plain_body .= $dump;
	close BACKUP;

	if ($data->{strname} !~ m{^\s*$}) {
	    $subject .= ": $data->{strname}";
	}
	$subject = substr($subject, 0, 70) . "..." if length $subject > 70;

	my $is_spam = length param('url');
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
			 # bbbikecss => "cid:bbbike.css", # XXX see below
		       };
	    $need_bbbike_css = 1;
	    #my $htmltpl = "$FindBin::RealBin/../html/newstreetform.tpl.html";
	    my $htmltpl = "$realbin/../html/newstreetform.tpl.html";
	    #warn $htmltpl;
	    die "Can't read <$htmltpl>" if !-r $htmltpl;
	    $t->process($htmltpl, $vars, \$add_html_body)
		or die $t->error;
	};
	if ($@) {
	    $plain_body .= "\nERROR processing template: $@";
	}

    } elsif (param("formtype") && param("formtype") eq 'bbbikeroute') {
	$comment =
	    "Von: $by_long\n" .
	    "An:  $to\n\n" .
	    "Kommentar:\n" .
	    param("comment") . "\n" .
	    "Query: " . param("query") . "\n";
	$plain_body .= $comment . "\n";
	$link1 = $bbbike_url . "?" . param("query");
	$link2 = "http://www/bbbike/cgi/bbbike.cgi?" . param("query");
	$plain_body .= "Remote: " . $link1 . "\n";
	$plain_body .= "Lokal:  " . $link2 . "\n";
	$plain_body .= "\n" . Data::Dumper->new([\%ENV],['ENV'])->Indent(1)->Useqq(1)->Dump;
    } else {
	my $comment_param = param("comment");
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
	if (request_method eq 'POST') {
	    $plain_body .= "\nPOST Vars:\n";
	    for my $key (param) {
		$plain_body .= Data::Dumper->new([param($key)],[$key])->Indent(1)->Useqq(1)->Dump;
	    }
	}
    }

    my $is_multipart = ((defined $add_html_body && $add_html_body ne "") ||
			(defined $add_bbd       && $add_bbd ne ""));
    $subject = substr($subject, 0, 70) . "..." if length $subject > 70;

    my($subject_mime, $to_mime, $cc_mime, $email_mime, $encoded_plain_body) =
	($subject, $to, $cc, $email, $plain_body);
    my $charset = "iso-8859-1";
    if (eval { require Encode; 1 }) {
	for ($subject_mime, $to_mime, $cc_mime, $email_mime) {
	    $_ = Encode::encode("MIME-B", $_)
		if defined $_;
	}
	if (defined $plain_body) {
	    $encoded_plain_body = Encode::encode("utf-8", $encoded_plain_body);
	    $charset = "utf-8";
	}
    }

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
			      Comments => 'Generated by ' . basename($0),
			     );
    if (!$msg) {
	die "Kann kein MIME::Lite-Objekt erzeugen. Body war:\n$plain_body\n";
    }

    if ($is_multipart) {
	if (defined $add_html_body && $add_html_body ne "") {
	    $msg->attach(Type => "text/html; charset=iso-8859-1",
			 Data => $add_html_body,
			 Filename => "newstreetform.html",
			);
	}
	$msg->attach(Type => "text/plain; charset=$charset",
		     Data => $encoded_plain_body,
		    );
	if (defined $add_bbd && $add_bbd ne "") {
	    $msg->attach(Type => "application/x-bbbike-data",
			 Data => $add_bbd,
			 Filename => "comment.bbd",
			 Encoding => "quoted-printable",
			);
	}
## Unfortunately, this does not work with Mozilla Mail:
# 	if ($need_bbbike_css) {
# 	    $msg->attach(Type => "text/css",
# 			 Path => "$realbin/../html/bbbike.css",
# 			 Id => "bbbike.css",
# 			);
# 	}
    }

    my @send_args = @MIME_Lite_send;
    if (!@send_args) {
	# This is a default, but I don't like the global usage of
	# MIME::Lite->send, so reset it always:
	#@send_args = ("sendmail");
    }
    $msg->send(@send_args)
	or die "Can't send mail with args <@send_args>. Body was:\n$plain_body\n";

    my $cookie = cookie(-name => 'mapserver_comment',
			-value => { email => $email,
				    author => $author,
				  },
			-path => "/",
			-expires => "+1y",
		       );
    if (param("formtype") && param("formtype") =~ /^(newstreetform|fragezeichenform)$/) {
	my $dir = defined $bbbike_html ? $bbbike_html : "..";
	my $url = "$dir/newstreetform.html";
	my $bbbikegoolemapsurl;
	if (param("supplied_coord")) {
	    $bbbikegoolemapsurl = "$BBBike::BBBIKE_GOOGLEMAP_URL?" .
		CGI->new({
		    wpt         => param("supplied_coord"),
		    coordsystem => "bbbike",
		    maptype     => "hybrid",
		    mapmode     => "addroute",
		    zoom        => 17,
		})->query_string;
	}
	print header(-cookie => $cookie),
	    start_html(-title=>"Neue Straße für BBBike",
		       -style=>{'src'=>"$bbbike_html/bbbike.css"}),
	    "Danke, die Angaben wurden an ", a({-href => "mailto:$to"}, $to), " gesendet.",br(),br(),
	    (defined $bbbikegoolemapsurl ?
	     (a({-href => $bbbikegoolemapsurl}, "Weitere Kommentare zu dieser Straße auf einer Karte eintragen"),br(),br()) :
	     ()
	    ),
	    a({-href => $url}, "Weitere Straße eintragen"),
	    end_html;
    } else {
	print header(-cookie => $cookie),
	    start_html(-title=>"Kommentar abgesandt",
		       -style=>{'src'=>"$bbbike_html/bbbike.css"}),
	    "Danke, der folgende Kommentar wurde an " . BBBikeCGIUtil::my_escapeHTML($to) . " gesendet:",br(),br(),
	    pre(BBBikeCGIUtil::my_escapeHTML($comment)),
	    end_html;
    }
};
if ($@) {
    warn "Could not send mail: $@\nMail content:\n$comment\n";
    error_msg($@);
}

sub error_msg {
    print(header,
	  start_html(-title=>"Fehler beim Versenden",
		     -style=>{'src'=>"$bbbike_html/bbbike.css"}),
	  "Der Kommentar konnte wegen eines internen Fehlers nicht abgesandt werden. Bitte stattdessen eine Mail an ",
	  a({-href=>"mailto:$to?" . CGI->new({subject => "BBBike-Kommentar (fallback)",
					      body=>$comment})->query_string},$to),
	  " mit dem folgenden Inhalt versenden:",br(),br(),
	  pre($comment),
	  end_html,
	 );
    exit;
}

sub empty_msg {
    print(header,
	  start_html(-title=>'Fehler beim Versenden',
		     -style=>{'src'=>"$bbbike_html/bbbike.css"}),
	  "Bitte einen Kommentar angeben.",br(),
	  a({-href=>'javascript:history.back()'},'Zurück'),
	  end_html,
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

    $extra_html .= "<textarea rows='4' cols='80'>" . BBBikeCGIUtil::my_escapeHTML($bbd_suggestion) . "</textarea><br>";

    my $reply_to = $header->{To};
    my $cc = 'newstreet@bbbike.de, ' . $BBBike::EMAIL;
    my $body =<<EOF;
Hallo $name,

danke für deinen Eintrag. Die Straße "$strname" wird demnächst bei BBBike verfügbar sein.

Gruß,

EOF
    # not anymore :-(    das BBBike-Team
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

=head1 NAME

mapserver_comment.cgi - send comments about mapserver data

=head1 SYNOPSIS

none

=head1 DESCRIPTION

Send comments about mapserver data via email. The receiver is the
C<$EMAIL> address in L<BBBikeVar>.

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

To define the mail sending method, define the C<@Mail_Send_open>
variable in C<bbbike.cgi.config>. The value of this variable is the
same as the arguments of the C<open> method of L<Mail::Send>. To
define an SMTP server, use the following:

    @Mail_Send_open = ("smtp", Server => "mail.example.com");

=head1 AUTHOR

Slaven Rezic

=cut
