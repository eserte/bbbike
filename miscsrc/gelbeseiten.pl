#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: gelbeseiten.pl,v 1.7 2003/04/27 17:10:45 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use strict;
use Getopt::Long;
use LWP::UserAgent;
use HTML::TableExtract;
use FindBin;
use lib ("$FindBin::RealBin",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 );
use TelbuchDBApprox;

# -test: use test page in ..../misc/download
# -devel: reuse mirrored pages in /tmp
my %opt;
if (!GetOptions(\%opt, "test!", "devel!")) {
    die "usage";
}

my($url, $page, $ua);
if (!$opt{test}) {
    $url = shift or die "existing search result URL!";
    ($page) = $url =~ /page=(\d+)/;
    if (!defined $page) { # fix URL
	$page = 0;
	$url .= "&page=$page";
    }

    $ua = LWP::UserAgent->new;
    $ua->env_proxy;
} else {
    $page = 0;
}

my $tb = TelbuchDBApprox->new;

my @contents;

fetch_all();
resolve_addresses();

sub resolve_addresses {
    warn "Resolve addresses (you may go offline) ...\n";
    my @adr;
    foreach my $content (@contents) {
	push @adr, parse_and_resolve_addresses($content);
    }
    warn "... OK\n";
}

sub dump_record_as_bbd {
    my $o = shift;
    if ($o->{Coord}) {
	my $fuzzy = defined $o->{Fuzzy} ? " [" . join(", ", @{$o->{Fuzzy}}) . "]" : "";
	print "$o->{Name} ($o->{Phone}) ($o->{Street}, $o->{Zip})$fuzzy\tX $o->{Coord}\n";
    } else {
	print "# $o->{Name} ($o->{Phone}) ($o->{Street}, $o->{Zip})\n";
    }
}

#  sub dump_bbd {
#      foreach my $o (@addr) {
#  	dump_record_as_bbd($o);
#      }
#  }

######################################################################
# code for new gelbeseiten.de site:

sub fetch_all {
    my $curr_url = $url;
    $page = 0;
    while(1) {
	my $content;
	if ($opt{test}) {
	    if ($page == 0) {
		open(T, "$FindBin::RealBin/../misc/download/gelbeseiten/gelbeseite1.html")
		    or last;
		local $/ = undef;
		$content = <T>;
		close T;
	    }
	} else {
	    if ($opt{devel} && -r "/tmp/gelbeseiten-$page.html" &&
		open(TEST, "/tmp/gelbeseiten-$page.html")) {
		local $/ = undef;
		$content = <TEST>;
		close TEST;
	    } else {
		$content = get_page($curr_url);
		last if !defined $content || $content =~ /Treffer gesamt:&nbsp;0/; # XXX ja?
		if (-d "/tmp" && -w "/tmp") {
		    if (open(TEST, ">/tmp/gelbeseiten-$page.html")) {
			print TEST $content;
			close TEST;
		    }
		}
	    }
	}

	if (defined $content) {
	    push @contents, $content;
	    $page++;
	    $curr_url = get_next_page_url($content);
	} else {
	    $curr_url = undef;
	}

	last if (!defined $content || !defined $curr_url);
    }
}

sub get_page {
    my $url = shift;
    print STDERR "Fetch $url ... ";
    my $resp = $ua->get($url);
    if (!$resp->is_success) {
	warn "Can't fetch $url: " . $resp->error_as_HTML;
	undef;
    } else {
	print STDERR "OK\n";
	$resp->content;
    }
}

sub get_next_page_url {
    my $s = shift;
    if ($s =~ m|<a href=\"([^\"]+)\".*<span.*?>&gt;</span></a>|) {
	my $u = $1;
	if ($u !~ /^http:/) {
	    # relative URL
	    $u = "http://www.gelbeseiten.de$u";
	}
	$u;
    } else {
	undef;
    }
}

# input is HTML string, output is list of matches
sub parse_addresses {
    my $s = shift;
    my @adr;
    my $curr;
    use constant PARSE_ADR => 0;
    use constant PARSE_TEL => 1;
    my $parse = PARSE_ADR;

    my $strip_spaces = sub {
	local $_ = shift;
	s/^\s+//;
	s/\s+$//;
	s/&quot;/\"/g;
	s/<br>/ /g;
	s/&amp;/&/g; # zuletzt!
	$_;
    };

    foreach my $l (split /\n/, $s) {
	$l =~ s/\240/ /g;
	$l =~ s/&nbsp;/ /g;
	if ($l =~ m#<a class=\"layoutD0\".*?><span.*?>(.*?)</span>,\s+(.*?),\s+(\d+)\s+Berlin#) {
	    my($name, $street, $zip) = ($1, $2, $3);
	    if ($curr) { push @adr, $curr }
	    $curr = {Name   => $strip_spaces->($name),
		     Street => $strip_spaces->($street),
		     Zip    => $strip_spaces->($zip),
		    };
	} elsif ($l =~ /Telefon:/) {
	    $parse = PARSE_TEL;
	} elsif ($parse == PARSE_TEL) {
	    if ($l =~ m|</td>|) {
		$parse = PARSE_ADR;
	    } elsif ($l =~ m|(\(\d+\)\s*\d+)|) {
		$curr->{Phone} = $1;
	    }
	}
    }
    if ($curr) { push @adr, $curr }

    @adr;
}

sub parse_and_resolve_addresses {
    my $s = shift;
    my @adr = parse_addresses($s);
    for my $o (@adr) {
	if (defined $o->{Street}) {
	    my($r) = $tb->search($o->{Street}, $o->{Zip});
	    $o->{Coord} = $r->{Coord} if defined $r->{Coord};
	    $o->{Fuzzy} = $r->{Fuzzy} if defined $r->{Fuzzy};
	}
	dump_record_as_bbd($o);
    }
    @adr;
}

__END__
