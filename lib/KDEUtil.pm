# -*- perl -*-

#
# $Id: KDEUtil.pm,v 2.11 2003/06/02 23:24:00 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

=head1 NAME

KDEUtil - provide standard KDE functions for perl

=cut

package KDEUtil;
use strict;

=head1 CONSTRUCTOR

=head2 KDEUtil->new(...)

Create a new object. Possible options are:

=over 4

=item -checkrunning

If set to true, then undef will be returned instead of a KDEUtil
object if KDE is not running.

=item -tk

=item -top

A reference to a Tk MainWindow. The C<-tk> option is an alias for C<-top>.

=back

=cut

sub new {
    my($class, %args) = @_;
    my $self = \%args;
    bless $self, $_[0];
    if (exists $args{-tk}) {
	$args{-top} = delete $args{-tk};
    }
    if ($args{-checkrunning} && !$self->is_running) {
	undef;
    } else {
	$self;
    }
}

=head1 METHODS

=head2 is_running

Check if KDE is running (ie. kwm is running).

=cut

sub is_running {
    my $self = shift;
    if ($self->get_property("KWM_RUNNING")) { # KDE 1
	$self->{KDE_VERSION} = 1;
	1;
    } elsif ($self->get_property("KWIN_RUNNING")) { # KDE 2
	$self->{KDE_VERSION} = 2;
	1;
    } else {
	0;
    }
}

=head2 current_desktop

Return active KDE desktop.

=cut

sub current_desktop {
    my $self = shift;
    if ($self->{KDE_VERSION} == 1) {
	$self->get_property("KWM_CURRENT_DESKTOP");
    } else {
	$self->get_property("_NET_CURRENT_DESKTOP");
    }
}

=head2 window_region

Return array with current window region bounds (for maximizing)
Output is (top, left, width, height).

=cut

sub window_region {
    my $self = shift;
    my $desktop = shift || $self->current_desktop;
    if ($self->{KDE_VERSION} == 1) {
	$self->get_property("KWM_WINDOW_REGION_$desktop");
    } else {
	my(@vals) = ($self->get_property("_NET_WORKAREA"))[$desktop*4 .. $desktop*4+3];
	if (@vals && defined $vals[0]) {
	    @vals;
	} elsif ($self->{-top} && defined &Tk::Exists && Tk::Exists $self->{-top}) {
	    (0, 0, $self->{-top}->screenwidth, $self->{-top}->screenheight);
	} else {
	    (0, 0, 800, 600); # XXX????
	}
    }
}

=head2 client_window_region

Return array with current windoe region bound without approximate size for
borders and titlebar.

=cut

sub client_window_region {
    my $self = shift;
    my(@extends) = $self->window_region;
    $extends[2] -= (4+4); # XXX wie kann man die Größe des Rahmens ansonsten rauskriegen?
    $extends[3] -= (22+4);
    @extends;
}

sub maximize {
    my $self = shift;
    my $w = shift;
    my(@extends) = $self->client_window_region;
    $w->geometry("$extends[2]x$extends[3]+$extends[0]+$extends[0]");
}

=head2 get_property

Get property with name C<$prop>.
If possible, use Tk methods, otherwise use the standard C<xprop> program.

=cut

sub get_property {
    my $self = shift;
    my $prop = shift;
    my @ret;
    if (exists $self->{'-top'} and Tk::Exists($self->{'-top'})) {
	my $top = $self->{'-top'};
	if ($top->property('exists', $prop, 'root')) {
	    # XXX split?
	    @ret = $top->property('get', $prop, 'root');
	    shift @ret; # get rid of property name
	}
    } else {
	local(%ENV) = %ENV;
	delete $ENV{XPROPFORMATS};
	open(XPROP, "xprop -notype -root $prop|");
	my $line = scalar <XPROP>;
	if ($line =~ /=\s*(.*)/) {
	    @ret = map { hex($_) } split /\s*,\s*/, $1;
	}
	close XPROP;
    }
    @ret;
}

# works with KDE 2
sub keep_on_top {
    shift;
    my $w = shift;
    my($wrapper) = $w->toplevel->wrapper;
    eval {
	if (!grep { $_ eq '_NET_WM_STATE_STAYS_ON_TOP' } $w->property('get', '_NET_SUPPORTED', 'root')) {
	    die "_NET_WM_STATE_STAYS_ON_TOP not supported";
	}
	$w->property('set', '_NET_WM_STATE', "ATOM", 32,
		     ["_NET_WM_STATE_STAYS_ON_TOP"], $wrapper);
    };
    if ($@) {
	warn $@;
	0;
    } else {
	1;
    }
}

sub panel {
    bless {Parent => $_[0]}, 'KDEUtil::Panel';
}

sub wm {
    bless {Parent => $_[0]}, 'KDEUtil::WM';
}

sub fm {
    bless {Parent => $_[0]}, 'KDEUtil::FM';
}

sub kde_dirs {
    my $self = shift;
    my $given_prefix = shift;
    my $writable = shift;
    if (defined $given_prefix) {
	my %kdedirs;
	%kdedirs = $self->_find_kde_dirs($given_prefix, $writable);
	return %kdedirs;
    } else {
	require Config;
	require File::Basename;
	my $sep = $Config::Config{'path_sep'} || ':';

	my %kdedirs = $self->_find_kde_dirs_with_kde_config($writable);
	return %kdedirs if %kdedirs;

	my @path = map { File::Basename::dirname($_) } split(/$sep/o, $ENV{PATH});
	foreach my $prefix (qw(/usr/local/kde /usr/local /opt/kde),
			    @path) {
#	    warn "Try $prefix...\n";
	    %kdedirs = $self->_find_kde_dirs($prefix, $writable);
	    return %kdedirs if %kdedirs;
	}
    }
    return ();
}

sub _find_kde_dirs_with_kde_config {
    shift;
    my $writable = shift;
    my %ret;
 TYPE:
    for my $def ([apps => "applnk"],
		 [icon => "icons"],
		 [mime => "mimelnk"],
		 [exe  => "bin"],
		 [html => "doc"],
		 [config => "config"],
		) {
	my($new_name, $old_name) = @$def;
	my(@path) = split /:/, `kde-config --expandvars --path $new_name`;
	for my $path (@path) {
	    next if (!-e $path || !-d $path);
	    next if $writable && !-w $path;
	    $ret{"-$old_name"} = $path;
	    next TYPE;
	}
    }
    %ret;
}

sub _find_kde_dirs {
    shift;
    my($prefix, $writable) = @_;
    my $applnk  = "$prefix/share/applnk";
    my $icons   = "$prefix/share/icons";
    my $mimelnk = "$prefix/share/mimelnk";
    my $bin     = "$prefix/bin";
    my $doc     = "$prefix/share/doc/HTML";
    my $config  = "$prefix/share/config";

    if (-d $applnk && (!$writable || -w $applnk) &&
	-d $icons  && (!$writable || -w $icons)) {
	my %ret = (-applnk => $applnk,
		   -icons  => $icons,
		  );
	if (-d $mimelnk && (!$writable || -w $mimelnk)) {
	    $ret{-mimelnk} = $mimelnk;
	}
	if (-d $bin && (!$writable || -w $bin)) {
	    $ret{-bin} = $bin;
	}
	if (-d $doc && (!$writable || -w $doc)) {
	    $ret{-doc} = $doc;
	}
	if (-d $config && (!$writable || -w $config)) {
	    $ret{-config} = $config;
	}
	%ret;
    } else {
	();
    }
}

sub get_kde_config {
    my $self = shift;
    my $rc = shift;
    my %commondirs = $self->kde_dirs;
    my %homedirs   = $self->kde_dirs("$ENV{HOME}/.kde");
    my $cfg = {};
    foreach my $cfgdir (\%commondirs, \%homedirs) {
	if (exists $cfgdir->{-config}) {
	    if (open(F, $cfgdir->{-config} . "/$rc")) {
		my $curr_section;
		while(<F>) {
		    /^#/ && next;
		    chomp;
		    if (/^\[(.*)\]/) {
			$curr_section = $1;
		    } elsif (/^([^=]+)=(.*)/) {
			if (defined $curr_section) {
			    $cfg->{$curr_section}{$1} = $2;
			}
		    }
		}
		close F;
	    }
	}
    }
    $cfg;
}

=head2 kde_config_for_tk

Set the appearance of Tk windows as close as possible to that of the
current KDE defintions.

=cut

sub kde_config_for_tk {
    my $self = shift;
    my $top = $self->{'-top'};
    return if (!open(KDERC, "$ENV{HOME}/.kderc"));

    my $general;
    while(<KDERC>) {
	if (!$general && /^\[General\]/) {
	    $general++;
	} elsif ($general) {
	    chomp;
	    my($key,$val) = split /=/, $_, 2;
	    if (grep { $key eq $_} qw(foreground
				      background
				      selectForeground
				      selectBackground)) {
		my $rgbcol = sprintf "#%02x%02x%02x", split /,/, $val;
		$top->optionAdd("*$key", $rgbcol, "userDefault");
		eval { $top->configure("-$key" => $rgbcol) };
		if ($key eq 'background') {
		    my $dark_rgbcol = $top->Darken($rgbcol, 80);
		    $top->optionAdd("*highlightBackground", $rgbcol,
				    "userDefault");
		    $top->optionAdd("*troughColor", $dark_rgbcol,
				    "userDefault");
		    foreach (qw(Check Radio)) {
			$top->optionAdd("*${_}button.selectColor",
					$dark_rgbcol, "userDefault");
		    }
		    $top->optionAdd("*NoteBook.backPageColor", $rgbcol,
				    "userDefault");
		    # XXX This is a hack:
		    $top->afterIdle
			(sub {
			     my $m = $top->cget(-menu);
			     $m->configure(-background => $rgbcol) if $m;
			 });
		    foreach (qw(Menu Menubutton Optionmenu)) {
			$top->optionAdd("*$_*activeBackground", $rgbcol,
					"userDefault");
		    }
		} elsif ($key eq 'foreground') {
		    foreach (qw(Menu Menubutton Optionmenu)) {
			$top->optionAdd("*$_*activeForeground", $rgbcol,
					"userDefault");
		    }
		}
	    } elsif ($key eq 'windowBackground') {
		my $rgbcol = sprintf "#%02x%02x%02x", split /,/, $val;
		for (qw(Entry NumEntry BrowseEntry.Entry
			Listbox KListbox K2Listbox TixHList HList
			Text ROText
		       )) {
		    $top->optionAdd("*$_.background", $rgbcol, "userDefault");
		}
	    } elsif ($key =~ /^(font|fixedFont)$/) {
		my @font = split /,/, $val;
		my $font = "$font[0] -$font[1]";
		$top->optionAdd("*$key", $font, "userDefault");
	    }
	}
    }
    close KDERC;

    $top->optionAdd("*Scrollbar*Width", 11, "userDefault");

    foreach (qw(Menu Menubutton Optionmenu)) {
	$top->optionAdd("*$_*tearOff", 0, "userDefault");
	$top->optionAdd("*$_*activeBorderWidth", 2, "userDefault");
	$top->optionAdd("*$_*relief", "raised", "userDefault");
    }

}

sub remove_kde_decoration {
    my $self = shift;
    my $toplevel = shift || $self->{-top};
    return if $Tk::platform ne 'unix';

    return; # XXX does not work very well!

    eval {
	my($wrapper) = $toplevel->wrapper;
	$toplevel->property('set','KWM_WIN_DECORATION','KWM_WIN_DECORATION',
			    32,[0],$wrapper);
    }; warn $@ if $@;
}

#XXX tobedone
# sub append_magic {
#     my($self, $magicfile, 
# }

{
package KDEUtil::WM;
@KDEUtil::WM::ISA = qw(KDEUtil);

my @cmd = qw(refreshScreen darkenScreen logout commandLine taskManager
	     configure
	     winMove winResize winRestore winIconify winClose winShade
	     winSticky winOperations
	     deskUnclutter deskCascade
	     desktop);
foreach (@cmd) {
    eval 'sub ' . $_ . ' { shift->command("' . $_ . '", @_) } ';
}

use vars qw($config);

sub command {
    shift;
    my(@cmd) = @_;
    my $cmd = join("", @cmd);
    system("kwmcom", $cmd);
}

sub get_config {
    my($self, $section, $key) = @_;
    if (!defined $config) {
	$config = KDEUtil->get_kde_config("kwmrc", 0);
    }
    if (exists $config->{$section}) {
	return $config->{$section}{$key};
    }
    undef;
}

}

{
package KDEUtil::Panel;
@KDEUtil::Panel::ISA = qw(KDEUtil);

my @cmd = qw(restart hide show system);
foreach (@cmd) {
    eval 'sub ' . $_ . ' { shift->command("' . $_ . '", @_) } ';
}

sub command {
    shift;
    my(@cmd) = @_;
    my $cmd = join("", @cmd);
    system("kwmcom", "kpanel:$cmd");
}

}

{
package KDEUtil::FM;
@KDEUtil::FM::ISA = qw(KDEUtil);

my @cmd = qw(openURL refreshDesktop refreshDirectory openProperties
	     exec move folder sortDesktop configure);
foreach (@cmd) {
    eval 'sub ' . $_ . ' { shift->command("' . $_ . '", @_) } ';
}

sub command {
    shift;
    my(@cmd) = @_;
    system("kfmclient", @cmd);
}

}

=head1 AUTHOR

Slaven Rezic

=cut

1;

__END__
