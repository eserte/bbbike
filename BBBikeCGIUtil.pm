# -*- perl -*-

#
# $Id: BBBikeCGIUtil.pm,v 1.5 2006/03/24 20:32:40 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeCGIUtil;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub encode_possible_utf8_params {
    my($q, $from, $to) = @_;
    eval {
	require Encode;
	my %new_param;
	for my $key ($q->param) {
	    next if $q->upload($key);
	    my @vals;
	    for my $val ($q->param($key)) {
		eval {
		    my $test_val = $val;
		    Encode::decode("utf-8", $test_val, Encode::FB_CROAK());
		};
		if (!$@) {
		    $val = Encode::decode("utf-8", $val);
		    utf8::downgrade($val);
		}
		push @vals, $val;
	    }
	    $new_param{$key} = \@vals;
	}
	$q->delete(keys %new_param);
	while(my($k,$v) = each %new_param) {
	    $q->param($k,@$v);
	}
    };
    warn $@ if $@;
}

# Hack for ProxyPass on bbbike.radzeit.de:
sub my_url {
    my($q, %args) = @_;
    if ($args{"-absolute"}) {
	$q->url(-absolute => 1);
    } elsif ($q->server_name eq 'bbbike.radzeit.de') {
	my $url = $q->url(%args);
	$url =~ s{^http://192\.168\.0\.2}{http://bbbike.radzeit.de};
	$url;
    } else {
	$q->url(%args);
    }
}

sub my_self_url {
    my($q) = @_;
    my $host = my_url($q);
    my $qs = $q->query_string;
    $host . ($qs ne "" ? "?$qs" : "");
}

1;

__END__
