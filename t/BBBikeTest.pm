# -*- perl -*-

#
# $Id: BBBikeTest.pm,v 1.1 2004/12/28 22:56:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeTest;

use strict;
use vars qw(@EXPORT $logfile);

use base qw(Exporter);

@EXPORT = qw($logfile);

# Old logfile
#$logfile = "$ENV{HOME}/www/log/radzeit.de-access_log";
# New logfile since 2004-09-28 ca.
$logfile = "$ENV{HOME}/www/log/radzeit.combined_log";

1;
