#!/usr/bin/env perl
# -*- perl -*-

#
# $Id: wapbbbike.cgi,v 1.3 2003/01/07 19:46:20 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000,2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeRouting::WAP;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");
use BBBikeRouting;
@ISA = 'BBBikeRouting';
use strict;

use vars qw($can_table);

sub wap_can_table { $can_table }

sub wap_input {
    my $self = shift;

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="input">
  <do type="options" label="Info" name="info">
   <go href="@{[ $self->Context->CGI->script_name ]}?info=1"/>
  </do>
  <do type="reset" label="Neu" name="reset"><refresh /></do>
  <p align="center"><big>BBBike</big></p>
  <p><b>Start</b><br/>
     Straﬂe: <input type="text" name="startname" /><br/>
     Bezirk: <input type="text" name="startbezirk" /><br/>
     Ziel<br/>
     Straﬂe: <input type="text" name="zielname" /><br/>
     Bezirk: <input type="text" name="zielbezirk" /><br/>
  <anchor>Route zeigen
   <go href="@{[ $self->Context->CGI->script_name ]}" cache-control="no-cache" method="get">
    <postfield name="startname"   value="\$(startname)" />
    <postfield name="startbezirk" value="\$(startbezirk)" />
    <postfield name="zielname"    value="\$(zielname)" />
    <postfield name="zielbezirk"  value="\$(zielbezirk)" />
    <postfield name="test"  value="foobar" />
   </go>
  </anchor>
  </p>
 </card>
@{[ $self->wap_footer ]}
EOF
}

sub wap_output {
    my $self = shift;

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="output">
  <do type="options" label="R¸ckweg" name="back">
   <go href="@{[ $self->Context->CGI->script_name ]}">
    <postfield name="startname"   value="@{[$self->Goal->Street]}" />
    <postfield name="startbezirk" value="@{[$self->Goal->Citypart]}" />
    <postfield name="zielname"    value="@{[$self->Start->Street]}" />
    <postfield name="zielbezirk"  value="@{[$self->Start->Citypart]}" />
   </go>
  </do>
  <do type="options" label="Neue Anfrage" name="newsearch">
   <go href="@{[ $self->Context->CGI->script_name ]}">
    <setvar name="startname"   value="" />
    <setvar name="startbezirk" value="" />
    <setvar name="zielname"    value="" />
    <setvar name="zielbezirk"  value="" />
   </go>
  </do>
  <do type="options" label="Info" name="info">
   <go href="@{[ $self->Context->CGI->script_name ]}">
    <postfield name="info" value="1" />
   </go>
  </do>
  <do type="prev" label="Zur¸ck" name="prev"><prev /></do>
  <p>Route von <b> @{[$self->Start->Street]} (@{[$self->Start->Citypart]}) </b> nach <b> @{[$self->Goal->Street]} (@{[$self->Goal->Citypart]}) </b><br/>
  @{[ $can_table ? $self->wap_output_table : $self->wap_output_notable ]}
  </p>
 </card>
@{[ $self->wap_footer ]}
EOF
}

sub wap_output_table {
    my $self = shift;

    my $out = "<table columns=\"2\">\n";
    foreach (@{ $self->RouteInfo }) {
	$out .= "<tr><td>";
	if (defined $_->{Street}) {
	    $out .= $_->{Street};
	}
	$out .= "</td><td>";
	if (defined $_->{Way} && $_->{Way} ne "") {
	    $out .= $_->{Way};
	}
	$out .= "</td></tr>\n";
    }
    $out .= "<tr><td>@{[$self->RouteInfo->[-1]->{Whole}]}</td><td></td></tr></table>\n";
    $out;
}

sub wap_output_notable {
    my $self = shift;

    my $out = "";
    foreach (@{ $self->RouteInfo }) {
        if (defined $_->{Way} && $_->{Way} ne "") {
	    $out .= "$_->{Way} =&gt; ";
        }
	if (defined $_->{Street}) {
	    $out .= $_->{Street};
	}
	$out .= "<br/>\n";
    }
    $out .= "@{[$self->RouteInfo->[-1]->{Whole}]}<br/>\n";
    $out;
}

sub wap_info {
    my $self = shift;

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="info">
  <do type="prev" label="Zur¸ck" name="prev"><prev /></do>
  <p><b>BBBike</b><br/>
  by Slaven Rezic [slaven.rezic\@berlin.de]</p>
 </card>
@{[ $self->wap_footer ]}
EOF
}

sub wap_cgi_object {
    my $self = shift;

    require CGI;
    my $q = $self->Context->CGI(CGI->new);
    eval {
	require BrowserInfo;
	my $bi = $self->Context->BrowserInfo(BrowserInfo->new($q));
	$can_table = $bi->{'can_table'};
    };
    warn $@ if $@;
    $q;
}

sub wap_std_header {
    my $self = shift;
    my %args = @_;
    $args{'-Cache-Control'} = "must-revalidate, max-age=0, no-cache";
    print $self->Context->CGI->header(-type => "text/vnd.wap.wml", %args);
}

sub wap_init {
    my $self = shift;
    $self->wap_cgi_object;
    $self->wap_std_header;
    $self->Context->CGI;
}

sub wap_header {
    my $self = shift;
    <<EOF;
<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN" "http://www.wapforum.org/DTD/wml_1.1.xml">
<wml>
EOF
}

sub wap_footer {
    my $self = shift;
    <<EOF;
</wml>
EOF
}

return 1 if caller() or keys %Devel::Trace::; # XXX Tracer bug

######################################################################

package main;

my $routing = BBBikeRouting->new->init_context;
bless $routing, 'BBBikeRouting::WAP'; # 5.005 compat

my $q = $routing->wap_init;
require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$q],[])->Indent(1)->Useqq(1)->Dump; # XXX
if ($q->param("info")) {
    $routing->wap_info();
} elsif (defined $q->param("startname") &&
	 $q->param("startname") ne ""
	 &&
	 defined $q->param("zielname")  &&
	 $q->param("zielname") ne ""
	) {
    $routing->Start->Street  ($q->param("startname"));
    $routing->Goal->Street   ($q->param("zielname"));
    $routing->Start->Citypart($q->param("startbezirk"));
    $routing->Goal->Citypart ($q->param("zielbezirk"));

    $routing->search;
    $routing->wap_output;
} else {
    $routing->wap_input();
}

__END__

