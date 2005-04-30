# -*- perl -*-

#
# $Id: FastSplash.pm,v 1.18 2003/11/21 18:30:56 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.rezic.de/eserte/
#

package Tk::FastSplash;
#use strict;use vars qw($TK_VERSION $VERSION);
$VERSION = $VERSION = 0.14;
$TK_VERSION = 800 if !defined $TK_VERSION;

sub Show {
    my($pkg,
       $image_file, $image_width, $image_height, $title, $override) = @_;
    $title = $0 if !defined $title;
    my $splash_screen = {};
    eval {
	package
	    Tk; # hide from indexer
	require DynaLoader;
	eval q{ require Tk::Event };
	@Tk::ISA = qw(DynaLoader);
	bootstrap Tk;
	sub TranslateFileName { $_[0] }
	sub SplitString { split /\s+/, $_[0] } # rough approximation

	if (Tk::FontRankInfo->can("encoding")) {
	    $Tk::FastSplash::TK_VERSION = 804;
	}

	if ($Tk::FastSplash::TK_VERSION < 804) {
	    package
		Tk::Photo; # hide from indexer
	    @Tk::Photo::ISA = qw(DynaLoader);
	    bootstrap Tk::Photo;
	}

	if ($Tk::FastSplash::TK_VERSION >= 804) {
	    *Tk::getEncoding = \&Tk::FastSplash::getEncoding;
	}

	package Tk::FastSplash;
	sub _Destroyed { }
	$splash_screen = Tk::MainWindow::Create(".", $title);
	bless $splash_screen, 'Tk::MainWindow';
	$splash_screen->{"Exists"} = 1;

	if ($override) {
	    require Tk::Wm;
	    $splash_screen->overrideredirect(1);
	}

	my $img = Tk::image($splash_screen, 'create', 'photo', 'splashphoto',
			    -file => $image_file);
	bless $img, 'Tk::Image';
	$splash_screen->{Photo} = $img;
	$image_width = $img->width if !defined $image_width;
	$image_height = $img->height if !defined $image_height;
	my $sw = Tk::winfo($splash_screen, 'screenwidth');
	my $sh = Tk::winfo($splash_screen, 'screenheight');
	Tk::wm($splash_screen, "geometry",
	       "+" . int($sw/2 - $image_width/2) .
	       "+" . int($sh/2 - $image_height/2));

	$splash_screen->{ImageWidth} = $image_width;

	my(@fontarg) = ($TK_VERSION >= 800
			# dummy font to satisfy SplitString
			? (-font => "Helvetica 10")
			# no font for older Tk's
			: ());
	my $l_path = '.splashlabel';
	my $l = Tk::label($splash_screen, $l_path,
			  @fontarg,
			  -bd => 0,
			  -image => 'splashphoto');
	if (!ref $l) {
	    # >= Tk803
	    $l = Tk::Widget::Widget($splash_screen, $l);
	}
	$l->{'_TkValue_'} = $l_path;
	bless $l, 'Tk::Widget';
	Tk::pack($l, -fill => 'both', -expand => 1);
	Tk::update($splash_screen);
    };
    warn $@ if $@;
    bless $splash_screen, $pkg;
}

sub Raise {
    my $w = shift;
    if ($w->{"Exists"}) {
	Tk::catch(sub { Tk::raise($w) });
    }
}

sub Destroy {
    my $w = shift;
    if ($w->{Photo}) {
	$w->{Photo}->delete;
	undef $w->{Photo};
    }
    if ($w->{"Exists"}) {
	Tk::catch(sub { Tk::destroy($w) });
    }
}

# Taken from Tk.pm (Tk804.025_beta6)
sub getEncoding
{
 my ($class,$name) = @_;

 eval { require Encode };
 if ($@)
  {
   require Tk::DummyEncode;
   return Tk::DummyEncode->getEncoding($name);
  }

 $Tk::encodeStopOnError = Encode::FB_QUIET();
 $Tk::encodeFallback    = Encode::FB_PERLQQ(); # Encode::FB_DEFAULT();

 $name = $Tk::font_encoding{$name} if exists $Tk::font_encoding{$name};
 my $enc = Encode::find_encoding($name);

 unless ($enc)
  {
   $enc = Encode::find_encoding($name) if ($name =~ s/[-_]\d+$//)
  }
# if ($enc)
#  {
#   print STDERR "Lookup '$name' => ".$enc->name."\n";
#  }
# else
#  {
#   print STDERR "Failed '$name'\n";
#  }
 unless ($enc)
  {
   if ($name eq 'X11ControlChars')
    {
     require Tk::DummyEncode;
     $Encode::encoding{$name} = $enc = Tk::DummyEncode->getEncoding($name);
    }
  }
 return $enc;
}




1;

=head1 NAME

Tk::FastSplash - create a fast starting splash screen

=head1 SYNOPSIS

    BEGIN {
        require Tk::FastSplash;
        $splash = Tk::FastSplash->Show($image, $width, $height, $title,
                                   $overrideredirect);
    }
    ...
    use Tk;
    ...
    $splash->Destroy if $splash;
    MainLoop;

=head1 DESCRIPTION

This module creates a fast loading splash screen for Perl/Tk programs.
It uses lowlevel Perl/Tk stuff, so upward compatibility is not given
(the module should work at least for Tk800.015, .022, .024, .025 and
Tk804.025).

The splash screen is created with the B<Show> function. Supplied
arguments are: filename of the displayed image, width and height of
the image and the string for the title bar. C<$width> and C<$height>
may be left undefined. If C<$overrideredirect> is set to a true value,
then the splash screen will come without window manager decoration. If
something goes wrong, then B<Show> will silently ignore all errors and
continue without a splash screen. The splash screen can be destroyed
with the B<Destroy> method, best short before calling B<MainLoop>.

If you want to run this module on a Tk402.xxx system, then you have to
set the variable C<$Tk::FastSplash::TK_VERSION> to a value less than
800.

=head1 CAVEAT

This module does forbidden things e.g. bootstrapping the Tk shared
object or poking in the Perl/Tk internals. Because of this, this
module can stop working in a new Perl/Tk release. If you are concerned
about compatibility, then you should use L<Tk::Splash> instead. If
your primary concern is speed, then C<Tk::FastSplash> is for you (and
the primary reason I wrote this module). The splash window of
C<Tk::FastSplash> should pop up 1 or 2 seconds faster than using
L<Tk::Splash> or a vanilla L<Tk::Toplevel> window.

=head1 BUGS

Probably many.

You cannot call C<Tk::FastSplash> twice in one application.

The $^W variable should be turned off until the "use Tk" call.

If FastSplash is executed in a BEGIN block (which is recommended for
full speed), then strange things will happen when using C<perl -c> or
trying to compile a script: the splash screen will always pop up while
doing those things. Therefore it is recommended to disable the splash
screen in check or debug mode:

    BEGIN {
        if (!$^C && !$^P) {
            require Tk::FastSplash;
            $splash = Tk::FastSplash->Show($image, $width, $height, $title,
                                           $overrideredirect);
        }
    }

The -display switch is not honoured (but setting the environment
variable DISPLAY will work).

XXX Avoid Win32 raise/lower problem with this code (maybe)?

    # Windows constants
    my ($ONTOP, $NOTOP, $TOP) = (-1, -2, 0);
    my ($SWP_NOMOVE, $SWP_NOSIZE) = (2, 1);
    
    my $SetWindowPos        = new Win32::API("user32", "SetWindowPos", 'NNNNNNN', 'N'); 
    my $FindWindow          = new Win32::API("user32", "FindWindow", 'PP', 'N'); 
    
    # Reestablish Z order
    my $class = "TkTopLevel";
    my $topHwnd = $FindWindow->Call($class, $w->title);
    $topHwnd and $SetWindowPos->Call($topHwnd, $ONTOP, 0, 0, 0, 0, $SWP_NOMOVE | $SWP_NOSIZE);


=head1 AUTHOR

Slaven Rezic (slaven@rezic.de)

=head1 SEE ALSO

L<Tk::Splash>, L<Tk::ProgressSplash>, L<Tk::Splashscreen>,
L<Tk::mySplashScreen>.

=cut

__END__
