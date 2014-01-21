// bbbike_start.js
// (c) 2001-2002,2009,2010 Slaven Rezic. All rights reserved.
// See comment in bbbike.cgi regarding x/ygridwidth

var all_above_layer = new Array();
var bbbike_images_dir;

function set_bbbike_images_dir(path) {
  bbbike_images_dir = path;
}

function init_hi() {
  if (typeof startmap_init  == "function")  startmap_init();
  if (typeof viamap_init    == "function")    viamap_init();
  if (typeof zielmap_init   == "function")   zielmap_init();
  if (typeof startchar_init == "function") startchar_init();
  if (typeof viachar_init   == "function")   viachar_init();
  if (typeof zielchar_init  == "function")  zielchar_init();
}

function getOffsetLeft(o) {
  var par = 0;
  if (o.offsetParent)
    par = getOffsetLeft(o.offsetParent);
  return par + o.offsetLeft;
}
function getOffsetTop(o) {
  var par = 0;
  if (o.offsetParent)
    par = getOffsetTop(o.offsetParent);
  return par + o.offsetTop;
}

function find_layer(x) {
  return document.getElementById(x);
}

function vis(x,val) {
  if (document.layers) {
    document.layers[x].visibility = val;
  } else {
    val = (val == 'hide' ? 'hidden' : 'visible');
    var l;
    if (document.all) {
      l = document.all[x];
    } else if (document.body) { // NS6.0
      l = find_layer(x);
    }
    l.style.visibility = val;
  }
}

function pos_rel(lay,rel_lay,x,y) {
  if (document.implementation && document.implementation.hasFeature("CSS2","2.0")) { // Mozilla 1.1+, Galeon, Firefox
    var pos_layer   = find_layer(lay);
    var below_layer = find_layer(rel_lay);
    pos_layer.style.left = (getOffsetLeft(below_layer)+x) + "px";
    pos_layer.style.top = (getOffsetTop(below_layer)+y) + "px";
  } else if (document.layers) { // Netscape 4
    document.layers[lay].pageX = document.layers[rel_lay].pageX+x;
    document.layers[lay].pageY = document.layers[rel_lay].pageY+y;
    //alert(document.layers[lay].pageX + "/" + document.layers[lay].pageY);
  } else if (document.all) {
    document.all[lay].style.left = getOffsetLeft(document.all[rel_lay])+x;
    document.all[lay].style.top = getOffsetTop(document.all[rel_lay])+y;
  }
}

function any_init(type) {
  var below_layer; // sigh - no block scoping in javascript
  var above_layer; // sigh - no block scoping in javascript
  if (document.implementation && document.implementation.hasFeature("CSS2","2.0")) { // Mozilla 1.1+, Galeon, Firefox
    below_layer = find_layer(type + "below");
    above_layer = find_layer(type + "above");
    above_layer.style.visibility = 'hidden';
    below_layer.style.visibility = 'visible';
    // positioning of the above layer happens now in any_highlight, so
    // it works correctly if the user zooms the page 
    below_layer.onmousemove = eval(type + "_highlight");
    above_layer.onmouseout = eval(type + "_byebye");
    above_layer.onmouseup = eval(type + "_detail");
    all_above_layer[all_above_layer.length] = above_layer;
  } else if (document.layers) { // Netscape 4
    if (!document.layers[type + "above"]) return;
    document.layers[type + "above"].visibility = 'hide';
    document.layers[type + "below"].visibility = 'show';
    // XXX theoretically this belongs also to any_highlight
    document.layers[type + "above"].pageX
      = document.layers[type + "below"].pageX;
    document.layers[type + "above"].pageY
      = document.layers[type + "below"].pageY;
    document.layers[type + "below"].captureEvents(Event.MOUSEMOVE);
    document.layers[type + "below"].onmousemove = eval(type + "_highlight");
    document.layers[type + "above"].onmouseout = eval(type + "_byebye");
    document.layers[type + "above"].captureEvents(Event.MOUSEUP);
    document.layers[type + "above"].onmouseup = eval(type + "_detail");
    all_above_layer[all_above_layer.length] = document.layers[type + "above"];
  } else if (document.all) { // MSIE, Opera
    document.all[type + "above"].style.visibility = 'hidden';
    document.all[type + "below"].style.visibility = 'visible';
    // positioning of the above layer happens now in any_highlight, so
    // it works correctly if the user zooms the page 
    document.all[type + "below"].onmousemove = eval(type + "_highlight");
    document.all[type + "above"].onmouseout = eval(type + "_byebye");
    document.all[type + "above"].onmouseup = eval(type + "_detail");
    all_above_layer[all_above_layer.length] = document.all[type + "above"];
  } else if (document.body) { // NS6.0
    below_layer = find_layer(type + "below");
    above_layer = find_layer(type + "above");
    above_layer.style.visibility = 'hidden';
    below_layer.style.visibility = 'visible';
    // XXX theoretically this belongs also to any_highlight
    above_layer.style.left
        = getOffsetLeft(below_layer);
    above_layer.style.top
        = getOffsetTop(below_layer);
    below_layer.onmousemove = eval(type + "_highlight");
    above_layer.onmouseout = eval(type + "_byebye");
    above_layer.onmouseup = eval(type + "_detail");
    all_above_layer[all_above_layer.length] = above_layer;
  }
}

function any_highlight(type, Evt) {
  var xgridwidth, ygridwidth, offset;
  var above, below, x, y; // sigh - no block scoping in javascript
  var l; // sigh - no block scoping in javascript
  if (type.indexOf("map") != -1) {
      xgridwidth = 20;
      ygridwidth = 20;
      offset = -2;
  } else {
      xgridwidth = 30;
      ygridwidth = 30;
      offset = 4;
  }
  if (document.layers) {
    above = document.layers[type + "above"];
    below = document.layers[type + "below"];
    if (above && below) {
      below.captureEvents(Event.MOUSEMOVE);
      below.onmousemove = eval(type + "_highlight");
      x = Math.floor((Evt.pageX-below.pageX)/xgridwidth)*xgridwidth;
      y = Math.floor((Evt.pageY-below.pageY)/ygridwidth)*ygridwidth+offset;
      // with is evil?
      above.clip.left = x;
      above.clip.top = y;
      above.clip.right = x+xgridwidth;
      above.clip.bottom = y+xgridwidth;
      above.visibility = 'show';
      for (l in all_above_layer) {
	if (all_above_layer[l] != above) all_above_layer[l].visibility = 'hide';
      }
    }
  } else if (document.all || document.body) {
    if (document.all) {
      above = document.all[type + "above"];
      below = document.all[type + "below"];
      Evt = window.event;
      x = Math.floor((Evt.offsetX-below.style.left)/xgridwidth)*xgridwidth;
      y = Math.floor((Evt.offsetY-below.style.top)/ygridwidth)*ygridwidth+offset;
      if (window.navigator.appName == "Microsoft Internet Explorer" && document.documentMode) { // IE8 and later
	above.style.clip = "rect("+y+"px,"+(x+xgridwidth)+"px,"+(y+ygridwidth)+"px,"+x+"px)";
      } else {
	// pre-IE8
	above.style.clip = "rect("+y+" "+(x+xgridwidth)+" "+(y+ygridwidth)+" "+x+")";
      }
      above.style.left = getOffsetLeft(document.all[type + "below"]);
      above.style.top  = getOffsetTop(document.all[type + "below"]);
    } else {
      above = find_layer(type + "above");
      below = find_layer(type + "below");
      above.style.left = getOffsetLeft(below) + "px";
      above.style.top = getOffsetTop(below) + "px";
      if (Evt.offsetX != null) {
	x = Math.floor(Evt.offsetX/xgridwidth)*xgridwidth;
	y = Math.floor(Evt.offsetY/ygridwidth)*ygridwidth+offset;
      } else {
	x = Math.floor(Evt.layerX/xgridwidth)*xgridwidth;
	y = Math.floor(Evt.layerY/ygridwidth)*ygridwidth+offset;
      }
      above.style.clip = "rect("+y+"px,"+(x+xgridwidth)+"px,"+(y+ygridwidth)+"px,"+x+"px)";
    }
    below.onmousemove = eval(type + "_highlight");
    above.style.visibility = 'visible';
    for (l in all_above_layer) {
      if (all_above_layer[l] != above) all_above_layer[l].style.visibility = 'hidden';
    }
  }
}

function any_byebye(type, Evt) {
  if (document.layers) { // only NS4
    document.layers[type + "above"].visibility = 'hide';
  }
}

function any_detail(type, Evt) {
  cleanup_special_click();
  if (document.layers) {
    document.BBBikeForm[type + "img.x"].value = Evt.layerX;
    document.BBBikeForm[type + "img.y"].value = Evt.layerY;
  } else if (document.all) {
    Evt = window.event;
    document.BBBikeForm[type + "img.x"].value = Evt.offsetX;
    document.BBBikeForm[type + "img.y"].value = Evt.offsetY;
  } else if (document.body) {
    document.BBBikeForm[type + "img.x"].value = Evt.layerX;
    document.BBBikeForm[type + "img.y"].value = Evt.layerY;
  }
  document.BBBikeForm.submit();
}

function list_all_streets_onload() {
  if (!document.body) return;
  var types = [["Start", "start"],
	       ["Via", "via"],
	       ["Ziel", "ziel"]];
  var e = document.getElementById("list");
  for (i = 0; i < e.childNodes.length; i++) {
    var n = e.childNodes[i];
    if (n.nodeName == "#text") {
      var nextNode = e.childNodes[i+1];
      var label = n.nodeValue;
      n.appendData(" ");

      for (t = 0; t < types.length; t++) {
	var type_label = types[t][0];
	var type = types[t][1];
	var elem = document.createElement("a");
	elem.setAttribute('href', 'javascript:all_streets_set_input("'+type+'", "'+escape(label)+'")');
	elem.appendChild(document.createTextNode(type_label));
	e.insertBefore(elem, nextNode);

	var spacer = document.createElement("span");
	spacer.appendChild(document.createTextNode(" "));
	e.insertBefore(spacer, nextNode);
      }
    }
  }
}

function all_streets_set_input(type, label) {
  if (window.opener &&
      window.opener.document &&
      window.opener.document.forms.BBBikeForm &&
      window.opener.document.forms.BBBikeForm.elements[type]) {
    window.opener.document.forms.BBBikeForm.elements[type].value = unescape(label);
  }
}

// Reset variables which are set from clicking on detail or char maps
function cleanup_special_click() {
  var guielems = ["char","map"];
  for(var guielem_i in guielems) {
    var types = ["start","via","ziel"];
    for(var type_i in types) {
      var xy = ["x", "y"];
      for (var xy_i in xy) {
	var name = types[type_i] + guielems[guielem_i] + "img." + xy[xy_i];
	var elem = document.BBBikeForm[name];
	if (elem) {
	  elem.value = "";
	}
      }
    }
  }
}

function set_street_in_berlinmap(type, inx) {
  for(var i = 1; i < 10000; i++) {
    var img = find_layer(type + "matchimg" + i);
    if (img) {
      var containingDiv = find_layer(type + "match" + i);
      if (i == inx) {
	img.src = bbbike_images_dir + "/reddot.png";
	if (containingDiv) {
	  containingDiv.style.zIndex = 1;
	}
      } else {
	img.src = bbbike_images_dir + "/bluedot.png";
	if (containingDiv) {
	  containingDiv.style.zIndex = 0;
	}
      }
    } else {
      break;
    }
  }
}

function set_street_from_berlinmap(type, inx) {
  document.BBBikeForm[type + "2"][inx-1].checked = true;
  set_street_in_berlinmap(type, inx);
  return false;
}

function focus_first() {
  if (document.BBBikeForm) {
    var elems = ["start", "via", "ziel"];
    for (var i = 0; i < elems.length; i++) {
      var elem = elems[i];
      if (document.BBBikeForm[elem] && typeof document.BBBikeForm[elem].focus == "function") {
	document.BBBikeForm[elem].focus();
	break;
      }
    }
  }
}

//////////////////////////////////////////////////////////////////////
// Geolocation

function check_locate_me() {
  if (!navigator || !navigator.geolocation) {
    return;
  }
  if (!document.getElementById) {
    return;
  }
  var elem = document.getElementById("locateme");
  if (!elem) {
    return;
  }
  elem.style.visibility = "visible";
}

function locate_me() {
  vis("locateme_wait", "show");
  navigator.geolocation.getCurrentPosition(locate_me_cb, locate_me_error);
}

function locate_me_error(error) {
  vis("locateme_wait", "hide");
  var msg = "Es konnte keine Positionierung durchgeführt werden. ";
  if (error.code == 1) {
    msg += "Möglicher Grund: Ortungsdienste sind ausgeschaltet. Bitte in den Einstellungen des Geräts aktivieren!";
  } else if (error.code == 2) {
    msg += "Die Position konnte nicht ermittelt werden.";
  } else if (error.code == 3) {
    msg += "Möglicher Grund: Zeitablauf bei der Ermittlung der Position";
  } else {
    msg += "Unbekannter Grund, Fehler-Code=" + error.code;
  }
  alert(msg);
}

function locate_me_cb(position) {
  var pos = position.coords.longitude + "," + position.coords.latitude;
  call_bbbike_api("revgeocode", "lon=" + position.coords.longitude + ";" + "lat=" + position.coords.latitude, locate_me_res);
}

function locate_me_res(res) {
  vis("locateme_wait", "hide");
  if (!res) {
    alert("Die Positionierung konnte nicht durchgeführt werden.");
  } else if (!res.bbbikepos) {
    //alert("Es konnte keine Position gefunden werden.");
    redirect_to_bbbikeorg(res.origlon, res.origlat);
  } else {
    var bbbikeform = document.forms["BBBikeForm"];
    bbbikeform.elements["start"].value = res.crossing;
    if (typeof transpose_dot_func == "function") {
      var xy = res.bbbikepos.split(/,/);
      var txy = transpose_dot_func(parseInt(xy[0]), parseInt(xy[1]));
      if (find_layer("startmapbelow")) {
	pos_rel("locateme_marker", "startmapbelow", txy[0], txy[1]);
	vis("locateme_marker", "show");
      }
      var startc_input = bbbikeform.elements["startc"];
      var startcvalidfor_input = bbbikeform.elements["scvf"];
      if (startc_input && startcvalidfor_input && res.bbbikepos) {
	startc_input.value = res.bbbikepos;
	startcvalidfor_input.value = res.crossing;
      }
    }
  }
}

function call_bbbike_api(action, params, cb) {
  var client = new XMLHttpRequest();
  var url = "bbbike.cgi?api=" + action + (params != "" ? ";" + params : "");
  client.open("GET", url, true);
  client.send();
  client.onreadystatechange = function() {
    if (this.readyState == 4) { // DONE
      eval("res = " + client.responseText);
      cb(res);
    }
  };
}

function call_bbbikeorg_location(lng, lat, cb_success, cb_fail) {
  var client = new XMLHttpRequest();
  var url = "http://www.bbbike.org/cgi/location.cgi?appid=bbbikede&lng=" + lng + "&lat=" + lat;
//  var url = "http://devel.bbbike.org/cgi/location.cgi?lng=" + lng + "&lat=" + lat;
  client.open("GET", url, true);
  client.send();
  client.onreadystatechange = function() {
    if (this.readyState == 4) { // DONE
      eval("res = " + client.responseText);
      if (res.length) {
	cb_success(res[0]);
      } else {
	cb_fail();
      }
    }
  };
}

function redirect_to_bbbikeorg(lng, lat) {
  call_bbbikeorg_location(lng, lat, function(city) {
      window.location = "http://www.bbbike.org/" + city + "/?appid=bbbikede&startc_wgs84=" + lng + "," + lat;
    }, function() {
      alert("Die Position " + lng + "," + lat + " wird von bbbike.de und bbbike.org nicht unterstützt.");
    });
}

// return the screen scale factor used for IE
// implementation idea from http://stackoverflow.com/questions/15193524/ie-does-not-scale-clicks-on-a-scaled-desktop-when-submitting-web-form-using-inpu
function get_scale_factor_MSIE10(elem_id) {
    try {
        nscalefactor = screen.deviceXDPI / screen.logicalXDPI;
        find_layer(elem_id).value = nscalefactor;
    } catch (e) {
	// fail silently
    }
}

// Local variables:
// c-basic-offset: 2
// End:
