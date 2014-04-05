# -*- perl -*-

#
# $Id: Http.pm,v 4.2 2014/04/05 18:05:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1995,1996,1998,2000,2001,2003,2005,2008,2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.rezic.de/eserte/
#

package Http;
require 5.000;
require Exporter;
use Carp;
use Socket;
use Symbol qw(gensym);
use strict;
use vars qw(@ISA @EXPORT_OK $VERSION $tk_widget $user_agent $http_defaultheader
	    $BACKEND $waitVariable $timeout $can_alarm $warned_pack_sockaddr_in);

@ISA = qw(Exporter);
@EXPORT_OK = qw(get $user_agent $http_defaultheader
		rfc850_date uuencode);
$VERSION = sprintf("%d.%02d", q$Revision: 4.2 $ =~ /(\d+)\.(\d+)/);

$tk_widget = 0 unless defined $tk_widget;
$timeout = 10  unless defined $timeout;
$user_agent = "Http.pm/$VERSION (perl)";
$http_defaultheader = <<EOF;
Accept: */*;
EOF

if (is_in_path("zcat")) {
    $http_defaultheader .= "Accept-encoding: x-compress; x-gzip\015\012";
}

# Holt das durch urlstring spezifizierte WWW-Dokument. Falls rfc850 oder ctime
# angegeben wurde, wird das Dokument nur geholt, falls seitdem
# modifiziert wurde.
# Zurückgegeben wird ein Hash mit dem Inhalt (content) und Error-Code (error),
# sowie der Uhrzeit der letzten Änderung.
# Format des proxy-Arguments: http://server[:port]
sub get {
    my(@args) = @_;
    if (!defined $BACKEND) {
	$BACKEND = "plain";
    }
    if ($BACKEND eq 'ghttp') {
	get_ghttp(@args);
    } elsif ($BACKEND eq 'best') {
	if (eval { require HTTP::GHTTP; 1; }) {
	    $BACKEND = 'ghttp';
	} else {
	    $BACKEND = 'plain';
	}
	get(@args);
    } else {
	get_plain(@args);
    }
}

sub get_ghttp {
    # Argument is hash or string
    my %a = ($#_ == 0 ? ('url' => $_[0]) : @_);
    my %saveargs = %a;

    my $urlstring     = delete $a{'url'}  || croak "URL not defined";
    my $modtime       = delete $a{'rfc850'} || delete $a{'ctime'};
    my $debug         = delete $a{'debug'} || $Http::debug || 0;
    my $extra_header  = delete $a{'header'} || '';
    my $no_retry      = delete $a{'no-retry'};
    my $proxy         = delete $a{'proxy'};

    if (exists $a{'time'}) {
	$modtime = time2str(delete $a{'time'});
    }

    require HTTP::GHTTP;

    # Complain about extra arguments
    (keys %a > 0) &&
	croak 'Wrong arguments specified: "' . join('", "', keys %a) . '"';

    my $http = HTTP::GHTTP->new;
    $http->set_uri($urlstring);
    if ($modtime) {
	$http->set_header("If-modified-since" => $modtime);
    }
    foreach my $h (split(/\n/, $http_defaultheader . $extra_header)) {
	my($header, $value) = split(/\s*:\s*/, $h, 2);
	$http->set_header($header => $value);
    }
    $http->set_header("User-Agent" => $user_agent);
    $http->set_proxy($proxy) if defined $proxy;
    $http->process_request;

    my %ret;
    $ret{'error'}         = ($http->get_status)[0];
    my $last_modified     = $http->get_header("last-modified");
    $ret{'last-modified'} = $last_modified if defined $last_modified;
    $ret{'content'}       = $http->get_body;

    %ret;
}

sub get_plain {
    # Argument is hash or string
    my %a = ($#_ == 0 ? ('url' => $_[0]) : @_);
    my %saveargs = %a;

    # Process arguments from hash
    my $urlstring     = delete $a{'url'}  || croak "URL not defined";
    my $modtime       = delete $a{'rfc850'} || delete $a{'ctime'};
    my $debug         = delete $a{'debug'} || $Http::debug || 0;
    my $extra_header  = delete $a{'header'} || '';
    my $no_retry      = delete $a{'no-retry'};
    my $proxy         = delete $a{'proxy'};
    my $waitref       = delete $a{'waitVariable'} || \$waitVariable;

    if ($a{'__ignore__'} && $a{'__ignore__'}->{$urlstring}) {
	# loop detected
	return ('content'      => "Loop detected",
		'error'        => 500,
	       );
    }
    delete $a{'__ignore__'};

    if (exists $a{'time'}) {
	$modtime = time2str(delete $a{'time'});
    }

    # Complain about extra arguments
    (keys %a > 0) &&
	croak 'Wrong arguments specified: "' . join('", "', keys %a) . '"';

    if (defined $ENV{"http_proxy"} and $ENV{"http_proxy"} ne '') {
        $proxy = $ENV{"http_proxy"};
	if ($proxy !~ m|/$|) {
	    $proxy .= "/";
	}
    }
    if (defined $proxy and $proxy ne '') {
	$proxy =~ s|/$||; # strip trailing slash
	$urlstring = "$proxy/$urlstring";
    }

    my($host, $path, $port, $user, $pw) = parse_url($urlstring);

    # führendes '/' bei proxy server-Adressen entfernen:
    $path = substr($path, 1) if ($path =~ /^\/(http|ftp|gopher):\/\//);

    if ($debug) {
	print STDERR "--- Http::get\n";
	print STDERR "host: $host\n";
	print STDERR "path: $path\n";
	print STDERR "port: $port\n";
	print STDERR "user: $user\n" if defined $user;
	print STDERR "pw:   $pw\n"   if defined $pw;
    }

    my(%header, %error, $content);
    $content = "";
    local($/) = $/;

    my $sock = gensym;

    my $r;
    if ($timeout && _can_alarm()) {
	local $SIG{ALRM} = sub { die "Timeout" };
	alarm($timeout);
	# connect() may block --- find a way how to detect blocking connects
	# and get rid of the alarm() stuff
	eval {
	    $r = &socket($sock, $host, $port);
	};
	my $err = $@;
	alarm(0);
	if ($err) {
	    return ('content' => $err,
		    'error' => 500);
	}
    } else {
	eval {
	    $r = &socket($sock, $host, $port);
	};
	if ($@) {
	    return ('content' => $@,
		    'error' => 500);
	}
    }
    binmode($sock);
    if (!defined $r) {
        return ('content'       => undef,
                'error'         => 500,
               );
    }

    my $hostheader;
    if (defined $host) {
	$hostheader = "Host: $host";
	if (defined $port && $port != 80) {
	    $hostheader .= ":$port";
	}
	$hostheader .= "\015\012";
    }

    my $cmd = "GET $path HTTP/1.0\015\012"
      . (defined $hostheader ? $hostheader : "")
        . (defined($modtime) ? "If-modified-since: $modtime\015\012" : "")
	  . "$http_defaultheader"
	    . "User-Agent: $user_agent\015\012"
	      . ($extra_header ne "" ? "$extra_header\015\012" : "")
	        . "\015\012";

    if ($tk_widget && $^O ne "MSWin32") {
	$$waitref = 0;
	print STDERR "\nWait for writable socket ..." if $debug;
	$tk_widget->fileevent($sock, 'writable', sub { $$waitref = 1 });
	$tk_widget->waitVariable($waitref);
	$tk_widget->fileevent($sock, 'writable', '');
	print STDERR " socket is writable\n" if $debug;
    }

    syswrite $sock, $cmd;
    print STDERR "\nSend>>>\n" . $cmd . "<<<Send\n" if $debug;

    my $stage = 0; # 0=header, 1=body
    my $buffer = "";

    print STDERR "\nReceive>>>\n" if $debug;
    my $parse_header_line = sub {
	s/\015?\012/\n/;
	if (/^\s*$/) {
	    print STDERR "<<<End of header detected>>>\n" if $debug;
	    return 0;
	}
	print STDERR $_ if $debug;
	if (m|HTTP/\d+\.\d+\s+(\d+)\s+(.*)|) {
	    $error{'code'} = $1;
	    $error{'text'} = $2;
	} elsif (/^(\S*):\s*([^\015\012]*)/) { # MIME-Header line
	    $header{"\L$1\E"} = $2;
	}			# XXX process multiline header lines
	1;
    };

    my $content_follows = sub {
	if (!exists $error{'code'}) {
	    $error{'code'} = 500;
	    $error{'text'} = "Can't connect server";
	}
	if ($error{'code'} == 301 || $error{'code'} == 302) { # Redirect
	    !defined($header{'location'}) && do {
		print STDERR "Location not defined\n" if $debug;
		return 0;
	    };

	    # XXX evtl. loops verhindern
	    $saveargs{'url'} = $header{'location'};
	    $saveargs{'__ignore__'}->{$urlstring} = 1;
	    my(%res) = &get(%saveargs);
	    $content = $res{'content'};
	    $error{'code'} = $res{'error'};
	    $header{'last-modified'} = $res{'last-modified'};
	    return 0;
	}
	elsif ($error{'code'} == 401) { # Unauthorized
	    $no_retry && do {
		print STDERR "No 2nd retry\n" if $debug;
		return 0;
	    };
	    $header{'www-authenticate'} =~ /^(\S+)\s+(.*)$/ || do {
		print STDERR "Wrong header www-authenticate\n" if $debug;
		return 0;
	    };
	    my %auth;
	    $auth{'type'} = $1;
	    $auth{'args'} = $2;
	    $auth{'type'} ne 'Basic' && do {
		print STDERR "Unsupported auth type $auth{type}\n" if $debug;
		return 0;
	    };
	    (!defined($user) || !defined($pw)) && do {
		print STDERR "User and/or password not defined\n" if $debug;
		return 0;
	    };
	    $saveargs{'header'} =
		"Authorization: $auth{type} " . &uuencode("$user:$pw");
	    $saveargs{'no-retry'} = 1;
	    my(%res) = &get(%saveargs);
	    $content = $res{'content'};
	    $error{'code'} = $res{'error'};
	    $header{'last-modified'} = $res{'last-modified'};
	    return 0;
	}
	elsif ($error{code} != 200) { # not OK
	    return 0;
	}
	1;
    };

    if ($tk_widget) {
	my $error = 0;
	my $recursive_call = 0;
	$$waitref = 0;
	$tk_widget->fileevent
	    ($sock, 'readable', sub {
		 if ($timeout && _can_alarm()) {
		     local $SIG{ALRM} = sub { die "Timeout" };
		     alarm($timeout);
		     my $r;
		     eval {
			 $r = sysread($sock, $buffer, 1024, length($buffer));
		     };
		     my $err = $@;
		     alarm(0);
		     if ($err) {
			 $content = $err;
			 $error = 1;
			 $$waitref = 1;
			 return;
		     }
		     if ($r == 0) {
			 $$waitref = 1;
			 return;
		     }
		 } else {
		     if (sysread($sock, $buffer, 1024, length($buffer)) == 0) {
			 $$waitref = 1;
			 return;
		     }
		 }
		 if ($stage == 0) {
		     while ($buffer =~ s/(.*?\012)(.*)/$2/) {
			 $_ = $1;
			 if (!$parse_header_line->()) {
			     $stage = 1;
			     if ($error{code} != 200) {
				 $$waitref = 1;
				 $recursive_call = 1;
				 return;
			     }
			     $content .= $buffer;
			     $buffer = "";
			     last;
			 }
		     }
		 } else {
		     $content .= $buffer;
		     $buffer = "";
		 }
	     });
	$tk_widget->waitVariable($waitref);
	$tk_widget->fileevent($sock, 'readable', '');
	if ($recursive_call) {
	    $content_follows->();
	} elsif ($error) {
	    close $sock;
	    return ('content' => $content,
		    'error'   => 500);
	}
    } else {
	local($/) = "\012";
	while (<$sock>) {
	    last if !$parse_header_line->();
	}
	if ($content_follows->()) {
	    undef $/;		# Rest der Datei in einem Schwung lesen
	    $content = <$sock>;
	    $content = "" if !defined $content;
	}
    }

    print "<<<Receive\n" if $debug;
    print STDERR "read ", length($content), " bytes\n" if $debug;

    close($sock);

    if (defined $header{'content-encoding'} and
	$header{'content-encoding'} =~ /^(?:x-)?(?:gzip|compress)/) {
	# gzip und compress dekomprimieren --- Holzhammermethode
	my($tmpfh,$tmpfile);
	if (eval { require File::Temp; 1 }) {
	    ($tmpfh,$tmpfile) = File::Temp::tempfile(SUFFIX => '_Http.gz',
						     UNLINK => 1);
	    croak "Cannot create temporary file" if !$tmpfile;
	    print $tmpfh $content
		or croak "While writing compressed content to temporary file $tmpfile: $!";
	    close $tmpfh
		or croak "While closing temporary file $tmpfile: $!";
	} else {
	    $tmpfile = "/tmp/zcat.$$";
	    open(OUT, "> $tmpfile")
		or croak "Can't write to temporary file $tmpfile: $!";
	    print OUT $content
		or croak "While writing compressed content to temporary file $tmpfile: $!";
	    close(OUT)
		or croak "While closing temporary file $tmpfile: $!";
	}

	local($/) = undef;
	open(IN, "zcat $tmpfile |") || croak "Can't uncompress";
	$content = <IN>;
	close(IN);

	unlink $tmpfile;
    }

    ('content'       => $content,
     'error'         => $error{code},
     'last-modified' => $header{'last-modified'},
     'headers'       => \%header,
    );
}


# Öffnet einen Socket
# Argumente sind Filedescriptor, Hostname und Port
# gibt undef zurück, wenn kein Socket geöffnet werden konnte
sub socket {
    my($conn, $host, $port) = @_;

    my $AF_INET = &AF_INET;
    my $SOCK_STREAM = &SOCK_STREAM;

    my(undef, undef, $proto) = getprotobyname('tcp');
    if (int($port) ne $port) {
	my $dummy;
	(undef, undef, $port, $proto) = getservbyname($port, $dummy);
    }
    my($name, undef, undef, undef, $thataddr) = gethostbyname($host);
    croak("Can't get host by name: $host") if (!defined $thataddr);
    my($this, $that);
    if (defined &Socket::pack_sockaddr_in && &Socket::INADDR_ANY) {
	$this = Socket::pack_sockaddr_in(0, Socket::INADDR_ANY());
	$that = Socket::pack_sockaddr_in($port, $thataddr);
    } else {
	if (!$warned_pack_sockaddr_in) {
	    warn "Fallback to unreliable manual packing for sockaddr...\n";
	    $warned_pack_sockaddr_in++;
	}
	my $sockaddr = 'S n a4 x8';
	$this = pack($sockaddr, $AF_INET, 0);
	$that = pack($sockaddr, $AF_INET, $port, $thataddr);
    }
    # Make the socket filehandle.
    socket($conn, $AF_INET, $SOCK_STREAM, $proto) ||
	croak "socket: $!";
    # Give the socket an address.
    bind($conn, $this) || croak "bind: $!";
    # Call up the server.
    connect($conn, $that) || croak "Couldn't connect to $name $port\n$!\n";
    # Set socket to be command buffered.
    my $old = select; select($conn); $| = 1; select($old);
    1;
}


# konvertiert das angegebene Datum (ctime oder RFC822) zu RFC850
sub rfc850_date {
    my($date) = @_;

    if ($date =~
	/(\S+)\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+([^\d]+)?\s*(\d+)/) {
	# ctime: wkday mon day hour:min:sec (tz) year
	"$1, $3 $2 $8 $4:$5:$6 $7";
    }
    elsif ($date =~
	   /(\S+)\s+(\d\d)-(\S\S\S)-(\d\d)\s+(\d+):(\d+):(\d+)\s+(\S+)/) {
	# RFC 850: wkday day-mon-year hour:min:sec tz
	my($year) = ($4 < 70 ? $4 + 2000 : $4 + 1900);
	"$1, $2 $3 $year $5:$6:$7 $8";
    }
    else {
	$date;
    }
}

# aus HTTP::Date
sub time2str
{
   my $time = shift;
   $time = time unless defined $time;
   my ($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime($time);
   my @DoW = qw(Sun Mon Tue Wed Thu Fri Sat);
   my @MoY = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
   sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT",
           $DoW[$wday],
           $mday, $MoY[$mon], $year+1900,
           $hour, $min, $sec);
}

# Kodierung der Authentifications-Daten
sub uuencode {
    my($in) = @_;
    my(@out4, @in3, $out);
    while($in ne '') {
	@in3 = map(ord, split(//, substr($in, 0, 3)));
	$in    = substr($in, 3);
	$out4[0] =  $in3[0] >> 2;
	$out4[1] = ($in3[0] & 3) << 4 |  ($in3[1] >> 4);
	$out4[2] = ($in3[1] & 15) << 2 | ($in3[2] >> 6);
	$out4[3] = ($in3[2] & 63);
	$out .= join('', map {&six2pr($_)} @out4);
    }
    $out;
}

sub six2pr {
    my($six) = @_;
    return chr(ord('A') + $six)      if $six <= 25;
    return chr(ord('a') - 26 + $six) if $six <= 51;
    return chr(ord('0') - 52 + $six) if $six <= 61;
    return '+'                       if $six == 62;
    return '/'                       if $six == 63;
    return chr(64);			# XXX ???
}

# partial URL parser
# argument: URL, result: (hostname, path, port)
sub parse_url {
    my($urlstring) = @_;

    my($host, $path, $port, $user, $pw);

    if (eval {
	local $SIG{'__DIE__'};
	require URI::URL;
	my($url) = new URI::URL $urlstring;
	$host = $url->host;
	$path = $url->full_path;
	$port = $url->port;
	eval {
	    $user = $url->user;
	    $pw   = $url->password;
  	};
  	if ($@ && $url->userinfo) {
  	    ($user, $pw) = split(/:/, $url->userinfo);
  	}
	1;
    }) {
	return ($host, $path, $port, $user, $pw);
    }

    # ansonsten: kein URI::URL installiert
    if ($urlstring !~ /(http):\/\/([^:\/]+):?(\d+)?(\/.*)/) {
        die "Bad URL. Must be http://hostname(:port)?/path. Error occured at";
    }
    my $protocol;
    ($protocol, $host, $port, $path) = ($1, $2, $3, $4);
    $port = 80 if (!defined $port or $port eq ''); # standard www port

    ($host, $path, $port, undef, undef);
}

sub is_in_path {
    my($prog) = @_;
    foreach (split(/:/, $ENV{PATH})) {
	return $_ if -x "$_/$prog";
    }
    undef;
}

sub _can_alarm {
    return $can_alarm if (defined $can_alarm);
    eval q{ alarm 0 };
    $can_alarm = $@ eq '';
    $can_alarm;
}

1;

__END__

=head1 NAME

Http - wrapper around HTTP protocol

=head1 SYNOPSIS

    use Http;
    %res = Http::get(url => "http://...");
    if ($res{'error'} == 200) {
        print $res{'content'};
    } else {
        print "Error code $res{'error'}\n";
    }

As a one-liner:

    perl -MData::Dumper -MHttp -e 'warn Dumper Http::get(url => shift)' http://...

=head1 DESCRIPTION

The get() function may take the following arguments:

=over

=item url

The URL to fetch. This is mandatory.

=item rfc850

An RFC 850-styled date. Only fetch the URL if the document is newer.

=item ctime

A ctime-styled date. Only fetch the URL if the document is newer.
C<rfc850> and C<ctime> may not be used together.

=item debug

Turn debugging on.

=item header

A string with extra header lines. Header lines should be in the form

    val: key\015\012

=item no-retry

Do not retry if the first fetch encounter an authorization request.

=item proxy

Use the named proxy. Also the environment variable C<http_proxy> may
be used to set a proxy.

=item waitVariable

For using with Tk: a variable reference to wait for a writable socket.

=back

=head2 Global variables

=over

=item C<$BACKEND>

Choose a backend. Choices are: C<plain> (for a pure-perl
implementation) and C<ghttp> (for using C<HTTP::GHTTP>). C<best>
chooses from either C<ghttp> (if available) or C<plain>.

=item C<$user_agent>

Change the name of the user agent.

=item C<$http_defaultheader>

A list of default headers to send. By default, C<Http.pm> checks
whether C<zcat> is available and adds a header to accept compress and
gzip encodings.

=back

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 COPYRIGHT

Copyright (c) 1995,1996,1998,2000,2001,2003,2005,2008 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO
