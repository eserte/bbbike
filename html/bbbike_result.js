// $Id: bbbike_result.js,v 1.20 2008/08/28 21:32:53 eserte Exp $
// (c) 2003 Slaven Rezic. All rights reserved.

function test_temp_blockings_set() {
    var frm = document.forms["Ausweichroute"];
    for (var elem = 0; elem < frm.elements["custom"].length; elem++) {
	if (frm.elements["custom"][elem].checked) {
	    return true;
	}
    }
    alert("Bitte mindestens eine Auswahlbox auswählen");
    return false;
}

function ms(x,y) {
    var frm = document.forms["showmap"];
    if (!frm) {
	alert("Form showmap not defined");
	return false;
    }
    var orig_center_value = frm.center.value;
    frm.center.value = x + "," + y;
    var orig_imagetype_value = frm.imagetype.value; //XXX
    frm.imagetype.value = "mapserver";
    var orig_form_target = frm.target;
    frm.target = "_blank";

    frm.submit();

    frm.center.value = orig_center_value;
    frm.imagetype.value = orig_imagetype_value; //XXX
    frm.target = orig_form_target;
    return false;
}

function show_map(args) {
    var frm = document.forms.showmap;
    var imagetype_value;
    if (frm) {
	imagetype_value = frm.imagetype.options[frm.imagetype.options.selectedIndex].value;
    }

    if (imagetype_value == 'leaflet') {
	if (args.leaflet_url) {
	    var w = window.open(args.leaflet_url, '_blank');
	    w.focus();
	    return false;
	} else {
	    alert('INTERNAL ERROR: leaflet_url is not set');
	    return false;
	}
    }

    return true;
}

function all_checked() {
    var all_checked_flag = false;
    var elems = document.forms["showmap"].elements;
    var e; // sigh - no block scoping in javascript
    for (e = 0; e < elems.length; e++) {
	if (elems[e].name == "draw" &&
	    elems[e].value == "all" &&
	    elems[e].checked) {
	    all_checked_flag = true;
	    break;
	}
    }
    for (e = 0; e < elems.length; e++) {
	if (elems[e].name == "draw") {
	    if (all_checked_flag) {
		elems[e].checked = true;
	    } else {
		elems[e].checked = (elems[e].value == "str" ||
				    elems[e].value == "title");
	    }
	}
    }
}

function enable_size_details_buttons() {
    var frm = document.forms["showmap"];
    if (!frm) return;
    var imgtypeelem = frm.elements["imagetype"];
    if (!imgtypeelem) return;
    var imgtype = imgtypeelem.value;
    var can_size = true;
    var can_details = true;
    if (imgtype && imgtype.match(/^(mapserver|pdf|svg)/)) {
	can_size = false;
    }
    var elems = frm.elements;
    for (var e = 0; e < elems.length; e++) {
	if (elems[e].name == "draw") {
	    elems[e].disabled = !can_details;
	}
	if (elems[e].name == "geometry") {
	    elems[e].disabled = !can_size;
	}
    }
}

function enable_settings_buttons() {
    var frm = document.forms["settings"];
    if (!frm) {
	frm = document.forms[0];
	if (!frm) return;
    }
    var winteroptelem = frm.elements["pref_winter"];
    if (!winteroptelem) return;
    return; // Currently all preferences are available, even with winter optimierung
    var disable_non_winter = winteroptelem.value != "";
    var elems = frm.elements;
    var other_prefs = ["speed", "cat", "quality", "ampel", "green"];
    for(var e = 0; e < other_prefs.length; e++) {
	var elem = frm.elements["pref_" + other_prefs[e]];
	if (elem) {
	    elem.disabled = disable_non_winter;
	}
    }
}

function reset_form(default_speed, default_cat, default_quality,
		    default_routen, default_ampel, default_green,
		    default_winter) {
    var frm = document.forms.settings;
    if (!frm) {
	frm = document.forms[0];
    }
    with (frm) {
	if (typeof default_speed != null) {
	    elements["pref_speed"].value = default_speed;
	}
	elements["pref_cat"].options[default_cat].selected = true;
	elements["pref_quality"].options[default_quality].selected = true;
	if (elements["pref_routen"]) {
	    elements["pref_routen"].options[default_routen].selected = true;
	}
	elements["pref_ampel"].checked = default_ampel;
	elements["pref_green"].options[default_green].selected = true;
	if (elements["pref_winter"]) {
	    elements["pref_winter"].options[default_winter].selected = true;
	}
    }
    return false;
}

// XXX The texts here should be duplicated in help.html!!!
function show_help(what) {
    if (what == "winteroptimization") {
	alert("Erfahrungsgemäß werden bei Schnee und Eis Hauptstraßen am ehesten geräumt. Deshalb wird bei dieser Einstellung verstärkt auf Hauptstraßen optimiert und Nebenstraßen gemieden. Weitere Eigenschaften fließen in eine schlechtere Bewertung einer Straße ein: benutzungspflichtige Radwege, Kopfsteinpflasterstraßen, Straßenbahnen auf der Fahrbahn und Brücken.");
    } else if (what == "fragezeichen") {
	alert("Bei Wahl dieser Einstellungen werden auch Straßen und Wege, deren Eignung für Radfahrer unbekannt ist, in die Suche mit einbezogen.");
    } else if (what == "") {
	alert("Es wurde kein Hilfethema angegeben");
    } else {
	alert("Keine Hilfe für das Thema " + what);
    }
}

function show_help_en(what) {
    if (what == "winteroptimization") {
	alert("Erfahrungsgemäß werden bei Schnee und Eis Hauptstraßen am ehesten geräumt. Deshalb wird bei dieser Einstellung verstärkt auf Hauptstraßen optimiert und Nebenstraßen gemieden. Weitere Eigenschaften fließen in eine schlechtere Bewertung einer Straße ein: benutzungspflichtige Radwege, Kopfsteinpflasterstraßen, Straßenbahnen auf der Fahrbahn und Brücken.");
    } else if (what == "fragezeichen") {
	alert("If you choose this option then streets with unknown suitability for cyclists will also be used in the route search.");
    } else if (what == "") {
	alert("No help topic given");
    } else {
	alert("No help for the topic " + what);
    }
}


function init_search_result() {
    enable_size_details_buttons();
    enable_settings_buttons();
}

// Local variables:
// c-basic-offset: 4
// End:
