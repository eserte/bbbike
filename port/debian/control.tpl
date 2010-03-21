[% PROCESS "../../BBBikeVar.tpl" -%]
Package: bbbike
Version: [% BBBike.STABLE_VERSION %]-[% BBBIKE_DEBIAN_REVISION %]
Section: misc
Priority: optional
Architecture: i386
Depends: perl (>= 5.005), perl-tk (>= 800)
Maintainer: Slaven Rezic <[% BBBike.EMAIL %]>
Suggests: netpbm | imagemagick, gv | ghostview | gs | ggv, libmailtools-perl, libtk-pod-perl, libwww-perl, libxml-libxml-perl, libclass-accessor-perl
Description: A route planner for cyclists in Berlin-Brandenburg
 BBBike is an information system for cyclists in Berlin and
 Brandenburg (Germany). The application has the following
 features:
 .
  * Display a map with streets, railways, rivers, parks,
    altitude and other features
 .
  * Find and show routes between two points. The route-finder
    can be customized to match the cyclists preferences
    (fastest or nicest route, keep wind direction and hills
    into account etc.)
 .
  * A bike power calculator
 .
  * Automatically fetch current Berlin weather data
 .
 Web page: [% BBBike.BBBIKE_SF_WWW %]
