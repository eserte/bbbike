#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");

use Encode qw(decode);
use File::Basename qw(basename);
use File::Glob qw(bsd_glob);
use Getopt::Long;
use MIME::Parser;
use Safe;

use Karte::Polar;
use Karte::Standard;
use PLZ;

my $d;
my $do_gnus_links = 1;
GetOptions("d|debug" => \$d)
    or die "usage?";

my $maildir = shift || "$ENV{HOME}/Mail/bbbike-comment";
my $cpt = Safe->new;
my $mp = MIME::Parser->new;
$mp->output_to_core(1);
$mp->output_under('/tmp');

binmode STDOUT, ':encoding(iso-8859-1)';
print <<EOF;
#: category_image.X: cross
#:
EOF

my $plz = PLZ->new;

for my $f (map { $_->[1] } sort { $a->[0] <=> $b->[0] } map { [basename($_), $_] } bsd_glob("$maildir/*")) {
    next if !-f $f;
    print STDERR "$f...\n" if $d;
    my $entity = $mp->parse_open($f);
    my $head = $entity->head;
    chomp(my $xref = $head->get('xref', 0));
    my(undef, $group_article) = split /\s+/, $xref, 2;
    my %data;
    for my $part ($entity->parts) {
	my $bodyh = $part->bodyhandle;
	for my $line ($bodyh->as_lines) {
	    if ($line =~ /(\$(supplied_coord|supplied_strname|strname|author|email|encoding|comment|route).*)/) {
		my($code, $key) = ($1, $2);
		my $val = $cpt->reval($code);
		$data{$key} = $val;
	    }
	}
	if ($data{encoding}) {
	    for my $val (values %data) {
		if (Encode::_utf8_off($val)) {
		    $val = decode($data{encoding}, $val);
		}
	    }
	}
    }
    my($coord, $name);
    if ($data{supplied_coord}) {
	$coord = $data{supplied_coord};
	$name = $data{strname} || $data{supplied_strname};
    } elsif ($data{route}) {
	my($polarcoord) = split /\s+/, $data{route};
	$coord = join(",", $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard(split /,/, $polarcoord)));
	$name = $data{comment};
    } elsif ($data{strname}) {
	my @res = $plz->look_loop($data{strname},
				  Agrep => 'default',
				  LookCompat => 1,
				 );
	if (@res) {
	    $name = $res[0]->[PLZ::LOOK_NAME()];
	    $coord = $res[0]->[PLZ::LOOK_COORD()];
	}
    }
    my $author = $data{author} || $data{email} || "anonymous";
    my $link = $do_gnus_links ? "gnus:nnml+private:$group_article" : "file://$f";
    if ($coord) {
	s{[\t\n]}{ }g for ($name, $author);
	print "$name (by $author) $link\tX $coord\n";
    } else {
	my $name = ($data{strname} || $data{supplied_strname} || '???');
	s{[\t\n]}{ }g for ($name, $author);
	print "# unknown: strname=$name author=$author $link\n";
    }
}

__END__
