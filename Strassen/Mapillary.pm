# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2020 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::Mapillary;

use strict;
use warnings;
our $VERSION = '0.03';

use Strassen::GeoJSON;
our @ISA = qw(Strassen::GeoJSON);

use LWP::UserAgent;

use BBBikeYAML;

use constant PER_PAGE => 2000;

sub new {
    my($class) = @_;
    my $self = $class->SUPER::new;
    $self->{Mapillary} = {};
    $self;
}

sub get_config {
    my($self, %opts) = @_;
    my $force_load = $opts{force_load};
    die "Unhandled options: " . join(" ", %opts) if %opts;

    if (!$force_load && $self->{Mapillary}->{Config}) {
	return $self->{Mapillary}->{Config};
    }

    my $mapillary_config_file = "$ENV{HOME}/.mapillary";
    my $mapillary_config = eval { BBBikeYAML::LoadFile($mapillary_config_file) };
    if (!$mapillary_config) {
	die "Can't load $mapillary_config_file: $@";
    }
    my $client_id = $mapillary_config->{client_id};
    if (!defined $client_id) {
	die "No client_id in $mapillary_config_file";
    }

    $self->{Mapillary}->{Config} = $mapillary_config;
}

sub get_sequences_start_url {
    my($self, %query) = @_;

    my $bbox = delete $query{bbox};
    my $usernames = delete $query{usernames};
    {
	my $username = delete $query{username};
	if (defined $username) {
	    push @$usernames, $username;
	}
    }
    if (!$bbox && !$usernames) {
	die "Either bbox or usernames/username is mandatory";
    }

    my $start_time = delete $query{start_time};
    if ($start_time && $start_time !~ /T/) {
	$start_time .= "T00:00:00.000Z";
    }
    my $end_time   = delete $query{end_time};
    if ($end_time && $end_time !~ /T/) {
	$end_time .= "T23:59:59.999Z";
    }

    die "Unhandled query parameters: " . join(" ", %query) if %query;

    my $config = $self->get_config;
    my $client_id = $config->{client_id};

    my $url = "https://a.mapillary.com/v3/sequences?client_id=${client_id}";
    $url .= "&per_page=" . PER_PAGE;
    if ($bbox) {
	$url .= "&bbox=" . join(",",@$bbox);
    }
    if ($start_time) {
	$url .= "&start_time=$start_time";
    }
    if ($end_time) {
	$url .= "&end_time=$end_time";
    }
    if ($usernames) {
	for my $username (@$usernames) {
	    $url .= "&usernames=$username";
	}
    }
    $url;
}

sub fetch_sequences {
    my($self, $query, $opts) = @_;

    $opts ||= {};
    my $max_pages = exists $opts->{max_pages} ? delete $opts->{max_pages} : 10; # limit pagination
    my $max_fetch_tries = exists $opts->{max_fetch_tries} ? delete $opts->{max_fetch_tries} : 3;
    my $verbose = delete $opts->{verbose};
    my $msgs = delete $opts->{msgs};
    die "Unhandled options: " . join(" ", %$opts) if %$opts;

    if (!$query) {
	die "Missing query";
    }

    my $url = $self->get_sequences_start_url(%$query);

    my $ua = LWP::UserAgent->new;
    $ua->default_header('Accept-Encoding' => scalar HTTP::Message::decodable());

    for my $i (1..$max_pages) {
	warn "Fetch $url (page $i)...\n" if $verbose;
	my $resp;
	for my $try_i (1..$max_fetch_tries) {
	    $resp = $ua->get($url);
	    my $code = $resp->code;
	    if ($code == 504 || $code == 502 || $code == 503) {
		warn "> Fetch failed (status code=$code, try $try_i): " . $resp->status_line . "\n" if $verbose;
		if ($try_i < $max_fetch_tries) {
		    sleep 1;
		}
	    } else {
		# success or fatal error
		last;
	    }
	}
	if (!$resp->is_success) {
	    die "Fetching $url failed: " . $resp->as_string;
	}
	my $geojson = $resp->decoded_content(charset => 'none');
	if (0) { # XXX debugging helper
	    if (open my $ofh, '>', '/tmp/mapillary.geojson') {
		print $ofh $geojson;
		close $ofh
		    or warn "Error while closing: $!";
	    } else {
		warn "Error writing mapillary.geojson: $!";
	    }
	}
	my $sg = $i == 1 ? $self : Strassen::GeoJSON->new;
	$sg->geojsonstring2bbd($geojson,
			       namecb => sub {
				   my $f = shift;
				   join(" ", @{$f->{properties}}{qw(captured_at username)});
			       },
			       dircb  => sub {
				   my $f = shift;
				   my $pKey = $f->{properties}{coordinateProperties}{image_keys}[0];
				   if ($pKey) {
				       my $date = $f->{properties}{captured_at};
				       my($dateFrom, $dateUntil);
				       if ($date) {
					   ($dateFrom = $date) =~ s{T.*}{};
					   $dateUntil = $dateFrom;
				       }
				       { url => ["https://www.mapillary.com/app/?focus=photo&pKey=$pKey" . ($dateFrom ? "&dateFrom=$dateFrom&dateUntil=$dateUntil" : "")] };
				   } else {
				       undef;
				   }
			       },
			      );
	# append
	if ($i > 1) {
	    $sg->init;
	    while() {
		my $r = $sg->next;
		last if !@{ $r->[Strassen::COORDS] };
		my $dir = $sg->get_directives;
		$self->push_ext($r, $dir);
	    }
	}

	my $more_data_pending;
	my $next_url;
	my $link = $resp->header('link');
	if (!$link) {
	    warn "Unexpected: no link HTTP header found"; # but we continue with the fallback plan
	    my $count_features = $sg->count;
	    my $max_mapillary_features = PER_PAGE;
	    if ($count_features == $max_mapillary_features) {
		$more_data_pending = 1;
	    } elsif ($count_features > $max_mapillary_features) {
		warn "NOTE: got more than expected $max_mapillary_features mapillary features (got $count_features)";
	    }
	} else {
	    if ($link =~ m{<([^>]+)>;\s*rel="next"}) {
		$next_url = $1;
		if ($i == $max_pages) {
		    $more_data_pending = 1;
		}
	    }
	}
	if ($more_data_pending) {
	    my $msg = "There's probably more Mapillary data available --- the shown dataset is limited";
	    if ($msgs) {
		push @$msgs, $msg;
	    }
	    warn "$msg\n" if $verbose;
	}
	if ($next_url) {
	    $url = $next_url;
	} else {
	    last;
	}
    } 
}

1;

__END__
