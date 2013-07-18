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

// localization
var msg = {"en":{"Kartendaten":"Map data",
		 "Qualit\u00e4t":"Smoothness"
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

var startMarker, goalMarker, loadingMarker;

// globals
var routeLayer;
var searchState = "start";
var startLatLng;
var map;

var defaultLatLng = [52.516224, 13.377463]; // Brandenburger Tor, good for Berlin

var base_map_url_mapping = { 'stable':'http://{s}.tile.bbbike.org/osm/mapnik-german' // will be mapnik-german-srt some day
                             ,'devel1':'http://z.tile.bbbike.org/osm/mapnik-german'
                             ,'devel2':'http://z.tile.bbbike.org/osm/mapnik-german-srt'
                             ,'mapnik-bbbike':'http://z.tile.bbbike.org/osm/mapnik-german-srt' // will point to non-z some day
                             ,'mapnik-osm':'http://{s}.tile.bbbike.org/osm/mapnik'
                             ,'mapnik-german':'http://tile.bbbike.org/osm/mapnik-german'
                           };
var smoothness_map_url_mapping = { 'stable':'http://{s}.tile.bbbike.org/osm/bbbike-smoothness'
                                   ,'devel1':'http://z.tile.bbbike.org/osm/bbbike-smoothness'
                                   ,'devel2':'http://z.tile.bbbike.org/osm/bbbike-smoothness'
                                   ,'mapnik-bbbike':'http://z.tile.bbbike.org/osm/bbbike-smoothness' // will point to non-z some day
                                   ,'mapnik-osm':'http://{s}.tile.bbbike.org/osm/bbbike-smoothness'
                                   ,'mapnik-german':'http://{s}.tile.bbbike.org/osm/bbbike-smoothness'
                                 };

var mapset = q.get('mapset') || 'stable';
var base_map_url = base_map_url_mapping[mapset] || base_map_url_mapping['stable'];
var smoothness_map_url = smoothness_map_url_mapping[mapset] || smoothness_map_url_mapping['stable'];

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
    var bbbikeOrgMapnikGermanUrl = base_map_url + '/{z}/{x}/{y}.png',
    bbbikeAttribution = M("Kartendaten") + ' \u00a9 2012 <a href="http://bbbike.de">Slaven Rezić</a>',
    bbbikeTileLayer = new L.TileLayer(bbbikeOrgMapnikGermanUrl, {maxZoom: 18, attribution: bbbikeAttribution});

    var bbbikeOrgSmoothnessUrl = smoothness_map_url + '/{z}/{x}/{y}.png',
    bbbikeSmoothnessTileLayer = new L.TileLayer(bbbikeOrgSmoothnessUrl, {maxZoom: 18, attribution: bbbikeAttribution});

    var osmMapnikUrl = 'http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    osmAttribution = M("Kartendaten") + ' \u00a9 2012 <a href="http://www.openstreetmap.org/">OpenStreetMap</a> Contributors',
    osmTileLayer = new L.TileLayer(osmMapnikUrl, {maxZoom: 18, attribution: osmAttribution});
    
    map = new L.Map('map',
		    {
			zoomAnimation:false, fadeAnimation:false, // animations may be super-slow, seen on mosor/firefox9
			doubleClickZoom:false, // used for setting start/goal, see below for click/dblclick event
			layers: [bbbikeTileLayer]
		    }
		   );

    var baseMaps = { "BBBike":bbbikeTileLayer, "OSM":osmTileLayer };
    var overlayMaps = {};
    overlayMaps[M("Qualit\u00e4t")] = bbbikeSmoothnessTileLayer;

    var layersControl = new L.Control.Layers(baseMaps, overlayMaps);
    map.addControl(layersControl);

    map.addLayer(bbbikeTileLayer);

    routeLayer = new L.GeoJSON();
    map.addLayer(routeLayer);
    layersControl.addOverlay(routeLayer, "Route");

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
	    container.innerHTML = "LOC";
	    L.DomUtil.addClass(container, "anycontrol_inactive");
	    trackingRunning = false;
	    container.onclick = function() {
		if (trackingRunning) {
		    map.my_stopLocate();
		    L.DomUtil.removeClass(container, "anycontrol_active");
		    L.DomUtil.addClass(container, "anycontrol_inactive");
		    trackingRunning = false;
		    removeLocation();
		} else {
		    map.my_locate({watch:true, setView:false});
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
		trackSegs.addPos(e);
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

    map.on(//'click', //XXX has bugs, may fire on simple zooming
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

    var zoom = q.get("zoom");
    if (!zoom) { zoom = 13 }
    if (initialRouteGeojson) {
	showRoute(initialRouteGeojson);
	map.setView(L.GeoJSON.coordsToLatLng(initialRouteGeojson.geometry.coordinates[0]), zoom);
    } else {
	var lat = q.get("lat");
	var lon = q.get("lon");
	if (lat && lon) {
	    map.setView(new L.LatLng(lat, lon), zoom);
	} else {
	    lat = q.get("mlat");
	    lon = q.get("mlon");
	    if (lat && lon) {
		var center = new L.LatLng(lat, lon);
		map.setView(center, zoom);
		setStartMarker(center);
	    } else {
		map.setView(defaultLatLng, zoom); // Brandenburger Tor
	    }
	}
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

function TrackSegs() {
    this.init();
}
TrackSegs.prototype.init = function() {
    this.polyline = [[]];
    this.upload = [[]];
}
TrackSegs.prototype.addPos = function(e) {
    this.polyline[this.polyline.length-1].push(e.latlng);
    if (enable_upload) {
	var lat = e.latlng.lat.toString().replace(/(\.\d{6}).*/, "$1");
	var lng = e.latlng.lng.toString().replace(/(\.\d{6}).*/, "$1");
	var uplRec = {lat:lat,
		      lng:lng,
		      acc:e.pos.coords.accuracy,
		      time:e.pos.timestamp};
	if (e.pos.coords.altitude != null) {
	    uplRec.alt = e.pos.coords.altitude;
	}
	if (e.pos.coords.altitudeAccuracy != null) {
	    uplRec.altacc = e.pos.coords.altitudeAccuracy;
	}
	this.upload[this.upload.length-1].push(uplRec);
    }
}
TrackSegs.prototype.addGap = function(e) {
    this.polyline.push([]);
    this.upload.push([]);
}
