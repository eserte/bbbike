# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Launch Merkaartor
# Description (de): Schnittstelle zu Merkaartor
package MerkaartorPlugin;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

sub register {
    $main::info_plugins{__PACKAGE__ . "_MerkaartorCmdline"} =
	{ name => "Merkaartor (via Kommandozeile)",
	  callback => sub { merkaartor_via_cmdline(@_) },
	  #XXX ($images{Pharus} ? (icon => $images{Pharus}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_MerkaartorURL"} =
	{ name => "Merkaartor/JOSM (via URL)",
	  callback => sub { merkaartor_via_url(@_) },
	  callback_3_std => sub { merkaartor_url(@_) },
	  #XXX ($images{Pharus} ? (icon => $images{Pharus}) : ()),
	};
}

sub merkaartor_via_cmdline {
    my(%args) = @_;
    my $url = sprintf 'osm://<whatever>/load_and_zoom?left=%s&right=%s&top=%s&bottom=%s', # &select=node413602999
	$args{px0}, $args{px1}, $args{py0}, $args{py1};
    if (fork == 0) {
	exec('merkaartor', $url);
	die "Cannot start merkaartor $url: $!";
    }
}

sub merkaartor_url {
    my(%args) = @_;
    my $url = sprintf 'http://localhost:8111/load_and_zoom?left=%s&right=%s&top=%s&bottom=%s', # &select=way65780504
	$args{px0}, $args{px1}, $args{py0}, $args{py1};
    $url;
}

sub merkaartor_via_url {
    my(%args) = @_;
    my $url = merkaartor_url(%args);
    send_url($url);
}

sub send_url {
    my($url) = @_;
    main::status_message("Die URL $url wird an Merkaartor geschickt.", "info");
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new;
    my $resp = $ua->get($url);
    if ($resp->code == 500 && $resp->status_line =~ m{Server closed connection without sending any data back}) {
	# this is success, at least for Merkaartor
    } elsif (!$resp->is_success) {
	warn $resp->as_string;
	main::status_message("Fehler: " . $resp->status_line . ". Vielleicht läuft Merkaartor nicht? Bitte starten!", "error");
	return;
    }
}

1;

__END__

=head1 NAME

MerkaartorPlugin - interface to merkaartor (and maybe also JOSM)

=head1 DESCRIPTION

Note: merkaartor with at least version 0.16.0 is needed for this
functionality. For the "via URL" functionality the "local server"
setting in merkaartor's network preferences need to be set.

JOSM is not tested at all, but should work with the "via URL"
functionality.

=head1 AUTHOR

Slaven Rezic

=cut
