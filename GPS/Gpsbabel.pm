# -*- perl -*-

#
# $Id: Gpsbabel.pm,v 1.6 2008/01/29 22:17:24 eserte Exp $
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
use vars qw($VERSION $GPSBABEL);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);
$GPSBABEL = "gpsbabel" unless defined $GPSBABEL;

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
    if (!$self->gpsbabel_available) {
	die "$GPSBABEL ist nicht installiert"; # Msg.pm
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

    my $s = $self->convert_to_strassen_using_gpsbabel
	($ofilename,
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

sub convert_to_strassen_using_gpsbabel {
    my($self, $file, %args) = @_;
    my $title = $args{title} || $file;
    my $input_format = $args{input_format} || die "input_format is missing";
    require File::Temp;
    my($ofh,$ofilename) = File::Temp::tempfile(UNLINK => 1);
    # XXX need a patched gpsbabel (gpsbabel by default only outputs waypoint files, not tracks)
    system($GPSBABEL, "-t",
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

sub strassen_to_gpsbabel {
    my($self, $s, $otype, $ofile, %args) = @_;
    my $as = delete $args{'as'} || 'track';
    die "Unhandled arguments: " . join(" ", %args) if %args;

    require File::Temp;
    require Strassen::GPX;

    my $s_gpx = Strassen::GPX->new($s);
    my $xml_res = $s_gpx->Strassen::GPX::bbd2gpx(-as => $as);

    my($ifh,$ifile) = File::Temp::tempfile(SUFFIX => ".gpx",
					   UNLINK => 1);
    print $ifh $xml_res
	or die "While writing to $ifile: $!";
    close $ifh
	or die "While closing $ifile: $!";

    my @cmd = ($GPSBABEL,
	       "-i", "gpx", "-f", $ifile,
	       "-o", $otype, "-F", $ofile,
	      );
    system @cmd;
    $? == 0
	or die "A problem occurred when running <@cmd>: exit code=$?";
}

sub gpsbabel_available {
    my($self, $new_gpsbabel) = @_;
    if ($new_gpsbabel) {
	if (is_in_path($new_gpsbabel)) {
	    $GPSBABEL = $new_gpsbabel;
	    return $GPSBABEL;
	} else {
	    return 0;
	}
    } else {
	return is_in_path($GPSBABEL);
    }
}

1;

__END__
