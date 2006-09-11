# -*- perl -*-

#
# $Id: BBBikeTkUtil.pm,v 1.2 2006/09/11 22:17:11 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeTkUtil;
use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

# Sort HList by index $inx. Only toplevel children are sorted, and only
# hlists with text items will work at all. Styles get lost.
sub sort_hlist {
    my($hl, $inx) = @_;
    my(@paths) = $hl->info("children");
    my(@newpaths) = map {
	$_->[1];
    } sort {
	$a->[0] cmp $b->[0];
    } map {
	[ eval { $hl->itemCget($_, $inx, '-text') } || "", $_]
    } @paths;

    my(@newnewpaths);
    my $cols = $hl->cget(-columns);
    for(my $i=0; $i<=$#newpaths; $i++) {
	my $p = {};
	$p->{Newpath} = $i;
	$p->{Data}    = $hl->entrycget($newpaths[$i], -data);
	for(my $j=0; $j < $cols; $j++) {
	    for my $def ("ItemType", "Text", "Style", "Widget") {
		my $opt = "-" . lc($def);
		eval {
		    $p->{$def}[$j] = $hl->itemCget($newpaths[$i], $j, $opt);
		};
	    }
	    # XXX is this a bug in ItemStyle?
	    eval {
		local $SIG{__DIE__};
		undef $p->{Style}[$j]
		    unless $p->{Style}[$j]->isa('Tk::ItemStyle');
	    };
	    if ($@) {
		undef $p->{Style}[$j];
	    }
	}
	push @newnewpaths, $p;
    }
    $hl->delete('all');
    foreach my $p (@newnewpaths) {
	$hl->add($p->{Newpath}, -text => $p->{Text}[0], -data => $p->{Data});
	for(my $j=1; $j < $cols; $j++) {
	    $hl->itemCreate
	      ($p->{Newpath}, $j,
	       (defined $p->{ItemType}[$j] ? (-itemtype => $p->{ItemType}[$j]) : ()),
	       (defined $p->{Text}[$j]     ? (-text     => $p->{Text}[$j])     : ()),
	       (defined $p->{Widget}[$j]   ? (-widget   => $p->{Widget}[$j])   : ()),
	       (defined $p->{Style}[$j]    ? (-style    => $p->{Style}[$j])    : ()),
	      );
	}
    }
}

1;

__END__
