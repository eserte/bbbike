# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017,2018,2023 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Doit::Lwp; # Convention: all commands here should be prefixed with 'lwp_'

use strict;
use warnings;
our $VERSION = '0.013';

use Doit::Log;

sub new { bless {}, shift }
sub functions { qw(lwp_mirror) }
sub add_components { qw(file) }

{
    my $ua; # XXX cache in object?
    sub _get_cached_ua {
	my($self) = @_;
	return $ua if $ua;
	require LWP::UserAgent;
	$ua = LWP::UserAgent->new; # XXX options?
    }
}

sub lwp_mirror {
    my($self, $url, $filename, %opts) = @_;
    if (!defined $url) { error "url is mandatory" }
    if (!defined $filename) { error "filename is mandatory" }
    my $refresh  = delete $opts{refresh} || 'always';
    if (UNIVERSAL::isa($refresh, 'ARRAY')) {
	if ($refresh->[0] ne 'digest') {
	    error "refresh in ARRAY form expects 'digest' as first element";
	}
	if (@$refresh < 2 || @$refresh > 3) {
	    error "refresh in ARRAY form expects two elements (string 'digest', the digest value and optionally digest type)";
	}
    } elsif ($refresh !~ m{^(always|never|unconditionally)$}) { error "refresh may be 'always', 'never' or 'unconditionally'" }
    my $debug    = delete $opts{debug}; 
    my $ua       = delete $opts{ua};
    error "Unhandled options: " . join(" ", %opts) if %opts;

    if (-e $filename) {
	if ($refresh eq 'never') {
	    if ($debug) {
		info "$url -> $filename already exists, do not refresh";
	    }
	    return 0;
	} elsif (UNIVERSAL::isa($refresh, 'ARRAY') && $refresh->[0] eq 'digest') {
	    my $digest = $refresh->[1];
	    my $type = $refresh->[2] || 'MD5';
	    if ($self->file_digest_matches($filename, $digest, $type)) {
		if ($debug) {
		    info "$url -> $filename already exists and $type digest is as expected, do not refresh";
		}
		return 0;
	    } else {
		$refresh = 'unconditionally';
	    }
	}
    }

    $ua ||= _get_cached_ua;

    if ($self->is_dry_run) {
	info "mirror $url -> $filename (dry-run)";
    } else {
	info "mirror $url -> $filename";
	my $resp;
	if ($refresh eq 'unconditionally') {
	    $self->file_atomic_write
		($filename, sub {
		     my $fh = shift;
		     if (ref $ua eq 'HTTP::Tiny') {
			 $resp = $ua->get($url, {
			     data_callback => sub {
				 my($data) = @_;
				 print $fh $data;
			     },
			 });
		     } else {
			 $resp = $ua->get($url, 
			     ':content_cb' => sub {
				 my($chunk) = @_;
				 print $fh $chunk;
			     },
			 );
		     }
		 });
	} else {
	    $resp = $ua->mirror($url, $filename);
	}
	if (ref $ua eq 'HTTP::Tiny') {
	    if ($debug) {
		require Data::Dumper;
		info "Response: " . Data::Dumper->new([$resp],[qw()])->Indent(1)->Useqq(1)->Sortkeys(1)->Terse(1)->Dump;
	    }
	    if (!$resp->{success}) {
		my $msg = "mirroring failed: $resp->{status} $resp->{reason}";
		if ($resp->{status} == 599) {
		    $msg .= ": $resp->{content}";
		}
		error $msg;
	    } elsif ($resp->{status} == 304) {
		return 0;
	    } else {
		return 1;
	    }
	} else {
	    if ($debug) {
		info "Response: " . $resp->as_string;
	    }
	    if ($resp->code == 304) {
		return 0;
	    } elsif (!$resp->is_success) {
		error "mirroring failed: " . $resp->status_line;
	    } elsif ($resp->header('X-Died')) {
		error "mirroring failed: " . $resp->header('X-Died');
	    } else {
		return 1;
	    }
	}
    }
}

1;

__END__
