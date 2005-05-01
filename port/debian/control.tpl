[% PROCESS "../../BBBikeVar.tpl" -%]
Package: bbbike
Version: [% BBBike.STABLE_VERSION %]
Section: geo
Priority: optional
Architecture: i386
Essential: no
Depends: perl (>= 5.005), perl-tk (>= 800)
Maintainer: Slaven Rezic <srezic@cpan.org>
Suggests: netpbm | imagemagick, gv | ghostview | gs | ggv
Description: BBBike is a route planner for cyclists in Berlin-Brandenburg
 .
 Web page: http://bbbike.sourceforge.net
