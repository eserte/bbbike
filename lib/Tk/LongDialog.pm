package Tk::LongDialog;

use vars qw($VERSION);
$VERSION = '4.004'; # $Id: LongDialog.pm,v 1.3 2005/12/10 21:49:45 eserte Exp $

# Dialog - a translation of `tk_dialog' from Tcl/Tk to TkPerl (based on
# John Stoffel's idea).
#
# Stephen O. Lidie, Lehigh University Computing Center.  94/12/27
# lusol@Lehigh.EDU

# Changed by Slaven Rezic to use a ROText instead of a Label

# Documentation after __END__

use Carp;
use strict;
use base qw(Tk::DialogBox);

Construct Tk::Widget 'LongDialog';

use Tk::ROText;

sub Populate
{

    # Dialog object constructor.  Uses `new' method from base class
    # to create object container then creates the dialog toplevel.

    my($cw, $args) = @_;

    $cw->SUPER::Populate($args);

    my ($w_bitmap,$w_but,$pad1,$pad2);

    # Create the Toplevel window and divide it into top and bottom parts.

    my (@pl) = (-side => 'top', -fill => 'both');

    ($pad1, $pad2) =
        ([-padx => '3m', -pady => '3m'], [-padx => '3m', -pady => '2m']);


    $cw->iconname('Dialog');

    my $w_top = $cw->Subwidget('top');

    # Fill the top part with the bitmap and message.

    @pl = (-side => 'left');

    $w_bitmap = $w_top->Label(Name => 'bitmap');
    $w_bitmap->pack(@pl, @$pad1);

    my $w_msg = $w_top->Scrolled("ROText",
				 -scrollbars => "oe",
				 -width => 45,
				 -height => 4,
				 -wrap => "word",
				 -borderwidth => 0);

    $w_msg->pack(-side => 'right', -expand => 1, -fill => 'both', @$pad1);

    $cw->Advertise(message => $w_msg);
    $cw->Advertise(bitmap  => $w_bitmap );

    $cw->ConfigSpecs( -image      => ['bitmap',undef,undef,undef],
                      -bitmap     => ['bitmap',undef,undef,undef],
                      -font       => ['message','font','Font', '-*-Times-Medium-R-Normal--*-180-*-*-*-*-*-*'],
		      -text	  => ['METHOD'],
                      DEFAULT     => ['message',undef,undef,undef]
                     );
}

sub text {
    my $w = shift;
    my $w_msg = $w->Subwidget("message");
    if (!@_) {
	$w_msg->get("1.0", "end");
    } else {
	my $val = shift;
	$w_msg->delete("1.0", "end");
	$w_msg->insert("end", $val);
	$val;
    }
}

# Override to "release" variable for destroyed windows.
sub Wait {
    my $cw = shift;
    $cw->Callback(-showcommand => $cw);
    my $aborted = 0;
    if (!$cw->{HasOnDestroy}) {
	$cw->{HasOnDestroy} = sub {
	    $aborted = 1;
	    $cw->{'selected_button'} = "ignore";
	};
	$cw->OnDestroy($cw->{HasOnDestroy});
    }
    $cw->waitVariable(\$cw->{'selected_button'});
    if (Tk::Exists($cw)) { # may not exist if closed or destroyed
	$cw->grabRelease;
	$cw->withdraw;
    }
    if ($aborted) {
	$cw->{'selected_button'} = undef;
    } else {
	$cw->Callback(-command => $cw->{'selected_button'});
    }
}

1;

__END__

=cut

