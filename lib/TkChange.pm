# -*- perl -*-

#
# $Id: TkChange.pm,v 1.12 2005/06/30 00:46:49 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package TkChange;

# Override von Standard-Methoden aus Tk.

# Verhindert, daß neue Fenster außerhalb des Fensters gezeichnet werden.
# Leider wird die Rahmenbreite der Window-Manager-Dekoration ignoriert.
package Tk::Wm; # AUTOLOAD: ignore

# XXX for window manager frame
use vars qw($wm_border_x $wm_border_y);
$wm_border_x = 6;
$wm_border_y = 28;

# XXX width/height-problem mit wine
# XXX aber ohne gehen popup-menüs anscheinend nicht...
sub XXXPopup
{
 my $w = shift;
 $w->withdraw;
 $w->positionfrom('user');
 if (defined $main::os and $main::os eq 'win') {
  my(%args) = @_;
  # don't use this on Win32 because of clicktofocus...
  delete $args{-popover} if $args{-popover} eq 'cursor';
  $w->configure(%args);
 } else {
  $w->configure(@_) if @_;
 }
# $w->idletasks;
 my($mw,$mh);
# if (defined $main::x11 && $Tk::VERSION >= 800) { # for wrapper
#     my $wrp = ($w->toplevel->wrapper)[0];
#     $w->update;
#     my %res = $main::x11->GetGeometry($wrp);
#     ($mw,$mh) = ($res{'width'}, $res{'height'});
# } else {
     ($mw,$mh) = ($w->reqwidth,$w->reqheight);
     $mw += $wm_border_x; $mh += $wm_border_y;
#warn "width=$mw height=$mh";
# }
 my ($rx,$ry,$rw,$rh) = (0,0,0,0);
 my $base    = $w->cget('-popover');
 my $outside = 0;
 if (defined $base)
  {
   if ($base eq 'cursor')
    {
     ($rx,$ry) = $w->pointerxy;
    }
   else
    {
     $rx = $base->rootx; 
     $ry = $base->rooty; 
     $rw = $base->Width; 
     $rh = $base->Height;
    }
  }
 else
  {
   my $sc = ($w->parent) ? $w->parent->toplevel : $w;
   $rx = -$sc->vrootx;
   $ry = -$sc->vrooty;
   $rw = $w->screenwidth;
   $rh = $w->screenheight;
  }
 my ($X,$Y) = AnchorAdjust($w->cget('-overanchor'),$rx,$ry,$rw,$rh);
 ($X,$Y)    = AnchorAdjust($w->cget('-popanchor'),$X,$Y,-$mw,-$mh);

 my ($sh,$sw) = ($w->screenheight, $w->screenwidth);
 if ($X + $mw > $sw) { $X = $sw - $mw }
 if ($X < 0)         { $X = 0         }
 if ($Y + $mh > $sh) { $Y = $sh - $mh }
 if ($Y < 0)         { $Y = 0         }

 ($X,$Y) = (int($X), int($Y));
 if ($X < $wm_border_x) { $X = $wm_border_x }
 if ($Y < $wm_border_y) { $Y = $wm_border_y }
 $w->deiconify;
# $w->Post($X,$Y);
 $w->positionfrom('user');
 $w->geometry("+$X+$Y");
#warn "+$X+$Y";
#warn $w->geometry;
## to prevent KDE slowness:
# $w->raise;
}

#  ######################################################################
#  #
#  # Beim Browsen mit den Cursortasten wechselt der aktive Eintrag automatisch
#  # in ein Cascade. Nervig.
#  # Aber: Mit Tk402 geht das hier nicht, auch wenn ich kurz davor ein
#  #       "return 1" mache.

#  package Tk::Menu;
#  use Tk::Menu;

#  sub FirstEntry
#  {
#   my $menu = shift;
#   return if (!defined($menu) || $menu eq '' || !ref($menu));
#   $menu->SetFocus;
#   return if ($menu->index('active') ne 'none');
#   my $last = $menu->index('last');
#   return if ($last eq 'none');
#   for (my $i = 0;$i <= $last;$i += 1)
#    {
#     my $state = eval {local $SIG{__DIE__};  $menu->entrycget($i,'-state') };
#     if (defined $state && $state ne 'disabled' && !$menu->typeIS($i,'tearoff'))
#      {
#       $menu->activate($i);
#       $menu->GenerateMenuSelect;
#  #      if ($menu->type($i) eq 'cascade')
#  #       {
#  #        my $cascade = $menu->entrycget($i,'-menu');
#  #        if (defined $cascade)
#  #         {
#  #          $menu->postcascade($i);
#  #          $cascade->FirstEntry;
#  #         }
#  #       }
#       return;
#      }
#    }
#  }

#  sub NextMenu
#  {
#   my $menu = shift;
#   my $direction = shift;
#   # First handle traversals into and out of cascaded menus.
#   my $count;
#   if ($direction eq 'right')
#    {
#  #XXX Problem: ein weiteres "right" wird nicht mehr ausgeführt
#  warn "right";
#     $count = 1;
#     if ($menu->typeIS('active','cascade'))
#      {
#  warn "1 $menu";
#  warn ">>" . $menu->index("active");
#       $menu->postcascade('active');
#       my $m2 = $menu->entrycget('active','-menu');
#  warn $m2;
#       $m2->FirstEntry if (defined $m2);
#       return;
#      }
#     else
#      {
#  warn 2;
#       my $parent = $menu->parent;
#       while ($parent->PathName ne '.')
#        {
#         if ($parent->IsMenu && $parent->cget('-type') eq 'menubar')
#          {
#           $parent->SetFocus;
#           $parent->NextEntry(1);
#           return;
#          }
#         $parent = $parent->parent;
#        }
#      }
#    }
#   else
#    {
#     $count = -1;
#     my $m2 = $menu->parent;
#     if ($m2->IsMenu)
#      {
#       if ($m2->cget('-type') ne 'menubar')
#        {
#         $menu->activate('none');
#         $menu->GenerateMenuSelect;
#         $menu->unpost;
#         $m2->SetFocus;
#         # This code unposts any posted submenu in the parent. XXX
#  #       my $tmp = $m2->index('active');
#  #       $m2->activate('none');
#  #       $m2->activate($tmp);
#         return;
#        }
#      }
#    }
#   # Can't traverse into or out of a cascaded menu. Go to the next
#   # or previous menubutton, if that makes sense.

#   my $m2 = $menu->parent;
#   if ($m2->IsMenu)
#    {
#     if ($m2->cget('-type') eq 'menubar')
#      {
#       $m2->SetFocus;
#       $m2->NextEntry(-1);
#       return;
#      }
#    }

#   my $w = $Tk::postedMb;
#   return unless defined $w;
#   my @buttons = $w->parent->children;
#   my $length = @buttons;
#   my $i = Tk::lsearch(\@buttons,$w)+$count;
#   my $mb;
#   while (1)
#    {
#     while ($i < 0)
#      {
#       $i += $length
#      }
#     while ($i >= $length)
#      {
#       $i += -$length
#      }
#     $mb = $buttons[$i];
#     last if ($mb->IsMenubutton && $mb->cget('-state') ne 'disabled'
#              && defined($mb->cget('-menu'))
#              && $mb->cget('-menu')->index('last') ne 'none'
#             );
#     return if ($mb == $w);
#     $i += $count
#    }
#   $mb->PostFirst();
#  }

### Was war das hier? Eine noch ältere Version?

# sub NextEntry
# {
#  my $menu = shift;
#  my $count = shift;
#  if ($menu->index('last') eq 'none')
#   {
#    return;
#   }
#  my $length = $menu->index('last')+1;
#  my $quitAfter = $length;
#  my $active = $menu->index('active');
#  my $i = ($active eq 'none') ? 0 : $active+$count;
#  while (1)
#   {
#    return if ($quitAfter <= 0);
#    while ($i < 0)
#     {
#      $i += $length
#     }
#    while ($i >= $length)
#     {
#      $i += -$length
#     }
#    my $state = eval {local $SIG{__DIE__};  $menu->entrycget($i,'-state') };
#    last if (defined($state) && $state ne 'disabled');
#    return if ($i == $active);
#    $i += $count;
#    $quitAfter -= 1;
#   }
#  if (defined $active and $menu->type($active) eq 'cascade')
#   {
# #XXX not perfect --- arrow is still highlighted
#    $menu->entrycget($active, '-menu')->unpost;
#   }
#  $menu->activate($i);
#  $menu->GenerateMenuSelect;
#  if ($menu->type($i) eq 'cascade')
#   {
#    my $cascade = $menu->entrycget($i, '-menu');
#    $menu->postcascade($i);
# #   $cascade->FirstEntry if (defined $cascade);
#   }
# }
######################################################################

# Enable mouse wheel on Tk::HList for older Tks
use Tk::HList;
BEGIN {
    if ($Tk::VERSION < 800.025 && Tk::Widget->can("MouseWheelBind")) { # or < 804?
	package Tk::HList;
	my $old_class_init = \&Tk::HList::ClassInit;
	local $^W = 0;
	*ClassInit = sub {
	    my($class,$mw) = @_;
	    $mw->MouseWheelBind($class);
	    $old_class_init->($class, $mw);
	};
    }
}

package Tk::Widget;

if ($Tk::platform eq 'MSWin32') { # under X11 another Busy implementation is used

local $^W = 0;
eval <<'EOF';
sub BusyRecurse
{
 my ($restore,$w,$cursor,$recurse,$top) = @_;
 my $c = $w->{_Cursor_} || $w->cget('-cursor');
 my @tags = $w->bindtags;
 if ($top || defined($c))
  {
   push(@$restore, sub { $w->configure(-cursor => $c); $w->bindtags(\@tags) });
   $w->configure(-cursor => $cursor);
  }
 else
  {
   push(@$restore, sub { $w->bindtags(\@tags) });
  }
 $w->bindtags(['Busy',@tags]);
 if ($recurse)
  {
   foreach my $child ($w->children)
    {
     BusyRecurse($restore,$child,$cursor,1,0);
    }
  }
 return $restore;
}
EOF
die $@ if $@;
}

package Tk::MyAdditions;

my %loc_de;
if (!defined $ENV{LANG} || $ENV{LANG} !~ /en/) {
    %loc_de = (Abort   => "Abbrechen",
	       Retry   => "Wiederholen",
	       Ignore  => "Ignorieren",
	       Yes     => "Ja",
	       No      => "Nein",
	       Cancel  => "Abbrechen",
	       Ok      => "Ok",
	      );
}

sub LocalisedMessageBox {
    my ($kind,%args) = @_;
    require Tk::Dialog;
    my $parent = delete $args{'-parent'};
    my $args = \%args;

    my %rev_loc_de = map { ($loc_de{$_}, $_) } keys %loc_de;

    $args->{-bitmap} = delete $args->{-icon} if defined $args->{-icon};
    $args->{-text} = delete $args->{-message} if defined $args->{-message};
    $args->{-type} = 'OK' unless defined $args->{-type};

    my $type;
    if (defined($type = delete $args->{-type})) {
	delete $args->{-type};
	my @buttons = grep($_,map(ucfirst($_),
                      split(/(abort|retry|ignore|yes|no|cancel|ok)/,
                            lc($type))));
	@buttons = map { $loc_de{$_} || $_ } @buttons;
	$args->{-buttons} = [@buttons];
	$args->{-default_button} = ucfirst(delete $args->{-default}) if
	    defined $args->{-default};
	if (not defined $args->{-default_button} and scalar(@buttons) == 1) {
	   $args->{-default_button} = $buttons[0];
	}
        my $md = $parent->Dialog(%$args);
        my $an = $md->Show;
        $md->destroy;
	$an = $rev_loc_de{$an} if exists $rev_loc_de{$an};
        return $an;
    }
} # end messageBox

{
    no strict 'refs';
    BEGIN { if ($] < 5.006) { $INC{"warnings.pm"} = 1; *warnings::unimport = sub {} } }
    no warnings 'redefine';
    my $code = \&{"LocalisedMessageBox"};
    *Tk::tk_messageBox = sub { &$code($kind,@_) };
}

1;

__END__
