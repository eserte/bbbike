# -*- perl -*-

#
# $Id: CDB.pm,v 1.4 2005/03/28 22:48:50 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::CDB;
use strict;
use vars qw($VERSION);

$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

package StrassenNetz;
use CDB_File;

use Strassen::StrassenNetz;
use vars @StrassenNetz::EXPORT_OK;

sub create_cdb_file {
    my($self, $outbase, %args) = @_;

    die "Only allowed with data_format=FMT_HASH"
	if $data_format != $FMT_HASH;

    my $c_target = $args{-ctarget};

    my $net_f = $outbase.'_net.cdb';
    my $net   = new CDB_File $net_f, "/tmp/net.cdb"
	or die "Can't tie $net_f: $!";
    while(my($p1,$h) = each %{ $self->{Net} }) {
	my $val;
	while(my($p2,$entf) = each %$h) {
	    $val .= ':' if (defined $val);
	    $entf = pack('s', $entf) if $c_target;
	    $val .= "$p2:$entf";
	}
	$net->insert($p1,$val);
    }
    $net->finish;

    my $net2name_f = $outbase.'_net2name.cdb';
    my $net2name   = new CDB_File $net2name_f, "/tmp/net2name.cdb"
	or die "Can't tie $net2name_f: $!";
    while(my($p1,$h) = each %{ $self->{Net2Name} }) {
	my $val;
	while(my($p2,$pos) = each %$h) {
	    $val .= ':' if (defined $val);
	    $pos = pack('s', $pos) if $c_target;
	    $val .= "$p2:$pos";
	}
	$net2name->insert($p1,$val);
    }
    $net2name->finish;
}

sub use_data_format_cdb {
    *reachable = \&reachable_1;
}

1;

__END__
