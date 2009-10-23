# -*- perl -*-

#
# $Id: SRTProgress.pm,v 1.12 2009/01/24 22:01:48 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2003,2005,2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::SRTProgress;
use Tk::Canvas;
use vars qw(@ISA $VERSION $VERBOSE);
use strict;

@ISA = qw(Tk::Derived Tk::Canvas);
$VERSION = '0.07';

Construct Tk::Widget 'SRTProgress';

sub ClassInit {
    my ($class,$mw) = @_;
    $class->SUPER::ClassInit($mw);
    $mw->Tk::bind($class, "<Configure>", "Refresh");
    $class;
}

sub Populate {
    my($w, $args) = @_;
    $args->{'height'} = 16 unless exists $args->{'height'};
    $w->SUPER::Populate($args);
    $w->{InProgress} = 0;
    $w->createRectangle(0,0,0,0,
			-outline => undef,
			-fill => 'blue',
			-tags => 'bar');
    $w->createText(0,0,
		   -fill => 'black', -justify => 'center',
		   -tags => 'label');
    $w->ConfigSpecs
      (-labelfont  => ['METHOD', 'labelFont', 'LabelFont', undef],
       -dependents => ['PASSIVE', 'dependents', 'Dependents', undef],
       -visible    => ['PASSIVE', 'visible', 'Visible', 1],
       # Warning: dont't change the -grab option during an
       # InitGroup/FinishGroup pair!
       -grab       => ['PASSIVE', 'grab', 'Grab', 0],
      );
    $w->Refresh;
}

sub labelfont { # XXX no cget variant yet
    my($w, $val) = @_;
    $w->itemconfigure('label', -font => $val);
    $val;
}

sub Refresh {
    my $w = shift;
    $w->{Width}  = $w->Width;
    $w->{Height} = $w->Height;
    $w->coords('label', $w->{'Width'}/2, $w->{'Height'}/2);
    if (@{$w->{CurrentFrac} || []} && defined $w->{CurrentFrac}[-1]) {
	$w->coords('bar', 0, 0, int($w->{Width}*$w->{CurrentFrac}[-1]), $w->{Height});
    }
}

sub InitGroup {
    my $w = shift;
    warn "InitGroup\n" if $VERBOSE;
    if ($w->{Group}) {
	warn "InitGroup already active!\n";
    } else {
	if ($w->cget(-grab)) {
	    $w->{OldBindtags} = [$w->toplevel->bindtags];
	    $w->grab;
	}
	$w->{Group}{Start} = 1;
    }
    $w->{Group}{Count}++;
}

sub Init {
    my($w, %args) = @_;
    warn "Init\n" if $VERBOSE;
    my $dep = (exists $args{'-dependents'}
	       ? $args{'-dependents'}
	       : $w->{'dependents'});
    push @{$w->{'CurrentDependents'}}, (ref $dep eq 'ARRAY'
					? $dep
					: (defined $dep ? [$dep] : undef));

    push @{$w->{'CurrentLabel'}}, $args{'-label'} || '';

    push @{$w->{'CurrentVisible'}}, (exists $args{'-visible'}
				     ? $args{'-visible'}
				     : $w->cget(-visible)||0);

    push @{$w->{'CurrentFrac'}}, undef;

    $w->{'Xpos'}    = 0 if !defined $w->{'Xpos'};
    $w->{'Forward'} = 1 if !defined $w->{'Forward'};

    $w->itemconfigure('label', -text => $w->{'CurrentLabel'}[-1]);

    $w->{InProgress}++;

    push @{$w->{HideDone}}, 0;
    $w->Update(0);
}

sub Update {
    my($w, $frac, %args) = @_;
    $frac = 0 unless defined $frac;
    $w->{CurrentFrac}[-1] = $frac;
    $w->coords('bar', 0, 0, int($w->{Width}*$frac), $w->{Height});
    $w->{'CurrentLabel'}[-1] = $args{'-label'} if exists $args{'-label'};
    my $text = $w->{'CurrentLabel'}[-1] .
      ($frac > 0 ? " " . int($frac*100) . "%" : "");
    $w->itemconfigure('label', -text => $text);
    if ($frac > 0) {
	$w->HideDependents;
    }
    $w->idletasks;
}

sub UpdateFloat {
    my $w = shift;
    $w->{CurrentFrac}[-1] = undef;
    if ($w->{'Forward'}) {
	if ($w->{'Xpos'}+2*$w->{'Height'} < $w->{'Width'}) {
	    $w->{'Xpos'} += $w->{'Height'};
	} else {
	    $w->{'Forward'} = 0;
	    $w->{'Xpos'} -= $w->{'Height'};
	}
    } else {
	if ($w->{'Xpos'} - $w->{'Height'} >= 0) {
	    $w->{'Xpos'} -= $w->{'Height'};
	} else {
	    $w->{'Forward'} = 1;
	    $w->{'Xpos'} += $w->{'Height'};
	}
    }
    $w->coords('bar', $w->{'Xpos'}, 0,
	       $w->{'Xpos'} + $w->{'Height'},
	       $w->{'Height'});
    $w->itemconfigure('label', -text => $w->{CurrentLabel}[-1])
      if defined $w->{CurrentLabel}[-1];
    $w->HideDependents;
    $w->idletasks;
}

sub RestoreDependents {
    my $w = shift;
    if ($w->{'HiddenWidgets'} && @{$w->{'HiddenWidgets'}}) {
	foreach my $dep (@{ $w->{'HiddenWidgets'}[-1] }) {
	    $w->ShowWidget($dep);
	}
	pop @{$w->{'HiddenWidgets'}};
    }
}

sub Finish {
    my $w = shift;
    warn "Finish\n" if $VERBOSE;
    $w->itemconfigure('label', -text => '');
    $w->coords('bar', 0, 0, 0, 0);
    pop @{$w->{'CurrentDependents'}};
    pop @{$w->{'CurrentLabel'}};
    pop @{$w->{'CurrentFrac'}};
    pop @{$w->{'CurrentVisible'}};
    pop @{$w->{'HideDone'}};
    if (!$w->{Group} ||
	($w->{'HiddenWidgets'} && @{$w->{'HiddenWidgets'}} > 1)
       ) {
	$w->RestoreDependents;
    }
    $w->{InProgress}--;
}

sub FinishGroup {
    my $w = shift;
    warn "FinishGroup\n" if $VERBOSE;
    $w->{Group}{Count}--;
    if (!$w->{Group}{Count}) {
	$w->RestoreDependents;
	# if-Abfrage, um autovivify zu verhindern (??? häh?)
	delete $w->{Group};
	if ($w->cget(-grab)) {
	    $w->grabRelease;
	    $w->toplevel->bindtags($w->{OldBindtags});
	}
    }
}

sub HideDependents {
    my($w) = @_;
    return if $w->{HideDone}[-1];
    my @hidden_widgets;
 TRY: {
	if ($w->{'CurrentDependents'}[-1]) {
#  	    if (exists $w->{'Group'}) {
#  		if ($w->{'Group'}{'Start'}) {
#  		    $w->{'Group'}{'Start'} = 0;
#  		} else {
#  		    last TRY;
#  		}
#  	    }
	    warn "inprogress=$w->{InProgress}\n" if $VERBOSE;
	    last TRY if ($w->{InProgress} != 1);
	    if (!$w->{'CurrentVisible'}[-1]) {
		foreach (@{ $w->{'CurrentDependents'}[-1] }) {
		    push @hidden_widgets, $_
			if $w->HideWidget($_);
		}
	    }
	}
    }
    push @{$w->{'HiddenWidgets'}}, \@hidden_widgets;
    $w->{HideDone}[-1] = 1;
}

sub HideWidget {
    my($w, $wid) = @_;
    my @res;
    my $mgr = $wid->manager;
    return 0 if !defined $mgr; # already hidden
    my $infosub   = $mgr . "Info";
    if ($wid->can($infosub)) {
	@res = $wid->$infosub();
	warn "found @res\n" if $VERBOSE;
	# Fix corrupted gridInfo for -sticky
	if ($Tk::VERSION <= 800.015 and $mgr eq 'grid') {
	    for(my $i=0; $i<$#res; $i+=2) {
		if ($res[$i] eq '-sticky' and
		    $res[$i+1] eq '{}') {
		    $res[$i+1] = '';
		}
	    }
	}
	$w->{Mgr}{$wid}{Type}   = $mgr;
	$w->{Mgr}{$wid}{Info}   = [@res];
	$w->{Mgr}{$wid}{Widget} = $wid;
	warn "forget $wid\n" if $VERBOSE;
	$wid->$mgr('forget');
	return 1;
    }
    0;
}

sub ShowWidget {
    my($w, $wid) = @_;
    my $mgr = $w->{Mgr}{$wid}{Type};
    if ($mgr) {
	warn "$w->{Mgr}{$wid}{Widget}->$mgr(@{ $w->{Mgr}{$wid}{Info} })\n"
	  if $VERBOSE;
	$w->{Mgr}{$wid}{Widget}->$mgr(@{ $w->{Mgr}{$wid}{Info} });
	delete $w->{Mgr}{$wid};
    }
}

# dummy sub to prevent error in Tk::Frame (why?)
sub labelPack { }

1;

__END__

=head1 NAME

Tk::SRTProgress - another progress bar for Tk

=head1 SYNOPSIS

    use Tk::SRTProgress;
    $progressbar = $mw->SRTProgress;

=head1 DESCRIPTION

Missing ...

=head1 EXAMPLE

    use Tk;
    use Tk::SRTProgress;
    my $mw = tkinit;
    my $p = $mw->SRTProgress->pack;
    $p->Init;
    $p->repeat(100, sub { $p->UpdateFloat });
    MainLoop;

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 COPYRIGHT

Copyright (c) 1999,2003,2005,2009 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Tk::ProgressBar>

=cut

