# -*- perl -*-

#
# $Id: Gpsbabel.pm,v 1.15 2008/08/03 09:17:12 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005,2008 Slaven Rezic. All rights reserved.
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
use vars qw($VERSION $GPSBABEL $DEBUG);
$VERSION = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);

use File::Basename qw(dirname);
use BBBikeUtil qw(is_in_path bbbike_root);

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

    my $s = $self->convert_to_strassen_using_gpsbabel
	($ofilename,
	 title => undef, # XXX
	 input_format => $input_format,
	);
    unlink $ofilename unless $File::Temp::KEEP_ALL;

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
    my(undef,$ofilename) = File::Temp::tempfile(UNLINK => 1);
    my @cmd = ("-t",
	       "-i", $input_format, "-f", $file,
	       "-o", "gpsman", "-F", $ofilename,
	      );
    warn "Run\n    @cmd\n    ...\n" if $DEBUG;
    $self->run_gpsbabel([@cmd]);
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

    unlink $ofilename unless $File::Temp::KEEP_ALL;
    unlink $o2filename unless $File::Temp::KEEP_ALL;

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

    $self->run_gpsbabel([($as eq 'track' ? '-t' : '-r'),
			 "-i", "gpx", "-f", $ifile,
			 "-o", $otype, "-F", $ofile,
			]);
    unlink $ifile unless $File::Temp::KEEP_ALL;
}

# May be called also as a static method
sub gpsbabel_available {
    my($self, $new_gpsbabel) = @_;
    $new_gpsbabel = "gpsbabel" if !$new_gpsbabel && !$GPSBABEL;
    local $ENV{PATH} = $ENV{PATH};
    if ($^O eq 'MSWin32') {
	# Maybe bundled together with BBBike:
	$ENV{PATH} .= ";" . dirname(bbbike_root()) . "\\gpsbabel";
	# There's no fixed installation location for gpsbabel under Windows:
	$ENV{PATH} .= ";" . $self->gpsbabel_recommended_path;
    } else {
	$ENV{PATH} .= ";" . $self->gpsbabel_recommended_path;
    }
    if ($new_gpsbabel) {
	my $found_new_gpsbabel = is_in_path($new_gpsbabel);
	if ($found_new_gpsbabel) {
	    $GPSBABEL = $found_new_gpsbabel;
	    return $GPSBABEL;
	} else {
	    return undef;
	}
    } else {
	return is_in_path($GPSBABEL);
    }
}

# May be called also as a static method
sub gpsbabel_recommended_path {
    if ($^O eq 'MSWin32') {
	"C:\\Program files\\gpsbabel-1.3.4"
    } else {
	"$ENV{HOME}/.bbbike/external/gpsbabel-1.3.4";
    }
}

# May be called also as a static method
sub gpsbabel_download_location {
    #"http://sourceforge.net/project/showfiles.php?group_id=58972";
    "http://sourceforge.net/project/platformdownload.php?group_id=58972";
}

sub run_gpsbabel {
    my($self, $cmdargs) = @_;
    $self->gpsbabel_available; # make sure it is available
    my @cmd = ($GPSBABEL, @$cmdargs);
    warn "Run\n    @cmd\n    ...\n" if $DEBUG;
    my $stderr;
    if (eval { require IPC::Run; defined &IPC::Run::run }) {
	my($stdout,$stdin);
	my $disable_tk_stderr = defined &Tk::Exists && Tk::Exists($main::top) && $main::top->can("RedirectStderr") && Tk::Exists($main::top->StderrWindow);
	$main::top->RedirectStderr(0) if $disable_tk_stderr;
	IPC::Run::run(\@cmd, \$stdin, \$stdout, \$stderr);
	$main::top->RedirectStderr(1) if $disable_tk_stderr;
    } else {
	system @cmd;
    }
    if ($? != 0) {
	my $msg = "A problem occurred when running <@cmd>:\n$stderr\nExit code=$?";
	if (defined &main::status_message) {
	    main::status_message($msg, "die");
	} else {
	    die $msg;
	}
    }
}

1;

__END__
