# -*- perl -*-

#
# $Id: BBBikeVar.pm,v 1.23 2003/05/19 05:50:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000-2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sf.net/
#

# BBBike variables and constants

package BBBike;

$VERSION	   = '3.12'; # remove "-DEVEL" for releases

$EMAIL_OLD	   = 'eserte@cs.tu-berlin.de';
$EMAIL		   = 'slaven@rezic.de';
# personal homepage
$HOMEPAGE	   = 'http://www.rezic.de/eserte/';
# pointer to WWW version
$BBBIKE_WWW	   = 'http://www.bbbike.de';
# list of additional WWW mirrors
@BBBIKE_WWW        = ('http://bbbike.sourceforge.net/cgi-bin/bbbike.cgi',
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
$BBBIKE_UPDATE_WWW = "http://bbbike.sourceforge.net/bbbike";
#$BBBIKE_UPDATE_RSYNC = 'rsync://www.radzeit.de/bbbike/'; # not yet XXX
$BBBIKE_UPDATE_DATA_RSYNC = 'rsync://www.radzeit.de/bbbike_data/';

# WAP version
$BBBIKE_WAP	   = 'http://www.radzeit.de/cgi-bin/wapbbbike.cgi';
# distribution directory for scripts:
$DISTDIR	   = 'http://prdownloads.sourceforge.net/bbbike';
# distribution directory for humans (entry to 'show files' at sourceforge)
$DISPLAY_DISTDIR   = 'http://sourceforge.net/project/showfiles.php?group_id=19142';
# XXX not used ... should be moved to sourceforge, too
# XXX first check whether I can connect to a subdir of cgi-bin, then
# try symlinks, then do a cp on the machine itself...
$UPDATE_DIR	   = 'http://www.onlineoffice.de/bbbike';
# URL auf die Diplomarbeit
$DIPLOM_URL        = 'http://user.cs.tu-berlin.de/~eserte/diplom/';

$BBBIKE_MAPSERVER_URL  = 'http://www.radzeit.de/cgi-bin/mapserv';
$BBBIKE_MAPSERVER_ADDRESS_URL = 'http://www.radzeit.de/cgi-bin/mapserver_address.cgi';
#XXX zurzeit nicht ansprechbar
$BBBIKE_MAPSERVER_INIT = 'http://www.radzeit.de/mapserver/brb/';

1;

__END__
