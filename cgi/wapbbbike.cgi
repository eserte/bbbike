#!/usr/bin/env perl
# -*- perl -*-

#
# $Id: wapbbbike.cgi,v 1.4 2003/06/01 21:43:46 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000,2001,2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeRouting::WAP;
BEGIN { delete $INC{"FindBin.pm"} }
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../BBBike", "$FindBin::RealBin/../BBBike/lib");
use BBBikeRouting;
use BBBikeVar;
@ISA = 'BBBikeRouting';
use strict;

sub wap_can_table {
    shift->{BrowserInfo}->{can_table};
}

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
     Straﬂe: <input type="text" name="startname" emptyok="false"/><br/>
     Bezirk: <input type="text" name="startbezirk" emptyok="true"/><br/>
     <b>Ziel</b><br/>
     Straﬂe: <input type="text" name="zielname" emptyok="false" /><br/>
     Bezirk: <input type="text" name="zielbezirk" emptyok="true"/><br/>
  <anchor>Route zeigen
   <go href="@{[ $self->Context->CGI->script_name ]}" method="get">
    <postfield name="startname"   value="\$startname" />
    <postfield name="startbezirk" value="\$startbezirk" />
    <postfield name="zielname"    value="\$zielname" />
    <postfield name="zielbezirk"  value="\$zielbezirk" />
   </go>
  </anchor>
  </p>
 </card>
@{[ $self->wap_footer ]}
EOF
}

sub wap_resolve_street {
    my $self = shift;

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="input">
  <do type="options" label="Info" name="info">
   <go href="@{[ $self->Context->CGI->script_name ]}?info=1"/>
  </do>
  <do type="prev" label="Zur¸ck" name="prev"><prev /></do>
  <p align="center"><big>BBBike</big></p>
EOF
    my %has_postfields;
    my %has_known_postfields;
    for my $type (qw(Start Goal)) {
	my $de_label = $type eq 'Goal' ? 'Ziel' : 'Start';
	my $cgi_label = lc $de_label;
	my $choices = $type . "Choices";
	if ($self->$type() && $self->$type()->Coord) {
	    $has_known_postfields{$cgi_label}++;
	} elsif (@{ $self->$choices() } == 0) {
	    print <<EOF;
<p>Die ${de_label}stra&#223;e ist nicht in
der Datenbank enthalten. Andere ${de_label}stra&#223;e:<br/>
Straﬂe: <input type="text" name="${cgi_label}name" emptyok="false" /><br/>
Bezirk: <input type="text" name="${cgi_label}bezirk" emptyok="true"/><br/>
</p>
EOF
            $has_postfields{$cgi_label}++;
	} elsif (@{ $self->$choices() } > 1) {
	    print "<p>Mehrere <b>${de_label}stra&#223;en</b> gefunden:<br/>";
	    print "<select name=\"${cgi_label}namebezirk\">\n";
	    for my $option (@{ $self->$choices() }) {
		print "<option value=\"" . $option->Street."|".$option->Citypart . "\">" . $option->Street . " (" . $option->Citypart. ")</option>\n";
	    }
	    print "</select></p>";
	}
    }
    print <<EOF;
  <p>
  <anchor>Route zeigen
   <go href="@{[ $self->Context->CGI->script_name ]}" method="get">
EOF
    for my $type (qw(start ziel)) {
	my $member = $type eq 'start' ? 'Start' : 'Goal';
	if ($has_known_postfields{$type}) {
	    print <<EOF;
    <postfield name="${type}name"   value="@{[ $self->$member()->Street ]}" />
    <postfield name="${type}bezirk" value="@{[ $self->$member()->Citypart ]}" />
EOF
	} elsif ($has_postfields{$type}) {
	    print <<EOF;
    <postfield name="${type}name"   value="\$${type}name" />
    <postfield name="${type}bezirk" value="\$${type}bezirk" />
EOF
	} else {
	    print <<EOF;
	    <postfield name="${type}namebezirk" value="\$${type}namebezirk" />
EOF
	}
    }
    print <<EOF;
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
  @{[ $self->wap_can_table ? $self->wap_output_table : $self->wap_output_notable ]}
  </p>
  <p><anchor>Als Grafik zeigen<go href="@{[ $self->Context->CGI->script_name ]}">
    <postfield name="startname"    value="@{[$self->Start->Street]}" />
    <postfield name="startbezirk"  value="@{[$self->Start->Citypart]}" />
    <postfield name="zielname"   value="@{[$self->Goal->Street]}" />
    <postfield name="zielbezirk" value="@{[$self->Goal->Citypart]}" />
    <postfield name="output_as" value="imagepage" />
   </go>
  </anchor></p>
 </card>
@{[ $self->wap_footer ]}
EOF
}

sub wap_image {
    my $self = shift;

    my $imagetype = "wbmp";
    if ($self->Context->CGI->Accept("image/gif")) {
	$imagetype = "gif";
    }

    #$GD::Convert::DEBUG=10;
    print $self->Context->CGI->header(-type => ($imagetype eq 'wbmp' ? "image/vnd.wap.wbmp" : "image/gif"));

    require BBBikeDraw;
    my $draw = BBBikeDraw->new
	(ImageType => $imagetype,
	 Geometry => join("x", @{$self->{BrowserInfo}->{display_size}}),
	 Coords => [ map { join ",", @$_ } @{$self->Path} ],
	 Draw => ['str'],
	);

    $draw->draw_map;
    $draw->draw_route;
    $draw->flush;
}

sub wap_image_page {
    my $self = shift;

    my $q2 = $self->Context->CGI;
    $q2->param("output_as", "image");

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="output">
  <do type="options" label="Info" name="info">
   <go href="@{[ $self->Context->CGI->script_name ]}">
    <postfield name="info" value="1" />
   </go>
  </do>
  <do type="prev" label="Zur¸ck" name="prev"><prev /></do>
  <p>
  <img src="@{[ $self->Context->CGI->script_name ]}?@{[ $q2->query_string ]}" alt="Route von @{[$self->Start->Street]} (@{[$self->Start->Citypart]}) nach @{[$self->Goal->Street]} (@{[$self->Goal->Citypart]})" />
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
	if (defined $_->{Way} && $_->{Way} ne "") {
	    $out .= $_->{Way};
	}
	$out .= "</td><td>";
	if (defined $_->{Street}) {
	    $out .= $_->{Street};
	}
	$out .= "</td></tr>\n";
    }
    $out .= "<tr><td></td><td>@{[$self->RouteInfo->[-1]->{Whole}]}</td></tr></table>\n";
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
  Routensuche f¸r Radfahrer in Berlin<br/>
  von Slaven Rezic [<a href="mailto:$BBBike::EMAIL">$BBBike::EMAIL</a>]</p>
  <p>Statt eines Stra&#223;ennamens kann auch eine Kreuzung in der Schreibweise<br/>
  &nbsp;&nbsp;Stra&#223;e/Kreuzende Stra&#223;e<br/>
  angegeben werden. Die Angabe des Bezirks ist optional.
  </p>
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
	$self->{BrowserInfo} = $bi;
    };
    warn $@ if $@;
    $q;
}

sub wap_std_header {
    my $self = shift;
    my %args = @_;
    print $self->Context->CGI->header(-type => "text/vnd.wap.wml",
				      -expires => "now",
				      '-cache-control' => 'no-cache',
				      %args);
}

sub wap_init {
    my $self = shift;
    my %args;
    $self->wap_cgi_object;
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

return 1 if ((caller() and (caller())[0] ne 'Apache::Registry')
	     or keys %Devel::Trace::); # XXX Tracer bug

######################################################################

my $routing = BBBikeRouting->new->init_context;
bless $routing, 'BBBikeRouting::WAP'; # 5.005 compat


my $q = $routing->wap_init;
my $do_image = defined $q->param("output_as") && $q->param("output_as") eq 'image';
$routing->wap_std_header if !$do_image;

for my $type (qw(start ziel)) {
    if ($q->param("${type}namebezirk")) {
	my($street, $citypart) = split /\|/, $q->param("${type}namebezirk");
	$q->param("${type}name", $street);
	$q->param("${type}bezirk", $citypart);
    }
}

if ($q->param("info")) {
    $routing->wap_info();
} elsif (defined $q->param("output_as") && $q->param("output_as") eq 'imagepage') {
    $routing->wap_image_page;
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

    my $has_start = $routing->get_start_position;
    my $has_goal  = $routing->get_goal_position;

    if (!$has_start || !$has_goal) {
	$routing->wap_resolve_street;
    } else {
	$routing->search;

	if ($do_image) {
	    $routing->wap_image;
	} else {
	    $routing->wap_output;
	}
    }
} else {
    $routing->wap_input();
}
