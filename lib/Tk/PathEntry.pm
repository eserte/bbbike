# -*- perl -*-

#
# $Id: PathEntry.pm,v 2.22 2004/05/16 21:53:57 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2002,2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.sourceforge.net/srezic
#

package Tk::PathEntry;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 2.22 $ =~ /(\d+)\.(\d+)/);

use base qw(Tk::Derived Tk::Entry);

Construct Tk::Widget 'PathEntry';

sub ClassInit {
    my($class,$mw) = @_;
    $class->SUPER::ClassInit($mw);

    $mw->bind($class,"<Tab>" => sub {
		  my $w = shift;
		  if (!defined $w->{CurrentChoices}) {
		      # this is called only on init:
		      my $pathref = $w->cget(-textvariable);
		      $w->_popup_on_key($$pathref);
		  }
		  if (@{$w->{CurrentChoices}} > 0) {
		      my $sep = $w->cget(-separator);
		      my $common = $w->_common_match;
		      if ($w->Callback(-isdircmd => $w, $common) &&
			  $common !~ m|\Q$sep\E$|                &&
			  @{$w->{CurrentChoices}} == 1
			 ) {
			  $common .= $sep;
		      }
		      my $pathref = $w->cget(-textvariable);
		      $$pathref = $common;
		      $w->icursor("end");
		      $w->xview("end");

		      $w->_popup_on_key($$pathref);
		  } else {
		      $w->bell;
		  }
		  Tk->break;
	      });

    $mw->bind($class,"<Prior>" => sub {
		  my $w = shift;
		  $w->_incr_choices('-1');
		  $w->_show_choices;
	      });
    $mw->bind($class,"<Next>" => sub {
		  my $w = shift;
		  $w->_incr_choices('+1');
		  $w->_show_choices;
	      });

#XXX not yet! => problems, because <Return> should be bound to set
# the entry value ... but <Return> is normally bound from outside this
# module...XXX
#      $mw->bind($class,"<Down>" => sub {
#  		  my $w = shift;
#  		  my $choices_t = $w->Subwidget("ChoicesToplevel");
#  		  if ($choices_t && $choices_t->state ne 'withdrawn') {
#  		      my $choices_l = $w->Subwidget("ChoicesLabel");
#  		      my @sel = $choices_l->curselection;
#  		      $choices_l->selectionClear(0,"end");
#  		      if (!@sel) {
#  			  $choices_l->selectionSet(0);
#  		      } else {
#  			  $choices_l->selectionSet($sel[0]+1);
#  		      }
#  		  }
#  	      });
#      $mw->bind($class,"<Up>" => sub {
#  		  my $w = shift;
#  		  my $choices_t = $w->Subwidget("ChoicesToplevel");
#  		  if ($choices_t && $choices_t->state ne 'withdrawn') {
#  		      my $choices_l = $w->Subwidget("ChoicesLabel");
#  		      my @sel = $choices_l->curselection;
#  		      $choices_l->selectionClear(0,"end");
#  		      if (@sel && $sel[0] > 0) {
#  			  $choices_l->selectionSet($sel[0]-1);
#  		      }
#  		  }
#  	      });

    for ("Meta", "Alt") {
	$mw->bind($class,"<$_-BackSpace>" => '_delete_last_path_component');
	$mw->bind($class,"<$_-d>"         => '_delete_next_path_component');
	$mw->bind($class,"<$_-f>"         => '_forward_path_component');
	$mw->bind($class,"<$_-b>"         => '_backward_path_component');
    }
    $mw->bind($class,"<FocusOut>" => sub {
		  my $w = shift;
		  $w->Finish;
	      });

    $class;
}

sub Populate {
    my($w, $args) = @_;

    my $choices_t = $w->Component("Toplevel" => "ChoicesToplevel");
    $choices_t->overrideredirect(1);
    $choices_t->withdraw;

    my $choices_l = $choices_t->Listbox(-background => "yellow",
					-border => 0,
				       )->pack(-fill => "both",
					       -expand => 1);
    $w->Advertise("ChoicesLabel" => $choices_l);
    $choices_l->bind("<1>" => sub {
			 my $lb = shift;
			 my $y = $lb->nearest($lb->XEvent->y);
			 $ {$w->cget(-textvariable)} = $lb->get($y);
			 $w->icursor("end");
			 $w->xview("end");
			 $choices_t->withdraw;
			 $w->Callback(-selectcmd => $w);
		     });
    $w->bind("<Return>" => sub {
		 $w->Finish;
		 $w->Callback(-selectcmd => $w);
	     });
    $w->bind("<Escape>" => sub {
		 $w->Finish;
		 $w->Callback(-cancelcmd => $w);
	     });

    if (exists $args->{-vcmd} ||
	exists $args->{-validatecommand} ||
	exists $args->{-validate}) {
	die "-vcmd, -validatecommand or -validate are not allowed with PathEntry";
    }

    $args->{-vcmd} = sub {
	my($pathname) = $_[0];
	my($action)   = $_[4];
	return 1 if $action == -1; # nothing on forced validation

	undef $w->{ChoicesTop};
	$w->_popup_on_key($pathname);

	if ($action == 1 && # only on INSERT
	    $w->{CurrentChoices} && @{$w->{CurrentChoices}} == 1 &&
	    $w->cget(-autocomplete)) {
	    # XXX the afterIdle is hackish
	    $w->afterIdle(sub { $ {$w->cget(-textvariable)} = $w->{CurrentChoices}[0] });
	    return 0;
	}

	1;
    };
    $args->{-validate} = 'key';

    if (!exists $args->{-textvariable}) {
	my $pathname;
	$args->{-textvariable} = \$pathname;
    }

    $w->ConfigSpecs
	(-initialdir  => ['PASSIVE',  undef, undef, undef],
	 -initialfile => ['PASSIVE',  undef, undef, undef],
	 # XXX auf den OS-separator setzen??? unter win32 ausprobieren!
	 -separator   => ['PASSIVE',  undef, undef, "/"],
	 -isdircmd    => ['CALLBACK', undef, undef, ['_is_dir']],
	 -isdirectorycommand => 'isdircmd',
	 -choicescmd  => ['CALLBACK', undef, undef, ['_get_choices']],
	 -choicescommand     => 'choicescmd',
	 -autocomplete => ['PASSIVE'],
	 -selectcmd   => ['CALLBACK'],
	 -selectcommand => 'selectcmd',
	 -cancelcmd   => ['CALLBACK'],
	 -cancelcommand => 'cancelcmd',
	);
}

sub ConfigChanged {
    my($w,$args) = @_;
    for (qw/dir file/) {
	if (defined $args->{'-initial' . $_}) {
	    $ {$w->cget(-textvariable)} = $args->{'-initial' . $_};
	}
    }
}

sub Finish {
    my $w = shift;
    my $choices_t = $w->Subwidget("ChoicesToplevel");
    $choices_t->withdraw;
    $choices_t->idletasks;
    delete $w->{CurrentChoices};
}

sub _popup_on_key {
    my($w, $pathname) = @_;
    if ($w->ismapped) {
	$w->{CurrentChoices} = $w->Callback(-choicescmd => $w, $pathname);
	if ($w->{CurrentChoices} && @{$w->{CurrentChoices}} > 1) {
	    $w->_incr_choices("TAB") if defined $w->{ChoicesTop};
	    $w->_show_choices($w->rootx);
	} else {
	    my $choices_t = $w->Subwidget("ChoicesToplevel");
	    $choices_t->withdraw;
	}
    }
}

sub _delete_last_path_component {
    my $w = shift;

    my $before_cursor = substr($w->get, 0, $w->index("insert"));
    my $after_cursor = substr($w->get, $w->index("insert"));
    my $sep = $w->cget(-separator);
    $before_cursor =~ s|[^$sep]+\Q$sep\E?$||;
    my $pathref = $w->cget(-textvariable);
    $$pathref = $before_cursor . $after_cursor;
    $w->icursor(length $before_cursor);
    undef $w->{ChoicesTop};
    $w->_popup_on_key($$pathref);
}

sub _delete_next_path_component {
    my $w = shift;

    my $before_cursor = substr($w->get, 0, $w->index("insert"));
    my $after_cursor = substr($w->get, $w->index("insert"));
    my $sep = $w->cget(-separator);
    $after_cursor =~ s|^\Q$sep\E?[^$sep]+||;
    my $pathref = $w->cget(-textvariable);
    $$pathref = $before_cursor . $after_cursor;
    $w->icursor(length $before_cursor);
    undef $w->{ChoicesTop};
    $w->_popup_on_key($$pathref);
}

sub _forward_path_component {
    my $w = shift;
    my $after_cursor = substr($w->get, $w->index("insert"));
    my $sep = $w->cget(-separator);
    if ($after_cursor =~ m|^(\Q$sep\E?[^$sep]+)|) {
	$w->icursor($w->index("insert") + length $1);
    }
}

sub _backward_path_component {
    my $w = shift;
    my $before_cursor = substr($w->get, 0, $w->index("insert"));
    my $sep = $w->cget(-separator);
    if ($before_cursor =~ m|([^$sep]+\Q$sep\E?)$|) {
	$w->icursor($w->index("insert") - length $1);
    }
}

sub _common_match {
    my $w = shift;
    my(@choices) = @{$w->{CurrentChoices}};
    my $common = shift @choices;
    foreach (@choices) {
	if (length $_ < length $common) {
	    $common = substr($common, 0, length $_);
	}
	for my $i (0 .. length($common) - 1) {
	    if (substr($_, $i, 1) ne substr($common, $i, 1)) {
		return "" if $i == 0;
		$common = substr($_, 0, $i);
		last;
	    }
	}
    }
    $common;
}

sub _get_choices {
    my($w, $pathname) = @_;
    my $sep = $w->cget(-separator);
    if ($pathname =~ m|^~([^$sep]+)$|) {
	my $userglob = $1;
	my @users;
	while(my $user = getpwent) {
	    if ($user =~ /^$userglob/) {
		push @users, "~$user$sep";
		last if $#users > 50; # XXX make better optimization!
	    }
	}
	endpwent;
	if (@users) {
	    \@users;
	} else {
	    [$pathname];
	}
    } else {
	my $glob;
	$glob = "$pathname*";
	[ glob($glob) ];
    }
}

sub _show_choices {
    my($w, $x_pos) = @_;
    my $choices = $w->{CurrentChoices};
    my $choices_l = $w->Subwidget("ChoicesLabel");
    my $choices_t = $w->Subwidget("ChoicesToplevel");
    #$choices_l->configure(-text => join("\n", @$choices));
    $choices_l->delete(0,"end");
    if (!defined $w->{ChoicesTop}) {
	$w->{ChoicesTop} = 0;
    }
    my $max_height = @$choices - $w->{ChoicesTop};
    my $choices_height = $choices_l->cget(-height);
    if ($max_height > $choices_height) {
	$max_height = $choices_height;
    }
    $choices_l->insert("end", @{$choices}[$w->{ChoicesTop} .. $w->{ChoicesTop}+$max_height-1]);
    my $max_width;
    foreach (@{$choices}[$w->{ChoicesTop} .. $w->{ChoicesTop}+$max_height-1]) {
	if (!defined $max_width || length($_) > $max_width) {
	    $max_width = length($_);
	}
    }
    $choices_l->configure(-width => $max_width);
    if (defined $x_pos) {
	$choices_t->geometry("+" . $x_pos . "+" . ($w->rooty+$w->height));
	$choices_t->deiconify;
	$choices_t->raise;
    }
}

sub _incr_choices {
    my($w, $direction) = @_;
    my $choices_t = $w->Subwidget("ChoicesToplevel");
    if ($choices_t->state eq 'normal' &&
	defined $w->{ChoicesTop} &&
	$w->{CurrentChoices}) {
	my $choices_l = $w->Subwidget("ChoicesLabel");
	my $choices_height = $choices_l->cget(-height);
	if ($direction eq '-1') {
	    $w->{ChoicesTop} -= $choices_height;
	    if ($w->{ChoicesTop} < 0) {
		$w->{ChoicesTop} = 0;
	    }
	} else {
	    $w->{ChoicesTop} += $choices_height;
	    if ($w->{ChoicesTop} >= @{$w->{CurrentChoices}}) {
		if ($direction eq 'TAB') {
		    $w->{ChoicesTop} = 0;
		} else {
		    $w->{ChoicesTop} -= $choices_height;
		    return;
		}
	    }
	}
    }
}

sub _is_dir { -d $_[1] }

1;

__END__

=head1 NAME

Tk::PathEntry - Entry widget for selecting paths with completion

=head1 SYNOPSIS

    use Tk::PathEntry;
    my $pe = $mw->PathEntry
                     (-textvariable => \$path,
		      -selectcmd => sub { warn "The pathname is $path\n" },
		     )->pack;

=head1 DESCRIPTION

This is an alternative to classic file selection dialogs. It works
more like the file completion in modern shells like C<tcsh> or
C<bash>.

With the C<Tab> key, you can force the completion of the current path.
If there are more choices, a window is popping up with these choices.
With the C<Meta-Backspace> or C<Alt-Backspace> key, the last path
component will be deleted.

=head1 OPTIONS

B<Tk::PathEntry> supports all standard L<Tk::Entry|Tk::Entry> options
except C<-vcmd> and C<-validate> (these are used internally in
B<PathEntry>). The additional options are:

=over 4

=item -initialdir

Set the initial path to the value. Alias: C<-initialfile>. You can
also use a pre-filled C<-textvariable> to set the initial path.

=item -separator

The character used as the path component separator. For Unix, this is "/".

=item -isdircmd

Can be used to set another directory recognizing subroutine. The
directory name is passed as second parameter. Alias:
C<-isdirectorycommand>. The default is a subroutine using C<-d>.

=item -choicescmd

Can be used to set another globbing subroutine. The current pathname
is passed as second parameter. Alias: C<-choicescommand>. The
default is a subroutine using the standard C<glob> function.

=item -selectcmd

This will be called if a path is selected, either by hitting the
Return key or by clicking on the choice listbox. Alias:
C<-selectcommand>.

=item -cancelcmd

This will be called if the Escape key is pressed. Alias:
C<-cancelcommand>.

=back

=head1 METHODS

=over 4

=item Finish

This will popdown the window with the completion choices. It is called
automatically if the user selects an entry from the listbox, hits the
Return or Escape key or the widget loses the focus.

=back

=head1 EXAMPLES

If you want to not require from your users to install Tk::PathEntry,
you can use the following code snippet to create either a PathEntry or
an Entry, depending on what is installed:


    my $e;
    if (!eval '
        use Tk::PathEntry;
        $e = $mw->PathEntry(-textvariable => \$file,
                            -selectcmd => sub { $e->Finish },
                           );
        1;
    ') {
        $e = $mw->Entry(-textvariable => \$file);
    }
    $e->pack;

=head1 NOTES

Since C<Tk::PathEntry> version 2.17, it is not recommended to bind the
Return key directly. Use the C<-selectcmd> option instead.

=head1 TODO

=over

=item * Check color settings on Windows

=item * Add ctrl-tab or another key as tab replacement

=back

=head1 SEE ALSO

L<Tk::PathEntry::Dialog (3)|Tk::PathEntry::Dialog>,
L<Tk::Entry (3)|Tk::Entry>, L<tcsh (1)|tcsh>, L<bash (1)|bash>.

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2001,2002 Slaven Rezic. All rights
reserved. This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

