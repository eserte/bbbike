# -*- perl -*-

#
# $Id: Telefonbuch99.pm,v 1.10 2001/07/04 11:38:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Telefonbuch99;
use Karte::T99;
use strict;
no locale; # too buggy!
use vars qw($VERBOSE $strdbbasefile $teldbbasefile $dbroot);
$VERBOSE = 0 if !defined $VERBOSE;

use constant str_abs_start_  => 0x1c1f;     # start of data
use constant str_abs_end_    => 0x0199F4F0; # end of data
use constant str_bufsize_    => 2048;
use constant str_datastart_  => 32;         # start of record data

use constant tel_abs_start_  => 0x00002C1F; # start of data
use constant tel_abs_end_    => 0x0C202BBD; # end of data
use constant tel_bufsize_    => 4096;
use constant tel_datastart_  => 65;

$strdbbasefile = "hhstr";
$teldbbasefile = "wshh";

sub strdbbasefile { $strdbbasefile }
sub teldbbasefile { $teldbbasefile }

sub dbroot { $dbroot }
sub set_dbroot {
    my $class = shift;
    my $new_dbroot = shift;
    my $code = "\$" . $class . '::dbroot = $new_dbroot';
    eval $code;
    die "$code: $@" if $@;
}

sub str_abs_start { shift->str_abs_start_ }
sub str_abs_end   { shift->str_abs_end_   }
sub str_bufsize   { shift->str_bufsize_   }
sub str_datastart { shift->str_datastart_ }

sub tel_abs_start { shift->tel_abs_start_ }
sub tel_abs_end   { shift->tel_abs_end_   }
sub tel_bufsize   { shift->tel_bufsize_   }
sub tel_datastart { shift->tel_datastart_ }

sub database { 99 }

# Argumente:
#  $tel: Pseudo-Klasse
#  $searchstr: zu suchende Straße
#  $searchhnr: zu suchende Hausnummer (optional)
#  $searchort: zu suchender Ort/PLZ (optional) (NYI)
#              bei 98 PLZ
#              bei 99 Ort (B-Bezirk)
# Rückgabe: eine Referenz auf ein Array von Items, jeweils im
#  [Straße, Hausnummer, undef, Ort, X, Y]-Format
sub search_street_hnr {
    my($tel, $searchstr, $searchhnr, $searchort) = @_;

    if (defined $searchhnr) {
	$searchhnr = lc $searchhnr;
    }
    if (defined $searchort) {
	# XXX ich habe kein locale, benutze aber lc... in Berlin
	# kein Problem, weil kein Bezirk mit einem Umlaut
	# anfängt --- hoffentlich
	$searchort = lc $searchort;
    }

    $searchstr =~ s/\s+$//;
    # "Str." normieren
    $searchstr =~ s/str\.$/straße/;
    $searchstr =~ s/Str\.$/Straße/;
    # "St." normieren ... hmmm XXX
    #$searchstr =~ s/\bSt\./Saint./;

    $tel->search_common('str', $searchstr, $searchhnr, $searchort);
}

# Wie search_street_hnr, nur wird die *nächstliegende* Hausnummer gesucht,
# nicht die genaue.
sub search_street_nearest_hnr {
    my($tel, $searchstr, $searchhnr, $searchort) = @_;
    my $res = search_street_hnr($tel, $searchstr, undef, $searchort);
    if ($res && @$res) {
	# nach Hausnummern sortieren und suchen
	my $last;
	$searchhnr = int($searchhnr);
	local $^W = undef; # mask non-numeric warnings...
	foreach my $r (sort { $a->[1] <=> $b->[1] } @$res) {
	    if ($r->[1] >= $searchhnr &&
		$last &&
		$last->[1] <= $searchhnr) {
		my $diff1 = $searchhnr - $last->[1];
		my $diff2 = $r->[1] - $searchhnr;
		if ($diff1 > $diff2) {
		    return [$r];
		} else {
		    return [$last];
		}
	    }
	    $last = $r;
	}
    }
    [];
}

sub search_name {
    my($tel, $nname, $vname) = @_;
    $nname = lc $nname;
    $vname = "" if !defined $vname;
    $vname = lc $vname;

    $tel->search_common('tel', $nname, $vname);
}

sub search_common {
    my($tel, $type, $search1, $search2, $search3, %args) = @_;

    my $fakesearch = create_fakesearch($search1);

    my $dbfile = $tel->dbroot . "/" . ($type eq 'str'
				       ? $tel->strdbbasefile
				       : $tel->teldbbasefile);
    open(DB, $dbfile) or die "$dbfile konnte nicht geöffnet werden: $!";
    binmode DB;

    my $start = ($type eq 'str' ? $tel->str_abs_start : $tel->tel_abs_start);
    my $end   = ($type eq 'str' ? $tel->str_abs_end   : $tel->tel_abs_end);
    my $bufsize = ($type eq 'str' ? $tel->str_bufsize : $tel->tel_bufsize);

    my $do_linear = 0;
    # $recsig scheint zum Feststellen eines Datensatzes alleine
    # nicht ausreichend zu sein. Deshalb wird in den Datensätzen überprüft,
    # ob Byte 3 von reclen == 0 ist (die Datensätze sind definitiv nicht
    # größer als 65535 Bytes)
    my $recsig = "\xfa\xfa";
    my($buf, $reclen, @data, $datastr);
    my($pure_str, $ort);

    my $datastart = ($type eq 'str' ? $tel->str_datastart : $tel->tel_datastart);

    my $read_record = sub {
	$reclen = unpack("V", substr($buf, 0, 4));
	if ($reclen > $bufsize/2) {
	    warn "Reclen probably too big: $reclen while searching $search1 $search2 $search3\n";
	    printf STDERR "Buf is <$buf>\n";
	    die;
	}
	$datastr = substr($buf, $datastart, $reclen-$datastart-2);
	($data[0], $data[1]) = split(/\x0/, $datastr);
	if ($data[0] =~ /^(.*)\s+\((.*)\)\s*$/) {
	    ($pure_str, $ort) = ($1, $2);
	} else {
	    ($pure_str, $ort) = ($data[0], "");
	}
	if ($VERBOSE) {
	    print STDERR
	      ($do_linear ? "L" : "B") . " ", join(" ", @data), "\n";
	}
    };

    my $create_res_item;
    if ($type eq 'str') {
	$create_res_item = sub {
	    my $origx = unpack("V", substr($buf, 24, 4));
	    my $origy = unpack("V", substr($buf, 28, 4));
	    my($x, $y) = convert_xy($origx, $origy);
	    print STDERR "FOUND: $pure_str $data[1] $ort $origx $origy\n"
	      if $VERBOSE;
	    [$pure_str, $data[1], undef, $ort, $x, $y];
	};
    } else {
	$create_res_item = sub {
	    my $origx = unpack("V", substr($buf, 55, 4));
	    my $origy = unpack("V", substr($buf, 59, 4));
	    my($x, $y) = convert_xy($origx, $origy);
	    my @whole_data = split(/\x0/, $datastr);
	    print STDERR "FOUND: $data[0] $data[1] $origx $origy\n"
	      if $VERBOSE;
	    [$data[0], $data[1], undef, $x, $y, @whole_data];
	}
    }

    my $new_middle;
    my %middle_seen;
    if ($args{-linearonly}) {
	$do_linear = 1;
	$new_middle = $start;
    } else {
	while(1) {
	    my $middle = int(($end-$start)/2+$start);
	    seek(DB, $middle, 0);
	    read(DB, $buf, $bufsize);
	    if ($buf =~ /(.*?)$recsig(..\0.*)/so) {
		$buf = $2;
		$new_middle = $middle + length($1);
		if (exists $middle_seen{$new_middle}) {
		    $do_linear = 1;
		    last;
		}
		$middle_seen{$new_middle}++;

		$read_record->();

		if (_sort_cmp($data[0], $fakesearch) < 1) {
		    $start = $middle;
		} else {
		    $end = $middle;
		}
	    } else {
		die "Can't find signature at seek $middle";
	    }
	}
    }

    my @res;
    if ($do_linear) {
	while(1) {
	    seek DB, $new_middle, 0;
	    read DB, $buf, $bufsize;
	    if ($buf =~ /$recsig(..\0.*)/so) {
		$buf = $1;
		$read_record->();
		if (_sort_regex(lc($pure_str), $search1)) {
		    my $useit = 1;
		    if (defined $search2 && $search2 ne "") {
			if ($search2 ne lc($data[1])) {
			    $useit = 0;
			}
		    }
		    if ($useit && defined $search3 && $search3 ne "") {
			if (!_sort_regex(lc($ort), $search3)) {
			    $useit = 0;
			}
		    }
		    if ($useit) {
			push @res, $create_res_item->();
		    }
		} elsif (_sort_cmp($pure_str, $search1) > 0) {
		    print STDERR "END OF SEARCH!\n" if $VERBOSE;
		    last;
		}
	    }
	    $new_middle = $new_middle + $reclen;
	}
    }

    \@res;
}

sub _kill_umlauts {
    $_[0] =~ tr/äöüÄÖÜ/aouAOU/;
    $_[0] =~ s/ß/ss/g;
}

# Die Reihenfolge in der DB sieht ungefähr so aus:
# * Groß- und Kleinschreibung wird ignoriert
# * ä,ö,ü wird zu a,o.u gemappt
# * ß wird zu ss gemappt
sub _sort_cmp {
    my($a, $b) = @_;
    _kill_umlauts($a); $a = lc $a;
    _kill_umlauts($b); $b = lc $b;
#    warn "$a <-> $b = " . ($a cmp $b);
    $a cmp $b;
}

sub _sort_regex {
    my($a, $b) = @_;
    _kill_umlauts($a);
    _kill_umlauts($b);
    $a =~ /^\Q$b\E/i;
}

sub create_fakesearch {
    my $search = shift;
    my $fakesearch = $search;
    _kill_umlauts($fakesearch);
    $fakesearch = lc $fakesearch;
    my $ch = substr($fakesearch, length($fakesearch)-1, 1);
    $ch = chr(ord($ch)-1);
    $fakesearch =~ s/.$/$ch/;
    $fakesearch .= ("\xff" x 10);
    warn $fakesearch if $VERBOSE;
    $fakesearch;
}

sub convert_xy {
    my($x, $y) = @_;
    $Karte::T99::obj->map2standard($x, $y);
}

1;

__END__
