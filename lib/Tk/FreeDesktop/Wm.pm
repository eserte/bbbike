package Tk::FreeDesktop::Wm;

=head1 NAME

Tk::FreeDesktop::Wm - a bridge between Tk and freedesktop window managers

=head1 SYNOPSIS

    use Tk;
    use Tk::FreeDesktop::Wm;

    my $mw = MainWindow->new;
    my $fd = Tk::FreeDesktop::Wm->new(mw => $mw); # mw argument is optional
    my @supported_properties = $fd->supported; # empty if WM is not a freedesktop WM
    my($desktop_width, $desktop_height) = $fd->desktop_geometry;
    $fd->set_wm_icon(["/path/to/icon16.png", "/path/to/icon32.png", "/path/to/icon48.png"]);

=head1 DESCRIPTION

=cut

use strict;
use vars qw($VERSION);
$VERSION = "0.03";

use Tk;

=head2 new(mw => $mainwindow)

Construct a B<Tk::FreeDesktop::Wm> object. The named argument C<mw> is
optional and should be a L<Tk::MainWindow> object, if given. If omitted,
then the first MainWindow is used.

=cut

sub new {
    my($class, %args) = @_;
    my $mw = delete $args{mw};
    die 'Unhandled arguments: ' . join(' ', %args)
	if %args;
    my $self = bless {}, $class;
    $self->mw($mw);
    $self;
}

=head2 mw([$mainwindow])

Set or get the MainWindow object.

=cut

sub mw {
    my $self = shift;
    if (@_) {
	my $val = shift;
	if ($val) {
	    $self->{mw} = $val;
	}
    } else {
	if (!$self->{mw}) {
	    $self->{mw} = (Tk::MainWindow::Existing)[0];
	}
	$self->{mw};
    }
}

sub _root_property {
    my($self, $prop) = @_;
    my(undef, @vals) = eval {
	$self->mw->property("get", "_NET_" . uc($prop), "root");
    };
    @vals;
}

sub _win_property {
    my($self, $prop) = @_;
    my(undef, @vals) = eval {
	$self->mw->property("get", "_NET_" . uc($prop), ($self->mw->wrapper)[0]);
    };
    @vals;
}

sub _win_string_property {
    my($self, $prop) = @_;
    my($val) = eval {
	$self->mw->property("get", "_NET_" . uc($prop), ($self->mw->wrapper)[0]);
    };
    $val =~ s{\0$}{} if defined $val;
    $val;
}

BEGIN {
    # root properties
    for my $prop (qw(
			supported client_list client_list_stacking
			desktop_geometry desktop_names desktop_viewport
			virtual_roots
		   )) {
	no strict 'refs';
	*{$prop} = sub { shift->_root_property($prop) };
    }

    # ... only returning a scalar
    for my $prop (qw(
			number_of_desktops active_window current_desktop
		   )) {
	no strict 'refs';
	*{$prop} = sub {
	    my($val) = shift->_root_property($prop);
	    $val;
	};
    }

    # window properties
    for my $prop (qw(
		 )) {
	no strict 'refs';
	*{$prop} = sub { shift->_win_property($prop) };
    }

    # ... only returning a scalar
    for my $prop (qw(
			wm_desktop wm_state wm_visible_name wm_window_type
		   )) {
	no strict 'refs';
	*{$prop} = sub {
	    my($val) = shift->_win_property($prop);
	    $val;
	};
    }

    # ... only returning a string
    for my $prop (qw(
			wm_desktop_file
		   )) {
	no strict 'refs';
	*{$prop} = sub {
	    my($val) = shift->_win_string_property($prop);
	    $val;
	};
    }
}

sub workareas {
    my($self) = @_;
    my(undef, @vals) = eval {
	$self->mw->property("get", "_NET_WORKAREA", "root");
    };
    my @ret;
    for(my $i = 0; $i < $#vals; $i+=4) {
	push @ret, [@vals[$i..$i+3]];
    }
    @ret;
}

sub workarea {
    my($self, $desktop) = @_;
    if (!defined $desktop) {
	$desktop = $self->current_desktop;
    }
    die "Cannot figure out current desktop" if !defined $desktop;
    @{ ($self->workareas)[$desktop] };
}

sub supporting_wm {
    my($self) = @_;
    my($win_id, $win_name, @win_class);
    eval {
	my $mw = $self->mw;
	(undef, $win_id) = $mw->property("get", "_NET_SUPPORTING_WM_CHECK", "root");
	my(undef, $win_check_id) = $mw->property("get", "_NET_SUPPORTING_WM_CHECK", $win_id);
	if ($win_id != $win_check_id) {
	    die "_NET_SUPPORTING_WM_CHECK mismatch: $win_id != $win_check_id";
	}
	if (defined $win_id) {
	    my($wm_name_utf8) = $mw->property("get", "_NET_WM_NAME", $win_id);
	    if (defined $wm_name_utf8) {
		require Encode;
		$win_name = Encode::decode("utf8", $wm_name_utf8, $win_id);
	    } else {
		($win_name) = $mw->property("get", "WM_NAME", $win_id);
	    }
	    my($raw_win_class) = $mw->property("get", "WM_CLASS", $win_id);
	    @win_class = split /\0/, $raw_win_class;
	}
    };

    return {
	    id    => $win_id,
	    name  => $win_name,
	    class => \@win_class,
	   };
}

sub set_number_of_desktops {
    my($self, $number) = @_;
    eval {
	$self->mw->property("set", "_NET_NUMBER_OF_DESKTOPS", "CARDINAL", 32,
			    [$number], "root");
    };
    warn $@ if $@;
}

sub set_desktop_viewport {
    my($self, $vx, $vy) = @_;
    eval {
	$self->mw->property("set", "_NET_DESKTOP_VIEWPORT", "CARDINAL", 32,
			    [$vx, $vy], "root");
    };
    warn $@ if $@;
}

sub set_active_window {
    die "NYI";
}

=head2 set_wm_icon([$photo, ...])

Set the window manager icon for the running application. The provided
argument is either a single element or an array reference of images
(for using icons in different sizes). Images may be specified as
L<Tk::Photo> objects, or as path names to the image files. By
specifying PNG and JPEG files L<Tk::PNG> resp. L<Tk::JPEG> is
automatically loaded.

Without this module, one could use the more restricted
L<iconimage|Tk::Wm/iconimage> Tk::Wm method. It's restricted because
images with transparency may not be displayed correctly, and there's
no support for multiple icon sizes.

See also L</BUGS> for restrictions with alpha channels.

=cut

sub set_wm_icon {
    my($self, $photos_or_files) = @_;
    my @data;
    my $mw = $self->mw;
    for my $photo_or_file (ref $photos_or_files eq 'ARRAY' ? @$photos_or_files : $photos_or_files) {
	push @data, $self->_parse_wm_icon_data($photo_or_file);
    }

    my($wr) = $mw->wrapper;
    $mw->property('set', '_NET_WM_ICON', "CARDINAL", 32,
		  [@data], $wr);
}

sub _parse_wm_icon_data {
    my($self, $photo_or_file) = @_;

    if (!UNIVERSAL::isa($photo_or_file, "Tk::Photo")) {
	my $file = $photo_or_file;
	my $magic;
	{
	    open my $fh, $file
		or die "Can't open file $file: $!";
	    read $fh, $magic, 10;
	}
	if      ($magic =~ m{^\x89PNG\x0d\x0a\x1a\x0a}) {
	    if (eval { require Imager::File::PNG; 1 }) {
		return $self->_parse_wm_icon_data_imager_png_file($file);
	    }
	    require Tk::PNG;
	} elsif ($magic =~ m{^\xFF\xD8}) {
	    require Tk::JPEG;
	}
	$self->_parse_wm_icon_data_tkphoto($self->mw->Photo(-file => $file));
    } else {
	$self->_parse_wm_icon_data_tkphoto($photo_or_file);
    }
}

sub _parse_wm_icon_data_tkphoto {
    my($self, $tkphoto) = @_;

    my @points;
    {
	my $data = $tkphoto->data;
	my $y = 0;
	# XXX Unfortunately we cannot get the alpha value from a Tk::Photo
	# --- only a transparency hack is possible.
	while ($data =~ m<{(.*?)}\s*>g) {
	    my(@colors) = split /\s+/, $1;
	    my(@trans);
	    if ($tkphoto->can("transparencyGet")) {
		# Tk 804
		for my $x (0 .. $#colors) {
		    push @trans, $tkphoto->transparencyGet($x,$y) ? "00" : "FF";
		}
	    } else {
		# Tk 800 (no transparency)
		@trans = map { "FF" } (0 .. $#colors);
	    }
	    my $x = 0;
	    push @points, map {
		hex($trans[$x++] . substr(("0"x8).substr($_, 1),-6));
	    } @colors;
	    $y++;
	}
    }

    ($tkphoto->width, $tkphoto->height, @points);
}

sub _parse_wm_icon_data_imager_png_file {
    my($self, $file) = @_;

    my $img = Imager->new(file => $file)
	or die Imager->errstr;
    my @points;
    for my $y (0 .. $img->getheight-1) {
	my @img_pixels = $img->getscanline(y => $y);
	for my $img_pixel (@img_pixels) {
	    my($r,$g,$b,$a) = $img_pixel->rgba;
	    push @points, ($a<<24) + ($r<<16) + ($g<<8) + $b;
	}
    }
    ($img->getwidth, $img->getheight, @points);
}

sub set_window_type {
    my($self, $type, $window) = @_;
    $window = $self->mw if !$window;
    $window->property("set", "_NET_WM_WINDOW_TYPE", "ATOM", 32,
		      [$type]);
}

sub set_wm_desktop_file {
    my($self, $file) = @_;
    my $mw = $self->mw;
    my($wr) = $mw->wrapper;
    $mw->property('set', '_NET_WM_DESKTOP_FILE', 'STRING', 8, $file, $wr);
}

1;

__END__

=head1 BUGS

=over

=item Alpha channels not supported in L</set_wm_icon>

It's not possible to get the alpha component of a pixel within
Perl/Tk. The alpha information is transformed into simple transparency
information, which may lead to suboptimal results. Currently it's
better to stick to icon images with transparency information only
(gif, xpm, png without alpha channel), or without transparency at all.

Currently there's a workaround which is enabled if L<Imager> with PNG
support is installed (i.e. if L<Imager::File::PNG> can be loaded). In
this case alpha channels are handled correctly.

=back

=head1 TODO

Most methods are undocumented.

Many properties are yet unimplemented.

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<http://www.freedesktop.org/wiki/Specifications/wm-spec/>,
L<Tk>, L<Tk::Wm>.

=cut

These are defined by fvwm 2.5.16:
_KDE_NET_SYSTEM_TRAY_WINDOWS
_KDE_NET_WM_FRAME_STRUT
_KDE_NET_WM_SYSTEM_TRAY_WINDOW_FOR
_NET_ACTIVE_WINDOW
_NET_CLIENT_LIST
_NET_CLIENT_LIST_STACKING
_NET_CLOSE_WINDOW
_NET_CURRENT_DESKTOP
_NET_DESKTOP_GEOMETRY
_NET_DESKTOP_NAMES
_NET_DESKTOP_VIEWPORT
_NET_FRAME_EXTENTS
_NET_MOVERESIZE_WINDOW
_NET_NUMBER_OF_DESKTOPS
_NET_RESTACK_WINDOW
_NET_SUPPORTED
_NET_SUPPORTING_WM_CHECK
_NET_VIRTUAL_ROOTS
_NET_WM_ACTION_CHANGE_DESKTOP
_NET_WM_ACTION_CLOSE
_NET_WM_ACTION_FULLSCREEN
_NET_WM_ACTION_MAXIMIZE_HORZ
_NET_WM_ACTION_MAXIMIZE_VERT
_NET_WM_ACTION_MINIMIZE
_NET_WM_ACTION_MOVE
_NET_WM_ACTION_RESIZE
_NET_WM_ACTION_SHADE
_NET_WM_ACTION_STICK
_NET_WM_ALLOWED_ACTIONS
_NET_WM_DESKTOP
_NET_WM_HANDLED_ICON
_NET_WM_ICON
_NET_WM_ICON_GEOMETRY
_NET_WM_ICON_NAME
_NET_WM_ICON_VISIBLE_NAME
_NET_WM_MOVERESIZE
_NET_WM_NAME
_NET_WM_PID
_NET_WM_STATE
_NET_WM_STATE_ABOVE
_NET_WM_STATE_BELOW
_NET_WM_STATE_FULLSCREEN
_NET_WM_STATE_HIDDEN
_NET_WM_STATE_MAXIMIZED_HORIZ
_NET_WM_STATE_MAXIMIZED_HORZ
_NET_WM_STATE_MAXIMIZED_VERT
_NET_WM_STATE_MODAL
_NET_WM_STATE_SHADED
_NET_WM_STATE_SKIP_PAGER
_NET_WM_STATE_SKIP_TASKBAR
_NET_WM_STATE_STAYS_ON_TOP
_NET_WM_STATE_STICKY
_NET_WM_STRUT
_NET_WM_VISIBLE_NAME
_NET_WM_WINDOW_TYPE
_NET_WM_WINDOW_TYPE_DESKTOP
_NET_WM_WINDOW_TYPE_DIALOG
_NET_WM_WINDOW_TYPE_DOCK
_NET_WM_WINDOW_TYPE_MENU
_NET_WM_WINDOW_TYPE_NORMAL
_NET_WM_WINDOW_TYPE_TOOLBAR
_NET_WORKAREA
