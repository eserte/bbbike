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
	return;
    }
    var orig_center_value = frm.center.value;
    frm.center.value = x + "," + y;
    var orig_imagetype_value = frm.imagetype.value; //XXX
    frm.imagetype.value = "mapserver";
    var orig_form_target = frm.target;
    frm.target = "BBBikeGrafik";

    frm.submit();

    frm.center.value = orig_center_value;
    frm.imagetype.value = orig_imagetype_value; //XXX
    frm.target = orig_form_target;
    return false;
}

function bs(px,py) {
    //XXX implement redirect to berliner-stadtplan.com
}

function show_map(bbbike_html_dir) {
    // show extra window for PDF && Netscape --- the .pdf is not embedded
    var frm = document.forms.showmap;
    if (frm && frm.imagetype.options[frm.imagetype.options.selectedIndex].value.indexOf('pdf') == 0 && !(navigator && navigator.appName && navigator.appName == "MSIE"))
	return true;
    var geom = "640x480";
    for (var i=0; i < document.showmap.geometry.length; i++) {
	if (document.showmap.geometry[i].checked) {
	    geom = document.showmap.geometry[i].value;
	    break;
	}
    }
    var addwindowparam = "";
    var imagetype_value;
    if (frm) {
	imagetype_value = frm.imagetype.options[frm.imagetype.options.selectedIndex].value;
    }
    if (imagetype_value == 'ascii' ||
	imagetype_value == 'mapserver' ||
	imagetype_value == 'berlinerstadtplan')
	addwindowparam += ",scrollbars,resizable"; // XXX sp?
    var x_y = geom.split("x");
// XXX height/width an aktuelle Werte anpassen
// XXX bei innerHeight/Width wird bei Netscape4 leider java gestartet?! (check!)
    var x = Math.floor(x_y[0])+15;
    var y = Math.floor(x_y[1])+15;
    // Menubar immer anzeigen ... damit Speichern und Drucken möglich ist
    y += 27;
    var menubar = "yes";

    var geometry_string = "";
    if (imagetype_value != 'mapserver' &&
	imagetype_value != 'berlinerstadtplan') {
        geometry_string = ",height=" + y + ",width=" + x;
    }

    // XXX cb_attachment and as_attachment never tested
    if (frm.cb_attachment.checked) {
	frm.as_attachment.value = "bla.foo";
    } else {
	frm.as_attachment.value = "";
	var w = window.open(bbbike_html_dir + "/pleasewait.html", "BBBikeGrafik",
			    "locationbar=no,menubar=" + menubar +
			    ",screenX=20,screenY=20" + addwindowparam +
			    geometry_string);
	w.focus();
    }
    return true;
}

function all_checked() {
    var all_checked_flag = false;
    var elems = document.forms["showmap"].elements;
    for (var e = 0; e < elems.length; e++) {
	if (elems[e].name == "draw" &&
	    elems[e].value == "all" &&
	    elems[e].checked) {
	    all_checked_flag = true;
	    break;
	}
    }
    for (var e = 0; e < elems.length; e++) {
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
    if (imgtype && imgtype.match(/^(berlinerstadtplan)/)) {
	can_size = false;
	can_details = false;
    }
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
