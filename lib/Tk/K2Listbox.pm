# -*- perl -*-

#
# $Id: K2Listbox.pm,v 1.12 2006/09/01 22:18:59 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999, 2000, 2002, 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::K2Listbox;
use Tk::Derived;
use Tk::Frame;
use Tk qw(Ev);
use Tie::Watch;
use strict;
use vars qw(@ISA $VERSION);
@ISA = qw(Tk::Derived Tk::Frame);
Construct Tk::Widget 'K2Listbox';

$VERSION = '0.08';

sub Populate {
    my($w,$args) = @_;

    my $textvarref;
    if (!exists $args->{-textvariable}) {
	my $gen = "";
	$textvarref = \$gen;
    } else {
	$textvarref = delete $args->{-textvariable};
    }
    $w->{Configure}{-textvariable} = $textvarref;
    $w->{Watch} = new Tie::Watch(-store => sub { $w->change_val(@_) },
				 -variable => $textvarref,
				);

    my $e  = $w->Component(Entry => 'entry',
			   -textvariable => $textvarref
			  )->pack(-fill => 'x');
    my $lb = $w->Component(Raw_K2Listbox => 'listbox',
			   -takefocus => 0
			  )->pack(-expand => 1, -fill => 'both');
    $lb->setMaster($w);

    $e->bind("<Down>" => sub {
		 $lb->UpDown(1);
		 $$textvarref = $lb->get("active");
	     });
    $e->bind("<Up>"   => sub {
		 $lb->UpDown(-1);
		 $$textvarref = $lb->get("active");
	     });
    $e->bind("<Next>" => sub {
		 my $height = $lb->cget(-height);
		 if ($height > 1) { $height-- }
		 $lb->UpDown($height);
		 $$textvarref = $lb->get("active");
	     });
    $e->bind("<Prior>" => sub {
		 my $height = $lb->cget(-height);
		 if ($height > 1) { $height-- }
		 $lb->UpDown(-$height);
		 $$textvarref = $lb->get("active");
	     });
    $e->bind("<Home>" => sub {
		 $lb->Cntrl_Home;
		 $$textvarref = $lb->get("active");
	     });
    $e->bind("<End>" => sub {
		 $lb->Cntrl_End;
		 $$textvarref = $lb->get("active");
	     });

    $w->ConfigSpecs(-regexp => ['PASSIVE', 'regexp', 'Regexp', 0],
		    DEFAULT => [$lb],
		   );
    $w->Delegates('focus'   => $e,
		  'Goto'    => $w, # XXX why are these necessary?
		  'Cache'   => $w,
		  'bind'    => $w,
		  'autocomplete' => $w,
		  'DEFAULT' => $lb);
    $w->AddScrollbars($lb) if exists $args->{-scrollbars};
}

sub bind {
    my $w = shift;
    $w->Subwidget('entry')->bind(@_);
    $w->Subwidget('listbox')->bind(@_);
}

sub change_val {
    my($w, $watch, $newval) = @_;
    my $lb = $w->Subwidget("listbox");
    my $e = $w->Subwidget("entry");
    my $found_i;
    if ($w->cget(-regexp)) {
	# check for valid regexp
	eval {
	    "" =~ /$newval/i;
	};
	if (!$@) {
	    my $i = 0;
	    for my $ent ($lb->get("0", "end")) {
		if ($ent =~ /$newval/i) {
		    $found_i = $i;
		    last;
		}
		$i++;
	    }
	    if (exists $w->{OrigEntryFg}) {
		$e->configure(-foreground => $w->{OrigEntryFg});
		delete $w->{OrigEntryFg};
	    }
	} else {
	    if (!exists $w->{OrigEntryFg}) {
		$w->{OrigEntryFg} = $e->cget(-foreground);
	    }
	    $e->configure(-foreground => "red");
	}
    } else {
	my(@entries);
	my $first_ch = lc(substr($newval, 0, 1));
	my $i;
	if (exists $w->{'_cache'}{$first_ch}) {
	    # XXX end könnte noch etwas effizienter sein...
	    $i = $w->{'_cache'}{$first_ch};
	} else {
	    $i = 0;
	}
	@entries = $lb->get($i, "end");
	for my $ent (@entries) {
	    if ($ent =~ /^\Q$newval\E/i) {
		$found_i = $i;
		last;
	    }
	    $i++;
	}
    }
    if (defined $found_i) {
	$lb->activate($found_i);
	$lb->selectionClear(0, "end");
	$lb->selectionSet($found_i);
	$lb->see($found_i);
    }
    $watch->Store($newval);
}

sub Goto {
    my($w, $text) = @_;
    return if (not defined $text or $text eq '');
    my $lb = $w->Subwidget("listbox"); # faster?
    my $start = (length($text) == 1 ? 0 : $lb->index('active'));
    $text = lc($text);
    $start = $w->{'_cache'}{$text} if (exists $w->{'_cache'}{$text});
    my $theIndex;
    my $less = 0;
    my $len = length($text);
    my $i = $start;
    # Search forward until we find a string whose prefix is an exact match
    # with $text
    while (1) {
	my $sub = lc(substr($lb->get($i), 0, $len));
	if ($text eq $sub) {
	    $theIndex = $i;
	    last;
	}
	++$i;
	$i = 0 if ($i == $lb->index('end'));
	last if ($i == $start);
    }
    if (defined $theIndex) {
	$lb->activate($theIndex);
#	$w->selectionSet($theIndex);
	$lb->see($theIndex);
    }
    $theIndex;     # Added By A. Johnson
}

sub Cache {
    my($w, $v) = @_;
    my $lb = $w->Subwidget("listbox"); # faster?
    $w->{'_cache'} = {};
    if ($v) {
	my $last = $lb->index('end');
	for my $i (0 .. $last) {
	    for my $j (1 .. $v) {
		my $s = $lb->get($i);
		next unless defined $s and $s ne '';
		my $beg = lc(substr($s, 0, $j));
		if (!exists $w->{'_cache'}{$beg}) {
		    $w->{'_cache'}{$beg} = $i;
		}
	    }
	}
    }
}

sub autocomplete {
    my $w = shift;
    my $e = $w->Subwidget("entry");
    # Here starts the modification - By A. Johnson
    # insert the selected item to Entry widget
    $e->bind("<FocusOut>" => sub {
	my $item = $w->Subwidget("listbox")->get("active");
	$e->delete("0.0" => 'end');
	$e->insert('end',$item);
    });
    # End of  modification - By A. Johnson
}

# Listbox package to override selectionSet
package
    Tk::Raw_K2Listbox;
use base qw(Tk::Listbox);
Construct Tk::Widget 'Raw_K2Listbox';

sub selectionSet {
    my $w = shift;
    $w->SUPER::selectionSet(@_);
    my($cur) = $w->curselection;
    if (defined $cur) {
        ${ $w->{Master}->{Configure}{-textvariable} } = $w->get($cur);
    }
}

sub setMaster {
    my($w, $master) = @_;
    $w->{Master} = $master;
}

1;


__END__
