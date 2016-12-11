# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1999,2005,2008,2015 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.rezic.de/eserte/
#

package Tk::LogScale;
use strict;
use vars qw($VERSION @ISA);
use base qw(Tk::Frame);
use Tk;
Construct Tk::Widget 'LogScale';

$VERSION = '0.10';

sub ClassInit {
    my($class,$mw) = @_;
    $class->SUPER::ClassInit($mw);
    $mw->bind($class, "<Configure>" => sub {
		  # Make sure the showvalue number is on the
		  # right place after resizing.
		  my $w = shift;
		  $w->afterIdle(sub{$w->update_showvalue});
	      });
}

sub Populate {
    my($w, $args) = @_;

    $w->Component('Label', 'showvalue');
    $w->Component('Label', 'dummy');
    my $scale = $w->Component('Scale', 'scale',
			      -showvalue => 0,
			      -command => [ $w, 'scale_command']
			     );

    $w->ConfigSpecs
      (-variable  => ['PASSIVE',   'variable',  'Variable',   undef],
       -from      => ['PASSIVE',  'from',      'From',       1],
       -to        => ['PASSIVE',  'to',        'To',         100],
       -orient    => ['PASSIVE',  'orient',    'Orient',    'horizontal'],
       -func      => ['CALLBACK', 'func',      'Func',      \&logfunc],
       -invfunc   => ['CALLBACK', 'invFunc',   'InvFunc',   \&expfunc],
       -showvalue => ['PASSIVE',  'showValue', 'ShowValue',  1],
       -command   => ['CALLBACK', 'command',   'Command',   undef],
       -valuefmt  => ['CALLBACK', 'valueFmt',  'ValueFmt',   sub { int($_[0]) }],
       DEFAULT    => [$scale]);

    $w->SUPER::Populate($args);
}

sub ConfigChanged {
    my($w, $args) = @_;
    if (exists $args->{-showvalue}) {
	if ($args->{-showvalue}) {
	    $w->Subwidget('dummy')->grid(-column => 0, -row => 0);
	    $w->Subwidget('dummy')->lower;
	} else {
	    $w->Subwidget('dummy')->gridForget
	      if $w->Subwidget('dummy')->manager;
	    $w->SubWidget('showvalue')->placeForget
	      if $w->Subwidget('dummy')->manager;
	}
    }

    if (exists $args->{-orient} ||
	!$w->Subwidget('scale')->manager) {
	if ($args->{-orient} =~ /^h/) {
	    $w->gridColumnconfigure(0,-weight=>1);
	    $w->Subwidget('scale')->grid(-column => 0, -row => 1, -sticky => "news");
	} else {
	    $w->gridRowconfigure(0,-weight=>1);
	    $w->Subwidget('scale')->grid(-column => 1, -row => 0, -sticky => "news");
	}
	$w->Subwidget('scale')->configure
	  (-orient => $args->{-orient});
    }

    if (exists $args->{-from}) {
	$w->Subwidget('scale')->configure
	  (-from  => $w->Callback(-func, $args->{-from}));
    }
    if (exists $args->{-to}) {
	$w->Subwidget('scale')->configure
	  (-to    => $w->Callback(-func, $args->{-to}));
    }
    if (exists $args->{-to} ||
	exists $args->{-valuefmt}) {
	$w->Subwidget('dummy')->configure
	  (-width => length($w->Callback(-valuefmt, $args->{-to})));
    }

    if (exists $args->{-variable}) {
 	require Tie::Watch;
	# Pre-set current variable value, so Tie::Watch does not get
	# confused.
	$w->set($ { $args->{-variable} });
 	$w->{Watch} = new Tie::Watch
 	  -variable => $args->{-variable},
	  -fetch    => sub { $w->get        },
 	  -store    => sub { $w->set($_[1]) };
    }
}

sub scale_command {
    my($w, $scaleval) = @_;
    $w->{RealVal} = $w->Callback(-invfunc, $scaleval);
    if (defined $w->{Watch}) {
	# XXX eigentlich möchte ich lieber das hier machen:
#	$w->{Watch}->Store($w->{RealVal});
	$ { $w->cget(-variable) } = $w->{RealVal};
    }
    $w->update_showvalue;
    $w->Callback(-command, $w->{RealVal});
}

sub set {
    my($w, $realval) = @_;
    $w->{RealVal} = $realval;
    my $scaleval = $w->Callback(-func, $realval);
    if (defined $scaleval && $scaleval ne "") {
	$w->Subwidget("scale")->set($scaleval);
    }
    $w->update_showvalue;
}

sub update_showvalue {
    my($w) = @_;
    if ($w->cget(-showvalue)) {
	my $l     = $w->Subwidget('showvalue');
	my $scale = $w->Subwidget('scale');
	my $dummy = $w->Subwidget('dummy');
	$l->configure(-text => $w->Callback(-valuefmt, $w->{RealVal}));
	if ($w->cget(-orient) =~ /^h/) {
	    my($x) = $scale->x + ($scale->coords)[0];
	    my($y) = $dummy->y + $l->reqheight/2;
	    $l->place('-x' => $x, '-y' => $y, -anchor => "c");
	} else {
	    my($x) = $dummy->x + $l->reqwidth/2;
	    my($y) = $scale->y + ($scale->coords)[1];
	    $l->place('-x' => $x, '-y' => $y, -anchor => "c");
	}
    }
}

sub get {
    my($w) = @_;
    $w->{RealVal};
}

sub logfunc {
    eval { log $_[0] };
}

sub expfunc {
    exp $_[0];
}

1;

__END__

=head1 NAME

Tk::LogScale - A logarithmic Scale widget

=head1 SYNOPSIS

  use Tk::LogScale;
  $scale = $mw->LogScale(...);

=head1 DESCRIPTION

This is a Scale widget which uses a logarithmic scale for the position
of the thumb.

=head1 OPTIONS

B<Tk::LogScale> roughly uses the same options as in
L<Tk::Scale|Tk::Scale>. The B<-digits> option is not implemented. For
the B<-bigincrement> and B<-resolution>, translated values have to be
used. The B<-variable> option can only be used if the
L<Tie::Watch|Tie::Watch> module is installed (Note: C<Tie::Watch> is
in the Perl/Tk distribution since 800.022).

The following options are new to B<Tk::LogScale>:

=over 4

=item B<-func>

Function to translate from real values to internal scale values. By default this is the B<log> function. If you want the 10-log, you can set this option to
    sub { log($_[0])/log(10) }

=item B<-invfunc>

This should be the inverse function of B<-func>. By default this is the B<exp> function. For 10-log, use
    sub { 10**$_[0] }

=item B<-valuefmt>

Callback to format the value for B<-showvalue>. The default is to show
integer values.

=back

=head1 ADVERTISED SUBWIDGETS

=over 4

=item scale

The scale widget.

=item dummy

A dummy placeholder for the showvalue area.

=item showvalue

A label holding the current value of the scale. This one is placed
over/left to the thumb of the scale.

=back

=head1 BUGS

Multiple ties of the same variable specified in B<-variable> will lead
to unpredictable results.

There are still some unimplemented options.

The correct implementation of the B<-bigincrement>, B<-resolution> and
B<-tickinterval> options is unclear.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=head1 SEE ALSO

L<Tk::Scale>, L<Tie::Watch>.

=cut
