# -*- perl -*-

#
# $Id: Storable.pm,v 1.7 2003/01/08 20:14:59 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# see results in ../../miscsrc/strassen_benchmark.pl

package Strassen::Storable;
use strict;
use vars qw($VERBOSE);

if (!caller) {
    require Getopt::Long;
    my $force  = 0;
    my $update = 0;
    my $verbose;
    if (!Getopt::Long::GetOptions("v+" => \$verbose,
				  "f" => \$force, "u" => \$update)) {
	die "Usage $0 [-v] [-f] [-u] from to";
    }

    my $from = shift or die "Strassen source missing";
    my $to   = shift or die "Strassen::Storable target missing";

    print STDERR "$from => $to" if $verbose;

    if (-e $to && !$force) {
	die "Target $to already exists and -f option not set";
    }
    if ($to !~ /\.st$/) {
	die "Target $to should have the extension .st";
    }

    if ($update && (-e $to && -M $to <= -M $from)) {
	print STDERR " (nothing to do)\n" if $verbose;
	exit(0);
    }

    require FindBin;
    push @INC, "$FindBin::RealBin/..";
    require Strassen;

    my $from_str = Strassen->new($from);
    my $to_str   = Strassen::Storable->new(undef);

    $to_str->create_cooked_data($from_str);
    $to_str->write($to);

    print STDERR " (done)\n" if $verbose;
}

# Only here to die if Strassen::Storable is required but no Storable.pm
# available
require Storable;

sub new {
    my($class, $filename, %args) = @_;
    my $self = {};
    bless $self, $class;

    if (defined $filename) {
	$filename .= ".st" unless $filename =~ /\.st$/;
	foreach my $dir ("", @Strassen::datadirs, ".") {
	    my $f = "$dir/$filename";
	    if (-r $f) {
		require Storable;
		$self->{CookedData} = Storable::retrieve($f);
		if ($self->{CookedData}) {
		    $self->{File} = $f;
		    return $self;
		}
	    }
	}
	return undef;
    }

    $self;
}

sub file { shift->{File} }

sub write {
    my($self, $filename) = @_;
    $filename = $self->file if !defined $filename;
    return 0 if !defined $filename;
    require Storable;
    if (!Storable::store($self->{CookedData}, $filename)) {
	warn "Can't write to $filename: $!" if $VERBOSE;
	return 0;
    }
    1;
}

# convert normal Strassen data to cooked Strassen::Storable data
sub create_cooked_data {
    my($self, $orig_strassen) = @_;

    $self->{CookedData} = [];
    $orig_strassen->init;
    while(1) {
	my $r = $orig_strassen->next;
	last if !@{ $r->[1] };
	push @{ $self->{CookedData} }, $r;
    }
}

sub count { scalar @{ $_[0]->{CookedData} } }
sub pos   { $_[0]->{Pos} }
sub init  { $_[0]->{Pos} = -1 }
sub first { $_[0]->{Pos} = 0; $_[0]->get(0) }
sub next  { $_[0]->get(++($_[0]->{Pos})) }
sub get   {
    my($self, $pos) = @_;
    if ($pos > $#{ $self->{CookedData} }) {
	[undef, [], undef];
    } else {
	$self->{CookedData}[$pos];
    }
}

# delegate to pseudo SUPER class (Strassen.pm)
sub get_hashref { shift->Strassen::get_hashref(@_) }

$Strassen::can_strassen_storable = 1;

1;

__END__
