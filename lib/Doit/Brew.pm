# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Doit::Brew; # Convention: all commands here should be prefixed with 'brew_'

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

sub new { bless {}, shift }
sub functions { qw(brew_install_packages brew_missing_packages can_brew) }
sub add_component { qw(extcmd) }

sub can_brew {
    require Doit::Extcmd;
    Doit::Extcmd::is_in_path('brew') ? 1 : 0;
}

sub brew_install_packages {
    my($self, @packages) = @_;
    my @missing_packages = $self->brew_missing_packages(@packages);
    if (@missing_packages) {
	$self->system('brew', 'install', @missing_packages);
    }
    @missing_packages;
}

sub brew_missing_packages {
    my($self, @packages) = @_;
    my @missing_packages;
    for my $package (@packages) {
	if (!-d "/usr/local/Cellar/$package") {
	    push @missing_packages, $package;
	}
    }
    @missing_packages;
}

1;

__END__
