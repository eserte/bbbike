# -*- perl -*-

#
# $Id: BBBikeSOAP.pm,v 1.10 2007/03/15 21:17:21 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Online Office Berlin. All rights reserved.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeSOAP;

### XXX how to debug???
BEGIN {

use Data::Dumper;
$Data::Dumper::Indent = 0;

sub logger {
#return; # DISABLED
  my $caller = (caller(2))[3];
  $caller = (caller(2))[3] if $caller =~ /eval/;
  chomp(my $msg = Data::Dumper->Dumpxs([@_],[]));
  open(LOG, ">>/tmp/bbbikesoap-trace.log");
  printf LOG "%s: %s\n", $caller, $msg;
  close LOG;
}

use SOAP::Lite +trace => 'all' => \&logger;
#  sub {
#    my $caller = (caller(2))[3];
#    $caller = (caller(2))[3] if $caller =~ /eval/;
#    chomp(my $msg = Data::Dumper->Dumpxs([@_],[]));
#    open(LOG, ">>/tmp/bbbikesoap-trace.log");
#    printf LOG "%s: %s\n", $caller, $msg;
#    close LOG;
#  };

sub SOAP::Serializer::envelope {
  my $self = shift->new;
  my $type = shift;

  my(@parameters, @header);
  for (@_) { 
    defined $_ && ref $_ && UNIVERSAL::isa($_ => 'SOAP::Header')
      ? push(@header, $_) : push(@parameters, $_);
  }
  my $header = SOAP::Data->set_value(@header);
  my($body,$parameters);
  if ($type eq 'method') {
    SOAP::Trace::method(@parameters);
    my $method = shift(@parameters) or die "Unspecified method for SOAP call\n";
    $parameters = SOAP::Data->set_value(@parameters);
    $body = UNIVERSAL::isa($method => 'SOAP::Data') 
      ? $method->value(\$parameters)
      : SOAP::Data->name($method => \$parameters)->uri($self->uri);
    $body->attr->{_preserve} = 1; # always preserve method element
  } elsif ($type eq 'fault') {
    SOAP::Trace::fault(@parameters);
    $body = SOAP::Data
      -> name(SOAP::Utils::qualify($self->envprefix => 'Fault'))
    # commented on 2001/03/28 because of failing in ApacheSOAP
    # need to find out more about it
    # -> attr({'xmlns' => ''})
      -> value(\SOAP::Data->set_value(
        SOAP::Data->name(faultcode => SOAP::Utils::qualify($self->envprefix => $parameters[0])),
        SOAP::Data->name(faultstring => $parameters[1]),
        defined($parameters[2]) ? SOAP::Data->name(detail => do{my $detail = $parameters[2]; ref $detail ? \$detail : $detail}) : (),
        defined($parameters[3]) ? SOAP::Data->name(faultactor => $parameters[3]) : (),
      ));
  } elsif ($type eq 'freeform') {
    SOAP::Trace::freeform(@parameters);
    $body = SOAP::Data->set_value(@parameters);
  } else {
    die "Wrong type of envelope ($type) for SOAP call\n";
  }

  $self->seen({}); # reinitialize multiref table
  my($encoded) = $self->encode_object(
    SOAP::Data->name(SOAP::Utils::qualify($self->envprefix => 'Envelope') => \SOAP::Data->value(
      SOAP::Data->name(SOAP::Utils::qualify($self->envprefix => 'Header') => \$header),
      SOAP::Data->name(SOAP::Utils::qualify($self->envprefix => 'Body')   => \$body)
    ))->attr($self->attr)
  );
  $self->signature($parameters->signature) if ref $parameters;

  # IMHO multirefs should be encoded after Body, but only some
  # toolkits understand this encoding, so we'll keep them for now (04/15/2001)
  # as the last element inside the Body 
  push(@{$encoded->[2]->[1]->[2]}, $self->encode_multirefs);
  my $envelope =  join '', qq!<?xml version="1.0" encoding="@{[$self->encoding]}"?>!,
                  $self->xmlize($encoded);

  SOAP::Trace::trace($envelope);

  $envelope;
}

}

use strict;
use vars qw($VERSION @ISA
	    $s $plz $net $cr $_cr %cinemas);
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

BEGIN {
#      eval 'use FindBin';
#      if (!defined $FindBin::RealBin || !-d $FindBin::RealBin) {
#  	require Cwd;
#  	$FindBin::RealBin = Cwd::cwd();
  	if (!defined $FindBin::RealBin || !-d $FindBin::RealBin) {
	    $FindBin::RealBin = "/home/e/eserte/src/bbbike-stable/miscsrc";
	}
#    }
}

use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	 "$FindBin::RealBin/../miscsrc",
	);
use Strassen;
use Karte; BEGIN { Karte::preload(":all") }
use BBBikeXS;
use PLZ;

# return 0 or 1
sub validate_address {
    my($self, $address) = @_;

    my $street   = $address->{'street'};
    my $zip      = $address->{'zip'};
    my $citypart = $address->{'citypart'};

    my $plz = _plz();
    my @res = $plz->look_loop($street, LookCompat => 1);
    return !!@res; # XXX
}

# returns array of addresses
sub get_address_coords {
    my($self, $address, %args) = @_;

    my $street   = $address->{'street'};
    my $zip      = $address->{'zip'};
    my $citypart = $address->{'citypart'};

    my @res;
    {
	my $plz = _plz();
	my %args;
	if (defined $zip && $zip ne "") {
	    $args{Citypart} = $zip;
	} elsif (defined $citypart && $citypart ne "") {
	    $args{Citypart} = $citypart;
	}
	@res = $plz->look_loop($street, %args, LookCompat => 1);
    }

    my @ret;
    foreach my $res (@res) {
	my $xy = $res->[3];
	$xy = _fix_coords($xy);
	my($x,$y) = split /,/, $xy;
	my $coord_obj = {'street' => $res->[0],
			 'citypart' => $res->[1],
			 'zip' => $res->[2],
			 'x' => $x, 'y' => $y,
			 'coordtype' => 'hafas'}; # XXX quality
	_convert_address_coordtype($coord_obj, $args{'-coordtype'});
	push @ret, $coord_obj;
    }

    \@ret;
}

sub get_address_coords_obj {
    my $self = shift;
    my $ret = $self->get_address_coords(@_);
    my $ret_obj = [];
    foreach my $elem (@$ret) {
	push @$ret_obj, BBBikeSOAP::Address->new(%$elem);
    }
    $ret_obj;
}


# NYI
sub get_coord_address {
    my($self, $coord) = @_;
    die "NYI";
}

sub get_route {
    my($self, $start, $goal, $search_constraints, $output_format) = @_;

    _convert_address_coordtype($start, 'hafas');
    _convert_address_coordtype($goal, 'hafas');

#    die "Start coord type must be hafas" if $start->{'coordtype'} ne 'hafas';
#    die "Goal coord type must be hafas"  if $goal->{'coordtype'} ne 'hafas';

    my $start_coord = $start->{'x'} . "," . $start->{'y'};
    my $goal_coord  = $goal->{'x'}  . "," . $goal->{'y'};

    my $net = _net();
    my @res = $net->search($start_coord, $goal_coord);
    if (@res == 0) {
	die "Can't find route between $start_coord and $goal_coord";
	[];
    } else {
	my @ret;
	foreach my $hop ($net->route_info(Route => $res[0], Km => 0)) {
	    my $ret_hop = {'street'    => $hop->{Street},
			   'direction' => $hop->{Way},
			   'hop'       => $hop->{'Hop'},
			  };
		push @ret, $ret_hop;
	}
	\@ret;
    }
}

sub get_route_obj {
    my $self = shift;
    my $ret = $self->get_route(@_);
    my $ret_obj = [];
    foreach my $elem (@$ret) {
	push @$ret_obj, BBBikeSOAP::Hop->new(%$elem);
    }
    $ret_obj;
}

sub get_route_lengths {
    my($self, $start, $goals) = @_;
    _convert_address_coordtype($start, 'hafas');
    foreach (@$goals) {
	_convert_address_coordtype($_, 'hafas');
    }

    my @ret;

    my $start_coord = $start->{'x'} . "," . $start->{'y'};
    my $net = _net();

    foreach my $goal (@$goals) {
	my $goal_coord  = $goal->{'x'}  . "," . $goal->{'y'};
	my @res = $net->search($start_coord, $goal_coord);
	if (@res) {
	    push @ret, int $res[&StrassenNetz::RES_LEN];
	} else {
	    push @ret, undef;
	}
    }

    \@ret;
}

sub get_route_lengths_obj {
    my $self = shift;
    $self->get_route_lengths(@_);
}

sub get_route_overview {
    my($self, $start, $goals, $search_constraints);
    die "NYI";
}

sub get_crossings {
    my($self, $address, %args) = @_;
    _convert_address_coordtype($address, 'hafas');

    my $s = _strassen();
    my @coords;
    $s->init;
 SEARCH_STREET:
    while(1) {
	my $ret = $s->next;
	last if !@{ $ret->[Strassen::COORDS] };
	if ($ret->[Strassen::NAME] =~ /^$address->{'street'}/ ) {
	SEARCH_COORDS: {
		foreach my $xy (@{ $ret->[Strassen::COORDS] }) {
		    my($x,$y) = split /,/, $xy;
		    if ($address->{'x'} == $x ||
			$address->{'y'} == $y) {
			last SEARCH_COORDS;
		    }
		}
		next SEARCH_STREET;
	    }
	    push @coords, @{ $ret->[Strassen::COORDS] };
	}
    }

    my $cr = _crossings();
    my $ret = [];
    foreach my $c (@coords) {
	my($x,$y) = split /,/, $c;
	if (ref $cr->{Hash}{$c} eq 'ARRAY') {
	    my $coord_obj =
		{'street' => join("/", @{ $cr->{Hash}{$c} }),
		 'x'      => $x,
		 'y'      => $y,
		 'coordtype' => 'hafas',
		};
	    _convert_address_coordtype($coord_obj, $args{'-coordtype'});
	    push @$ret, $coord_obj;
	}
    }
    $ret;
}

sub _convert_address_coordtype {
    my($address, $target_type) = @_;

    if (!defined $target_type || $target_type eq '') {
	return;
    }

    my $from_type = $address->{'coordtype'};
    $from_type   = 'standard' if $from_type   eq 'hafas';
    $target_type = 'standard' if $target_type eq 'hafas';
    if ($from_type eq $target_type) {
	return;
    }

    if (!$Karte::map{$from_type}) {
	die "Coordtype of address @{[%$address]} `$from_type' is unknown";
    }
    if (!$Karte::map{$target_type}) {
	die "Target coordtype `$target_type' is unknown";
    }

    my($newx, $newy) = $Karte::map{$from_type}->map2map($Karte::map{$target_type}, $address->{'x'}, $address->{'y'});
    $address->{'x'} = $newx;
    $address->{'y'} = $newy;
    $target_type = 'hafas' if $target_type eq 'standard';
    $address->{'coordtype'} = $target_type;
}

sub _plz {
    return $plz if defined $plz;
    $plz = new PLZ;
}

sub _strassen {
    return $s if defined $s;
    $s = new Strassen "strassen";
}

sub _crossings {
    if (!$cr) {
	if (scalar keys %$_cr == 0) {
	    $_cr = $s->all_crossings(RetType => 'hash',
				    UseCache => 1);
	}

	$cr = new Kreuzungen Hash => $_cr;
	$cr->make_grid;
    }
    $cr;
}

sub _net {
    return $net if defined $net;
    my $s = _strassen;
    $net = new StrassenNetz $s;
    $net->make_net;
    $net;
}

sub _cinemas {
    if (!keys %cinemas) {
	unshift @Strassen::datadirs, "$FindBin::RealBin/condat";
	my $k = Strassen->new("kinos.bbd");
	$k->init;
	while(1) {
	    my $ret = $k->next;
	    last if !@{ $ret->[Strassen::COORDS] };
	    my($name, $street, $zip, $id) = split /;/, $ret->[Strassen::NAME];
	    my($x,$y) = split /,/, $ret->[Strassen::COORDS][0];
	    $cinemas{$id} = {'street' => $street,
			     'name'   => $name,
			     'zip'    => $zip,
			     'x' => $x, 'y' => $y,
			     'coordtype' => 'hafas',
			     'id'        => $id,
			    };
	}
    }
}

sub get_cinema_address {
    my($self, $id) = @_;
    _cinemas();
    $cinemas{$id};
}

sub get_nearest_cinema_from_list_by_id {
    my($self, $start, $cinema_ids) = @_;
    my @cinemas;
    foreach (@$cinema_ids) {
	my $adr = $self->get_cinema_address($_);
	push @cinemas, $adr if ($adr);
    }
    $self->get_nearest_cinema_from_list($start, \@cinemas);
}

sub get_nearest_cinema_from_list {
    my($self, $start, $cinemas) = @_;
    my $start_c = "$start->{'x'},$start->{'y'}";
    my @sorted = sort {
	Strassen::Util::strecke_s("$a->{'x'},$a->{'y'}", $start_c)
				<=>
	Strassen::Util::strecke_s("$b->{'x'},$b->{'y'}", $start_c)
    } @$cinemas;
    \@sorted;
}

sub get_nearest_cinema {
    my($self, $start, $count) = @_;
    _convert_address_coordtype($start, 'hafas');

    my @sorted_cinemas;
    _cinemas();
    while(my($id,$cinema) = each %cinemas) {
	my $entf = Strassen::Util::strecke([$cinema->{'x'}, $cinema->{'y'}],
					   [$start->{'x'},  $start->{'y'}]);
	push @sorted_cinemas, [$id, $entf];
    }

    @sorted_cinemas = sort { $a->[1] <=> $b->[1] } @sorted_cinemas;
    splice @sorted_cinemas, $count if defined $count;

    # append "distance" information to cinema objects
    $cinemas{$_->[0]}->{'approxdistance'} = $_->[1]
	for @sorted_cinemas;

    [ map { $cinemas{$_->[0]} } @sorted_cinemas ];
}

# falls die Koordinate nicht exakt existiert, wird der nächste Punkt
# gesucht und gesetzt
sub _fix_coords {
    my($coord) = @_;
    my $net = _net();
    if (!exists $net->{Net}{$coord}) {
	my $cr = _crossings();
	my(@nearest) = $cr->nearest_coord($coord);
	if (@nearest) {
	    $coord = $nearest[0];
	}
    }
    $coord;
}

package GenericObject;
sub new {
    my($pkg, %hash) = @_;
    my $self = {%hash};
    bless $self, $pkg;
}

package BBBikeSOAP::Address;
@BBBikeSOAP::Address::ISA = 'GenericObject';

package BBBikeSOAP::Hop;
@BBBikeSOAP::Hop::ISA = 'GenericObject';

#  package BBBikeSOAP;

1;

__END__

=head1 NAME

BBBikeSOAP - SOAP interface for BBBike routing

=head1 SYNOPSIS


=head1 DESCRIPTION

=head2 DATA STRUCTS

The following data types (SOAP structs) are used in the methods:

=over 4

=item address

An address specification, with or without coordinate information. The
address specification may be incomplete. The fields are

=over 8

=item street

The name of the street.

=item number

The house number.

=item citypart

The part of the city (e.g. "Bezirk").

=item zip

The ZIP code of the address.

=item city

Not used.

=item country

Not used.

=item x

The x coordinate of the address in the coordinate system given by the
coordtype member.

=item y

The y coordinate of the address.

=item coordtype

Type of the coordinate system (e.g. WGS-84). Only "hafas" is defined
at this time.

=item name

The name of the point (if applicable, for example the name of a cinema).

=item id

The id of the point (if applicable, for example the id of a cinema).

=item approxdistance

Some methods will include the approximate distance in meters from a
start point to this address.

=back

=item hop

Information for a route hop.

=over 8

=item hop

Length in meters for this hop.

=item direction

The direction to turn at the beginning of a hop. "R" stands for right,
"L" for left. The value can be prefixed with "H" for "half". If this
field is empty or an empty string, then it means "keep straight on".
The direction field of the first hop is always empty.

=item street

Name of the street of this hop.

=back

=back

=head2 CLASSES

Classes are used in methods ending with "_obj". All members are
probably strings in the non-perl world.

=over 4

=item BBBikeSOAP::Address

This object corresponds to the L<address|/address> struct.

=item BBBikeSOAP::Hop

This object corresponds to the L<hop|/"hop"> struct.

=back

=head2 METHODS

These methods are implemented:

=over 4

=item validate_address(address)

Return 1, if the address is valid, otherwise 0.

=item get_address_coords(address)

For a given address, return an array of matching addresses, filled
with coordinates.

=item get_address_coords_obj(address)

Same as get_address_coords, but accepts a
L<BBBikeSOAP::Address|/BBBikeSOAP::Address> object and returns an array
of L<BBBikeSOAP::Address|/BBBikeSOAP::Address> objects.

=item get_crossings(address)

Return a list of addresses with the crossings of the street in the
given address. Only the street, x, y, and coordtype fields are filled.
The street field is concatenated with the streets at this crossing,
e.g. "Dudenstr./Methfesselstr./Mussehlstr.".

=item get_route(start_address,goal_address)

Perform a search for a route between a start address and a goal
address. The addresses should have valid coordinates. Return an array
of route hops. The function raises an exception if no route can be
found between start and goal.

=item get_route_obj(start_address,goal_address)

Same as get_route, but accepts
L<BBBikeSOAP::Address|/BBBikeSOAP::Address> objects and returns an array
of L<BBBikeSOAP::Hop|/BBBikeSOAP::Hop> objects.

=item get_route_lengths(start_address,goal_addresses)

Return the lengths of the routes between start_address and the
goal_addresses. goal_addresses should be an array of address structs.
The returned value is an array of lengths in meters. Each entry of the
returned array corresponds to the given goal_address. If a route cannot
be calculated to a goal_address, the sorresponding array element will
be null/undefined.

=item get_route_lengths(start_address,goal_addresses)

Same as get_route_lengths, but accepts
L<BBBikeSOAP::Address|/BBBikeSOAP::Address> object for start_address
and an array of L<BBBikeSOAP::Address|/BBBikeSOAP::Address> objects
for goal_addresses.

=item get_route_overview(start_address,goal_addresses)

NYI

=item get_cinema_address(id)

Return the address of the cinema with the given id (which must be a
string). If no cinema is found, then undefined is returned.

=item get_nearest_cinema_from_list_by_id(start_adress, cinema_ids)

Return a list of the expanded cinema addresses, sorted by the approximate
distance from the start address.

=item get_nearest_cinema_from_list(start_adress, cinema_addresses)

Same as get_nearest_cinema_by_id, but use a list of cinema addresses
as input parameter.

=item get_nearest_cinema(start_adress, count)

Returns a list of the nearest cinema addresses from the specified
start point. The list is sorted by the approximate distance and
limited to I<count> entries (if count is defined). This method will
include the approxdistance field to the address object (see above).

=back

=head1 Running interface

The current paramters for the BBBikeSOAP interface are:

     proxy: http://194.140.111.226:8080/soapbbbike
     URN: BBBikeSOAP

You can test the interface with the SOAPsh.pl script:

     SOAPsh.pl http://outerwww/soapbbbike BBBikeSOAP

or (to test from outer space):

     SOAPsh.pl http://194.140.111.226:8080/soapbbbike BBBikeSOAP

=head1 Configuring Apache

In the configuration file C</etc/httpd/httpd.conf> or
C<.../outerwww.conf> a location specifier should be included:

    <Location /soapbbbike>
        <IfDefine PERL>
        SetHandler perl-script
        PerlHandler Apache::SOAP
        PerlSetVar dispatch_to "/home/e/eserte/src/bbbike/miscsrc, BBBikeSOAP"
        PerlSetVar options "compress_threshold => 10000"
        </IfDefine>
    </Location>

The first argument to C<dispatch_to> should be the directory
containing the C<BBBikeSOAP.pm> file. Of course, C<modperl> should be
compiled and activated in Apache.

=head1 AUTHOR

Slaven Rezic - slaven.rezic@berlin.de

=head1 SEE ALSO

SOAP::Lite(3).

=cut
