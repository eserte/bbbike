# -*- perl -*-

#
# $Id: WinCompat.pm,v 1.4 1999/02/20 16:39:21 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package main;

#XXX del:
# eval {
#     $win32s = (!Win32::IsWinNT() and !Win32::IsWin95());
# };
# if ($win32s) {
#     # STDERR landet ansonsten im Nirvana
#     if (defined $ENV{TEMP} and -d $ENV{TEMP}) {
# 	open(W, ">$ENV{TEMP}/error.txt"); # truncate
# 	close W;
# 	my $warn_sub = sub {
# 	    open(W, ">>$ENV{TEMP}/error.txt");
# 	    print W join("\n", @_);
# 	    close W;
# 	};
# 	$SIG{__WARN__} = $SIG{__DIE__} = $warn_sub;
#     }
#     $do_www    = 0; # Internet-Zugriffe unterdrücken
#     $want_wind = 0;
#     $sfn       = 1;
# }      

if ($Tk::VERSION < 800) {
    eval q{
        package Tk::Balloon;

        sub SetStatus {
            my $w = shift;
            my $client = $w->{"client"};
            return if ((not defined $client) ||
        	       (not exists $w->{"clients"}->{$client}));
            my $msg = $w->{"clients"}->{$client}->{-statusmsg} || '';
            main::status_message($msg);
        }

        sub ClearStatus {
            main::status_message("");
        }
    };
}

package Tk::ContextHelp;
@ISA = qw(Tk::Toplevel);
Construct Tk::Widget 'ContextHelp';

sub Populate {
    my($w, $args) = @_;
    my(@keys) = keys %$args;
    foreach (@keys) {
	delete $args->{$_};
    }
    $w->withdraw;
}

sub attach { }

sub HelpButton {
    my($self, $top, %args) = @_;
    my $b = $top->Button(-text => '?',
			 -padx => 0,
			 -pady => 0,
			 -state => 'disabled');
    $b;
}

1;
