#!/usr/bin/env perl
# -*- perl -*-

#
# $Id: BrowserInfo.pm,v 1.41 2004/06/10 23:00:37 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999-2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

package BrowserInfo;
use CGI;
use strict;
use vars qw($VERSION);

$VERSION = sprintf("%d.%02d", q$Revision: 1.41 $ =~ /(\d+)\.(\d+)/);

sub new {
    my($pkg, $q) = @_;
    if (!defined $q) {
	$q = new CGI;
    }
    my $self = {'CGI' => $q};
    bless $self, $pkg;
    $self->set_info;
    $self;
}

sub emulate {
    my($self, $browser) = @_;
    if ($browser =~ /^palmscape$/i) {
	$ENV{HTTP_USER_AGENT} = "Palmscape/PR5 (PalmPilot Pro; I)";
    } elsif ($browser =~ /^lynx$/i) {
	$ENV{HTTP_USER_AGENT} = "Lynx/2.8rel.2 libwww-FM/2.14";
    } elsif ($browser =~ /^wap$/i) {
	$ENV{HTTP_USER_AGENT} = "SIE-C3I/1.0 UP/4.1.8c UP.Browser/4.1.8c-XXXX UP.Link/4.1.0.6";
    } else {
	die "Unknown emulation: $browser";
    }
    $self->set_info;
}

sub set_info {
    my $self = shift;
    my $q = $self->{CGI};
    # User-Agent-Information normieren
    $self->{'user_agent_name'} = "";
    $self->{'user_agent_version'} = 0;
    $self->{'user_agent_os'} = "";
    $self->{'user_agent_compatible'} = "";

    ($self->{'user_agent_name'}, $self->{'user_agent_version'}) =
	_get_browser_version($q->user_agent);

    if ($q->user_agent =~ /\((.*)\)/) {
	my(@infos) = split(/;\s*/, $1);
	my $ignore_next = 0;
	my $i; # be compatible with 5.003
	for($i=0; $i<=$#infos; $i++) {
	    my $info = $infos[$i];
	    if ($ignore_next) {
		$ignore_next = 0;
		next;
	    }
	    next if $info =~ /^(I|U|N|X11|AK|AOL\s\d\.\d|MSN\s\d\.\d|Update\s.|1und1|R3SSL1.1|SK|pdQbrowser|\d+bit|\d+-bit|\d\.\d+)$/;
	    if ($info =~ /^compatible$/i) {
		$i++;
		$info = $infos[$i];
		$self->{'user_agent_compatible'} =
		    $self->{'user_agent_name'} . "/" .
		    $self->{'user_agent_version'};

		if ($info =~ /^Konqueror/) {
		    ($self->{'user_agent_name'}, $self->{'user_agent_version'}) =
			_get_browser_version($info);
		} elsif ($self->{'user_agent_name'} ne 'Opera') {
		    ($self->{'user_agent_name'}, $self->{'user_agent_version'}) =
			_get_browser_version($info, " ");
		}
		next;
	    }
	    $self->{'user_agent_os'} = $info;
	    last;
	}
    }

    $self->{'text_browser'} = ($q->user_agent('lynx') ||
			       $q->user_agent('w3m')  ||
			       $q->user_agent('palmscape') ||
			       $q->user_agent('sie-c3i') ||
			       $q->user_agent('sie-s35')
			      );
    $self->{'wap_browser'} = ($q->user_agent('sie-c3i') ||
			      $q->user_agent('sie-s35') ||
			      $q->user_agent('SIE-S55') ||
			      $q->user_agent('SIE-MC60') ||
			      $q->user_agent('SIE-SX1') ||
			      $q->user_agent('SIE-CX65') ||
                              $q->user_agent('nokia-wap-toolkit') ||
			      $q->user_agent('Nokia7110') ||
			      $q->user_agent('Nokia6210') ||
			      $q->user_agent('Nokia6250') ||
			      $q->user_agent('Nokia3510i') ||
			      $q->user_agent('Nokia6100') ||
			      $q->user_agent('Nokia3650') ||
			      $q->user_agent('Nokia7650') ||
			      $q->user_agent('Nokia6600') ||
			      $q->user_agent('Nokia3100') ||
			      $q->user_agent('Nokia3200') ||
			      $q->user_agent('Nokia6620') ||
			      $q->user_agent('Nokia7250') ||
			      $q->user_agent('Nokia7250I') ||
			      $q->user_agent('NokiaN-Gage') ||
			      $q->user_agent('SEC_SGHV200') ||
			      $q->user_agent('SonyEricssonP800') ||
			      $q->user_agent('SonyEricssonP900') ||
			      $q->user_agent('SonyEricssonT68') ||
			      $q->user_agent('SonyEricssonT300') ||
			      $q->user_agent('SonyEricssonT610') ||
			      $q->user_agent('MOT-') ||
			      (defined $ENV{HTTP_ACCEPT} &&
			       $ENV{HTTP_ACCEPT} =~ /vnd.wap.wml/i
			      )
			      # XXX check:
			      #|| $q->user_agent('Ericsson/R1A') ||
			      #$q->user_agent('EudoraWeb')
			     );
    # usually text browser with even limited screen dimensions
    $self->{'mobile_device'} = ($q->user_agent('palmscape') ||
				$self->{'user_agent_os'} =~ /PalmOS/ ||
				($self->{'wap_browser'} &&
				 # Take out "big" browsers which may or may not
				 # understand wml
				 $self->{'user_agent_name'} !~ /^(?:Opera|Mozilla|MSIE|Konqueror)$/
				)
			       );

    # display size without permanent footers etc.
    if ($q->user_agent('nokia-wap-toolkit')) {
	$self->{'display_size'} = [80,60-20]; # ???
    } elsif ($q->user_agent('MotorolaT720')) { # XXX
	$self->{'display_size'} = [120,160];
    } elsif ($q->user_agent('PanasonicEB-GD87')) { # XXX
	$self->{'display_size'} = [132,176];
    } elsif ($q->user_agent('Panasonic-GD67')) { # XXX
	$self->{'display_size'} = [101,80];
    } elsif ($q->user_agent('Panasonic-GD87') ||
	     $q->user_agent('Panasonic-X70')) { # XXX
	$self->{'display_size'} = [132,176];
    } elsif ($q->user_agent('PhilipsFisio820')) { # XXX
	$self->{'display_size'} = [112,112];
    } elsif ($q->user_agent('SagemMyx5')) { # XXX
	$self->{'display_size'} = [101,80];
    } elsif ($q->user_agent('SamsungSGH-S200') ||
	     $q->user_agent('SamsungSGH-T100')) { # XXX
	$self->{'display_size'} = [128,144];
    } elsif ($q->user_agent('SHARP-TQ-GX10')) {
	$self->{'display_size'} = [120,160];
    } elsif ($q->user_agent('SonyEricssonT300')) {
	$self->{'display_size'} = [101,101];
    } elsif ($q->user_agent('SonyEricssonT68i') ||
	     $q->user_agent('SonyEricssonT68ie')) {
	$self->{'display_size'} = [101,80];
    } elsif ($q->user_agent('SonyEricssonP800') ||
	     $q->user_agent('SonyEricssonP900')) { # XXX sizes for P900 guessed
	$self->{'display_size'} = [208,320]; # flip open, with flip closed: 208x144
    } elsif ($q->user_agent('SonyEricssonT610')) {
	$self->{'display_size'} = [125,95]; # visible screen size
    } elsif ($q->user_agent('TriumEclipse')) { # XXX
	$self->{'display_size'} = [143,120];
    } elsif ($q->user_agent('SIE-SX1')) {
	$self->{'display_size'} = [170,144];
    } elsif ($q->user_agent('SIE-CX65')) {
	$self->{'display_size'} = [132,140]; # useable
    } elsif ($q->user_agent('SIE-')) { # S55, ...
	$self->{'display_size'} = [101,80];
    } elsif ($q->user_agent('SAMSUNG-SGH-')) { # X...,E700
	$self->{'display_size'} = [115,100];
    } elsif ($q->user_agent('Trium320') ||
	     $q->user_agent('Trium630')) { # XXX
	$self->{'display_size'} = [128,141];
    } elsif ($q->user_agent('portalmmm')) {
	$self->{'display_size'} = [120,120]; # minimum size, newer imode devices have larger displays
    } elsif ($q->user_agent('MOT-A835')) {
	$self->{'display_size'} = [165,162]; # XXX roughly...
    } elsif ($q->user_agent('Nokia')) {
	my %nokias =
	    (
	     Nokia3310 => [84, 84],
	     Nokia3330 => [84, 84],
	     Nokia6090 => [84, 84],
	     Nokia6210 => [96, 60],
	     Nokia6250 => [96, 60],
	     Nokia8210 => [84, 48],
	     Nokia8850 => [84, 48],
	     Nokia8890 => [84, 48],
	     Nokia9210 => [84, 48],
	     Nokia8310 => [84, 48],
	     Nokia6510 => [96, 65],
	     Nokia5510 => [84, 48],
	     Nokia5210 => [84, 48],
	     Nokia6310 => [96, 65],
	     Nokia7110 => [96, 65],
	     Nokia3100 => [124, 128], # space for vert scrollbar
	     Nokia3200 => [124, 128], # space for vert scrollbar
	     Nokia6620 => [124, 128], # space for vert scrollbar
	     Nokia7250 => [124, 128], # space for vert scrollbar ?
	     Nokia7250I=> [124, 128], # space for vert scrollbar ?
	     Nokia6610 => [128, 128],
	     Nokia6100 => [128, 90], # XXX ca.
	     Nokia3650 => [170, 144], # visible size
	     Nokia3660 => [170, 144],
	     Nokia7650 => [170, 144], # max image width is smaller? check wapbbbike.cgi output
	     Nokia6600 => [170, 144],
	     "NokiaN-Gage" => [170, 144],
	    );
    TRY: {
	    while(my($k,$v) = each %nokias) {
		if ($q->user_agent($k)) {
		    $self->{display_size} = $v;
		    last TRY;
		}
	    }
	    warn "Fallback for unknown Nokia phone " . $q->user_agent;
	    $self->{display_size} = [84, 49]; # fallback to smallest...
	}
    } elsif ($q->user_agent("Dillo")) {
	$self->{'display_size'} = [200,320]; # iPAQ
    } elsif ($self->{'mobile_device'}) {
	$self->{'display_size'} = [80,60-20]; # ???
    } else {
	$self->{'display_size'} = [800-50,600-10]; # ???
    }

    # XXX neues User-Agent-Scheme anwenden...
    $self->{'can_javascript'} =
      ($q->user_agent =~ m#(Mozilla/[4-9])#i
       ? 1.2
       : ($q->user_agent =~ m#(Mozilla/3)#i
	  ? 1.1
	  : ($q->user_agent =~ m#(Mozilla/2|Konqueror)#i
	     ? 1.0
	     : 0)));
    if ($self->{'can_javascript'}) {
	$self->{'window_open_buggy'} = ($q->user_agent =~ m|^Konqueror/1.0|i ||
					$q->user_agent =~ m|^Mozilla/2|i);
	$self->{'javascript_incomplete'} =
	  ($q->user_agent =~ m|^Konqueror/1\.[01]|i);
    }
    $self->{'can_png'} = ($q->user_agent =~ m|(Mozilla/[4-9])|i ? 1 : 0);
    # accept("image/png") heißt leider nicht, dass PNG auch Inline dargestellt
    # wird... und Netscape/3 macht es eh' falsch
    $self->{'can_css'} = ($q->user_agent =~ m|(Mozilla/[4-9])|i ? 1 : 0);
    $self->{'can_dhtml'} = (($self->{'user_agent_name'} eq 'Mozilla' &&
			     $self->{'user_agent_version'} >= 4.0) ||
			    ($self->{'user_agent_name'} eq 'MSIE' &&
			     $self->{'user_agent_version'} >= 4.0) ||
			    ($self->{'user_agent_name'} eq 'Konqueror' &&
			     $self->{'user_agent_version'} >= 2.0));
    $self->{'can_table'} = ((!$self->{'text_browser'} ||
			     $q->user_agent("w3m")) &&
			    !$q->user_agent("nokia7110") &&
			    !$q->user_agent("libwww-perl") # tkweb
			   );
    # Dillo kann Tabellen ab ca. 0.6.x
    $self->{'dom_type'} = "";
    if ($self->{'user_agent_name'} eq 'Mozilla') {
	if ($self->{'user_agent_version'} >= 4 &&
	    $self->{'user_agent_version'} < 5) {
	    $self->{'dom_type'} = 'layers';
	} elsif ($self->{'user_agent_version'} >=5) {
	    $self->{'dom_type'} = '2';
	}
    } elsif ($self->{'user_agent_name'} eq 'MSIE' &&
	     $self->{'user_agent_version'} >= 4.0) {
	$self->{'dom_type'} = '1';
    }

    # bei Mozilla funktionieren meine DHTML-Sachen mit 4.04 build 97329, aber
    # nicht mit 4.04 build 97308 ... also 4.04 generell ausschließen
    # beim alten Explorer gibt es offenbar Probleme mit offsetTop
    # Explorer 5.5 hat ebenfalls Probleme mit offsetTop
    if ($self->{'can_dhtml'}) {
	$self->{'dhtml_buggy'} = (($self->{'user_agent_name'} eq 'Mozilla' &&
				   $self->{'user_agent_version'} < 4.05) ||
				  ($self->{'user_agent_name'} eq 'MSIE' &&
				   ($self->{'user_agent_version'} < 5.0 ||
				    $self->{'user_agent_version'} == 5.5)));
    }

    # CSS beim alten Netscape ist oft Glückssache
    if ($self->{'user_agent_name'} eq 'Mozilla' &&
	$self->{'user_agent_version'} < 5.0) {
	$self->{'css_buggy'} = 1;
    }

    if ($q->user_agent =~ /Gecko\/(\d+)/) {
	$self->{gecko_version} = $1;
    }
}

sub is_browser_version {
    my $self = shift;
    while(@_) {
	my $browser = shift;
	my $min_version;
	my $max_version;
	if (@_) {
	    $min_version = shift;
	    if (@_) {
		$max_version = shift;
	    }
	}
	next if ($self->{user_agent_name} ne $browser);
	next if (defined $min_version &&
		 $self->{user_agent_version} < $min_version);
	next if (defined $max_version &&
		 $self->{user_agent_version} > $max_version);
	return 1;
    }
    0;
}

sub show_info {
    my $self = shift;
    if ($self->{'wap_browser'}) {
	$self->show_info_wml(@_);
    } else {
	$self->show_info_html(@_) . "<hr>\n";
    }
}

sub show_info_html {
    my $self = shift;
    my $complete = shift;
    my $q = $self->{CGI};
    my $out = "";
    if ($complete) {
	if ($self->{'can_javascript'}) {
	    $out .= <<EOF;
<script language=javascript><!--
function get_navigator() {
    var s = "";
    for(var i in navigator) {
	s = s + i + " = " + navigator[i] + "\\n";
    }
    alert(s);
}

// for buggy browsers like MSIE 4.5 for Mac, which do not support
// examining objects over "var i in ..."
function get_navigator2() {
    var attr = new Array("appCodeName", "appMinorVersion", "appName",
                         "appVersion", "cookieEnabled", "cpuClass",
                         "mimeTypes", "onLine", "opsProfile",
                         "platform", "plugins", "systemLanguage",
                         "userAgent", "userLanguage", "userProfile");
    var s = "";
    for(var i = 0; i < attr.length; i++) {
        s = s + attr[i] + " = " + navigator[attr[i]] + "\\n";
//	if ((attr[i] == "mimeTypes" || attr[i] == "plugins") &&
//	    typeof navigator[attr[i]] == "object" &&
//	    navigator[attr[i]].length
//	   ) {
//	    for(var ii = 0; ii < navigator[attr[i]].length; ii++) {
//		s = s + "[" + ii + "]: " + navigator[attr[i]][ii] + "\\n";
//	    }
//	}
    }
    alert(s);
}

// what DHTML elements or functions are supported
function get_dhtml_info() {
   var s = "";
   if (document.layers) s+="NS 4.x layers\\n";
   if (document.all)    s+="IE document.all\\n";
   if (document.body)   s+="DOM compliant\\n";
   if (!document.layers && !document.all && document.body)
       s+="No DHTML implementation\\n";
   s+="\\n";
   s+="Functions/members supported:\\n";
   if (window.open)     s+="* window.open()\\n";
   if (window.focus)    s+="* window.focus()\\n";
   if (window.event)    s+="* window.event()\\n";
   if (document.getElementById) s+="* document.getElementById()\\n";
   if (Event && typeof Event.MOUSEMOVE != "undefined") s+="* Event.MOUSEMOVE\\n";

   alert(s);
}
// -->
</script>
EOF
	}
	$out .= "</head><body><pre>";
    }
    $out .= "Browser: " . $q->user_agent . "\n";
    $out .= " User-Agent-Name:    " . $self->{'user_agent_name'} . "\n";
    $out .= " User-Agent-Version: " . $self->{'user_agent_version'} . "\n";
    $out .= " User-Agent-OS:      " . $self->{'user_agent_os'} . "\n";
    $out .= "\nCapabilities:\n";
    $out .= " Text Browser:       " . (!!$self->{'text_browser'}) . "\n";
    $out .= " WAP Browser:        " . (!!$self->{'wap_browser'}) . "\n";
    $out .= " Mobile device:      " . (!!$self->{'mobile_device'}) . "\n";
    $out .= " Javascript:         " . (!!$self->{'can_javascript'}) . "\n";
    $out .= " CSS:                " . (!!$self->{'can_css'}) . "\n";
    $out .= " DHTML:              " . (!!$self->{'can_dhtml'}) . "\n";
    $out .= " Tables:             " . (!!$self->{'can_table'}) . "\n";
    $out .= " Display size        " . join("x", @{$self->{display_size}}) . "\n";
    $out .= "\nBugs:\n";
    $out .= " Window.open:        " . (!!$self->{'window_open_buggy'}) . "\n";
    $out .= " DHTML:              " . (!!$self->{'dhtml_buggy'}) . "\n";
    $out .= " CSS:                " . (!!$self->{'css_buggy'}) . "\n";
    if ($complete) {
	$out .= <<EOF;
</pre>
<br>
<a href="javascript:get_navigator()">Information via Javascript</a><br>
<a href="javascript:get_navigator2()">Same in an alternative manner (less error-prone way)</a><br>
<a href="javascript:get_dhtml_info()">DHTML information</a>
<br>
EOF
    }
    $out;
}

sub show_info_wml {
    my $self = shift;
    my $complete = shift;
    my $q = $self->{CGI};
    my $out = "";
    if ($complete) {
	$out .= <<EOF;
  <p>
Browser: @{[ $q->user_agent ]}<br/>
User-Agent-Name: @{[ $self->{'user_agent_name'} ]}<br/>
User-Agent-Version: @{[ $self->{'user_agent_version'} ]}<br/>
User-Agent-OS:      @{[ $self->{'user_agent_os'} ]}<br/>
<br/>Capabilities:<br/>
Text Browser:       @{[ (!!$self->{'text_browser'}) ]}<br/>
WAP Browser:        @{[ (!!$self->{'wap_browser'}) ]}<br/>
Mobile device:      @{[ (!!$self->{'mobile_device'}) ]}<br/>
Javascript:         @{[ (!!$self->{'can_javascript'}) ]}<br/>
CSS:                @{[ (!!$self->{'can_css'}) ]}<br/>
DHTML:              @{[ (!!$self->{'can_dhtml'}) ]}<br/>
Tables:             @{[ (!!$self->{'can_table'}) ]}<br/>
Display size        @{[ join("x", @{$self->{display_size}}) ]}<br/>
<br/>Bugs:<br/>
Window.open:        @{[ (!!$self->{'window_open_buggy'}) ]}<br/>
DHTML:              @{[ (!!$self->{'dhtml_buggy'}) ]}<br/>
CSS:                @{[ (!!$self->{'css_buggy'}) ]}<br/>
   <br/>
  </p>
EOF
    }
    $out;
}

sub show_server_info {
    my $bi = shift;
    my $out = "";
    if ($bi->{'wap_browser'}) {
	require HTML::Entities;
	$out .= "<p>Server Info (environment):<br/>\n";
	foreach my $env (sort keys %ENV) {
	    $out .= "$env: " . HTML::Entities::encode_entities_numeric($ENV{$env}) . "<br/>\n";
	}
	$out .= "</p>\n";
    } else {
	$out .= "Server Info (environment):<ul>\n";
	foreach my $env (sort keys %ENV) {
	    $out .= "<li>$env: $ENV{$env}\n";
	}
	$out .= "</ul>";
    }
    $out;
}

sub _get_browser_version {
    my($s, $sep) = @_;
    $sep = "/" unless defined $sep;
    if ($s =~ m|\b(Opera)\s+(\d+\.\d+)|) {
	($1, $2);
    } elsif ($s =~ m!^([^$sep]+)$sep(\d+\.\d+(\.\d+)?|beta-.*|PR\d+)!i) {
	($1, $2);
    } else {
	($s, 0);
    }
}

if (caller()) {
    if (!(defined $ENV{GATEWAY_INTERFACE} &&
	  $ENV{GATEWAY_INTERFACE} =~ /^CGI-Perl/ &&
	  (caller())[0] eq 'Apache::Registry')) {
	return 1;
    }
}

sub header {
    my $self = shift;
    my $q = $self->{CGI};
    my $out = "";
    if ($self->{'wap_browser'}) {
	$out .= $q->header(-type => 'text/vnd.wap.wml');
	$out .= <<EOF;
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.2//EN" "http://www.wapforum.org/DTD/wml12.dtd">
<wml>
 <card title="Browserinfo">
EOF
    } else {
	$out .= $q->header(-type => 'text/html');
	$out .= "<html><head><title>Browserinfo</title>";
    }
    $out;
}

sub footer {
    my $self = shift;
    my $out = "";
    if ($self->{'wap_browser'}) {
	$out .= "<p>by BrowserInfo.pm $BrowserInfo::VERSION</p></card>";
	$out .= "</wml>\n";
    } else {
	$out .= "<hr><small>by BrowserInfo.pm $BrowserInfo::VERSION</small>\n";
	$out .="</body>\n";
    }
    $out;
}

package main;
my $bi = new BrowserInfo CGI->new;
#$bi->emulate("wap");
print $bi->header;
print $bi->show_info('complete');
print $bi->show_server_info;
print $bi->footer;
exit;

