# -*- perl -*-

#
# $Id: Telefonbuch2001.pm,v 1.4 2003/01/06 02:46:27 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Telefonbuch2001;
use base qw(Telefonbuch99);
use Karte::T2001;
use BBBikeUtil;
use FindBin;
use Config;
use strict;
no locale; # too buggy!
use vars qw($VERBOSE $strdbbasefile $teldbbasefile $dbroot);
$VERBOSE = 0 if !defined $VERBOSE;

local $ENV{PATH} = $ENV{PATH};

use constant str_abs_start_  => 0x1c1f;     # start of data
use constant str_abs_end_    => 0x0199F4F0; # end of data
use constant str_bufsize_    => 2048;
use constant str_datastart_  => 32;         # start of record data XXX

use constant tel_abs_start_  => 28703;      # start of data
use constant tel_abs_end_    => 0x0A3C046E; # end of data
use constant tel_bufsize_    => 4096;
use constant tel_datastart_  => 24;         # start of record data

$strdbbasefile = "straverz";
$teldbbasefile = "tverz";

*my_die = (defined &main::status_message
	   ? sub { main::status_message($_[0], "die") }
	   : sub { die $_[0] }
	  );

sub strdbbasefile { $strdbbasefile }
sub teldbbasefile { $teldbbasefile }

sub dbroot { $dbroot }

sub set_dbroot {
    my $self = shift;
    $self->SUPER::set_dbroot(@_);

    $ENV{PATH} .= $Config{'path_sep'}."$FindBin::RealBin/miscsrc";
    if (!is_in_path("telekom")) {
	my_die("Das Programm \"telekom\" muss im PATH ($ENV{PATH}) sein");
    }
}

sub database { 2001 }

my %key2inx = ('str_hnr' => 1,
	       'str_name' => 0,
	       'str' => 0,
	       'hnr' => 1,
	       'plz' => 2,
	       'ort' => 3,
	       'str_x' => 4,
	       'x' => 4,
	       'str_y' => 5,
	       'y' => 5,
	       'name' => 6,
	       'vorname' => 7,
	       'telnr_voice' => 8,
	      );

# Rückgabe: ein Array von Items, jeweils im
# [Straße, Hausnummer, PLZ, Ort, X, Y]-Format
sub search_street_hnr {
    my($tel, $str, $hnr, $plz) = @_;

    my $cmd = "telekom -f straverz str_name='" . $str . ".*'";
    if (defined $hnr && $hnr ne "") {
	$cmd .= " str_hnr='$hnr'";
    }
    warn "cmd=$cmd";

    my @res;
    my $res = [];

    my $push = sub {
	if (@$res) {
	    @{$res}[4,5] = convert_xy(@{$res}[4,5]);
	    push @res, $res;
	    $res = [];
	}
    };

    open(OUT, "$cmd|") or my_die($!);
    while(<OUT>) {
	if (/^-/) {
	    $push->();
	} elsif (/^(str_\S+)\s*:\s*(.*)/) {
	    my($key, $val) = ($1, $2);
	    if ($key eq 'str_name') {
		if ($val =~ /^(.*)\s+\((.*)\)\s+\((0x[0-9a-f]+)\)$/) {
		    $res->[3] = $2;
		    $val = $1;
		}
	    }
	    $res->[$key2inx{$key}] = $val
		if defined $key2inx{$key};
	}
    }
    $push->();
    close OUT;

    [@res];

}

# Rückgabe: ein Array von Items, jeweils im
# [Straße, Hausnummer, PLZ, Ort, X, Y, Nachname, Vorname, Telefon]-Format
sub search_name {
    my($tel, $nname, $vname, %args) = @_;
    my $cmd = "telekom -long name='" . $nname . (!$args{-exact} ? ".*" : "") . "'";
    if (defined $vname && $vname ne "") {
	$cmd .= " vorname='$vname'";
    }
    warn "cmd=$cmd";


    my @res;
    my $res = [];

    my $push = sub {
	if (@$res && $res->[4] && $res->[5]) {
	    @{$res}[4,5] = convert_xy(@{$res}[4,5]);
	    push @res, $res;
	}
	$res = [];
    };

    open(OUT, "$cmd|") or my_die($!);
    while(<OUT>) {
	if (/^-/) {
	    $push->();
	} elsif (/^(\S+)\s*:\s*(.*)/) {
	    my($key, $val) = ($1, $2);
	    if ($key =~ /^(name|ort|plz|str|vorname)/) {
		$val =~ s/\s+\((0x[0-9a-f]+)\)$//;
	    }
	    $res->[$key2inx{$key}] = $val
		if defined $key2inx{$key};
	}
    }
    $push->();
    close OUT;

    [@res];
}

sub convert_xy {
    my($x, $y) = @_;
    $Karte::T2001::obj->map2standard($x, $y);
}

1;

__END__
