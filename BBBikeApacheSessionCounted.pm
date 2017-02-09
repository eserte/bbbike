# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011,2014,2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeApacheSessionCounted;

use strict;
use vars qw($VERSION $debug);

$VERSION = '0.05';
$debug = $main::debug; # XXX hmmmm
$main::debug = $main::debug if 0; # cease -w

use Apache::Session::Counted;

######################################################################
# CONFIGURATION SECTION
our %CLUSTER_DEFS = (
		     #'biokovo.herceg.de'                         => [1, 'http://biokovo/bbbike/cgi/asch'],
		     #'lvps83-169-19-137.dedicated.hosteurope.de' => [2, 'http://bbbike.lvps83-169-19-137.dedicated.hosteurope.de/cgi-bin/asch'],
		     'eserte'                                    => [3, 'http://eserte.bbbike.org/cgi-bin/asch'],
		     'mosor'                                     => [4, 'http://mosor/bbbike/cgi/asch'],
		     #'lvps176-28-19-132.dedicated.hosteurope.de' => [5, 'http://bbbike.lvps176-28-19-132.dedicated.hosteurope.de/cgi-bin/asch'],
		     'bbbike-vmz'                                => [6, 'http://ip78-137-103-246.pbiaas.com/cgi-bin/asch'],
		     'lvps83-169-5-248.dedicated.hosteurope.de'  => [7, 'http://bbbike.lvps83-169-5-248.dedicated.hosteurope.de/cgi-bin/asch'],
		    );
######################################################################
our $THIS_HOST_ID;

sub pre_init {
    Apache::Session::CountedStore->tree_init("/tmp/bbbike-sessions-$<","1");
}

sub tie_session {
    my $id = shift;

    # To retrieve a session file:
    #perl -MData::Dumper -MStorable=thaw -e '$content=do{open my $fh,$ARGV[0] or die;local$/;<$fh>}; warn Dumper thaw $content' file

    #my $dirlevels = 0;
    my $dirlevels = 1;
    my @l = localtime;
    my $date = sprintf "%04d-%02d-%02d", $l[5]+1900, $l[4]+1, $l[3];
    ## Make sure a different user for cgi-bin/mod_perl operation is used
    #my $directory = "/tmp/bbbike-sessions-" . $< . "-$date";
    ## No need for per-day directories,
    ## I have /tmp/coordssessions
    my $directory = "/tmp/bbbike-sessions-" . $<;
    ## Resetting the sessions daily:
    my $counterfile = "/tmp/bbbike-counter-" . $< . "-$date";
    #my $counterfile = "/tmp/bbbike-counter-" . $<;

#     require File::Spec;
#     open(OLDOUT, ">&STDOUT") or die $!;
#     open(STDOUT, ">&STDERR") or die $!;
#     Apache::Session::CountedStore->tree_init($directory, $dirlevels);
#     close STDOUT;
#     open(STDOUT, ">&OLDOUT") or die $!;

    my %sess;
    eval {
	if (!defined $THIS_HOST_ID) {
	    require Sys::Hostname;
	    my $hostname = Sys::Hostname::hostname();
	    if (exists $CLUSTER_DEFS{$hostname}) {
		$THIS_HOST_ID = $CLUSTER_DEFS{$hostname}->[0];
	    } else {
		$THIS_HOST_ID = 0; # defined, but false
	    }
	}
	tie %sess, 'Apache::Session::Counted', $id,
	    { Directory => $directory,
	      DirLevels => $dirlevels,
	      CounterFile => $counterfile,
	      AlwaysSave => 1,
	      ($THIS_HOST_ID ?
	       (
		HostID  => $THIS_HOST_ID,
		HostURL => sub {
		    my($host_id, $session_id) = @_;
		    for (values %CLUSTER_DEFS) {
			if ($_->[0] eq $host_id) {
			    return $_->[1] . '?' . $session_id;
			}
		    }
		    warn "Cannot handle host id <$host_id>";
		    undef;
		},
	       ) : ()
	      ),
	      Timeout => 10,
	    } or do {
		warn $! if $debug;
		return undef;
	    };
    };
    if ($@) { # I think this normally does not happen
	if (!defined $id) {
	    # this is fatal
	    die "Cannot create new session: $@";
	} else {
	    # may happen for old sessions, e.g. in links, so
	    # do not die
	    warn "Cannot load old session, maybe already garbage-collected: $@";
	}
    }
    if (defined $id && keys %sess == 1) {
	# we silently assume that the session is invalid
	return undef;
    }

    return \%sess;
}

1;

__END__
