# -*- perl -*-

#
# $Id: DataChangeLog.pm,v 1.2 2006/02/12 23:08:58 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package DataChangeLog;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my $coordrx = qr/^[0-9+-]/;

sub parse {
    my($datachange_log, $callback, %args) = @_;

    my $start = delete $args{start};
    die "Extra args: " . join(" ", %args) if %args;

    open(LOG, $datachange_log) or die "Can't open $datachange_log: $!";
    while(<LOG>) {

	if (defined $start) {
	    if (/\Q$start/) {
		undef $start;
	    } else {
		next;
	    }
	}

	if (/^#/ || /^$/) {
	    $callback->(comment => $_);
	    next;
	}

	chomp;
	my(@coords, @files);
	my($oper, $name, $cat, $rest) = $_ =~ /^(add)\s+([^\t]+)\t(\S+)\s+(.*)$/;
	if (!defined $oper) {
	    my(@rest) = split /\s+/, $_;
	    $oper = shift @rest;
	    while ($rest[-1] !~ $coordrx) {
		unshift @files, pop @rest;
	    }
	    @coords = @rest;
	    # check sanity:
	    if ($oper eq 'change') {
		if (@coords != 2) {
		    warn "Expected two coords for 'change' operation in $_";
		}
	    } elsif ($oper eq 'delete') {
		if (@coords != 1) {
		    warn "Expected one coord for 'delete' operation in $_";
		}
	    } elsif ($oper eq 'changeline') {
		if (@coords != 3) {
		    warn "Expected three coords for 'changeline' operation in $_";
		}
	    } elsif ($oper eq 'insert') {
		if (@coords != 3) {
		    warn "Expected three coords for 'insert' operation in $_";
		}
	    } elsif ($oper eq 'insertmulti') {
		if (@coords < 3) {
		    warn "Expected at least three coords for 'insertmulti' operation in $_";
		}
	    } else {
		warn "Unknown operation '$oper' in $_";
	    }
	} else {
	    my(@rest) = split /\s+/, $rest;
	    for my $i (0 .. $#rest) {
		if ($rest[$i] =~ $coordrx) {
		    push @coords, $rest[$i];
		} else {
		    push @files, @rest[$i .. $#rest];
		    last;
		}
	    }
	    #XXX undef $cat;		# XXX use the oper_cat value
	}

	$callback->(operation => $oper,
		    name      => $name,
		    files     => \@files,
		    cat       => $cat,
		    coords    => \@coords,
		   );
    }
}

1;

__END__
