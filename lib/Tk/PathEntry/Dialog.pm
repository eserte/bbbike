# -*- perl -*-

#
# $Id: Dialog.pm,v 1.11 2007/09/19 18:58:17 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

Construct Tk::Widget 'PathEntryDialog';

sub import {
    if (defined $_[1] and $_[1] eq 'as_default') {
	local $^W = 0;
	package # hide from PAUSE indexer
	    Tk;
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
    # Disable default button feature of Tk::DialogBox
    $args->{-default_button} = 'none';
    $args->{-title}  ||=  'Select path';   # default window title
    $w->SUPER::Populate($args);

    my $pe = $w->add('PathEntry',
		     -textvariable => \$w->{PathName},
		    )->pack(-expand => 1, -fill => 'x');
    $w->Advertise("PathEntry" => $pe);
    $args->{-focus} = $pe;

    $pe->bind("<Return>" => sub {
		  $w->Subwidget("B_OK")->Invoke;
	      });
    $w->bind("<Escape>" => sub {
		 $w->Subwidget("B_Cancel")->Invoke;
	     });

    $w->ConfigSpecs
	(-create => ['PASSIVE', undef, undef, 0],
	 'DEFAULT' => [$pe],
	);
}

sub Show {
    my $w = shift;
    my @args = @_;

    my $pathname;
    my $pe = $w->Subwidget("PathEntry");

    while (1) {
	undef $pathname;

	my $r = $w->SUPER::Show(@args);
	$pathname = $w->{PathName} if $r =~ /ok/i;
	$pe->Finish;

	if (defined $pathname && $w->cget(-create) && -f $pathname) {

	    # Disable default button feature of Tk::DialogBox
	    # (invalid option and not required for Windows)
	    my $noDefault = $Tk::platform eq 'MSWin32' ? '' :
                               "-default_button => 'none'";
	    my $reply = $w->messageBox
		(-icon => 'warning',
		 -type => 'YesNo',
		 eval {split(' => ', $noDefault)},
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
    $filename = $mw->getOpenFile;

Using as a normal module:

    use Tk::PathEntry::Dialog;
    $filename = $mw->PathEntryDialog(-autocomplete => 1)->Show;

=head1 DESCRIPTION

This module provides a dialog window with a L<Tk::PathEntry|Tk::PathEntry>
widget, an OK button and a Cancel button.

With this module, the L<Tk::PathEntry|Tk::PathEntry> can also be used
as a standard Tk file dialog. You are allowed to select a directory.

=head1 OPTIONS

=head2 Options of getOpenFile and getSaveFile

You cannot use the options C<-filetypes>, C<-defaultextension>, and C<-multiple>. So the only
remaining options are C<-initialdir>, C<-initialfile>, and C<-title>.

=head2 Options of PathEntryDialog

B<PathEntryDialog> supports all options of L<Tk::PathEntry|Tk::PathEntry>. The additional options are:

=over 4

=item -title

Sets the window title.

=item -create

If this is set to a C<true> value, you will be warned when you select an existing file.

=back

=head1 NOTES

Surprisingly this module also works on Microsoft Windows.

=head1 BUGS

The following bug is known for B<PathEntryDialog> on Microsoft Windows:
Directly after klicking on a choice in the choices listbox which displays
below the C<PathEntryDialog> window, the C<OK> and
C<Cancel> buttons don't respond to mouse clicks. Workaround: Move the mouse
cursor out of the button and back. Or use the Enter resp. Escape keys in
place of the buttons.

The following bug is known for B<PathEntryDialog> on Knoppix:
C<PathEntryDialog> will often abort immediately with the error message

	*** glibc detected *** malloc(): memory corruption: 0x08495514 ***

Workaround: Do something that causes B<PathEntryDialog> to start at a different 
memory location, e. g. open or close a Konqueror window (beleave me, this may help).

=head1 SEE ALSO

L<Tk::PathEntry (3)|Tk::PathEntry>, L<Tk::getOpenFile (3)|Tk::getOpenFile>.

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2001 Slaven Rezic. All rights
reserved. This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
