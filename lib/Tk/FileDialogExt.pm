# -*- perl -*-

#
# $Id: FileDialogExt.pm,v 1.1 1999/03/28 22:01:47 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use Tk;
use Tk::FileDialog;

sub _FDialog {
    my($cmd, %args) = @_;
    $args{-Create} = ($cmd =~ /Save/ ? 1 : 0);
    if (exists $args{-defaultextension}) {
	if (defined $args{-defaultextension}) {
	    $args{-FPat} = "*." . $args{-defaultextension};
	}
	delete $args{-defaultextension};
    }
    $args{-Path} = delete $args{-initialdir}
    if exists $args{-initialdir};
    $args{-File} = delete $args{-initialfile}
    if exists $args{-initialfile};
    $args{-Title} = delete $args{-title}
    if exists $args{-title};
    if (exists $args{-filetypes}) {
	warn "-filetypes not supported by Tk::FileDialog";
	delete $args{-filetypes};
    }
    Tk::DialogWrapper('FileDialog', $cmd, %args);
}

{
    local($^W) = 0;

    *Tk::FDialog      = \&_FDialog;
    *Tk::MotifFDialog = \&_FDialog;

}

1;
