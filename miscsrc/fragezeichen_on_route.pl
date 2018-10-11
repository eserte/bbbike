#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012,2018 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..", "$FindBin::RealBin/../lib";

use Getopt::Long;

use Strassen::Core;
use Strassen::Util;

sub usage (;$) {
    my $msg = shift;
    if ($msg) {
	warn $msg, "\n";
    }
    die <<EOF;
usage: $0 route.bbd
EOF
}

my $formatter = 'text80';
my $nextcheck_only;
my $use_utf8;
GetOptions(
	   "nextcheck-only" => \$nextcheck_only,
	   "two-column" => sub {
	       $formatter = 'twocolumn';
	   },
	   "utf8!" => \$use_utf8,
	  )
    or usage;

if ($use_utf8) {
    binmode STDOUT, ':utf8';
}

my $formatter_obj = FragezeichenOnRoute::Formatter->factory($formatter);

my $route_file = shift
    or usage "Please supply route file as .bbd";
my $route = Strassen->new_stream($route_file);

my $fz_file = "$FindBin::RealBin/../tmp/" . ($nextcheck_only ? "fragezeichen-outdoor-nextcheck.bbd" : "fragezeichen-outdoor.bbd");
my $fz = Strassen->new_stream($fz_file);
my %fz_coord_to_rec;
$fz->read_stream
    (
     sub {
	 my($rec) = @_;
	 for my $coord (@{ $rec->[Strassen::COORDS] }) {
	     push @{ $fz_coord_to_rec{$coord} }, $rec;
	 }
     }
    );

my %rec_seen;
my $len = 0;
$route->read_stream
    (
     sub {
	 my($rec) = @_;
	 my $cs = $rec->[Strassen::COORDS];
	 for my $coord_i (0 .. $#$cs) {
	     my $coord = $cs->[$coord_i];
	     if ($coord_i > 0) {
		 $len += Strassen::Util::strecke_s($cs->[$coord_i-1], $cs->[$coord_i]);
	     }
	     if ($fz_coord_to_rec{$coord}) {
		 for my $fz_rec (@{ $fz_coord_to_rec{$coord} }) {
		     if (!$rec_seen{$fz_rec}) {
			 $formatter_obj->out(rec => $fz_rec, len => $len);
			 $rec_seen{$fz_rec} = 1;
		     }
		 }
	     }
	 }
     }
    );
$formatter_obj->flush;

{
    package FragezeichenOnRoute::Formatter;
    # Factory
    sub factory {
	my(undef, $formatter) = @_;
	my $class = "FragezeichenOnRoute::" . ucfirst($formatter);
	$class->new;
    }
    # For subclasses
    sub flush { }
}

{
    package FragezeichenOnRoute::Text80;
    use base 'FragezeichenOnRoute::Formatter';
    use BBBikeUtil qw(m2km);
    use Text::Wrap qw(wrap);
    sub new { bless {}, shift }
    sub out {
	my($self, %opts) = @_;
	my $rec = $opts{rec};
	my $len = m2km($opts{len}, 3, 2);
	# add leading spaces, m2km cannot do this
	my($pre,$post) = $len =~ m{^(\d+)(.*)};
	$len = sprintf("%3d",$pre).$post;
	print wrap("* ".$len." ",
		   " "x(2+10+1),
		   $rec->[Strassen::NAME] ."\n"
		  );
    }
}

{
    package FragezeichenOnRoute::Twocolumn;
    use base 'FragezeichenOnRoute::Formatter';
    use BBBikeUtil qw(m2km);
    use Text::Wrap qw(wrap);
    sub new { bless { lines => []}, shift }
    sub out {
	my($self, %opts) = @_;
	my $rec = $opts{rec};
	my $len = m2km($opts{len}, 3, 2);
	local $Text::Wrap::columns = 38;
	push @{ $self->{lines} }, split /\n/, wrap("* ", "  ", $len . " " . $rec->[Strassen::NAME]);
    }
    sub flush {
	my($self) = @_;
	my $lines_per_page = 68; # XXX make configurable?
	my $column = 1;
	my $row = 0;
	my @page_lines;
	my $flush_page = sub {
	    for my $page_line (@page_lines) {
		print $page_line, "\n";
	    }
	    @page_lines = ();
	    $column = 1;
	};
	for my $line (@{ $self->{lines} }) {
	    if ($column == 1) {
		$page_lines[$row] = $line . (" " x (40-length($line)));
	    } else {
		$page_lines[$row] .= $line;
	    }
	    $row++;
	    if ($row+1 > $lines_per_page) {
		$column++;
		$row = 0;
		if ($column > 2) {
		    $flush_page->();
		}
	    }
	}
	$flush_page->();
    }
}

__END__

=head1 NAME

fragezeichen_on_route.pl - generate a listing of all "fragezeichen" on a route

=head1 DESCRIPTION

=head2 OPTIONS

=over

=item C<--nextcheck-only>

If not set, then all "fragezeichen" are printed, also the ones with a
next_check date in future. If set, then only "fragezeichen" entries
with next_check date in the past.

=item C<--two-column>

Use a two column layout. Default is a one column layout.

=item C<--utf8>

Print as utf8. Default is latin1.

=back

=head2 EXAMPLES

=over

=item * Create a route with BBBike and save it using "Datei > Exportieren > Route speichern als > bbd"

=item * Run this script

    ./miscsrc/fragezeichen_on_route.pl /path/to/saved.bbd

=item * If it looks OK, then print it:

    ./miscsrc/fragezeichen_on_route.pl /path/to/saved.bbd | lpr

=back

Alternatively, if the route exists as .bbr (zsh syntax):

    ./miscsrc/fragezeichen_on_route.pl =(./miscsrc/bbr2bbd ~/.bbbike/gps_uploads/route.bbr)

=cut
