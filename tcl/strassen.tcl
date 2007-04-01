#
# $Id: strassen.tcl,v 1.3 2007/03/31 20:04:44 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Tcl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# XXXXXXX
# wie gehen verschachtelte Arrays mit tcl???
# wie kann man vernünftig mit Objekten umgehen???

set strassenDatadirs { "./data" "../data" "/home/e/eserte/src/bbbike/data" }

proc strassenNew {filename} {
    global strassenData strassenPos
    global strassenDatadirs
    global test

    set B ""
    for {set x 0} {$x < [llength $strassenDatadirs]} {incr x} {
	set file [lindex $strassenDatadirs $x]
	set file "$file/$filename"
	if {[file readable $file]} {
	    set B [open $file r]
	    break
	}
    }

    if {$B == ""} {
	error [concat "No strassen file <" $filename "> found, tried in <" $strassenDatadirs ">"]
    }

    set strassenData {}
    set i 0
    while {! [eof $B]} {
	gets $B line
	if {[string index $line 0] ne "#"} {
	    lappend strassenData $line
	    incr i
	}
	# debug
	if {$test && $i > 100} break
    }
    close $B

    set strassenPos 0
}

proc strassenGet {pos} {
    global strassenData

    set line [lindex $strassenData $pos]
    if {$line == ""} {
	return {"" {} ""}
    }
    set list [split $line "\t"]
    set name [lindex $list 0]
    set list2 [split [lindex $list 1] " \t"]
    set category [lindex $list2 0]
    set res [lrange $list2 1 end]
    return [list $name $res $category]
}

proc strassenInit {} {
    global strassenPos
    set strassenPos -1
}

proc strassenFirst {} {
    global strassenPos
    set strassenPos 0
    return [strassenGet 0]
}

proc strassenNext {} {
    global strassenPos
    incr strassenPos
    return [strassenGet $strassenPos]
}

# strassenNext2 NYI
# strassenAtEnd NYI

proc strassenCount {} {
    global strassenData
    return [llength $strassenData]
}

proc strassenPos {} {
    global strassenPos
    return $strassenPos
}

# Bei Ändrungen des Koordinatenformats müssen die folgenden beiden
# Funktionen geändert werden:
proc strassenToKoord {koordlist} {
    set res {}
    foreach elem $koordlist {
	if {[regexp {^([^\)]+),([^\)]+)$} $elem _ x y]} {
	    lappend res [list $x $y]
	} else {
	    puts stderr "Warning: Can't parse $elem"
	}
    }
    return $res
}

proc strassenToKoord1 {s} {
    if {[regexp {^([^\)]+),([^\)]+)$} $s _ x y]} {
	return [list $x $y]
    }
    puts stderr "Warning: Can't parse $s"
    return {}
}

proc strassenAllCrossings {} {
    array set crossings {}
    array set crossings_name {}
    strassenInit
    while {1} {
	set ret [strassenNext]
	set kreuzungen [lindex $ret 1]
	if {$kreuzungen == ""} {
	    break
	}
	set name [lindex $ret 0]
	set kreuz_coord [strassenToKoord $kreuzungen]
	foreach elem $kreuz_coord {
	    set xy [join [list [lindex $elem 0] , [lindex $elem 1]] ""]
	    if {[array get crossings $xy] == ""} {
		set crossings($xy) 1
	    } else {
		set crossings($xy) [expr $crossings($xy) + 1]
	    }
	    set equal 0
	    if {[array get crossing_name $xy] == ""} {
		set crossing_name($xy) ""
	    }
	    foreach test $crossing_name($xy) {
		if {$test == $name} {
		    set equal 1
		    break
		}
	    }
	    if {!$equal} {
		lappend crossing_name($xy) $name
	    }
	}
    }

    set all_crossings {}
    foreach key [array names crossings] {
	if {$crossings($key) > 1} {
	    set xy [split $key ","]
	    lappend all_crossings [list \
		    [lindex $xy 0] [lindex $xy 1] \
		    [join $crossing_name($key) "/"]]
	}
    }
    return $all_crossings
}

######################################################################

proc strassenNetzNew {} {
    global strnetNet strnetNet2Name strnetKoordXY
    array set strnetNet {}
    array set strnetNet2Name {}
    array set strnetKoordXY {}
}

proc strassenNetzMakeNet {} {
    global strnetNet strnetNet2Name strnetKoordXY
    array set strnetNet {}
    array set strnetNet2Name {}
    array set strnetKoordXY {}

    strassenInit
    while {1} {
	set ret [strassenNext]
	set kreuzungen [lindex $ret 1]
	if {$kreuzungen == ""} {
	    break
	}
	set kreuz_coord [strassenToKoord $kreuzungen]
	for {set i 0} {$i < [expr [llength $kreuzungen] - 1]} {incr i} {
	    set entf [_strecke \
		    [lindex $kreuz_coord $i] \
		    [lindex $kreuz_coord [expr $i + 1]]]
	    set strnetNet([join [lrange $kreuzungen $i [expr $i + 1]] "|"]) $entf
	    set strnetNet([join [list [lindex $kreuzungen [expr $i + 1]] \
		                      [lindex $kreuzungen $i]] "|"]) $entf
	    if {[array get strnetKoordXY [lindex $kreuzungen $i]] == ""} {
		set strnetKoordXY([lindex $kreuzungen $i]) \
			[lindex $kreuz_coord $i]
	    }
	    set strnetNet2Name([join [lrange $kreuzungen $i [expr $i + 1]] "|"]) [strassenPos]
	    set strnetNet2Name([join [list [lindex $kreuzungen [expr $i + 1]] "|" [lindex $kreuzungen $i]] ""]) [strassenPos]
	}
	# letztes $i
	if {[array get strnetKoordXY [lindex $kreuzungen $i]] == ""} {
	    set strnetKoordXY([lindex $kreuzungen $i]) \
		    [lindex $kreuz_coord $i]
	}
    }
}

# proc make_sperre NYI

proc strassenNetzSearchAstar {from to} {
    global strnetNet strnetKoordXY

    if {![strassenNetzReachable $from] || \
	    ![strassenNetzReachable $to]} {
	puts stderr "$from and/or not reachable!"
	return {}
    }

    array set OPEN_CLOSED [list $from 1]
    array set NODES [list $from [list {} 0 0]]

    while {1} {
	if {[array size OPEN_CLOSED] == 0} { ;# nicht richtig
	    puts stderr "No path found!"
	    return {}
	}

	set min_node {}
	set min_node_f 99999999
	foreach k [array names OPEN_CLOSED] {
	    if {$OPEN_CLOSED($k) == 1} {
		if {[lindex $NODES($k) 2] < $min_node_f} {
		    set min_node $k
		    set min_node_f [lindex $NODES($k) 2]
		}
	    }
	}
	set OPEN_CLOSED($min_node) 0

	if {$min_node == $to} {
	    puts stderr "Found!"
	    set tmppath {}
	    set len 0
	    while {1} {
		set tmppath [linsert $tmppath 0 $min_node]
		set prev_node [lindex $NODES($min_node) 0]
		if {$prev_node != ""} {
		    set len [expr $len + [_strecke_s $min_node $prev_node]]
		    set min_node $prev_node
		} else {
		    break;
		}
	    }
	    set path {}
	    foreach elem $tmppath {
		set kl [split $elem ","]
		lappend path $kl
	    }

	    return [list [list $path $len 0 0 0]]
	}

	set successors [array names strnetNet "$min_node|*"]
	foreach successor_key $successors {
	    set successor [lindex [split $successor_key "|"] 1]
	    # XXX next implementieren

	    set g [expr [lindex $NODES($min_node) 1] + \
		        $strnetNet($successor_key)]
	    set f [expr $g + \
		        [_strecke_s $successor $to]]

	    if {[array get NODES $successor] == {}} {
		set NODES($successor) [list $min_node $g $f]
		set OPEN_CLOSED($successor) 1
	    } else {
		if {$f < [lindex $NODES($successor) 2]} {
		    set NODES($successor) [list $min_node $g $f]
		    set OPEN_CLOSED($successor) 1
		}
	    }
	}
    }
}

proc strassenNetzSearch {from to} {
    global strnetNet strnetKoordXY
    global visualSearch inVisualSearch

    if {![strassenNetzReachable $from] || \
	    ![strassenNetzReachable $to]} {
	puts stderr "$from and/or not reachable!"
	return {}
    }

    set all_paths [list [list [list $from] 0]]
    set found_paths {}
    set suspended_paths {}
    array set visited [list $from 0]
    while {1} {
	while {$all_paths != ""} {
	    set new_all_paths {}
	    foreach path_def $all_paths {
		set path [lindex $path_def 0]
		set curr_len [lindex $path_def 1]
		set last_node [lindex $path [expr [llength $path] - 1]]
		set next_node_names {}
		set koord_names [array names strnetNet $last_node*]
		foreach koord_name $koord_names {
		    lappend next_node_names [lindex [split $koord_name "|"] 1]
		}
		foreach next_node $next_node_names {
		    set len $strnetNet($last_node|$next_node)
		    set next_node_len [expr $len + $curr_len]
		    if {[array get visited $next_node] != "" && \
			    $next_node_len >= $visited($next_node)} {
			continue
		    }
		    set visited($next_node) $next_node_len
		    if {$next_node == $to} {
			set koords [concat $path $to]
			puts "Found path, len: $next_node_len"
			lappend found_paths \
				[list [strassenToKoord $koords] \
				$next_node_len]
			continue
		    }
		    set virt_len [expr $next_node_len + \
			    [_strecke $strnetKoordXY($next_node) \
			              $strnetKoordXY($to)]]
		    if {[array get visited $to] != "" && \
			    $visited($to) < $virt_len} {
			continue
		    }
		    lappend new_all_paths \
			    [list [concat $path $next_node] \
			    $next_node_len $virt_len]
		}
	    }
#puts [join [list [llength $all_paths] [llength $suspended_paths] [llength $found_paths]] " "]
	    set all_paths [lsort -command _cmp_not2 \
		    [concat $new_all_paths $suspended_paths] ]
	    set suspended_paths [lrange $all_paths 0 4]
	    set all_paths [lrange $all_paths 5 end]
#puts [join $all_paths ", "]
	    if {$visualSearch} {
		set inVisualSearch 1
		clear_path
		foreach path $suspended_paths {
		    draw_path [strassenToKoord $path] 0
		}
		foreach path $all_paths {
		    draw_path [strassenToKoord $path] 1
		}
		update idletasks
		set inVisualSearch 0
	    }
	}
	if {$suspended_paths != ""} {
	    set all_paths [lrange $suspended_paths 0 4]
	    set all_paths [lsort -command _cmp_not2 $all_paths]
	    set suspended_paths [lrange $all_paths 5 end]
	} else {
	    break
	}
    }

    if {$found_paths == ""} {
	puts "Nothing found"
	return {}
    } else {
	set found_paths [lsort -command _cmp1 $found_paths]
	return $found_paths
    }
}

proc strassenNetzKoordToName {koords} {
    global strnetNet2Name
    set res {}
    for {set i 0} {$i < [expr [llength $koords] - 1]} {incr i} {
	set koord1 [lindex $koords $i]
	set koord2 [lindex $koords [expr $i + 1]]
	set xy [join [list [coord_as_string $koord1] [coord_as_string $koord2]] "|"]
	set pos $strnetNet2Name($xy)
	set ret [strassenGet $pos]
	set name [lindex $ret 0]
	if {[llength $res] < 1 || \
		$name != [lindex $res [expr [llength $res] - 1]]} {
	    lappend res $name
	}
    }
    return $res
}

proc _cmp1 {a b} {
    return [expr [lindex $a 1] > [lindex $b 1] ? 1 : \
	    [lindex $a 1] == [lindex $b 1] ? 0 : -1]
}

proc _cmp2 {a b} {
    return [expr [lindex $a 2] > [lindex $b 2] ? 1 : \
	    [lindex $a 2] == [lindex $b 2] ? 0 : -1]
}

proc _cmp_not2 {a b} {
    return [expr [lindex $a 2] > [lindex $b 2] ? -1 : \
	    [lindex $a 2] == [lindex $b 2] ? 0 : 1]
}

proc _cmp2str {a b} {
    return [string compare [lindex $a 2] [lindex $b 2]]
}

proc strassenNetzReachable {index} {
    global strnetNet
    if {[array get strnetNet($index)] != ""} {
	puts "$index is not reachable"
	return 0
    } else {
	return 1
    }
}

proc _strecke {p1 p2} {
    return [expr sqrt([_sqr [expr [lindex $p1 0] - [lindex $p2 0]]] + \
	              [_sqr [expr [lindex $p1 1] - [lindex $p2 1]]])]
}

proc _strecke_s {p1 p2} {
    set pl1 [split $p1 ","]
    set pl2 [split $p2 ","]
    return [_strecke $pl1 $pl2]
}

proc _sqr {x} { return [expr $x * $x] }

proc coord_as_string {koord_xy} {
    return [join [list [lindex $koord_xy 0] "," [lindex $koord_xy 1] ] ""]
}