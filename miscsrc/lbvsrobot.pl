#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: lbvsrobot.pl,v 1.3 2004/02/14 16:12:54 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use HTML::LinkExtor;
#use HTML::Parser;
use HTML::TreeBuilder;
use HTTP::Cookies;
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
my $quiet;
my $force;
my $state_id;
my $state_id_url = "http://www.lbvs.brandenburg.de/SCRIPTS/hsrun.exe/Single/BIS1/MapXtreme.htx;start=HS_Info";
my $base_url = "http://194.76.232.138/SCRIPTS/hsrun.exe/Single/BIS1/StateId/%STATE_ID%/HAHTpage";
my $all_listing_url = "$base_url/SucheStrasse?txtStr="; # . Anfangsbuchstabe
my $str_listing_url = "$base_url/ZeigeStrasse?lstStr="; # . Streetname
my $detail_url      = "$base_url/HS_BauBlatt?BaustRowNr="; # . Rownumber
my $map_url         = "$base_url/ZeigeBaustelle?baust=" ; # . Rownumber
my @output_as;

if (!GetOptions("test" => \$test,
		"i|inputfile=s" => \$inputfile,
		"old|oldffile=s" => \$oldfile,
		"diffcount" => \$do_diffcount,
		"q" => \$quiet,
		"f" => \$force,
		'outputas=s@' => \@output_as,
	       )) {
    die <<EOF;
usage: $0 [-test] [-i|-inputfile file] [-old|-oldfile file]
          [-diffcount] [-q] [-outputas type] ...

Multiple -outputas optione are possible, default is "text". -outputas
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
    $state_id_url = "http://localhost:8080/~slavenr/lbvs1.html";
}

my $ua;
my @details;
if ($inputfile) {
    require YAML;
    my $ref = YAML::LoadFile($inputfile);
    @details = @$ref;
} else {
    $ua = LWP::UserAgent->new(cookie_jar => HTTP::Cookies->new);
    #$ua->agent(...);
    print STDERR "Get state id..." if !$quiet;
    get_state_id();
    print STDERR " OK\n" if !$quiet;
    if (0) {
	print STDERR "Get street names..." if !$quiet;
	my @street_names = get_street_names();
	print STDERR " OK\n" if !$quiet;
	{
	    my $i = 0;
	    for my $street_name (@street_names) {
		printf STDERR "%d/%d (%d%%)   \r", ($i+1), scalar(@street_names), $i/$#street_names*100 if !$quiet;
		my @this_street_details = get_street_details($street_name);
		push @details, @this_street_details;
		$i++;
	    }
	}
    } else {
	@details = get_street_details2();
    }
}

if ($oldfile) {
    @details = diff();
    if ($do_diffcount) {
	my $diffcount = grep { $_->{text} !~ /^UNCHANGED/ } @details;
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
    print $fh join($sep, map { $_->{text} } @details);
}

if (exists $output_as{'bbd'}) {
    my $fh = file_or_stdout($output_as{bbd});
    require Karte;
    Karte::preload(qw(Standard Polar));
    for my $info (@details) {
	(my $text = $info->{text}) =~ s/[\n\t]+/ /g;
	my($x1, $y1) = map { int } $Karte::Polar::obj->map2standard
	    ($info->{x}, $info->{y});
	print $fh "$text\tX $x1,$y1\n";
    }
}

if (exists $output_as{'dump'}) {
    my $fh = file_or_stdout($output_as{'dump'});
    require Data::Dumper;
    print $fh (Data::Dumper->new([\@details], ['lbvs'])->Dump);
}

if (exists $output_as{'yaml'}) {
    my $fh = file_or_stdout($output_as{'yaml'});
    require YAML;
    print $fh (YAML::Dump(\@details));
}

print STDERR "\n" if !$quiet;

sub get_state_id {
    warn "GET URL $state_id_url...\n" if !$quiet;
    my $resp = $ua->get($state_id_url);
    if (!$resp->is_success) {
	die "Can't fetch $state_id_url: " . $resp->content;
    }
    my $p = HTML::LinkExtor->new
	(sub {
	     my($tag, %attr) = @_;
	     if ($tag =~ /^a$/i) {
		 my $href = uri_unescape($attr{href});
		 if ($href =~ m{StateId/([^/]+)/}) {
		     $state_id = $1;
		     return;
		 }
	     }
	 }, $state_id_url);
    $p->parse($resp->content);
    if (!defined $state_id) {
	die "Cannot find state id";
    } elsif (!$quiet) {
	warn "Found state id $state_id.\n";
    }
}

sub get_street_details2 {
    my @details;
    for my $ch ('L', 'B', 'K') {
	my $url = get_url('all_listing');
	$url .= $ch if !$test;
	warn "Get URL $url...\n" if !$quiet;
	my $resp = $ua->get($url);
	if (!$resp->is_success) {
	    warn "Can't fetch $url: " . $resp->content;
	    next;
	}
	push @details, parse_details_content($resp->content);
    }
    @details;
}

sub get_street_names {
    my @street_names;
    for my $ch ('L', 'B', 'K') {
	my $url = get_url('all_listing');
	$url .= $ch if !$test;
	warn "Get URL $url...\n" if !$quiet;
	my $resp = $ua->get($url);
	if (!$resp->is_success) {
	    warn "Can't fetch $url: " . $resp->content;
	    next;
	}
	push @street_names, parse_street_list($resp->content, $url);
    }
    if (!@street_names) {
	warn "No street names in listing page found!\n";
    }
    @street_names;
}

sub get_street_details {
    my($street_name) = @_;
#     if ($test) {
# 	warn "Would try $street_name";
# 	$qs = "";
#     } else {
# 	$qs = "?$qs";
#     }
    my $url = get_url("str_listing");
    $url .= $street_name if !$test;
    warn "Get URL $url...\n" if !$quiet;
    my $resp = $ua->get($url);
    if (!$resp->is_success) {
	warn "Can't fetch $url: " . $resp->content;
	return;
    }
    parse_details_content($resp->content);
}

sub parse_street_list {
    my($content, $url) = @_;
    my @street_names;
    my $p = HTML::LinkExtor->new
	(sub {
	     my($tag, %attr) = @_;
	     if ($tag =~ /^a$/i) {
		 my $href = uri_unescape($attr{href});
		 if ($href =~ /ZeigeStrasse?lstStr=(\S+)/) {
		     push @street_names, $1;
		 }
	     }
	 }, $url);
    $p->parse($content);
    @street_names;
}

sub parse_details_content {
    my $content = shift;
    my %details;
    my $p = HTML::TreeBuilder->new;
    $p->parse($content);
    $p->eof;
    () = $p->look_down(
	'_tag', 'a',
	sub {
	    my $href = $_[0]->attr('href');
	    return unless defined $href && $href =~ /HS_BauBlatt\?BaustRowNr=(\d+)/;
	    my $row_number = $1;

	    my $tr = $_[0]->parent->parent;
	    my $tr_pos = $tr->pos;
	    my $text = HTML::FormatText->new->format($tr);
	    $text =~ s/^\s*Detail-Info\s*Karte\s*//;
	    $tr = $tr->right;
	    $text .= "\n" . HTML::FormatText->new->format($tr);

	    $details{$row_number} = { row => $row_number,
				      text => $text};

	    my $this_map_url = get_url("map");
	    $this_map_url .= $row_number if !$test;
	    warn "Get URL $this_map_url...\n" if !$quiet;
	    my $resp_map = $ua->get($this_map_url);
	    if (!$resp_map->is_success) {
		warn "Can't fetch $this_map_url: " . $resp_map->content;
		return;
	    }

	    my $p2 = HTML::TreeBuilder->new;
	    $p2->parse($resp_map->content);
	    $p2->eof;
	    () = $p2->look_down(
	        '_tag', 'input',
		sub {
		    return if $_[0]->attr('type') !~ /^hidden$/i;
		    if ($_[0]->attr('name') =~ /OldCenter(.)/) {
			my $xy = lc $1;
			my $val = $_[0]->attr('value');
			$val =~ s/,/./g; # german => english
			$details{$row_number}{$xy} = $val;
		    }
		});
	});
    values %details;
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

sub get_url {
    my $type = shift;
    my $url;
    if ($type eq 'all_listing') {
	if ($test) { return "http://localhost:8080/~slavenr/lbvs2.html" }
	$url = $all_listing_url;
    } elsif ($type eq 'str_listing') {
	if ($test) { die }
	$url = $str_listing_url;
    } elsif ($type eq 'detail') {
	if ($test) { die }
	$url = $detail_url;
    } elsif ($type eq 'map') {
	if ($test) { return "http://localhost:8080/~slavenr/lbvs3.html" }
	$url = $map_url;
    } else {
	die "Invalid argument $type";
    }
    $url =~ s/%STATE_ID%/$state_id/g;
    $url;
}

sub diff {
    my $ref = YAML::LoadFile($oldfile);
    #my $diffcol = "row";
    my $diffcol = "text";
    my $infocol = "text";
    my @old_details = @$ref;
    my %details     = map {($_->{$diffcol} => $_)} @details;
    my %old_details = map {($_->{$diffcol} => $_)} @old_details;
    my @diff_details;
    for my $orig_detail (@details) {
	my $detail = dclone $orig_detail;
	my $old_detail = $old_details{$detail->{$diffcol}};
	my $state;
	my $info = "";
	if (!defined $old_detail) {
	    $state = "NEW:       ";
	} else {
	    my $c1 = dclone $detail;
	    my $c2 = dclone $old_detail;
	    delete $c1->{"row"};
	    delete $c2->{"row"};
	    if (Compare($c1, $c2) == 0) {
		$state = "CHANGED:   ";
		if ($detail->{$infocol} eq $old_detail->{$infocol}) {
		    $info = " (coord change)";
		} else {
		    # XXX will never happen!!!
		    $info = " (old text was: $old_detail->{$infocol})";
		}
	    } else {
		$state = "UNCHANGED: ";
	    }
	}
	$detail->{text} = "$state$detail->{text}$info";
	push @diff_details, $detail;
    }
    for my $orig_detail (@old_details) {
	my $detail = dclone $orig_detail;
	if (!exists $details{$detail->{$diffcol}}) {
	    $detail->{text} = "REMOVED:    $detail->{$infocol}";
	    push @diff_details, $detail;
	}
    }
    @diff_details;
}

__END__

# cd .../bbbike/miscsrc
# cp -f /tmp/vmz.yaml /tmp/oldvmz.yaml
# ./vmzrobot.pl -f -outputas yaml:/tmp/newvmz.yaml || exit 1
# mv -f /tmp/newvmz.yaml /tmp/vmz.yaml
# ./vmzrobot.pl -old /tmp/oldvmz.yaml -i /tmp/vmz.yaml -diffcount || \
#    (./vmzrobot.pl -old /tmp/oldvmz.yaml -i /tmp/vmz.yaml -f -outputas bbd:/tmp/vmz.bbd; \
#     tkmessage -center -font "helvetica 18" -bg red -fg white "New VMZ data available" )
