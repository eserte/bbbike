# -*- perl -*-

#
# Copyright (C) 2006,2010,2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeCGI::Util;

use strict;
use vars qw($VERSION);
$VERSION = 1.11;

sub decode_possible_utf8_params {
    my($q) = @_;
    eval {
	require Encode;
	local $^W = 0; # version not numeric warning
	Encode->VERSION(2.08); # "Süd" gets destroyed in older versions
	my @new_params;
	for my $key ($q->param) {
	    next if $q->upload($key);
	    my @vals;
	    for my $val (my_multi_param($q, $key)) {
		eval {
		    my $test_val = $val;
		    Encode::decode("utf-8", $test_val, Encode::FB_CROAK());
		};
		if (!$@) {
		    $val = Encode::decode("utf-8", $val);
		    if ($val =~ m{^[\0-\xff]+$}) {
			utf8::downgrade($val);
		    }
		}
		push @vals, $val;
	    }
	    push @new_params, [$key, \@vals];
	}
	for my $new_param (@new_params) {
	    my($k,$v) = @$new_param;
	    $q->delete($k);
	    $q->param($k,@$v);
	}
    };
    if ($@ && $@ !~ /Encode version .* required/) {
	warn $@ if $@;
    }
}

# Hack for old ProxyPass on bbbike.radzeit.de, not needed anymore, but
# still here in case proxy games are again needed:
sub my_url {
    my($q, %args) = @_;
    return $q->url(%args);

    # Not used anymore:
    if ($args{"-absolute"}) {
	$q->url(-absolute => 1);
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
    if (0) {
	'other.server.name';
    } else {
	$q->server_name;
    }
}

require CGI;
if (defined &CGI::multi_param) {
    *my_multi_param = \&CGI::multi_param;
} else {
    *my_multi_param = \&CGI::param;
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
