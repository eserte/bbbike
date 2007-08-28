# -*- perl -*-

#
# $Id: Dialog.pm,v 1.9 2004/09/04 01:11:59 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Tk::PathEntry::Dialog;
use Tk::PathEntry;
use base qw(Tk::DialogBox);
use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

Construct Tk::Widget 'PathEntryDialog';

sub import {
    if (defined $_[1] and $_[1] eq 'as_default') {
	local $^W = 0;
	package Tk;
	if ($Tk::VERSION < 804) {
	    *FDialog      = \&Tk::PathEntry::Dialog::FDialog;
	    *MotifFDialog = \&Tk::PathEntry::Dialog::FDialog;
	} else {
            *tk_getOpenFile = sub {
                Tk::PathEntry::Dialog::FDialog("tk_getOpenFile", @_);
            };
            *tk_getSaveFile = sub {
                Tk::PathEntry::Dialog::FDialog("tk_getSaveFile", @_);
            };
	}
    }
}

sub Populate {
    my($w, $args) = @_;

    $args->{-buttons} = ["OK", "Cancel"];

    my %pe_args;
    foreach (qw(dir file)) {
	if (exists $args->{"-initial$_"}) {
	    $pe_args{"-initial$_"} = delete $args->{"-initial$_"};
	}
    }

    $w->SUPER::Populate($args);

    my $pe = $w->add('PathEntry',
		     -textvariable => \$w->{PathName},
		     %pe_args)->pack;
    $w->Advertise("PathEntry" => $pe);

    $pe->bind("<Return>" => sub {
		  $w->Subwidget("B_OK")->Invoke;
	      });
    $w->bind("<Escape>" => sub {
		 $w->Subwidget("B_Cancel")->Invoke;
	     });

    $w->ConfigSpecs
	(-create => ['PASSIVE', undef, undef, 0]);
}

sub Show {
    my $w = shift;
    my @args = @_;

    my $pathname;
    my $pe = $w->Subwidget("PathEntry");

    while (1) {
	undef $pathname;

	$w->after(300, sub {
		      $pe->focus;
		      $pe->icursor("end");
		  });

	my $r = $w->SUPER::Show(@args);
	$pathname = $w->{PathName} if $r =~ /ok/i;
	$pe->Finish;

	if (defined $pathname && $w->cget(-create) && -e $pathname) {

	    my $reply = $w->messageBox
		(-icon => 'warning',
		 -type => 'YesNo',
		 -message => "File \"$pathname\" already exists.\nDo you want to overwrite it?");
	    redo unless (lc($reply) eq 'yes');
	}
	last;
    }

    $pathname;
}

sub FDialog
{
 my($cmd, %args) = @_;

 $args{-create} = !!($cmd =~ /Save/);

 delete $args{-filetypes};
 delete $args{-defaultextension};
 delete $args{-force};

 Tk::DialogWrapper('PathEntryDialog',$cmd, %args);
}

1;

__END__

=head1 NAME

Tk::PathEntry::Dialog - File dialog using Tk::PathEntry

=head1 SYNOPSIS

Using as a replacement for getOpenFile and getSaveFile:

    use Tk::PathEntry::Dialog qw(as_default);
    $mw->getOpenFile;

Using as a normal module:

    use Tk::PathEntry::Dialog;
    $filename = $mw->PathEntryDialog->Show;

=head1 DESCRIPTION

With this module, the L<Tk::PathEntry|Tk::PathEntry> can also be used
as a standard Tk file dialog.

=head1 BUGS

This widget does not work on Windows.

=head1 SEE ALSO

L<Tk::PathEntry (3)|Tk::PathEntry>, L<Tk::getOpenFile (3)|Tk::getOpenFile>.

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2001 Slaven Rezic. All rights
reserved. This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
