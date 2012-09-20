# -*- perl -*-

#
# $Id: HTML.pm,v 1.7 2003/10/22 21:36:11 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BikePower::HTML;
use BikePower;
use strict;
use vars qw($fontstr $VERSION);

$fontstr = "";
$VERSION = "0.02";

# XXX englische Version

sub cgi {
    require CGI;
    my $q = CGI->new;
    print $q->header;
    print code();
}

sub code {
    head() . body();
}

sub head {
    my $head = <<'EOF';
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2//EN"> <!-- -*-html-*- -->
<html><head>
<title>BikePower: pers&ouml;nliche Einstellungen</title>
<link rev=made href="mailto:slaven@rezic.de">
<meta name="viewport" content="width=device-width; initial-scale=1.0, max-scale=1.0, user-scalable=no">
EOF
    $head .= set_personal_settings_js_code();
    $head .= get_personal_settings_js_code();
    $head .= "</head>\n";
    $head;
}

sub body {
    my $body = <<'EOF';
<body onload="get_personal_settings()" bgcolor="#ffffff">
EOF
    $body .= $fontstr . <<'EOF';
<h1>BikePower: pers&ouml;nliche Einstellungen</h1>
<form name=personalsettings  onSubmit="set_personal_settings(); window.close(); return true;">
<table>
EOF
# <!--
# Temperature: <input type=text name=temperature>∞C<br>
# Wind velocity: <input type=text name=vw>m/s<br>
# Crosswind: <input type=checkbox name=crosswind value=1><br>
# Grade of hill: <input type=text name=
# -->
    $body .= <<EOF;
<tr><td>${fontstr}Fahrergewicht</td><td>${fontstr} <input align=right type=text name=weightcyclist value="77" size=3> kg</td></tr>
<tr><td>${fontstr}Gewicht von Rad+Kleidung</td><td>${fontstr} <input type=text name=weightmachine
value="12" size=3> kg</td></tr>
<tr><td>${fontstr}Haltung des Fahrers</td><td>${fontstr}<select name=frontalarea>
EOF
    foreach my $res_key (@BikePower::air_resistance_order) {
	my $res = $BikePower::air_resistance{$res_key};
	$body .= "<option value=\"" . $res->{A_c} . "\">"
	  . $res->{'text_de'} . "\n";
    }
    $body .= <<EOF;
</select></td></tr>
<tr><td>${fontstr}Rollwiderstand</td><td>${fontstr} <select name=rollfriction>
EOF
    foreach my $r (@BikePower::rolling_friction) {
	$body .= "<option value=\"" . $r->{'R'} . "\">"
	  . $r->{'text_de'} . "\n";
    }
    $body .= <<EOF;
</select></td></tr>
<tr><td>${fontstr}Effizienz der ‹bertragung</td><td>${fontstr} <input type=text name=transeff value="0.95" size=5></td></tr>
</table>
<input type=submit value="Werte sichern"> <a href="javascript:window.close()">Schlieﬂen</a>
</form>
</body></html>
EOF
    $body;
}

sub set_personal_settings_js_code {
    <<'EOF'
<script language=javascript><!--
function set_personal_settings() {
  var cookie;
  cookie = "BikePower=" +
           "frontalarea=" + document.personalsettings.frontalarea[document.personalsettings.frontalarea.selectedIndex].value + ":" +
           "transeff=" + document.personalsettings.transeff.value + ":" +
           "rollfriction=" + document.personalsettings.rollfriction[document.personalsettings.rollfriction.selectedIndex].value + ":" +
           "weightcyclist=" + document.personalsettings.weightcyclist.value + ":" +
           "weightmachine=" + document.personalsettings.weightmachine.value;
  var expires = new Date;
  expires.setTime(expires.getTime() + 1000*60*60*24*365*5);
  document.cookie = cookie + "; expires=" + expires.toGMTString();
}
// --></script>
EOF
}

sub get_personal_settings_js_code {
    my $code = <<'EOF';
<script language=javascript><!--
function adjust_frontalarea(val) {
    var f = new Array(
EOF
    my $need_comma;
    foreach my $res_key (@BikePower::air_resistance_order) {
	my $res = $BikePower::air_resistance{$res_key};
	if ($need_comma) {
	    $code .= ", ";
	} else {
	    $need_comma = 1;
	}
	$code .= "$res->{A_c}";
    }
    $code .= <<'EOF';
    );
    var i;
    var inx = 0;
    for (i in f) {
        if (val >= f[i]) return inx;
        inx++;
    }
    return inx-1;
}

function adjust_rollfriction(val) {
    var f = new Array(
EOF
    $need_comma = 0;
    foreach my $r (@BikePower::rolling_friction) {
	if ($need_comma) {
	    $code .= ", ";
	} else {
	    $need_comma = 1;
	}
	$code .= "$r->{R}";
    }
    $code .= <<'EOF';
    );
    var i;
    var inx = 0;
    for (i in f) {
        if (val <= f[i]) return inx;
        inx++;
    }
    return inx-1;
}

var token_str;
var token_delim;

function init_tokenizer(str, delim) {
  token_str = str;
  token_delim = delim;
}

function get_next_token() {
  if (token_str == "") return token_str;
  var inx = token_str.indexOf(token_delim);
  var ret;
  if (inx == -1) {
    ret = token_str;
    token_str = "";
  } else {
    ret = token_str.substring(0, inx);
    token_str = token_str.substring(inx+1, token_str.length);
  }
  return ret;
}

var token_val;
var token_key;

function get_key_val(str) {
  var inx = str.indexOf("=");
  if (inx == -1) {
    token_val = str;
    token_key = "";
  } else {
    token_val = str.substring(0, inx);
    token_key = str.substring(inx+1, str.length);
  }
}


function get_personal_settings() {
  var rest_cookie = document.cookie;
  while (rest_cookie != "") {
     var endofcookie = rest_cookie.indexOf(";");
     if (endofcookie == -1) endofcookie = rest_cookie.length
     var this_cookie = rest_cookie.substring(0, endofcookie);
     rest_cookie = rest_cookie.substring(endofcookie+1);
     while (rest_cookie.substring(0, 1) == " ") {
       rest_cookie = rest_cookie.substring(1);
     }
     var endofcookiekey = this_cookie.indexOf("=");
     var cookie_key = this_cookie.substring(0, endofcookiekey);
     if (cookie_key != "BikePower") continue;
     var cookie_val = this_cookie.substring(endofcookiekey+1);

     init_tokenizer(cookie_val, ":");
     while(1) {
       var valkey = get_next_token();
       if (valkey == "") break;
       get_key_val(valkey);
       var val = token_val;
       var key = token_key;
       if (val == "frontalarea") {
         document.personalsettings.frontalarea.selectedIndex = adjust_frontalarea(key);
       } else if (val == "transeff") {
         document.personalsettings.transeff.value = key;
       } else if (val == "rollfriction") {
         document.personalsettings.rollfriction.selectedIndex = adjust_rollfriction(key);
       } else if (val == "weightcyclist") {
         document.personalsettings.weightcyclist.value = key;
       } else if (val == "weightmachine") {
	 document.personalsettings.weightmachine.value = key;
       }
     }
     break;
  }
  return true;
}
// --></script>
EOF
    $code;
}

sub new_from_cookie {
    my $q = shift; # CGI object

    my $raw_cookie = $q->raw_cookie;
    return if !defined $raw_cookie || $raw_cookie eq '';
    my(@cookies) = split(/;\s*/, $raw_cookie);
    my %bikepower_def;
  TRY_COOKIE: {
	foreach (@cookies) {
	    my($name, $cookie_def) = split(/=/, $_, 2);
	    if ($name eq 'BikePower') {
		foreach (split(/:/, $cookie_def)) {
		    my($key, $val) = split(/=/, $_);
		    $bikepower_def{$key} = $val;
		}
		last TRY_COOKIE;
	    }
	}
	return;
    }

    require BikePower;
    my $bp_obj = new BikePower '-no-ini' => 1;
    foreach (['frontalarea', 'A_c'],
	     ['transeff', 'transmission_efficiency'],
	     ['rollfriction', 'rolling_friction'],
	     ['weightcyclist', 'weight_cyclist'],
	     ['weightmachine', 'weight_machine'],
	    ) {
	my($cgidef, $method) = ($_->[0], $_->[1]);
	if (exists $bikepower_def{$cgidef}) {
	    my $eval = '$bp_obj->' . $method . '($bikepower_def{$cgidef})';
	    eval $eval;
	    warn $@ if $@; # XXX
	}
    }

    $bp_obj;
}

1;

__END__
