package your;

require 5.004;

use strict qw(vars subs);
use vars qw($VERSION);
$VERSION = '0.01';

=head1 NAME

your - Perl pragma to declare use of other package's variables

=head1 SYNOPSIS

    use your qw($Foo::bar @Moo::you %This::that);

=head1 DESCRIPTION

You should use variables from other packages with care, but as long as
you're going to, it doesn't hurt to predeclare it.

Currently, if you use another package's variables and only use it
once, Perl will throw a "variable used only once" warning.  vars.pm
won't allow you to declare other package's variables, and there are
various hack to get around that.  This package lets you declare "Yes,
I am going to use someone else's variables!"

    use Foo;
    use your qw($Foo::magic);
    print $Foo::magic;

=cut


sub import {
    my $caller = caller;
    my($class, @imports) = @_;

    foreach my $sym (@imports) {
        my($type, $name) = unpack('a1a*', $sym);
        unless( $name =~ /::/ ) {
            require Carp;
            Carp::croak("Can only declare other package's variables");
        }
        if( $name =~ tr/A-Za-z_0-9://c ) {
            if( $sym =~ /^\w+[\[{].*[\]}]$/ ) {
                require Carp;
                Carp::croak("Can't declare individual elements of a hash or array");
            }
            elsif ( $^H &= strict::bits('vars') ) {
                require Carp;
                Carp::croak("'$sym' is not a valid variable name under strict vars");
            }
        }
        *$name =
          (  $type eq "\$" ? \$$name
           : $type eq "\@" ? \@$name
           : $type eq "\%" ? \%$name
           : $type eq "\*" ? \*$name
           : $type eq "\&" ? \&$name
            : do {
                require Carp;
                Carp::croak("'$sym' is not a valid variable name");
            });
    }
}


=head1 AUTHOR

Michael G Schwern <schwern@pobox.com>

=head1 SEE ALSO

L<vars>, L<perlfunc/our>, L<perlfunc/my>, L<strict>

=cut

1;
