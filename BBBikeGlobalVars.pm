# -*- perl -*-

#
# $Id: BBBikeGlobalVars.pm,v 1.39 2006/08/19 20:08:38 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeGlobalVars;

use vars qw($VERSION);
$VERSION = sprintf("%d.%03d", q$Revision: 1.39 $ =~ /(\d+)\.(\d+)/);

package main;

use strict;

use vars
  qw($bbbike_context $splash_screen $booting $status_message_dialog
     $coords_ref $realcoords_ref $search_route_points_ref @realcoords
     $VERSION $PROG_REVISION $tmpdir %tmpfiles $progname
     $os $os_bsd $use_clipboard $verbose $advanced $devel_host $public_test
     $datadir $no_original_datadir $city $country
     $top %toplevel %processes $transient $c $sx $sy $top_dpi $top_dpmm @want_extends %autouse_func
     $small_icons $is_handheld
     @scrollregion $init_scrollregion $normal_scrollregion $scrollre
     $K2Listbox
     $dataset %str_obj %str_cache_attr %p_obj $net $no_make_net
     %str_file %p_file $koord %ampeln %hoehe %custom_net_str
     %sperre %sperre_tragen %sperre_narrowpassage $sperre_file $use_faehre
     $do_activate_temp_blockings $show_active_temp_blockings
     $coord_system $coord_system_obj $scale_coeff $scale %scalecommand
     $default_img_fmt $register_window_adjust
     $ampel_count $kopfstein_count $ampel_count_button $kopfstein_count_button
    );

# Photos
use vars qw(
     $ampel_photo $ampelf_photo $ampel_klein_photo $ampelf_klein_photo
     $ampel_klein2_photo $ampelf_klein2_photo
     $ampel_klein_grey_photo $zugbruecke_photo $zugbruecke_klein_photo
     $kopfstein_klein_photo $kopfstein_klein_grey_photo
     $vorfahrt_photo $vorfahrt_klein_photo
     $andreaskr_photo $andreaskr_klein_photo $andreaskr_klein2_photo
     %obst_photo
     $windrose2_photo $usercross_photo
     $strasse_photo $landstrasse_photo $ort_photo $hs_photo
     $ubahn_photo $sbahn_photo $rbahn_photo $wasser_photo $flaechen_photo
     $kneipen_photo $kneipen_klein_photo
     $essen_photo $essen_klein_photo $kino_klein_photo
     $search_photo $search_pref_photo $steigung_photo $gefaelle_photo
     $inwork_photo $cal_photo $star_photo $newlayer_photo
     $menuarrow_photo $ferry_photo $ferry_klein_photo $blocked_photo
     %photo
);
use vars qw(
     @wetter_dir $wetter_dir %wetter_zuordnung %wetter_name
     $x11 $special_edit $edit_mode $edit_mode_flag $edit_normal_mode
     $customchoosecmd $b2m_customcmd
     %line_width %line_length %line_dash %category_dash %line_arrow
     $default_line_width %line_shorten
     %category_size %outline_color %category_color %category_stipple
     %str_color %p_color %p_width
     %category_font_color %category_font %category_width %category_image
     %layer_active_color %layer_pre_enter_command %layer_post_enter_command
     %layer_pre_leave_command %layer_post_leave_command
     $crossings $all_outline %str_attrib %p_attrib %category_attrib
     $init_choose_street %init_str_draw %str_draw %occupied_layer
     %init_p_draw %p_draw %str_outline $auto_show_list
     %str_name_draw %str_nr_draw %p_name_draw %str_far_away %p_far_away
     %p_regions %str_regions
     $init_from $init_to $coloring $route_dashed $route_arrowed
     $public $want_wind $winddir $wind
     $wind_v $wind_v_max $winddate
     $bp_obj $ua $proxy
     $orientation $wasserstadt $wasserumland $init_scope %act_value
     $map_draw @route_info
     $palm_doc_format $show_route_start $show_route_ziel @act_search_route
     @speed_txt @power_txt @calories_speed @calories_power
     $route_strname_lbox $show_strlist $show_enter_opt_preferences
     %module_time %module_check $aufschlag
     $plotstr_draw_sub $plotpoint_draw_sub $plotorte_draw_sub $progress
     %lazy_str $lazy_plot @remember_plot_str @remember_plot_p
     @standard_mode_cmd @edit_mode_cmd @edit_mode_b_cmd @edit_mode_brb_cmd
     @edit_mode_standard_cmd
     $map_mode %map_mode_callback $map_mode_deactivate $b2_mode %b2_mode_desc
     %set_route_point %alt_set_route_point $search_stat $search_visual
     $coord_prefix $use_current_coord_prefix %delayed_sub_timer
     %global_search_args %penalty_subs %optprefs $autosave_opts
     $autoscroll_speed $autoscroll_middle
     $do_iconframe %check_sub $right_is_popup
     $environment $use_server $turbo $use_mldbm
     $run_under_kde $kde $exceed
     $use_xwd_if_possible $str_history $nearest_orte
     $standard_menubar $auto_install_cpan $ask_quit $gps_device
     $outline_i
     $without_zoom_factor $coord_output_int
    );
#XXX del:  %wind_dir $wind_dir_from $wind_dir_to $wind 
use vars qw(@speed @power $speed_power_reference_string
	    $wetter_station %wetter_source
	    $wetter_force_update $wetter_route_update
	    $do_route_strnames $do_route_strnames_km
	    $do_route_strnames_compact $do_route_strnames_orte
	    $do_route_strnames_comments $comments_net $comments_pos_net
	    @comments_types %comment_cat_labels);

# Scale of the map (1:$mapscale)
use vars qw($mapscale $default_mapscale);

use vars qw($small_scale $medium_scale $small_scale_edit $medium_scale_edit);
use vars qw($zoomrect_after $showmark_after $bbbike_route_ext);
use vars qw(%active_speed_power);
use vars qw(%str_restrict %str_ignore);
use vars qw(%tag_group);
use vars qw(@route_strnames);
use vars qw($net_type %add_net);
use vars qw($place_category $orte_label_size);
use vars qw(%no_overlap_label %do_outline_text);
use vars qw($overview_canvas $radar_image
	    %overview_draw $show_overview $show_overview_mode);
use vars qw($show_calories);
use vars qw(%choose_ort_cache @mouse_text $flat_relief @route_time
	    @route_distance $use_hoehe $steigung_optimierung
	    $grade_minimum_short $grade_minimum $grade_minimum_short_length
	    $use_legend $use_legend_right $show_legend $show_mouse_help);
use vars qw(%immediate %pending);
use vars qw(%tag_invisible $auto_visible %tag_visibility);
use vars qw(@popup_style $focus_policy
	    $escape $abortWWW
	    $followmouse $followmouse_repeat
	    $map_default_type $use_map_fallback
	    $map_surround $dont_delete_map
	    @special_lower %special_lower @special_raise %special_raise
	    %obst_file);
use vars qw($last_loaded_menu $last_loaded_obj $last_loaded_layers_obj
	    $coord_output $coord_output_sub);
use vars qw($coordlist_lbox $coordlist_lbox_nl);
# $hs_check: checkbutton für Haltestellen
# $plzmcmd: Menüpunkt für PLZ-Auswahl
# $set_mode: evtl. durch $edit_mode ersetzen
use vars qw($hs_check $plzmcmd $ampelstatus_label_text
	    $windrose_button
	    $cache_decider_time $min_cache_decider_time $use_smooth_scroll
	    $use_balloon $use_c_balloon $c_balloon_wait
	    $balloon $c_balloon $leave_after $ch
	    $map_bg $map_color $steady_mark $lowmem $slowcpu
	    $use_contexthelp $use_logo $use_dialog
	    $center_on_str $center_on_coord
	    $center_loaded_route $zoom_loaded_route
	    $zoom_new_route $zoom_new_route_chooseort
	    $set_mode $init_with_edittools
	    $ps_image_res $point_editor $info_text
	    $mark_color $initial_plugins $initial_layers
	    %info_plugins);
use vars qw($export_txt_mode $export_txt_min_angle $gps_waypoints);
use vars qw($www_is_slow $do_www $really_no_www $no_map
	    %save_route $multistrassen
	    @coords @names @rbahn_coords
	    $abbiege_optimierung $abbiege_penalty
	    $ampel_optimierung $lost_strecke_per_ampel
	    %lost_time_per_ampel $average_v $beschleunigung);

use vars qw($qualitaet_s_optimierung %qualitaet_s_speed
	    $qualitaet_s_net);

use vars qw($handicap_s_optimierung %handicap_s_speed
	    $handicap_s_net $temporary_handicap_s);

use vars qw($radwege_optimierung $radwege_net $N_RW_optimization $N_RW_net
	    %radwege_speed $green_optimization $green_net
	    $unlit_streets_optimization $unlit_streets_net
	   );
use vars qw($strcat_optimierung $strcat_net %strcat_speed
	    @strcat_order);
# XXX use curr_selection instead of inslauf_selection some day
use vars qw($steigung_net %steigung_penalty_env $steigung_penalty
	    $curr_selection @inslauf_selection @ext_selection
	    $strecke $dim_color $unit_s
	    $bikepwr @bikepwr_all_time @bikepwr_time @bikepwr_cal
	    $power_cache $next_is_undo
	    %do_flag);
use vars qw(@search_route_points $search_route_flag $in_search
	    $show_grade);
use vars qw(%wetter_full $temperature %wind_colors $stderr $stderr_window
	    $geometry $open_maximized $scaling $visual @max_extends);
### Fonts
use vars qw(%font @font $font_family $fixed_font_family $font_size $font_weight
	    $standard_height $use_font_rot $label_font_size);
### Postscript
use vars qw($ps_rotate $print_cmd $gv_reuse $ps_color $ps_scale_a4 $ps_fixed_font $print_backend);

use vars qw($nr $cache_root $use_wwwcache);
use vars qw($map_img @map_surround_img $do_wwwmap);
use vars qw($bbbike_configdir $bbbike_routedir $oldpath $save2_path);
# $opt: Tk::Getopt object
use vars qw($opt $preload_file @opttable @getopt);
use vars qw(@extra_args);
use vars qw($srtbike_icon $srtbike_photo);
use vars qw($capstyle_round);
use vars qw($rot_font_sub $rot_bold_font_sub);
use vars qw(%category_rot_font);
use vars qw($frame $ctrl_frame);
use vars qw($hs_label $str_label);
use vars qw($misc_frame $misc_frame2 $DockFrame $Checkbutton $Radiobutton);
use vars qw(%flag_photo);
use vars qw($berlin_overview_photo); # wird bei Bedarf nachgeladen
##### Statuszeile/Progress Bar #####
use vars qw($status_label $status_button $status_button_column
	    $edit_mode_type $edit_mode_indicator
	    $indicator_frame);

use vars qw(%cursor %cursor_mask);
use vars qw(%busy_watch_args);
use vars qw($pp_color);
use vars qw($xadd_anchor_type $yadd_anchor_type %label_spaceadd);
use vars qw(@normal_stack_order @set_stack_order);
use vars qw(%perlmod_install_advice_seen
	    %long_url_to_short_url);

use enum qw/:EXPORT_TXT_ FULL SIMPLIFY_NAME SIMPLIFY_ANGLE SIMPLIFY_NAME_OR_ANGLE SIMPLIFY_AUTO/;

use constant DEFAULT_SCALE => 4;
use constant DEFAULT_SMALL_SCALE => 1;
use constant MINMEM        => 28000;

# Map modes
# Please don't change order to stay compatible with tkbabybike
use enum qw(:MM_
	    SEARCH INFO BUTTONPOINT USEREDIT DRAG EDITPOINT
	    SPECIALEDIT INSERTPOINT CREATERELATION
	    CUSTOMCHOOSE CUSTOMCHOOSE_TAG
	    BABYBIKE_SELECT BABYBIKE_BROWSE SCRIBBLE
	    URL_SELECT
	   );

# Button2 modes, order is important because of option saving!
use enum qw(:B2M_
	    NONE DELLAST AUTOSCROLL SCAN FASTSCAN CUSTOM);

# Attribute description field indexes
use enum qw(:ATTRIB_ SINGULAR PLURAL LINES LONG);

1;

__END__

If for some reason I want to switch from "use vars" to "our", then I
may use the following script:

perl -e '$/=undef;open A, "BBBikeGlobalVars.pm" or die; $buf=<A>; $buf =~ s/use vars/our/g; $buf =~ s{qw\((.*?)\)}{"(" . join(",", grep { !/^\s*$/ } split /\s+/, $1) . ")"}ges; print $buf' > BBBikeGlobalVars_with_our.pm

