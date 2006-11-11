package Tk::ResizeButton;
#------------------------------------------------
# automagically updated versioning variables -- CVS modifies these!
#------------------------------------------------
our $Revision    = '$Revision: 1.3 $';
our $CheckinDate = '$Date: 2003/02/17 16:46:54 $';
our $CheckinUser = '$Author: xpix $';

# we need to clean these up right here
$Revision    =~ s/^\$\S+:\s*(.*?)\s*\$$/$1/sx;
$CheckinDate =~ s/^\$\S+:\s*(.*?)\s*\$$/$1/sx;
$CheckinUser =~ s/^\$\S+:\s*(.*?)\s*\$$/$1/sx;

our $VERSION = '0.01';

#-------------------------------------------------
#-- package Tk::ResizeButton ---------------------
#-------------------------------------------------

=head1 NAME

Tk::ResizeButton - provides a resizeable button to be used in an HList
column header.

=head1 SYNOPSIS

    use Tk;
    use Tk::HList;
    use Tk::ResizeButton;

    my $mw = MainWindow->new();

    # CREATE MY HLIST
    my $hlist = $mw->Scrolled('HList',
         -columns=>2, 
         -header => 1
         )->pack(-side => 'left', -expand => 'yes', -fill => 'both');

    # CREATE COLUMN HEADER 0
    my $headerstyle   = $hlist->ItemStyle('window', -padx => 0, -pady => 0);
    my $header0 = $hlist->ResizeButton( 
          -text => 'Test Name', 
          -relief => 'flat', -pady => 0, 
          -command => sub { print "Hello, world!\n";}, 
          -widget => \$hlist,
          -column => 0
    );
    $hlist->header('create', 0, 
          -itemtype => 'window',
          -widget => $header0, 
          -style=>$headerstyle
    );

    # CREATE COLUMN HEADER 1
    my $header1 = $hlist->ResizeButton( 
          -text => 'Status', 
          -relief => 'flat', 
          -pady => 0,
          -command => sub { print "Hello, world!\n";}, 
          -widget => \$hlist, 
          -column => 1
    );
    $hlist->header('create', 1,
          -itemtype => 'window',
          -widget   => $header1, 
          -style    =>$headerstyle
    );

=head1 DESCRIPTION

The ResizeButton widget provides a resizeable button widget for use
in an HList column header.  When placed in the column header, the
edge of the widget can be selected and dragged to a new location to
change the size of the HList column.  When resizing the column, a 
column bar will also be placed over the HList indicating the eventual
size of the HList column.  A command can also be bound to the button
to do things like sorting the column.

The widget takes all the options that Button does.  In addition,
the following options must be specified:

=over 4

=item B<-widget>

A reference to the HList widget must by provided via the -widget
option.  This allows the ResizeButton to update the column width
after resizing.

=item B<-column>

The column number that this ResizeButton is associated with must
also be provided to resize the appropriate column.

=back

=head1 AUTHOR

B<Shaun Wandler> <wandler@unixmail.compaq.com>


=head1 UPDATES

Updated by Slaven Rezic and Frank Herrmann

=head1 TODO

=over 4

=item don't give error if -command is not specified

=item don't let the user hide columns (minwidth?)

=back

=head1 KEYWORDS

Tk::HList

=cut

#########################################################################
# Tk::ResizeButton 
# Summary:  This widget creates a button for use in an HList header which
#           provides methods for resizing a column. This was heavily 
#	    leveraged from Columns.pm by Damion Wilson.
# Author:   Shaun Wandler
# Date:     $Date: 2003/02/17 16:46:54 $
# Revision: $Revision: 1.3 $
#########################################################################=
#####
#
# Updated by Slaven Rezic and Frank Herrmann
#

use base qw(Tk::Derived Tk::Button);

Construct Tk::Widget 'ResizeButton';

sub ClassInit {
	my ( $class, $mw ) = @_;
	$class->SUPER::ClassInit($mw);
	$mw->bind( $class, '<ButtonRelease-1>', 'ButtonRelease' );
	$mw->bind( $class, '<ButtonPress-1>',   'ButtonPress' );
	$mw->bind( $class, '<Motion>',          'ButtonOver' );

	return $class;
}

sub Populate {
	my ( $this, $args ) = @_;

# CREATE THE RESIZE CONTROLS
	my $l_Widget;
	for ( my $i = 0 ; $i < 2 ; ++$i ) {
		$l_Widget = $this->Component(
			'Frame'      => 'Trim_' . $i,
			-background  => 'white',
			-relief      => 'raised',
			-borderwidth => 2,
			-width       => 2,
		)->place(
			'-x'         => -( $i * 3 + 2 ),
			'-relheight' => 1.0,
			'-anchor'    => 'ne',
			'-height'    => -4,
			'-relx'      => 1.0,
			'-y'         => 2,
		);
	}

	$l_Widget->bind( '<ButtonRelease-1>' => sub { $this->ButtonRelease(1); } );
	$l_Widget->bind( '<ButtonPress-1>'   => sub { $this->ButtonPress(1); } );
	$l_Widget->bind( '<Motion>'          => sub { $this->ButtonOver(1); } );

	$this->SUPER::Populate($args);
	$this->ConfigSpecs(
		-widget => [ [ 'SELF', 'METHOD' ], 'Widget', 'Widget', undef ],
		-column => [ [ 'SELF', 'PASSIVE' ], 'Column', 'Column', 0 ],
		-minwidth => [ [ 'SELF', 'PASSIVE' ], 'minWidth', 'minWidth', 50 ], 
	);

# Keep track of last trim widget
	$this->{'m_LastTrim'} = $l_Widget;
}

sub widget {
	my $this = shift;
	if (@_) {
		my $widget = $_[0];
		my $scrolled;
		if ($$widget && $$widget->can("Subwidget")) {
			$scrolled = $$widget->Subwidget("scrolled");
		}
		if (Tk::Exists($scrolled)) {
			$this->{Configure}{'-widget'} = \$scrolled;
		} else {
			$this->{Configure}{'-widget'} = $widget;
		}
	}
	$this->{Configure}{'-widget'};
}

sub ButtonPress {
	my ( $this, $p_Trim ) = ( shift, @_ );

	$this->{'m_relief'} = $this->cget( -relief );
	if ( $this->ButtonEdgeSelected() || $p_Trim ) {
		$this->{'m_EdgeSelected'} = 1;
		$this->{m_X} = $this->pointerx() - $this->rootx();
		$this->CreateColumnBar;
	} else {
		$this->configure( -relief => 'sunken' );
		$this->{m_X} = -1;
	}
}

sub ButtonRelease {
	my ( $this, $p_Trim ) = ( shift, @_ );

	$this->{'m_EdgeSelected'} = 0;
	$this->configure( -relief => $this->{'m_relief'} );

	if ( $this->{columnBar} ) {
		$this->{columnBar}->destroy;
		undef $this->{columnBar};
	}
	if ( $this->{m_X} >= 0 ) {
		my $l_NewWidth = ( $this->pointerx() - $this->rootx() );

		my $hlist = $this->cget('-widget');
		my $col   = $this->cget( -column );
		$$hlist->columnWidth( $col, $l_NewWidth + 5 )
			if(($l_NewWidth + 5) > $this->cget( -minwidth ));

		$this->GeometryRequest( $l_NewWidth, $this->reqheight(), );

	} elsif ( !$this->ButtonEdgeSelected() ) {
		$this->Callback( -command );
	}

	$this->{m_X} = -1;
}

# CHECK IF THE RESIZE CONTROL IS SELECTED
sub ButtonEdgeSelected {
	my ($this) = @_;
	{
		return ( $this->pointerx() - $this->{m_LastTrim}->rootx() ) > -1;
	}
}

# CHANGE THE CURSOR OVER THE RESIZE CONTROL
sub ButtonOver {
	my ( $this, $p_Trim ) = @_;
	my ($cursor);
	if ( $this->{'m_EdgeSelected'} || $this->ButtonEdgeSelected() || $p_Trim ) {
		if ( $this->{columnBar} ) {
			$this->PlaceColumnBar(100);
		}
		$cursor = 'sb_h_double_arrow';
	} else {
		$cursor = 'left_ptr';
	}
	$this->configure( -cursor => $cursor );
}

# Create a column bar which displays on top of the HList widget
# to indicate the eventual size of the column.
sub CreateColumnBar {
	my ($this) = @_;

	my $hlist  = $this->cget('-widget');
	my $height = $$hlist->height() - $this->height();
	my $x      = $this->rootx + $this->width - $$hlist->rootx;

	$this->{columnBar} = $$hlist->Frame(
		-background  => 'white',
		-relief      => 'raised',
		-borderwidth => 2,
		-width       => 2,
	);
	$this->{columnBarHeight} = $height;
	$this->{columnBarDeltaX} = $$hlist->pointerx - $x;

	$this->PlaceColumnBar;
}

sub PlaceColumnBar {
	my ($this) = @_;
	
	my $hlist = $this->cget('-widget');
	my $x = $$hlist->pointerx - $this->{columnBarDeltaX};
	$this->{columnBar}->place(
		'-x'      => $x,
		'-height' => $this->{columnBarHeight} - 5,
		'-relx'   => 0.0,
		'-rely'   => 0.0,
		'-y'      => $this->height() + 5,
	);
}

1;
