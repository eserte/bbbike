# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeApacheSessionCounted;

use strict;
use vars qw($VERSION $debug);

$VERSION = '0.01';
$debug = $main::debug; # XXX hmmmm

use Apache::Session::Counted;
use Sys::Hostname qw(hostname);

# XXX DO NOT HARDCODE HERE!
my %CLUSTER_DEFS = (
		    'biokovo.herceg.de'                         => [1, 'http://biokovo/bbbike/cgi/asch'],
		    'lvps83-169-19-137.dedicated.hosteurope.de' => [2, 'http://bbbike.de/cgi-bin/asch'], # XXX in real cluster operation this must be a node name, not the cluster domain name!
		    'eserte'                                    => [3, 'http://eserte.bbbike.org/cgi-bin/asch'],
		    'mosor'                                     => [4, 'http://mosor/bbbike/cgi/asch'],
		   );

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
	tie %sess, 'Apache::Session::Counted', $id,
	    { Directory => $directory,
	      DirLevels => $dirlevels,
	      CounterFile => $counterfile,
	      AlwaysSave => 1,
	      (exists $CLUSTER_DEFS{hostname()} ?
	       (HostID => $CLUSTER_DEFS{hostname()}->[0],
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
