# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004,2008,2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2023,2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): My shortcuts for BBBike
# Description (de): Meine Shortcuts f�r BBBike
package SRTShortcuts;
#use lib ("/home/slavenr/work2/bbbike", "/home/slavenr/work2/bbbike/lib"); # XXX for flymake
use BBBikePlugin;
push @ISA, 'BBBikePlugin';

BEGIN {
    *M    = \&BBBikePlugin::M;
    *Mfmt = \&BBBikePlugin::Mfmt;
}

use strict;
use vars qw($VERSION);
$VERSION = 2.15;

use File::Glob qw(bsd_glob);

use your qw(%MultiMap::images $BBBikeLazy::mode
	    %main::line_width %main::p_width %main::str_draw %main::p_draw %main::p_file
	    %main::p_obj
	    $main::lazy_plot %main::lazy_p %main::layer_active_color
	    %main::add_net
	    $main::newlayer_photo
	    @main::inslauf_selection $main::edit_normal_mode
	    $main::gps_waypoints $main::gps_waypointlength
	    $main::gps_waypointcharset $main::gps_needuniqueroutenumber
	    $main::zoom_loaded_route $main::center_loaded_route
	    $Karte::Berlinmap1996::obj $Karte::Polar::obj
	    $Tk::Config::xlib
	  );

use BBBikeUtil qw(bbbike_root bbbike_aux_dir);

my $bbbike_rootdir = bbbike_root;
my $bbbike_auxdir  = bbbike_aux_dir;

my $streets_track                    = "$bbbike_rootdir/tmp/streets.bbd";
my $acc_streets_track                = "$bbbike_rootdir/tmp/streets-accurate.bbd";
my $acc_cat_streets_track            = "$bbbike_rootdir/tmp/streets-accurate-categorized.bbd";
my $acc_cat_split_streets_track      = "$bbbike_rootdir/tmp/streets-accurate-categorized-split.bbd";
my $fit_track                        = "$bbbike_rootdir/tmp/fit.bbd";
my @acc_cat_split_streets_years = do {
    my $curr_year = 1900 + (localtime)[5];
    ($curr_year-3..$curr_year); # also used for unique-matches
};
my $acc_cat_split_streets_byyear_track = sub { my $year = shift; "$bbbike_rootdir/tmp/streets-accurate-categorized-split-since$year.bbd" };
my $other_tracks                     = "$bbbike_rootdir/tmp/other-tracks.bbd";
my $str_layer_level = 'l';

use vars qw($hm_layer);

use vars qw($show_situation_at_point_for_route);
use vars qw(%want_plot_type_file %layer_for_type_file);
use vars qw($want_winter_optimization);
$want_winter_optimization = '' if !defined $want_winter_optimization;

use vars qw(%images);

sub register {
    my $pkg = __PACKAGE__;
    $BBBikePlugin::plugins{$pkg} = $pkg;
    _create_images();
    add_button();
    add_keybindings();
    define_subs();
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $subw = $mf->Subwidget($pkg . '_on');
    if (Tk::Exists($subw)) { $subw->destroy }
    remove_keybindings();
    BBBikePlugin::remove_menu_button(__PACKAGE__."_menu");
    delete $BBBikePlugin::plugins{$pkg};
}

sub _create_images {
    if (!defined $images{bridge}) {
	# Created from bbbike-aux/drawings/bridge.svg
	# Bitmap exported with inkscape and converted with mmencode -b
	# XXX this image could also be used in the bbbike legend (perl/tk,
	# mapserver ...)
	$images{bridge} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAAAlw
SFlzAAAN1wAADdcBQiibeAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoA
AADuSURBVDiNzdOxLkRREMbx314KIlEolHqikfUAukmUOo1WQe0lvMKqhMYLGHqNaHUKiWQR
iU7FXsUuWTcnGzcaX3JycuZ88883xXTquhYRizjDTmbem6CImMYpLjKzV0FmPqPGTUQsT2ie
xSU2cQ7V2P82ZnAdEeuF5nlcYQO7mfnwA5CZffQwh71CgDWs4DUzT76KVcP0PrrrAmAwdr7V
BIybm6rRaRbbAEq11gn+BBhoMcLHL6H/eIT2CSKiQoyetwVvH29YiIhuKcE+VnGQmUfN7sx8
RBdPOI6IqSZgy3BJDktRR5A7w514wRJ8AtaGUGHkMDeVAAAAAElFTkSuQmCC
EOF
    }

    if (!defined $images{car_cross}) {
	# Created from bbbike-aux/images/car-cross.png
	$images{car_cross} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAAZiS0dE
AP8A/wD/oL2nkwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB90CGRUGNraovaAAAAAd
aVRYdENvbW1lbnQAAAAAAENyZWF0ZWQgd2l0aCBHSU1QZC5lBwAAAQFJREFUOMuVkD1KA0EU
gL9dSfCniVh5CA9g4xHiMSy0tooYa/US6dOLhQeQgNgIgmAZshYWNmHZ3c8isyjLrhkfDAxv
3ve99wZBoRBOiAhhX5gGTuqLkK+TNGGhoJHolLTAq9rOhxg4piCmwV+S89gVuyTlfz65S1Kf
VjhtJhKYA++NdEVsCOOW7nErtMA3wtQQp1A+TiZPqjHwWL0s8jy/GI0ETEHAg37/Wb1bB5dZ
lj0ABVD+FgBew61qKxy8x8AiwB8pZANY7oIb4B54Nhy+Jq6MdVwlP4I3oAfshClIId2GwSb0
UuAIKlo6r9bST3UZRn5Rv9TFFtwfwtzZTKvKbyU8I7/i8L+dAAAAAElFTkSuQmCC
EOF
    }

    if (!defined $images{camera}) {
	# Created from bbbike-aux/images/camera.png
	$images{camera} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAAZiS0dE
AP8A/wD/oL2nkwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB90CGgcHOTIbSYAAAALU
SURBVDjLjZNNa11VFIbftdfe5+um99x7bRRbksZgTBvR0DpxUIT6F8SBjp0IggOFTpyIYwf9
B51UqI7agaWTFoqIQontwNA2/UAUjMn1JOfe87332cuR0kEpPvMXHnh5SERARHgKvbS0Qs71
3hjjl1dW5IdbN/A8CM9Hra1tEAAcO3bi2eNb168kd359+GE+L+Or31+798vW3b3xaHR4+dtL
v7977pwHgNXVNXr06IEAwJnTb6CsGnK9gADQ6c233ouTweWu69Tu3i6KopgqUjuk1I9K8ZWu
7X/K810LGDWZjJBl+/4/g803Nz8qivrjumnOiO/hpUdVNxAPMCuEQXD1/OdfvP/Z+U+6p9W/
+vLTcHpQeDq5vvGNte4Dazu0XSWjNCWtNbIsR922YM13jiTJJe/9VEAqCoOqrqsTnXXLRKqk
xcWXt9PhwimRHoMklNdPrVMYhri/8xh/PfnNNrbXBUAkAs2MwSBBVbWoqgrMBN117SveJ0JK
iDXjz909YaPBrBBo1q11BCEAgn8vJ6WgjYbRBK0UHltn1713rAhQrLH4wgTeWGS9o2BhAWc3
TmKYDqSYlzT9O0M+K7F0fF3iKCTt+/6PKDSvta0gTVO8c/ZtCgKF7e37IECiwODo0TG99OKE
suxQyrIiEZLVlWUyhqF7L5TEMSajEdJ0SINBjLatpbMOACg7OMTtrbuIowCddeScR9O29PPt
LSFSpI0xERGxYkZnLWb5DCJCIgCB0HUWWXYAEQ/nBXEUoSxr7E+nxKyh4zgm5zzN5gUmnMJ2
DtY6dK1DYIIsjnHPhMGw712sPIRANRG9yqxjo02ujTY3m7adQHAcRDSbl1JVjZsXNbPW342T
6EJrbUMIYh0wBGKJ1aJWKg2CoNZK8ddlVV00bCIRUfm8lFleyKwopffYf/Lg4fQZge383xIx
TMdqPDqirLUAFJgZ+WyOpqlhjJF/AHqpZ2nFH6CCAAAAAElFTkSuQmCC
EOF
    }

    # XXX NOTE: Image is also defined in MultiMap.pm, maybe reuse from
    # there? But in this case it has to be made sure that MultiMap.pm
    # is loaded; could be done without using the plugin, just the
    # image initialization should be (partially) done)
    if (!defined $images{VIZ}) {
	# Got from: http://www.vmz-info.de/vmz-fuercho-5.1.1.1/images/liferay.ico
	# Converted with convert + mmencode -b
	$images{VIZ} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAALGPC/xhBQAAAAFz
UkdCAK7OHOkAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAA
AiJQTFRFL06DGj9/ETd5d4mqprXFhZ+9hJ69o7PEz9fdyNfmyNflx9Hb+vr6////G0CACjWB
ACt6bYOqp7nMh6fKhqbKo7XJ09vj0uPz0uPyzNjkEzh7ACp6AB9zZXylorXJgKLHf6DHnrHG
0Nnhz+Hyz+HxydbjfI6tcIara4GnqrXIxM3Wrr3Prb3Pw8zW3uLm2ODo2N7kp7bGprjNorbL
wsvV1drf0drk0Nrj193i/fz7/vz7//792+DlyNXgztvmxtDZh6C+iKbKgaLHrLvN0drj0uLz
0OHy0tzm/Pv72ODny9zt0uTzxNPhhp+9hqXKgKHHq7rN0NnizuDx0dvl2eDny93u0uT0xdPh
p7XGpLbKoLPIw8vW09zm0dzl2d/l/Pv6/f384OPnz9jg093kzdXbzdXa0dnh2t/l0dvk0tzl
197jx8/YoLHGprbKprTFxtPg0+P019/n0tvl0d3msL7PfZzCh6bKgp29xdPf1t/n09zl0eLz
0t3nsb/Pfp3DiafKhJ6+xtDYztnly9fj//38/v382N7j0Nvk1dzhxc7Xn7PIprnNpLTG3uPm
rr3Os7zMboGndImtfI6s+/v6y9fhzd/vzd/wz9ngobPHfp7EgKDFn7PLcYaqABxuACt5DzN3
z9vl0uP009zjprjLhqTJpbjOeYyuACh3CjaBFDt9+/v7yNLaxtXhxtXiztbbqbfHiKK/pbXH
hJSxFjd5H0SCLEyCxY87YQAAAAFiS0dEDfa0YfUAAAEJSURBVBjTY2BgZGJmYWVj5+Dk4ubh
5eVl4OMXEBQSFhEVE5eQBAtIScvIyskrKCopq6iCBdTUNTS1tHV09fT1DXiAgMHQyNjE1Mzc
wtLKytrG1s6ewcHRydnF1c3dA6jc08vbh8HXzz8g0C0oGCQQEhoWzhARGRVtERMbFx8fn5CY
lJzCkCqWphfv4RGfnpGZlZ2Tm8eQX6BcaMXL61EUpFxcUlpWzlAhrlJpCRSoUq6uqa2rb2Bo
bGo2aLG2bm1rD+7o7OruYQA5xsbTsze7r0S3f8LESQxA2yZPmTpt+oyZs2bPmTtvPlhggfjC
RYuXOC5dtnzFSpDAqtVr1q5b77Bh46bNW7YCAKJlS6V7R7bEAAAAJXRFWHRkYXRlOmNyZWF0
ZQAyMDEzLTAyLTE5VDIxOjQyOjUxKzAxOjAws5ftwQAAACV0RVh0ZGF0ZTptb2RpZnkAMjAx
Mi0wOC0xNFQxNjoyODo1MCswMjowMOv6tcMAAAAASUVORK5CYII=
EOF
    }

    if (!defined $images{git}) {
	# Converted with:
	# cat ~/images/icons/git-favicon.png | perl -MMIME::Base64 -e 'print encode_base64(join("",<>))'
	$images{git} = $main::top->Photo
	    (-format => 'png',
	     -data => <<'EOF');
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQAgMAAABinRfyAAAADFBMVEXAAAAAgAD////////GbSb/
AAAACXBIWXMAAAsTAAALEwEAmpwYAAAAPklEQVR4AQXBsRFAQBQFwPXmy+lIoFDxdaEDkRqEF4gY
M3aHhkAgEKhzu57A0BCot/Ze/bi/QKZ1rhotAoEfzicL4tjT/h8AAAAASUVORK5CYII=
EOF
    }

    if (!defined $images{usbahn}) {
	# Created manually using ubahn.png and sbahn.png
	$images{usbahn} = $main::top->Photo
	    (-format => 'png',
	     -data => <<'EOF');
iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI
WXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5woTEzE60biiYwAAAH5JREFUKM+Vk1EOwCAIQ9vFe4sn
7z4WjeLYhD+I9JUIBEyIwszl4JxeyIRBMAwYO1mqT4FtvO01AGDj5qJ8geYGVW0Cx7bZCFUtI6Rm
TpFVtdJcHJEjkZRtL3D9zbh9UZYcCYzmvhzzYni7i4iB9Lv91hxtGFOH4Q6kJA9jwd/1YTOeKzXm
wgAAAABJRU5ErkJggg==
EOF
    }
}

sub add_button {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $mmf = $main::top->Subwidget("ModeMenuPluginFrame");
    return unless defined $mf;

    my $btn;
    $btn = $mf->Label
	(-text => "Srt",
	 -font => main::find_font_by_height(15), # match the icon size of symbol bar
	);
    BBBikePlugin::replace_plugin_widget($mf, $btn, __PACKAGE__.'_on');
    $main::balloon->attach($btn, -msg => "SRT Shortcuts")
	if $main::balloon;

    my $rare_or_old_menu = $mmf->Menu
	(-disabledforeground => "black",
	 -menuitems =>
	 [
	  ($main::devel_host ? [Cascade => "Karte"] : ()),
	  [Cascade => "Old VMZ/LBVS/fritz stuff",
	   -font => $main::font{'bold'},
	   -menuitems =>
	   [
	    [Button => 'Show recent fritzdiff',
	     -command => sub { show_fritz_verkehr_diff() },
	    ],
	    "-",
	    [Button => 'VMZ/LBVS lister (old files)',
	     -command => sub { show_vmz_lbvs_files() },
	    ],
	    "-",
	    [Button => "Show recent VMZ diff (old version)",
	     -command => sub { show_vmz_diff() },
	    ],
	    (map { [Button => "VMZ version $_", -command => [sub { show_vmz_diff($_[0]) }, $_] ] } (0 .. 5)),
	    "-",
	    [Button => "Show recent LBVS diff",
	     -command => sub { show_lbvs_diff() },
	    ],
	    (map { [Button => "LBVS version $_", -command => [sub { show_lbvs_diff($_[0]) }, $_] ] } (0 .. 5)),
	    "-",
	    [Button => "Select any file as VMZ/LBVS diff",
	     -command => sub { select_vmz_lbvs_diff() },
	    ],
	   ],
	  ],
	  [Button => 'GPS downloads (not on biokovo)',
	   -state => 'disabled',
	   -font => $main::font{'bold'},
	  ],
	  [Button => "Standard download all",
	   -command => sub { make_gps_target("download") },
	  ],
	  [Button => "Standard download trk only",
	   -command => sub { make_gps_target("download-trk") },
	  ],
	  [Button => "Standard download wpt only",
	   -command => sub { make_gps_target("download-wpt") },
	  ],
	  [Button => 'Not working anymore',
	   -state => 'disabled',
	   -font => $main::font{'bold'},
	  ],
	  [Button => "Edit with new GPS trk",
	   -command => sub {
	       require BBBikeEdit;
	       require BBBikeAdvanced;
	       require BBBikeLazy;
	       require File::Basename;
	       main::plot("str","s", -draw => 0);
	       #XXX del? main::switch_edit_berlin_mode();
	       main::bbbikelazy_clear();
	       main::bbbikelazy_setup();
	       
	       main::bbbikelazy_init();
	       add_new_layer("str", $streets_track);
	       
	       my $file = main::draw_gpsman_data($main::top);
	       if (defined $file) {
		   BBBikeEdit::edit_gps_track(File::Basename::basename($file));
		   BBBikeEdit::set_edit_gpsman_waypoint();
		   BBBikeEdit::editmenu($main::top);
	       } else {
		   main::status_message("No file from draw_gpsman_data", "warn");
	       }
	       main::plot('str','fz', -draw => 1);
	   }],
	 ]);

    my $do_compound = sub {
	my($text, $image) = @_;
	if ($Tk::VERSION >= 804) {
	    # Tk804 has native menu item compounds
	    if ($image) {
		($text, -image => $image, -compound => "left");
	    } else {
		if (!$SRTShortcuts::empty_image_16) {
		    $SRTShortcuts::empty_image_16 = $main::top->Photo(-data => <<EOF);
R0lGODlhEAAQAIAAAP///////yH+FUNyZWF0ZWQgd2l0aCBUaGUgR0lNUAAh+QQBCgABACwA
AAAAEAAQAAACDoyPqcvtD6OctNqLsz4FADs=
EOF
		}
		($text, -image => $SRTShortcuts::empty_image_16, -compound => "left");
	    }
	} else {
	    ($text);
	}
    };

    BBBikePlugin::place_menu_button
	    ($mmf,
	     [
	      [Cascade => $do_compound->("Set penalty: unique matches..."), -menuitems =>
	       [
		[Button => $do_compound->("alltime"),
		 -command => sub { set_penalty('tmp/unique-matches.bbd') },
		],
		(map {
		    my $year = $_;
		    [Button => $do_compound->("since $year"),
		     -command => sub { set_penalty("tmp/unique-matches-since$year.bbd") },
		    ];
		} @acc_cat_split_streets_years
		),
		'-',
		[Button => $do_compound->('unset'),
		 -command => sub { unset_penalty() },
		],
	       ]
	      ],
	      [Button => $do_compound->("Set penalty fragezeichen-outdoor-nextcheck"),
	       -command => sub { set_penalty_fragezeichen() },
	      ],
	      [Button => $do_compound->("Tracks in region"),
	       -command => sub { tracks_in_region() },
	      ],
	      layer_checkbutton([$do_compound->("Add streets-accurate-categorized-split.bbd")],
				'str', $acc_cat_split_streets_track,
				set_layer_highlightning => 1,
				special_raise => 1,
				Width => 1,
			       ),
	      (map {
		  my $year = $_;
		  layer_checkbutton([$do_compound->("Add streets-accurate-categorized-split-since".$year.".bbd")],
				    'str', $acc_cat_split_streets_byyear_track->($year),
				    set_layer_highlightning => 1,
				    special_raise => 1,
				    Width => 1,
				   );
	      } ($acc_cat_split_streets_years[0], $acc_cat_split_streets_years[-1]), # only first and last year, rest will be done in a submenu
	      ),
	      [Cascade => $do_compound->("Add streets-accurate-categorized-split-since ..."), -menuitems =>
	       [
		(map {
		    my $last_days = $_;
		    my $file = '/tmp/street-accurate-categorized-split-last-' . $last_days . '-days.bbd';
		    layer_checkbutton([$do_compound->("Last $last_days days")],
				      'str', $file,
				      set_layer_highlightning => 1,
				      special_raise => 1,
				      Width => 1,
				      preparecallback => sub {
					  my $rx = _generate_date_range_regex($last_days);
					  require IPC::Run;
					  my @cmd = ("$bbbike_rootdir/miscsrc/grepstrassen", "--preserveglobaldirectives", "--namerx", $rx, "$bbbike_rootdir/tmp/streets-accurate-categorized-split-since2013.bbd", "$bbbike_rootdir/tmp/fit.bbd");
					  if (!IPC::Run::run(\@cmd, '>', "$file~")) {
					      main::status_message("Failed to create $file", "die");
					  }
					  rename "$file~", $file
					      or main::status_message("Failed to rename $file to final destination: $!", "die");
				      },
				     );
		} (30, 90)
		),
		(map {
		    my $year = $_;
		    layer_checkbutton([$do_compound->("Add streets-accurate-categorized-split-since".$year.".bbd")],
				      'str', $acc_cat_split_streets_byyear_track->($year),
				      set_layer_highlightning => 1,
				      special_raise => 1,
				      Width => 1,
				     );
		} @acc_cat_split_streets_years[1..$#acc_cat_split_streets_years-1],
		),
	       ],
	      ],
	      layer_checkbutton([$do_compound->("Add fit tracks")],
				'str', $fit_track,
				-interactivelyselected => 0,
				set_layer_highlightning => 1,
				special_raise => 1,
				Width => 1,
			       ),
	      [Cascade => $do_compound->("Add other streets...bbd"), -menuitems =>
	       [
		layer_checkbutton("Add streets.bbd (all GPS tracks)",
				  'str', $streets_track,
				  set_layer_highlightning => 1,
				  special_raise => 1,
				  Width => 1),
		layer_checkbutton("Add streets-accurate.bbd (all accurate GPS tracks)",
				  'str', $acc_streets_track,
				  set_layer_highlightning => 1,
				  special_raise => 1,
				  Width => 1),
		layer_checkbutton("Add streets-accurate-categorized.bbd",
				  'str', $acc_cat_streets_track,
				  set_layer_highlightning => 1,
				  special_raise => 1,
				  Width => 1),
		layer_checkbutton("Add plane-accurate.bbd",
				  'str', "$bbbike_rootdir/tmp/plane-accurate.bbd",
				  set_layer_highlightning => 1,
				  special_raise => 1,
				  Width => 1),
		'-',
		layer_checkbutton("Add other-tracks.bbd (other people's GPS tracks)",
				  'str', $other_tracks,
				  set_layer_highlightning => 1,
				  special_raise => 1,
				  Width => 1),
		layer_checkbutton("Add other_sites tracks.bbd",
				  'str', "$bbbike_rootdir/misc/gps_data/other_sites/tracks.bbd",
				  set_layer_highlightning => 1,
				  special_raise => 1,
				  Width => 1),
	       ],
	      ],
	      layer_checkbutton([$do_compound->("Add points-all.bbd (all GPS trackpoints)")],
				'p', "$bbbike_rootdir/tmp/points-all.bbd",
				oncallback => sub {
				    my($layer) = @_;
				    main::special_lower($layer . "-fg", 0); # XXX does not work?
				},
				Width => 20),
	      layer_checkbutton([$do_compound->("Add points-symbols.bbd (with symbols)")],
				'p', "$bbbike_rootdir/tmp/points-symbols.bbd",
				oncallback => sub {
				    my($layer) = @_;
				    main::special_lower($layer . "-fg", 0); # XXX does not work?
				},
				Width => 20),
	      [Cascade => $do_compound->('Add layer', $main::newlayer_photo), -menuitems =>
	       [
		[Button => $do_compound->("Current route"), -command => sub { add_current_route_as_layer() }],
		## Additional layers
		layer_checkbutton([$do_compound->('Zebrastreifen', main::load_photo($mf, "misc/verkehrszeichen/Zeichen_350.svg", -w => 16, -h => 16, -persistent => 1))],
				  'p', "$main::datadir/zebrastreifen",
				  above => $str_layer_level,
				 ),
		layer_checkbutton([$do_compound->('Sackgassen', main::load_photo($mf, "misc/verkehrszeichen/Zeichen_357.svg", -w => 16, -h => 16, -persistent => 1))],
				  'p', "$main::datadir/culdesac",
				  maybe_orig_file => 1,
				  above => $str_layer_level,
				 ),
		layer_checkbutton([$do_compound->('Ortsschilder', main::load_photo($mf, "misc/verkehrszeichen/Zeichen_310_leer.svg", -w => 16, -h => 16, -persistent => 1))],
				  'p', "$main::datadir/ortsschilder",
				  maybe_orig_file => 1,
				  above => $str_layer_level,
				 ),
		layer_checkbutton([$do_compound->('brunnels', $images{bridge})],
				  'str', "$main::datadir/brunnels",
				  maybe_orig_file => 1),
		## routing helpers
		layer_checkbutton([$do_compound->('routing_helper')],
				  'str', "$main::datadir/routing_helper-orig",
				  maybe_orig_file => 0, # does not exist in non-orig version, already resoved to strassen+handicap
				  above => $str_layer_level,
				 ),
		layer_checkbutton([$do_compound->('Gerichtete Handicaps')],
				  'str', "$main::datadir/handicap_directed",
				  maybe_orig_file => 1,
				  above => $str_layer_level,
				 ),
		layer_checkbutton([$do_compound->('mudways')],
				  'str', "$main::datadir/mudways",
				  maybe_orig_file => 0, # no orig file
				  above => $str_layer_level,
			         ),
		layer_checkbutton([$do_compound->('current mudways')],
				  'str', "/tmp/mudways_prognosis.bbd",
				  above => $str_layer_level,
				  preparecallback => sub {
				      prepare_mudways_prognosis();
				  },
			          ),
		layer_checkbutton([$do_compound->('Exits (�PNV)', $images{usbahn})],
				  'str', "$main::datadir/exits",
				  maybe_orig_file => 1),
		## car related
		layer_checkbutton([$do_compound->('Staugefahr', main::load_photo($mf, "misc/verkehrszeichen/Zeichen_124.svg", -w => 16, -h => 16, -persistent => 1))],
				  'str', "$main::datadir/comments_trafficjam",
				  maybe_orig_file => 1,
				  above => $str_layer_level,
				 ),
		layer_checkbutton([$do_compound->('gesperrt_car', $images{car_cross})],
				  'sperre', 'gesperrt_car',
				  maybe_orig_file => 1,
				  above => $str_layer_level),
		## edit helpers - images
		layer_checkbutton([$do_compound->('geocoded images', $images{camera})],
				  'str', "$ENV{HOME}/.bbbike/geocoded_images.bbd",
				  above => $str_layer_level,
				 ),
		[Cascade => $do_compound->("geocoded images - more options", $images{camera}), -menuitems =>
		 [
		  [Button => $do_compound->("today", $images{camera}), -command => sub { add_todays_geocoded_images() }],
		  (map {
		      my $filename = $_;
		      if (my($name) = $filename =~ m{/geocoded_images_(.*)\.bbd}) {
			  layer_checkbutton([$do_compound->($name, $images{camera})],
					    'str', $filename,
					    above => $str_layer_level,
					   );
		      } else {
			  warn "Unexpected: cannot parse '$filename'";
		      }
		  } bsd_glob "$ENV{HOME}/.bbbike/geocoded_images_*.bbd")
		 ]
		],
		## edit helpers - fragezeichen
		layer_checkbutton([$do_compound->('fragezeichen-outdoor')],
				  'str', "$bbbike_rootdir/tmp/fragezeichen-outdoor.bbd",
				  below_above_cb => sub {
				      $main::edit_normal_mode ? (below => $str_layer_level) : (above => $str_layer_level)
				  },
				 ),
		[Cascade => $do_compound->('Other fragezeichen'), -menuitems =>
		 [
		  layer_checkbutton([$do_compound->('fragezeichen-outdoor-categorized')],
				    'str', "$bbbike_rootdir/tmp/fragezeichen-outdoor-categorized.bbd",
				    below_above_cb => sub {
					$main::edit_normal_mode ? (below => $str_layer_level) : (above => $str_layer_level)
				    },
				   ),
		  layer_checkbutton([$do_compound->('fragezeichen-indoor-nextcheck')],
				    'str', "$bbbike_rootdir/tmp/fragezeichen-indoor-nextcheck.bbd"),
		  layer_checkbutton([$do_compound->('fragezeichen-outdoor-nextcheck')],
				    'str', "$bbbike_rootdir/tmp/fragezeichen-outdoor-nextcheck.bbd",
				    below_above_cb => sub {
					$main::edit_normal_mode ? (below => $str_layer_level) : (above => $str_layer_level)
				    },
				   ),
		  layer_checkbutton([$do_compound->('fragezeichen-outdoor-nextcheck-categorized')],
				    'str', "$bbbike_rootdir/tmp/fragezeichen-outdoor-nextcheck-categorized.bbd",
				    below_above_cb => sub {
					$main::edit_normal_mode ? (below => $str_layer_level) : (above => $str_layer_level)
				    },
				   ),
		  layer_checkbutton([$do_compound->('fragezeichen-nextcheck')],
				    'str', "$bbbike_rootdir/tmp/fragezeichen-nextcheck.bbd"),
		 ],
		],
		## edit helpers - website searches
		[Cascade => $do_compound->('Unique matches...'), -menuitems =>
		 [
		  layer_checkbutton('Unique matches since beginning',
				    'str', "$bbbike_rootdir/tmp/unique-matches.bbd",
				    above => $str_layer_level,
				   ),
		  (
		   map {
		       my $year = $_;
		       layer_checkbutton("Unique matches since $year", 'str',
					 "$bbbike_rootdir/tmp/unique-matches-since$year.bbd",
					 above => $str_layer_level,
					);
		   } @acc_cat_split_streets_years,
		  ),
		 ],
		],
		do {
		    my $glob = "$bbbike_rootdir/tmp/weighted/????-??_weighted_dir_*.bbd";
		    my @candidates = bsd_glob $glob;
		    if (!@candidates) {
			warn <<EOF;
No candidates for a weighted bbd found
(tried the glob $glob).
Please create a file using $bbbike_rootdir/miscsrc/weight_bbd
(see documentation there)
EOF
			();
		    } else {
			my @checkbuttons;
			my($latest, $prev) = sort { $b cmp $a } @candidates;
			for my $file ($latest, $prev) {
			    my $date_desc;
			    if ($file =~ m{/(\d{4}-\d{2})_}) {
				$date_desc = " (for month $1)";
			    } else {
				$date_desc = " (unknown month)";
			    }
			    push @checkbuttons, layer_checkbutton([$do_compound->("Weighted matches$date_desc")],
								  'str', $file,
								  above => $str_layer_level,
								  Width => undef, # XXX weighted-matches.desc sets its own widths, but why it isn't winning?
								 );
			}
			@checkbuttons;
		    }
		},
		do {
		    my $glob = "$bbbike_rootdir/tmp/weighted/????-??_last12months_weighted_dir_*.bbd";
		    my @candidates = bsd_glob $glob;
		    if (!@candidates) {
			warn <<EOF;
No candidates for a weighted bbd for last 12 months found
(tried the glob $glob).
Please create a file using $bbbike_rootdir/miscsrc/weight_bbd
(see documentation there)
EOF
			();
		    } else {
			my($latest) = sort { $b cmp $a } @candidates;
			my $date_desc;
			if ($latest =~ m{/(\d{4}-\d{2})}) {
			    $date_desc = " (last 12 months from $1)";
			} else {
			    $date_desc = " (unknown period)";
			}
			layer_checkbutton([$do_compound->("Weighted matches$date_desc")],
					  'str', $latest,
					  above => $str_layer_level,
					  Width => undef, # XXX weighted-matches.desc sets its own widths, but why it isn't winning?
					 );
		    }
		},
		'-',
		## edit helpers - others
		[Button => $do_compound->("Abdeckung"),
		 -command => sub {
		     local $main::p_draw{'pp-all'} = 1;
		     add_new_layer("str", "$bbbike_rootdir/misc/abdeckung.bbd");
		     below => '*landuse*',
		 }
		],
		## edit helpers - PLZ
		[Cascade => $do_compound->('Berlin/Potsdam coords'), -menuitems =>
		 [
		  [Button => "Add Berlin.coords.data",
		   -command => sub { add_coords_data("Berlin.coords.bbd") },
		  ],
# 		  [Button => "Add Berlin.coords.data with labels",
# 		   -command => sub { add_coords_data("Berlin.coords.bbd", 1) },
# 		  ],
		  [Button => "Add Berlin-by-citypart data",
		   -command => sub { choose_Berlin_by_data("$bbbike_rootdir/tmp/Berlin.coords-by-citypart") },
		  ],
		  [Button => "Add Berlin-by-zip data",
		   -command => sub { choose_Berlin_by_data("$bbbike_rootdir/tmp/Berlin.coords-by-zip") },
		  ],
		  [Button => "Add Potsdam.coords.data",
		   -command => sub { add_coords_data("Potsdam.coords.bbd") },
		  ],
# 		  [Button => "Add Potsdam.coords.data with labels",
# 		   -command => sub { add_coords_data("Potsdam.coords.bbd", 1) },
# 		  ],
		 ]
		],
		## edit helpers - 3rd party data
		(defined $bbbike_auxdir ?
		 (
		  [Cascade => $do_compound->("VMZ-Detailnetz", $images{VIZ}), -menuitems =>
		   [	
		    layer_checkbutton('strassen', 'str',
				      "$bbbike_auxdir/vmz/bbd/strassen",
				      below => $str_layer_level,
				     ),
		    layer_checkbutton('gesperrt', 'sperre',
				      "$bbbike_auxdir/vmz/bbd/gesperrt",
				      above => $str_layer_level,
				     ),
		    layer_checkbutton('qualitaet', 'str',
				      "$bbbike_auxdir/vmz/bbd/qualitaet_s",
				      above => $str_layer_level,
				     ),
		    layer_checkbutton('radwege', 'str',
				      "$bbbike_auxdir/vmz/bbd/radwege",
				      above => $str_layer_level,
				     ),
		    layer_checkbutton('ampeln', 'str', # yes, str, otherwise symbol is not plotted
				      "$bbbike_auxdir/vmz/bbd/ampeln",
				      above => $str_layer_level,
				     ),
		   ],
		  ],
		 ) : ()
		),
		(defined $bbbike_auxdir ?
		 (
		  layer_checkbutton([$do_compound->('hm96.bbd (H�henpunkte)')],
				    'p', "$bbbike_auxdir/data/senat_b/hm96.bbd",
				    oncallback  => sub { $main::top->bind("<F12>"=> \&find_nearest_hoehe) },
				    offcallback => sub { $main::top->bind("<F12>"=> '') },
				   )
		 ) : ()
		),
		## experiments
		(defined $bbbike_auxdir ?
		 (
		  layer_checkbutton([$do_compound->('Neue Sehensw�rdigkeiten')],
				    'str', "$bbbike_auxdir/images/sehenswuerdigkeit_img/bw/test.bbd"),
		 ) : ()
		),
		## layers only functional with osm data
		layer_checkbutton([$do_compound->('Kneipen/Cafes', main::load_photo($mf, 'glas', -persistent => 1))],
				  'str', ($main::city_obj->is_osm_source ? "$main::datadir/kneipen" : "$bbbike_rootdir/data_berlin_osm_bbbike/kneipen")),
		layer_checkbutton([$do_compound->('Restaurants', main::load_photo($mf, 'essen', -persistent => 1))],
				  'str', ($main::city_obj->is_osm_source ? "$main::datadir/restaurants" : "$bbbike_rootdir/data_berlin_osm_bbbike/restaurants")),
		## all layers
		[Button => $do_compound->("All layers for editing"),
		 -command => sub { enable_all_layers_for_editing() },
		],
	       ],
	      ],
	      [Cascade => $do_compound->('OSM Live data', $MultiMap::images{OpenStreetMap}), -menuitems =>
	       [
		[Button => "Display (and refresh) OSM tiles (Berlin)",
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::mirror_and_plot_visible_area();
		 }],
		[Button => "Display (without refresh) OSM tiles (Berlin)",
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::plot_visible_area();
		 }],
		[Button => "Display (and refresh) OSM tiles (elsewhere)",
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::mirror_and_plot_visible_area_constrained(refreshdays => 0.5);
		 }],
		[Button => "Display (without refresh) OSM tiles (elsewhere)",
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::mirror_and_plot_visible_area_constrained(refreshdays => 999999);
		 }],
		[Button => "Download and display any OSM data",
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::download_and_plot_visible_area();
		 }],
		[Button => "Delete OSM layer",
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::delete_osm_layer();
		 }],
		[Button => 'Show download URL',
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     my $url  = BBBikeOsmUtil::get_download_url(BBBikeOsmUtil::get_visible_area());
		     my $url2 = BBBikeOsmUtil::get_overpass_download_url(BBBikeOsmUtil::get_visible_area());
		     main::status_message("Official URL: $url\nOverpass URL: $url2", "infodlg");
		 }],
		"-",
		[Button => 'Set Merkaartor Icon Style',
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::choose_merkaartor_icon_style();
		 },
		],
	       ],
	      ],
	      [Cascade => $do_compound->('OSM-converted layer'), -menuitems =>
	       [
		do {
		    my @osm_layers = qw(building education motortraffic oepnv power unhandled);
		    my @menu_items = map {
			my $layer = $_;
			[Button => $layer, -command => sub { add_new_datafile_layer("str", "_$layer") }];
		    } @osm_layers;
		    push @menu_items, [Button => 'all of above',
				       -command => sub {
					   my @errors;
					   for my $layer (@osm_layers) {
					       eval { add_new_datafile_layer("str", "_$layer") };
					       push @errors, "$layer: $@" if $@;
					   }
					   if (@errors) {
					       main::status_message(join("\n", @errors), "die");
					   }
				       }];
		    @menu_items;
		},
	       ]
	      ],
	      [Button => $do_compound->('VMZ', $images{VIZ}),
	       -command => sub { newvmz_process() },
	      ],
	      [Button => $do_compound->("Show recent VMZ diff"),
	       -command => sub { show_new_vmz_diff() },
	      ],
	      [Button => $do_compound->('Diff since last deployment', $images{git}),
	       -command => sub { show_diffs_since_last_deployment() },
	      ],
	      [Button => $do_compound->("Mark Layer"),
	       -command => sub { mark_layer_dialog() },
	      ],
	      [Button => $do_compound->("Mark most recent Layer"),
	       -command => sub { mark_most_recent_layer() },
	      ],
	      [Cascade => $do_compound->("Current search in ..."), -menuitems =>
	       [
		[Button => $do_compound->("local bbbike.cgi"),
		 -command => sub { current_search_in_bbbike_cgi(stage => 'local') },
		],
		[Button => $do_compound->("devel bbbike.cgi"),
		 -command => sub { current_search_in_bbbike_cgi(stage => 'devel') },
		],
		[Button => $do_compound->("pps bbbike.cgi"),
		 -command => sub { current_search_in_bbbike_cgi(stage => 'pps') },
		],
		[Button => $do_compound->("bbbike.de"),
		 -command => sub { current_search_in_bbbike_cgi(stage => 'live') },
		],
		'-',
		[Button => $do_compound->("BBBike.org (Berlin)"),
		 -command => sub { current_search_in_bbbike_org_cgi() },
		],
		[Button => $do_compound->("openrouteservice"),
		 -command => sub { current_search_in_openrouteservice_org() },
		],
	       ]
	      ],
	      [Cascade => $do_compound->("Current route in ..."), -menuitems =>
	       [
		[Button => $do_compound->("local bbbike.cgi as PDF"),
		 # don't use draw=>'all' here --- strnames are not displayed very well (sometimes with ... or ???), probably due to coord inaccuracies XXX
		 -command => sub { current_route_in_bbbike_cgi(imagetype => 'pdf-auto', (map { (draw => $_) } qw(str sbahn ubahn wasser flaechen ampel))) },
		],
		[Button => $do_compound->("local bbbikeleaflet.cgi"),
		 -command => sub { current_route_in_bbbikeleaflet_cgi(live => 0) },
		],
		[Button => $do_compound->("live bbbikeleaflet.cgi"),
		 -command => sub { current_route_in_bbbikeleaflet_cgi(live => 1) },
		],
		[Button => $do_compound->("as selection for live bbbikeleaflet.cgi"),
		 -command => sub { current_route_in_bbbikeleaflet_cgi(live => 1, selection => 1) },
		],
		[Button => $do_compound->("as QRCode for live bbbikeleaflet.cgi"),
		 -command => sub { current_route_as_qrcode(in => "bbbikeleaflet-live") },
		],
		[Button => $do_compound->("as QRCode for GPX track with live bbbike.cgi"),
		 -command => sub { current_route_as_qrcode(in => "bbbike-gpx-track-live") },
		],
		[Button => $do_compound->("Windy"),
		 -command => sub { current_route_in_windy() },
		],
	       ],
	      ],
	      [Button => $do_compound->('Search while type (Berlin/Potsdam streets)'),
	       -command => sub { show_bbbike_suggest_toplevel() },
	      ],
	      [Button => $do_compound->('Search while type (everything)'),
	       -command => sub { tk_suggest() },
	      ],
	      [Button => $do_compound->("Today's GPS tracks"),
	       -command => sub { todays_gps_tracks() },
	      ],
	      [Button => $do_compound->("Load route"),
	       -command => sub { route_lister() },
	      ],
	      [Button => $do_compound->("GPS data viewer"),
	       -command => sub { gps_data_viewer() },
	      ],
	      [Button => $do_compound->("Set Garmin device defaults"),
	       -command => sub { garmin_devcap() },
	      ],
	      [Button => $do_compound->("Upload waypoint by coordinates"),
	       -command => sub { upload_waypoint_by_coordinates() },
	      ],
	      [Button => $do_compound->("Fragezeichen on route"),
	       -command => sub { fragezeichen_on_route() },
	      ],
	      [Button => $do_compound->('Mapillary tracks', $MultiMap::images{Mapillary}),
	       -command => sub { select_and_show_mapillary_tracks() },
	      ],
	      [Cascade => $do_compound->("Development"), -menuitems =>
	       [
		[Button => "Render Mapnik map (all current layers)",
		 -command => sub { render_mapnik_map(-special => "current-layers") },
		],
		[Button => "Render Mapnik map (streets only)",
		 -command => sub { render_mapnik_map() },
		],
		[Button => "Update Mapnik map data",
		 -command => sub { update_mapnik_map_data() },
		],
		[Button => "Update Mapnik map data (with experimental switch)",
		 -command => sub { update_mapnik_map_data(experimental => 1) },
		],
		'-',
		[Button => "Update tracks and matches.bbd",
		 -command => sub { make_gps_target("tracks tracks-accurate tracks-accurate-categorized tracks-accurate-categorized-split unique-matches") },
		],
		'-',
		[Button => "Show Karte canvas items",
		 -command => sub {
		     my $wd = _get_tk_widgetdump();
		     $Tk::WidgetDump::ref2widget{$main::c} = $main::c; # XXX hack
		     $wd->canvas_dump($main::c);
		 },
		],
		[Button => "Show Karte canvas bindings",
		 -command => sub {
		     my $wd = _get_tk_widgetdump();
		     $Tk::WidgetDump::ref2widget{$main::c} = $main::c; # XXX hack
		     $wd->show_bindings($main::c);
		 },
		],
		'-',
		[Button => "Center to current Garmin's device position",
		 -command => sub { center_garmin_device_position() },
		],
	       ]
	      ],
	      [Cascade => $do_compound->("Various experiments"), -menuitems =>
	       [
		[Button => $do_compound->('Fetch WMS map'),
		 -command => sub { fetch_fis_broker_wms_map() },
		],
		[Button => $do_compound->("Street name experiment"),
		 -command => sub { street_name_experiment() },
		],
		[Button => $do_compound->("New GPS simplification"),
		 -command => sub { new_gps_simplification() },
		],
		[Button => $do_compound->('Real street widths'),
		 -command => sub { real_street_widths() },
		],
		[Cascade => $do_compound->('Situation at point'), -menuitems =>
		 [
		  [Button => 'For three points',
		   -command => sub { show_situation_at_point() },
		  ],
		  [Checkbutton => 'When calculating routes',
		   -command => sub { toggle_situation_at_point_for_route() },
		   -variable => \$show_situation_at_point_for_route,
		  ],
		 ],
		],
		[Button => $do_compound->("Trafficlight circuit + GPS tracks"),
		 -command => sub {
		     require "$bbbike_rootdir/miscsrc/TrafficLightCircuitGPSTracking.pm";
		     TrafficLightCircuitGPSTracking::tk_gui($main::top);
		 },
		],
		[Cascade => $do_compound->("Winter optimization"), -menuitems =>
		 [
		  [Radiobutton => "Disable",
		   -variable => \$want_winter_optimization,
		   -value => '',
		   -command => sub {
		       do_winter_optimization(undef);
		   },
		  ],
		  (
		   map {
		       if ($_ eq '-') {
			   '-';
		       } else {
			   my $winter_hardness = $_;
			   [Radiobutton => $winter_hardness,
			    -variable => \$want_winter_optimization,
			    -value => $winter_hardness,
			    -command => sub {
				do_winter_optimization($winter_hardness);
			    },
			   ];
		       }
		   } qw(- XXX_busroute - snowy very_snowy dry_cold - grade1 grade2 grade3)
		  ),
		 ],
		],
		[Cascade => $do_compound->("Multi-page PDF"), -menuitems =>
		 [
		  [Button => $do_compound->('Standard settings'),
		   -command => sub { multi_page_pdf() },
		  ],
		  [Button => $do_compound->('Custom settings'),
		   -command => sub { multi_page_pdf_dialog() },
		  ],
		 ],
		],
	       ],
	      ],
	      "-",
	      [Cascade => $do_compound->("Rare or old"), -menu => $rare_or_old_menu],
	      "-",
	      [Button => $do_compound->("Delete this menu"),
	       -command => sub {
		   $mmf->after(100, sub {
				   unregister();
			       });
	       }],
	     ],
	     $btn,
	     __PACKAGE__."_menu",
	     -title => "SRT Shortcuts",
	    );

#     if ($devel_host) {
# 	for my $keysym (qw(question slash ssharp)) { # all possible and impossible places for C-?
# 	    bind_nomod($top, "<Control-$keysym>" => sub { warn "? of @_" });
# $t->bind("<Control-slash>" => sub { warn "? of @_"; Tk->break });
# $t->bind("<Control-ssharp>" => sub { warn "? of @_"; Tk->break });


    my $menu = $mmf->Subwidget(__PACKAGE__ . "_menu_menu");
    $menu->configure(-disabledforeground => "black");
    if ($main::devel_host) {
	my $map_menuitem = $rare_or_old_menu->index("Karte");
	$rare_or_old_menu->entryconfigure($map_menuitem,
					  -menu => main::get_map_button_menu($menu));
    }
}

sub prepare_mudways_prognosis {
    open my $fh, '-|', $^X, "$bbbike_rootdir/miscsrc/dwd-soil-update.pl", '-q';
    my $dwd_soil = do { local $/; <$fh> };
    print STDERR "Current soil data:\n", $dwd_soil;

    my $dwd_station = 'Dahlem';
    my $bf10;
    for my $line (split /\n/, $dwd_soil) {
	if ($line =~ m{^\Q$dwd_station\E.*\s+(\d+)$}) {
	    $bf10 = $1;
	    last;
	}
    }
    if (!defined $bf10) {
	main::status_message("Cannot get soil data for DWD station '$dwd_station', please see stderr for more information", "die");
    }

    # XXX some duplication in dwd-soil-update.pl
    my $soil_dwd_dir;
    if (defined $bbbike_auxdir) {
	$soil_dwd_dir = $bbbike_auxdir . "/data/soil_dwd";
    } else {
	$soil_dwd_dir = $bbbike_rootdir . "/tmp/soil_dwd";
    }

    system($^X, "$bbbike_rootdir/miscsrc/mudways-enrich.pl", "--soil-dwd-dir", $soil_dwd_dir); die $? if $? != 0;
    system($^X, "$bbbike_rootdir/miscsrc/mudways-enriched-to-handicap.pl", "--bf10=$bf10", "-o", "/tmp/mudways_prognosis.bbd"); die $? if $? != 0;
}

sub add_keybindings {
    # same like in Merkaartor
    $main::top->bind("<Control-D>" => sub {
			 _require_BBBikeOsmUtil();
			 BBBikeOsmUtil::mirror_and_plot_visible_area();
		     });
}

sub remove_keybindings {
    $main::top->bind("<Control-D>" => undef);
}

sub tracks_in_region {
    require BBBikeEdit;
    require BBBikeGPS;
    if (@main::coords != 2) {
	main::status_message("Expecting exactly two points forming a region", "die");
    }
    my @region_corners = map { @$_ } @main::coords;
    my $parse_tag = sub {
	my($tag) = @_;
	$tag =~ s{(\.trk)(?:\s+\((.*)\))?$}{$1}; # strip comment part
	my $comment = $2;
	($tag, $comment);
    };

    my %seen_track;
    my %file_to_comment;
    my @tracks = sort grep {
	if (!$seen_track{$_}) {
	    $seen_track{$_}++;
	    1;
	} else {
	    0;
	}
    } grep {
	/\.trk($|\s)/
    } map {
	my($file, $comment) = $parse_tag->(($main::c->gettags($_))[1]);
	if ($comment) {
	    $file_to_comment{$file}->{$comment}++;
	}
	$file;
    } $main::c->find(overlapping => @region_corners);
    @tracks = map {
	my @comments;
	if ($file_to_comment{$_}) {
	    @comments = keys %{ $file_to_comment{$_} };
	}
	if (@comments) {
	    $_ . " (" . join(", ", @comments) . ")";
	} else {
	    $_;
	}
    } @tracks;

    my $t = $main::top->Toplevel(-title => "Tracks in region");
    $t->transient($main::top) if $main::transient;
    my $lb = $t->Scrolled("Listbox",
			  -selectmode => 'multiple',
			  -scrollbars => "osoe",
			  -exportselection => 0,
			 )->pack(-fill => "both", -expand => 1);
    $lb->insert("end", @tracks);
    my %old_selection;
    my %index_to_layers;
    $lb->bind("<<ListboxSelect>>" => sub {
		  my %new_selection = map{($_,1)} $lb->curselection;
		  my @add = grep { !$old_selection{$_} } keys %new_selection;
		  my @del = grep { !$new_selection{$_} } keys %old_selection;
		  for my $index (@del) {
		      my @layers = @{ $index_to_layers{$index} || [] };
		      for my $layer (@layers) {
			  my($type, $abk) = split /-/, $layer;
			  main::delete_layer($abk);
		      }
		  }
		  my @errors;
		  for my $index (@add) {
		      my $base = $lb->get($index);
		      ($base, undef) = $parse_tag->($base);
		      my $file = BBBikeEdit::find_gpsman_file($base);
		      if (!$file) {
			  push @errors, M("Keine Datei zu $base gefunden");
			  next;
		      }
		      my %plotted_layer_info;
		      BBBikeGPS::do_draw_gpsman_data($main::top, $file,
						     -solidcoloring => 1,
						     -plottedlayerinfo => \%plotted_layer_info,
						    );
		      eval { mark_most_recent_layer() }; warn $@ if $@;
		      $index_to_layers{$index} = [keys %plotted_layer_info];
		  }
		  %old_selection = %new_selection;
		  if (@errors) {
		      main::status_message(join("\n", @errors));
		  }
	      });
    {
	my $f = $t->Frame->pack(qw(-fill x));
	my $cb = $f->Button(Name => "close",
			    -command => sub { $t->destroy })->pack(qw(-side left));
	$t->bind('<Escape>' => sub { $cb->invoke });
	$f->Button(-text => M("Liste speichern"),
		   -command => sub {
		       my $outfile = $t->getSaveFile;
		       if (defined $outfile) {
			   open my $ofh, ">", $outfile
			       or main::status_message(Mfmt("Kann auf %s nicht schreiben: %s", $outfile, $!), "die");
			   print $ofh join("\n", @tracks), "\n"
			       or die $!;
			   main::status_message(Mfmt("Die Datei %s wurde geschrieben", $outfile), "infodlg");
		       }
		   },
		  )->pack(qw(-side left));
    }
}

sub make_gps_target {
    my $rule = shift;
    if (fork == 0) {
	require BBBikeBuildUtil;
	exec(qw(xterm -e sh -c),
	     'cd ' . $bbbike_rootdir . '/misc/gps_data && ' . BBBikeBuildUtil::get_pmake() . ' ' . $rule . '; echo Ready; sleep 9999');
	die $!;
    }
}

sub add_new_datafile_layer {
    my($type, $file, %args) = @_;
    add_new_layer($type, _maybe_orig_file("$main::datadir/$file"));
}

# $type: p or str
# $file: file to render
# Possible further arguments: Width => $size (p or str) or Width => [$size,...] (str)
sub add_new_layer {
    my($type, $file, %args) = @_;
    my $free_layer = main::next_free_layer($type);
    if ($type eq 'str') {
	if (exists $args{Width}) {
	    if (ref $args{Width} eq 'ARRAY') {
		$main::line_width{$free_layer} = [@{$args{Width}}];
	    } elsif (defined $args{Width}) {
		$main::line_width{$free_layer} = [($args{Width})x6];
	    } else {
		delete $main::line_width{$free_layer};
	    }
	} else {
	    $main::line_width{$free_layer} = [@{$main::line_width{default}}];
	}
    } elsif ($type eq 'p') {
	if (exists $args{Width}) {
	    $main::p_width{$free_layer} = $args{Width};
	} else {
	    delete $main::p_width{$free_layer};
	}
    }
    $layer_for_type_file{"$type $file"} = $free_layer;
    if ($type eq 'sperre') { # XXX BBBikeLazy does not handle sperre type yet
	$main::p_draw{$free_layer} = 1;
	$main::p_file{$free_layer} = $file; # XXX not needed for plot_sperre, but for the LayerEditor (to display the file name as label)
	main::plot_sperre($file, -abk => $free_layer);
    } else {
	if (!$BBBikeLazy::mode) {
	    require BBBikeLazy;
	    BBBikeLazy::bbbikelazy_empty_setup();
	    main::handle_global_directives($file, $free_layer);
	    main::bbbikelazy_add_data($type, $free_layer, $file);
	    main::bbbikelazy_init();
	} else {
	    main::handle_global_directives($file, $free_layer);
	    main::bbbikelazy_add_data($type, $free_layer, $file);
	}
    }
    # XXX add_to_stack functionality gots destroyed by calling once the layer_editor, because it used special_raise for *all*. get rid of special_raise/lower!
    main::add_to_stack($free_layer, "before", "pp");
    Hooks::get_hooks("after_new_layer")->execute;
    $free_layer;
}

sub toggle_new_layer {
    my($type, $file, %args) = @_;
    my $layer;
    my $active = 0;
    my $method = delete $args{method} || 'add_new_layer';
    my $type_file = "$type $file";
    if (!$layer_for_type_file{$type_file}) {
	eval {
	    no strict 'refs';
	    $layer = &{$method}($type, $file, %args);
	    if ($args{above}) {
		main::set_in_stack($layer_for_type_file{$type_file}, 'above', $args{above});
	    } elsif ($args{below}) {
		main::set_in_stack($layer_for_type_file{$type_file}, 'below', $args{below});
	    }
	    $active = 1;
	};
	if ($@) {
	    $want_plot_type_file{$type_file} = 0;
	    main::status_message("Cannot toggle layer: $@", 'die');
	}
    } else {
	$layer = $layer_for_type_file{$type_file};
	if ($type eq 'sperre') { # XXX BBBikeLazy does not handle sperre type yet
	    delete $main::p_draw{$layer};
	    main::plot_sperre(undef, -abk => $layer);
	    delete $layer_for_type_file{$type_file};
	} else {
	    eval {
		delete $main::str_draw{$layer};
		delete $main::p_draw{$layer};
		if ($type eq 'p') {
		    $main::c->delete($layer.'-fg');
		    $main::c->delete($layer.'-img');
		} else {
		    $main::c->delete($layer);
		}
		delete $layer_for_type_file{$type_file};
		BBBikeLazy::bbbikelazy_remove_data($type, $layer);
		$active = 0;
	    };
	    if ($@) {
		$want_plot_type_file{$type_file} = 1;
		main::status_message("Cannot toggle layer: $@", 'die');
	    }
	}
    }
    ($layer, $active);
}

our %layer_checkbutton; # XXX our just for debugging
sub layer_checkbutton {
    my($label, $type, $file, %args) = @_;
    my $oncallback  = delete $args{oncallback};
    my $offcallback = delete $args{offcallback};
    my $preparecallback = delete $args{preparecallback};
    my $below = delete $args{below};
    my $above = delete $args{above};
    # XXX This does not seem to work, $main::edit_normal_mode value
    # seems to get freezed although it's a global?!
    my $below_above_cb = delete $args{below_above_cb};
    my $maybe_orig_file = delete $args{maybe_orig_file};
    my $set_layer_highlightning = delete $args{set_layer_highlightning};
    my $special_raise = delete $args{special_raise};
    my $real_file = $maybe_orig_file ? _maybe_orig_file($file) : $file;
    my $key = "$type $real_file";
    
    [Checkbutton => (ref $label eq 'ARRAY' ? @$label : $label),
     -variable => \$layer_checkbutton{$key},
     -command => sub {
	 if ($below_above_cb) {
	     my %below_above_args = $below_above_cb->();
	     if ($below_above_args{below}) {
		 $below = $below_above_args{below};
	     } elsif ($below_above_args{above}) {
		 $above = $below_above_args{above};
	     }
	 }

	 if ($preparecallback && !$layer_for_type_file{$key}) {
	     $preparecallback->();
	 }

	 my($layer, $active) = toggle_new_layer($type, $real_file, below => $below, above => $above, %args);
	 if ($oncallback && $layer_for_type_file{$key}) {
	     $oncallback->($layer, $type, $real_file);
	 } elsif ($offcallback && !$layer_for_type_file{$key}) {
	     $offcallback->($layer, $type, $real_file);
	 }
	 if ($set_layer_highlightning) {
	     set_layer_highlightning($layer);
	 }
	 if ($special_raise) {
	     main::special_raise($layer, 0);
	 }
     },
    ];
}

sub set_layer_highlightning {
    my $layer = shift;
    $main::layer_active_color{$layer} = 'red';
#     $main::layer_post_enter_command{$layer} = sub {
# 	#$main::c->raise("current")
# 	$name_tag = ($main::c->gettags("current"))[1];
# 	$main::c->
#     };
}

# Very hardcoded to my own environment:
# * images in ~/images/from_handy/Fotos and ~/images/nikon/**
# * gps tracks in ~/src/bbbike/misc/gps_data
sub add_todays_geocoded_images {
    require File::Copy;
    require File::Find;
    require File::Temp;
    my(@l) = localtime;
    my $y = $l[5]+1900;
    my $m = $l[4]+1;
    my $d = $l[3];
    my $glob = sprintf "$ENV{HOME}/images/from_handy/Fotos/%04d-%02d/%02d%02d%04d*.jpg", $y,$m,$d,$m,$y;
    my @images = bsd_glob $glob;
    File::Find::find(sub {
			 if (-f $_ && $_ =~ m{.jpg$}i) {
			     my(@s) = stat($_);
			     if (time-$s[9] < 86400) {
				 push @images, $File::Find::name;
			     }
			 }
		     }, "$ENV{HOME}/images/nikon", "$ENV{HOME}/images/iphone6", "$ENV{HOME}/images/iphone11", "$ENV{HOME}/images/mapillary_iphone");
    if (!@images) {
	main::status_message("No images found with glob '$glob'", "warn");
	return;
    }

    my $found_files = 0;
    my $gpsdata_dest_dir = File::Temp::tempdir(CLEANUP => 1, TMPDIR => 1);
    my $gpsdatadir = "$bbbike_rootdir/misc/gps_data";
    my $trk = sprintf "$gpsdatadir/%04d%02d%02d.trk", $y,$m,$d;
    if (-e $trk) {
	File::Copy::cp($trk, $gpsdata_dest_dir)
		or main::status_message("Copying $trk to $gpsdata_dest_dir failed: $!", 'die');
	$found_files++;
    }
    my $current_gpx = "$ENV{HOME}/trash/Current.gpx";
    if (-e $current_gpx) {
	my @cmd = ("$bbbike_rootdir/miscsrc/gpx2gpsman", "-timeoffset", "automatic", $current_gpx, "-o", sprintf("$gpsdata_dest_dir/%04d%02d%02db.trk", $y,$m,$d));
	system(@cmd);
	if ($? != 0) {
	    main::status_message("The command '@cmd' failed", 'die');
	}
	$found_files++;
    }
    if (!$found_files) {
	main::status_message("No today's track found, checked for $trk and $current_gpx", 'die');
    }
    my($tmpfh,$tmpfile) = File::Temp::tempfile(SUFFIX => sprintf("_geocoded_images_%04d%02d%02d.bbd", $y,$m,$d), UNLINK => 1)
	or main::status_message($!, 'die');
    my @cmd = ("$bbbike_rootdir/miscsrc/geocode_images", "-o", $tmpfile, "-gpsdatadir", $gpsdata_dest_dir, "-v", @images);
    system(@cmd);
    if ($? != 0) {
	main::status_message("The command '@cmd' failed", 'die');
    }
    add_new_layer('str', $tmpfile);
}

sub enable_all_layers_for_editing {
    # Don't include "u" here, because it usually disturbs normal editing
    for my $str_abk (qw(s l f w b r rw e qs ql hs hl nl gr)) {
	main::plot('str', $str_abk, -draw => 1);
    }
    # XXX hackish. There should be an easier way to do this
    for my $basefile_def (
			  ['zebrastreifen', maybe_orig_file => 0],
			  ['culdesac', maybe_orig_file => 1],
			  ['ortsschilder', maybe_orig_file => 1],
			 ) {
	my($basefile, %layer_opts) = @$basefile_def;
	my $type = "p";
	my $file = "$main::datadir/$basefile";
	my $real_file = $layer_opts{maybe_orig_file} ? _maybe_orig_file($file) : $file;
	my $type_file = "$type $real_file";
	if (!$layer_for_type_file{$type_file}) {
	    my(undef, $active) = toggle_new_layer($type, $real_file);
	    $layer_checkbutton{$type_file} = $active;
	}
    }
    main::plot_comments_all(1);
    # Don't include "u" here, too, see above.
    for my $p_abk (qw(b r lsa vf sperre)) {
	main::plot('p', $p_abk, -draw => 1);
    }
}

######################################################################
# VMZ/LBVS

# The "done" file which remembers what is already done.
use vars qw($vmz_lbvs_directory $vmz_lbvs_done_file);
$vmz_lbvs_directory = "$ENV{HOME}/cache/misc";
$vmz_lbvs_done_file = "$vmz_lbvs_directory/vmz_lbvs_done";

sub md5_file {
    my($file) = @_;
    require Digest::MD5;
    my $ctx = Digest::MD5->new;
    open my $fh, $file
	or die "Can't open $file: $!";
    $ctx->addfile($fh);
    my $digest = $ctx->hexdigest;
}

sub newvmz_process {
    my @vmztool_args;
    # XXX It would be nice to rebuild the both "sourceid" files using
    # the targets in data/Makefile. But: the build process probably
    # does not work well if there are multiple parallel processes, and
    # I have usually an endless build loop running... so invent some
    # kind of locking maybe?
    if (-e "$bbbike_rootdir/tmp/sourceid-all.yml") {
	push @vmztool_args, "-existsid-current", "$bbbike_rootdir/tmp/sourceid-all.yml";
    } else {
	main::status_message("'$bbbike_rootdir/tmp/sourceid-all.yml' is not built!", "die");
    }
    if (-e "$bbbike_rootdir/tmp/sourceid-current.yml") {
	push @vmztool_args, "-existsid-all", "$bbbike_rootdir/tmp/sourceid-current.yml";
    } else {
	main::status_message("'$bbbike_rootdir/tmp/sourceid-current.yml' is not built!", "die");
    }

    my $bbd = "$vmz_lbvs_directory/diffnewvmz.bbd";
    rename $bbd, "$vmz_lbvs_directory/diffnewvmz.old.bbd";
    my @cmd = ($^X, "$bbbike_rootdir/miscsrc/VMZTool.pm",
	       @vmztool_args,
	       "-oldstore", "$vmz_lbvs_directory/newvmz.yaml",
	       "-newstore", "$vmz_lbvs_directory/newvmz.new.yaml",
	       "-outbbd", $bbd,
	      );
    system(@cmd);
    if (!-s $bbd) {
	main::status_message("Error while running @cmd, no bbd file $bbd created", "die");
    }
    show_new_vmz_diff();
}

sub show_vmz_lbvs_files {
    require File::Basename;
    my $t = $main::top->Toplevel(-title => "VMZ/LBVS files");
    fill_vmz_lbvs_files($t);
}

sub fill_vmz_lbvs_files {
    my $t = shift;
    return if !Tk::Exists($t);
    $_->destroy for ($t->children);
    my @files;
    opendir my $DIRH, $vmz_lbvs_directory
	or die "Cannot open $vmz_lbvs_directory directory: $!";
    while(defined(my $f = readdir $DIRH)) {
	if ($f =~ m{^diff(lbvs|vmz)\.bbd(\.\d+)?$}) {
	    push @files, "$vmz_lbvs_directory/$f";
	}
    }
    my %files_undone = map {($_,1)} get_undone_files($vmz_lbvs_done_file, \@files);
    for my $file (sort @files) {
	$t->Button(-text => File::Basename::basename($file) . " (" . ($files_undone{$file} ? "UNDONE" : "DONE") . ")",
		   -foreground => $files_undone{$file} ? 'red' : 'DarkSeaGreen4',
		   ($files_undone{$file} ? (-font => $main::font{'bold'}) : ()),
		   -command => sub {
		       show_any_diff($file, ($file =~ m{lbvs} ? "lbvs" : "vmz"), $t);
		   },
		  )->pack(-fill => 'x', -anchor => 'w');
    }
}

sub _vmz_lbvs_splitter {
    my($line) = @_;
    my($type, $content, $id, $inuse);
    if ($line =~ m{�}) {
	# new style
	($type, $content, $id, undef, $inuse) = split /�/, $line; # ignore 4th column (url) and everything after 5th
    } else {
	($type, $content) = split /:\s+/, $line, 2;
    }
    ($type, $content, $id, $inuse);
}

sub _vmz_lbvs_columnwidths {
    # the minimum width for the '*' column is hardcoded in show_any_diff
    (200, '*', 200, 100);
}

sub select_vmz_lbvs_diff {
    require Tk::PathEntry;
    my $t = $main::top->Toplevel(-title => "Select VMZ file");
    my $file;
    my $weiter = 0;
    my $pe = $t->PathEntry
	(-textvariable => \$file,
	 -selectcmd => sub { $weiter = 1 },
	 -cancelcmd => sub { $weiter = -1 },
	)->pack(-fill => "x", -expand => 1, -side => "left");
    $pe->focus;
    $t->waitVariable(\$weiter);
    $t->destroy;
    if ($weiter == 1 && $file) {
	show_any_diff($file, "vmz");
    }
}

sub show_vmz_diff {
    my($version) = @_;
    if (defined $version) { $version = ".$version" }
    show_any_diff("$vmz_lbvs_directory/diffvmz.bbd$version", "vmz");
}

sub show_lbvs_diff {
    my($version) = @_;
    unless ($main::str_draw{l}) {
	main::plot("str",'l', -draw => 1);
	main::make_net();
    }
    if (defined $version) { $version = ".$version" }
    show_any_diff("$vmz_lbvs_directory/difflbvs.bbd$version", "lbvs");
}

sub show_new_vmz_diff {
    my($version) = @_;
    unless ($main::str_draw{l}) {
	main::plot('str','l', -draw => 1);
	main::plot('str','sBAB', -draw => 1);
	main::make_net();
    }
    if (defined $version) {
	$version = ".$version";
    } else {
	$version = '';
    }
    show_any_diff("$vmz_lbvs_directory/diffnewvmz.bbd$version", "newvmz");
}

sub show_any_diff {
    my($file, $diff_type, $listener) = @_;
    # To pre-generate cache:
    # XXX make sure that only ONE check_bbbike_temp_blockings process
    # runs at a time...
    system("$bbbike_rootdir/miscsrc/check_bbbike_temp_blockings >/dev/null 2>&1 &");
    require BBBikeAdvanced;
    require File::Basename;
    # XXX note: still a race condition possible! Would be better to
    # open a filehandle and pass this to both the md5 calculation and
    # the plotting.
    my $digest = md5_file($file);
    my $abk = main::plot_additional_layer("str", $file, -interactivelyselected => 0);
    my $token = "chooseort-" . File::Basename::basename($file) . "-str";
    my $t = main::redisplay_top($main::top, $token, -title => $file);
    my $max_window_width = $main::top->screenwidth-20;
    if (!$t) {
	# XXX delete_layer does not happen here. $abk is never recorded.
	$t = $main::toplevel{$token};
	$_->destroy for ($t->children);
    } else {
	$t->geometry($max_window_width . "x" . 260 . "+0-20");
    }
    $t->OnDestroy(sub { main::delete_layer($abk) });
    {
	local $^T = time;
	$t->Label(-text => "Modtime: " . scalar(localtime((stat($file))[9])) .
		  sprintf " (%.1f days ago)", (-M $file)
		 )->pack(-anchor => "w");
    }
    my $f;
    my $hide_ignored;
    {
	my $ff = $t->Frame->pack(-fill => 'x');
	$ff->Checkbutton(-text => "Hide ignored and unchanged",
			 -variable => \$hide_ignored,
			 -command => sub {
			     my $hl = $f->Subwidget("Listbox");
			     if ($hide_ignored) {
				 for ($hl->info("children")) {
				     if ($hl->entrycget($_, "-text") =~ /(ignore|unchanged)/i) {
					 $hl->hide("entry", $_);
				     }
				 }
			     } else {
				 for ($hl->info("children")) {
				     $hl->show("entry", $_);
				 }
			     }
			 })->pack(-anchor => "w", -side => 'left');
	$ff->Button(-text => "Mark done",
		    -command => sub {
			my $ans = $t->messageBox(-message => "Mark file " . File::Basename::basename($file) . " as done?",
						 -type => "YesNo",
						 -icon => 'question',
						);
			if ($ans =~ m{yes}i) {
			    add_done_file($vmz_lbvs_done_file, $file, $digest);
			    if ($listener && Tk::Exists($listener)) {
				fill_vmz_lbvs_files($listener);
				$listener->raise;
			    }
			    if ($diff_type eq 'newvmz') {
				{
				    my @rename = ("$vmz_lbvs_directory/newvmz.yaml", "$vmz_lbvs_directory/newvmz.old.yaml");
				    rename $rename[0], $rename[1]
					or main::status_message("Cannot rename @rename: $!", "warn");
				}
				{
				    my @rename = ("$vmz_lbvs_directory/newvmz.new.yaml", "$vmz_lbvs_directory/newvmz.yaml");
				    rename $rename[0], $rename[1]
					or main::status_message("Cannot rename @rename: $!", "warn");
				}
				require File::Copy;
				require POSIX;
				my $today = POSIX::strftime("%Y%m%d", localtime);
				my $archive_dir = "$vmz_lbvs_directory/archive";
				mkdir $archive_dir if !-d $archive_dir;
				my @copy = ("$vmz_lbvs_directory/newvmz.yaml",
					    "$archive_dir/newvmz-$today.yaml");
				File::Copy::copy(@copy)
					or main::status_message("Cannot copy @copy: $!", "warn");
			    }
			    $t->destroy;
			}
		    })->pack(-anchor => 'e', -side => 'right');
    }
    $f = $t->Frame->pack(-fill => "both", -expand => 1);

    my(@columnwidths) = _vmz_lbvs_columnwidths();
    {
	my $sum_columnwidths = 0;
	my $joker_index;
	for my $index (0 .. $#columnwidths) {
	    my $this_columnwidth = $columnwidths[$index];
	    if ($this_columnwidth ne '*') {
		$sum_columnwidths += $this_columnwidth;
	    } else {
		$joker_index = $index;
	    }
	}
	if (defined $joker_index) {
	    my $new_width = $max_window_width - 10 - $sum_columnwidths;
	    if ($new_width < 200) { $new_width = 200 } # minimum width
	    $columnwidths[$joker_index] = $new_width;
	}
    }

    main::choose_ort("str", $abk,
		     -splitter => \&_vmz_lbvs_splitter,
		     -columnwidths => \@columnwidths,
		     # XXX Maybe implement -infocallback (an info
		     # button in the choose_ort window) some time, but
		     # not that urgent
		     (0 && $diff_type eq 'lbvs' ? (-infocallback => sub {
						       my($w, %args) = @_;
						       $args{-file} = $file;
						       _lbvs_info_callback($w, %args);
						   }) : ()),
		     -container => $f,
		     -ondestroy => sub { $t->destroy },
		    );
}

sub _lbvs_info_callback {
    my($w, %args) = @_;
    my $index = $args{"-index"};
    my $file = $args{"-file"};
    my $info_file = $file . "-info";
    my $token = "lbvsinfo-$file";
    my $t = main::redisplay_top($main::top, $token, -title => M("Information"));
    if (!$t) {
	$t = $main::toplevel{$token};
	$_->destroy for ($t->children);
    }
    my $txt = $t->Scrolled("ROText", -scrollbars => "eos")->pack(qw(-fill both -expand 1));

    require DB_File;
    my $text = "No info for index $index in info file $info_file available.";
    if (tie my %info, "DB_File", $info_file, &Fcntl::O_RDONLY) {
	$text = $info{$index};
    }
    $txt->insert("end", $text);
}

sub show_fritz_verkehr_diff {
    require Tk::TextANSIColor;
    my $token = 'fritzdiff';
    my $t = main::redisplay_top($main::top, $token, -title => "fritz_verkehr diff");
    my $txt;
    if (!$t) {
	$t = $main::toplevel{$token};
	$txt = $t->Subwidget('text');
	$txt->delete('1.0', 'end');
    } else {
	$txt = $t->Scrolled('ROTextANSIColor', -scrollbars => 'eos')->pack(qw(-fill both -expand 1));
	$t->Advertise(text => $txt);
    }
    my $diff = do {
	open my $fh, '-|:utf8', "$bbbike_auxdir/misc/fritz-verkehr-tool.pl", "diff"
	    or die $!;
	local $/;
	<$fh>;
    };
    $txt->insert('end', $diff);
}

sub load_digest_file {
    my $digest_file = shift;
    my $digest_done;
    if (-e $digest_file) {
	require Safe;
	my $c = Safe->new;
	$digest_done = $c->rdo($digest_file) || {};
    }
    $digest_done;
}

sub get_undone_files {
    my($digest_file, $files_ref) = @_;
    my $digest_done = load_digest_file($digest_file);
    my @files_undone;
    for my $file (@$files_ref) {
	my $digest = md5_file($file);
	if (!exists $digest_done->{$digest}) {
	    push @files_undone, $file;
	}
    }
    @files_undone;
}

sub add_done_file {
    my($digest_file, $file, $digest) = @_;
    my $digest_done = load_digest_file($digest_file);
    if (!defined $digest) {
	$digest = md5_file($file);
    }
    $digest_done->{$digest} = $file;
    require Data::Dumper;
    open my $ofh, ">", "$digest_file~"
	or die "Can't write to $digest_file~: $!";
    print $ofh Data::Dumper->new([$digest_done],[qw(digest_done)])->Indent(1)->Useqq(1)->Dump;
    close $ofh
	or die $!;
    rename "$digest_file~", $digest_file
	or die "Can't rename $digest_file~ to $digest_file: $!";
}

######################################################################

sub define_subs {
    package main;
    no warnings 'once';
    *show_info_ext = sub {
	my($c, @tags) = @_;
	#warn "$c - $tags[3] - @tags ";
	my $res;
	if (defined $tags[3] && $tags[3] =~ /^(\d{4}-\d{2}-\d{2})$/ &&
	    open(F, "$ENV{HOME}/private/docs/rad/radstat.data")) {
	    (my $date = $tags[3]) =~ s/-//g;
	    while(<F>) {
		if (index($_, $date) == 0) {
		    chomp;
		    $res = "Radtour:\n" . join "\n", split /\|/, $_;
		    $res =~ s//\n    /g;
		    last;
		}
	    }
	    close F;
	}
	$res;
    };
}

sub find_nearest_hoehe {
    my @inslauf_selection = @main::inslauf_selection;
    if (!@inslauf_selection) {
	main::status_message("No point in selection!", "warn");
	return;
    }
    if (@inslauf_selection > 1) {
	main::status_message("Multiple points in selection!", "warn");
	return;
    }
    my $xy = $Karte::Berlinmap1996::obj->map2standard_s($inslauf_selection[0]);
    my $nearest = $main::lazy_p{$hm_layer}->nearest_point($xy, FullReturn => 1);
    if (!$nearest) {
	main::status_message("No nearest point found", "warn");
	return;
    }
    my $obj = $nearest->{StreetObj};
    (my $elevation) = $obj->[Strassen::NAME()] =~ /^([+-]?\d+\.\d)/;
    my $selbuf = "$elevation\tX $inslauf_selection[0]\n";

    $main::c->SelectionHandle
	(sub {
	     my($offset, $maxbytes) = @_;
	     substr($selbuf, $offset, $maxbytes);
	 });
}

sub set_penalty {
    my $filefrag = shift;
    require BBBikeEdit;
    $main::bbd_penalty = 1;
    $BBBikeEdit::bbd_penalty_invert = 0;
    $BBBikeEdit::bbd_penalty_file = "$bbbike_rootdir/$filefrag";
    BBBikeEdit::build_bbd_penalty_for_search();
}

sub unset_penalty {
    delete $main::penalty_subs{'bbdpenalty'};
}

sub set_penalty_fragezeichen {
    $main::add_net{fz} = 1;
    main::change_net_type();

    require BBBikeEdit;
    $main::bbd_penalty = 1;
    $BBBikeEdit::bbd_penalty_invert = 1;
    $BBBikeEdit::bbd_penalty_file = "$bbbike_rootdir/tmp/fragezeichen-outdoor-nextcheck.bbd";
    BBBikeEdit::build_bbd_penalty_for_search();
}

# XXX $namedraw does not work
sub add_coords_data {
    my($file, $namedraw) = @_;
    require File::Spec;
    my $abs_file = File::Spec->file_name_is_absolute($file) ? $file : _maybe_orig_file("$bbbike_rootdir/tmp/$file");
    add_new_layer("p", $abs_file, NameDraw => $namedraw);
}

sub choose_Berlin_by_data {
    my($directory) = @_;
    if (!-d $directory) {
	require File::Basename;
	main::status_message("The directory '$directory' does not exist. You can create it by running 'make " . File::Basename::basename($directory) . "' in $main::datadir.", 'error');
	return;
    }
    require Encode;
    require File::Basename;
    my $t = $main::top->Toplevel;
    my $lb = $t->Scrolled('Listbox', -scrollbars => "osoe")->pack(qw(-fill both -expand 1));
    $lb->insert("end", map { File::Basename::basename($_) } bsd_glob "$directory/*");
    $lb->bind("<Double-1>" => sub {
		  my(@cursel) = $lb->curselection;
		  my $basename = $lb->get($cursel[0]);
		  $basename = Encode::encode("iso-8859-1", $basename);
		  add_coords_data("$directory/$basename");
	      });
}

sub add_any_streets_bbd {
    my($f, %args) = @_;
    my $layer = add_new_layer("str", _maybe_orig_file($f), %args);
    set_layer_highlightning($layer);
    main::special_raise($layer, 0);
}

sub mark_layer_dialog {
    main::additional_layer_dialog
	    (-title => "Layer markieren",
	     -cb => \&main::mark_layer,
	     -token => 'mark_additional_layer',
	    );
}

sub mark_most_recent_layer {
    main::mark_layer($main::most_recent_str_layer)
	if defined $main::most_recent_str_layer;
}

sub current_search_in_bbbike_cgi {
    my(%args) = @_;
    my $stage = delete $args{stage};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    my $root_url = ($stage eq 'local' ? 'http://localhost/bbbike/cgi/bbbike.cgi' :
		    $stage eq 'devel' ? 'http://bbbike.cvrsnica.herceg.de/cgi-bin/bbbike.cgi' :
		    $stage eq 'pps'   ? 'http://bbbike-pps-jessie.herceg.de/cgi-bin/bbbike.cgi' :
		    $stage eq 'live'  ? 'http://bbbike.de/cgi-bin/bbbike.cgi' :
		    die "Invalid stage parameter '$stage'"
		   );

    if (@main::search_route_points < 2) {
	main::status_message("Not enough points", "die");
    }
    if (@main::search_route_points > 3) {
	main::status_message("Too many points, bbbike.cgi only supports one via", "die");
    }
    my $inx = 0;
    my($start, $via, $goal);
    $start = $main::search_route_points[$inx++]->[0];
    if (@main::search_route_points == 3) {
	$via = $main::search_route_points[$inx++]->[0];
    }
    $goal = $main::search_route_points[$inx]->[0];

    require BBBikeUtil;
    my $url = BBBikeUtil::uri_with_query
	($root_url,
	 [ startc => $start,
	   ($via ? (viac => $via) : ()),
	   zielc => $goal,
	   pref_seen => 1, # gelogen
	 ]);
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    require WWWBrowser;
    WWWBrowser::start_browser($url);
}

sub current_search_in_bbbike_org_cgi {
    if (@main::search_route_points < 2) {
	main::status_message("Not enough points", "die");
    }
    if (@main::search_route_points > 3) {
	main::status_message("Too many points, bbbike.cgi only supports one via", "die");
    }
    my $inx = 0;
    my($start, $via, $goal);
    $start = $main::search_route_points[$inx++]->[0];
    if (@main::search_route_points == 3) {
	$via = $main::search_route_points[$inx++]->[0];
    }
    $goal = $main::search_route_points[$inx]->[0];

    require Karte::Polar;
    my $o = $Karte::Polar::obj;
    for my $coord ($start, (defined $via ? $via : ()), $goal) {
	$coord = join(",", $o->trim_accuracy($o->standard2map(split /,/, $coord)));
    }

    require BBBikeUtil;
    my $url = BBBikeUtil::uri_with_query
	("http://www.bbbike.org/Berlin/",
	 [ startc_wgs84 => $start,
	   ($via ? (viac_wgs84 => $via) : ()),
	   zielc_wgs84 => $goal,
	   pref_seen => 1, # gelogen
	 ]);
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    require WWWBrowser;
    WWWBrowser::start_browser($url);
}

sub current_search_in_openrouteservice_org {
    if (@main::search_route_points < 2) {
	main::status_message("Not enough points", "die");
    }

    require Karte::Polar;
    my $o = $Karte::Polar::obj;
    my @coords;
    for my $c (@main::search_route_points) {
	my($lon,$lat) = $o->trim_accuracy($o->standard2map(split /,/, $c->[0]));
	push @coords, "$lat,$lon";
    }

    my($n1, $n2, $n3);
    {
	my($lat0,$lon0) = split /,/, $coords[0];
	my($lat1,$lon1) = split /,/, $coords[-1];
	$n1 = ($lat1-$lat0)/2 + $lat0;
	$n2 = ($lon1-$lon0)/2 + $lon0;
	$n3 = 10; # XXX how to calculate zoom factor best?
    }

    # https://maps.openrouteservice.org/directions?
    # n1=52.96666&n2=13.993752 - lat/lon of center
    # n3=9 - zoom? (but does not matter...)
    # a=52.509326,13.437996,52.565917,13.51902,... - coordinates for search
    # b=1d - ?
    # c=0 - ?
    # g1=-1 - ?
    # g2=0 - ? 
    # h2=3
    # k1=en-US
    # k2=km
    require BBBikeUtil;
    my $url = BBBikeUtil::uri_with_query
	("https://maps.openrouteservice.org/directions",
	 [ n1 => $n1,
	   n2 => $n2,
	   n3 => $n3,
	   a => join(",", @coords),
	   b => '1d',
	   c => 0,
	   g1 => '-1',
	   g2 => 0,
	   h2 => 3,
	   k1 => 'en-US',
	   k2 => 'km',
	 ]);
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    require WWWBrowser;
    WWWBrowser::start_browser($url);
}

sub current_route_in_bbbike_cgi {
    my(@params) = @_;

    if (!@main::realcoords) {
	main::status_message("No current route", "warn");
	return;
    }
    require Route;
    require Route::GPLE;
	require Route::GPLEU;
    my $rte = Route->new_from_realcoords(\@main::realcoords);
    $rte->set_coord_system($main::coord_system);
    my $gpleu = Route::GPLEU::gple_to_gpleu(Route::GPLE::as_gple($rte));

    require BBBikeUtil;
    my $url = BBBikeUtil::uri_with_query
	("http://localhost/bbbike/cgi/bbbike.cgi",
	 # [ @params ], raw_query => [ gple => $gple ], # minimal, but may cause problems in start_browser call
	 [ gpleu => $gpleu, @params ],
	);
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    require WWWBrowser;
    WWWBrowser::start_browser($url);
}

sub current_route_in_bbbikeleaflet_cgi {
    my(%opts) = @_;
    my $live = delete $opts{live};
    my $selection = delete $opts{selection};

    if (!@main::realcoords) {
	main::status_message("No current route", "warn");
	return;
    }

    my $cgiurl = $live ? "http://bbbike.de/cgi-bin/bbbikeleaflet.cgi" : "http://localhost/bbbike/cgi/bbbikeleaflet.cgi";

    my($coords_string, $gpleu);
    if (0) {
	$coords_string = join("!", map { join(",", @$_) } @main::realcoords);
    } else {
	require Route;
	require Route::GPLE;
	require Route::GPLEU;
	my $rte = Route->new_from_realcoords(\@main::realcoords);
	$rte->set_coord_system($main::coord_system);
	$gpleu = Route::GPLEU::gple_to_gpleu(Route::GPLE::as_gple($rte));
    }

    require BBBikeUtil;
    my %coord_params = ($gpleu ? (gpleu => $gpleu) : (coords => $coords_string));
    my $url;
    if ($selection) {
	# use raw_query here to make URL shorter
	$url = BBBikeUtil::uri_with_query($cgiurl, [%opts], raw_query => [%coord_params]);
	$main::c->SelectionHandle
	    (sub {
		 my($offset, $maxbytes) = @_;
		 substr($url, $offset, $maxbytes);
	     });
    } else {
	# safer, especially avoiding possible shell metacharacters
	$url = BBBikeUtil::uri_with_query($cgiurl, [%opts, %coord_params]);
	main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
	require WWWBrowser;
	WWWBrowser::start_browser($url);
    }
}

sub current_route_as_qrcode {
    my(%args) = @_;
    my $in = delete $args{in} || die "Parameter 'in' is mandatory";
    die "Unhandled parameters: " . join(" ", %args) if %args;

    if (!@main::realcoords) {
	main::status_message("No current route", "warn");
	return;
    }

    my $gple = do {
	require Route;
	require Route::GPLE;
	my $rte = Route->new_from_realcoords(\@main::realcoords);
	$rte->set_coord_system($main::coord_system);
	Route::GPLE::as_gple($rte);
    };

    my @search_route = @{ main::get_act_search_route() };
    my($start, $goal) = ($search_route[0]->[0], $search_route[-1]->[0]);

    my $cgiurl;
    my %params;

    if      ($in eq 'bbbikeleaflet-live') {
	$cgiurl = 'http://bbbike.de/cgi-bin/bbbikeleaflet.cgi';
    } elsif ($in eq 'bbbike-gpx-track-live') {
	$cgiurl = 'http://bbbike.de/cgi-bin/bbbike.cgi';
#	$cgiurl = 'http://cabulja.herceg.de/bbbike/cgi/bbbike.cgi';
	%params =
	    (
	     output_as => 'gpx-track',
	     showroutelist => 1,
	    );
    } else {
	die "Currently only 'bbbikeleaflet-live' and 'bbbike-gpx-track-live' are allowed for 'in' parameter";
    }

    require BBBikeUtil;
    # Using raw_query here may save some 20% on URL length
    my $url = BBBikeUtil::uri_with_query($cgiurl, [%params], raw_query => [ gple => $gple ]);

    _show_qrcode_for_url($url, start => $start, goal => $goal);
}

sub _show_qrcode_for_url {
    my($url, %opts) = @_;
    my $start = delete $opts{start};
    my $goal  = delete $opts{goal};

    require Imager::QRCode;
    my $img = Imager::QRCode->new(casesensitive => 1)->plot($url);
    my $data;
    $img->write(data => \$data, type => 'gif')
	or die main::status_message("Creating QRCode with Imager failed: " . $img->errstr);

    my $t = $main::top->Toplevel(-title => 'QRCode');
    my $p = $t->Photo(-format => 'gif', -data => $data);
    $t->transient($main::top) if $main::transient;
    $t->Label(-image => $p, -borderwidth => 20)->pack;
    {
	my $f = $t->Frame->pack(-fill => 'x');
	my $cb = $f->Button(Name => "close",
			    -command => sub { $t->destroy })->pack(-side => 'right');
	$t->bind('<Escape>' => sub { $cb->invoke });
	my $info_photo = main::load_photo($t, 'info');
	my $info_msg = "URL: $url\nLength of URL: " . length($url);
	if ($start) { $info_msg .= "\nStart: $start" }
	if ($goal)  { $info_msg .= "\nGoal:  $goal" }
	$f->Button(main::image_or_text($info_photo, 'Info'),
		   -command => sub { main::status_message($info_msg, "infodlg") })->pack(-side => 'right');
    }
}

sub current_route_in_windy {
    if (!@main::realcoords) {
	main::status_message('No current route', 'warn');
	return;
    }

    require Karte::Polar;
    my $o = $Karte::Polar::obj;

    my @in_points = map {
	my($x, $y) = map { sprintf "%.3f", $_ } $o->standard2map(@$_);
	+{ x=>$x,y=>$y }
    } @main::realcoords;

    my $i = $#in_points;
    while($i>0) {
	if ($in_points[$i]->{x} == $in_points[$i-1]->{x} &&
	    $in_points[$i]->{y} == $in_points[$i-1]->{y}) {
	    splice @in_points, $i, 1;
	}
	$i--;
    }

    my $simplified_points = visvalingam_whyatt(\@in_points, ['strlen', 950]); # windy seems to limit URLs to about 1024 bytes
    my $middle_point = join ',', @{ $simplified_points->[$#$simplified_points/2] }{qw(y x)};
    my $url = 'https://www.windy.com/distance/car/' . join(';', map { join ',', $_->{y}, $_->{x} } @$simplified_points ) . '?rainAccu,next3d,' . $middle_point . ',9';
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    require WWWBrowser;
    WWWBrowser::start_browser($url);
}

# XXX BBBikeOsmUtil should probably behave like a plugin? or not?
sub _require_BBBikeOsmUtil {
    # XXX hmmm, why not simply require $bbbike_rootdir/miscsrc/BBBikeOsmUtil.pm?
    require Cwd; require File::Basename; local @INC = (@INC, File::Basename::dirname(File::Basename::dirname(Cwd::realpath(__FILE__))) . "/miscsrc");
    require BBBikeOsmUtil;
    BBBikeOsmUtil::register();
}

sub _maybe_orig_file {
    my $file = shift;
    return $file if !$main::edit_normal_mode;
    require File::Spec;
    if (File::Spec->file_name_is_absolute($file)) {
	return $file.'-orig' if -f $file.'-orig';
	return $file;
    } else {
	# assume it exists, without checking
	return $file.'-orig';
    }
}

sub route_lister {
    require "$bbbike_rootdir/miscsrc/BBBikeRouteLister.pm";
    my $show_route = sub {
	my $file = shift;
	if (defined $file) {
	    local $main::zoom_loaded_route = 0; # not good for large routes
	    local $main::center_loaded_route = 1; # but this is OK
	    main::load_save_route(0, $file);
	}
    };
    my $file = BBBikeRouteLister->new($main::top, -browse => sub { $show_route->(shift) })->Show;
    $show_route->($file);
}

sub add_current_route_as_layer {
    if (!@main::realcoords) {
	main::status_message("No current route", "warn");
	return;
    }
    require Route;
    require Route::Heavy;
    require File::Temp;
    my $rte = Route->new_from_realcoords(\@main::realcoords);
    my $s = $rte->as_strassen;
    my($tmpfh,$tmpfile) = File::Temp::tempfile(UNLINK => 1, SUFFIX => '_current_route.bbd')
	or main::status_message($!, 'die');
    $s->write($tmpfile);
    add_new_layer('str', $tmpfile);
}

######################################################################
# Experiments
#

######################################################################
# Nice street labels
#
# currently only executable using
#    SRTShortcuts::street_name_experiment()
# in ptksh or using the SRTShortcuts menu
#
# Known problems:
# - Overlapping street labels
# - Tk's canvas does not deal correctly with rotated fonts, as the bbox
#   calculation is wrong. This is sometimes visible when scrolling or parts
#   of the canvas were obscured. Forcing a redisplay somehow helps.
# - Zooming does not force a recalculation of labels (possible solution:
#   see lazy drawing below)
# - Printing of rotated fonts does not work at all. Probably best is for
#   now to hide all street labels before printing and restore them after
# Minor problems:
# - The angle has to be normalized in 5� steps, otherwise the calculation would
#   take too long. Maybe a smaller angle could be used, or this restriction
#   removed completely with lazy drawing (see below)
# - Mathematical background/explanation for reversing street names is missing
# Improvement possibilities
# - Lazy drawing, and deleting of invisible parts. This would also help in
#   reducing the huge memory consumption in the Xorg server.
# - Splitting labels for long streets (e.g. "Oranienstr." -> "Oranien" "str.")
#   and putting the first part at the beginning and the second part at the end
#   (normal cartographic style)
# - Thicker streets, so labels fit into the streets
#
use constant LABELS_INSIDE_STREET => 1; # yes/no
use constant STREET_NAME_EXPERIMENT_DEBUGGING => 0; # yes/no
my %font_char_length;

{
my $street_name_experiment_preinit_already_warned;
# XXX This sub must currently be physically before
# street_name_experiment() (because of pi import)
sub street_name_experiment_preinit {
    require Tk::Config;
    require Strassen::Core;
    require Strassen::CoreHeavy;
    require Strassen::MultiStrassen;
    require Strassen::Strasse;
    require Strassen::Util;
    use BBBikeUtil qw(pi schnittwinkel sum);
    use VectorUtil qw(move_point_orthogonal);
    if ($^O eq 'MSWin32') {
	die 'Not supported for MSWin32'; # no GUI dialog here, may be called within BBBikeLazy.pm
    }
    if ($Tk::Config::xlib !~ /-lXft\b/) {
	if (!$street_name_experiment_preinit_already_warned) {
	    # Nowadays XFT=1 is default on Unix platforms, so we can be loud here:
	    main::status_message("Sorry, this experiment needs Tk with freetype support! Consider to recompile Tk with XFT=1", "die");
	    $street_name_experiment_preinit_already_warned = 1;
	} else {
	    die; # silently
	}
    }
}

# "pre-loop-globals"
my($delta_HH, $delta_N, $default_fontsize, $fontsize);
my $get_rot_matrix;
my($regular_font, $bold_font);
my $tag;
my($ascent, $descent);

# "strassen-object globals"
my $tag_label;

sub street_name_experiment {
    street_name_experiment_preinit();

    main::IncBusy($main::top);
    ## XXX progress bar does not work --- hiding of dependent canvas does not work
    #$main::progress->Init(-dependents => $main::c, -label => 'Street labels');
    eval {
	street_name_experiment_init();

	$main::c->delete($tag);

	for my $def ([Strassen->new("strassen"), "s-label"],
		     [Strassen->new("fragezeichen"), "s-label"],
		     [do {
			 my $potsdam_s;
			 my $ls = Strassen->new("landstrassen");
			 $ls->grepstreets(sub { $_->[Strassen::NAME()] =~ m{\Q(Potsdam)} });
		     }, "l-label"],
		    ) {
	    my($s, $tag_label) = @$def;
	    street_name_experiment_init_strassen($s, $tag_label);
	    $s->init;
	    #our $xxx=0;
	    #my $anzahl_eindeutig = $s->count; my $s_i = 0;
	    while(1) {
		# XXX progress stuff does not work anymore, since I am not using MultiStrassen anymore
		# XXX it didn't work before, either
		#$main::progress->Update($s_i/$anzahl_eindeutig) if ($s_i % 500 == 0);
	    #$xxx++;last if $xxx > 100;
		my $use_bold;
		my $rec = $s->next;
		my $cat = $rec->[Strassen::CAT()];
		next if $cat =~ m{::igndisp};
		my $c = $rec->[Strassen::COORDS()];
		last if !@$c;
		my $name = $rec->[Strassen::NAME()];
		$use_bold = 1 if $cat =~ m{^(H|HH|B)$};
		# The same street continued? Without interruptions?
		while (1) {
		    my $peek = $s->peek;
		    my $peek_c = $peek->[Strassen::COORDS()];
		    if (!@$peek_c ||
			!($peek->[Strassen::NAME()] eq $name &&
			  $peek_c->[0] eq $c->[-1])) {
			last;
		    }
		    push @$c, @{$peek_c}[1..$#$peek_c];
		    if (!$use_bold) {
			$use_bold = 1 if $peek->[Strassen::CAT()] =~ m{^(H|HH|B)$};
		    }
		    $s->next;
		}
		next if @$c < 2 || $c->[0] eq $c->[-1];

		street_name_experiment_one($name, $c, $use_bold);
	    }
	}
    };
    my $err = $@;
    #$main::progress->Finish;
    main::DecBusy($main::top);
    main::status_message($err, "die") if $err;
	
}

sub street_name_experiment_init {
    # half widths of street signatures
    $delta_HH = main::get_line_width('s-HH')/2;
    $delta_N  = main::get_line_width('s-N')/2;

    $default_fontsize = 12;	# default of sans
    $fontsize = ($main::scale > 7   ? 12   :
		 $main::scale > 5.5 ? 11.3 :
		 $main::scale > 4   ? 11   :
		 $main::scale > 3   ? 10.5 :
		 $main::scale > 2   ? 10   :
		 $main::scale > 1.3 ? 9    :
		                      8
		);

    # XXX Taken from Tk::RotFont
    # Erstellt eine Rotationsmatrix f�r freetype
    # XXX rot-Funktion auslagern (CanvasRotText)
    #use constant ANGLE_STEPS => 10;
    use constant ANGLE_STEPS => 5;
    $get_rot_matrix = sub {
	my($r, $size) = @_;
	$r = int(($r/pi)*((360+ANGLE_STEPS/2)/ANGLE_STEPS))/(360/ANGLE_STEPS)*pi; # ANGLE_STEPS�-Schritte erzwingen, um den X-Server zu entlasten
	if (abs($r - pi) < 0.1) {
	    $r = 3.2;
	} elsif (abs($r + pi) < 0.1) {
	    $r = -3.1;
	}
	my $a1 = $size*cos($r);
	my $s1 = sin($r);
	'matrix=' . join(" ", $a1, $size*$s1, $size*-$s1, $a1);
    };

    ## The normal Vera font, usually
    $regular_font = "sans:size=$fontsize";
    $bold_font    = "sans:size=$fontsize:style=bold";
    ## A condensed font
    # $regular_font = "Nimbus Sans L:size=$fontsize:style=ReguCond";
    # $bold_font    = "Nimbus Sans L:size=$fontsize:style=BoldCond";

    $tag = "experiment-strname";

    my %font_metrics = $main::c->fontMetrics($regular_font); # assume bold metrics are the same
    ($ascent, $descent) = @font_metrics{qw(-ascent -descent)};
}

sub street_name_experiment_init_strassen {
    my(undef, $set_tag_label) = @_;
    $tag_label = $set_tag_label;
}

sub street_name_experiment_one {
    my($name, $c, $use_bold) = @_;
    return if !defined $name || $name eq ''; # may happen with osm data

    my($x1,$y1,$x2,$y2) = (main::transpose(split(/,/, $c->[0])),
			   main::transpose(split(/,/, $c->[-1]))
			  );
    my $using_font = $use_bold ? $bold_font : $regular_font;
    $font_char_length{$using_font} ||= {};
    my $char_length = $font_char_length{$using_font};
    $name = Strasse::strip_bezirk($name);
    $name =~ s{:.*}{};	    # strip fragezeichen/qualitaet description
    my $street_length = Strassen::Util::strecke([$x1,$y1], [$x2,$y2]);
    # fontMeasure is slow, so cache single character width, at the
    # expense of accuracy (kerning!)
    my $text_length = sum map { $char_length->{$_} ||= $main::c->fontMeasure($using_font, $_) } split //, $name;
    if ($street_length < $text_length) {
	if (STREET_NAME_EXPERIMENT_DEBUGGING) {
	    warn "too long: '$name', street length is $street_length\n";
	}
	return;
    }

    # find center of polyline
    my $etappe_length = $street_length;
    {
	# Note: working with untransposed coords here
	my $real_street_length = 0;
	my @c = map { [split /,/] } @$c;
	for my $i (1 .. $#c) {
	    $real_street_length += Strassen::Util::strecke($c[$i-1], $c[$i]);
	}
	my $current_street_length = 0;
	for my $i (1 .. $#c) {
	    $current_street_length += Strassen::Util::strecke($c[$i-1], $c[$i]);
	    if ($current_street_length > $real_street_length/2) {
		# Look back and forth for additional lines which
		# does not change the angle of the middle line
		# (only by a tolerant value). This was an bad
		# example: Kochstr. (in Kreuzberg). This may also
		# lead to worse results, see Apostel-Paulus-Str.
		use constant TOLERANT_ANGLE => 3/180*pi;
		my $begin_i = $i-1;
		my $end_i = $i;
		while ($end_i < $#c) {
		    # Wrap schnittwinkel into eval{}, as especially
		    # for osm data zero-length arcs are possible
		    my($deg, undef) = eval { schnittwinkel(@{ $c[$i-1] }, @{ $c[$i] }, @{ $c[$end_i+1] }) };
		    last if ($deg > TOLERANT_ANGLE);
		    $end_i++;
		}
		while ($begin_i > 0) {
		    # eval{} -> see above
		    my($deg, undef) = eval { schnittwinkel(@{ $c[$begin_i-1] }, @{ $c[$i-1] }, @{ $c[$i] }) };
		    last if ($deg > TOLERANT_ANGLE);
		    $begin_i--;
		}
		($x1,$y1,$x2,$y2) = (main::transpose(@{ $c[$begin_i] }),
				     main::transpose(@{ $c[$end_i] })
				    );
		$etappe_length = Strassen::Util::strecke([$x1,$y1], [$x2,$y2]);
		last;
	    }
	}
    }

    return if !$etappe_length;

    my $r = -atan2($y2-$y1, $x2-$x1);
    if (1) {
	$r = 2*pi - $r;
    }
    if (($r > pi && $r <= pi*1.5) ||
	($r > 2.5*pi && $r <= pi*3)) { # XXXX auf dem Kopf stehend! XXX mathematisch herausfinden, nicht empirisch!
	($x1,$y1,$x2,$y2) = ($x2,$y2,$x1,$y1);
	$r = -atan2($y2-$y1, $x2-$x1);
	if (1) {
	    $r = 2*pi - $r;
	}
    }
    my $matrix = $get_rot_matrix->($r, $fontsize/$default_fontsize);
    #my $deg = $r*180/pi; print STDERR "$name $deg $matrix\n";

    my $fac = ($etappe_length-$text_length)/(2*$etappe_length);
    my($xm,$ym) = (int(($x2-$x1)*$fac+$x1), int(($y2-$y1)*$fac+$y1));
    if (LABELS_INSIDE_STREET) {
	# Street labels should be on the street, European style! So
	# move the labels a little bit towards the center of the
	# street. On the other hand, this may obscure additional map
	# signatures (lik equality, vorfahrt etc.).
	my $delta = $descent + $ascent/2 - ($use_bold ? $delta_HH : $delta_N);
	($xm,$ym) = move_point_orthogonal($xm,$ym,$x1,$y1,$x2,$y2,$delta);
    }
    $main::c->createText($xm,$ym,
			 -text => $name,
			 -anchor => "sw",
			 -font => $using_font . ":$matrix",
			 -state => "disabled",
			 -tags => [$tag, $tag_label],
			);
    if (STREET_NAME_EXPERIMENT_DEBUGGING) {
	$main::c->createLine($x1,$y1,$x2,$y2, -arrow => "last", -tags => $tag);
	$main::c->createLine($xm,$ym,$xm,$ym+1, -capstyle=>"round",-width=>4, -tags => $tag);
    }
}
} # scope for street_name_experiment* functions

######################################################################
# GPS data viewer
sub gps_data_viewer {
    my($gps_file) = @_;

    require GPS::GpsmanData::TkViewer;

    my $t = GPS::GpsmanData::TkViewer->gps_data_viewer($main::top,
						       -gpsfile => $gps_file,
						       -statsargscb => sub {
							   my %stats_args;
							   require Strassen::MultiStrassen;

							   my $areas = eval {
							       MultiStrassen->new("$bbbike_rootdir/data/berlin_ortsteile", "$bbbike_rootdir/data/potsdam");
							   };
							   if (!$areas) {
							       warn "Can't create areas for Stats: $@";
							   } else {
							       $stats_args{areas} = $areas;
							   }

							   my $places = eval {
							       MultiStrassen->new("$bbbike_rootdir/data/orte", "$bbbike_rootdir/data/orte2");
							   };
							   if (!$places) {
							       warn "Can't create places for Stats: $@";
							   } else {
							       $stats_args{places} = $places;
							   }
							   %stats_args;
						       },
						      );
    $main::toplevel{gps_data_viewer} = $t; # XXX what about an existing GPS data viewer?
}

######################################################################
# New GPS simplification

use vars qw($gps_simplification_route_street_layer $gps_simplification_route_point_layer
	    $gps_simplification_route_street_file  $gps_simplification_route_point_file
	  );

sub new_gps_simplification {
    if ($gps_simplification_route_street_layer) {
	main::delete_layer($gps_simplification_route_street_layer);
	undef $gps_simplification_route_street_layer;
    }
    if ($gps_simplification_route_street_file &&
	-f $gps_simplification_route_street_file) {
	unlink $gps_simplification_route_street_file;
    }
    if ($gps_simplification_route_point_layer) {
	main::delete_layer($gps_simplification_route_point_layer);
	undef $gps_simplification_route_point_layer;
    }
    if ($gps_simplification_route_point_file &&
	-f $gps_simplification_route_point_file) {
	unlink $gps_simplification_route_point_file;
    }

    if (!@main::realcoords) {
	main::status_message("No route available", "die");
    }
    my $route = Route->new_from_realcoords(\@main::realcoords);
    require Route::Simplify;
    if (!$main::net) {
	main::make_net();
    }
    my($strobj) = $main::net->sourceobjects; # XXX is this correct for multistrassen?
    my $res = $route->simplify_for_gps
	(-streetobj => $strobj,
	 -netobj => $main::net,
	 -routetoname => [StrassenNetz::simplify_route_to_name
			  ([$main::net->route_to_name([@main::realcoords],-startindex=>0,-combinestreet=>0)],
			   -minangle => 5, -samestreet => 1)
			 ],
	 -showcrossings => 0,
	 -waypointlength => 14, # XXX check if 15 are possible?
	 -waypointcharset=>"latin1",
	);
    my @c;
    my $p = Strassen->new;
    for my $wpt (@{ $res->{wpt} }) {
	my $xy = $wpt->{origlon}.",".$wpt->{origlat};
	push @c, $xy;
	$p->push([$wpt->{ident}, [$xy], "X"]);
    }
    push @c, map { $_->{origlon}.",".$_->{origlat} } $res->{wpt}->[-1];

    my $s = Strassen->new;
    $s->push(["", \@c, "X"]);

    require File::Temp;
    {
	(my($tmpfh),$gps_simplification_route_point_file) = File::Temp::tempfile(UNLINK => 1, SUFFIX => "_p.bbd");
	print $tmpfh $p->as_string
	    or die $!;
	close $tmpfh
	    or die $!;
	$gps_simplification_route_point_layer = main::plot_additional_layer("p", $gps_simplification_route_point_file, -namedraw => 1);
    }

    {
	(my($tmpfh),$gps_simplification_route_street_file) = File::Temp::tempfile(UNLINK => 1, SUFFIX => "_s.bbd");
	print $tmpfh $s->as_string
	    or die $!;
	close $tmpfh
	    or die $!;
	$gps_simplification_route_street_layer = main::plot_additional_layer("str", $gps_simplification_route_street_file);
    }
}

######################################################################
# Real street widths

use vars qw($real_street_widths_s %real_street_widths_pos_to_width);
    
sub real_street_widths {
    use constant LANE_WIDTH => 3; # rough estimates
    use constant PEDESTRIAN_PATHS_WIDTH => 2 * 2.5;
    use constant MEDIAL_STRIP_WIDTH => 2;
    my %cat_to_width = ('B'  => 6 * LANE_WIDTH + PEDESTRIAN_PATHS_WIDTH + MEDIAL_STRIP_WIDTH,
			'HH' => 6 * LANE_WIDTH + PEDESTRIAN_PATHS_WIDTH + MEDIAL_STRIP_WIDTH,
			'H'  => 6 * LANE_WIDTH + PEDESTRIAN_PATHS_WIDTH,
			'NH' => 4 * LANE_WIDTH + PEDESTRIAN_PATHS_WIDTH,
			'N'  => 4 * LANE_WIDTH + PEDESTRIAN_PATHS_WIDTH,
			'NN' => 2 * LANE_WIDTH,
		       );
    my $px_per_m = do {
	my($x0) = main::transpose(0,0);
	my($x1) = main::transpose(1,0);
	abs($x1-$x0);
    };
    my $pos_to_width = \%real_street_widths_pos_to_width;
    if (!$real_street_widths_s || !$real_street_widths_s->is_current) {
	my $s = Strassen->new("strassen-orig", UseLocalDirectives => 1);
	%real_street_widths_pos_to_width = ();
	$s->init;
	while(1) {
	    my $r = $s->next;
	    last if !@{ $r->[Strassen::COORDS()] };
	    my $dir = $s->get_directives;
	    my $w;
	    my $street_width_dir = $dir->{street_width};
	    if ($street_width_dir) {
		if ($street_width_dir->[0] =~ m{^([\d\.]+)m}) {
		    $w = $1;
		} elsif ($street_width_dir->[0] =~ m{(\d+)\s*lanes?}) {
		    $w = $1 * LANE_WIDTH + PEDESTRIAN_PATHS_WIDTH;
		    if ($street_width_dir->[0] =~ m{medial\s+strip}) {
			$w += MEDIAL_STRIP_WIDTH;
		    }
		} else {
		    warn "Cannot parse street_width directive <$street_width_dir->[0]>";
		}
	    } else {
		my $carriageway_width_dir = $dir->{carriageway_width};
		if ($carriageway_width_dir && $carriageway_width_dir->[0] =~ m{^([\d\.]+)m}) {
		    $w = $1 + PEDESTRIAN_PATHS_WIDTH;
		}
	    }
	    if (!$w) {
		$w = $cat_to_width{$r->[Strassen::CAT()]};
	    }
	    if ($w) {
		$pos_to_width->{$s->pos} = $w;
	    }
	}
	$real_street_widths_s = $s;
    }
    for my $item ($main::c->find(withtag => 's')) {
	my(@tags) = $main::c->gettags($item);
	my($index) = $tags[3] =~ m{^s-(\d+)};
	next if !defined $index;
	if (exists $pos_to_width->{$index}) {
	    $main::c->itemconfigure($item, -width => $pos_to_width->{$index}*$px_per_m);
	}
    }
}

######################################################################
# Search while typing feature

sub build_suggest_list {
    require File::Basename;
    my $ignore_qr = qr{(?:
			 qualitaet_s
		       | qualitaet_l
		       | handicap_s
		       | handicap_l
		       | gesperrt
		       | gesperrt_car
		       | comments_[^/]*
		       | ampelschaltung
		       | relation_gps
		       )}x;
    my @files = grep { !m{/${ignore_qr}-orig$}x } glob("$main::datadir/*-orig");
    if (!@files) {
	# Oh, no -orig files available. Assume an osm-converted
	# directory or bbbike from a distribution package
	@files = grep { !m{/${ignore_qr}$}x } grep { !m{/[^/]*\.[^/]*$} } glob("$main::datadir/*");
    }
    if (!@files) {
	main::status_message("Can't use this feature, no suitable files found in $main::datadir.", "error");
	return;
    }
    my %map;
    for my $file (@files) {
	my $s = eval { Strassen->new($file, UseLocalDirectives => 1) };
	if ($s) {
	    my $base = File::Basename::basename($file);
	    $s->init;
	    while(1) {
		my $r = $s->next;
		last if !@{ $r->[Strassen::COORDS()] };
		my $name = $r->[Strassen::NAME()];
		next if $name =~ m{^(\s*|[\d\.]+)$};
		$map{$name . " ($base)"} = $r->[Strassen::COORDS()][0];
		my $dir = $s->get_directives;
		if ($dir->{alias}) {
		    for my $alias (@{ $dir->{alias} }) {
			$map{$alias . " ($base)"} = $r->[Strassen::COORDS()][0];
		    }
		}
	    }
	}
    }
    map { [$_, $map{$_}] } sort keys %map;
}

sub tk_suggest {
    my @suggest_list = build_suggest_list();
    my $t = $main::top->Toplevel(-title => "Search");
    my $search;
    my $k2l = $t->Scrolled("K2Listbox",
			   -width => 40,
			   -scrollbars => "osoe",
			   -textvariable => \$search,
			  )->pack(qw(-expand 1 -fill both));
    $k2l->focus;
    $k2l->autocomplete;
    $k2l->insert("end", map { join("\t", @$_) } @suggest_list);
    my $show_cb = sub {
	my($name, $coord) = split /\t/, $search;
	if (!$coord) {
	    main::status_message("Please enter something!", "warn");
	} else {
	    main::mark_point(-coords => [[[ main::transpose(split /,/, $coord) ]]],
			     -clever_center => 1,
			     -inactive => 1,
			    );
	}
    };
    $t->Button(-text => "Show",
	       -command => $show_cb,
	      )->pack;
    $t->bind("<Return>" => sub { # hack:
		 $k2l->focusNext; # to trigger focusout
		 $t->after(100, $show_cb);
	     });
}

######################################################################
# Situation at point, debugging helper

sub _get_kreuzungen {
    our $kreuzungen;
    return $kreuzungen if $kreuzungen;
    require Strassen::Kreuzungen;
    my $ampeln = Strassen->new("$main::datadir/ampeln");
    my $vf     = Strassen->new("$main::datadir/vorfahrt");
    $kreuzungen = Kreuzungen::MoreContext->new(Strassen => $main::str_obj{'s'},
					       AllPoints => 1, # auch Kurvenpunkte
					       WantPos => 1, # for get_records
					       Ampeln => $ampeln->get_hashref_by_cat,
					       Vf     => $vf,
					       HandicapNet => main::make_handicap_net(),
					       QualitaetNet => main::make_qualitaet_net(),
					      );
}

sub show_situation_at_point {
    my $kreuzungen = _get_kreuzungen();
    if (@main::realcoords != 3) {
	main::status_message('Must be three coordinates in route!', 'error');
	return;
    }
    require Data::Dumper;
    my @p = map { join ",", @$_ } @main::realcoords[1,0,2];
    my %result = $kreuzungen->situation_at_point(@p);
    my $txt = $main::top->Subwidget('SituationAtPoint');
    $txt = undef if !Tk::Exists($txt);
    if (!$txt) {
	my $tl = $main::top->Toplevel(-title => "Situation at point");
	$txt = $tl->Scrolled("ROText", -scrollbars => "osoe")->pack(qw(-fill both -expand 1));
	$main::top->Advertise('SituationAtPoint' => $txt);
    }
    $txt->delete('1.0','end');
    $txt->insert('end', "For points @p\n");
    $txt->insert('end', Data::Dumper->new([\%result],[qw()])->Indent(1)->Useqq(1)->Dump);
    $txt->toplevel->raise;
}

sub toggle_situation_at_point_for_route {
    my $hookname_add = __PACKAGE__ . "_show_situation_at_point_for_route";
    my $hookname_del = __PACKAGE__ . "_show_situation_at_point_for_route-delete";
    if ($show_situation_at_point_for_route) {
	Hooks::get_hooks("new_route")->add(\&show_situation_at_point_for_route, $hookname_add);
	Hooks::get_hooks("del_route")->add(\&delete_situation_at_point_for_route, $hookname_del);
	main::add_to_stack("situation_at_point", "topmost");
	show_situation_at_point_for_route();
    } else {
	Hooks::get_hooks("new_route")->del($hookname_add);
	Hooks::get_hooks("del_route")->del($hookname_del);
	delete_situation_at_point_for_route();
    }
}

sub show_situation_at_point_for_route {
    my $kreuzungen = _get_kreuzungen();
    if (!@main::realcoords) {
	return;
    }
    my @search_route = @{ main::get_act_search_route() };
    my %point_to_dir;
    for my $i (0 .. $#search_route) {
	my $coord = join(",", @{ $main::realcoords[$search_route[$i+1]->[StrassenNetz::ROUTE_ARRAYINX()][0]] });
	my $direction = {'l' => 'left',
			 'r' => 'right',
			 '' => '',
			}->{$search_route[$i]->[StrassenNetz::ROUTE_DIR()]};
	my $angle = $search_route[$i]->[StrassenNetz::ROUTE_ANGLE()];
	my $extra = $search_route[$i]->[StrassenNetz::ROUTE_EXTRA()];
	my $important = $extra && $extra->{ImportantAngle};
	# Heuristik from bbbike.cgi
	if (!$angle) { $angle = 0 }
	$angle = int($angle/10)*10;
	if ($angle < 30 && !$important) {
	    $direction = "";
	} elsif ($angle >= 160 && $angle <= 200) {
	    $direction = 'turn-back';
	} elsif ($angle <= 45) {
	    $direction = 'half-' . $direction . " $angle�";
	} else {
	    $direction .= " $angle�";
	}
	if (exists $point_to_dir{$coord}) {
	    $point_to_dir{$coord} .= "; $direction";
	} else {
	    $point_to_dir{$coord} = $direction;
	}
    }

    delete_situation_at_point_for_route();
    for my $i (1 .. $#main::realcoords-1) {
	my @p = map { join ",", @$_ } @main::realcoords[$i,$i-1,$i+1];
	my %result = $kreuzungen->situation_at_point(@p);
	main::outline_text($main::c,
			   main::transpose(@{$main::realcoords[$i]}),
			   -text => $result{action} . (exists $point_to_dir{$p[0]} ? " ($point_to_dir{$p[0]})" : ""),
			   -anchor => 'w',
			   -tags => ['situation_at_point'],
			  );
    }
}

sub delete_situation_at_point_for_route {
    $main::c->delete('situation_at_point');
}

######################################################################
# Visualize nets (debugging helper)

sub net_to_strassen {
    my($net, $payload_is_name) = @_;
    my $file = $main::top->getSaveFile;
    return if !$file;
    my $s = Strassen->new;
    my %used_cat;
    while(my($c1,$v) = each %{ $net->{Net} }) {
	while(my($c2,$payload) = each %$v) {
	    my($name, $cat) = $payload_is_name ? ($payload, "X") : ($payload, $payload);
	    $used_cat{$cat}++;
	    $s->push([$name, [$c1, $c2], "$cat;"]);
	}
    }

    my $color_i = 0;
    my @colors = (qw(green red blue orange black darkblue yellow), '#ffdead');
    my %color;
    for my $cat (sort { $used_cat{$b} <=> $used_cat{$a} } keys %used_cat) {
	$color{$cat} = $colors[$color_i++];
	last if $color_i > $#colors;
    }
    $s->set_global_directives({
			       map { ("category_color.$_" => [$color{$_}]) } keys %color
			      });
    $s->write($file);
}

sub visualize_N_RW_net {
    if (!$main::N_RW_net) {
	main::status_message("\$N_RW_net does not exist --- please do one search with N_RW opt turned on first!", "error");
	return;
    }
    my %cat_to_color = ( 'N' => 'green',
			 'N_RW' => 'blue',
			 'H_RW' => 'orange',
			 'H' => 'red',
		       );
    main::IncBusy($main::top);
    eval {
	$main::c->delete('N_RW_net');
	while(my($c1,$v) = each %{ $main::N_RW_net->{Net} }) {
	    while(my($c2,$cat) = each %$v) {
		$main::c->createLine(main::transpose(split /,/, $c1),
				     main::transpose(split /,/, $c2),
				     -width => 2,
				     -fill => $cat_to_color{$cat} || 'black',
				     -tags => 'N_RW_net',
				);
	    }
	}
    };
    my $err = $@;
    main::DecBusy($main::top);
    main::status_message($err, "die") if $err;
}

######################################################################
# BBBikeSuggest

sub show_bbbike_suggest_toplevel {
    my(%args) = @_;
    require File::Temp;
    require Strassen::Strasse;
    require "$FindBin::RealBin/babybike/lib/BBBikeSuggest.pm";
    my $suggest = BBBikeSuggest->new;
    my($ofh,$sorted_zipfile) = File::Temp::tempfile(SUFFIX => "_bbbike_suggest.data", UNLINK => 1);
    my $tempstreetsfile;
    my $srcfile;
    my $is_opensearch_file;
    my %alias2street;
    my $is_utf8;
    my $plz;
    for my $try_srcfile ("$main::datadir/opensearch.streetnames",
			 "$main::datadir/strassen",
			 "$main::datadir/Berlin.coords.data", # usually never used --- check for this file, but possibly use the combined cache file
			) {
	if (-s $try_srcfile) {
	    if ($try_srcfile =~ m{/strassen$}) {
		require Strassen::MultiStrassen;
		require Strassen::Core;
		require Strassen::CoreHeavy;
		require PLZ;
		my @ms;
		push @ms, Strassen->new("$main::datadir/strassen");
		if ($main::city_obj->cityname eq 'Berlin' && -r "$main::datadir/landstrassen") {
		    my $s = Strassen->new("$main::datadir/landstrassen");
		    push @ms, $s->grepstreets(sub { $_->[Strassen::NAME()] =~ m{ \(Potsdam\)$} });
		}
		my $ms = MultiStrassen->new(@ms);
		(my($tmpfh), $tempstreetsfile) = File::Temp::tempfile(UNLINK => 1, SUFFIX => "_bbbike_suggest0.data")
		    or die $!;
		binmode $tmpfh, ':encoding(iso-8859-1)'; # XXX PLZ.pm is not yet utf-8 capable
		print $tmpfh PLZ->new_data_from_streets($ms);
		close $tmpfh
		    or die $!;
		$plz = PLZ->new($tempstreetsfile);
		$srcfile = $tempstreetsfile;
	    } elsif ($try_srcfile =~ m{Berlin.coords.data}) {
		$plz = main::make_plz();
		$srcfile = $plz->{File};
		main::status_message("Should never happen: Keine PLZ-Datenbank vorhanden!", 'die') if (!$plz);
	    } else { # openssearch
		$srcfile = $try_srcfile;
		$is_opensearch_file = 1;
		$is_utf8 = 1;
	    }
	    last;
	}
    }
    if (!$srcfile) {
	main::status_message("Sorry, no data file suitable for BBBikeSuggest found", "err");
	return;
    }
    {
	local $ENV{LANG} = $ENV{LC_CTYPE} = $ENV{LC_ALL} = $is_utf8 ? 'de_DE.UTF-8' : 'de_DE.ISO8859-1'; # XXX what about other languages? what if iso-8859-1 or utf-8 locale is N/A?
	open my $fh, "-|", 'sort', $srcfile
	    or die "Cannot sort $srcfile: $!";
	binmode $fh, ':utf8' if $is_utf8;
	binmode $ofh, ':utf8' if $is_utf8;
	while(<$fh>) {
	    if ($is_opensearch_file) {
		chomp;
		my($alias, $street) = split /\t/, $_;
		print $ofh join("|", $alias, "", "", "0,0"), "\n";
		if ($street) {
		    $alias2street{$alias} = $street;
		}
	    } else {
		print $ofh $_;
	    }
	}
	close $fh
	    or die "Cannot sort $srcfile: $!";
	close $ofh
	    or die "Error while writing to $sorted_zipfile: $!";
    }
    $suggest->set_zipfile($sorted_zipfile, ($is_utf8 ? (-encoding => "utf-8") : ()));
    my $t = main::redisplay_top($main::top, 'bbbike_suggest', -force => 1, -title => 'Search street', %args);
    main::set_as_toolwindow($t);
    my $w = $suggest->suggest_widget
	($t, -selectcmd => sub {
	     my $w = shift;
	     my $str = $w->get;
	     my $coord;
	     if (!$is_opensearch_file) {
		 ($str,my(@cityparts)) = Strasse::split_street_citypart($str);
		 my($matchref) = $plz->look_loop
		     ($str, Agrep => 3, Max => 1,
		      (@cityparts ? (Citypart => \@cityparts) : ()),
		     );
		 my(@match) = @$matchref;
		 main::status_message("Strange, no match for $str (@cityparts) found...", 'die') if (!@match);
		 $coord = $match[0]->[PLZ::LOOK_COORD()];
	     } else {
		 if (exists $alias2street{$str}) {
		     $str = $alias2street{$str};
		 }
		 my $s = $main::str_obj{s} || die "No strassen object available";
		 $s->init;
		 while(1) {
		     my $r = $s->next;
		     my $c = $r->[Strassen::COORDS()];
		     last if !@$c;
		     if ($str eq $r->[Strassen::NAME()]) {
			 $coord = $c->[$#$c/2];
			 last;
		     }
		 }
		 if (!$coord) {
		     main::status_message("Strange, no match for $str found...", 'die');
		 }
	     }
	     main::mark_point(-coords => [[[ main::transpose(split /,/, $coord) ]]],
			      -clever_center => 1,
			      -inactive => 1);
	 });
    $w->pack;
    $w->focus;
}

######################################################################
# Garmin devcap

sub garmin_devcap {
    require BBBikeYAML;
    my $devcap_data = BBBikeYAML::LoadFile("$FindBin::RealBin/misc/garmin_devcap.yaml");
    my $t = $main::top->Toplevel(-title => 'Garmin devices');
    my $lb = $t->Scrolled('Listbox', -scrollbars => 'osoe', -selectmode => 'single')->pack(qw(-fill both -expand 1));
    my @prod_id_list = do {
	no warnings 'uninitialized', 'numeric';
	# younger devices (by release_date or with larger product ids) first
	sort { $devcap_data->{$b}->{release_date} cmp $devcap_data->{$a}->{release_date} || $b <=> $a } keys %$devcap_data;
    };
    my @data;
    for my $prod_id (@prod_id_list) {
	my $name = $devcap_data->{$prod_id}->{name};
	push @data, [$name, $prod_id];
	$lb->insert('end', $name);
    }
    my $f = $t->Frame->pack(qw(-fill x));
    $f->Button(-text => 'Use device',
	       -command => sub {
		   my($sel) = $lb->curselection;
		   if (!defined $sel) {
		       main::status_message('Please select a device', 'err');
		       return;
		   }
		   my $device_data = $devcap_data->{$data[$sel]->[1]};
		   for my $def (['wpts_in_route',       \$main::gps_waypoints],
				['wpt_length',          \$main::gps_waypointlength],
				['wpt_charset',         \$main::gps_waypointcharset],
				['unique_route_number', \$main::gps_needuniqueroutenumber],
			       ) {
		       my($data_key, $ref) = @$def;
		       if (exists $device_data->{$data_key}) {
			   $$ref = $device_data->{$data_key};
		       }
		   }
	       })->pack(qw(-side left));
    $f->Button(-text => 'Cancel',
	       -command => sub {
		   $t->destroy;
	       })->pack(qw(-side left));
}

sub upload_waypoint_by_coordinates {
    if (!defined &WaypointUploader::upload_waypoint) {
	main::status_message("Requires WaypointUploader plugin to be loaded", "die");
    }
    my $t = $main::top->Toplevel(-title => "Upload Waypoint");
    $t->transient($main::top) if $main::transient;
    my $f1 = $t->Frame->pack;
    $f1->Label(-text => "OSM Map URL")->pack(-side => 'left');
    my $e = $f1->Entry(-textvariable => \my $url)->pack(-side => 'left');
    $e->focus;
    my $f2 = $t->Frame->pack;
    $f2->Button(-text => "Continue",
		-command => sub {
		    if ($url =~ m{map=\d+/(-?[\d.]+)/(-?[\d.]+)}) {
			my $py = $1;
			my $px = $2;
			WaypointUploader::upload_waypoint(px => $px, py => $py);
			$t->destroy;
		    } else {
			main::status_message("Cannot parse URL '$url' as a OSM map URL", "error");
		    }
		})->pack(qw(-side left));
}

######################################################################
# Winter optimization
sub do_winter_optimization {
    my($winter_hardness) = @_;
    if (!defined $winter_hardness) {
	delete $main::penalty_subs{'winteroptimization'};
    } else {
	# XXX Taken from bbbike.cgi and changed slightly
	require JSON::XS;
	my $penalty;
	for my $try (1 .. 2) {
	    for my $dir ("$bbbike_rootdir/tmp", @Strassen::datadirs) {
		my $f = "$dir/winter_optimization.$winter_hardness.json";
		if (-r $f && -s $f) {
		    my $uptodate = 1;
		    for my $check (qw(strassen brunnels qualitaet_s radwege_exact comments_kfzverkehr comments_tram)) {
			if (-M $f > -M "$bbbike_rootdir/data/$check") {
			    main::status_message("$f is not up-to-date wrt $check, need to rebuild...", "info");
			    $uptodate = 0;
			    last;
			}
		    }
		    if ($uptodate) {
			my $json = do { open my $fh, $f or die $!; local $/; <$fh> };
			$penalty = JSON::XS->new->decode($json);
			#$penalty = Storable::retrieve($f);
			last;
		    }
		}
	    }
	    if (!$penalty) {
		if ($try == 2) {
		    die "Can't find winter_optimization.$winter_hardness.json in @Strassen::datadirs and cannot build...";
		} else {
		    main::status_message("Rebuilding winter optimization files for $winter_hardness...", "info");
		    my @cmd = ($^X, "$bbbike_rootdir/miscsrc/winter_optimization.pl", "-as-json", "-winter-hardness", $winter_hardness, "-one-instance");
		    main::IncBusy($main::top);
		    eval {
			system @cmd;
			if ($? != 0) {
			    die "The command <@cmd> failed";
			}
		    };
		    my $err = $@;
		    main::DecBusy($main::top);
		    if ($err) {
			# Reset everything
			delete $main::penalty_subs{'winteroptimization'};
			$want_winter_optimization = '';
			main::status_message($err, "die");
		    } else {
			main::status_message("... done", "info");
		    }
		}
	    } else {
		last;
	    }
	}

	my $koeff = 1;
##XXX implement?
# 	if ($q->param('pref_winter') eq 'WI1') {
# 	    $koeff = 0.5;
# 	}

	$main::penalty_subs{'winteroptimization'} = sub {
	    my($pen, $next_node, $last_node) = @_;
	    if (exists $penalty->{$last_node.",".$next_node}) {
		my $this_penalty = $penalty->{$last_node.",".$next_node};
		$this_penalty = $koeff * $this_penalty + (100-$koeff*100)
		    if $koeff != 1;
		if ($this_penalty < 1) {
		    $this_penalty = 1;
		}		# avoid div by zero or negative values
		$pen *= (100 / $this_penalty);
	    }
	    $pen;
	};
    }
}

use vars qw($fragezeichen_on_route_nextcheck_only $fragezeichen_on_route_printer_needs_utf8 $fragezeichen_on_route_two_column);
$fragezeichen_on_route_nextcheck_only = 1;
$fragezeichen_on_route_printer_needs_utf8 = 1;
$fragezeichen_on_route_two_column = 0;
sub fragezeichen_on_route {
    eval {
	require File::Temp;
	require Route;
	require Route::Heavy;
	my($tmp1fh,$tmp1file) = File::Temp::tempfile(SUFFIX => ".bbr", UNLINK => 1) or die $!;
	my($tmp2fh,$tmp2file) = File::Temp::tempfile(SUFFIX => ".bbd", UNLINK => 1) or die $!;
	main::load_save_route(1, $tmp1file);
	my $s = Route::as_strassen($tmp1file,
				   name => 'Route',
				   cat => 'X',
				   fuzzy => 0,
				  );
	if (!$s) {
	    die "$tmp1file l�sst sich nicht konvertieren";
	}
	$s->write($tmp2file);

	my $cmdline = "$bbbike_rootdir/miscsrc/fragezeichen_on_route.pl" .
	    ($fragezeichen_on_route_nextcheck_only ? " -nextcheck-only" : "") .
	    ($fragezeichen_on_route_two_column ? " -two-column" : "") .
	    " $tmp2file";
	my $res = `$cmdline`;
	if (!$res) {
	    die "Cannot get any fragezeichen on route (using $cmdline)";
	}

	unlink $tmp1file;
	unlink $tmp2file;
    
	my $token = 'fragezeichen_on_route';
	my $t = main::redisplay_top($main::top, $token, -title => 'Fragezeichen on route');
	if (!$t) {
	    $t = $main::toplevel{$token};
	    $_->destroy for ($t->children);
	}
	my $txt = $t->Scrolled('ROText', -font => $main::font{'fixed'}, -scrollbars => "ose")->pack(qw(-fill both -expand 1));
	$txt->insert("end", $res);
	my $bf = $t->Frame->pack(-fill => 'x');
	$bf->Button(-text => "Print",
		    -command => sub {
			open my $ofh, "|-", "lpr" or die $!;
			if ($fragezeichen_on_route_printer_needs_utf8) {
			    binmode $ofh, ':utf8';
			}
			print $ofh $res;
			close $ofh or die $!;
			main::status_message("Sent to printer", "infodlg");
		    })->pack(-side => "left");
	$bf->Checkbutton(-text => 'nextcheck only',
			 -variable => \$fragezeichen_on_route_nextcheck_only,
			 -command => sub { fragezeichen_on_route() },
			)->pack(-side => 'left');
	$bf->Checkbutton(-text => 'two column layout',
			 -variable => \$fragezeichen_on_route_two_column,
			 -command => sub { fragezeichen_on_route() },
			)->pack(-side => 'left');
	$bf->Checkbutton(-text => 'printer needs utf-8',
			 -variable => \$fragezeichen_on_route_printer_needs_utf8,
			)->pack(-side => 'left');
    };
    if ($@) {
	main::status_message("An error happened: $@", "error");
    }
}

sub multi_page_pdf {
    my(@extra_args) = @_;
    eval {
	require File::Temp;
	require BBBikeProcUtil;
	my($tmp1fh,$tmp1file) = File::Temp::tempfile(SUFFIX => ".bbr", UNLINK => 1) or die $!;
	main::load_save_route(1, $tmp1file);
	my @cmd = ("$bbbike_rootdir/miscsrc/split-route-bboxes.pl", $tmp1file, "-view", @extra_args);
	warn "Run <@cmd>...\n" if $main::verbose;
	BBBikeProcUtil::double_forked_exec(@cmd);
    };
    if ($@) {
	main::status_message("An error happened: $@", "error");
    }
}

{
    my $hi_scale = 10000;
    my $lo_scale = 20000;

    sub multi_page_pdf_dialog {
	require Tk::LogScale;
	my $t = $main::top->Toplevel(-title => 'Multi PDF settings');
	$t->transient($main::top) if $main::transient;
	Tk::grid($t->Label(-text => 'Hi scale 1:'),
		 $t->LogScale(-variable => \$hi_scale,
			      -from => 1000, -to => 3_000_000, -resolution => 0.01,
			      -command => sub {
				  if ($hi_scale > $lo_scale) {
				      $lo_scale = $hi_scale;
				  }
			      },
			     ));
	Tk::grid($t->Label(-text => 'Lo scale 1:'),
		 $t->LogScale(-variable => \$lo_scale,
			      -from => 1000, -to => 3_000_000, -resolution => 0.01,
			      -command => sub {
				  if ($lo_scale < $hi_scale) {
				      $hi_scale = $lo_scale;
				  }
			      },
			     ));
	Tk::grid($t->Button(-text => 'Run',
			    -command => sub {
				multi_page_pdf(
					       '--hi-scale' => $hi_scale,
					       '--lo-scale' => $lo_scale,
					      );
				$t->afterIdle(sub { $t->destroy });
			    }),
		 $t->Button(-text => 'Cancel',
			    -command => sub {
				$t->afterIdle(sub { $t->destroy });
			    }));
    }
}

use vars qw($WIDGETDUMP_W);
sub _get_tk_widgetdump {
    if (Tk::Exists($WIDGETDUMP_W)) {
	return $WIDGETDUMP_W;
    }
    require Tk::WidgetDump;
    Tk::WidgetDump->VERSION('1.38_51');
    $WIDGETDUMP_W = $main::top->WidgetDump;
    $WIDGETDUMP_W->iconify;
    $WIDGETDUMP_W;
}

######################################################################
# -> mapnik
sub render_mapnik_map {
    my(%args) = @_;
    my $mapfile = delete $args{-mapfile};
    my $special = delete $args{-special};
    die "Unhandled parameters: " . join(" ", %args) if %args;

    my($px0,$py0,$px1,$py1) = main::get_current_bbox_as_wgs84();

    my $mapnik_bbbike_dir = get_mapnik_map_directory();
    return if !$mapnik_bbbike_dir;
    my $renderer = "$mapnik_bbbike_dir/tools/renderer.py";

    my $bbox_arg = "--bbox=$px0,$py0,$px1,$py1";

    if ($special) {
	require File::Temp;
	require BBBikeUtil;
	for my $utility (qw(convert display)) {
	    if (!BBBikeUtil::is_in_path($utility)) {
		main::status_message("ImageMagick utility '$utility' not available", 'error');
		return;
	    }
	}

	if ($special eq 'current-layers') {
	    my @available_layers = (
				    # mapfile                 checkbutton variable
				    ['bbbike'              => \$main::str_draw{'s'}],
				    ['bbbike-smoothness'   => \$main::str_draw{'qs'}],
				    ['bbbike-handicap'     => \$main::str_draw{'hs'}],
				    ['bbbike-green'        => \$main::str_draw{'gr'}],
				    ['bbbike-unlit'        => \$main::str_draw{'nl'}],
				    ['bbbike-unknown'      => \$main::str_draw{'fz'}],
				    ['bbbike-cycleway'     => \$main::str_draw{'rw'}],
				    ['bbbike-cycle-routes' => \$main::str_draw{'comm-route'}],
				   );
	    my @active_layers;
	    for my $layer_def (@available_layers) {
		my($mapfile, $varref) = @$layer_def;
		if ($$varref) {
		    my($tmpfh,$tmpfile) = File::Temp::tempfile(SUFFIX => '_' . $mapfile . '_mapnik.png', UNLINK => 1);
		    push @active_layers, [$mapfile, $tmpfile];
		}
	    }
	    if (!@active_layers) {
		main::status_message('No layers available for drawing', 'warn');
		return;
	    }

	    my($combinefh,$combinefile) = File::Temp::tempfile(SUFFIX => '_combine_mapnik.png', UNLINK => 1);

	    my @outfiles;
	    for my $layer_def (@active_layers) {
		my($mapfile, $outfile) = @$layer_def;
		my @cmd = ($renderer, "--mapfile=$mapfile", "--outfile=$outfile", $bbox_arg);
		warn "@cmd ...\n" if $main::verbose;
		system @cmd;
		main::status_message("Command '@cmd' failed", 'die') if $? != 0;
		push @outfiles, $outfile;
	    }

	    my @montagecmd = ('convert', @outfiles, '-flatten', $combinefile);
	    warn "@montagecmd ...\n" if $main::verbose;
	    system @montagecmd;
	    main::status_message("Command '@montagecmd' failed", 'die') if $? != 0;

	    my @displaycmd = ('display', $combinefile);
	    BBBikeProcUtil::double_forked_exec(@displaycmd);
	    unlink $_ for @outfiles; # cannot delete $combinefile yet
	} else {
	    die "Invalid value for -special '$special'";
	}
    } else {
	my @cmd = ($renderer, ($mapfile ? "--mapfile=$mapfile" : ()), '--view', $bbox_arg);
	BBBikeProcUtil::double_forked_exec(@cmd);
    }
}

sub update_mapnik_map_data {
    my(%opts) = @_;
    my $experimental = delete $opts{experimental};
    die "Unhandled options: " . join(" ", %opts) if %opts;

    my $mapnik_bbbike_dir = get_mapnik_map_directory();
    return if !$mapnik_bbbike_dir;
    my $tools_dir = "$mapnik_bbbike_dir/tools";
    require BBBikeUtil;
    my $save_pwd = BBBikeUtil::save_pwd2();
    chdir $tools_dir
	or main::status_message("Can't chdir to $tools_dir: $!", 'die');
    my @cmd = ('make', ($experimental ? 'experimental' : 'bbbike2wgs84-mapnik'), 'import-postgres');
    main::IncBusy($main::top);
    system @cmd;
    my $exit_code = $?;
    main::DecBusy($main::top);
    if ($exit_code != 0) {
	main::status_message("Error running '@cmd'", 'die');
    } else {
	main::status_message('Update done', 'info');
    }
}

sub get_mapnik_map_directory {
    my $dir = "$bbbike_rootdir/../mapnik-bbbike";
    if (!-x $dir) {
	require File::Basename;
	main::status_message("Mapnik project '$dir' not available --- please run 'git clone https://github.com/eserte/mapnik-bbbike.git' in " . File::Basename::dirname($bbbike_rootdir) . " and follow the instructions in mapnik-bbbike/tools/Makefile", 'error');
	return;
    }
    return $dir;
}

######################################################################

sub show_diffs_since_last_deployment {
    require File::Temp;
    require IPC::Run;
    require BBBikeUtil;

    my $tag = 'deployment/bbbikede/current';

    my @cvsdiffbbd_cmd = ($^X, 'miscsrc/cvsdiffbbd');
    my @temp_blockings_tasks_cmd = ($^X, 'miscsrc/temp_blockings_tasks');
    my $bbbike_temp_blockings_bbd = 'tmp/bbbike-temp-blockings.bbd';

    my $save_pwd = BBBikeUtil::save_pwd2();
    chdir $bbbike_rootdir
	or main::status_message("Can't chdir to $bbbike_rootdir: $!", 'die');

    # read relevant bbd files from data/.modified (further filtering
    # may happen in cvsdiffbbd itself)
    my @files = do {
	my @files;
	open my $modfh, "data/.modified"
	    or main::status_message("Can't open data/.modified: $!", 'die');
	while(<$modfh>) {
	    chomp;
	    my($file) = split /\s+/;
	    next if $file =~ m{^data/sehenswuerdigkeit_img/};
	    next if $file =~ m{^data/*.\.coords\.data$};
	    push @files, $file;
	}
	@files;
    };

    my($tmpfh,$tmpfile) = File::Temp::tempfile('bbbike_since_tag_XXXXXXXX', SUFFIX => '.bbd', TMPDIR => 1, UNLINK => 1);

    IPC::Run::run(['git', 'diff', $tag, '--', @files], '|', [@cvsdiffbbd_cmd, '--title=BBBike diff since last deployment', '--add-file-label', '--diff-file=-'], '>', $tmpfile)
	    or main::status_message("Creation of diff bbd file '$tmpfile' using 'git diff' and '@cvsdiffbbd_cmd' failed", 'die');

    # Create only if missing. XXX Creating is somewhat dangerous, as
    # there could already a "make" job be running in the background,
    # and currently it's not possible to run multiple makes in
    # parallel without the possibility of damaging files.
    if (! -e $bbbike_temp_blockings_bbd) {
	my $save_pwd2 = BBBikeUtil::save_pwd2();
	chdir 'data'
	    or main::status_message("Can't chdir to data: $!", 'die');
	system('make', '../' . $bbbike_temp_blockings_bbd);
	if (! -e $bbbike_temp_blockings_bbd) {
	    main::status_message("Could not create '$bbbike_temp_blockings_bbd' (make failed?)", 'die');
	}
    }
    IPC::Run::run(
		  ['git', 'show', "$tag:data/temp_blockings/bbbike-temp-blockings.pl"], '|',
		  [@temp_blockings_tasks_cmd, 'pl_to_yml', '/dev/stdin', '/dev/stdout'], '|',
		  [@temp_blockings_tasks_cmd, 'yml_to_bbd', '--basedir', "$main::datadir/temp_blockings", '/dev/stdin'], '|',
		  ['sh', '-c', "diff -u - $bbbike_temp_blockings_bbd || true"], '|', # XXX ugly hack, because diff would exit with a non-zero status, making the whole IPC::Run::run looking like a failure
		  [@cvsdiffbbd_cmd, '--add-fixed-label=bbbike-temp-blockings: ', '--diff-file=-'],
		  '>>', $tmpfile
		 )
	    or main::status_message("Adding bbbike-temp-blockings diffs to '$tmpfile' using git, '@temp_blockings_tasks_cmd', '@cvsdiffbbd_cmd' failed", 'die');

    my $layer = add_new_layer('str', $tmpfile);

    my $t = main::choose_ort("str", $layer, -ondestroy => sub {
				 my $t = shift;
				 main::delete_layer($layer);
				 $t->destroy; # no need to withdraw
			     });
    $t->geometry("600x200");
}

######################################################################
# Mapillary tracks

sub select_and_show_mapillary_tracks {
    require Tk::DateEntry;
    require POSIX;
    my $t = $main::top->Toplevel(-title => "Select Mapillary tracks");
    $t->transient($main::top) if $main::transient;
    my $date_since = POSIX::strftime("%Y-%m-%d", localtime);
    my $date_until = POSIX::strftime("%Y-%m-%d", localtime);
    my $bbox = 'berlin';
    {
	my $f = $t->Frame->pack(-fill => 'x', -anchor => 'w');
	$f->Label(-text => 'Since:')->pack(-side => 'left');
	$f->DateEntry
	    (-dateformat => 2,
	     -todaybackground => "yellow",
	     -weekstart => 1,
	     -daynames => 'locale',
	     -textvariable => \$date_since,
	     -formatcmd => sub {
		 my($year,$month,$day) = @_;
		 sprintf "%04d-%02d-%02d", $year, $month, $day;
	     },
	    )->pack(-side => 'left');
    }
    {
	my $f = $t->Frame->pack(-fill => 'x', -anchor => 'w');
	$f->Label(-text => 'Until:')->pack(-side => 'left');
	$f->DateEntry
	    (-dateformat => 2,
	     -todaybackground => "yellow",
	     -weekstart => 1,
	     -daynames => 'locale',
	     -textvariable => \$date_until,
	     -formatcmd => sub {
		 my($year,$month,$day) = @_;
		 sprintf "%04d-%02d-%02d", $year, $month, $day;
	     },
	    )->pack(-side => 'left');
    }
    {
	my $f = $t->Frame(-borderwidth => 1, -relief => 'solid')->pack(-fill => 'x', -anchor => 'w', -padx => 1, -pady => 1);
	$f->Label(-text => 'Bbox:')->pack(-anchor => 'w');
	$f->Radiobutton(-text => 'Berlin', -value => 'berlin', -variable => \$bbox)->pack(-anchor => 'w');
	$f->Radiobutton(-text => 'Current region', -value => 'current-region', -variable => \$bbox)->pack(-anchor => 'w');
    }

    $t->Button(-text => 'Show',
	       -command => sub {
		   show_mapillary_tracks(-since => $date_since, -until => $date_until, -bbox => $bbox);
		   $t->destroy;
	       },
	      )->pack;
}

sub show_mapillary_tracks {
    my(%args) = @_;
    my $since = delete $args{-since};
    my $until = delete $args{-until};
    my $bbox = delete $args{-bbox} || 'berlin';
    die "Unhandled arguments: " . join(" ", %args) if %args;

    require Strassen::Mapillary;
    require File::Temp;
    require Geography::Berlin_DE;
    
    my @bbox;
    if ($bbox eq 'berlin') {
	@bbox = @{ Geography::Berlin_DE->new->bbox_wgs84 };
    } elsif ($bbox eq 'current-region') {
	@bbox = main::get_current_bbox_as_wgs84();
    } else {
	die "Unexpected value for \$bbox: '$bbox'";
    }

    my $sm = Strassen::Mapillary->new;
    $sm->fetch_sequences(
			 {
			  bbox => \@bbox,
			  ($since ? (start_time => $since) : ()),
			  ($until ? (end_time   => $until) : ()),
			 },
			 {
			  verbose => 1,
			  msgs => \my @msgs,
			 }
			);

    my(undef, $tmpfile) = File::Temp::tempfile(UNLINK => 1, SUFFIX => ($since ? "_$since" : "") . "_mapillary.bbd");
    $sm->write($tmpfile);

    plot_and_choose_mapillary_tracks($tmpfile);
}

sub plot_and_choose_mapillary_tracks {
    my($bbdfile) = @_;

    my $done = load_mapillary_done_file();
    my %new_done;

    my $layer = main::plot_additional_layer("str", $bbdfile, -temporaryfile => 1);

    my $token = 'mapillary-show';
    my $t = main::redisplay_top($main::top, $token, -title => 'Mapillary tracks');
    if (!$t) {
	$t = $main::toplevel{$token};
	$_->destroy for ($t->children);
    } else {
	$t->geometry('340x200');
    }
    $t->OnDestroy(sub {
		      main::delete_layer($layer);
		  });

    my $f;
    my $hide_seen;
    {
	my $ff = $t->Frame->pack(-fill => 'x');
	$ff->Checkbutton(-text => "Hide seen",
			 -variable => \$hide_seen,
			 -command => sub {
			     my $hl = $f->Subwidget("Listbox");
			     if ($hide_seen) {
				 for ($hl->info("children")) {
				     if ($hl->itemCget($_, 1, "-text") =~ /\x{2714}/) {
					 $hl->hide("entry", $_);
				     }
				 }
			     } else {
				 for ($hl->info("children")) {
				     $hl->show("entry", $_);
				 }
			     }
			 })->pack(-anchor => "w", -side => 'left');
	$ff->Button(-text => "Mark done",
		    -command => sub {
			my $ans = $t->messageBox(-message => "Mark all mapillary tracks as done?",
						 -type => "YesNo",
						 -icon => 'question',
						);
			if ($ans =~ m{yes}i) {
			    for my $new_done (keys %new_done) {
				$done->{$new_done} = 1;
			    }
			    save_mapillary_done_file($done);
			    $t->destroy;
			}
		    })->pack(-anchor => 'e', -side => 'right');
    }
    $f = $t->Frame->pack(-fill => "both", -expand => 1);

    main::choose_ort("str", $layer,
		     -splitter => sub {
			 my($line) = @_;
			 my $seen = $done->{$line} ? "\x{2714}" : " ";
			 $new_done{$line} = 1;
			 ($line, $seen);
		     },
		     -columnwidths => [310,30],
		     -container => $f,
		     -showcenter => 'begin',
		     -ondestroy => sub { $t->destroy },
		    );
}

# The "done" files for mapillary tracks
use vars qw($mapillary_done_file);
$mapillary_done_file = do {
    no warnings 'once';
    "$main::bbbike_configdir/mapillary_done";
};

sub load_mapillary_done_file {
    my %done;
    if (-r $mapillary_done_file) {
	open my $fh, $mapillary_done_file
	    or main::status_message("Cannot load existing file $mapillary_done_file: $!", "die");
	while(<$fh>) {
	    chomp;
	    $done{$_} = 1;
	}
    } else {
	warn "INFO: $mapillary_done_file does not exist yet\n";
    }
    \%done;
}

sub save_mapillary_done_file {
    my($done_ref) = @_;
    open my $ofh, ">", "$mapillary_done_file~"
	or main::status_message("Cannot write to $mapillary_done_file~: $!", "die");
    for my $done (sort keys %$done_ref) {
	print $ofh "$done\n";
    }
    close $ofh
	or main::status_message("Error while closing $mapillary_done_file~: $!", "die");
    rename "$mapillary_done_file~", $mapillary_done_file
	or main::status_message("Error while renaming $mapillary_done_file~ to $mapillary_done_file: $!", "die");
}

######################################################################

sub todays_gps_tracks {
    require BBBikeGPS;

    my $gpsdatadir = "$bbbike_rootdir/misc/gps_data";
    my(@l) = localtime;
    my $yyyy = sprintf "%04d", $l[5]+1900;
    my $mm   = sprintf "%02d", $l[4]+1;
    my $dd   = sprintf "%02d", $l[3];

    my @files;
    my $current_gpx = "$ENV{HOME}/trash/Current.gpx";
    if (-e $current_gpx) {
	my $age_in_days = (time - (stat($current_gpx))[9]) / 86400;
	if ($age_in_days  < 1) {
	    push @files, $current_gpx;
	}
    }
    push @files, glob("$gpsdatadir/$yyyy$mm$dd.{trk,wpt}");
    push @files, glob("$gpsdatadir/*/$yyyy$mm$dd.{trk,wpt}");
    push @files, glob("$gpsdatadir/*/$yyyy-$mm-$dd*.{trk,wpt}");
    @files = grep { -f $_ && -r $_ && -s $_ } @files;
    if (!@files) {
	main::status_message("No GPS files found for date $yyyy-$mm-$dd", "infodlg");
	return;
    }

    warn "INFO: Found files: @files\n";
    my $file_i = 0;
    my %plotted_layer_info;
    tie %plotted_layer_info, 'Tie::IxHash' if eval { require Tie::IxHash; 1 };
    for my $file (@files) {
	BBBikeGPS::do_draw_gpsman_data($main::top, $file,
				       -drawtypeauto => 1,
				       -plottedlayerinfo => \%plotted_layer_info,
				       ($file_i == 0 ? (-centerbegin => 1) : ()),
				      );
	$file_i++;
    }
## XXX does not work
#    for my $abk (sort keys %plotted_layer_info) {
#	if ($abk =~ /^p-/) {
#	    main::set_in_stack($abk, 'above', 's-BAB');
#	} else {
#	    main::set_in_stack($abk, 'below', 's-NN');
#	}
#    }
}

######################################################################

sub center_garmin_device_position {
    require GPS::BBBikeGPS::MountedDevice;
    require Strassen::GPX;
    GPS::BBBikeGPS::MountedDevice->maybe_mount
	    (sub {
		 my $dir = shift;
		 my $pos_file = "$dir/Garmin/.Position.gpx";
		 if (!-r $pos_file) {
		     main::status_message("File $pos_file not available", "error");
		     return;
		 }
		 my $s = Strassen::GPX->new;
		 $s->gpx2bbd($pos_file);
		 $s->init;
		 my $r = $s->next;
		 my $sxy = $r->[Strassen::COORDS()]->[0];
		 main::status_message("Found coordinate in $pos_file: bbbike coordinates $sxy", "info");
		 main::mark_point(-coords => [[[ main::transpose(split /,/, $sxy) ]]],
				  -clever_center => 1,
				  -inactive => 1,
				 );
	     });
}

######################################################################

sub visvalingam_whyatt {
    require VectorUtil;
    require Storable;

    my($in_points_ref, $stop) = @_;
    my @out_points = @{ Storable::dclone($in_points_ref) };

    my $get_size_func;
    if (ref $stop->[0] eq 'CODE') {
	$get_size_func = $stop->[0];
    } elsif ($stop->[0] eq 'strlen') {
	# assumes a one-byte separator between x and y and one-byte separator between points
	require List::Util;
	$get_size_func = sub {
	    my $points_ref = shift;
	    (List::Util::sum(map { length($_->{x}) + length($_->{y}) + 1 } @$points_ref) + @$points_ref - 1);
	};
    } elsif ($stop->[0] eq 'elements') {
	$get_size_func = sub {
	    my $points_ref = shift;
	    scalar @$points_ref;
	};
    } else {
	die "Unhandled stop function $stop->[0]";
    }
    my $max_size = $stop->[1];

    my $calc_area = sub {
	my($i) = @_;
	$out_points[$i]->{area} = VectorUtil::triangle_area(
							    [@{$out_points[$i-1]}{qw(x y)}],
							    [@{$out_points[$i  ]}{qw(x y)}],
							    [@{$out_points[$i+1]}{qw(x y)}],
							   );
    };

    if ($get_size_func->(\@out_points) > $max_size && @out_points > 2) {

	for my $i (1 .. $#out_points-1) {
	    $calc_area->($i);
	}

	while (@out_points > 2) {
	    my($min_area, $min_area_inx);
	    for my $i (1 .. $#out_points-1) {
		if (!defined $min_area || $min_area > $out_points[$i]->{area}) {
		    $min_area = $out_points[$i]->{area};
		    $min_area_inx = $i;
		}
	    }
	    splice @out_points, $min_area_inx, 1;
	    if ($min_area_inx-1 > 0) {
		$calc_area->($min_area_inx-1)
	    }
	    if ($min_area_inx < $#out_points) {
		$calc_area->($min_area_inx);
	    }
	    my $current_size = $get_size_func->(\@out_points);
	    if ($current_size <= $max_size) {
		last;
	    }
	}
    }
    return \@out_points;
}
    
######################################################################
sub _generate_date_range_regex {
    my($last_days) = @_;

    require Time::Piece;
    require Regexp::Assemble;

    my $current_date = Time::Piece->new;
    my $some_days_ago = $current_date - $last_days * 24 * 60 * 60;

    my $start_date = $some_days_ago->ymd;
    my $end_date   = $current_date->ymd;

    my $ra = Regexp::Assemble->new;

    my $tp_start = Time::Piece->strptime($start_date, '%Y-%m-%d');
    my $tp_end = Time::Piece->strptime($end_date, '%Y-%m-%d');

    while ($tp_start <= $tp_end) {
        my $date_str = $tp_start->ymd('-');
        $ra->add(quotemeta($date_str), 's');
        $ra->add(quotemeta($tp_start->ymd('')), 's'); # Date without dashes
        $tp_start += 24 * 60 * 60; # Incrementing by 1 day
    }

    my $regexp_pattern = '^' . $ra->re;
    $regexp_pattern;
}

######################################################################

sub fetch_fis_broker_wms_map {
    my($px0,$py0,$px1,$py1) = main::get_current_bbox_as_wgs84();
    ($py0,$py1)=($py1,$py0) if $py0 > $py1;
    my($w,$h) = ($main::c->width, $main::c->height);
    require LWP::UserAgent;
    #require MIME::Base64;
    require File::Temp;
    my $origfile = File::Temp->new(SUFFIX => '.png', TMPDIR => 1);
    my $ua = LWP::UserAgent->new;
    my $layer = 'k_radverkehrsnetz';
    my $url = 'https://fbinter.stadt-berlin.de/fb/wms/senstadt/k_radverkehrsnetz?service=WMS&request=GetMap&version=1.3.0&bbox='.$py0.','.$px0.','.$py1.','.$px1.'&width='.$w.'&height='.$h.'&format=image/png&layers='.$layer.'&styles=gdi_default&crs=EPSG:4326&transparent=true';
    warn "Fetch $url...\n";
    # XXX For some reason fetching does not work with LWP. Use Net::Curl instead.
    my $resp = _lwp_get_with_curl($ua, $url);
    if (!$resp->is_success || $resp->content_type ne 'image/png') {
	warn "Request:\n" . $resp->request->dump;
	warn "Response:\n" . $resp->dump;
	main::status_message('Fetching image from WMS failed, please see STDERR for details', 'die');
    }
    open my $ofh, '>', $origfile or die $!;
    binmode $ofh;
    print $ofh $resp->content;
    $ofh->close or die $!;

    # XXX somehow coordinates to not fit, try to rotate a little bit
    my $rotfile = File::Temp->new(SUFFIX => '.png', TMPDIR => 1);
    my @cmd = ('convert', $origfile, '-distort', 'SRT', '-2.3', $rotfile);
    system @cmd;
    if ($? != 0) { die "Command @cmd failed" }

    my $img = $main::c->Photo(-file => "$rotfile", -format => 'png');
    my($x0,$y0) = $main::c->get_corners;
    $main::c->createImage($x0,$y0,-image=>$img,-anchor=>'nw',-tags=>['map-ovl']);
    # XXX original map position is low, but in this case it is an overlay, so it should be raised
    #main::restack_delayed();
    $main::c->raise('map-ovl');
}

sub _lwp_get_with_curl {
    my($ua, $url, @fields) = @_;
    if (!$INC{'LWP/Protocol/Net/Curl.pm'}) {
	warn "Need to load LWP::Protocol::Net::Curl...\n";
	require LWP::Protocol::Net::Curl;
	LWP::Protocol::Net::Curl->import(takeover => 0);
    }
    my @schemes = qw(http https);
    my %orig_implementor;
    $orig_implementor{$_} = LWP::Protocol::implementor($_) for @schemes;
    LWP::Protocol::implementor($_ => 'LWP::Protocol::Net::Curl') for @schemes;
    my $resp = eval { $ua->get($url, @fields) };
    my $err = $@;
    LWP::Protocol::implementor($_ => $orig_implementor{$_}) for @schemes;
    if ($err) {
	die $err;
    }
    $resp;
}

######################################################################

1;

__END__
