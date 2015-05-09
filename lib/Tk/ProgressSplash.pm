# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2001,2012 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::ProgressSplash;
#use strict;use vars qw($TK_VERSION $VERSION $firstupdatetime $lastcallindex);
$VERSION = 0.05;
$TK_VERSION = 800 if !defined $TK_VERSION;

sub Show {
    my($pkg, @args) = @_;

    Tk::ProgressSplash::_ProgressLog($pkg, 0.0, 'create splash');

    my @splash_arguments;
    my $splashtype = 'normal';
    for(my $i=0; $i<=$#args; $i++) {
	if ($args[$i] eq '-splashtype') {
	    $splashtype = $args[$i+1];
	    $i++;
	} elsif ($args[$i] =~ /^-/) {
	    die "Unrecognized option $args[$i]";
	} else {
	    push @splash_arguments, $args[$i];
	}
    }

    my $self = {};

    my $Splash;
    if ($splashtype eq 'fast') {
	require Tk::FastSplash;
	$Splash = 'Tk::FastSplash';
    } else {
	require Tk::Splash;
	$Splash = 'Tk::Splash';
    }

    my $splash = $Splash->Show(@splash_arguments);
    # XXX if fast
    my $f_path = '.splashframe';
    my $f = Tk::frame($splash, $f_path,
		      -height => 10,
		      -bg => 'blue',
		     );
    if (!ref $f) {
	# >= Tk803
	$f = Tk::Widget::Widget($splash, $f);
    }
    $f->{'_TkValue_'} = $f_path;
    bless $f, 'Tk::Widget';
    Tk::pack($f, -anchor => 'w'); # , -padx => 2, -pady => 2);

    $splash->{ProgressFrame} = $f;

    $splash;
}

sub Tk::Splash::Update     { Tk::ProgressSplash::Update(@_) }
sub Tk::FastSplash::Update { Tk::ProgressSplash::Update(@_) }

sub Update {
    my($w, $frac, $debuginfo) = @_;
    Tk::configure($w->{ProgressFrame}, -width => $w->{ImageWidth}*$frac);
    Tk::update($w);
    Tk::ProgressSplash::_ProgressLog($w, $frac, $debuginfo);
}

sub _ProgressLog {
    if ($ENV{TK_SPLASH_COMPUTE}) {
	my(undef, $frac, $debuginfo) = @_; # first arg is $w or $pkg
	if (!defined $lastcallindex) {
	    $lastcallindex = 0;
	    $firstupdatetime = defined &Tk::timeofday ? Tk::timeofday() : time;
	} else {
	    $lastcallindex++;
	    my $time = (defined &Tk::timeofday ? Tk::timeofday() : time) - $firstupdatetime;
	    print "    $time,\t# Update $lastcallindex frac=$frac # $debuginfo\n";
	}
    }
}

1;

=head1 NAME

Tk::ProgressSplash - create a starting splash screen with a progress bar

=head1 SYNOPSIS

    BEGIN {
        require Tk::ProgressSplash;
        $splash = Tk::ProgressSplash->Show(-splashtype => 'normal',
                                           $image, $width, $height, $title,
                                           $overrideredirect);
    }
    ...
    use Tk;
    ...
    $splash->Update(0.1) if $splash;
    ...
    $splash->Update(1.0) if $splash;
    ...
    $splash->Destroy if $splash;
    MainLoop;

=head1 DESCRIPTION

Create a splash screen with progress bar.

=head2 METHODS

=over

=item Show

The Show() method takes the same arguments as the Show() method of
L<Tk::Splash>. Additionally you can specify:

=over

=item -splashtype

Set to "fast" if you want to use L<Tk::FastSplash> instead of
L<Tk::Splash> as the underlying splash widget. "normal", "safe" or
"slow" may be used for L<Tk::Splash>. Default is "normal". Please look
at L<Tk::FastSplash/CAVEAT> for problems with the "fast" approach (and
why you don't want it at all).

=back

=item Update

Advance the progressbar and make it visible, if it was not yet
visible. The argument is a floating number between 0 and 1.

=item Destroy

Destroy the splash widget.

=back

=head2 PROGRESS SPEED COMPUTATION

To adjust the Update() value to the real progress speed one can set
the environment variable C<TK_SPLASH_COMPUTE> to gather some
information:

    env TK_SPLASH_COMPUTE=1 bbbike -public | tee /tmp/bbbike.log

The resulting file can be processed like this:

    perl -nle '/^\s*([\d\.]+).*frac=([\d\.]+)/ and push @x, [$1,$2]; END { for (@x) { my($time,$frac) = @$_; printf "%.4f -> %.4f\n", $frac, ($time/$x[-1]->[0]) } }' /tmp/bbbike.log

=head1 BUGS

See L<Tk::Splash> and L<Tk::FastSplash>.

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 SEE ALSO

L<Tk::Splash>, L<Tk::FastSplash>.

=cut

__END__
