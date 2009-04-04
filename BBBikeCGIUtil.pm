# -*- perl -*-

#
# $Id: BBBikeCGIUtil.pm,v 1.10 2009/04/04 11:08:44 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

sub encode_possible_utf8_params {
    my($q, $from, $to) = @_;
    eval {
	require Encode;
	local $^W = 0; # version not numeric warning
	Encode->VERSION(2.08); # "Süd" gets destroyed in older versions
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
    if ($@ && $@ !~ /Encode version .* required/) {
	warn $@ if $@;
    }
}

# Hack for old ProxyPass on bbbike.radzeit.de, not needed anymore:
sub my_url {
    my($q, %args) = @_;
    return $q->url(%args);

    # Not used anymore:
    if ($args{"-absolute"}) {
	$q->url(-absolute => 1);
    } elsif ($q->server_name eq 'bbbike.radzeit.de' ||
	     $q->server_name eq 'bbbike.de' 
	    ) {
	my $url = $q->url(%args);
	$url =~ s{^http://192\.168\.0\.2}{http://bbbike.de};
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

sub my_server_name {
    my($q) = @_;
    if ($q->server_name eq '192.168.0.5') {
	'slaven1.radzeit.de';
    } else {
	$q->server_name;
    }
}

# CGI::escapeHTML does not escape anything above 0x80. Do it to avoid
# charset and encoding issues
BEGIN {
    if ($] >= 5.008) { # perl5.6.x cannot use [\x{....}] in regexpes
	eval <<'EOF';
sub my_escapeHTML {
    my($str) = @_;
    $str =~ s{([<>&\x80-\x{ffff}])}{ "&#" . ord($1) . ";" }eg;
    $str;
}
EOF
	die $@ if $@;
    } else {
	# fallback to original escapeHTML
	require CGI;
	*my_escapeHTML = \&CGI::escapeHTML;
    }
}

1;

__END__
