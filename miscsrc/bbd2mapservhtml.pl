#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004,2005,2012,2013,2014,2015,2016,2018,2023 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Create a HTML-Formular from bbd data. The HTML form will redirect to
# MapServer using the specified data for a new (route) layer.

use strict;
use warnings;
use FindBin;
use utf8;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
use Strassen::Core;
use Strassen::Util;
use Strassen::Combine;
use Object::Iterate qw(iterate);
use Getopt::Long;
use BBBikeVar;
use CGI qw();
use URI::Escape qw(uri_escape);

my $COORD_SEP = '!'; # "!" for older bbbike.cgi

my $bbbike_url = $BBBike::BBBIKE_DIRECT_WWW;
my $email = $BBBike::EMAIL;
my @layers;
my($width, $height);
my $mapscale;
my $center_spec;
my $do_center_nearest;
my $partialhtml;
my $do_linklist;
my $do_headlines;
my $only_one_direction;
my $distinguish_directions;
my $do_alternatives_handling;
my $do_completeness;
my $preferalias;
my $imagetype = "mapserver";
my $title = "Mapserver/BBBike";
my @custom_link_defs;
my $do_routelist_button = 1;
my $do_mapserver_button = 1;
my $do_leaflet_button = 1;
my $link_target;
my $bad_browser_compat = 1; # e.g. IE7/8
my $debug;

my $save_cmdline = "$0 @ARGV";

if (!GetOptions("bbbikeurl=s" => \$bbbike_url,
		"email=s" => \$email,
		'layer=s@' => \@layers,
		'initmapext=s' => sub {
		    ($width, $height) = split /x/, $_[1];
		},
		'mapscale=s' => sub {
		    my $scale = $_[1];
		    $scale =~ s{^1:}{};
		    if ($scale !~ /^\d+$/) {
			die "-mapscale must be a number or 1:number";
		    }
		    $width = $height = $scale/5;
		},
		'center=s' => \$center_spec,
		'centernearest!' => \$do_center_nearest,
		'partialhtml!' => \$partialhtml,
		'linklist!' => \$do_linklist,
		'preferalias!' => \$preferalias,
		'headlines!' => \$do_headlines,
		'imagetype=s' => \$imagetype,
		'title=s' => \$title,
		'onlyonedirection!' => \$only_one_direction,
		'distinguishdirections!' => \$distinguish_directions,
		'althandling!' => \$do_alternatives_handling,
		'completeness!' => \$do_completeness,
		'customlink=s@' => \@custom_link_defs,
		'routelistbutton!' => \$do_routelist_button,
		'mapserverbutton!' => \$do_mapserver_button,
		'leafletbutton!' => \$do_leaflet_button,
		'linktarget=s' => \$link_target,
		'debug' => \$debug,
	       )) {
    require Pod::Usage;
    Pod::Usage::pod2usage(2);
}

if (!@layers) {
    push @layers, qw(sbahn rbahn wasser flaechen str grenzen ort fragezeichen);
}

for (@custom_link_defs) {
    my($url, $label) = split /\s+/, $_, 2;
    $_ = { url => $url, label => $label };
}

# XXX does not work if bbbike_url contains something else
(my $leaflet_url = $bbbike_url) =~ s{\Qbbbike.cgi\E}{bbbikeleaflet.cgi};

my $bbd_file = shift || "-";
my $s;
if ($bbd_file =~ /\.bbr$/) {
    require Route;
    require Route::Heavy;
    $s = Route::as_strassen($bbd_file);
} else {
    $s = Strassen->new($bbd_file, UseLocalDirectives => 1);
}
## Maybe call 
#$s = $s->make_long_streets;
## some day, but see the TODOs in Strassen::Combine first.

my $center;
if (defined $center_spec && $center_spec ne "") {
    if ($center_spec =~ /^city=(.*)/) {
	my($city,$country) = split /_/, $1, 2;
	require Geography;
	my $geo = Geography->new($city, $country);
	$center = $geo->center;
    } elsif ($center_spec =~ /\d+,.*\d/) {
	$center = $center_spec;
    } else {
	die "Cannot understand -center specification <$center_spec>";
    }
}

my $target_attr = $link_target ? qq{ target="$link_target"} : '';

my $html_header = <<EOF;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"> <!-- -*-html-*- -->
<html><head>
<title>@{[ CGI::escapeHTML($title) ]}</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<link rev="made" href="mailto:$email" />
EOF
if (!$do_linklist) {
    $html_header .= <<EOF;
<script type="text/javascript"><!--
function autosubmit() {
  var frm = document.forms[0];
  frm.submit();
}
function hidesubmitbutton() {
  if (document.getElementById) {
    var sb = document.getElementById("submitbutton");
    if (sb) {
      sb.style.visibility = "hidden";
    }
  }
}
// --></script>
EOF
}
$html_header .= <<EOF;
</head>
<body@{[ $do_linklist ? '' : ' onload="autosubmit()"' ]}>
EOF

my $html;

if ($do_linklist) {
    my @html;

    push @html, <<'EOF';
<script type="text/javascript"><!--
function transform_coords_forw_rev(frm) {
  for(var i=0; i<frm.elements.length; i++) {
    var name = frm.elements[i].name;
    if (name == 'coords_forw' || name == 'coords_rev') {
      frm.elements[i].name = 'coords';
    }
  }
}
function transform_coords_remove_rev(frm) {
  for(var i=0; i<frm.elements.length; i++) {
    var name = frm.elements[i].name;
    if (name == 'coords_forw') {
      frm.elements[i].name = 'coords';
    }
    // leave coords_rev as is, will be ignored by bbbike.cgi
  }
}
// --></script>
EOF

    $s->init;

    my $last_route_id;
    my $last_section;
    my $current_display_name;
    my $current_display_addition;
    my @current_lines_with_directions;
    my $current_link;
    my $current_section;
    my %current_alternatives;
    my @current_alternatives_order;
    my $current_ignore_routelist;

    my $generate_single_html = sub {
	my @coords_with_directions = lines_to_coords_with_directions(@current_lines_with_directions);

	if ($do_headlines) {
	    if ($current_section) {
		if (!defined $last_section || $current_section ne $last_section) {
		    push @html, "<h2>" . CGI::escapeHTML($current_section) . "</h2>";
		    $last_section = $current_section;
		}
	    }
	}

	my @common_html_args = (
				map_button_options(),
				$current_ignore_routelist || !$do_routelist_button ? () : (routelistlabel => " Routenliste "),
			       );

	my @current_lines = map { $_->[1] } @current_lines_with_directions;

	push @html, generate_single_html(coords_with_directions => \@coords_with_directions,
					 (defined $center ? (center => find_nearest_to_center(\@current_lines, $center)) : ()),
					 label => $current_display_name,
					 label_addition => $current_display_addition,
					 link => $current_link,
					 @common_html_args,
					);
	if (%current_alternatives) {
	    for my $alt (@current_alternatives_order) {
		my $label = $current_alternatives{$alt}->{label};
		my $label_html = "&#xa0;&#xa0;&#xa0;" . CGI::escapeHTML($label);
		my @coords_with_directions = lines_to_coords_with_directions(@{ $current_alternatives{$alt}->{coords_with_directions} });
		push @html, generate_single_html(coords_with_directions => \@coords_with_directions,
						 center => find_nearest_to_center([ map { $_->[1] } @{ $current_alternatives{$alt}->{coords_with_directions} }], $center),
						 label => $label,
						 label_html => $label_html,
						 @common_html_args,
						);
	    }
	}	

	@current_lines_with_directions = ();
	undef $current_display_name;
	undef $current_display_addition;
	undef $current_link;
	undef $current_section;
	undef $current_ignore_routelist;
	%current_alternatives = ();
	@current_alternatives_order = ();
    };

    while(1) {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS] };

	my($cat_hin,$cat_rueck) = split /;/, $r->[Strassen::CAT];
	if ($only_one_direction) {
	    if ($cat_hin eq '') {
		warn "Ignore rueckweg in $r->[Strassen::NAME]...\n" if $debug;
		next;
	    }
	}

	my $push_coords_with_directions = sub {
	    my($dest_arrref) = @_;
	    if (!defined $cat_rueck) {
		push @$dest_arrref, ['coords', $r->[Strassen::COORDS]];
	    } else {
		if ($cat_hin ne '') {
		    push @$dest_arrref, ['coords_forw', $r->[Strassen::COORDS]];
		}
		if ($cat_rueck ne '') {
		    push @$dest_arrref, ['coords_rev', $r->[Strassen::COORDS]];
		}
	    }
	};

	my $route_id = $r->[Strassen::NAME];
	my $alt_name;
	if ($do_alternatives_handling) {
	    if ($route_id =~ s{\s+\[(.*)\]$}{}) {
		$alt_name = $1;
		if (!exists $current_alternatives{$alt_name}) {
		    push @current_alternatives_order, $alt_name;
		}
		$current_alternatives{$alt_name}->{label} = $alt_name;
		$current_alternatives{$alt_name}->{coords_with_directions} = [];
		$push_coords_with_directions->($current_alternatives{$alt_name}->{coords_with_directions});
		warn "XXX handle alternative $r->[Strassen::NAME]...\n" if $debug;
		next;
	    }
	}

	if (defined $last_route_id && $last_route_id ne $route_id) {
	    $generate_single_html->();
	}

	$last_route_id = $route_id;

	$push_coords_with_directions->(\@current_lines_with_directions);

	if (!defined $current_display_name) {
	    if ($preferalias) {
		$current_display_name = $s->get_directive->{alias}->[0] || $r->[Strassen::NAME];
	    } else {
		$current_display_name = $r->[Strassen::NAME] || $s->get_directive->{alias}->[0];
	    }

	    if ($do_completeness) {
		my $complete = $s->get_directive->{complete}->[0];
		if ($complete) {
		    if ($complete eq 'no') {
			$current_display_addition = " (unvollständig)";
		    } elsif ($complete ne 'yes') {
			warn "WARN: unexpected value for 'complete' directive '$complete', seen for '$current_display_name'...\n";
		    }
		}
	    }
	}

	if (!defined $current_link) {
	    $current_link = $s->get_directive->{url}->[0] || '';
	}

	if (!defined $current_section) {
	    $current_section = $s->get_directive->{section}->[0] || '';
	}

	if (!defined $current_ignore_routelist) {
	    # This handles the directive "XXX_prog: no_routelist".
	    # Naming here is somewhat ambiguous: the directive
	    # "ignore_routelist" means that an entry should not appear
	    # in radroute.html at all. "XXX_prog: no_routelist" just
	    # means that the "Routenliste" button is missing in
	    # radroute.html, but the entry is still there with a
	    # "Karte" button.
	    $current_ignore_routelist = ($s->get_directive->{XXX_prog}->[0]||'') eq 'no_routelist' ? 1 : 0;
	}

    }
    if ($last_route_id) {
	$generate_single_html->();
    }

    $html = join("\n", @html);
} else {
    my @lines;
    iterate {
	push @lines, $_->[Strassen::COORDS()];
    } $s;

    my @coords = lines_to_coords(@lines);

    $html = generate_single_html(coords => \@coords,
				 (defined $center ? (center => find_nearest_to_center(\@lines, $center)) : ()),
				 label => undef,
				 map_button_options(),
				 ($do_routelist_button ? (routelistlabel => " Routenliste ") : ()),
				 single => 1,
				);
				 
}

my $html_footer = "";
if (!$do_linklist) {
    $html_footer .= <<EOF;
<script><!--
  hidesubmitbutton();
 //--></script>
EOF
}
$html_footer .= <<EOF;
</body></html>
<!--
     This file was generated with

EOF
$html_footer .= "  " . CGI::escapeHTML($save_cmdline) . "\n";
$html_footer .= <<EOF;

     on @{[ scalar localtime ]}
-->
EOF

print $html_header if !$partialhtml;
print $html;
print $html_footer if !$partialhtml;

sub find_nearest_to_center {
    my($lines_ref, $center) = @_;
    my $nearest_c;
    my $nearest_dist;
    for my $c (map { @$_ } @$lines_ref) {
	my $dist = Strassen::Util::strecke_s($center, $c);
	if (!defined $nearest_dist || $dist < $nearest_dist) {
	    $nearest_c = $c;
	    $nearest_dist = $dist;
	}
    }
    $nearest_c;
}

sub lines_to_coords {
    my(@lines) = @_;
    # XXX instead of int() should something like best_accuracy be used
    my @coords =
	map {
	    join $COORD_SEP, map {
		join ",", map { int } split /,/, $_
	    } @$_
	} @lines;
    @coords;
}

sub lines_to_coords_with_directions {
    my(@lines_with_directions) = @_;
    # XXX instead of int() should something like best_accuracy be used
    my @coords_with_directions =
	map {
	    [$_->[0],
	     join $COORD_SEP, map {
		 join ",", map { int } split /,/, $_
	     } @{$_->[1]}
	    ]
	} @lines_with_directions;
    @coords_with_directions;
}

sub map_button_options {
    my $has_both_map_buttons = $do_mapserver_button && $do_leaflet_button;
    my @opts;
    if ($do_leaflet_button) {
	push @opts, leafletlabel => ' Karte ' . ($has_both_map_buttons ? '(Leaflet) ' : '');
    }
    if ($do_mapserver_button) {
	push @opts, mapserverlabel => ' Karte ' . ($has_both_map_buttons ? '(Mapserver) ' : '');
    }
    @opts;
}

sub generate_single_html {
    my(%args) = @_;

    my @coords = @{ delete $args{coords} || [] };
    my @coords_with_directions = @{ delete $args{coords_with_directions} || [] };
    my $center = delete $args{center};
    my $label = delete $args{label};
    my $label_addition = delete $args{label_addition};
    my $label_html = delete $args{label_html};
    my $mapserverlabel = delete $args{mapserverlabel};
    my $leafletlabel = delete $args{leafletlabel};
    my $routelistlabel = delete $args{routelistlabel};
    my $link = delete $args{link};
    my $is_single = delete $args{single} || 0;

    die "usage? " . join(" ", %args) if keys %args;

    if (!@coords && !@coords_with_directions) {
	die "Both coords and coords_with_directions are empty --- refuse generating form (label=$label)";
    }

    my $html = <<EOF;
<form style='margin-bottom:0px;' action="$bbbike_url" method="post"$target_attr>
 <input type="hidden" name="imagetype" value="$imagetype" />
 <input type="hidden" name="scope" value="wideregion" />
EOF
    for my $coords (@coords) {
	$html .= <<EOF;
 <input type="hidden" name="coords" value="$coords" />
EOF
    }
    for my $coord_def (@coords_with_directions) {
	my($key, $val) = @$coord_def;
	$html .= <<EOF;
 <input type="hidden" name="$key" value="$val" />
EOF
    }
    for my $layer (@layers) {
	$html .= <<EOF;
 <input type="hidden" name="draw" value="$layer" />
EOF
    }
    if (defined $center) {
	$html .= <<EOF;
 <input type="hidden" name="center" value="$center" />
EOF
    }
    if (defined $width && defined $height) {
	$html .= <<EOF;
 <input type="hidden" name="width" value="$width" />
 <input type="hidden" name="height" value="$height" />
EOF
    }

    if (defined $label || defined $label_html) {
	$html .= <<EOF;
 <input type="hidden" name="routetitle" value="@{[ $label_html || CGI::escapeHTML($label) ]}" />
EOF
	$html .= "\n" . ($link ? CGI::a({href => $link, class => "moreinfo"}, $label) : ($label_html || CGI::escapeHTML($label)));
    } 
    if (defined $label_addition) {
	$html .= CGI::escapeHTML($label_addition);
    }

    # leaflet button
    my $restore_action = '';
    if ($leafletlabel) {
	$html .= <<EOF;
 <input type="submit" onclick='this.form.action="$leaflet_url?zoom=15";' value="@{[ CGI::escapeHTML($leafletlabel) ]}" />
EOF
	$restore_action = qq{this.form.action="$bbbike_url";};
    }

    # mapserver button
    if ($mapserverlabel) {
	$html .= ' <input';
	if ($is_single) {
	    $html .= ' id="submitbutton"';
	}
	$html .= <<EOF;
 type="submit" onclick='this.form.showroutelist.value="0"; this.form.imagetype.value="$imagetype"; transform_coords_forw_rev(this.form); $restore_action' value="@{[ CGI::escapeHTML($mapserverlabel) ]}" />
 <input type="hidden" name="showroutelist" value="0" />
EOF
    }

    # route list button
    if ($routelistlabel) {
	$html .= <<EOF;
 <input type="submit" onclick='this.form.showroutelist.value="1"; this.form.imagetype.value=""; transform_coords_remove_rev(this.form); $restore_action' value="@{[ CGI::escapeHTML($routelistlabel) ]}" />
EOF
    }

    for my $custom_link_def (@custom_link_defs) {
	my $url = $custom_link_def->{url};
	my $link_label = $custom_link_def->{label}; # XXX fallback?
	$url =~ s{\$(NAME_HTML|NAME|FIRST_COORD|CENTER_COORD)}{
	    my $repl;
	    if      ($1 eq 'NAME_HTML') {
		$repl = uri_escape($label_html || CGI::escapeHTML($label));
	    } elsif ($1 eq 'NAME') {
		$repl = uri_escape($label);
	    } elsif ($1 eq 'FIRST_COORD') {
		$repl = uri_escape((split /$COORD_SEP/, $coords[0])[0]);
	    } elsif ($1 eq 'CENTER_COORD') {
		my @single_coords = map { split /$COORD_SEP/, $_ } @coords;
		$repl = uri_escape($single_coords[$#single_coords/2]);
	    } else {
		die "Should never happen: \$1 = $1";
	    }
	    $repl;
	}eg;
	if ($bad_browser_compat) {
	    # IE8 cannot handle <a><button>...</>
	    $html .= <<EOF;
 <a style="text-decoration:none;" href="@{[ CGI::escapeHTML($url) ]}"$target_attr>@{[ CGI::escapeHTML($link_label) ]}</a>
EOF
	} else {
	    $html .= <<EOF;
 <a style="text-decoration:none;" href="@{[ CGI::escapeHTML($url) ]}"$target_attr><button>@{[ CGI::escapeHTML($link_label) ]}</button></a>
EOF
	}
    }
    $html .= <<EOF;
</form>
EOF

    return $html;
}

__END__

=encoding utf-8

=head1 NAME

bbd2mapservhtml.pl - create a mapserver or leaflet route from a bbd or bbr file

=head1 SYNOPSIS

    bbd2mapservhtml [-bbbikeurl url] [-email email]
                    [-layer layername [-layer ...]]
                    [-initmapext {width}x{height}] [-mapscale scale]
		    [-center x,y] [-centernearest]
		    [-partialhtml] [-linklist] [-linktarget ...] [-preferalias]
		    [-title title] [-imagetype ...]
		    [-onlyonedirection] [-althandling] [-completeness]
		    [-customlink "url label" ...]
		    [-noroutelistbutton] [-nomapserverbutton] [-noleafletbutton]
		    [file]

=head1 DESCRIPTION

=over

=item -bbbikeurl url

Use the given URL for the bbbike cgi instead of the official one from L<BBBikeVar>

=item -layer

Specify the initial set of layers. This option may be given multiple
times.

=item -initmapext I<width>xI<height>

Set the initial extents (in real life meters) of the map.

=item -mapscale I<scale>

=item -mapscale 1:I<scale>

Set the initial extents via a scale number (e.g. 1:20000 or just
20000). Note that B<-mapscale> and B<-initmapext> cannot be specified
together.

=item -center I<...>

Center the map. The argument to center may be one of the following:

=over

=item I<x>,I<y>

Center to the specified BBBike standard coordinate.

=item C<city=>I<city_country>

Center to the preferred center of the specified city. A sample city
specification: C<Berlin_DE>. See the L<Geography> module/directory for
available cities.

=back

If the C<-center> option is not given, then center to the first point
in the bbd file resp. the first point of a street record in linklist
more.

=item -centernearest

In conjunction with the C<-center> option: center to the nearest point
in the route from the specified center.

=item -partialhtml

Output partial html without HTML head, body start and end tags. This
option is useful for automatic inclusion into a pre-made html page.

=item -linklist

Create a link list with one street per line.

=item -linktarget framename

This will be added to use a specific frame for form and link targets.

=item -headlines

Create headlines from "section" blocks.

=item -preferalias

In a linklist, prefer the alias name (set in bbd files with the "#:
alias" directive) over the street name.

=item -title I<string>

Set title of generated HTML page to I<string>.

=item -imagetype ...

Specify another imagetype than the default "mapserver". Examples are
pdf or png, which would use different backends.

=item -onlyonedirection

Use only street records in the "forward" direction (see
F<comments_route> for an example; C<< radroute >> vs. C<< radroute; >>
and C<< ;radroute >>).

=item -althandling

Handling of alternative routes. This option in hand-optimized for
F<comments_route> and may be changed in future or even vanish
completely.

=item -completeness

Mark incomplete features marked with a C<<complete:no>> directive. XXX
Currently hardcoded to a German label "unvollständig".

=item -customlink "url label"

Create another link with the given label and URL. This option may be
given multiple times. The URL will have the following variables
replaced:

=over

=item C<$NAME>

name of current record

=item C<$NAME_HTML>

name of current record, as HTML

=item C<$FIRST_COORD>

first coordinate as I<X,Y>

=item C<$CENTER_COORD>

middle coordinate

=back

=item -noroutelistbutton

Don't create a button to the route list.

=item -nomapserverbutton

Don't create a button to mapserver.

=item -noleafletbutton

Don't create a button to the leaflet map.

If both mapserver and leaflet buttons exist, then the button label
changes to "Karte (Mapserver)" and "Karte (Leaflet)", and leaflet
button is shown first.

=back

If I<file> is not given, then read from standard input.

=head1 EXAMPLE

=head2 Using iframes

Here's an example for building a static page which uses the upper half
for the link list and the lower half of the screen for the target of
the link (map, route list, or custom link).

The HTML header may look like this:

    <html>
      <head>...</head>
      <body style="margin:0px;">
        <div style="width:100%; height:50%; overflow:scroll; padding:0px;">

Here insert the output of C<bbd2mapservhtml.pl -partialhtml -linklist
-linktarget int_frame ...>.

Following the HTML footer:

        </div>
        <iframe style="width:100%; height:50%; border:0px;" name="int_frame"></iframe>
      </body>
    </html>

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<cmdbbbike>, L<bbd>

=cut

