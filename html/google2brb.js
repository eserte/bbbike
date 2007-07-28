var custommap;

function google2brb () {
    var centerPoint = null;
    centerPoint = centerQueryString();
    if (!centerPoint) {
        var lat = 52.516193;
        var lon = 13.376991;
        centerPoint = new GLatLng(lat, lon);
    }

    if (GBrowserIsCompatible()) {

        var map = new GMap(document.getElementById("map"));
        map.addControl(new GLargeMapControl());
        map.addControl(new GScaleControl());
      
        CustomGetTileUrl=function(pos,zoom){
            var sx = pos.x - 70404/4;
            var sy = pos.y - 43010/4;
            sy = -sy;
            return "/cgi-bin/gridserv.pl"
            + "?x="  + sx
            + ";y="  + sy
            + ";posx=" + pos.x
            + ";posy=" + pos.y
            + ";zoom=" + zoom
            ;
        }

        // ============================================================
        // ====== Create a single layer "Old OSS" custom maptype ====== 
        //
        // == Create the GTileLayer ==
        var tilelayers = [
                          new GTileLayer(new
                                         GCopyrightCollection(""),16,16)
        ];
        tilelayers[0].getTileUrl = CustomGetTileUrl;
        tilelayers[0].isPng = function (){ return 1 }
        tilelayers[0].getCopyright = function(a,b) {
            return "(c) Slaven Rezic 1995-2006";
        }
      
        // == Create the GMapType, copying most things from G_SATELLITE_MAP ==
        custommap = new GMapType(tilelayers,
                                     G_SATELLITE_MAP.getProjection(),
                                     "BBBikeMaps",
                                 //{tileSize:128,errorMessage:_mMapError}
            {tileSize:512,errorMessage:_mMapError}
                                     );
        
        // == Add the maptype to the map ==
        map.addMapType(custommap);


        // ============================================================
        // ====== Create a two layer  "OSS Hybrid" layer ==============
        
        // === It has two layers one is the "Old OSS" map and the other
        // is the top layer from G_HYBRID_MAP
        var htilelayers = [
                           tilelayers[0], // a reference to the tile
                                          // layer from the first
                                          // custom map
                           G_HYBRID_MAP.getTileLayers()[1] // a
                                                           // reference
                                                           // to the
                                                           // upper
                                                           // tile
                                                           // layer fo
                                                           // the
                                                           // hybrid
                                                           // map
        ];
      
        var custommap2 = new GMapType(htilelayers,
                                      G_SATELLITE_MAP.getProjection(),
                                      "OS Hybrid",
            {maxResolution:14,minResolution:7,errorMessage:_mMapError}
                                      );

        // === Add it to the list of map types ===
        // map.addMapType(custommap2);

        // ============================================================
        map.addControl(new GMapTypeControl());

        map.setCenter(centerPoint, 16, custommap);
        

    } else {
        alert("Sorry, the Google Maps API is not compatible with this browser");
    }
    
    // This Javascript is based on code provided by the
    // Blackpool Community Church Javascript Team
    // http://www.commchurch.freeserve.co.uk/   
    // http://www.econym.demon.co.uk/googlemaps/

}

function centerQueryString() {
    if (location.search) {
        var search = unescape(location.search);
        if (search.match(/center=([^,]*),([^;&]*)/)) {
            var lat = RegExp.$1;
            var lon = RegExp.$2;
            return new GLatLng(lat, lon);
        }
    }
    return null;
}

// Local Variables:
// mode: java
// End:
