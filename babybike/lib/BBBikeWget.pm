# -*- perl -*-

#
# $Id: BBBikeWget.pm,v 1.2 2003/01/08 20:17:12 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# get remote data

package BBBikeWget;
use strict;
use vars qw($url $datadir);
use File::Basename;

$url = "http://10.0.0.1/~eserte/bbbike-tmp2/"
    if !defined $url;

$datadir = "/tmp/bbd"
    if !defined $datadir;

sub _tk_get_data {
    my $mw = shift;
    if (!-d $datadir) {
	chdir dirname($datadir) or die "Can't chdir: $!";
	mkdir basename($datadir), 0775;
	if (!-d $datadir) {
	    die "Can't mkdir $datadir: $!";
	}
    }
    chdir $datadir or die "Can't chdir to $datadir: $!";

    require Tk::DialogBox;
    my $d = $mw->DialogBox(-buttons => [qw(Ok Cancel)]);
    $d->Label(-text => "URL:")->pack(-side => "left");
    my $e = $d->Entry(-textvariable => \$url)->pack(-side => "left", -fill => 'x');
    return unless $d->Show =~ /ok/i;

    system(qw(rxvt -geometry 40x8
	      -e wget --no-parent --cut-dirs=2 -nH -r --mirror
	      -A .bbd,.bbd.gz,.st,.db,.db.gz), $url);

    $datadir;
}

1;

__END__
