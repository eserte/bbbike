#!/usr/local/bin/wish8.0 -f
# -*- tcl -*-

#
# $Id: bbbike.tcl,v 1.2 2005/10/27 01:03:49 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Tcl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

source strassen.tcl

set scale 2
set found_paths {}
set visualSearch 0
set inVisualSearch 0

proc transpose {x y} {
    global scale
    return [list [expr int((-200+$x/25)*$scale)] \
	    [expr int((600-$y/25)*$scale)]]
}

proc fillin {} {
    global all_crossings all_crossings_l
    global stage
    global start ziel
    global found_paths found_path_i

    set i [.kreuz.lbox curselection]
    set name [lindex $all_crossings $i]
    set koord_xy [lindex $all_crossings_l $i]
    set koord [coord_as_string $koord_xy]
    if {[string compare $stage start] == 0} {
	set stage ziel
	.sz.start configure -text $name
	set start $koord
    } else {
	set stage start
	set ziel $koord
	.sz.ziel configure -text $name
	set oldcursor [. cget -cursor]
	. configure -cursor watch
	update
	#set found_paths [strassenNetzSearch $start $ziel]
	set found_paths [strassenNetzSearchAstar $start $ziel]
	best_path
	. configure -cursor $oldcursor
    }
}

proc clear_path {} {
    .t.c delete route
}

proc draw_path {route yesno} {
    global inVisualSearch
    if {!$inVisualSearch} {
	clear_path
    }
    set koord {}
    foreach xy $route {
	set txy [transpose [lindex $xy 0] [lindex $xy 1]]
	lappend koord [lindex $txy 0] [lindex $txy 1]
    }
    if {$yesno == 1} {
	set fill red
    } else {
	set fill {#ffe0e0}
    }
    if {[llength $koord] >= 2} {
	eval [concat .t.c create line $koord -fill $fill -width 3 -tags route]
    }
}

proc show_path {route_def} {
    set best_route [lindex $route_def 0]
    .sz.l configure -text [join [list [expr int([lindex $route_def 1])/1000.0] "km"]]
    set route_name [strassenNetzKoordToName $best_route]
    .res.lbox delete 0 end
    foreach elem $route_name {
	.res.lbox insert end $elem
    }
    draw_path $best_route 1
}

proc best_path {} {
    global found_paths found_path_i
    set found_path_i 0
    show_path [lindex $found_paths $found_path_i]
}

proc next_path {} {
    global found_paths found_path_i
    if {$found_paths == ""} {
	return
    }
    incr found_path_i
    if {$found_path_i == [llength $found_paths]} {
	set found_path_i 0
    }
    show_path [lindex $found_paths $found_path_i]
}

proc draw_net {} {
    .t.c delete s
    strassenInit
    while {1} {
	set ret [strassenNext]
	set kreuzungen [lindex $ret 1]
	if {$kreuzungen == ""} {
	    break
	}
	set name [lindex $ret 0]
	set cat [lindex $ret 2]
	set koord {}
	foreach k $kreuzungen {
	    set xy [strassenToKoord1 $k]
	    set txy [transpose [lindex $xy 0] [lindex $xy 1]]
	    lappend koord [lindex $txy 0] [lindex $txy 1]
	}
	if {[llength $koord] >= 4} {
	    set fill white
	    set width 3
	    switch -- $cat {
		HH -
		H {
		    set fill yellow
		    set width 4
		}
		B {
		    set fill red
		    set width 5
		}
		NN {
		    set fill "#c0ffc0"
		    set width 2
		}
	    }
	    eval [concat .t.c create line $koord -fill $fill -width $width \
		    -tags {[list s $name]}]
	}
    }
    update
}

set test 0
for {set i 0} {$i < $argc} {incr i 2} {
    set opt [lindex $argv $i]
    set val [lindex $argv [expr $i + 1]]
    switch -- $opt {
	-test {
	    set test 1
	    incr i -1
	}
	default {
	    puts "Unknown switch $opt"
	    exit 1
	}
    }
}

strassenNew strassen
set all_crossings_l [strassenAllCrossings]
strassenNetzNew
strassenNetzMakeNet

set all_crossings_l [lsort -command _cmp2str $all_crossings_l]
set all_crossings {}
#array set rev_all_crossings {}
foreach elem $all_crossings_l {
    lappend all_crossings [lindex $elem 2]
#    array set rev_all_crossings [list [join [list [lindex $elem 0] , [lindex $elem 1]] "" ] [lindex $elem 2]]
}

set stage start

frame .kreuz
pack .kreuz -expand 1 -fill both -side left

label .kreuz.caption -text Kreuzungen
listbox .kreuz.lbox \
	-xscrollcommand ".kreuz.hscroll set" \
        -yscrollcommand ".kreuz.vscroll set"

bind .kreuz.lbox <Double-1> fillin
foreach elem $all_crossings {
    .kreuz.lbox insert end $elem
}

scrollbar .kreuz.hscroll -orient horiz -command ".kreuz.lbox xview"
scrollbar .kreuz.vscroll -command ".kreuz.lbox yview"

grid rowconfig    .kreuz 1 -weight 1 -minsize 0
grid columnconfig .kreuz 0 -weight 1 -minsize 0

grid .kreuz.caption -row 0 -column 0 -columnspan 2
grid .kreuz.lbox    -row 1 -column 0 -sticky news
grid .kreuz.hscroll -row 2 -column 0 -sticky news
grid .kreuz.vscroll -row 1 -column 1 -sticky news

frame .sz
pack .sz -side left

label .sz.startl -text Start:
pack .sz.startl -anchor w
label .sz.start -width 40 -relief sunken -justify left
pack .sz.start
label .sz.ziell -text Ziel:
pack .sz.ziell -anchor w
label .sz.ziel -width 40 -relief sunken -justify left
pack .sz.ziel
label .sz.ll -text Länge:
pack .sz.ll -anchor w
label .sz.l -width 40 -relief sunken -justify left
pack .sz.l
frame .sz.b
pack .sz.b -expand 1 -fill x
button .sz.b.best -text {Best path} -command best_path
pack .sz.b.best -side left
button .sz.b.next -text {Next path} -command next_path
pack .sz.b.next -side left

frame .res
pack .res -expand 1 -fill both -side left

label .res.caption -text Ergebnis
listbox .res.lbox \
	-xscrollcommand ".res.hscroll set" \
        -yscrollcommand ".res.vscroll set"

scrollbar .res.hscroll -orient horiz -command ".res.lbox xview"
scrollbar .res.vscroll -command ".res.lbox yview"

grid rowconfig    .res 1 -weight 1 -minsize 0
grid columnconfig .res 0 -weight 1 -minsize 0

grid .res.caption -row 0 -column 0 -columnspan 2
grid .res.lbox    -row 1 -column 0 -sticky news
grid .res.hscroll -row 2 -column 0 -sticky news
grid .res.vscroll -row 1 -column 1 -sticky news

set taskbarheight 20
switch $tcl_platform(os) {
    Darwin {
	# space for menubar and taskbar
	set taskbarheight 80
    }
}
toplevel .t
wm geometry .t [join [list [winfo screenwidth .t] x [expr [winfo screenheight .t] - $taskbarheight] "+0+0"] ""]
scrollbar .t.hscroll -orient horiz -command ".t.c xview"
scrollbar .t.vscroll -command ".t.c yview"
canvas .t.c -scrollregion {-4000 -4000 4000 4000} \
	-xscrollcommand ".t.hscroll set" \
        -yscrollcommand ".t.vscroll set" \
        -background \#ddeedd
label .t.l
.t.c bind s <Enter> {.t.l configure -text [lindex [.t.c gettags current] 1]}

grid rowconfig    .t 0 -weight 1 -minsize 0
grid columnconfig .t 0 -weight 1 -minsize 0

grid .t.c -padx 1 -in .t -pady 1 \
    -row 0 -column 0 -rowspan 1 -columnspan 1 -sticky news
grid .t.vscroll -in .t -padx 1 -pady 1 \
    -row 0 -column 1 -rowspan 1 -columnspan 1 -sticky news
grid .t.hscroll -in .t -padx 1 -pady 1 \
    -row 1 -column 0 -rowspan 1 -columnspan 1 -sticky news
grid .t.l -in .t -padx 1 -pady 1 \
    -row 2 -column 0 -rowspan 1 -columnspan 2 -sticky news

draw_net
