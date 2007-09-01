# -*- perl -*-

#
# $Id: YahooMaps.pm,v 1.2 2007/09/01 12:46:48 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2007 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package YahooMaps;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use CGI;
use LWP::UserAgent;
use XML::LibXML;

my $service_url   = 'http://local.yahooapis.com/MapsService/V1/mapImage';
my $default_appid = 'znzZEtLV34GSYLIJNez7Qefa2YvW9ZaTtJn3BnNPqjF4UPyTLzTlUGrt_uh_adM-';

# API documentation at:
#   http://developer.yahoo.com/maps/rest/V1/mapImage.html
sub map_service_url {
    my($class, %args) = @_;

    my %api_args;
    for my $key (qw(appid street city state zip location latitude longitude
		    image_type image_height image_width zoom radius output)) {
	$api_args{$key} = delete $args{$key};
    }

    if (%args) {
	die "Unhandled arguments: " . join(" ", %args);
    }

    $api_args{appid} = $default_appid if !defined $api_args{appid};

    CGI->import('-oldstyle_urls');
    my $url = $service_url . "?" . CGI->new(\%api_args)->query_string;

    $url;
}

sub map_url {
    my($class, %args) = @_;
    my $map_service_url = $class->map_service_url(%args);

    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    my $resp = $ua->get($map_service_url);
    if (!$resp->is_success) {
	die "Cannot get <$map_service_url>: " . $resp->status_line;
    }
    my $p = XML::LibXML->new;
    my $doc = eval { $p->parse_string($resp->decoded_content) };
    if (!$doc) {
	die "Cannot parse result content from <$map_service_url>: $@";
    }
    my $root = $doc->documentElement;
    my $map_url = $root->findvalue("/Result");
    $map_url;
}

sub map_image {
    my($class, %args) = @_;
    my $map_url = $class->map_url(%args);

    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    my $resp = $ua->get($map_url);
    if (!$resp->is_success) {
	die "Cannot get <$map_url>: " . $resp->status_line;
    }
    $resp->decoded_content;
}

sub show_map_at_point {
    my($class, %args) = @_;

    my $top = delete $args{tk};
    my $need_mainloop = 0;
    if (!$top) {
	require Tk;
	$top = MainWindow->new;
	$top->withdraw;
	$need_mainloop = 1;
    }

    $args{image_type} = "gif";
    my $image_data = $class->map_image(%args);
    my $p = $top->Photo(-data => $image_data);

    my $t = $top->Toplevel;
    $t->Label(-image => $p)->pack;

    if ($need_mainloop) {
	$t->OnDestroy(sub { $top->destroy });
	Tk::MainLoop();
    }
}

return 1 if caller;

YahooMaps->show_map_at_point(longitude => $ARGV[0], latitude => $ARGV[1]);

__END__
