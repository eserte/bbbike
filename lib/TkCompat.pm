# -*- perl -*-

#
# $Id: TkCompat.pm,v 1.11 2002/01/26 22:58:27 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# buggy fileevent: writable vs. writeable
package Tk;
use Carp;

sub eventAdd { }

sub messageBox {
    my($parent, %args) = @_;
    require Tk::Dialog;
    while(my($k) = each %args) {
	delete $args{$k} unless $k =~ /^-(title|text)$/;
    }
    my $d = $parent->Dialog(%args);
    $d->Show;
}

sub fileevent
{
 require Tk::IO;
 my ($obj,$file,$mode,$cb) = @_;
 croak "Unknown mode '$mode'" unless $mode =~ /^(readable|writable)$/;
 unless (ref $file)
  {
   require IO::Handle;
   no strict 'refs';
   $file = Symbol::qualify($file,(caller)[0]);
   $file = bless \*{$file},'IO::Handle';
  }
 if ($cb)
  {
   # Adding the handler
   $cb = Tk::Callback->new($cb);
   if ($mode eq 'readable')
    {
     Tk::IO::CreateReadHandler($file,$cb);
    }
   else
    {
     Tk::IO::CreateWriteHandler($file,$cb);
    }
  }
 else
  {
   if ($mode eq 'readable')
    {
     Tk::IO::DeleteReadHandler($file);
    }
   else
    {
     Tk::IO::DeleteWriteHandler($file);
    }
  }
}

sub tabFocus
{
 shift->Tk::focus;
}

#package Tk::Balloon;

# XXX geht leider nicht, weil @balloons file-lokal ist.
# sub Motion

sub getOpenFile {
    my($w,%args) = @_;
    $w->_getFile(%args, -Create => 0);
}

sub getSaveFile {
    my($w,%args) = @_;
    $w->_getFile(%args, -Create => 1);
}

# XXX not tested yet...
sub _getFile {
    my($w,%args) = @_;
    $args{-FPat}  = delete $args{-defaultextension};
    $args{-Path}  = delete $args{-initialdir};
    $args{-File}  = delete $args{-initialfile};
    $args{-Title} = delete $args{-title};
    my($file) = main::get_filename($w, %args);
    $file;
}

package main;

sub set_fonts_402 {
    my(@basefontwidth);

    if ($top->width <= 640) {
	@basefontwidth = (70, 80, 90, 100, 120, 140, 180, 240);
    } elsif ($top->width <= 800) {
	@basefontwidth = (80, 90, 100, 120, 140, 180, 240, 280);
    } else {
	@basefontwidth = (80, 100, 120, 140, 180, 240, 280, 360);
    }

    # Tk4: Zeichensätze können nicht skaliert werden
    if ($os eq 'unix') {
	for(my $i = 0; $i <= $#basefontwidth; $i++) {
	    if ($basefontwidth[$i] == 70) {
		$basefontwidth[$i] = 80;
	    } elsif ($basefontwidth[$i] == 90) {
		$basefontwidth[$i] = 100;
	    } elsif ($basefontwidth[$i] == 280 ||
		     $basefontwidth[$i] == 320) {
		$basefontwidth[$i] = 240;
	    }
	}
    }

    $font{'normal'}
    = "-*-$font_family-medium-r-normal--*-$basefontwidth[3]-75-75-*-iso8859-1";
    my $tmp_label;
    eval {
	$tmp_label = $top->Label(-font => $font{'normal'});
    };
    if ($@) {
	warn $@;
	$font_family = "helvetica";
	$font{'normal'}
	= "-*-$font_family-medium-r-normal--*-$basefontwidth[3]-75-75-*-iso8859-1";
    }

    $font{'veryhuge'}
    = "-*-$font_family-medium-r-normal--*-$basefontwidth[7]-75-75-*-iso8859-1";
    $font{'huge'}
    = "-*-$font_family-medium-r-normal--*-$basefontwidth[6]-75-75-*-iso8859-1";
    $font{'verylarge'}
    = "-*-$font_family-medium-r-normal--*-$basefontwidth[5]-75-75-*-iso8859-1";
    $font{'large'}
    = "-*-$font_family-medium-r-normal--*-$basefontwidth[4]-75-75-*-iso8859-1";
    $font{'bold'}
    = "-*-$font_family-bold-r-normal--*-$basefontwidth[3]-75-75-*-iso8859-1";
    $font{'fix15'}
    = "lucidasanstypewriter-14";
    $font{'reduced'}
    = "-*-$font_family-medium-r-normal--*-$basefontwidth[2]-75-75-*-iso8859-1";
    $font{'small'}
    = "-*-$font_family-medium-r-normal--*-$basefontwidth[1]-75-75-*-iso8859-1";
    $font{'tiny'}
    = "-*-$font_family-medium-r-normal--*-$basefontwidth[0]-75-75-*-iso8859-1";
    $font{'standard'}
    = "-*-$font_family-medium-r-normal--*-" . ($standard_height*10) . "-75-75-*-iso8859-1";
    $font{'fixed'}
    = "-*-$fixed_font_family-medium-r-normal--*-$basefontwidth[3]-75-75-*-iso8859-1";
    $top->optionAdd("*font" => $font{'normal'}, 'userDefault');
}

if ($Tk::VERSION <= 402.002) {
    require Tk::HList;
    package Tk::HList; # fehlende HList-Methode
    Tk::HList->EnterMethods(__FILE__, qw(header));
}

package main;


# XXX getOpen/SaveFile zum Standard machen und in TkCompat
# Kompatibilitätsroutine schreiben
### AutoLoad Sub
sub get_filename {
    my($top, %args) = @_;
    my %change_opt;
    my $defaultextension;
    if ($args{'-FPat'}) {
	if ($Tk::VERSION <= 800.011) {
	    ($defaultextension = $args{'-FPat'}) =~ s/^\*\.//;
	} else {
	    ($defaultextension = $args{'-FPat'}) =~ s/^\*//;
	}
    }
    if ($args{-Create} && $top->can('getSaveFile') &&
	!($os eq 'win' && $Config{'cc'} eq 'gcc' && $Tk::VERSION < 800.014)) { # XXX Probleme mit Mingw
	my $file = $top->getSaveFile
	  (-initialdir => $args{-Path},
	   -initialfile => $args{'-File'},
	   -defaultextension => $defaultextension,
	   -title => $args{-Title});
	my $path = dirname $file;
	return ($file, $path);
    } elsif (!$args{-Create} && $top->can('getOpenFile') &&
             !($os eq 'win' && $Config{'cc'} eq 'gcc' && $Tk::VERSION < 800.014)) { # XXX Probleme mit Mingw
	my $file = $top->getOpenFile
	  (-initialdir => $args{-Path},
	   -defaultextension => $defaultextension,
	   -title => $args{-Title},
	   ($Tk::VERSION >= 800.012 ?
	    (-filetypes => [['Route-Dateien', '.' . $bbbike_route_ext],
			    ['Alle Dateien',  '*']])
	    : ()
	   ),
	  );
	my $path = dirname $file;
	return ($file, $path);
    }

    my $filedialog = 'FileDialog';
    if ($os eq 'win') {
	$@ = "XXX Tk::FileDialog does not work with win32";
    } else {
	eval { require Tk::FileDialog };
    }
    if ($@) {
	warn "Harmless warning:\n$@\n";
	require Tk::FileSelect;
	$filedialog = 'FileSelect';
	%change_opt = (-FPat   => '-filter',
		       -Path   => '-directory',
		       -File   => undef,
		       -Create => undef,
		       -Title  => undef,
		      );
    }
    foreach (keys %args) {
	if (exists $change_opt{$_}) {
	    if (defined $change_opt{$_}) {
		$args{$change_opt{$_}} = delete $args{$_};
	    } else {
		delete $args{$_};
	    }
	}
    }
    my $fd = $top->$filedialog(%args);
    my $file = $fd->Show(@popup_style);
    my $path;
    if ($filedialog eq 'FileDialog') {
	$path = $fd->cget(-Path);
    } else {
	$path = dirname $file;
    }
    ($file, $path);
}

1;
