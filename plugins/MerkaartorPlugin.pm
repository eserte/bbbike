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
$VERSION = '0.02';

use vars qw(%images);

sub register {
    _create_images();
    $main::info_plugins{__PACKAGE__ . "_MerkaartorCmdline"} =
	{ name => "Merkaartor (via Kommandozeile)",
	  callback => sub { merkaartor_via_cmdline(@_) },
	  ($images{Merkaartor} ? (icon => $images{Merkaartor}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_MerkaartorURL"} =
	{ name => "Merkaartor/JOSM (via URL)",
	  callback => sub { merkaartor_via_url(@_) },
	  callback_3_std => sub { merkaartor_url(@_) },
	  allmaps => 0, # do not show in allmaps list
	  ($images{Merkaartor} ? (icon => $images{Merkaartor}) : ()),
	};
}

sub _create_images {
    if (!defined $images{Merkaartor} && eval { require Tk::PNG; 1 }) {
	# Logo in merkaartor source code: Icons/48x48/merkaartor.png
	# Resized with gimp to 16x16
	# Created base64:
	#   mmencode -b ...
	$images{Merkaartor} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAAXNSR0IArs4c6QAAAAlwSFlz
AAALEwAACxMBAJqcGAAAAAd0SU1FB9oLBRUVOtQrCvcAAAMBSURBVCjPBcFLbNtkHADw//f5
s+NH7Cyp3SZkTdvRirUd7taNNEwaCDYJxCYmqmnqxAUJBBLShnYANCSOSBwRFy67cUACTaqE
umMrpJWJqjRruz4Wp13TLukjjzqe7diOY+/3Q/d/zm1pG1YrjLDc8qaxWnAEDk1eVTFFXpQP
a3WTZSNpJfADShadVN8FslVqtn1YK75cXDOUOPx494N4jOpWunQzGB7qmf0n/2ihMqtD9k26
Jvhs9ICaGJP+XzlY34bBDHz9WVaUunZKpUrVLxT3mnoTqGhvkuYi8GipNZCmT8SiRI6z2i4A
AtdDv95fUGT+5vXsztbKulZ/XoaGAbYDZ9/Ab6vMf6vexHmEOwEYFjguNIzQsGDq2uuqOvzR
1Wscy1gt4FiEEJwe4E/1hhhDcS/Ars/QBFIyfHJFjImoUieW5c7O70pR1J8mIg9hCHXdU+K4
PwXP92zy0gIASMRQUhG/utUzM1fg+NjC4hpHM6Zt0jSdlCERCzHCSRlZfkgkriUJ0J3AhOqI
Avn+zseu137/0tRhtfbgrz9eywyylBEXbNP2U7K3vqNTZ0e6F1dqE2pkICMjTG8U9h88XI3y
wfT0TBDiucdHF8+JNI39thMCdjwBE0bAGAAIwrhycPznjJZUpOmHy+UqLDwNfvjmctBxowJL
E4IRZdoOdr1OXILBfiEMAoYEuTNIHe2lsH9sQHa8rzeT3K/BT7/tmg6DkCdGecyw4tRkLp0Z
+Xt2HzPdfSelbW35rdHIUQM+vHKh7djzT+xKNfjl9+rSMyzyQN672M9H/NqxNaHGtK1yJkUh
1G457a449n2/3YlYZovngKKof/PuyJBHffnpOEKoUNweHj2f7InXqlWKEZu6ru12JAEOD/Zu
XM/ZZv3bO5MnFa+8b5KG7ioJZm5+JyqlTw/16bo+/zi/WUK3P393/NyZRJe8sZa/990XTsuh
s+rTQhM3GrqhH21qNYGPYMyMjalaqX3v7o13LuViJ5TDo8bSk01CcSwrFp/le2TuFZAxVO70
Ub2wAAAAAElFTkSuQmCC
EOF
    }
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
