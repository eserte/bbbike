# -*- perl -*-

#
# $Id: Gpsbabel.pm,v 1.5 2006/08/29 21:43:52 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::Gpsbabel;
require GPS;
push @ISA, 'GPS';

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use BBBikeUtil qw(is_in_path);

my %magics =
    ('pcx' => ['^H  SOFTWARE NAME & VERSION'],
     'gpx' => ['^<\?xml\s+'],
    );

sub magics {
    map { @$_ } values %magics;
}

sub convert_to_route {
    my($self, $file, %args) = @_;
    if (!is_in_path("gpsbabel")) {
	die "gpsbabel ist nicht installiert"; # Msg.pm
    }

    my($fh, $lines_ref) = $self->overread_trash($file, %args);
    die "File $file does not match" unless $fh;

    my $input_format;
 GET_INPUT_FORMAT:
    for my $last_line (@$lines_ref) {
	while(my($test_input_format, $magics) = each %magics) {
	    for my $magic (@$magics) {
		if ($last_line =~ /$magic/) {
		    $input_format = $test_input_format;
		    last GET_INPUT_FORMAT;
		}
	    }
	}
    }
    if (!$input_format) {
	die "Strange: Cannot find magic in @$lines_ref";
    }

    require File::Temp;
    my($ofh, $ofilename) = File::Temp::tempfile(UNLINK => 1);
    while(<$fh>) {
	print $ofh $_;
    }
    close $fh;
    close $ofh;

    my $s = $self->run_gpsbabel($ofilename,
				title => undef, # XXX
				input_format => $input_format,
			       );
    unlink $ofilename;

    my @coords;
    $s->init;
    while(1) {
	my $ret = $s->next;
	last if !@{ $ret->[Strassen::COORDS()] };
	push @coords, map { [ split /,/ ] } @{ $ret->[Strassen::COORDS()] };
    }

    @coords;
}

sub run_gpsbabel {
    my($self, $file, %args) = @_;
    my $title = $args{title} || $file;
    my $input_format = $args{input_format} || die "input_format is missing";
    require File::Temp;
    my($ofh,$ofilename) = File::Temp::tempfile(UNLINK => 1);
    # XXX need a patched gpsbabel (gpsbabel by default only outputs waypoint files, not tracks)
    system("gpsbabel", "-t",
	   "-i", $input_format, "-f", $file,
	   "-o", "gpsman", "-F", $ofilename);
    # Hack: set track name
    my($o2fh,$o2filename) = File::Temp::tempfile(UNLINK => 1);
    open(F, $ofilename) or die $!;
    while(<F>) {
	s/(^!T:)/$1\t$title/;
	print $o2fh $_;
    }
    close F;
    close $o2fh;

    require Strassen::Gpsman;
    my $s = Strassen::Gpsman->new($o2filename, cat => "#000080");

    unlink $ofilename;
    unlink $o2filename;

    $s;
}

1;

__END__
