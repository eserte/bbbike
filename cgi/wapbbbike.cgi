#!/usr/bin/env perl
# -*- perl -*-

#
# $Id: wapbbbike.cgi,v 2.11 2003/09/22 19:58:49 eserte Exp $
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

BEGIN {
    if ($ENV{SERVER_SOFTWARE} =~ /roxen/i) {
	open(STDERR, ">/tmp/wapbbbike.log");
    }
}

sub adjust_lib {
    delete $INC{"FindBin.pm"};
    require FindBin;
    require lib;
    lib->import("$FindBin::RealBin/..", "$FindBin::RealBin/../lib",
		"$FindBin::RealBin/../BBBike", "$FindBin::RealBin/../BBBike/lib");
    lib->import("/home/e/eserte/lib/perl"); # XXX fuer GD on cs
}

BEGIN { adjust_lib }

use BBBikeRouting;
use BBBikeVar;
@ISA = 'BBBikeRouting';
use strict;

use vars qw($use_apache_session);
$use_apache_session = 1 if !defined $use_apache_session;

sub wml {
    my $s = shift;
    $s =~ s/([&<>\$\x00-\x1f\x7f-\xff])/"&#".ord($1).";"/ge;
    $s;
}

sub wap_can_table {
    shift->{BrowserInfo}->{can_table};
}

sub wap_input {
    my $self = shift;

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="input" title="BBBike">
  <do type="options" label="Info" name="info">
   <go href="@{[ $self->Context->CGI->script_name ]}?info=1"/>
  </do>
  <do type="reset" label="Neu" name="reset"><refresh /></do>
<!--  <p align="center"><big>BBBike</big></p> -->
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
 <card id="input" title="BBBike">
  <do type="options" label="Info" name="info">
   <go href="@{[ $self->Context->CGI->script_name ]}?info=1"/>
  </do>
  <do type="prev" label="Zur¸ck" name="prev"><prev /></do>
<!--  <p align="center"><big>BBBike</big></p> -->
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
 <card id="output" title="BBBike Resultat">
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

sub _any_image {
    my($self, %args) = @_;

    my $cgi = $self->Context->CGI;

    my $imagetype = "wbmp";
    if ($cgi->Accept("image/gif")) {
	$imagetype = "gif";
    } elsif ($cgi->Accept("image/png")) {
	$imagetype = "png";
    }

    my $convert_to = undef;
    my %extra_args;
    if ($ENV{SERVER_NAME} =~ /herceg.de/) {
	require BBBikeDraw::MapServer;
	# XXX Usually can't use gif with gd:
	if ($imagetype ne 'png') {
	    if (!$cgi->Accept("image/png")) {
		$convert_to = $imagetype;
	    }
	    $imagetype = "png";
	}
	$extra_args{Conf} = BBBikeDraw::MapServer::Conf->bbbike_cgi_ipaq_conf
	    (ImageType => $imagetype);
	$extra_args{Module} = "MapServer";
    }

    my(@geometry) = @{$self->{BrowserInfo}->{display_size}};
    require BBBikeDraw;
    my $draw = BBBikeDraw->new
	(ImageType => $imagetype,
	 Geometry => join("x", @geometry),
	 Coords => [ map { join ",", @$_ } @{$self->Path} ],
	 Draw => ['str'],
	 NoScale => ($geometry[0] < 400),
	 %extra_args,
	);

    if ($args{bbox}) {
	$draw->set_bbox(@{ $args{bbox} });
    }

    $draw->draw_map;
    $draw->draw_route;
    if (defined $convert_to) {
	$draw->{ImageType} = $convert_to;
	print $cgi->header(-type => $draw->mimetype);

	my $temp = "/tmp/wapbbbike." . time . ".$$";
	open(FH, ">$temp") or die "Can't write to $temp: $!";
	$draw->flush(Fh => \*FH);
	close FH;

	my $temp2cmd = "";
	my $temp2;
	if ($ENV{MOD_PERL}) {
	    $temp2 = "/tmp/wapbbbike2." . time . ".$$";
	    $temp2cmd = " > $temp2";
	}
	if ($convert_to eq 'gif') {
	    system("pngtopnm $temp | ppmquant 256 | ppmtogif $temp2cmd");
	} else { # wbmp
	    system("pngtopnm $temp | ppmtopgm | pgmtopbm | pbmtowbmp $temp2cmd");
	}

	if (defined $temp2) {
	    open(IMG, $temp2) or die "Can't open file $temp2: $!";
	    local $/ = undef;
	    print <IMG>;
	    close IMG;
	    unlink $temp2;
	}
	unlink $temp;
    } else {
	print $cgi->header(-type => $draw->mimetype);
	$draw->flush;
    }

}

sub wap_image {
    my $self = shift;
    $self->_any_image;
}

sub wap_image_page {
    my $self = shift;

    my $q2 = $self->Context->CGI;
    $q2->param("output_as", "image");

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="output" title="BBBike Karte">
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

sub wap_surrounding_image {
    my $self = shift;
    my($cx,$cy) = split /,/, $self->Context->CGI->param("center");
    $self->_any_image(bbox => [$cx-500,$cy-500,$cx+500,$cy+500]);
}

sub wap_surrounding_image_page {
    my $self = shift;

    my $q2 = $self->Context->CGI;

    my @q;

    my $path = $self->{Session}->{Path};
    my $center = $q2->param("center");
    # XXX This is not optimal! Better to check for tile borders and
    # XXX create another image from there on...
    for my $i (0 .. $#$path) {
	local $" = ",";
	my $hop = $path->[$i];
	if ($center eq "@{$hop}") {
	    for (1..4) {
		push @q, CGI->new($q2->query_string);
	    }
	    if ($i == 0) {
		$q[0] = $q[1] = undef; # no prev
	    } else {
		$q[0]->param("center", "@{$path->[0]}");
		$q[1]->param("center", "@{$path->[$i-1]}");
	    }
	    if ($i == $#$path) {
		$q[2] = $q[3] = undef; # no next
	    } else {
		$q[2]->param("center", "@{$path->[$i+1]}");
		$q[3]->param("center", "@{$path->[-1]}");
	    }
	    last;
	}
    }

    $q2->param("output_as", "surroundingimage");

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="output" title="BBBike Karte">
  <do type="options" label="Info" name="info">
   <go href="@{[ $q2->script_name ]}">
    <postfield name="info" value="1" />
   </go>
  </do>
  <do type="prev" label="Zur¸ck" name="prev"><prev /></do>
  <p>
  <img src="@{[ $q2->script_name ]}?@{[ $q2->query_string ]}" alt="Umgebungskarte" />
  </p>
  <p>
EOF
    if ($q[0]) {
	print "<a href=\"" . $q[0]->url(-path_info=>1,-query=>1) . "\">|&lt;</a> ";
    }
    if ($q[1]) {
	print "<a href=\"" . $q[1]->url(-path_info=>1,-query=>1) . "\">&lt;</a> ";
    }
    if ($q[2]) {
	print "<a href=\"" . $q[2]->url(-path_info=>1,-query=>1) . "\">&gt;</a> ";
    }
    if ($q[3]) {
	print "<a href=\"" . $q[3]->url(-path_info=>1,-query=>1) . "\">&gt;|</a> ";
    }
    print <<EOF;
  </p>
 </card>
@{[ $self->wap_footer ]}
EOF
}

sub _surrounding_href {
    my($self, $hop) = @_;
    my $out = "";
    if ($self->{Session}) {
	$out .= "<a href=\"" . $self->Context->CGI->script_name . "?output_as=surroundingimagepage;sess=" . $self->{Session}{_session_id}
	    . ";center=" . $hop->{Coords} . "\">";
    }
    $out .= wml($hop->{Street});
    if ($self->{Session}) {
	$out .= "</a>";
    }
    $out;
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
	    $out .= $self->_surrounding_href($_);
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
	    $out .= $self->_surrounding_href($_);
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
 <card id="info"  title="BBBike Info">
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
    CGI->import('-newstyle_urls');
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
    return if $ENV{WAPBBBIKE_FROM_CMDLINE};
    my %args = @_;
    # Don't be defensive --- better to maintain a list of devices
    # where caching is crucial...
    print $self->Context->CGI->header(-type => "text/vnd.wap.wml",
				      #-expires => "now",
				      #'-cache-control' => 'no-cache',
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

sub tie_session {
    my $id = shift;
    return unless $use_apache_session;

    if (!eval {require Apache::Session::DB_File}) {
	$use_apache_session = undef;
	#warn $@;
	return;
    }

    tie my %sess, 'Apache::Session::DB_File', $id,
	{ FileName => "/tmp/wapbbbike_sessions_" . $< . ".db", # XXX make configurable
	  LockDirectory => '/tmp',
	} or do {
	    $use_apache_session = undef;
	    #warn $!;
	    return;
	};

    return \%sess;
}

return 1 if ((caller() and (caller())[0] ne 'Apache::Registry')
	     or keys %Devel::Trace::); # XXX Tracer bug

######################################################################

adjust_lib() if $ENV{MOD_PERL};

use vars qw($routing $q $do_image $sess);

$routing = BBBikeRouting->new->init_context;
bless $routing, 'BBBikeRouting::WAP'; # 5.005 compat
$routing->read_conf("$FindBin::RealBin/bbbike.cgi.config");

$q = $routing->wap_init;
$do_image = defined $q->param("output_as") &&
    ($q->param("output_as") eq 'image' ||
     $q->param("output_as") eq 'surroundingimage');
$routing->wap_std_header if !$do_image;

for my $type (qw(start ziel)) {
    if ($q->param("${type}namebezirk")) {
	my($street, $citypart) = split /\|/, $q->param("${type}namebezirk");
	$q->param("${type}name", $street);
	$q->param("${type}bezirk", $citypart);
    }
}

$sess = tie_session($q->param("sess"));
$routing->{Session} = $sess;

if ($q->param("info")) {
    $routing->wap_info();
} elsif (defined $q->param("output_as") && $q->param("output_as") eq 'imagepage') {
    $routing->wap_image_page;
} elsif (defined $q->param("output_as") && $q->param("output_as") eq 'surroundingimagepage') {
    $routing->wap_surrounding_image_page;
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
	if ($do_image) {
	    # Search or session
	    if (!$sess || !$sess->{Path}) {
		$routing->search;
	    } else {
		$routing->Path($sess->{Path});
	    }
	    $routing->wap_image;
	} else {
	    $routing->search;
	    $routing->wap_output;
	    if ($sess) {
		$sess->{Path} = $routing->Path;
	    }
	}
    }
} elsif (defined $q->param("output_as") && $q->param("output_as") eq 'surroundingimage') {
    # Search or session
    if (!$sess || !$sess->{Path}) {
	$routing->search;
	$sess->{Path} = $routing->Path;
    } else {
	$routing->Path($sess->{Path});
    }
    $routing->wap_surrounding_image;
} else {
    $routing->wap_input();
}

untie %$sess if $sess;
