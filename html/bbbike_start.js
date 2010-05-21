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
  if (document.implementation && document.implementation.hasFeature("CSS2","2.0")) { // Mozilla 1.1+, Galeon, Firefox
    var below_layer = find_layer(type + "below");
    var above_layer = find_layer(type + "above");
    above_layer.style.visibility = 'hidden';
    below_layer.style.visibility = 'visible';
    above_layer.style.left
        = getOffsetLeft(below_layer) + "px";
    above_layer.style.top
        = getOffsetTop(below_layer) + "px";
    below_layer.onmousemove = eval(type + "_highlight");
    above_layer.onmouseout = eval(type + "_byebye");
    above_layer.onmouseup = eval(type + "_detail");
    all_above_layer[all_above_layer.length] = above_layer;
  } else if (document.layers) { // Netscape 4
    if (!document.layers[type + "above"]) return;
    document.layers[type + "above"].visibility = 'hide';
    document.layers[type + "below"].visibility = 'show';
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
    document.all[type + "above"].style.left
      = getOffsetLeft(document.all[type + "below"]);
    document.all[type + "above"].style.top
      = getOffsetTop(document.all[type + "below"]);
    document.all[type + "below"].onmousemove = eval(type + "_highlight");
    document.all[type + "above"].onmouseout = eval(type + "_byebye");
    document.all[type + "above"].onmouseup = eval(type + "_detail");
    all_above_layer[all_above_layer.length] = document.all[type + "above"];
  } else if (document.body) { // NS6.0
    var below_layer = find_layer(type + "below");
    var above_layer = find_layer(type + "above");
    above_layer.style.visibility = 'hidden';
    below_layer.style.visibility = 'visible';
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
    var above = document.layers[type + "above"];
    var below = document.layers[type + "below"];
    if (above && below) {
      below.captureEvents(Event.MOUSEMOVE);
      below.onmousemove = eval(type + "_highlight");
      var x = Math.floor((Evt.pageX-below.pageX)/xgridwidth)*xgridwidth;
      var y = Math.floor((Evt.pageY-below.pageY)/ygridwidth)*ygridwidth+offset;
      // with is evil?
      above.clip.left = x;
      above.clip.top = y;
      above.clip.right = x+xgridwidth;
      above.clip.bottom = y+xgridwidth;
      above.visibility = 'show';
      for (var x in all_above_layer) {
	if (all_above_layer[x] != above) all_above_layer[x].visibility = 'hide';
      }
    }
  } else if (document.all || document.body) {
    var above, below, Evt, x, y;
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
    } else {
      above = find_layer(type + "above");
      below = find_layer(type + "below");
      x = Math.floor(Evt.layerX/xgridwidth)*xgridwidth;
      y = Math.floor(Evt.layerY/ygridwidth)*ygridwidth+offset;
      above.style.clip = "rect("+y+"px,"+(x+xgridwidth)+"px,"+(y+ygridwidth)+"px,"+x+"px)";
    }
    below.onmousemove = eval(type + "_highlight");
    above.style.visibility = 'visible';
    for (var x in all_above_layer) {
      if (all_above_layer[x] != above) all_above_layer[x].style.visibility = 'hidden';
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
    var Evt = window.event;
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
      if (i == inx) {
	img.src = bbbike_images_dir + "/reddot.png";
      } else {
	img.src = bbbike_images_dir + "/bluedot.png";
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
  if (!document.implementation || !document.implementation.hasFeature("CSS2","2.0")) { // Mozilla 1.1+, Galeon, Firefox
    return;
  }
  var elem = document.getElementById("locateme");
  if (!elem) {
    return;
  }
  elem.style.visibility = "visible";
}

function locate_me() {
  navigator.geolocation.getCurrentPosition(locate_me_cb);
}

function locate_me_cb(position) {
  var pos = position.coords.longitude + "," + position.coords.latitude;
  call_bbbike_api("revgeocode", "lon=" + position.coords.longitude + ";" + "lat=" + position.coords.latitude, locate_me_res);
}

function locate_me_res(res) {
  if (!res) {
    alert("Die Positionierung konnte nicht durchgeführt werden.");
  } else if (!res.bbbikepos) {
    alert("Es konnte keine Position gefunden werden.");
  } else {
    document.forms["BBBikeForm"].elements["start"].value = res.crossing;
    if (typeof transpose_dot_func == "function") {
      var xy = res.bbbikepos.split(/,/);
      var txy = transpose_dot_func(parseInt(xy[0]), parseInt(xy[1]));
      pos_rel("locateme_marker", "startmapbelow", txy[0], txy[1]);
      vis("locateme_marker", "show");
    }
  }
}

function call_bbbike_api(action, params, cb) {
  var client = new XMLHttpRequest();
  client.open("GET", "bbbike.cgi?api=" + action + (params != "" ? ";" + params : ""), true);
  client.send();
  client.onreadystatechange = function() {
    if (this.readyState == 4) { // DONE
      eval("res = " + client.responseText);
      cb(res);
    }
  };
}

// Local variables:
// c-basic-offset: 2
// End:
