# -*- perl -*-

package myclassstruct;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

sub import {
    my $class   = shift;
    my $callpkg = caller(0);
    my @properties = @_ or return;
    $class->create_accessors_for($callpkg, @properties);
    $class->create_new_for($callpkg);
}

sub create_accessors_for {
    my $class   = shift;
    my $callpkg = shift;
    foreach my $property (@_) {
	my $accessor = "$callpkg\::$property";
	$class->create_accessor( $accessor, $property );
    }
}

sub create_accessor {
    my($class, $accessor, $property) = @_;
    my $acc = sub {
	(
	 (@_ > 1)
	 ? $_[0]->{$property} = $_[1]
	 : $_[0]->{$property}
	);
    };
    no strict 'refs';
    *{$accessor} = $acc;
}

sub create_new_for {
    my $class   = shift;
    my $callpkg = shift;
    my $new = sub {
	my $class = shift;
	my $self = bless {}, $class;
	if (@_) {
	    my %args = @_;
	    while(my($k,$v) = each %args) {
		$self->$k($v);
	    }
	}
	$self;
    };
    no strict 'refs';
    *{$callpkg . "::new"} = $new;
}

1;

__END__

=head1 NAME

myclassstruct - create accessor methods

=head1 SYNOPSIS

    package Foo;
    use myclassstruct qw(a b c);

=head1 DESCRIPTION

This is a stripped-down version of the CPAN module
L<accessors::classic>, and a OO-capable version of L<Class::Struct>.

Notable differences to L<accessors::classic>:

=over

=item * The key names of the internal hash do not have a preceding
dash (-).

=item * There's no support for debugging, different export levels etc.
(which are in the original accessors.pm, but not documented).

=item * There are no checks for invalid accessor names like C<BEGIN>.

=item * The generated accessor is strict-safe.

=back

=head1 AUTHOR

Slaven Rezic.

Steve Purkis wrote the original L<accessors::classic>.

=cut
