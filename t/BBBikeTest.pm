# -*- perl -*-

#
# $Id: BBBikeTest.pm,v 1.2 2004/12/30 20:48:33 eserte Exp $
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

use vars qw(@opt_vars);
BEGIN {
    @opt_vars = qw($logfile $do_xxx $do_display $cgiurl $debug);
}

use strict;
use vars qw(@EXPORT);
use vars (@opt_vars);

use base qw(Exporter);

use BBBikeUtil qw(is_in_path);

@EXPORT = (qw(get_std_opts set_user_agent do_display),
	   @opt_vars);

# Old logfile
#$logfile = "$ENV{HOME}/www/log/radzeit.de-access_log";
# New logfile since 2004-09-28 ca.
$logfile = "$ENV{HOME}/www/log/radzeit.combined_log";

if (defined $ENV{BBBIKE_TEST_CGIURL}) {
    $cgiurl = $ENV{BBBIKE_TEST_CGIURL};
} elsif (defined $ENV{BBBIKE_TEST_CGIDIR}) {
    $cgiurl = $ENV{BBBIKE_TEST_CGIDIR} . "/bbbike.cgi";
} else {
    $cgiurl = 'http://www/bbbike/cgi/bbbike.cgi';
}

sub get_std_opts {
    my(@what) = @_;
    my %std_opts = ("cgiurl=s" => \$cgiurl,
		    "xxx"      => \$do_xxx,
		    "display!" => \$do_display,
		    "debug!"   => \$debug,
		   );
    my %opts;
 OPT: for (@what) {
	keys %std_opts; # reset iterator
	while(my($k,$v) = each %std_opts) {
	    if ($k !~ /^(\w+[-\w|]*)?(!|[=:][infse][@%]?)?$/) {
		die "Error in option spec: \"", $k, "\"\n";
	    }
	    my($o) = ($1);
	    if ($o eq $_) {
		$opts{$_} = $v;
		next OPT;
	    }
	}
	die "This is not a standard option: $_";
    }
    %opts;
}

sub set_user_agent {
    my($ua) = @_;
    $ua->agent("BBBike-Test/1.0");
    $ua->env_proxy;
}

sub do_display {
    my($filename_or_scalar, $imagetype) = @_;

    my $filename;
    if (ref $filename_or_scalar eq 'SCALAR') {
	require File::Temp;
	my $fh;
	($fh, $filename) = File::Temp::tempfile(SUFFIX => ".$imagetype",
						UNLINK => !$debug,
					       );
	print $fh $$filename_or_scalar;
    } else {
	$filename = $filename_or_scalar;
    }

    if ($imagetype eq 'svg') {
	if (is_in_path("mozilla")) {
	    system("mozilla -noraise -remote 'openURL(file:$filename,new-tab)' &");
	} else {
	    warn "Can't display $filename";
	}
    } elsif ($imagetype eq 'pdf') {
	if (is_in_path("xpdf")) {
	    system("xpdf $filename &");
	} else {
	    warn "Can't display $filename";
	}
    } else {
	if (is_in_path("xv")) {
	    system("xv $filename &");
	} elsif (is_in_path("display")) {
	    system("display $filename &");
	} else {
	    warn "Can't display $filename";
	}
    }
}

1;
