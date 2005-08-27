#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: vmzrobot.pl,v 1.18 2005/08/26 23:09:18 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004 Slaven Rezic. All rights reserved.
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
#use HTML::LinkExtor;
use HTML::TreeBuilder;
use HTML::FormatText 2; # can deal with tables
use LWP::UserAgent;
use Getopt::Long;
use URI::Escape qw(uri_unescape);
use Text::Balanced qw(extract_delimited);
use Data::Compare qw(Compare);
use Storable qw(dclone);

my $test;
my $inputfile;
my $oldfile;
my $do_diffcount;
my $do_irrelevant;
my $quiet;
my $force;
my $listing_url = "http://www.vmz-berlin.de/vmz/rdstmc.do";
my $detail_url  = "http://www.vmz-berlin.de/vmz/trafficmap.do"; # XXX not used anymore
my @output_as;

return 1 if caller;

if (!GetOptions("test" => \$test,
		"i|inputfile=s" => \$inputfile,
		"old|oldfile=s" => \$oldfile,
		"diffcount" => \$do_diffcount,
		"q" => \$quiet,
		"f" => \$force,
		'outputas=s@' => \@output_as,
		'irrelevant|markirrelevant!' => \$do_irrelevant,
	       )) {
    die <<EOF;
usage: $0 [-test] [-i|-inputfile file] [-old|-oldfile file]
          [-diffcount] [-irrelevant] [-q] [-outputas type] ...

Multiple -outputas options are possible, default is "text". -outputas
is of the form "type:file". If ":file" is left, then the output goes
to stdout. file must not exist. type may be text, bbd, dump (perl
dump) and yaml.

-inputfile and -oldfile have to be YAML files.
EOF
}

if (!@output_as) { @output_as = "text" }
my %output_as = map { my($type, $file) = split /:/, $_, 2;
		      ($type => $file);
		    } @output_as;
my @valid_types = qw(text bbd dump yaml);
my $valid_types_rx = '(' . join("|", map { quotemeta } @valid_types) . ')';
$valid_types_rx = qr/$valid_types_rx/;

while(my($type,$file) = each %output_as) {
    if ($type !~ $valid_types_rx) {
	die "The type $type is invalid, try @valid_types\n";
    }
    if (defined $file && -e $file && !$force) {
	die "Won't overwrite existing file $file without -f\n";
    }
}

if ($test) {
    $listing_url = "file:///home/www/download/www.vmz-berlin.de/vmz/rdstmc.do";
}

my $ua;
my @detail_links;
my @old_detail_links;
if ($inputfile) {
    require YAML;
    my $ref = YAML::LoadFile($inputfile);
    @detail_links = @$ref;
} else {
    $ua = LWP::UserAgent->new;
    #$ua->agent(...);
    print STDERR "Get listing..." if !$quiet;
    @detail_links = get_listing();
    print STDERR " OK\n" if !$quiet;
}

if ($oldfile) {
    require YAML;
    my $ref = YAML::LoadFile($oldfile);
    @old_detail_links = @$ref;

    if ($do_irrelevant) {
	mark_irrelevant_entries(@detail_links);
	mark_irrelevant_entries(@old_detail_links);
    }

    @detail_links = diff();
    if ($do_diffcount) {
	my $diffcount = grep {
	    $_->{_state} && !grep {
		$_ =~ /^UNCHANGED/
	    } @{ $_->{_state} }
	} @detail_links;
	if (!$diffcount) {
	    warn "No changes.\n" if !$quiet;
	    exit 0;
	} else {
	    warn "There are $diffcount changes.\n" if !$quiet;
	    exit $diffcount;
	}
    }
}

if (exists $output_as{'text'}) {
    my $fh = file_or_stdout($output_as{text});
    my $sep = "-"x50 . "\n";
    print $fh join($sep, map { state_out($_) . $_->{text} } @detail_links);
}

if (exists $output_as{'bbd'}) {
    my $fh = file_or_stdout($output_as{bbd});
    require Karte;
    Karte::preload(qw(Standard Polar));

    print $fh <<EOF;
#: title: VMZ
#:
EOF
    for my $info (@detail_links) {
	(my $text = $info->{text}) =~ s/[\n\t]+/ /g;
	$text =~ s/\[IMAGE\]//g; # XXX
	$text = state_out($info) . $text;
	my($x1, $y1) = map { int } $Karte::Polar::obj->map2standard
	    ($info->{x1}, $info->{y1});
	my($x2, $y2) = map { int } $Karte::Polar::obj->map2standard
	    ($info->{x2}, $info->{y2});
	my $cat = get_bbd_category($info);
	print $fh "$text\t$cat ";
	if ($x1 == $x2 && $y1 == $y2) {
	    print $fh "$x1,$y1";
	} else {
	    print $fh "$x1,$y1 $x2,$y1 $x2,$y2 $x1,$y2 $x1,$y1";
	}
	print $fh "\n";
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
	die "Can't fetch $listing_url: " . $resp->content;
    }
    my @detail_links;

    my $p = HTML::TreeBuilder->new;
    $p->parse($resp->content);
    $p->eof;

    () = $p->look_down(
	'_tag', 'a',
	sub {
	    my $elem = shift;
	    my $href = $elem->attr('href');
	    return unless defined $href;
	    my $href = uri_unescape($href);
	    return unless $href =~ /javascript:trafficmap\((.*)\)/;
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

	    my $tr = $elem->parent->parent;
	    my $tree = HTML::TreeBuilder->new->parse($tr->as_HTML);
	    my $formatter = HTML::FormatText->new(leftmargin => 0, rightmargin => 50);
	    $info{text} = $formatter->format($tree);
	    push @detail_links, \%info;
	}
		      );
    if (!@detail_links) {
	warn "No detail links in listing page found!\n";
    }
    @detail_links;
}

# XXX not used anymore
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
	if (-e $f && !$force) {
	    die "Won't overwrite existing file $f without -f\n";
	}
	open($fh, ">$f") or die "Can't write to $f: $!";
    } else {
	$fh = \*STDOUT;
    }
    $fh;
}

sub diff {
    my %detail_links     = map {($_->{id} => $_)} @detail_links;
    my %old_detail_links = map {($_->{id} => $_)} @old_detail_links;
    my @diff_detail_links;
    for my $orig_detail_link (@detail_links) {
	my $detail_link = dclone $orig_detail_link;
	my $old_detail_link = $old_detail_links{$detail_link->{id}};
	if (!$old_detail_link) {
	    push @{ $detail_link->{_state} }, "NEW";
	} else {
	    if (Compare($detail_link, $old_detail_link) == 0) {
		push @{ $detail_link->{_state} }, "CHANGED";
		if (Compare($detail_link->{text}, $old_detail_link->{text}) == 0) {
		    push @{ $detail_link->{_state} }, "(text)";
		} else {
		    push @{ $detail_link->{_state} }, "(coords)";
		}
	    } else {
		push @{ $detail_link->{_state} }, "UNCHANGED";
	    }
	}
	push @diff_detail_links, $detail_link;
    }
    for my $orig_detail_link (@old_detail_links) {
	my $detail_link = dclone $orig_detail_link;
	if (!exists $detail_links{$detail_link->{id}}) {
	    push @{ $detail_link->{_state} }, "REMOVED";
	    push @diff_detail_links, $detail_link;
	}
    }
    @diff_detail_links;
}

sub mark_irrelevant_entries {
    my(@detail_links) = @_;
    for my $detail (@detail_links) {
	mark_irrelevant_entry($detail);
    }
}

sub mark_irrelevant_entry {
    my $detail = shift;

    my $ignore = 0;
    if ($detail->{text} =~ /^A\s*(\d+)/) {
	$ignore = 1;
    } else {
	my(@comp) = split /,\s+/, $detail->{text};
	my $Fahrstreifen = qr{(?:Fahrstreifen|Fahrspuren)};
	my $reduziert    = qr{(?:reduziert|verengt)};
	my $zahl         = qr{(?:\d|ein|einen|zwei|drei|vier)};
	my $last_index   = -1;
	if ($comp[-1] =~
	    /( Verkehrsbehinderung\s+erwartet
	    )/xs) {
	    $last_index = -2;
	}
	if ($comp[$last_index] =~
	    /( Fahrbahn\s+(teilweise\s+)?auf\s+\S+\s+$Fahrstreifen\s+verengt
	     | $Fahrstreifen\s+gesperrt
	     | Fahrbahnverengung
	     | Ampeln\s+ausgefallen
	     | Ampeln\s+in\s+Betrieb
	     | auf\s+$zahl\s+$Fahrstreifen\s+$reduziert
	    )/xs) {
	    $ignore = 1;
	}
    }
    if ($ignore) {
	push @{ $detail->{_state} }, "IGNORE";
    }
}

sub state_out {
    my $detail = shift;
    my $text = "";
    if ($detail->{_state}) {
	$text = join(", ", @{ $detail->{_state} }) . ": ";
    }
    sprintf "%-20s", $text;
}

sub get_bbd_category {
    my($info) = @_;
    my $cat = "X";
    if ($info->{_state}) {
	my $state = join " ", @{ $info->{_state} };
	if ($state =~ /^IGNORE/) {
	    $cat = "#d9c9c9"; # rötliches grau
	} elsif ($state =~ /^UNCHANGED/) {
	    $cat = "#e9c0c0"; # etwas deutlicher
	} elsif ($state =~ /^(CHANGED|NEW)/) {
	    $cat = "#008000";
	} elsif ($state =~ /^REMOVED/) {
	    $cat = "#800000";
	}
    }
    $cat;
}

__END__

cd .../bbbike/miscsrc
cp -f /tmp/vmz.yaml /tmp/oldvmz.yaml
./vmzrobot.pl -f -outputas yaml:/tmp/newvmz.yaml || exit 1
mv -f /tmp/newvmz.yaml /tmp/vmz.yaml
./vmzrobot.pl -old /tmp/oldvmz.yaml -i /tmp/vmz.yaml -diffcount || \
   (./vmzrobot.pl -old ~/cache/misc/oldvmz.yaml -i ~/cache/misc/vmz.yaml -f -outputas bbd:/tmp/vmz.bbd; \
    tkmessage -center -font "helvetica 18" -bg red -fg white "New VMZ data available" )

Einzeiler: check mark_irrelevant_entry regexps
perl -MData::Dumper -e 'require "vmzrobot.pl"; $detail->{text} = $ARGV[0]; mark_irrelevant_entry($detail); warn Dumper $detail' '...'
