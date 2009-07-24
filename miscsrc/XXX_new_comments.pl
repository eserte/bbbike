#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: XXX_new_comments.pl,v 1.4 2005/03/28 22:53:36 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package NewComments;

use strict;
use lib ("/home/e/eserte/src/bbbike/lib",
	 "/home/e/eserte/src/bbbike",
	 "/home/e/eserte/src/bbbike/data",
	);
use Strassen;
use Strassen::Kreuzungen;
use Strassen::Dataset;
use BBBikeUtil qw(m2km);
use YAML;
use Getopt::Long;

my $skip_lines;
my $use_internal_test_data;

my $s;
my $net;
my $qs;
my $qs_net;
my $kr;

sub len_fmt ($;$) {
    my $len = shift;
    my $prefix = shift;
    if ($len >= 100) {
	(defined $prefix ? "$prefix " : "") . m2km($len);
    } else {
	$len = int($len/10)*10;
	if ($len == 0) {
	    "";
	} else {
	    (defined $prefix ? "$prefix " : "") . "$len m";
	}
    }
}

my $cgi;

sub set_data {
    my($_net, $_qs_net) = @_;
    $net = $_net;
    $s = $_net->{Strassen};
    $qs_net = $_qs_net;
    $qs = $_qs_net->{Strassen};
    $kr = Kreuzungen->new(Strassen => $s, UseCache => 1);
}

sub process {
    GetOptions("skiplines=i" => \$skip_lines,
	       "internaltestdata!" => \$use_internal_test_data,
	      ) or die "usage!";

    # base net
    $s = Strassen->new("strassen");
    $net = StrassenNetz->new($s);
    $net->make_net(UseCache => 1);

    $kr = Kreuzungen->new(Strassen => $s, UseCache => 1);

    # attrib net
    $qs = MultiStrassen->new
	("qualitaet_s", "handicap_s", map { "comments_$_" } grep { $_ ne "kfzverkehr" } @Strassen::Dataset::comments_types);
    $qs_net = StrassenNetz->new($qs);
    $qs_net->make_net_cat(-usecache => 1, -net2name => 1, -multiple => 1);

    $cgi = "/home/e/eserte/src/bbbike/cgi/bbbike.cgi";
    my @logfiles = ("/home/e/eserte/www/log/radzeit.combined_log",
		"/home/e/eserte/www/log/radzeit.combined_log.0",
	       );

    use CGI;
    use URI::Escape;

    if ($use_internal_test_data) {
	for my $inx (0 .. 2) { # 0 .. 2
	    my $d = get_internal_test_data($inx);
	    process_data($d);
	    output_data($d);
	}
    } else {
	for my $logfile (@logfiles) {
	    open(LOG, "tail -r $logfile | ") or die $!;
	    while(<LOG>) {
		if ($skip_lines > 0) {
		    $skip_lines--;
		    next;
		}
		my $d = parse_line($_);
		next if !$d;
		process_data($d);
		output_data($d);
	    }
	}
    }
}

sub parse_line {
    my $line = shift;
    my $lastcoords;
    if ($line =~ m{GET\s+
		   (?:
		    /~eserte/bbbike/cgi/bbbike\.cgi |
		    /cgi-bin/bbbike\.cgi            |
		    /bbbike/cgi/bbbike\.cgi
		   )\?(.*)\s+HTTP[^"]+"\s(\d+)}x
       ) {
	my $query_string = $1;
	my $status_code = $2;
	if ($status_code =~ /^[45]/) {
	    return;
	}

	my %has;
	for my $type (qw(start via ziel)) {
	    if ($query_string =~ /${type}c=([^&; ]+)/) {
		my $coords = uri_unescape(uri_unescape($1));
		next if $coords =~ /^\s*$/;
		my $name = "$coords";
		if ($type =~ /(?:start|ziel)/) {
		    $has{$type}++;
		}
		if ($line =~ /${type}name=([^&; ]+)/) {
		    $name = uri_unescape(uri_unescape($1));
		}
		my $date = "???";
		if ($line =~ m{(\d+/[a-z]+/\d+:\d+:\d+:\d+)}i) {
		    $date = $1;
		}
	    }
	}
	if ($has{start} && $has{ziel}) {
	    my $q = CGI->new($query_string);
	    $q->param("output_as", "yaml");

	    $ENV{QUERY_STRING} = $q->query_string;
	    $ENV{REQUEST_METHOD} = "GET";

	    my $yaml = `$cgi`;

	    my $d = YAML::Load($yaml);
	    return $d;
        }
    }
}

sub process_data {
    my $d = shift;

    $kr = $kr; # XXX hack for lexical binding (because of the "eval" below)

    my $path_i = 0;

    my $get_hop_coords = sub {
	my($hop_i) = @_;
	my $end_coord = $d->{Route}[$hop_i+1]{Coord};
	my @coords;
	while(1) {
	    last if $path_i > $#{ $d->{Path} };
	    my $coord = $d->{Path}[$path_i];
	    push @coords, $coord;
	    last if $coord eq $end_coord;
	    $path_i++;
	}
	@coords;
    };

    for my $hop_i (0 .. $#{ $d->{Route} } - 1) {
	my @hop_coords = $get_hop_coords->($hop_i);

	my $process = sub {
	    my($k, $v) = @_;

	    my $begin_coord = $hop_coords[$v->[0]];
	    my $end_coord   = $hop_coords[$v->[1]];
	    my $r           = $v->[2];

	    $k =~ s/^.*?:\s*//;
	    my $main_street = $d->{Route}[$hop_i]{Strname};
	    #print $main_street . "\t";

	    if ($r->[Strassen::CAT] =~ /^CP/) {
		return ["", $k]; # point comment
	    }

	    my $ret;
	    if ($v->[0] == 0 && $v->[1] == $#hop_coords
	       ) {
		$ret = ["", "$k (*gesamt)"]; # XXX "(*gesamt)" only for debugging
	    } else {
		my $prev_street = $hop_i >= 0 ? $d->{Route}[$hop_i-1]{Strname} : undef;

		my $begin_crossing = eval { $kr->get($begin_coord) };
		$begin_crossing = [ map { Strasse::strip_bezirk($_) } @$begin_crossing ];
		$begin_crossing = [ Strasse::get_crossing_streets($main_street, $prev_street, $begin_crossing) ];
		if (@$begin_crossing == 0) {
		    undef $begin_crossing;
		} else {
		    $begin_crossing = $begin_crossing->[0];
		    $begin_crossing =~ s/^\(//;
		    $begin_crossing =~ s/\)$//;
		}
		
		my $end_crossing   = eval { $kr->get($end_coord)   };
		$end_crossing = [ map { Strasse::strip_bezirk($_) } @$end_crossing ];
		$end_crossing = [ Strasse::get_crossing_streets($main_street, $prev_street, $end_crossing) ];
		if (@$end_crossing == 0) {
		    undef $end_crossing;
		} else {
		    $end_crossing = $end_crossing->[0];
		    $end_crossing =~ s/^\(//;
		    $end_crossing =~ s/\)$//;
		}

		if ($v->[0] == 0 && defined $end_crossing) {
		    $ret = ["bis $end_crossing", $k];
		} elsif (defined $begin_crossing && $v->[1] == $#hop_coords) {
		    $ret = ["ab $begin_crossing", $k];
		} elsif (defined $begin_crossing && defined $end_crossing) {
		    $ret = ["zwischen $begin_crossing und $end_crossing", $k];
		    # alternativ: ab ... bis ...
		} elsif (!defined $begin_crossing && !defined $end_crossing) {
		    my $len1 = len_fmt get_path_part_len(\@hop_coords, 0, $v->[0]), "nach";
		    my $len2 = len_fmt get_path_part_len(\@hop_coords, $v->[0], $v->[1]), "f¸r";
		    $ret = ["$len1 $len2", $k];
		} elsif (defined $begin_crossing && !defined $end_crossing) {
		    my $len = len_fmt get_path_part_len(\@hop_coords, $v->[0], $v->[1]), "f¸r";
		    $ret = ["ab $begin_crossing $len", $k];
		} elsif (!defined $begin_crossing && defined $end_crossing) {
		    my $len = len_fmt get_path_part_len(\@hop_coords, 0, $v->[0]), "nach";
		    $ret = ["$len bis $end_crossing", $k];
		} elsif (!defined $begin_crossing && $v->[1] == $#hop_coords) {
		    my $len = len_fmt get_path_part_len(\@hop_coords, 0, $v->[0]), "nach";
		    $ret = ["$len", $k];
		} elsif ($v->[0] == 0 && !defined $end_crossing) {
		    my $len = len_fmt get_path_part_len(\@hop_coords, 0, $v->[1]), "f¸r";
		    $ret = ["$len", $k];
		} else {
		    die "Should never happen!";
		    $ret = ["$begin_crossing $end_crossing", ""];
		}
	    }
	    $ret;
	};

	my %last_attribs;
	my @new_comments;
	for my $hop_coord_i (1 .. $#hop_coords) {

	    my $valid_comment_for_this_point = sub {
		my($r) = @_;
		if ($r->[Strassen::CAT] =~ /^CP/) {
		    my $this_coord = $hop_coords[$hop_coord_i-1];
		    return 0 if $this_coord ne $r->[Strassen::COORDS][1]; # der mittlere Punkt?
		    my $index_of_point = $d->{Route}[$hop_i]{PathIndex} + $hop_coord_i - 1; # XXX correct?
		    my $ret = seq_in_seq_including_point($d->{Path}, $index_of_point,
							 $r->[Strassen::COORDS]);
		    return $ret if $ret;
		    if ($r->[Strassen::CAT] ne 'CP;') { # both directions
			my @rev = reverse @{ $r->[Strassen::COORDS] };
			$ret = seq_in_seq_including_point($d->{Path}, $index_of_point, \@rev);
		    }
		    $ret;
		} elsif ($r->[Strassen::CAT] =~ /^PI/) {
		    my $index_of_point = $d->{Route}[$hop_i]{PathIndex} + $hop_coord_i - 1; # XXX correct?
		    my $ret = seq_in_seq_including_point($d->{Path}, $index_of_point,
							 $r->[Strassen::COORDS]);
		    return $ret if $ret;
		    if ($r->[Strassen::CAT] ne 'PI;') { # both directions
			my @rev = reverse @{ $r->[Strassen::COORDS] };
			$ret = seq_in_seq_including_point($d->{Path}, $index_of_point, \@rev);
		    }
		    $ret;
		} else {
		    1;
		}
	    };

	    my $is = $qs_net->{Net2Name}{$hop_coords[$hop_coord_i-1]}{$hop_coords[$hop_coord_i]};
	    my %next_last_attribs;
	    if (defined $is) {
		for my $i (@$is) {
		    my($r) = $qs->get($i);
		    if ($valid_comment_for_this_point->($r, $d->{Route}, $hop_i, \@hop_coords, $hop_coord_i)) {
			my($name) = $r->[Strassen::NAME];
			if (exists $last_attribs{$name}) {
			    $next_last_attribs{$name} = [$last_attribs{$name}[0],
							 $hop_coord_i,
							 $r];
			} else {
			    $next_last_attribs{$name} = [$hop_coord_i-1,
							 undef,
							 $r];
			}
		    }
		}
	    }
	    while(my($k,$v) = each %last_attribs) {
		if (!exists $next_last_attribs{$k}) {
		    $v->[1] = $hop_coord_i - 1; # XXX off by one?
		    push @new_comments, $process->($k, $v);
		    delete $last_attribs{$k};
		}
	    }
	    %last_attribs = %next_last_attribs;
	}

	while(my($k,$v) = each %last_attribs) {
	    if (!defined $v->[1]) {
		$v->[1] = $#hop_coords;
	    }

	    push @new_comments, $process->($k, $v);
	}

	if (@new_comments) {
	    my %same_hop;
	    for (@new_comments) {
		my($hop_desc, $comment) = @$_;
		push @{ $same_hop{$hop_desc} }, $comment;
	    }
	    $d->{Route}[$hop_i]{Comment} =
		join("; ",
		     map {
			 my $comments = join(", ", @{ $same_hop{$_} });
			 if ($_ eq '') {
			     $comments;
			 } else {
			     $_ . ": " . $comments;
			 }
		     } keys %same_hop);
	}
    }
}

sub output_data {
    my $d = shift;

    use Text::Table;
    use Text::Wrap;
    my $tb = Text::Table->new("Etappe", "Richtung", "Straﬂe", \"|", "Gesamt", \"|", "Bemerkungen");

    $tb->load(
	      map {
		  local $Text::Wrap::columns = 30;
		  my $strname = wrap("", "", $_->{Strname}||"");
		  local $Text::Wrap::columns = 55;
		  my $comment = wrap("", "", $_->{Comment}||"");
		  [$_->{DistString},
		   $_->{DirectionString},
		   $strname,
		   $_->{TotalDistString},
		   $comment,
		  ]
	      } @{ $d->{Route} }
	     );

    print $tb->title,
	  $tb->rule( '-', '+'),
	  $tb->body;
}

sub get_path_part_len {
    my($path_ref, $from_i, $to_i) = @_;
    my $len = 0;
    for my $i ($from_i + 1 .. $to_i) {
	$len += Strassen::Util::strecke_s($path_ref->[$i-1],
					  $path_ref->[$i]);
    }
    $len;
}

sub seq_in_seq_including_point {
    my($path, $index_of_point, $small_sequence) = @_;
 DELTA:
    for my $delta (0 .. $#$small_sequence) {
	for my $i (0 .. $#$small_sequence) {
	    my $c1 = $small_sequence->[$i];
	    my $c2 = $path->[$index_of_point + $i - $delta];
	    if (defined $c1 && defined $c2 && $c1 eq $c2) {
		# nop
	    } else {
		next DELTA;
	    }
	}
	# found!
	return 1;
    }
    0;
}

sub get_internal_test_data {
    my($inx) = @_;
my @yaml;
# http://www/bbbike/cgi/bbbike.cgi?startname=Columbiadamm&startplz=10965&startc=11416%2C8283&zielname=Eschersheimer+Str.&zielplz=12099&zielc=11672%2C6737&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&pref_green=&pref_winter=&scope=;output_as=yaml
push @yaml, <<'EOF';
--- #YAML:1.0
Len: 1564
LongLatPath:
  - 13.417909,52.480122
  - 13.417843,52.478595
  - 13.418617,52.476662
  - 13.418954,52.475319
  - 13.419175,52.474453
  - 13.419447,52.473362
  - 13.419668,52.472497
  - 13.419787,52.472100
  - 13.420115,52.470900
  - 13.420374,52.469863
  - 13.420489,52.469359
  - 13.420955,52.467465
  - 13.421095,52.466807
  - 13.421206,52.466186
Path:
  - 11416,8283
  - 11415,8113
  - 11472,7899
  - 11498,7750
  - 11515,7654
  - 11536,7533
  - 11553,7437
  - 11562,7393
  - 11587,7260
  - 11607,7145
  - 11616,7089
  - 11652,6879
  - 11663,6806
  - 11672,6737
Power: {}
Route:
  - Angle: ~
    Comment: ''
    Coord: 11416,8283
    Direction: S
    DirectionString: nach S¸den
    Dist: 0
    DistString: ~
    PathIndex: 0
    Strname: Straﬂe 645
    TotalDist: 0
    TotalDistString: ''
  - Angle: 0
    Comment: Kopfsteinpflaster
    Coord: 11472,7899
    Direction: ''
    DirectionString: ''
    Dist: 391
    DistString: nach 0.39 km
    PathIndex: 2
    Strname: Oderstr.
    TotalDist: 391
    TotalDistString: 0.4 km
  - Coord: 11672,6737
    DirectionString: angekommen!
    Dist: 1173
    DistString: nach 1.17 km
    PathIndex: 13
    Strname: Eschersheimer Str.
    TotalDist: 1564
    TotalDistString: 1.6 km
Speed:
  10:
    Pref: ''
    Time: 0.157066841594913
  15:
    Pref: ''
    Time: 0.104711227729942
  20:
    Pref: 1
    Time: 0.0785334207974565
  25:
    Pref: ''
    Time: 0.0628267366379652
Trafficlights: 0

EOF

# push @yaml, <<'EOF';
# --- #YAML:1.0
# Len: 5993
# LongLatPath:
#   - 13.413655,52.488360
#   - 13.413992,52.488311
#   - 13.413921,52.487512
#   - 13.416331,52.480445
#   - 13.417909,52.480122
#   - 13.417843,52.478595
#   - 13.418617,52.476662
#   - 13.419668,52.472497
#   - 13.419787,52.472100
#   - 13.420115,52.470900
#   - 13.420374,52.469863
#   - 13.420955,52.467465
#   - 13.421095,52.466807
#   - 13.421206,52.466186
#   - 13.421425,52.465257
#   - 13.421834,52.462546
#   - 13.417839,52.460522
#   - 13.424916,52.457945
#   - 13.427275,52.456355
#   - 13.432911,52.452472
#   - 13.436206,52.448974
#   - 13.437584,52.448384
#   - 13.438741,52.448228
#   - 13.440141,52.447880
#   - 13.440936,52.447457
#   - 13.443971,52.445851
#   - 13.441486,52.445419
# Path:
#   - 11108,9194
#   - 11131,9189
#   - 11128,9100
#   - 11308,8317
#   - 11416,8283
#   - 11415,8113
#   - 11472,7899
#   - 11553,7437
#   - 11562,7393
#   - 11587,7260
#   - 11607,7145
#   - 11652,6879
#   - 11663,6806
#   - 11672,6737
#   - 11689,6634
#   - 11723,6333
#   - 11456,6103
#   - 11943,5825
#   - 12107,5651
#   - 12499,5226
#   - 12731,4841
#   - 12826,4777
#   - 12905,4761
#   - 13001,4724
#   - 13056,4678
#   - 13266,4503
#   - 13098,4452
# Power: {}
# Route:
#   - Angle: ~
#     Comment: ''
#     Coord: 11108,9194
#     Direction: W
#     DirectionString: nach W
#     Dist: 0
#     DistString: ~
#     Strname: Hasenheide
#     TotalDist: 0
#     TotalDistString: ''
#   - Angle: 70
#     Comment: Parkweg
#     Coord: 11131,9189
#     Direction: r
#     DirectionString: rechts (70∞) =>
#     Dist: 23
#     DistString: nach 0.02 km
#     Strname: '(Hasenheide)'
#     TotalDist: 23
#     TotalDistString: 0.0 km
#   - Angle: 50
#     Comment: ''
#     Coord: 11308,8317
#     Direction: l
#     DirectionString: links (50∞) in den
#     Dist: 892
#     DistString: nach 0.89 km
#     Strname: Columbiadamm
#     TotalDist: 915
#     TotalDistString: 0.9 km
#   - Angle: 70
#     Comment: ''
#     Coord: 11416,8283
#     Direction: r
#     DirectionString: rechts (70∞) in die
#     Dist: 113
#     DistString: nach 0.11 km
#     Strname: Straﬂe 645
#     TotalDist: 1028
#     TotalDistString: 1.0 km
#   - Angle: 0
#     Comment: Kopfsteinpflaster
#     Coord: 11472,7899
#     Direction: ''
#     DirectionString: ''
#     Dist: 391
#     DistString: nach 0.39 km
#     Strname: Oderstr.
#     TotalDist: 1419
#     TotalDistString: 1.4 km
#   - Angle: 0
#     Comment: ''
#     Coord: 11672,6737
#     Direction: ''
#     DirectionString: ''
#     Dist: 1175
#     DistString: nach 1.18 km
#     Strname: Eschersheimer Str.
#     TotalDist: 2594
#     TotalDistString: 2.6 km
#   - Angle: 50
#     Comment: ''
#     Coord: 11723,6333
#     Direction: r
#     DirectionString: rechts (50∞) in die
#     Dist: 406
#     DistString: nach 0.41 km
#     Strname: Gottlieb-Dunkel-Str.
#     TotalDist: 3000
#     TotalDistString: 3.0 km
#   - Angle: 100
#     Comment: ''
#     Coord: 11456,6103
#     Direction: l
#     DirectionString: links (100∞) in den
#     Dist: 352
#     DistString: nach 0.35 km
#     Strname: Tempelhofer Weg
#     TotalDist: 3352
#     TotalDistString: 3.4 km
#   - Angle: 20
#     Comment: ''
#     Coord: 12731,4841
#     Direction: ''
#     DirectionString: ''
#     Dist: 1826
#     DistString: nach 1.83 km
#     Strname: Fulhamer Allee
#     TotalDist: 5178
#     TotalDistString: 5.2 km
#   - Angle: 120
#     Comment: ''
#     Coord: 13266,4503
#     Direction: r
#     DirectionString: rechts (120∞) in die
#     Dist: 640
#     DistString: nach 0.64 km
#     Strname: Parchimer Allee
#     TotalDist: 5818
#     TotalDistString: 5.8 km
#   - Coord: 13098,4452
#     DirectionString: angekommen!
#     Dist: 175
#     DistString: nach 0.17 km
#     Strname: Parchimer Allee
#     TotalDist: 5993
#     TotalDistString: 6.0 km
# Speed:
#   10:
#     Pref: ''
#     Time: 0.600582223743283
#   15:
#     Pref: ''
#     Time: 0.400388149162189
#   20:
#     Pref: 1
#     Time: 0.300291111871641
#   25:
#     Pref: ''
#     Time: 0.240232889497313
# Trafficlights: 5

# EOF

# push @yaml, <<'EOF';
# --- #YAML:1.0
# Len: 5993
# LongLatPath:
#   - 13.441486,52.445419
#   - 13.443971,52.445851
#   - 13.440936,52.447457
#   - 13.440141,52.447880
#   - 13.438741,52.448228
#   - 13.437584,52.448384
#   - 13.436206,52.448974
#   - 13.432911,52.452472
#   - 13.427275,52.456355
#   - 13.424916,52.457945
#   - 13.417839,52.460522
#   - 13.421834,52.462546
#   - 13.421425,52.465257
#   - 13.421206,52.466186
#   - 13.421095,52.466807
#   - 13.420955,52.467465
#   - 13.420374,52.469863
#   - 13.420115,52.470900
#   - 13.419787,52.472100
#   - 13.419668,52.472497
#   - 13.418617,52.476662
#   - 13.417843,52.478595
#   - 13.417909,52.480122
#   - 13.416331,52.480445
#   - 13.413921,52.487512
#   - 13.413992,52.488311
#   - 13.413655,52.488360
# Path:
#   - 13098,4452
#   - 13266,4503
#   - 13056,4678
#   - 13001,4724
#   - 12905,4761
#   - 12826,4777
#   - 12731,4841
#   - 12499,5226
#   - 12107,5651
#   - 11943,5825
#   - 11456,6103
#   - 11723,6333
#   - 11689,6634
#   - 11672,6737
#   - 11663,6806
#   - 11652,6879
#   - 11607,7145
#   - 11587,7260
#   - 11562,7393
#   - 11553,7437
#   - 11472,7899
#   - 11415,8113
#   - 11416,8283
#   - 11308,8317
#   - 11128,9100
#   - 11131,9189
#   - 11108,9194
# Power: {}
# Route:
#   - Angle: ~
#     Comment: ''
#     Coord: 13098,4452
#     Direction: W
#     DirectionString: nach W
#     Dist: 0
#     DistString: ~
#     Strname: Parchimer Allee
#     TotalDist: 0
#     TotalDistString: ''
#   - Angle: 120
#     Comment: ''
#     Coord: 13266,4503
#     Direction: l
#     DirectionString: links (120∞) in die
#     Dist: 175
#     DistString: nach 0.17 km
#     Strname: Fulhamer Allee
#     TotalDist: 175
#     TotalDistString: 0.2 km
#   - Angle: 20
#     Comment: ''
#     Coord: 12731,4841
#     Direction: ''
#     DirectionString: ''
#     Dist: 640
#     DistString: nach 0.64 km
#     Strname: Tempelhofer Weg
#     TotalDist: 815
#     TotalDistString: 0.8 km
#   - Angle: 100
#     Comment: ''
#     Coord: 11456,6103
#     Direction: r
#     DirectionString: rechts (100∞) in die
#     Dist: 1826
#     DistString: nach 1.83 km
#     Strname: Gottlieb-Dunkel-Str.
#     TotalDist: 2641
#     TotalDistString: 2.6 km
#   - Angle: 50
#     Comment: ''
#     Coord: 11723,6333
#     Direction: l
#     DirectionString: links (50∞) in die
#     Dist: 352
#     DistString: nach 0.35 km
#     Strname: Eschersheimer Str.
#     TotalDist: 2993
#     TotalDistString: 3.0 km
#   - Angle: 0
#     Comment: Kopfsteinpflaster
#     Coord: 11672,6737
#     Direction: ''
#     DirectionString: ''
#     Dist: 406
#     DistString: nach 0.41 km
#     Strname: Oderstr.
#     TotalDist: 3399
#     TotalDistString: 3.4 km
#   - Angle: 0
#     Comment: ''
#     Coord: 11472,7899
#     Direction: ''
#     DirectionString: ''
#     Dist: 1175
#     DistString: nach 1.18 km
#     Strname: Straﬂe 645
#     TotalDist: 4574
#     TotalDistString: 4.6 km
#   - Angle: 70
#     Comment: ''
#     Coord: 11416,8283
#     Direction: l
#     DirectionString: links (70∞) in den
#     Dist: 391
#     DistString: nach 0.39 km
#     Strname: Columbiadamm
#     TotalDist: 4965
#     TotalDistString: 5.0 km
#   - Angle: 50
#     Comment: Parkweg
#     Coord: 11308,8317
#     Direction: r
#     DirectionString: rechts (50∞) =>
#     Dist: 113
#     DistString: nach 0.11 km
#     Strname: '(Hasenheide)'
#     TotalDist: 5078
#     TotalDistString: 5.1 km
#   - Angle: 70
#     Comment: ''
#     Coord: 11131,9189
#     Direction: l
#     DirectionString: links (70∞) =>
#     Dist: 892
#     DistString: nach 0.89 km
#     Strname: Hasenheide
#     TotalDist: 5970
#     TotalDistString: 6.0 km
#   - Coord: 11108,9194
#     DirectionString: angekommen!
#     Dist: 23
#     DistString: nach 0.02 km
#     Strname: Fichtestr. (Kreuzberg)
#     TotalDist: 5993
#     TotalDistString: 6.0 km
# Speed:
#   10:
#     Pref: ''
#     Time: 0.600582223743283
#   15:
#     Pref: ''
#     Time: 0.400388149162189
#   20:
#     Pref: 1
#     Time: 0.300291111871642
#   25:
#     Pref: ''
#     Time: 0.240232889497313
# Trafficlights: 5

# EOF

# GET 'http://www/bbbike/cgi/bbbike.cgi?startname=Frankfurter+Allee&startplz=10247&startc=13792%2C12292&zielname=Frankfurter+Allee&zielplz=10247&zielc=15349%2C12073&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&pref_green=&pref_winter=&scope=;output_as=yaml'
push @yaml, <<'EOF';
--- #YAML:1.0
Len: 1566
LongLatPath:
  - 13.454060,52.515774
  - 13.455424,52.515642
  - 13.460160,52.515195
  - 13.461376,52.515047
  - 13.463472,52.514808
  - 13.464264,52.514737
  - 13.464777,52.514677
  - 13.466213,52.514527
  - 13.467401,52.514415
  - 13.469425,52.514240
  - 13.470584,52.514137
  - 13.471684,52.514044
  - 13.473283,52.513901
  - 13.476890,52.513556
Path:
  - 13792,12292
  - 13885,12279
  - 14208,12235
  - 14291,12220
  - 14434,12196
  - 14488,12189
  - 14523,12183
  - 14621,12168
  - 14702,12157
  - 14840,12140
  - 14919,12130
  - 14994,12121
  - 15103,12107
  - 15349,12073
Power: {}
Route:
  - Angle: ~
    Comment: RR8
    Coord: 13792,12292
    Direction: E
    DirectionString: nach Osten
    Dist: 0
    DistString: ~
    PathIndex: 0
    Strname: Frankfurter Allee
    TotalDist: 0
    TotalDistString: ''
  - Coord: 15349,12073
    DirectionString: angekommen!
    Dist: 1566
    DistString: nach 1.57 km
    PathIndex: 13
    Strname: Frankfurter Allee
    TotalDist: 1566
    TotalDistString: 1.6 km
Speed:
  10:
    Pref: ''
    Time: 0.15725245647252
  15:
    Pref: ''
    Time: 0.10483497098168
  20:
    Pref: 1
    Time: 0.0786262282362601
  25:
    Pref: ''
    Time: 0.0629009825890081
Trafficlights: 6

EOF

# GET 'http://www/bbbike/cgi/bbbike.cgi?startname=Frankfurter+Allee&startplz=10247&startc=14208%2C12235&zielname=Kreutzigerstr.&zielplz=10247&zielc=14161%2C11930&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&pref_green=&pref_winter=&scope=;output_as=yaml'
push @yaml, <<'EOF';
--- #YAML:1.0
Len: 402
LongLatPath:
  - 13.460160,52.515195
  - 13.461376,52.515047
  - 13.461279,52.514778
  - 13.459377,52.512461
Path:
  - 14208,12235
  - 14291,12220
  - 14285,12190
  - 14161,11930
Power: {}
Route:
  - Angle: ~
    Comment: ''
    Coord: 14208,12235
    Direction: E
    DirectionString: nach Osten
    Dist: 0
    DistString: ~
    PathIndex: 0
    Strname: Frankfurter Allee
    TotalDist: 0
    TotalDistString: ''
  - Angle: 90
    Comment: Einfahrt in Hausdurchgang
    Coord: 14291,12220
    Direction: r
    DirectionString: rechts (90∞) in die
    Dist: 84
    DistString: nach 0.08 km
    PathIndex: 1
    Strname: '((Frankfurter Allee -) Kreutzigerstr.)'
    TotalDist: 84
    TotalDistString: 0.1 km
  - Angle: 10
    Comment: ''
    Coord: 14285,12190
    Direction: ''
    DirectionString: ''
    Dist: 30
    DistString: nach 0.03 km
    PathIndex: 2
    Strname: Kreutzigerstr.
    TotalDist: 114
    TotalDistString: 0.1 km
  - Coord: 14161,11930
    DirectionString: angekommen!
    Dist: 288
    DistString: nach 0.29 km
    PathIndex: 3
    Strname: Kreutzigerstr.
    TotalDist: 402
    TotalDistString: 0.4 km
Speed:
  10:
    Pref: ''
    Time: 0.0402994198815616
  15:
    Pref: ''
    Time: 0.0268662799210411
  20:
    Pref: 1
    Time: 0.0201497099407808
  25:
    Pref: ''
    Time: 0.0161197679526246
Trafficlights: 1

EOF

$inx = 0 if !defined $inx;
my $d = YAML::Load($yaml[$inx]);

$d;
}

return 1 if caller();

process();

__END__



"ab Treskowallee f¸r 2.2 km: Parkweg, OK; R1 (*); ab (Wuhlheide/FEZ):
Fuﬂg‰nger " => sortieren, und zwar: Gesamtstrecken zuerst, und dann
nach Startpunkt sortiert

"bis (Wuhlewanderweg, ˆstliches Ufer): bereits an der Ampel Kˆpenicker
Allee die Straﬂenseite wechseln (Straﬂenbahn auf Mittelstreifen); R1
(*); ab (Wuhlewanderweg, ˆstliches Ufer): zun‰chst linken Gehweg
benutzen" => f¸r PI und ‰hnliches keine Start/Endpunkte verwenden,
Sortierung siehe oben

"bis Schreiberhauer Str.: sehr guter Asphalt; ab Schreiberhauer Str.:
m‰ﬂiges Kopfsteinpflaster": wie bislang Q0 und q0 ignorieren

"zwischen Sonnenallee und Weigandufer" (Innstr) => was ist hier
passiert? (verbessert!)

"nach 0.1 km bis Tempelhofer Ufer: reger Fuﬂg‰ngerverkehr"
(Bl¸cherplatz) => besser w‰re es hier, wenn man den Gehwegbereich
explizit angeben w¸rde. Oder das Kaufhaus an der Stelle

"ab Hallesches Ufer f¸r 0.0 km: reger Fuﬂg‰ngerverkehr" => hmmm, hier
vielleicht die Meterangaben anzeigen oder "f¸r kurze Strecke"?

"ab Goethestr.: gutes Kopfsteinpflaster; ab Goethestr.: Mi und Sa
Wochenmarkt, Behinderungen mˆglich" => kann das hier zusammengefasst
werden?

ab Prinzregentenstr. f¸r 0.4 km: zum ‹berqueren der Bundesallee Ampel
an der Hildegarstr. (links) benutzen => "f¸r 0.4 km" ist hier albern

Hauptstr | bis (Am Rummelsburger See): wegen Straﬂenbahn so fr¸h wie
mˆglich auf die linke Gehwegseite wechseln; ab (Am Rummelsburger See)
f¸r 0.2 km: wegen Straﬂenbahn zun‰chst auf der linken Gehwegseite
weiterfahren => ups... solche Kommentare (PI;) nur anzeigen, wenn die
kompletter Strecke befahren wird!!!

Mangerstr. | Kopfsteinpflaster; Kopfsteinpflaster, Ausweichen auf
Uferweg mˆglich => geht es hier (landstrassen) mit der
Kreuzungserkennung nicht? (wahrscheinlich, siehe Sourcecode)

nach 0.0 km f¸r 0.1 km => optimieren: "nach 0.0 km" weglassen, "f¸r
0.0 km" in "f¸r eine kurze Strecke" ¸bersetzen

nach 0.0 km f¸r 0.0 km: rechts des Neuen Sees halten => jaja...

Gleimstr. | ab Swinem¸nder Str. f¸r 0.2 km: Kopfsteinpflaster (noch);
nach 0.2 km bis Schwedter Str.: Kopfsteinpflaster (noch) => hier hat
die Zusammenfassung nicht funktioniert, da einmal "Gleimtunnel" und
einmal "Gleimstr." vor dem Doppelpunkt in qualitaet_s-orig steht.
Ergo: zuerst abschneiden, dann zusammenfassen

ab Oberwallstr. f¸r 0.2 km: m‰ﬂiger Asphalt => statt "0.2 km" kˆnnte
man vielleicht "200 m" schreiben, ist k¸rzer und weniger pseudo-genau
(evtl. vielleicht auf 50er-Meter runden, um nicht ganz so ungenau zu
sein...) (lieber nicht, da ich in der Etappenbeschreibung auf 10 Meter
genau bin)

Klemkestr. | zwischen (An der Nordbahn) und (An der Nordbahn):
Berliner Mauer-Radweg => obskur, aber so ist meine Benamung der
Querstraﬂen... -> evtl. durch zus‰tzliche
Himmelsrichtungsbezeichnungen auflˆsen

Kurios, aber schwer lˆsbar:
nach 0.41 km rechts (90∞) in die Leipziger Str.|5.4km|zwischen Jerusalemer Str. und Jerusalemer Str.:      
                                               |     |zun‰chst linken Gehweg benutzen (schlecht
					       |     |passierbarer Mittelstreifen)
-> auch hier kˆnnte man Himmelsrichtungen verwenden:
"zwischen Jerusalemer Str. (nˆrdlicher Abschnitt) und Jerusalemer Str. (s¸dlicher Abschnitt) ..."

Viele Eintr‰ge in bbbike_temp_blockings.pl enthalten schon die Angabe
"zwischen ... und ... ". Das sollte gematcht werden und in diesem Fall
beibehalten werden.

Manchmal sollte bei Punkt-Kommentaren die Kreuzung am Punkt
gekennzeichnet werden, manchmal aber nicht. Mˆgliches Beispiel:
Frankfurter Allee - Kreutzigerstr.

DONE:

"ab (Lichtensteinallee - Tiergartenufer) Parkweg, Fuﬂg‰nger" => Klammern weg? ja! DONE
"nach 657 m f¸r 43 m Fuﬂg‰nger" => gruselig! DONE: Doppelpunkt, ungenauere Meterangaben
"ab Luckauer Str. Berliner Mauer-Radweg" => hier w‰re ein Doppelpunkt besser DONE
"bis Dorotheenstr. R1" => hier auch DONE
