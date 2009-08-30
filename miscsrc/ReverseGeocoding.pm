#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package ReverseGeocoding;

use strict;
use Geo::Cloudmade;

sub new {
    my $class = shift;

    my $apikey = do {
	my $file = "$ENV{HOME}/.cloudmadeapikey";
	open my $fh, $file
	    or main::status_message("Cannot get key from $file: $!", "die");
	local $_ = <$fh>;
	chomp;
	$_;
    };

    my $geo = Geo::Cloudmade->new($apikey);

    bless { geo => $geo }, $class;
}

sub find_closest {
    my($self, $pxy, $type) = @_;
    $type = 'area' if !$type;
    my($px, $py) = split /,/, $pxy;

    my($res) = $self->{geo}->find_closest($type, [$py, $px], {return_geometry=>'False'});
    $res->name;
}

return 1 if caller;

{
    require Getopt::Long;
    my $type;
    Getopt::Long::GetOptions('type=s' => \$type) or die "usage?";
    die "Expects longitude and latitude" if @ARGV != 2;
    my($px, $py) = @ARGV;
    print __PACKAGE__->new->find_closest("$px,$py", $type), "\n";
}

__END__

=head1 EXAMPLES

Using from command line:

    perl miscsrc/ReverseGeocoding.pm 13.5 52.5

=cut
