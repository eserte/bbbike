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
use Encode qw(decode);
use File::Glob qw(bsd_glob);
use Getopt::Long;
use MIME::Parser;
use Safe;

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

for my $f (bsd_glob("$maildir/*")) {
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
	    if ($line =~ /(\$(supplied_coord|supplied_strname|strname|author|encoding).*)/) {
		my($code, $key) = ($1, $2);
		my $val = $cpt->reval($code);
		$data{$key} = $val;
	    }
	}
	if ($data{encoding}) {
	    for my $val (values %data) {
		$val = decode($data{encoding}, $val);
	    }
	}
    }
    if ($data{supplied_coord}) {
	my $name = $data{strname} || $data{supplied_strname};
	my $author = $data{author} || "anonymous";
	s{[\t\n]}{ }g for ($name, $author);
	my $link = $do_gnus_links ? "gnus:nnml+private:$group_article" : "file://$f";
	print "$name (by $author) $link\tX $data{supplied_coord}\n";
    }
}

__END__
