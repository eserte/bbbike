# -*- perl -*-

#
# $Id: BerlinerStadtplan.pm,v 1.6 2006/03/24 07:26:27 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeDraw::BerlinerStadtplan;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

use base qw(BBBikeDraw);

use vars qw($berliner_stadtplan_post_url);
if (!defined $berliner_stadtplan_post_url) {
    $berliner_stadtplan_post_url = "http://www.berliner-stadtplan24.com/";
    #$berliner_stadtplan_post_url = "http://www.berliner-stadtplan.com/";
    #$berliner_stadtplan_post_url = "http://www:1214/~eserte/cgi/post.cgi";
}

use CGI qw(:standard);

use Karte;
Karte::preload(qw(Standard Polar));

sub module_handles_all_cgi { 1 } # only with flush_direct_redirect

sub pre_draw {
    my $self = shift;
    $self->{PreDrawCalled}++;
}

sub flush_direct_redirect {
    my $self = shift;
    my $q = $self->{CGI} || CGI->new;
    my @new_coords;
    for my $xy (@{ $self->{Coords} }) {
	my($px,$py) = map { sprintf "%.5f", $_ } $Karte::Polar::obj->standard2map(split /,/, $xy);
	push @new_coords, "$px,$py";
    }
    my $new_coords = join "!", @new_coords;

    print $q->redirect($berliner_stadtplan_post_url . "?longlatcoords=$new_coords");
}

sub mimetype { "text/html" }

sub flush {
    my $self = shift;
    my $q = $self->{CGI} || CGI->new;
    my @new_coords;
    for my $xy (@{ $self->{Coords} }) {
	my($px,$py) = map { sprintf "%.5f", $_ } $Karte::Polar::obj->standard2map(split /,/, $xy);
	push @new_coords, "$px,$py";
    }
    my $new_coords = join "!", @new_coords;

    my $fh = $self->{Fh} || \*STDOUT;

    print $fh header(-type => $self->mimetype,
		     -Vary => "User-Agent",
		    );
    print $fh start_html(-onLoad => "init()",
			 -script => <<EOF);
function init() {
    document.forms[0].submit();
}
EOF
    print $fh start_form(-action => $berliner_stadtplan_post_url,
			 -method => "POST");
    print $fh hidden("longlatcoords", $new_coords);
    print $fh "<noscript>";
    print $fh submit("Weiterleitung auf www.berliner-stadtplan24.com");
    print $fh "</noscript>";
    print $fh end_form, end_html;
}

1;

__END__
