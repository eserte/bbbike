##############################################################################
# Tk::resizeButton 
# Summary: This widget creates a button for use in an HList header which
#          provides methods for resizing a column. This was heavily leveraged
#          from Columns.pm by Damion Wilson.
# Author:  Shaun Wandler
# Date:    11/17/1998
# Revision: $Revision$
##############################################################################
#
# Updated by Slaven Rezic
#


# XXX needs lot of work:
# * position columnbar correctly and only use MoveColumnBar to move it instead
# of destroying it and re-creating with CreateColumnBar
# * use Subwidget('scrolled') if it exists
# * don't give error if -command is not specified
# * don't let the user hide columns (minwidth?)

package Tk::resizeButton;

use base qw(Tk::Derived Tk::Button);

Construct Tk::Widget 'resizeButton';
 
 sub ClassInit
 {
  my ($class,$mw) = @_;
  $class->SUPER::ClassInit($mw);
  $mw->bind ($class, '<ButtonRelease-1>' ,'ButtonRelease');
  $mw->bind ($class, '<ButtonPress-1>' ,'ButtonPress');
  $mw->bind ($class, '<Motion>' ,'ButtonOver');

  return $class;
 }

 
 sub Populate
 {
  my ($this,$args) = @_;

    # CREATE THE RESIZE CONTROLS
    my $l_Widget;
    for (my $i = 0; $i < 2; ++$i)
       {
        $l_Widget = $this->Component
           (
            'Frame' => 'Trim_'.$i,
            '-background' => 'white',
            '-relief' => 'raised',
            '-borderwidth' => 2,
            '-width' => 2,
           );
        $l_Widget->place
           (
            '-x' => - ($i * 3 + 2),
            '-relheight' => 1.0,
            '-anchor' => 'ne',
            '-height' => - 4,
            '-relx' => 1.0,
            '-y' => 2,
           );
    }

    $l_Widget->bind ('<ButtonRelease-1>' => sub {$this->ButtonRelease (1);});
    $l_Widget->bind ('<ButtonPress-1>' => sub {$this->ButtonPress (1);});
    $l_Widget->bind ('<Motion>' => sub {$this->ButtonOver (1);});

    $this->SUPER::Populate($args);
    $this->ConfigSpecs(
     '-widget' => [['SELF', 'PASSIVE'], 'Widget', 'Widget', undef],
     '-column' => [['SELF', 'PASSIVE'], 'Column', 'Column', 0]
    );

    # Keep track of last trim widget
    $this->{'m_LastTrim'} = $l_Widget;
 }

sub ButtonPress{
    my ($this, $p_Trim) = (shift, @_);

    $this->{'m_relief'} = $this->cget('-relief');
    if ($this->ButtonEdgeSelected() || $p_Trim)
       {
        $this->{'m_EdgeSelected'} = 1;
        $this->{m_X} = $this->pointerx() - $this->rootx();
        CreateColumnBar($this);
       }
    else
       {
        $this->configure ('-relief' => 'sunken');
        $this->{m_X} = -1;
       }

}

sub ButtonRelease {
    my ($this, $p_Trim) = (shift, @_);

    $this->{'m_EdgeSelected'} = 0;
    $this->configure ('-relief' => $this->{'m_relief'});

    if ($this->{columnBar}){ 
        $this->{columnBar}->destroy;
        undef $this->{columnBar};
    }
    if ($this->{m_X} >= 0)
       {
        my $l_NewWidth =
           (
            $this->pointerx() -
            $this->rootx()
           );

         my $hlist = $this->cget('-widget');
         my $col = $this->cget('-column');
         $$hlist->columnWidth($col, $l_NewWidth+5);

        $this->GeometryRequest
           (
            $l_NewWidth,
            $this->reqheight(),
           );

       }
    elsif (! $this->ButtonEdgeSelected ())
       {
         $this->Callback('-command');
       }

    $this->{m_X} = -1;
}


# CHECK IF THE RESIZE CONTROL IS SELECTED
sub ButtonEdgeSelected{
   my ($this) = @_;
   {
    return ($this->pointerx() - $this->{m_LastTrim}->rootx()) > -1;
   }
}

# CHANGE THE CURSOR OVER THE RESIZE CONTROL
sub ButtonOver{
   my($this, $p_Trim) = @_;
    my ($cursor);
    if ($this->{'m_EdgeSelected'} || $this->ButtonEdgeSelected() || $p_Trim){ 
        if ($this->{columnBar}){ 
            $this->{columnBar}->destroy; 
            CreateColumnBar($this);
        }
        $cursor = 'sb_h_double_arrow' ;
    }
    else{
        $cursor = 'left_ptr';
    }
   $this->configure(-cursor => $cursor);
}

# Create a column bar which displays on top of the HList widget
# to indicate the eventual size of the column.
sub CreateColumnBar{
    my($this) = @_;

    my $hlist  = $this->cget('-widget');
    my $height = $$hlist->height() - $this->height();
    my $x = $$hlist->pointerx() - $$hlist->rootx();
#    my $x = $this->rootx + $this->width - $$hlist->rootx;
    $this->{columnBar} = $$hlist->Frame( 
        '-background' => 'white',
        '-relief' => 'raised',
        '-borderwidth' => 2,
        '-width' => 2,
       );
    #FIXFIX: Some fudge factors were used here to place the column
    # bar at the correct place.  It appears that hlist->rootx is
    # relative to the scrollbar, while when placing the columnbar
    # the x location is relative to hlist widget.  This definitely
    # doesn't work when using a non-scrolled hlist.
    $this->{columnBar}->place
       (
        '-x' => $x,
        '-height' => $height-5,
        '-relx' => 0.0,
        '-rely' => 0.0,
        '-y' => $this->height()+5,
       );
}
1;
