[% PROCESS "../../BBBikeVar.tpl" -%]
Package: bbbike
Version: [% BBBike.STABLE_VERSION %]-[% BBBIKE_DEBIAN_REVISION %]
Section: misc
Priority: optional
Architecture: i386
Depends: perl (>= 5.005), perl-tk (>= 800)
Maintainer: Slaven Rezic <srezic@cpan.org>
Suggests: netpbm | imagemagick, gv | ghostview | gs | ggv, libmailtools-perl, libtk-pod-perl, libwww-perl, libxml-libxml-perl, libclass-accessor-perl
Description: A route planner for cyclists in Berlin-Brandenburg
 .
 Web page: http://bbbike.sourceforge.net
