# -*- perl -*-

#
# $Id: KDEUtil.pm,v 2.27 2008/08/22 19:52:27 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2004,2008 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.rezic.de/eserte
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

Check if KDE is running (ie. kwm is running). Set the KDE_VERSION member to
either 1 (version 1) or 2 (version 2 and 3).

=cut

sub is_running {
    my $self = shift;
    if ($self->get_property("KWM_RUNNING")) { # KDE 1
	$self->{KDE_VERSION} = 1;
	1;
    } elsif ($self->get_property("KWIN_RUNNING")) { # KDE 2
	$self->{KDE_VERSION} = 2; # or 3
	1;
    } else {
	0;
    }
}

=head2 current_desktop

Return the active KDE desktop.

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
	for my $prop ("_NET_WORKAREA") { # does "_WIN_AREA" work, too?
	    my(@vals) = ($self->get_property($prop))[$desktop*4 .. $desktop*4+3];
	    if (@vals && defined $vals[0]) {
		return @vals;
	    }
	}
	if ($self->{-top} && defined &Tk::Exists && Tk::Exists $self->{-top}) {
	    (0, 0, $self->{-top}->screenwidth, $self->{-top}->screenheight);
	} else {
	    (0, 0, 800, 600); # provide reasonable values as fallback
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
If possible, use Tk methods, otherwise use the standard X11 program C<xprop>.

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

=head2 keep_on_top($tkwin)

Arrange the Tk window $tkwin to stay on top. This works best with Tk
804.028, otherwise you need X11::Protocol, otherwise it will only work
with older KDE window managers (version 2 or so).

Return true on success. You cannot trust the success value, as KDE 3.5
(for example) defines the old _NET_WM_STATE_STAYS_ON_TOP property, but
does not handle it anymore.

Note that this method might actually overwrite a <Map> binding on
$tkwin's toplevel. This actually happens if

=over

=item * the Tk version is too old and X11::Protocol must be used and

=item * $tkwin is withdrawn when calling this method

=back

Alias method name: stays_on_top.

=cut

sub keep_on_top {
    shift;
    my $w = shift;
    my $toplevel = $w->toplevel;

    if ($Tk::VERSION >= 804.027501 && $w->toplevel->can('attributes')) {
	$toplevel->attributes(-topmost => 1);
	# this was easy
	return 3;
    }

    my($wrapper) = $toplevel->wrapper;

    if (eval {
	require X11::Protocol;
	my $x = X11::Protocol->new($toplevel->screen);
	my $_NET_WM_STATE_ADD = 1;
	my $data = pack("LLLLL", $_NET_WM_STATE_ADD, $w->InternAtom('_NET_WM_STATE_ABOVE'), 0, 0, 0);
	my $send_event = sub {
	    $x->SendEvent($x->{'root'}, 0,
			  $x->pack_event_mask('SubstructureNotify', 'SubstructureRedirect'),
			  $x->pack_event(name   => 'ClientMessage',
					 window => $wrapper,
					 type   => $w->InternAtom('_NET_WM_STATE'),
					 format => 32,
					 data   => $data));
	};
	if ($toplevel->state eq 'withdrawn') {
	    $toplevel->bind('<Map>' => sub { $send_event->(); $toplevel->bind('<Map>', undef) });
	} else {
	    $send_event->();
	}
	1;
    }) {
	return 2;
    }
    warn $@ if $@;

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
*stays_on_top = \&keep_on_top;

sub panel {
    bless {Parent => $_[0]}, 'KDEUtil::Panel';
}

sub wm {
    bless {Parent => $_[0]}, 'KDEUtil::WM';
}

sub fm {
    bless {Parent => $_[0]}, 'KDEUtil::FM';
}

# XXX Probably wrong for KDE 3
sub kde_dirs {
    my $self = shift;
    my(%args) = @_;
    my $given_prefix = $args{-prefix};
    my $writable     = $args{-writable};
    my $all          = $args{-all};
    if (defined $given_prefix) {
	my %kdedirs;
	%kdedirs = $self->_find_kde_dirs($given_prefix, $writable);
	return %kdedirs;
    } else {
	require Config;
	require File::Basename;
	my $sep = $Config::Config{'path_sep'} || ':';

	my %kdedirs = $self->_find_kde_dirs_with_kde_config(-writable => $writable, -all => $all);
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
    my(%args) = @_;
    my $writable = $args{-writable} || 0;
    my $all      = $args{-all}      || 0;
    my %ret;

    # PATH fallback
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    local $ENV{PATH} = $ENV{PATH} . join $sep, map { "/opt/kde$_/bin" } (3, 2, "");

 TYPE:
    for my $def ([apps => "applnk"],
		 [icon => "icons"],
		 [mime => "mimelnk"],
		 [exe  => "bin"],
		 [html => "doc"],
		 [config => "config"],
		) {
	my($new_name, $old_name) = @$def;
	my $cfg = `kde-config --expandvars --path $new_name`;
	chomp $cfg;
	my(@path) = split /:/, $cfg;
	for my $path (@path) {
	    next if (!-e $path || !-d $path);
	    next if $writable && !-w $path;
	    if ($all) {
		push @{ $ret{"-$old_name"} }, $path;
	    } else {
		$ret{"-$old_name"} = $path;
		next TYPE;
	    }
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

# Modern KDE paths
# References:
#   http://docs.kde.org/userguide/kde-menu.html
#   http://standards.freedesktop.org/basedir-spec/basedir-spec-0.6.html
#   http://standards.freedesktop.org/menu-spec/menu-spec-1.0.html
sub get_kde_path_types {
    my($self) = @_;
    if (!$self->{PATH_TYPES}) {
	my @path_types;
	for (split /\n/, `kde-config --types`) {
	    chomp;
	    my($path_type) = $_ =~ m{^(\S+)};
	    push @path_types, $path_type;
	}
	$self->{PATH_TYPES} = \@path_types;
    }
    @{ $self->{PATH_TYPES} };
}

# Returns array of paths
sub get_kde_path {
    my($self, $path_type) = @_;
    if (!$self->{PATH}->{$path_type}) {
	my $paths;
	if (_is_in_path("kde-config")) {
	    ($paths) = `kde-config --expandvars --path $path_type`;
	    chomp $paths;
	} else {
	    # Fallback only works for xdg paths
	    my $xdg_data_home   = $ENV{XDG_DATA_HOME} || "$ENV{HOME}/.local/share";
	    my $xdg_config_home = $ENV{XDG_CONFIG_HOME} || "$ENV{HOME}/.config";
	    $paths = {'xdgconf-menu' => "$xdg_config_home/menus/:" . _default_prefix("etc") . "/xdg/menus/",
		      'xdgdata-apps' => "$xdg_data_home/applications/:" . _default_prefix("share") . "/applications/",
		      'xdgdata-dirs' => "$xdg_data_home/desktop-directories/:" . _default_prefix("share") . "/desktop-directories/",
		     }->{$path_type};
	}
	$self->{PATH}->{$path_type} = [ split /:/, $paths ];
    }
    @{ $self->{PATH}->{$path_type} };
}

# Returns default installation path
sub get_kde_install_path {
    my($self, $path_type) = @_;
    if (!$self->{INSTALL_PATH}->{$path_type}) {
	my $paths;
	if (_is_in_path("kde-config")) {
	    ($paths) = `kde-config --expandvars --install $path_type`;
	    chomp $paths;
	} else {
	    $paths = {'xdgconf-menu' => _default_prefix("etc")   . "/xdg/menus/",
		      'xdgdata-apps' => _default_prefix("share") . "/applications/",
		      'xdgdata-dirs' => _default_prefix("share") . "/desktop-directories/",
		      'exe'          => _default_prefix("usr")   . "/bin/",
		     }->{$path_type};
	}
	$self->{INSTALL_PATH}->{$path_type} = $paths;
    }
    $self->{INSTALL_PATH}->{$path_type};
}

sub get_kde_user_path {
    my($self, $path_type) = @_;
    if (!$self->{USER_PATH}->{$path_type}) {
	my $paths;
	if (_is_in_path("kde-config")) {
	    # Cease kde-config's "KLocale: trying to look up "" in catalog. Fix the program"
	    # warnings by redirecting STDERR.
	    # Seen with KDE: 3.5.1, kde-config: 1.0
	    ($paths) = `kde-config --expandvars --userpath $path_type 2>/dev/null`;
	    chomp $paths;
	} else {
	    $paths = {'desktop'  => "$ENV{HOME}/Desktop",
		      'document' => "$ENV{HOME}",
		     }->{$path_type};
	}
	$self->{USER_PATH}->{$path_type} = $paths;
    }
    $self->{USER_PATH}->{$path_type};
}

# KDE configuration, probably outdated
sub get_kde_config {
    my $self = shift;
    my $rc = shift;

    my %commondirs = $self->kde_dirs(-all => 1);
    my %homedirs   = $self->kde_dirs(-prefix => "$ENV{HOME}/.kde");

    my @dirs;
    foreach my $cfgdir (\%commondirs, \%homedirs) {
	if (exists $cfgdir->{-config}) {
	    if (ref $cfgdir->{-config} eq "ARRAY") {
		push @dirs, reverse @{ $cfgdir->{-config} };
	    } else {
		push @dirs, $cfgdir->{-config};
	    }
	}
    }

    my $cfg = {};
    foreach my $dir (@dirs) {
	my $rcfile = "$dir/$rc";
	if (open(F, $rcfile)) {
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
    $cfg;
}

=head2 kde_config_for_tk

Set the appearance of Tk windows as close as possible to that of the
current KDE defintions.

Seems to work again with KDE 3 (but is there always a .kderc?)

XXX It's better to use get_kde_config on config > kdeglobals
 
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

=head2 remove_kde_decoration($tkwin)

Remove the window decoration for the Tk window $tkwin. This is
different from overrideredirect, because window manager operations
like lowering, raising etc. still work. This method works for KDE 2
and 3.

=cut

sub remove_kde_decoration {
    my $self = shift;
    my $toplevel = shift || $self->{-top};
    return if $Tk::platform ne 'unix';

    my($wrapper) = $toplevel->wrapper;

    if (eval {
	scalar grep { $_ eq '_KDE_NET_WM_WINDOW_TYPE_OVERRIDE' } $toplevel->property('get', '_NET_SUPPORTED', 'root')
    }) {
	eval {
	    $toplevel->property('set','_NET_WM_WINDOW_TYPE','ATOM',
				32,['_KDE_NET_WM_WINDOW_TYPE_OVERRIDE'],$wrapper);
	}; warn $@ if $@;
    } else {
	eval {
	    my($wrapper) = $toplevel->wrapper;
	    $toplevel->property('set','KWM_WIN_DECORATION','KWM_WIN_DECORATION',
				32,[0],$wrapper);
	}; warn $@ if $@;
    }
}

#XXX tobedone
# sub append_magic {
#     my($self, $magicfile, 
# }

sub _is_in_path {
    my($prog) = @_;
    my $sep = ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	return "$_/$prog" if (-x "$_/$prog" && !-d "$_/$prog");
    }
    undef;
}

sub _default_prefix {
    my($path) = @_;
    if ($^O =~ m{linux}) {
	if ($path eq 'etc') {
	    '/etc';
	} elsif ($path eq 'usr') {
	    '/usr';
	} elsif ($path eq 'share') {
	    '/usr/share';
	} else {
	    die "Unhandled path <$path>";
	}
    } else { # e.g. BSD
	if ($path eq 'etc') {
	    '/usr/local/etc';
	} elsif ($path eq 'usr') {
	    '/usr/local';
	} elsif ($path eq 'share') {
	    '/usr/local/share';
	} else {
	    die "Unhandled path <$path>";
	}
    }
}

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

# peacify -w
$Tk::platform = $Tk::platform if 0;
*KDEUtil::stays_on_top = *KDEUtil::stays_on_top if 0;

1;

__END__
