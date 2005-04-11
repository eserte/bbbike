[% PROCESS "../../BBBikeVar.tpl" -%]
Source: bbbike
Section: geo
Priority: optional
Maintainer: Slaven Rezic <srezic@cpan.org>
Package: bbbike
Version: [% BBBike.VERSION.replace("-DEVEL", "") %]
Architecture: any
Depends:  perl (>= 5.005), perl-tk (>= 800)
Suggests: netpbm | imagemagick, gv | ghostview | gs | ggv
Description: BBBike is a route planner for cyclists in Berlin-Brandenburg
 .
 Web page: http://bbbike.sourceforge.net
