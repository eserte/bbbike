# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010,2013,2016 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Launch Merkaartor or JOSM
# Description (de): Schnittstelle zu Merkaartor/JOSM
package MerkaartorPlugin;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = '0.08';

use vars qw(%images);

use BBBikeUtil qw(is_in_path);
use BBBikeProcUtil qw(double_forked_exec);

sub register {
    _create_images();
    $main::info_plugins{__PACKAGE__ . "_JOSMCmdline"} =
	{ name => "JOSM (via Kommandozeile)",
	  using_current_region => 1,
	  callback => sub { josm_via_cmdline(@_) },
	  ($images{JOSM} ? (icon => $images{JOSM}) : ()),
	  order => -102,
	};
    $main::info_plugins{__PACKAGE__ . "_MerkaartorCmdline"} =
	{ name => "Merkaartor (via Kommandozeile)",
	  using_current_region => 1,
	  callback => sub { merkaartor_via_cmdline(@_) },
	  ($images{Merkaartor} ? (icon => $images{Merkaartor}) : ()),
	  order => -101,
	};
    $main::info_plugins{__PACKAGE__ . "_MerkaartorURL"} =
	{ name => "Merkaartor/JOSM (via URL)",
	  using_current_region => 1,
	  callback => sub { merkaartor_via_url(@_) },
	  callback_3_std => sub { merkaartor_url(@_) },
	  allmaps => 0, # do not show in allmaps list
	  ($images{MerkaartorJOSM} ? (icon => $images{MerkaartorJOSM}) : ()),
	  order => -100,
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
    if (!defined $images{JOSM} && eval { require Tk::PNG; 1 }) {
	# Logo in josm jar: images/logo_16x16x8.png
	# Created base64:
	#   mmencode -b ...
	$images{JOSM} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAACPVBMVEUBAAAAAAD///9APUJE
QUaOmH6an4JoalksNCpgaVaZt3uImHNCQUVVVlJSU1BaXFlIRkg7PjaluZXm4rTU2KvR6rnA
8pOcynNubG56gna1xKyVtXmatYCFkXpZWlpwfmXW6bfp46/m/8rG751ecVFebVTA3KPl8eC9
1LCqwJXF3quOnoFXVlvR2qvh5LHf/MW/2KNkZ2Jllj9+tVidxnuPum+fuJGyy6Wkuo5cXFyX
q4zh2anh877j/8eux5dkbF5sn0Rcj75xqmeLv1aovpbD2K57iWhKSEx9f3qxxZvj877h1abh
77i32Zt1dnV3mIJ/qbyAqqujwnuvvqS70qg/SDdgXmLE1qjg/MXc0qLZ4q/m/8aHjoN1fHDE
3qKx0J25yqm0vqywx5xNVUlycHOktZXg+cLg5LLay5+znoR0fHVram5vfGaIjGl9j2uKmX2R
mohZWVl1f23O6L/n/MWDdkBLNAh2bGB7hXxwcGOCfYCcoZ2mq6qura6GfmnP5LJ+cj1CLwVh
TBZaQQquupXTz72vpJq/rJm1p5vKxb/U2s+fqICEeEBCLgRfSxhlRQVtWiXX6sGknpVNIwBb
MgdAIgMSCACQj5Lv7u9bRxNJNwxdSRZqTQx4XynOw5vU1ajc3NSkm5NiVEdSSUJtbG2wsLDX
19fR0dFtUx9RPRFaRxNtTg1cThqjqIytrIyZn4vIysTu8PDW1ta+vr5bSRVpTQ9gSxTMzMvZ
2NjFxMStra2amppVRh6BgYF6enoO+csKAAAAAXRSTlMAQObYZgAAAHFJREFUGNNjYIADZhYQ
ycjAyogE3jOwMPCiCjAyyCMLMF5hYXioiywAVGGFooKRhYEfhb+KhYEPRYABTaAf3VoGoEBf
PYoAI0M3ihkZ6IYuZ1kBYwYxrGf8zOvLyLCFkdEL5M3tIFFXEGsP1Pt794FIAF7gEE4ei/dj
AAAAAElFTkSuQmCC
EOF
    }
    if (!defined $images{MerkaartorJOSM} && eval { require Tk::PNG; 1 }) {
	# A combination of the merkaartor and josm logos
	# created in GIMP
	$images{MerkaartorJOSM} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAADGElEQVQozzXBX2wTdRwA8O/97nf/
uN6t/+htXTe3irHMAVrGnJOkbYJuauIfyEa2xMQIAuGBgcxEXwh/giE+CcITJGIUEhMIDzyQEH0A
1g7pti77w4htKVvpWsr6564tvWt7HE98PsSlM32x6MOqSjAMG1lSIo+qAge7v3zPMFAqnc0+LzEs
19Gs13TKuq4wcuAyjj0pNnRiMaqE5uSmdXDsyA6LiCSHLa8Yb7nX3/73QWg6/c8E9GyE73/6ddO2
IbJ3sxiezSzECc8bxNGD/Rxvjcbiz/IoGl9RFAUzZncbw+Ia4/CXK2TA78eSnYsmgaKMWgP9fDZk
s1BfD3/4ODrzf6IYT4LyAjI5OPHLt4Ojn58ZuzIRDKJ6w5DLUKnCmmy80GDfiKe727Nz1xBDUxUN
kAHjJ75xdnkZzC4vR2dnZ5HWoDEJkhWGBwSOgXSe0fX6nfvLzQ7KZYUvDm8PfOaziczqyqqcq6RS
KayUARFgN4PdKox/J12/NUezwt3gPA2NvpH93oBNU4AR+BtXb7a1t/I8j8181SxA83qSpnSWJo7/
OKyq6mBgtGLpLGEroWPD4Mvl7OP4ss/3kUNy4LxCFBRosVNNgolAOBiauvvfU2/voOEAm7Cypjas
guiSOja4Ni8szJ/b/xuiWRNCYAB+CcRqpvDH9UeeLt9zzZZO5MpPsNuyUeLcdZkd2Cq5OjqdTidW
1YaJgw0dPEkYHAv9m/hcfGLPhb+knL5SRKDmMWsy251dvUP3fjhar9cxSZlGdm1rcZmuXLvvcbeY
Ob3KUHZRi4RKd34ft1jNGeVlbK3+wcDuzva3DcPAg4E3EahySW21kWouX9PJvUdO8cjs7X9nYfqT
+algodSoUk1b3vX29b0/OTmJOQaRiJsOL1E1FjvET3cevjf/sDgRCQS+On3+z0KhmM6ka7Xa02Qy
m82Gw2GcL6qJ2FIqGpMNlqj2xhPkxzv2tbe1Tk1NJ5NJURQ5li0pSiKRWFxc9Pv9xNyDv5/l6KsX
T3b3jx4aG8OYgtdmZmYikYgsy5qm+Xy+np4emqZfAcqvYBk6Ws9LAAAAAElFTkSuQmCC
EOF
    }
}

sub merkaartor_via_cmdline {
    if (!is_in_path 'merkaartor') {
	main::status_message("merkaartor ist nicht installiert.", "die");
    }
    my($minx,$miny,$maxx,$maxy) = main::get_visible_map_bbox_polar();
    my $url = sprintf 'osm://<whatever>/load_and_zoom?left=%s&right=%s&top=%s&bottom=%s', # &select=node413602999
	$minx, $maxx, $miny, $maxy;
    double_forked_exec 'merkaartor', $url;
}

sub josm_via_cmdline {
    if (!is_in_path 'josm') {
	main::status_message("josm ist nicht installiert.", "die");
    }
    my($minx,$miny,$maxx,$maxy) = main::get_visible_map_bbox_polar();
    # [--download=]minlat,minlon,maxlat,maxlon
    my $download_opt = sprintf '--download=%s,%s,%s,%s',
	$miny, $minx, $maxy, $maxx;
    double_forked_exec 'josm', $download_opt;
}

sub merkaartor_url {
    my($minx,$miny,$maxx,$maxy) = main::get_visible_map_bbox_polar();
    # localhost:8111 does not seem to work on Windows
    my $url = sprintf 'http://127.0.0.1:8111/load_and_zoom?left=%s&right=%s&top=%s&bottom=%s', # &select=way65780504
	$minx, $maxx, $maxy, $miny;
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
	main::status_message(<<EOF, "error");
Fehler: @{[ $resp->status_line ]}.

Falls Merkaartor verwendet werden soll:
* Vielleicht läuft Merkaartor nicht? Bitte starten!
* Vielleicht ist die Fernsteuerung in Merkaartor
  nicht aktiviert? Bitte hier ändern:
  * Deutsche Variante:
    Werkzeuge > Einstellungen > Netzwerk
    > JOSM-kompatiblen Server auf Port 8111 aktivieren
  * Englische Variante:
    Tools > Preferences > Network
    > Enable JOSM-compatible local server on port 8111

Falls JOSM verwendet werden soll:
* Vielleicht läuft JOSM nicht? Bitte starten!
* Vielleicht ist die Fernsteuerung in JOSM
  nicht aktiviert? Bitte über die Einstellung aktivieren.
* Für ältere JOSM-Versionen (älter als 3715)
  muss das RemoteControl-Plugin installiert sein.
EOF
	return;
    }
}

1;

__END__

=head1 NAME

MerkaartorPlugin - interface to merkaartor and JOSM

=head1 DESCRIPTION

Note: merkaartor with at least version 0.16.0 is needed for this
functionality. For the "via URL" functionality the "local server"
setting in merkaartor's network preferences need to be set.

JOSM also works, both with commandline and via URL.

=head1 AUTHOR

Slaven Rezic

=cut
