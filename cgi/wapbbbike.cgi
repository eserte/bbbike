#!/usr/bin/env perl
# -*- perl -*-

#
# $Id: wapbbbike.cgi,v 2.27 2008/02/20 23:04:54 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000,2001,2003,2004,2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeRouting::WAP;

BEGIN {
    # see also webeditor/cgi-bin/we_redisys.cgi
    if (defined $ENV{SERVER_SOFTWARE} &&
	$ENV{SERVER_SOFTWARE} =~ m{(netscape|roxen|apache/2\.0)}i
       ) {
	open(STDERR, ">/tmp/wapbbbike.log");
    }
}

sub adjust_lib {
    delete $INC{"FindBin.pm"};
    require FindBin;
    require lib;
    "lib"->import(grep { -d }
		  ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib",
		   "$FindBin::RealBin/../BBBike", "$FindBin::RealBin/../BBBike/lib"));
    "lib"->import("/home/e/eserte/lib/perl"); # XXX fuer GD on cs
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

sub _wap_hr {
    print "<p>" . "-"x10 . "</p>";
}

sub wap_input {
    my $self = shift;

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="input" title="BBBike">
<!--  <p align="center"><big>BBBike</big></p> -->
  <p><b>Start</b><br/>
     Straße: <input type="text" name="startname" emptyok="false"/><br/>
     Bezirk: <input type="text" name="startbezirk" emptyok="true"/><br/>
     <b>Ziel</b><br/>
     Straße: <input type="text" name="zielname" emptyok="false" /><br/>
     Bezirk: <input type="text" name="zielbezirk" emptyok="true"/><br/>
  <anchor>Route suchen
   <go href="@{[ $self->Context->CGI->script_name ]}?startname=\$(startname)&amp;startbezirk=\$(startbezirk)&amp;zielname=\$(zielname)&amp;zielbezirk=\$(zielbezirk)" method="get"/>
  </anchor><br/>
  <anchor>Erweiterte Suche
   <go href="@{[ $self->Context->CGI->script_name ]}?startname=\$(startname)&amp;startbezirk=\$(startbezirk)&amp;zielname=\$(zielname)&amp;zielbezirk=\$(zielbezirk);form=advanced" method="get"/>
  </anchor>
  </p>
EOF
    $self->_wap_hr;
    print "<p>";
    $self->_wap_info;
    print <<EOF;
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
<!--  <p align="center"><big>BBBike</big></p> -->
EOF
    my %postfields;
    if ($self->Ext->{Form} ne 'normal') {
	$postfields{"form"} = $self->Ext->{Form};
    }

    for my $type (qw(Start Goal)) {
	my $de_label = $type eq 'Goal' ? 'Ziel' : 'Start';
	my $cgi_label = lc $de_label;
	my $choices = $type . "Choices";
	if (@{ $self->$choices() } > 1) {
	    print "<p>";
	    my $choices_is_crossings = $type . "ChoicesIsCrossings";
	    if ($self->$choices_is_crossings) {
		print "Genaue Kreuzung angeben: <b>" . $self->$type->Street . "</b> Ecke<br/>";
		print "<select name=\"${cgi_label}coord\">\n";
		for my $option (@{ $self->$choices() }) {
		    print "<option value=\"" . $option->Coord . "\">" . $option->Street . " " . _def_citypart($option) . "</option>\n";
		}
		print "</select>";
		$postfields{$cgi_label."coord"} = "\$${cgi_label}coord";
		$postfields{$cgi_label."name"} = wml($self->$type->Street);
		$postfields{$cgi_label."bezirk"} = wml($self->$type->Citypart);
	    } else {
		print "Mehrere <b>${de_label}stra&#223;en</b> gefunden:<br/>";
		print "<select name=\"${cgi_label}namebezirk\">\n";
		for my $option (@{ $self->$choices() }) {
		    print "<option value=\"" . $option->Street."|".$option->Citypart . "\">" . $option->Street . " " . _def_citypart($option) . "</option>\n";
		}
		print "</select>";
		$postfields{$cgi_label."namebezirk"} = "\$${cgi_label}namebezirk";
	    }
	    print "</p>";
	} elsif ($self->$type() && $self->$type()->Coord) {
	    $postfields{$cgi_label."name"} = wml($self->$type->Street);
	    $postfields{$cgi_label."bezirk"} = wml($self->$type->Citypart);
	} else { # if (@{ $self->$choices() } == 0) {
	    print <<EOF;
<p>Die ${de_label}stra&#223;e ist nicht in
der Datenbank enthalten. Andere ${de_label}stra&#223;e:<br/>
Straße: <input type="text" name="${cgi_label}name" emptyok="false" /><br/>
Bezirk: <input type="text" name="${cgi_label}bezirk" emptyok="true"/><br/>
</p>
EOF
	    $postfields{$cgi_label."name"} = "\$${cgi_label}name";
	    $postfields{$cgi_label."bezirk"} = "\$${cgi_label}bezirk";
	}
    }
    print <<EOF;
  <p>
  <anchor>Route suchen
   <go href="@{[ $self->Context->CGI->script_name ]}" method="get">
EOF
    while(my($k,$v) = each %postfields) {
	print <<EOF;
    <postfield name="$k" value="$v" />
EOF
    }
    print <<EOF;
   </go>
  </anchor>
  </p>
 </card>
@{[ $self->wap_footer ]}
EOF
}

sub _wap_info {
    my $self = shift;
    print <<EOF;
  <anchor>Info
   <go href="@{[ $self->Context->CGI->script_name ]}?info=1"/>
  </anchor><br/>
EOF
}

sub _wap_new_search {
    my $self = shift;
    print <<EOF;
  <anchor>Neue Anfrage
   <go href="@{[ $self->Context->CGI->script_name ]}">
    <setvar name="startname"   value="" />
    <setvar name="startbezirk" value="" />
    <setvar name="startcoord"  value="" />
    <setvar name="zielname"    value="" />
    <setvar name="zielbezirk"  value="" />
    <setvar name="zielcoord"   value="" />
   </go>
  </anchor><br/>
EOF
}

sub _def_citypart {
    my $pos = shift;
    if (defined $pos->Citypart && $pos->Citypart !~ m{^\s*$}) {
	"(" . $pos->Citypart . ")";
    } else {
	"";
    }
}

sub wap_output {
    my $self = shift;

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="output" title="BBBike Resultat">
  <p>Route von
   <b> @{[$self->Start->Street]} @{[_def_citypart($self->Start)]} </b> nach
   <b> @{[$self->Goal->Street]} @{[_def_citypart($self->Goal)]} </b><br/>
  @{[ $self->wap_can_table ? $self->wap_output_table : $self->wap_output_notable ]}
  </p><p>
EOF
    if ($self->{Session}) {
	my $q2 = $self->Context->CGI;
	$q2->param("output_as", "imagepage");
	$q2->param("sess", $self->{Session}{_session_id});
	print <<EOF;
   <anchor>Als Grafik zeigen<go href="@{[ $q2->script_name ]}?@{[ $q2->query_string ]}"></go></anchor><br/>
EOF
    } else {
	print <<EOF;
   <anchor>Als Grafik zeigen<go href="@{[ $self->Context->CGI->script_name ]}">
    <postfield name="startname"   value="@{[$self->Start->Street]}" />
    <postfield name="startbezirk" value="@{[$self->Start->Citypart]}" />
    <postfield name="startcoord"  value="@{[$self->Goal->Coord]}" />
    <postfield name="zielname"    value="@{[$self->Goal->Street]}" />
    <postfield name="zielbezirk"  value="@{[$self->Goal->Citypart]}" />
    <postfield name="zielcoord"   value="@{[$self->Start->Coord]}" />
    <postfield name="output_as" value="imagepage" />
    </go>
   </anchor><br/>
EOF
    }
    print <<EOF;
  <anchor>Rückweg
   <go href="@{[ $self->Context->CGI->script_name ]}">
    <postfield name="startname"   value="@{[$self->Goal->Street]}" />
    <postfield name="startbezirk" value="@{[$self->Goal->Citypart]}" />
    <postfield name="startcoord"  value="@{[$self->Goal->Coord]}" />
    <postfield name="zielname"    value="@{[$self->Start->Street]}" />
    <postfield name="zielbezirk"  value="@{[$self->Start->Citypart]}" />
    <postfield name="zielcoord"   value="@{[$self->Start->Coord]}" />
   </go>
  </anchor><br/>
EOF
    $self->_wap_new_search;
    print <<EOF;

  </p>
 </card>
@{[ $self->wap_footer ]}
EOF
}

sub wap_error {
    my $self = shift;
    my $errormessage = shift;

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="output" title="BBBike Fehler">
  <p><b>Fehler:</b> @{[ wml($errormessage) ]}</p>
 </card>
@{[ $self->wap_footer ]}
EOF
}

sub _any_image {
    my($self, %args) = @_;

    my $cgi = $self->Context->CGI;

    my $imagetype = "wbmp";
    if ($cgi->Accept("image/png")) {
	$imagetype = "png";
    } elsif ($cgi->Accept("image/gif")) {
	$imagetype = "gif";
    }

    my $convert_to = undef;
    my %extra_args;
    if ($BBBikeConf::wapbbbike_use_mapserver) {
	if (!eval { require BBBikeDraw::MapServer; 1 }) {
	    warn $@ if $@;
	} else {
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
    }

    my(@geometry) = $self->{BrowserInfo} && $self->{BrowserInfo}->{display_size} ? @{$self->{BrowserInfo}->{display_size}} : ();
    if ($cgi->param("debug") || !@geometry) {
	@geometry = (170, 144);
    }

    require BBBikeDraw;
    my $draw = BBBikeDraw->new
	(ImageType => $imagetype,
	 Geometry => join("x", @geometry),
	 Coords => [ map { join ",", @$_ } @{$self->Path} ],
	 Draw => ['str', 'wasser', 'flaechen', 'ubahn', 'sbahn'],
	 NoScale => ($geometry[0] < 400),
	 MarkerPoint => $args{markerpoint},
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
	my $cmd;
	if ($convert_to eq 'gif') {
	    $cmd = "pngtopnm $temp | ppmquant 2>/dev/null 256 | ppmtogif 2>/dev/null $temp2cmd ";
	} else { # wbmp
	    # with the default pgmtopbm the resulting image is just white
	    $cmd = "pngtopnm $temp | ppmtopgm | pgmtopbm -d8 | pbmtowbmp $temp2cmd";
	}
	#warn $cmd;
	system($cmd);
	if ($? != 0) {
	    warn "In case of netpbm errors: try to upgrade to at least version 10.26.30";
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
    if ($self->{Session}) {
	$q2->param("sess", $self->{Session}{_session_id});
    }

    my $start;
    if ($self->Start && $self->Start->Street) {
	$start = $self->Start->Street . " " . _def_citypart($self->Start);
    } else {
	$start = $q2->param("startname") || "???";
    }
    my $goal;
    if ($self->Goal && $self->Goal->Street) {
	$goal = $self->Goal->Street . " " . _def_citypart($self->Goal);
    } else {
	$goal = $q2->param("zielname") || "???";
    }

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="output" title="BBBike Karte">
  <p>
   <img src="@{[ $q2->script_name ]}?@{[ $q2->query_string ]}" alt="Route von $start nach $goal" /><br/>
   <anchor>Routenliste<prev /></anchor><br/>
EOF
    $self->_wap_new_search;
    print <<EOF;
  </p>
 </card>
@{[ $self->wap_footer ]}
EOF
}

sub wap_surrounding_image {
    my $self = shift;
    my $center = $self->Context->CGI->param("center");
    my($cx,$cy) = split /,/, $center;
    $self->_any_image(bbox => [$cx-500,$cy-500,$cx+500,$cy+500],
		      markerpoint => $center);
}

# XXX This is not optimal! Better to check for tile borders and
# XXX create another image from there on...
sub wap_surrounding_image_page {
    my $self = shift;

    use constant FIRST   => 0;
    use constant PREV    => 1;
    use constant NEXT    => 2;
    use constant LAST    => 3;
    use constant PREVDIR => 4;
    use constant NEXTDIR => 5;
    use constant LAST_INX => 5;

    my $q2 = $self->Context->CGI;
    my $q3 = CGI->new($q2->query_string);

    my @q;

    my $path = $self->{Session}->{Path};
    my $route_info = $self->{Session}->{RouteInfo};

    my $center = $q2->param("center");
    my $found;
    my $label;

    # First try to get a route point...
    for my $i (0 .. $#$route_info) {
	my $hop = $route_info->[$i];
	if ($center eq $hop->{Coords}) {
	    $label = $hop->{Street};
	    if ($i > 0) {
		$label .= " (" . $route_info->[$i-1]->{Whole} . ")";
	    }
	    for (0 .. LAST_INX) {
		push @q, CGI->new($q2->query_string);
	    }
	    if ($i == 0) {
		$q[FIRST] = $q[PREVDIR] = $q[PREV] = undef;
	    } else {
		$q[FIRST]->param("center", $route_info->[0]->{Coords});
		$q[PREV] ->param("center", $route_info->[$i-1]->{Coords});
	    TRY: {
		    for my $ii (reverse(0 .. $i-1)) {
			if (defined $route_info->[$ii]->{Way} &&
			    $route_info->[$ii]->{Way} ne "") {
			    $q[PREVDIR]->param("center",
					       $route_info->[$ii]->{Coords});
			    last TRY;
			}
		    }
		    $q[PREVDIR] = undef;
		}
	    }
	    if ($i == $#$route_info) {
		$q[NEXT] = $q[NEXTDIR] = $q[LAST] = undef;
	    } else {
		$q[NEXT]->param("center", $route_info->[$i+1]->{Coords});
		$q[LAST]->param("center", $route_info->[-1]->{Coords});
	    TRY: {
		    for my $ii ($i+1 .. $#$route_info) {
			if (defined $route_info->[$ii]->{Way} &&
			    $route_info->[$ii]->{Way} ne "") {
			    $q[NEXTDIR]->param("center",
					       $route_info->[$ii]->{Coords});
			    last TRY;
			}
		    }
		    $q[NEXTDIR] = undef;
		}
	    }
	    $found++;
	    last;
	}
    }

    if (!$found) {
	warn "Nothing found in RouteInfo, fallback to search in Path";
	# Fallback to searching in path
	for my $i (0 .. $#$path) {
	    local $" = ",";
	    my $hop = $path->[$i];
	    if ($center eq "@{$hop}") {
		for (FIRST, PREV, NEXT, LAST) {
		    push @q, CGI->new($q2->query_string);
		}
		if ($i == 0) {
		    $q[FIRST] = $q[PREV] = undef; # no prev
		} else {
		    $q[FIRST]->param("center", "@{$path->[0]}");
		    $q[PREV] ->param("center", "@{$path->[$i-1]}");
		}
		if ($i == $#$path) {
		    $q[NEXT] = $q[LAST] = undef; # no next
		} else {
		    $q[NEXT]->param("center", "@{$path->[$i+1]}");
		    $q[LAST]->param("center", "@{$path->[-1]}");
		}
		last;
	    }
	}
    }

    $q2->param("output_as", "surroundingimage");
    $q3->param("output_as", "resultpage");

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="output" title="BBBike Karte">
  <p>
  <img src="@{[ $q2->script_name ]}?@{[ $q2->query_string ]}" alt="Umgebungskarte" />
EOF
    if (defined $label) {
	print "<br/>" . wml($label) . "<br/>";
    }
    print <<EOF;
  </p>
  <p>
EOF
    # As we use here -absolute => 1 in the url() call, we don't need to
    # worry about hostnames.
    if ($q[FIRST]) {
	print "<a href=\"" . $q[FIRST]->url(-absolute => 1,-path_info=>1,-query=>1) . "\">|&lt;</a> ";
    }
    if ($q[PREVDIR]) {
	print "<a href=\"" . $q[PREVDIR]->url(-absolute => 1,-path_info=>1,-query=>1) . "\">&lt;&lt;</a> ";
    }
    if ($q[PREV]) {
	print "<a href=\"" . $q[PREV]->url(-absolute => 1,-path_info=>1,-query=>1) . "\">&lt;</a> ";
    }
    if ($q[NEXT]) {
	print "<a href=\"" . $q[NEXT]->url(-absolute => 1,-path_info=>1,-query=>1) . "\">&gt;</a> ";
    }
    if ($q[NEXTDIR]) {
	print "<a href=\"" . $q[NEXTDIR]->url(-absolute => 1,-path_info=>1,-query=>1) . "\">&gt;&gt;</a> ";
    }
    if ($q[LAST]) {
	print "<a href=\"" . $q[LAST]->url(-absolute => 1,-path_info=>1,-query=>1) . "\">&gt;|</a> ";
    }
    print <<EOF;
  <br/><anchor><go href="@{[ $q3->script_name ]}?@{[ $q3->query_string ]}"/>Routenliste</anchor><br/>
EOF
    $self->_wap_new_search;
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
    $out .= "</table>\n";

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
    $out;
}

sub wap_info {
    my $self = shift;

    print <<EOF;
@{[ $self->wap_header ]}
 <card id="info"  title="BBBike Info">
  <p><b>BBBike</b><br/>
  Routensuche für Radfahrer in Berlin<br/>
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
    print $self->Context->CGI->header
	(-type => "text/vnd.wap.wml",
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
<!-- <head>
  <meta forua="true" http-equiv="Cache-Control" content="no-cache, max-age=0, must-revalidate, proxy-revalidate, s-maxage=0"/>
 </head>
-->
 <template>
  <do type="prev" label="Zurück"><prev/></do>
 </template>
EOF
}

sub wap_footer {
    my $self = shift;
    <<EOF;
</wml>
EOF
}

# Add the last point manually --- or should this be done in BBBikeRouting? XXX
sub search {
    my $self = shift;
    $self->SUPER::search(@_);
    my $route_info = $self->RouteInfo;
    my $path       = $self->Path;
    if ($route_info && $path) {
	push @$route_info, {Street => "angekommen, " . $route_info->[-1]{Whole},
			    Coords => join ",", @{$path->[-1]},
			   };
    }
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

return 1 if ((caller() and (caller())[0] ne 'Apache::Registry'));
#	     or keys %Devel::Trace::); # XXX Tracer bug XXX del, not anymore

######################################################################

adjust_lib() if $ENV{MOD_PERL};

use vars qw($routing $q $do_image $sess @member);

@member = qw(Path RouteInfo Start Goal);

sub get_session {
    my $routing = shift;
    for my $member (@member) {
	eval {
	    $routing->$member($sess->{$member});
	}; # catch errors if assigning "undef" to a object-expecting member
    }
}

sub store_session {
    my $routing = shift;
    for my $member (@member) {
	$sess->{$member} = $routing->$member();
    }
}

$routing = BBBikeRouting->new->init_context;
$routing->Context->MultipleChoicesLimit(7);
bless $routing, 'BBBikeRouting::WAP'; # 5.005 compat
$routing->Ext({ Form => "normal" });
$routing->read_conf("$FindBin::RealBin/bbbike.cgi.config");

$BBBikeConf::wapbbbike_use_mapserver = $BBBikeConf::wapbbbike_use_mapserver; # cease -w

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
    $routing->get_session;
    $routing->wap_image_page;
} elsif (defined $q->param("output_as") && $q->param("output_as") eq 'surroundingimagepage') {
    $routing->get_session;
    $routing->wap_surrounding_image_page;
} elsif (defined $q->param("output_as") && $q->param("output_as") eq 'image' && $sess && $sess->{Path}) {
    $routing->get_session;
    $routing->wap_image;
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

    if ($q->param("form") && $q->param("form") eq 'advanced') {
	$routing->Context->ChooseExactCrossing(1);
	$routing->Ext({ Form => $q->param("form") });
    }

    my($has_start, $has_goal);
    if (defined $q->param("startcoord") && $q->param("startcoord") ne "") {
	$routing->Start->Coord($q->param("startcoord"));
	$has_start = 1;
    } else {
	$has_start = $routing->get_start_position;
    }
    if (defined $q->param("zielcoord") && $q->param("zielcoord") ne "") {
	$routing->Goal->Coord($q->param("zielcoord"));
	$has_goal = 1;
    } else {
	$has_goal = $routing->get_goal_position;
    }

    if (!$has_start || !$has_goal) {
	$routing->wap_resolve_street;
    } else {
	if ($do_image) {
	    # Search or session
	    if (!$sess || !$sess->{Path}) {
		$routing->search;
	    } else {
		$routing->get_session;
	    }
	    $routing->wap_image;
	} else {
	    $routing->search;
	    $routing->wap_output;
	    if ($sess) {
		$routing->store_session;
	    }
	}
    }
} elsif (defined $q->param("output_as") && $q->param("output_as") eq 'resultpage') {
    if (!$sess || !$sess->{Path}) {
	$routing->wap_error("Die Session ist nicht mehr gültig!");
    } else {
	$routing->get_session;
	$routing->wap_output;
    }
} elsif (defined $q->param("output_as") && $q->param("output_as") eq 'surroundingimage') {
    # Search or session
    if (!$sess || !$sess->{Path}) {
	$routing->search;
	$routing->store_session;
    } else {
	$routing->get_session;
    }
    $routing->wap_surrounding_image;
} else {
    $routing->wap_input();
}

untie %$sess if $sess;
