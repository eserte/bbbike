#!/usr/bin/perl -w
# -*- mode:perl;coding:iso-8859-1; -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib $FindBin::RealBin;
use CGI '-oldstyle_urls';
use Encode qw(encode_utf8);
no utf8;

BEGIN {
    if (!eval q{
	use Email::MIME;
	# NOTE: The usage of decode_entities below is not that correct,
	# but sufficient for the test cases here.
	use HTML::Entities qw(decode_entities);
	use HTTP::Message;
	use HTTP::Request;
	use HTTP::Request::Common 'POST';
	use IPC::Run 'run';
	use Test::More;
	defined &done_testing;
    }) {
	print "1..0 # skip no Email::MIME, HTML::Entities, HTTP::Message, IPC:Run and/or (modern) Test::More modules\n";
	exit;
    }
}

use BBBikeTest qw(check_cgi_testing);

check_cgi_testing;

my $mapserver_comment = "$FindBin::RealBin/../cgi/mapserver_comment.cgi";

for my $method (qw(GET POST)) {

    my $simulate_mail_sending = sub {
	my(@cgi_params) = @_;
	push @cgi_params, mailout => 1;
	my $content;
	local %ENV;
	if ($method eq 'GET') {
	    $ENV{REQUEST_METHOD} = 'GET';
	    my %cgi_params;
	    for(my $i=0; $i<$#cgi_params; $i+=2) {
		my($k,$v) = @cgi_params[$i, $i+1];
		if (exists $cgi_params{$k}) {
		    push @{ $cgi_params{$k} }, $v;
		} else {
		    $cgi_params{$k} = [ $v ];
		}
	    }
	    $ENV{QUERY_STRING} = CGI->new(\%cgi_params)->query_string;
	} else {
	    $ENV{REQUEST_METHOD} = 'POST';
	    
	    my $request = POST 'dummy', [@cgi_params];
	    $ENV{CONTENT_LENGTH} = $request->header('content-length');
	    $ENV{CONTENT_TYPE} = $request->content_type;
	    $content = $request->content;
	}
	$ENV{SERVER_NAME} = 'bbbike.de';
	# Kinda hack: HTTP message is sent to STDOUT, Mail message is
	# sent to STDERR. In case of errors or warnings the Mail
	# message will be unusable, of course.
	my($stdout, $stderr);
	ok run [$^X, $mapserver_comment], ">", \$stdout, "2>", \$stderr, (defined $content ? ("<", \$content) : ());
	(
	 raw_stdout => $stdout,
	 http => HTTP::Message->parse($stdout),
	 raw_stderr => $stderr,
	 mail => $stderr eq '' ? undef : Email::MIME->new($stderr),
	);
    };

    {
	my %res = $simulate_mail_sending->();
	like $res{http}->decoded_content, qr{Bitte einen Kommentar angeben}, "Comment was missing ($method)";
	is $res{mail}, undef, 'No mail sent'
	    or diag "Raw STDERR:\n" . $res{raw_stderr};
    }

    {
	my $comment = 'Some comment with umlauts äöü';
	my %res = $simulate_mail_sending->(comment => $comment);
	like decode_entities($res{http}->decoded_content), qr{\Q$comment}, "HTTP: A comment with umlauts ($method)";
	like $res{mail}->body_str, qr{\Q$comment}, 'Mail';
    }

    {
	my $comment = 'Some comment with umlauts äöü';
	my $author = 'Some Body With Umlauts äöü';
	my %res = $simulate_mail_sending->(comment => $comment, author => $author);
	like decode_entities($res{http}->decoded_content), qr{\Q$comment}, "HTTP: A comment and author with umlauts ($method)";
	like $res{mail}->body_str, qr{\Q$comment}, 'Mail';
    }

    {
	my $comment = "Some utf8-encoded comment with umlauts äöü\x{20ac}";
	my $comment_utf8 = encode_utf8($comment);
	my %res = $simulate_mail_sending->(comment => $comment_utf8, encoding => 'utf-8');
	like decode_entities($res{http}->decoded_content), qr{\Q$comment}, "HTTP: An utf8-encoded comment with umlauts ($method)";
	like $res{mail}->body_str, qr{\Q$comment}, 'Mail';
    }

    {
	my $email = 'somebody@example.org';
	my $author = "Some Body\x{107}";
	my $comment = "Some utf8-encoded comment with umlauts äöü\x{20ac}";
	my $comment_utf8 = encode_utf8($comment);
	my $author_utf8 = encode_utf8($author);
	my %res = $simulate_mail_sending->(comment => $comment_utf8,
					   email => $email,
					   author => $author_utf8,
					   encoding => 'utf-8');
	like decode_entities($res{http}->decoded_content), qr{\Q$comment}, "HTTP: An utf8-encoded comment and author with umlauts ($method)";
	like $res{mail}->body_str, qr{\Q$comment}, 'Mail';
    }

    {
	my %res = $simulate_mail_sending->(author => 'Some Body',
					   email => 'somebody@example.org',
					   comment => encode_utf8("test with \x{107} in body\nand a 2nd line\n"),
					   routelink => "Link to route: http://bbbike.lvps176-28-19-132.dedicated.hosteurope.de/cgi-bin/bbbikegooglemap.cgi?zoom=14&amp;coordsystem=polar&amp;maptype=hybrid&amp;wpt_or_trk=13.362122,52.517109+13.377829,52.514811",
					   encoding => "utf-8",
					   route => "13.362122,52.517109 13.377829,52.514811",
					  );
	unlike $res{http}->decoded_content, qr{intern.*Fehler}, 'Internal error'
	    or diag $res{raw_stdout};
	isnt $res{mail}, undef
	    or diag $res{raw_stderr};
	my @parts = $res{mail}->parts;
	is scalar(@parts), 2, "Two parts found in mail (text and bbd)"
	    or diag $res{raw_stderr};
	like $parts[0]->body_str, qr{and a 2nd line}, 'Found text in first part'
	    or diag $res{raw_stderr};
    }

    {
	my %res = $simulate_mail_sending->(formtype => 'newstreetform',
					   var1 => 'var1_val',
					   var2 => 'var2_val',
					   multivar => 'multivar_val1',
					   multivar => 'multivar_val2',
					   strname => 'Teststreet',
					   email => 'somebody@example.org',
					   comment => "test comment",
					  );
	like decode_entities($res{http}->decoded_content), qr{Danke, die Angaben.*gesendet}, "HTTP: Thankyou ($method)";
	like $res{http}->header('set-cookie'), qr{mapserver_comment}, 'Seen Set-Cookie header';
	my @parts = $res{mail}->parts;
	is scalar(@parts), 2, "Two parts found in mail (html and text)";
	my $plain = $parts[1]->body_str;
	like $plain, qr{var1.*var1_val}, 'Found single param in plain part';
	like $plain, qr{multivar_val2}, 'Found 2nd multi param in plain part';
	like $plain, qr{email.*somebody.*example\.org}, 'Found email in plain part';
    }
}

done_testing;

__END__
