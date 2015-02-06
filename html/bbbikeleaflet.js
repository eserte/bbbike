// URL layout, lang detection
var thisURL = location.href;
var lang = "de";
if (thisURL.match(/bbbikeleaflet\.en\./)) {
    lang = "en";
    thisURL = thisURL.replace(/bbbikeleaflet\.en\./, "bbbikeleaflet.");
}
var useOldURLLayout = thisURL.match(/(cgi\/bbbikeleaflet|bbbike\/html\/bbbikeleaflet)/);
var bbbikeRoot, cgiURL, bbbikeImagesRoot;
if (useOldURLLayout) {
    bbbikeRoot = thisURL.replace(/\/(cgi|html)\/bbbikeleaflet\..*/, "");
    bbbikeImagesRoot = bbbikeRoot + "/images";
    cgiURL     = bbbikeRoot + "/cgi/bbbike.cgi";
} else {
    bbbikeRoot = thisURL.replace(/\/(cgi-bin|BBBike\/html)\/bbbikeleaflet\..*/, "");
    bbbikeImagesRoot = bbbikeRoot + "/BBBike/images";
    cgiURL     = bbbikeRoot + "/cgi-bin/bbbike.cgi";
}

var q = new HTTP.Query;
if (q.get("lang") == "de") {
    lang = "de";
} else if (q.get("lang") == "en") {
    lang = "en";
}

var initLayerAbbrevs = q.get('l');
if (initLayerAbbrevs) {
    initLayerAbbrevs = initLayerAbbrevs.split(",");
} else {
    initLayerAbbrevs = [];
}

// localization
var msg = {"en":{"Kartendaten":"Map data",
		 "Qualit\u00e4t":"Smoothness",
		 "Radwege":"Cycleways",
		 "Unbeleuchtet":"Unlit",
		 "Gr\u00fcne Wege":"Green ways",
		 "Fragezeichen":"Unknown"
		}
	  };
function M(string) {
    if (msg[lang] && msg[lang][string]) {
	return msg[lang][string];
    } else {
	return string;
    }
}

// icons and markers
var startIcon = L.icon({
    iconUrl: bbbikeImagesRoot + "/flag2_bl_centered.png",
    shadowUrl: bbbikeImagesRoot + "/flag_shadow.png",
    iconSize: new L.Point(32,32),
    shadowSize: new L.Point(45,24),
    iconAnchor: new L.Point(16,16)
});

var goalIcon = L.icon({
    iconUrl: bbbikeImagesRoot + "/flag_ziel_centered.png",
    shadowUrl: bbbikeImagesRoot + "/flag_shadow.png",
    iconSize: new L.Point(32,32),
    shadowSize: new L.Point(45,24),
    iconAnchor: new L.Point(16,16)
});

var loadingIcon = L.icon({
    iconUrl: bbbikeImagesRoot + "/loading.gif",
    shadowUrl: bbbikeImagesRoot + "/px_1t.gif",
    iconSize: new L.Point(16,16),
    shadowSize: new L.Point(1,1),
    iconAnchor: new L.Point(0,0)
});

var nightIcon = L.icon({
    iconUrl: bbbikeImagesRoot + "/night.png",
    shadowUrl: bbbikeImagesRoot + "/px_1t.gif",
    iconSize: new L.Point(12,14),
    shadowSize: new L.Point(1,1),
    iconAnchor: new L.Point(6,7)
});

var clockIcon = L.icon({
    iconUrl: bbbikeImagesRoot + "/clock.png",
    shadowUrl: bbbikeImagesRoot + "/px_1t.gif",
    iconSize: new L.Point(13,13),
    shadowSize: new L.Point(1,1),
    iconAnchor: new L.Point(6,6)
});

var inworkIcon = L.icon({
    iconUrl: bbbikeImagesRoot + "/inwork_12.png",
    shadowUrl: bbbikeImagesRoot + "/px_1t.gif",
    iconSize: new L.Point(12,11),
    shadowSize: new L.Point(1,1),
    iconAnchor: new L.Point(6,6)
});

var startMarker, goalMarker, loadingMarker;

var id2marker;

// globals
var routeLayer;
var searchState = "start";
var startLatLng;
var map;
var routelistPopup;

var defaultLatLng = [52.516224, 13.377463]; // Brandenburger Tor, good for Berlin
var defaultZoom = 13;

var devel_tile_letter = 'a'; // or 'z' or 'y'

var base_map_url_mapping = { 'stable':'http://{s}.tile.bbbike.org/osm/bbbike'
                             ,'devel1':'http://' + devel_tile_letter + '.tile.bbbike.org/osm/bbbike'
                             ,'devel2':'http://' + devel_tile_letter + '.tile.bbbike.org/osm/mapnik-german'
                             ,'mapnik-osm':'http://{s}.tile.bbbike.org/osm/mapnik'
                             ,'mapnik-german':'http://{s}.tile.bbbike.org/osm/mapnik-german'
                           };
var smoothness_map_url_mapping = { 'stable':'http://{s}.tile.bbbike.org/osm/bbbike-smoothness'
                                   ,'devel1':'http://' + devel_tile_letter + '.tile.bbbike.org/osm/bbbike-smoothness'
                                 };
var handicap_map_url_mapping = { 'stable':'http://{s}.tile.bbbike.org/osm/bbbike-handicap'
                                 ,'devel1':'http://' + devel_tile_letter + '.tile.bbbike.org/osm/bbbike-handicap'
                               };
var cycleway_map_url_mapping = { 'stable':'http://{s}.tile.bbbike.org/osm/bbbike-cycleway'
                                 ,'devel1':'http://' + devel_tile_letter + '.tile.bbbike.org/osm/bbbike-cycleway'
                               };
var unlit_map_url_mapping = { 'stable':'http://{s}.tile.bbbike.org/osm/bbbike-unlit'
                              ,'devel1':'http://' + devel_tile_letter + '.tile.bbbike.org/osm/bbbike-unlit'
                            };
var green_map_url_mapping = { 'stable':'http://{s}.tile.bbbike.org/osm/bbbike-green'
                              ,'devel1':'http://' + devel_tile_letter + '.tile.bbbike.org/osm/bbbike-green'
                            };
var unknown_map_url_mapping = { 'stable':'http://{s}.tile.bbbike.org/osm/bbbike-unknown'
                                ,'devel1':'http://' + devel_tile_letter + '.tile.bbbike.org/osm/bbbike-unknown'
                              };

var mapset = q.get('mapset') || 'stable';
var base_map_url = base_map_url_mapping[mapset] || base_map_url_mapping['stable'];
var smoothness_map_url = smoothness_map_url_mapping[mapset] || smoothness_map_url_mapping['stable'];
var handicap_map_url = handicap_map_url_mapping[mapset] || handicap_map_url_mapping['stable'];
var cycleway_map_url = cycleway_map_url_mapping[mapset] || cycleway_map_url_mapping['stable'];
var unlit_map_url = unlit_map_url_mapping[mapset] || unlit_map_url_mapping['stable'];
var green_map_url = green_map_url_mapping[mapset] || green_map_url_mapping['stable'];
var unknown_map_url = unknown_map_url_mapping[mapset] || unknown_map_url_mapping['stable'];
var accel;

/*
 * Provides L.Map with convenient shortcuts for using browser geolocation features.
 * This is Map.Geolocation.js with own changes.
 */
var L_Util = L.Util || L;
L.Map.include({
	_my_defaultLocateOptions: {
		watch: false,
		setView: false,
		maxZoom: Infinity,
		timeout: 10000,
		maximumAge: 0,
		enableHighAccuracy: false
	},

	my_locate: function (/*Object*/ options) {

		options = this._my_locateOptions = L_Util.extend(this._my_defaultLocateOptions, options);

		if (!navigator.geolocation) {
			this._my_handleGeolocationError({
				code: 0,
				message: 'Geolocation not supported.'
			});
			return this;
		}

		var onResponse = L_Util.bind(this._my_handleGeolocationResponse, this),
			onError = L_Util.bind(this._my_handleGeolocationError, this);

		if (options.watch) {
			this._my_locationWatchId =
			        navigator.geolocation.watchPosition(onResponse, onError, options);
		} else {
			navigator.geolocation.getCurrentPosition(onResponse, onError, options);
		}
		return this;
	},

	my_stopLocate: function () {
		if (navigator.geolocation) {
			navigator.geolocation.clearWatch(this._my_locationWatchId);
		}
		if (this._my_locateOptions) {
			this._my_locateOptions.setView = false;
		}
		return this;
	},

	_my_handleGeolocationError: function (error) {
		var c = error.code,
		    message = error.message ||
		            (c === 1 ? 'permission denied' :
		            (c === 2 ? 'position unavailable' : 'timeout'));

		if (this._my_locateOptions.setView && !this._loaded) {
			this.fitWorld();
		}

		this.fire('locationerror', {
			code: c,
			message: 'Geolocation error: ' + message + '.'
		});
	},

	_my_handleGeolocationResponse: function (pos) {
		var lat = pos.coords.latitude,
		    lng = pos.coords.longitude,
		    latlng = new L.LatLng(lat, lng),

		    latAccuracy = 180 * pos.coords.accuracy / 40075017,
		    lngAccuracy = latAccuracy / Math.cos(L.LatLng.DEG_TO_RAD * lat),

		    bounds = L.latLngBounds(
		            [lat - latAccuracy, lng - lngAccuracy],
		            [lat + latAccuracy, lng + lngAccuracy]),

		    options = this._my_locateOptions;

		if (options.setView) {
			var zoom = Math.min(this.getBoundsZoom(bounds), options.maxZoom);
			this.setView(latlng, zoom);
		}

		var data = {
			latlng: latlng,
			bounds: bounds,
			pos: pos
		};

		// for (var i in pos.coords) {
		// 	if (typeof pos.coords[i] === 'number') {
		// 		data[i] = pos.coords[i];
		// 	}
		// }

		this.fire('locationfound', data);
	}
});

function doLeaflet() {
    var nowYear = new Date().getFullYear();

    var bbbikeOrgMapnikGermanUrl = base_map_url + '/{z}/{x}/{y}.png';
    var bbbikeAttribution = M("Kartendaten") + ' \u00a9 ' + nowYear + ' <a href="http://bbbike.de">Slaven Rezić</a>';
    var bbbikeTileLayer = new L.TileLayer(bbbikeOrgMapnikGermanUrl, {maxZoom: 18, attribution: bbbikeAttribution});

    var bbbikeOrgSmoothnessUrl = smoothness_map_url + '/{z}/{x}/{y}.png';
    var bbbikeSmoothnessTileLayer = new L.TileLayer(bbbikeOrgSmoothnessUrl, {maxZoom: 18, attribution: bbbikeAttribution});

    var bbbikeOrgHandicapUrl = handicap_map_url + '/{z}/{x}/{y}.png';
    var bbbikeHandicapTileLayer = new L.TileLayer(bbbikeOrgHandicapUrl, {maxZoom: 18, attribution: bbbikeAttribution});

    var bbbikeOrgCyclewayUrl = cycleway_map_url + '/{z}/{x}/{y}.png';
    var bbbikeCyclewayTileLayer = new L.TileLayer(bbbikeOrgCyclewayUrl, {maxZoom: 18, attribution: bbbikeAttribution});

    var bbbikeOrgUnlitUrl = unlit_map_url + '/{z}/{x}/{y}.png';
    var bbbikeUnlitTileLayer = new L.TileLayer(bbbikeOrgUnlitUrl, {maxZoom: 18, attribution: bbbikeAttribution});

    var bbbikeOrgGreenUrl = green_map_url + '/{z}/{x}/{y}.png';
    var bbbikeGreenTileLayer = new L.TileLayer(bbbikeOrgGreenUrl, {maxZoom: 18, attribution: bbbikeAttribution});

    var bbbikeOrgUnknownUrl = unknown_map_url + '/{z}/{x}/{y}.png';
    var bbbikeUnknownTileLayer = new L.TileLayer(bbbikeOrgUnknownUrl, {maxZoom: 18, attribution: bbbikeAttribution});

    var osmMapnikUrl = use_osm_de_map ? 'http://tile.openstreetmap.de/tiles/osmde/{z}/{x}/{y}.png' : 'http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
    var osmAttribution = M("Kartendaten") + ' \u00a9 ' + nowYear + ' <a href="http://www.openstreetmap.org/">OpenStreetMap</a> Contributors';
    var osmTileLayer = new L.TileLayer(osmMapnikUrl, {maxZoom: 18, attribution: osmAttribution});
    
    map = new L.Map('map',
		    {
			zoomAnimation:false, fadeAnimation:false, // animations may be super-slow, seen on mosor/firefox9
			doubleClickZoom:disable_routing, // used for setting start/goal, see below for click/dblclick event
			layers: [bbbikeTileLayer]
		    }
		   );

    var overlayDefs = [
	{label:M("Qualit\u00e4t"),   layer:bbbikeSmoothnessTileLayer, abbrev:'Q'},
	{label:M("Handicaps"),       layer:bbbikeHandicapTileLayer,   abbrev:'H'},
	{label:M("Radwege"),         layer:bbbikeCyclewayTileLayer,   abbrev:'RW'},
	{label:M("Unbeleuchtet"),    layer:bbbikeUnlitTileLayer,      abbrev:'NL'},
	{label:M("Gr\u00fcne Wege"), layer:bbbikeGreenTileLayer,      abbrev:'GR'},
	{label:M("Fragezeichen"),    layer:bbbikeUnknownTileLayer,    abbrev:'FZ'}
    ];

    var baseMaps = { "BBBike":bbbikeTileLayer, "OSM":osmTileLayer };
    var overlayMaps = {};
    for(var i=0; i<overlayDefs.length; i++) {
        overlayMaps[overlayDefs[i].label] = overlayDefs[i].layer;
    }

    if (initLayerAbbrevs.length) {
	var abbrevToLayer = {};
	for(var i=0; i<overlayDefs.length; i++) {
	    abbrevToLayer[overlayDefs[i].abbrev] = overlayDefs[i].layer;
	}
	for(var i=0; i<initLayerAbbrevs.length; i++) {
	    var l = abbrevToLayer[initLayerAbbrevs[i]];
	    if (l) {
		map.addLayer(l);
	    } else {
		if (console && console.debug) {
		    console.debug("Layer abbrev '" + initLayerAbbrevs[i] + "' unhandled");
		}
	    }
	}
    }

    var layersControl = new L.Control.Layers(baseMaps, overlayMaps);
    map.addControl(layersControl);

    map.addLayer(bbbikeTileLayer);

    routeLayer = new L.GeoJSON();
    map.addLayer(routeLayer);

    if (enable_accel) {
	accel = new AccelHandler();
    }

    var trackPolyline;
    var trackSegs = new TrackSegs();
    var lastLatLon = null;
    var trackingRunning;
    var LocControl = L.Control.extend({
	options: {
	    position: 'bottomleft'
	},

	onAdd: function (map) {
	    var container = L.DomUtil.create('div', 'anycontrol');
	    var label = "LOC";
	    if (enable_accel) {
		label += "+ACCEL";
	    }
	    container.innerHTML = label;
	    L.DomUtil.addClass(container, "anycontrol_inactive");
	    trackingRunning = false;
	    container.onclick = function() {
		if (trackingRunning) {
		    map.my_stopLocate();
		    if (accel) {
			accel.stop();
		    }
		    L.DomUtil.removeClass(container, "anycontrol_active");
		    L.DomUtil.addClass(container, "anycontrol_inactive");
		    trackingRunning = false;
		    removeLocation();
		} else {
		    map.my_locate({watch:true, setView:false});
		    if (accel) {
			accel.start();
		    }
		    L.DomUtil.removeClass(container, "anycontrol_inactive");
		    L.DomUtil.addClass(container, "anycontrol_active");
		    trackingRunning = true;
		}
	    };
	    return container;
	}
    });
    map.addControl(new LocControl());

    var ClrControl = L.Control.extend({
	options: {
	    position: 'bottomleft'
	},

	onAdd: function (map) {
	    var container = L.DomUtil.create('div', 'anycontrol anycontrol_inactive');
	    container.innerHTML = "CLR";
	    container.onclick = function() {
		if (confirm("Clear track?")) {
		    trackSegs.init();
		    if (trackPolyline && map.hasLayer(trackPolyline)) {
			map.removeLayer(trackPolyline);
		    }
		    trackPolyline = L.multiPolyline(trackSegs.polyline, {color:'#f00', weight:2, opacity:0.7}).addTo(map);
		    lastLatLon = null;
		}
	    };
	    return container;
	}
    });
    map.addControl(new ClrControl());

    if (enable_upload) {
	var UplControl = L.Control.extend({
	    options: {
		position: 'bottomleft'
	    },

	    onAdd: function (map) {
		var container = L.DomUtil.create('div', 'anycontrol anycontrol_inactive');
		container.innerHTML = "UPL";
		container.onclick = function() {
		    L.DomUtil.removeClass(container, "anycontrol_inactive");
		    L.DomUtil.addClass(container, "anycontrol_active");
		    var serialized = JSON.stringify({ua:navigator.userAgent, trackSegs:trackSegs.upload});
		    var uploadRequest = new XMLHttpRequest();
		    uploadRequest.open("POST", "upload-track.cgi", false);
		    uploadRequest.send(serialized);
		    if (uploadRequest.status == 200) {
			alert("Upload response: " + uploadRequest.responseText);
		    } else {
			alert("Error while uploading track: " + uploadRequest.status);
		    }
		    L.DomUtil.removeClass(container, "anycontrol_active");
		    L.DomUtil.addClass(container, "anycontrol_inactive");
		};
		return container;
	    }
	});
	map.addControl(new UplControl());
    }

    var locationCircle = L.circle(defaultLatLng, 10); // XXX better or no defaults?
    var locationPoint = L.circle(defaultLatLng, 2); // XXX better or no defaults
    locationCircle.setStyle({stroke:true,color:'#03f',weight:4,opacity:0.5,
                             fill:true,fillColor:'#36f',fillOpacity:0.2,
			     clickable:false});
    locationPoint.setStyle({stroke:true,color:'#03f',weight:2,opacity:0.5,
                            fill:true,fillColor:'#03f',fillOpacity:0.5,
			    clickable:false});
    function locationFoundOrNot(type, e) {
	if (type == "locationfound") {
	    locationCircle.setLatLng(e.latlng);
	    locationCircle.setRadius(e.pos.coords.accuracy);
	    if (!map.hasLayer(locationCircle)) {
		locationCircle.addTo(map);
	    }
	    locationPoint.setLatLng(e.latlng);
	    if (!map.hasLayer(locationPoint)) {
		locationPoint.addTo(map);
	    }
	    map.panTo(e.latlng);
	    if (!lastLatLon || !lastLatLon.equals(e.latlng)) {
		var accelres = accel ? accel.flush() : null;
		trackSegs.addPos(e, accelres);
		lastLatLon = e.latlng;
		if (trackPolyline && map.hasLayer(trackPolyline)) {
		    map.removeLayer(trackPolyline);
		}
		trackPolyline = L.multiPolyline(trackSegs.polyline, {color:'#f00', weight:2, opacity:0.7}).addTo(map);
	    }
	} else {
	    removeLocation();
	    if (lastLatLon != null) {
		trackSegs.addGap();
		lastLatLon = null;
	    }
	}
    }
    map.on('locationfound', function(e) { locationFoundOrNot('locationfound', e); });
    map.on('locationerror', function(e) { locationFoundOrNot('locationerror', e); });

    function removeLocation() {
	if (locationCircle && map.hasLayer(locationCircle)) {
	    map.removeLayer(locationCircle);
	}
	if (locationPoint && map.hasLayer(locationPoint)) {
	    map.removeLayer(locationPoint);
	}
    }

    if (!disable_routing) {
	map.on(
            'dblclick', function(e) {
		if (searchState == "start") {
		    startLatLng = e.latlng;

		    if (goalMarker) {
			map.removeLayer(goalMarker);
		    }
		    setStartMarker(startLatLng);

		    searchState = 'goal';
		} else if (searchState == "goal") {
		    setGoalMarker(e.latlng);

		    searchRoute(startLatLng, e.latlng);
		} else if (searchState == "searching") {
		    // nop
		}
	    });
    }

    var setViewLatLng;
    var setViewZoom;
    var setViewLayer;

    id2marker = {};

    if (initialRouteGeojson) {
	showRoute(initialRouteGeojson);
	setViewLatLng = L.GeoJSON.coordsToLatLng(initialRouteGeojson.geometry.coordinates[0]);
    } else if (initialGeojson) {
	if (show_feature_list) { // auto-id numbering
	    var features = initialGeojson.features;
	    var id = 0;
	    for(var i = 0; i < features.length; i++) {
		features[i].properties.id = ++id;
	    }
	}
	var l = L.geoJson(initialGeojson, {
            style: function (feature) {
		if (feature.properties.cat.match(/^(1|2|3|q\d)::(night|temp|inwork);?/)) {
                    var attrib = RegExp.$2;
                    var latLngs = L.GeoJSON.coordsToLatLngs(feature.geometry.coordinates);
                    var centerLatLng = getLineStringCenter(latLngs);
                    var l;
                    if (attrib == 'night') {
			l = L.marker(centerLatLng, { icon: nightIcon });
                    } else if (attrib == 'temp') {
			l = L.marker(centerLatLng, { icon: clockIcon });
                    } else if (attrib == 'inwork') {
			l = L.marker(centerLatLng, { icon: inworkIcon });
                    }
                    l.addTo(map);
                    l.bindPopup(feature.properties.name);
                    return { //dashArray: [2,2],
			color: "#f00", weight: 5, lineCap: "butt" }
		}
            },
            onEachFeature: function (feature, layer) {
		layer.bindPopup(feature.properties.name);
		id2marker[feature.properties.id] = layer;
            }
	});
	l.addTo(map);
	setViewLayer = l;
    } else {
	var lat = q.get("mlat");
	var lon = q.get("mlon");
	if (lat && lon) {
	    var center = new L.LatLng(lat, lon);
	    setViewLatLng = center;
	    setStartMarker(center);
	}
    }

    if (!setViewLatLng) {
	var lat = q.get("lat");
	var lon = q.get("lon");
	if (lat && lon) {
	    setViewLatLng = new L.LatLng(lat, lon);
	}
    }
    if (setViewLayer && !setViewLatLng) {
	map.fitBounds(setViewLayer.getBounds());
    } else {
	if (!setViewLatLng) {
	    setViewLatLng = defaultLatLng;
	}    
	if (!setViewZoom) {
	    setViewZoom = q.get("zoom") || defaultZoom;
	}
	map.setView(setViewLatLng, setViewZoom);
    }

    if (show_feature_list && initialGeojson) {
	var listHtml = '';
	var features = initialGeojson.features;
	for(var i = 0; i < features.length; i++) {
	    var featureProperties = features[i].properties
	    if (featureProperties) {
		listHtml += "\n" + '<a href="javascript:showMarker(' + featureProperties.id + ')">' + featureProperties.name + '</a><br><hr>';
	    }
	}

	setFeatureListContent(listHtml);
    }
}

function setFeatureListContent(listHtml) {
    var listDiv = document.getElementById('list');
    listDiv.innerHTML = listHtml;
    listDiv.style.visibility = 'visible';
    listDiv.style.overflowY = 'scroll';
    listDiv.style.width = '20%';
    listDiv.style.height = '100%';
    listDiv.style.padding = '3px';
}

function showMarker(id) {
    var marker = id2marker[id];
    if (marker) {
	marker.openPopup();
    } else {
	alert('Sorry, no marker with id ' + id);
    }
}

function getSearchCoordParams(startPoint, goalPoint) {
    return "startc_wgs84=" + startPoint.lng + "," + startPoint.lat + ";zielc_wgs84=" + goalPoint.lng + "," + goalPoint.lat;
}

// XXX do not hardcode!
var commonSearchParams = ";pref_seen=1;pref_speed=20;pref_cat=;pref_quality=;pref_green=;scope=;referer=bbbikeleaflet;output_as=geojson";

function searchRoute(startPoint, goalPoint) {
    searchState = 'searching';
    var searchCoordParams = getSearchCoordParams(startPoint, goalPoint);
    var requestLine = cgiURL + "?" + searchCoordParams + commonSearchParams;
    var routeRequest = new XMLHttpRequest();
    routeRequest.open("GET", requestLine, true);
    setLoadingMarker(goalPoint);
    routeRequest.onreadystatechange = function() {
	showRouteResult(routeRequest);
    };
    routeRequest.send(null);
}

function showRouteResult(request) {
    if (request.readyState == 4) {
	if (request.status != 200) {
	    alert("Error calculating route: " + request.statusText  + " (status=" + request.status + ")");
	} else {
	    var geojson;
	    var json = "geojson = " + request.responseText;
	    eval(json);
	    showRoute(geojson);
	    if (show_feature_list) {
		populateRouteList(geojson);
	    }
	}
	map.removeLayer(loadingMarker);
	searchState = 'start';
    }
}

function showRoute(geojson) {
    routeLayer.clearLayers();
    routeLayer.addData(geojson);
    var coordinatesLength = geojson.geometry.coordinates.length;
    if (coordinatesLength) {
	setStartMarker(L.GeoJSON.coordsToLatLng(geojson.geometry.coordinates[0]));
	setGoalMarker (L.GeoJSON.coordsToLatLng(geojson.geometry.coordinates[coordinatesLength-1]));
    }
}

function setStartMarker(latLng) {
    if (!startMarker) {
	startMarker = new L.Marker(latLng, {icon:startIcon});
    } else {
	startMarker.setLatLng(latLng);
    }
    map.addLayer(startMarker);
}

function setGoalMarker(latLng) {
    if (!goalMarker) {
	goalMarker = new L.Marker(latLng, {icon:goalIcon});
    } else {
	goalMarker.setLatLng(latLng);
    }
    map.addLayer(goalMarker);
}

function setLoadingMarker(latLng) {
    if (!loadingMarker) {
	loadingMarker = new L.Marker(latLng, {icon:loadingIcon});
    } else {
	loadingMarker.setLatLng(latLng);
    }
    map.addLayer(loadingMarker);
}

function populateRouteList(geojson) {
    var result = geojson.properties.result;
    var route = result.Route;

    var html = "<div>Länge: " + sprintf("%.2f", result.Len / 1000) + " km</div>\n";

    var pref_speed;
    var pref_time;
    for(var speed in result.Speed) {
	if (result.Speed[speed].Pref == "1") {
	    pref_speed = speed;
	    pref_time = result.Speed[speed].Time;
	    break;
	}
    }
    if (pref_speed) {
	var h = parseInt(pref_time);
	var m = parseInt((pref_time-h)*60);
	html += "<div>Fahrzeit (" + pref_speed + " km/h): " + h + "h" + m + "min</div>\n";
    }

    // XXX duplicated in cgi
    var rawDirectionToArrow = {'l':  '&#x21d0;',
			       'hl': '&#x21d6;',
			       'hr': '&#x21d7;',
			       'r':  '&#x21d2;',
			       'u':  '&#x21b6;',
			      };
    html += "<table>\n";
    html += "<tr><th>Etappe</th><th></th><th>Straße</th></tr>\n";
    for(var i=0; i<route.length; i++) {
	var elem = route[i];
	html += "<tr>";
	html += "<td style='text-align:right;'>" + sprintf("%.2f", elem.Dist/1000) + " km</td>";
	html += "<td>" + (rawDirectionToArrow[elem.Direction] || '') + "</td>";
	var coord = L.GeoJSON.coordsToLatLng(geojson.geometry.coordinates[elem.PathIndex]);
	html += '<td onclick="showStreet(' + "'" + escapeHtml(elem.Strname) + "'" + ', '+coord.lat+','+coord.lng+')">' + escapeHtml(elem.Strname) + "</a></td>";
	html += "</tr>\n";
    }
    html += "</table>\n";
    html += "</div>\n";

    setFeatureListContent(html);
}

function showStreet(strname, lat, lng) {
    map.openPopup(strname, new L.LatLng(lat,lng));
}

// from https://gist.github.com/BMintern/1795519
// XXX is this fine or too hackish?
function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
}

function getLineStringCenter(latLngArray) {
    if (latLngArray.length == 1) {
       return latLngArray[0];
    }
    var len = 0;
    for(var i=1; i<latLngArray.length; i++) {
       len += latLngArray[i].distanceTo(latLngArray[i-1]);
    }
    var len0 = 0;
    for(var i=1; i<latLngArray.length; i++) {
       len0 += latLngArray[i].distanceTo(latLngArray[i-1]);
       if (len0 > len/2) {
           // XXX ungenau, besser machen!
           var newLat = (latLngArray[i].lat - latLngArray[i-1].lat)/2 + latLngArray[i-1].lat;
           var newLng = (latLngArray[i].lng - latLngArray[i-1].lng)/2 + latLngArray[i-1].lng;
           return L.latLng(newLat, newLng);
       }
    }
    // should never be reached
}

////////////////////////////////////////////////////////////////////////

function AccelHandler() {
    this.scrollarray = new ScrollArray(20);
}

AccelHandler.prototype.start = function() {
    var _this = this;
    this.devicemotionlistener = function(event) {
	var now = Date.now();
	var g = event.accelerationIncludingGravity;
	_this.scrollarray.push({'x':g.x,'y':g.y,'z':g.z,'time':now});
    };
    this.scrollarray.empty();
    window.addEventListener("devicemotion", this.devicemotionlistener, true);
};

AccelHandler.prototype.stop = function() {
    if (this.devicemotionlistener) {
	window.removeEventListener("devicemotion", this.devicemotionlistener, true);
	this.devicemotionlistener = null;
    }
};

AccelHandler.prototype.flush = function() {
    var res = this.scrollarray.as_array();
    this.scrollarray.empty();
    return res;
};

//////////////////////////////////////////////////////////////////////

function TrackSegs() {
    this.init();
}
TrackSegs.prototype.init = function() {
    this.polyline = [[]];
    this.upload = [[]];
};
TrackSegs.prototype.addPos = function(e, accelres) {
    this.polyline[this.polyline.length-1].push(e.latlng);
    if (enable_upload) {
	var uplRec = {lat:this._trimDigits(e.latlng.lat, 6),
		      lng:this._trimDigits(e.latlng.lng, 6),
		      acc:this._trimDigits(e.pos.coords.accuracy, 1),
		      time:e.pos.timestamp};
	if (e.pos.coords.altitude != null) {
	    uplRec.alt = e.pos.coords.altitude;
	}
	if (e.pos.coords.altitudeAccuracy != null) {
	    uplRec.altacc = this._trimDigits(e.pos.coords.altitudeAccuracy,1);
	}
	if (accelres) {
	    var accelUplRecs = [];
	    var firstTime;
	    for(var i=0; i<accelres.length; i++) {
		var accelUplRec = {x:this._trimDigits(accelres[i].x, 2),
				   y:this._trimDigits(accelres[i].y, 2),
				   z:this._trimDigits(accelres[i].z, 2)};
		if (i == 0) {
		    accelUplRec.time = accelres[i].time;
		    firstTime = accelres[i].time;
		} else {
		    accelUplRec.dt = accelres[i].time - firstTime;
		}
		accelUplRecs.push(accelUplRec);
	    }
	    uplRec.accel = accelUplRecs;
	}
	this.upload[this.upload.length-1].push(uplRec);
    }
};
TrackSegs.prototype.addGap = function(e) {
    this.polyline.push([]);
    this.upload.push([]);
};
TrackSegs.prototype._trimDigits = function(num,digits) {
    return num.toString().replace(new RegExp("(\\.\\d{" + digits + "}).*"), "$1");
};
