# -*- perl -*-

#
# $Id: E00.pm,v 1.1 2005/04/16 12:20:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::E00;

use strict;
use vars qw(@ISA $VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

require Strassen::Core;

@ISA = 'Strassen';

=head1 NAME

Strassen::E00 - read e00 files into a Strassen object

=cut

sub new {
    my($class, $filename, %args) = @_;
    my $self = {};
    bless $self, $class;

    if ($filename) {
	require File::Temp;
	my($tmpfh, $tmpfile) = File::Temp::tempfile(SUFFIX => ".bbd",
						    #UNLINK => 1
						   );
	open(DCWTOBBD, "-|") or do {
	    require File::Basename;
	    my $bbbikeroot = File::Basename::dirname(__FILE__) . "/..";
	    system("$bbbikeroot/miscsrc/dcwtobbd.pl", $filename);
	    if ($?) {
		warn "Fallback to e00_to_bbd...\n";
		system("$bbbikeroot/miscsrc/e00_to_bbd.pl < $filename");
	    }
	    exit 0;
	};
	while(<DCWTOBBD>) {
	    print $tmpfh $_;
	}
	close DCWTOBBD;
	$filename = $tmpfile;

	return Strassen->new($filename, %args);
    }

    $self;
}


1;

__END__
