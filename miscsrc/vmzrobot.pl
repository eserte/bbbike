#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: vmzrobot.pl,v 1.3 2003/11/03 22:48:45 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use HTML::LinkExtor;
use HTML::TreeBuilder;
use HTML::FormatText 2; # can deal with tables
use LWP::UserAgent;
use Getopt::Long;
use URI::Escape qw(uri_unescape);
use Text::Balanced qw(extract_delimited);

my $test;
my $inputfile;
my $quiet;
my $listing_url = "http://www.vmz-berlin.de/vmz/trafficspotmap.do";
my $detail_url  = "http://www.vmz-berlin.de/vmz/trafficmap.do";
my @output_as;

if (!GetOptions("test" => \$test,
		"i|inputfile=s" => \$inputfile,
		"q" => \$quiet,
		'outputas=s@' => \@output_as,
	       )) {
    die <<EOF;
usage: $0 [-test] [-i|-inputfile file] [-q] [-outputas type] ...

Multiple -outputas optione are possible, default is "text". -outputas
is of the form "type:file". If ":file" is left, then the output goes
to stdout. file must not exist. type may be text, bbd, dump (perl
dump) and yaml.

-inputfile has to be a YAML file for now.
EOF
}

if (!@output_as) { @output_as = "text" }
my %output_as = map { my($type, $file) = split /:/, $_, 2;
		      ($type => $file);
		    } @output_as;

while(my($k,$v) = each %output_as) {
    if (defined $v && -e $v) {
	die "Won't overwrite existing file $v";
    }
}

if ($test) {
    $listing_url = "file:///home/www/download/www.vmz-berlin.de/vmz/trafficspotmap.do";
    $detail_url  = "file:///home/www/download/www.vmz-berlin.de/vmz/trafficmap.do";
}

my $ua;
my @detail_links;
if ($inputfile) {
    require YAML;
    my $ref = YAML::LoadFile($inputfile);
    @detail_links = @$ref;
} else {
    $ua = LWP::UserAgent->new;
    print STDERR "Get listing..." if !$quiet;
    my @detail_links = get_listing();
    print STDERR " OK\n" if !$quiet;
    {
	my $i = 0;
	for my $detail_link (@detail_links) {
	    printf STDERR "%d%%   \r", $i/@detail_links*100 if !$quiet;
	    $detail_link->{text} = get_detail($detail_link->{querystring});
	    $i++;
	}
    }
}

if (exists $output_as{'text'}) {
    my $fh = file_or_stdout($output_as{text});
    my $sep = "-"x50 . "\n";
    print $fh join($sep, map { $_->{text} } @detail_links);
}

if (exists $output_as{'bbd'}) {
    my $fh = file_or_stdout($output_as{bbd});
    require Karte;
    Karte::preload(qw(Standard Polar));
    for my $info (@detail_links) {
	(my $text = $info->{text}) =~ s/[\n\t]+/ /g;
	$text =~ s/\[IMAGE\]//g; # XXX
	my($x1, $y1) = map { int } $Karte::Polar::obj->map2standard
	    ($info->{x1}, $info->{y1});
	my($x2, $y2) = map { int } $Karte::Polar::obj->map2standard
	    ($info->{x2}, $info->{y2});
	print $fh "$text\tX $x1,$y1 $x2,$y1 $x2,$y2 $x1,$y2 $x1,$y1\n";
    }
}

if (exists $output_as{'dump'}) {
    my $fh = file_or_stdout($output_as{'dump'});
    require Data::Dumper;
    print $fh (Data::Dumper->new([\@detail_links], ['vmz'])->Dump);
}

if (exists $output_as{'yaml'}) {
    my $fh = file_or_stdout($output_as{'yaml'});
    require YAML;
    print $fh (YAML::Dump(\@detail_links));
}

print STDERR "\n" if !$quiet;

sub get_listing {
    my $resp = $ua->get($listing_url);
    if (!$resp->is_success) {
	warn "Can't fetch $listing_url: " . $resp->content;
	return;
    }
    my @detail_links;
    my $p = HTML::LinkExtor->new
	(sub {
	     my($tag, %attr) = @_;
	     if ($tag =~ /^area$/i) {
		 my $href = uri_unescape($attr{href});
		 if ($href =~ /javascript:trafficmap\((.*)\)/) {
		     my $remainder = $1;
		     my @arg;
		     my %info;
		     while(1) {
			 (my $extracted, $remainder) = extract_delimited
			     ($remainder, '"');
			 $remainder =~ s/^[^\"]*//;
			 my $arg = substr($extracted, 1, -1);
			 push @arg, $arg;
			 if ($arg =~ /^(id|x1|y1|x2|y2)=(.*)/) {
			     $info{$1} = $2;
			 } else {
			     warn "Unhandled $1 => $2";
			 }
			 last if $remainder eq '';
		     }
		     $info{querystring} = join("&", @arg);
		     push @detail_links, \%info;
		 }
	     }
	 }, $listing_url);
    $p->parse($resp->content);
    @detail_links;
}

sub get_detail {
    my($qs) = @_;
    if ($test) {
	warn "Would try $qs";
	$qs = "";
    } else {
	$qs = "?$qs";
    }
    my $resp = $ua->get("$detail_url$qs");
    if (!$resp->is_success) {
	warn "Can't fetch $detail_url$qs: " . $resp->content;
	return;
    }

    my $tree = HTML::TreeBuilder->new->parse($resp->content);
    my $formatter = HTML::FormatText->new(leftmargin => 0, rightmargin => 50);
    $formatter->format($tree);
}

sub file_or_stdout {
    my($output_as) = @_;
    my $fh;
    if (defined $output_as) {
	my $f = $output_as;
	if (-e $f) {
	    die "Won't overwrite existing file $f";
	}
	open($fh, ">$f") or die "Can't write to $f: $!";
    } else {
	$fh = \*STDOUT;
    }
    $fh;
}

__END__
