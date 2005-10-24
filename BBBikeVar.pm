# -*- perl -*-

#
# $Id: BBBikeVar.pm,v 1.40 2005/10/24 20:04:31 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000-2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

# BBBike variables and constants

package BBBike;

$VERSION	   = '3.15-DEVEL'; # remove "-DEVEL" for releases
$STABLE_VERSION	   = '3.14';
$WINDOWS_VERSION   = '3.14'; # Windows distribution

$EMAIL_OLD	   = 'eserte@cs.tu-berlin.de';
$EMAIL		   = 'slaven@rezic.de';
# personal homepage
$HOMEPAGE	   = 'http://www.rezic.de/eserte/';
# pointer to WWW version
$BBBIKE_WWW	   = 'http://www.bbbike.de';
# list of additional WWW mirrors
@BBBIKE_WWW_MIRRORS = ('http://bbbike.sourceforge.net/cgi-bin/bbbike.cgi',
		       'http://www.radzeit.de/cgi-bin/bbbike.cgi',
		       'http://www.rezic.de/cgi-bin/bbbike.cgi',
		       'http://user.cs.tu-berlin.de/~eserte/bbbike/cgi/bbbike.cgi',
		      );
# WWW version, URL for direct access (sometimes www.bbbike.de does not work)
#$BBBIKE_DIRECT_WWW = 'http://user.cs.tu-berlin.de/~eserte/bbbike/cgi/bbbike.cgi';
$BBBIKE_DIRECT_WWW = 'http://www.radzeit.de/cgi-bin/bbbike.cgi';

# Homepage on Sourceforge
$BBBIKE_SF_WWW	   = 'http://bbbike.sourceforge.net';
# URLs for data update
#$BBBIKE_UPDATE_WWW = "http://bbbike.sourceforge.net/bbbike";
$BBBIKE_UPDATE_WWW = "http://www.radzeit.de/BBBike";
$BBBIKE_UPDATE_DATA_CGI = "http://www.radzeit.de/cgi-bin/bbbike-data.cgi";
#$BBBIKE_UPDATE_RSYNC = 'rsync://www.radzeit.de/bbbike/'; # not yet XXX
#$BBBIKE_UPDATE_DATA_RSYNC = 'rsync://www.radzeit.de/bbbike_data/'; # XXX not yet

# WAP version
$BBBIKE_WAP	   = 'http://bbbike.de/wap';
$BBBIKE_DIRECT_WAP = 'http://www.radzeit.de/cgi-bin/wapbbbike.cgi';

# Sourceforge IDs
$SF_BBBIKE_GROUP_ID = 19142;
$SF_BBBIKE_PACKAGE_ID = 14052;
$SF_BBBIKE_LATEST_RELEASE_ID = 324253; # change for new releases

# Distribution directory for scripts. Unfortunately there's no directory
# index available anymore at sourceforge...
$DISTDIR	   = 'http://heanet.dl.sourceforge.net/sourceforge/bbbike';
$DISTFILE_SOURCE   = "$DISTDIR/BBBike-$STABLE_VERSION.tar.gz";
$DISTFILE_WINDOWS  = "$DISTDIR/BBBike-$WINDOWS_VERSION-Windows.exe";
# Distribution directory for humans (link to 'show files' at sourceforge, and restricted to BBBike)
$DISPLAY_DISTDIR   = 'http://sourceforge.net/project/showfiles.php?group_id=' . $SF_BBBIKE_GROUP_ID . '&package_id=' . $SF_BBBIKE_PACKAGE_ID;
$LATEST_RELEASE_DISTDIR  = 'http://sourceforge.net/project/showfiles.php?group_id=' . $SF_BBBIKE_GROUP_ID . '&package_id=' . $SF_BBBIKE_PACKAGE_ID . '&release_id=' . $SF_BBBIKE_LATEST_RELEASE_ID;

# URL auf die Diplomarbeit
$DIPLOM_URL        = 'http://user.cs.tu-berlin.de/~eserte/diplom/';

# The URL of the mapserver CGI
$BBBIKE_MAPSERVER_URL  = 'http://www.radzeit.de/cgi-bin/mapserv';
# Address form for mapserver
$BBBIKE_MAPSERVER_ADDRESS_URL = 'http://www.radzeit.de/cgi-bin/mapserver_address.cgi';
# The initial mapserver URL (direct)
$BBBIKE_MAPSERVER_DIRECT = 'http://www.radzeit.de/mapserver/brb/';
# The initial mapserver URL (indirect, from www.bbbike.de)
$BBBIKE_MAPSERVER_INDIRECT = "http://www.bbbike.de/mapserver/brb/";

# CVS
$BBBIKE_CVS_ANON_REPOSITORY = ":pserver:anonymous\@cvs.sourceforge.net:/cvsroot/bbbike";
$BBBIKE_CVS_HTTP = "http://sourceforge.net/cvs/?group_id=" . $SF_BBBIKE_GROUP_ID;

1;

__END__
