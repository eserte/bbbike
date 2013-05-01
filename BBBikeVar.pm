# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2000-2010,2012,2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

# BBBike variables and constants

package BBBike;

$VERSION	   = '3.19-DEVEL'; # remove "-DEVEL" for releases
$STABLE_VERSION	   = '3.18';
$WINDOWS_VERSION   = '3.18'; # Windows distribution
$FREEBSD_VERSION   = '3.18'; # (used on download page and bbbikevar.t)
$DEBIAN_I386_VERSION  = '3.18-1'; # including revision
$DEBIAN_AMD64_VERSION = '3.18-1'; # including revision
*DEBIAN_VERSION       = \$DEBIAN_I386_VERSION; # for backward compat

$EMAIL_OLD	   = 'eserte@cs.tu-berlin.de';
$EMAIL		   = 'slaven@rezic.de';
$EMAIL_NEWSTREET   = 'slaven@rezic.de';
# personal homepage
$HOMEPAGE	   = 'http://www.rezic.de/eserte/';
# pointer to WWW version
$BBBIKE_WWW	   = 'http://www.bbbike.de';
# list of additional WWW mirrors
@BBBIKE_WWW_MIRRORS = ('http://bbbike.sourceforge.net/cgi-bin/bbbike.cgi',
		       'http://bbbike.de/cgi-bin/bbbike.cgi',
		       'http://user.cs.tu-berlin.de/~eserte/bbbike/cgi/bbbike.cgi',
		      );
# WWW version, URL for direct access (sometimes www.bbbike.de does not work)
#$BBBIKE_DIRECT_WWW = 'http://user.cs.tu-berlin.de/~eserte/bbbike/cgi/bbbike.cgi';
$BBBIKE_DIRECT_WWW = 'http://bbbike.de/cgi-bin/bbbike.cgi';

# Homepage on Sourceforge
$BBBIKE_SF_WWW	   = 'http://bbbike.sourceforge.net';
# URLs for data update
#$BBBIKE_UPDATE_WWW = "http://bbbike.sourceforge.net/bbbike";
$BBBIKE_UPDATE_DIRECT_WWW = "http://bbbike.de/BBBike";
$BBBIKE_UPDATE_WWW = "http://www.bbbike.de/BBBike";
$BBBIKE_UPDATE_DATA_DIRECT_CGI = "http://bbbike.de/cgi-bin/bbbike-data.cgi";
$BBBIKE_UPDATE_DATA_CGI = "http://www.bbbike.de/cgi-bin/bbbike-data.cgi";
$BBBIKE_UPDATE_DIST_DIRECT_CGI = "http://bbbike.de/cgi-bin/bbbike-snapshot.cgi";
$BBBIKE_UPDATE_DIST_CGI = "http://www.bbbike.de/cgi-bin/bbbike-snapshot.cgi";

# WAP version
$BBBIKE_WAP	   = 'http://bbbike.de/wap';
$BBBIKE_DIRECT_WAP = 'http://bbbike.de/cgi-bin/wapbbbike.cgi';

# m
$BBBIKE_MOBILE	   = 'http://m.bbbike.de';

# Distribution directory for scripts. Unfortunately there's no directory
# index available anymore at sourceforge...
$DISTDIR	   = 'http://sourceforge.net/projects/bbbike/files';
$DISTFILE_SOURCE   = "$DISTDIR/BBBike/$STABLE_VERSION/BBBike-$STABLE_VERSION.tar.gz/download";
$DISTFILE_WINDOWS  = "$DISTDIR/BBBike/$WINDOWS_VERSION/BBBike-$WINDOWS_VERSION-Windows.exe/download";
# Distribution directory for humans (link to 'show files' at sourceforge, and restricted to BBBike)
$DISPLAY_DISTDIR   = 'http://sourceforge.net/projects/bbbike/files/BBBike/';
$LATEST_RELEASE_DISTDIR  = "http://sourceforge.net/projects/bbbike/files/BBBike/$STABLE_VERSION/";
# Contains all BBBike project releases:
$DISPLAY_BBBIKE_PROJECT_DISTDIR   = 'http://sourceforge.net/projects/bbbike/files/';
# These link to the intermediate SourceForge download page (only for humans)
$SF_DISTDIR	      = 'http://sourceforge.net/projects/bbbike/files/BBBike';
$SF_DISTFILE_SOURCE   = "$SF_DISTDIR/$STABLE_VERSION/BBBike-$STABLE_VERSION.tar.gz/download";
# The $SF_DISTFILE_SOURCE URL may cause problems if the client expects that the URL basename is the distribution basename.
# In this case use the following URL.
$SF_DISTFILE_SOURCE_ALT = "http://heanet.dl.sourceforge.net/project/bbbike/BBBike/$STABLE_VERSION/BBBike-$STABLE_VERSION.tar.gz";
$SF_DISTFILE_WINDOWS  = "$SF_DISTDIR/$WINDOWS_VERSION/BBBike-$WINDOWS_VERSION-Windows.exe/download";
$SF_DISTFILE_DEBIAN_I386  = "$SF_DISTDIR/" . join('', $DEBIAN_I386_VERSION =~ m{(^[^-]+)}) . "/bbbike_${DEBIAN_I386_VERSION}_i386.deb/download";
$SF_DISTFILE_DEBIAN_AMD64 = "$SF_DISTDIR/" . join('', $DEBIAN_AMD64_VERSION =~ m{(^[^-]+)}) . "/bbbike_${DEBIAN_AMD64_VERSION}_amd64.deb/download";
*SF_DISTFILE_DEBIAN = \$SF_DISTFILE_DEBIAN_I386; # compatibility
$DISTFILE_FREEBSD_I386 = "ftp://ftp.FreeBSD.org/pub/FreeBSD/ports/i386/packages-stable/All/de-BBBike-3.17_1.tbz";
*DISTFILE_FREEBSD = \$DISTFILE_FREEBSD_I386; # compatibility
$DISTFILE_FREEBSD_ALL  = "http://portsmon.freebsd.org/portoverview.py?category=german&portname=BBBike";

# URL auf die Diplomarbeit
$DIPLOM_URL        = 'http://user.cs.tu-berlin.de/~eserte/diplom/';

# The URL of the mapserver CGI
$BBBIKE_MAPSERVER_URL  = 'http://bbbike.de/cgi-bin/mapserv';
# Address form for mapserver
$BBBIKE_MAPSERVER_ADDRESS_DIRECT_URL = 'http://bbbike.de/cgi-bin/mapserver_address.cgi';
$BBBIKE_MAPSERVER_ADDRESS_URL = 'http://www.bbbike.de/cgi-bin/mapserver_address.cgi';
# The initial mapserver URL (direct)
$BBBIKE_MAPSERVER_DIRECT = 'http://bbbike.de/mapserver/brb/';
# The initial mapserver URL (indirect, from www.bbbike.de)
$BBBIKE_MAPSERVER_INDIRECT = "http://www.bbbike.de/mapserver/brb/";

# git
$BBBIKE_GIT_CLONE_URL = 'git://github.com/eserte/bbbike.git';
$BBBIKE_GIT_HTTP = 'http://github.com/eserte/bbbike';

# CVS (outdated!)
$BBBIKE_CVS_ANON_REPOSITORY = ":pserver:anonymous\@bbbike.cvs.sourceforge.net:/cvsroot/bbbike";
$BBBIKE_CVS_HTTP = 'http://bbbike.cvs.sourceforge.net/viewvc/bbbike/bbbike/';

$BBBIKE_GOOGLEMAP_URL = 'http://bbbike.de/cgi-bin/bbbikegooglemap.cgi';

$BBBIKE_LEAFLET_URL = 'http://bbbike.de/BBBike/html/bbbikeleaflet.html';
$BBBIKE_LEAFLET_CGI_URL = 'http://bbbike.de/cgi-bin/bbbikeleaflet.cgi';

1;

__END__
