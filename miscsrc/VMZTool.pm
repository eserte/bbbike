# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package VMZTool;

use strict;
our $VERSION = '0.01';

use LWP::UserAgent ();
use URI ();
use URI::QueryParam ();
use XML::LibXML ();

use Cwd qw(abs_path);
use File::Basename qw(dirname);
my $bbbike_root;
BEGIN {
    $bbbike_root = dirname(dirname(abs_path(__FILE__)));
    require lib;
    lib->import($bbbike_root);
}

use Karte::Polar;
use Karte::Standard;

use constant MELDUNGSLISTE_URL => 'http://asp.vmzberlin.com/VMZ_LSBB_MELDUNGEN_WEB/Meldungsliste.jsp?back=true';

my $date_rx = qr{[0123]\d\.[01]\d\.\d{4}};
my $time_rx = qr{[012]\d:[0-5]\d Uhr};
my $de_num_rx = qr{(ein|einen|zwei|drei|vier|fünf|\d)}; # für Fahrstreifen

sub new { bless {}, shift }

sub fetch {
    my($self, $file) = @_;
    my $ua = LWP::UserAgent->new;
    my $resp = $ua->mirror(MELDUNGSLISTE_URL, $file);
    if (!$resp->is_success) {
	die "Failed while fetching " . MELDUNGSLISTE_URL . ": " . $resp->as_string;
    }
}

sub parse {
    my($self, $file) = @_;
    my %place2rec;
    my %id2rec;
    open my $fh, $file
	or die "Can't open $file: $!";
    my $stage = 'search_gruppierung';
    my $payload;
    while(<$fh>) {
	if ($stage eq 'search_gruppierung') {
	    if (/Gruppierung nach:/) {
		$stage = 'search_br_b';
	    }
	} elsif ($stage eq 'search_br_b') {
	    if (/<br><b>(.*)/) {
		$payload = $1;
		$stage = 'add_payload';
	    }
	} elsif ($stage eq 'add_payload') {
	    $payload .= $_;
	}
    }
    my $p = XML::LibXML->new;
    while ($payload =~ m{(.*?)(?:<br><b>|\s+</font>\s+</body>)}gs) {
	my $chunk = '<html><body><b>'.$1.'</body></html>';
	$chunk =~ s{&}{&amp;}g;
	my $doc = $p->parse_html_string($chunk);
	my $root = $doc->documentElement;
	my $place = $root->findvalue('/html/body/b'); $place =~ s{:\s+}{};
	my @records;
	for my $tr_node ($root->findnodes('/html/body/table/tr')) {
	    my $meldungskarte_href = $tr_node->findvalue('.//a/@href');
	    my $u = URI->new_abs($meldungskarte_href, MELDUNGSLISTE_URL);
	    my $lat = $u->query_param('x'); # yes, it's reversed
	    my $lon = $u->query_param('y');
	    my $id  = $u->query_param('meldungId');

	    my $record = { place   => $place,
			   map_url => $u->as_string,
			   lat     => $lat,
			   lon     => $lon,
			   id      => $id,
			 };
	    if (exists $id2rec{$id}) {
		warn "Duplicate record for $id?!";
	    } else {
		$id2rec{$id} = $record;
	    }

	    my $icon = $tr_node->findvalue('//img/@src');
	    if ($icon =~ m{(closure|roadWorks)\.gif}) {
		$record->{type} = lc $1;
	    }
	    my @line_nodes = $tr_node->findnodes('.//p/child::node()');
	    my @lines = '';
	    for (@line_nodes) {
		if ($_->nodeName eq 'br') {
		    push @lines, '';
		} else {
		    $lines[-1] .= $_->textContent;
		}
	    }
	    pop @lines if $lines[-1] eq '';
	    for (@lines) {
		s{^\s+}{};
		s{\s+$}{};
		s{\s+}{ }g;
	    }
	    $record->{text} = join("\n", @lines);
	    
	    my @strassen;
	    for (reverse @lines) { # typically 2nd last line, so start from end
		if (m{^Stra(?:ss|ß)en:\s*(.*)}) {
		    @strassen = split /\s*,\s*/, $1;
		    $record->{strassen} = \@strassen;
		    last;
		}
	    }
	    if ($lines[-1] =~ m{^($date_rx)(?:\s($time_rx))?\sbis\s($date_rx)(?:\s($time_rx))?}) {
		@{$record}{qw(from_date from_time to_date to_time)} = ($1,$2,$3,$4);
	    } else {
		warn "Cannot parse date/time from $lines[-1]";
	    }

	    push @records, $record;
	}

	$place2rec{$place} = \@records;
    }

    (place2rec => \%place2rec,
     id2rec    => \%id2rec,
     parsed_at => scalar(localtime),
    );
}

sub as_bbd {
    my($self, $place2rec, $old_store) = @_;
    my $old_id2rec = $old_store ? $old_store->{id2rec} : undef;
    my $s = <<'EOF';
#: title: VMZ
#:
EOF
    my $handle_rec = sub {
	my($rec, $is_removed) = @_;
	my @attribs;
	if (grep { m{^A} } @{ $rec->{strassen} }) {
	    push @attribs, 'IGNORE';
	} elsif ($rec->{place} eq 'Berlin') {
	    # special ignore detection for Berlin
	    my @lines = split /\n/, $rec->{text};
	    # remove all lines after (and including) "Strassen:"
	    for(my $i=$#lines; $i>0; $i--) {
		if ($lines[$i] =~ m{^Strassen:}) {
		    @lines = @lines[0..$i-1];
		    last;
		}
	    }
	    # Last line now is always additional direction notes
	    pop @lines;
	    if (@lines == 1) {
		$lines[0] =~ s{\s\(.*?\)}{}g;
		$lines[0] =~ s{^(Baustelle|Bauarbeiten),\s+}{};
		$lines[0] =~ s{(,\s*)?
			       (Fahrbahn\s(teilweise\s)?auf\s$de_num_rx\sFahrstreifen\sje\sRichtung\sverengt
			       |Fahrbahn\s(teilweise\s)?auf\s$de_num_rx\sFahrstreifen\sverengt
			       |Fahrbahn\s(teilweise\s)?je\sRichtung\sauf\s$de_num_rx\sFahrstreifen\sverengt
			       |Fahrbahn\svon\s$de_num_rx\sauf\s$de_num_rx\sFahrstreifen\sreduziert
			       |Fahrbahn\svon\s$de_num_rx\sFahrstreifen\sreduziert
			       |($de_num_rx|linker|rechter|mittlerer)\sFahrstreifen\sgesperrt
			       |veränderte\sVerkehrsführung\sim\sBaustellenbereich
			       |Fahrstreifenverschwenkung\sund\sFahrbahnverengung
			       |Fahrstreifenverschwenkung
			       |Behinderungen\sdurch\sParkplatzsuchverkehr
			       |bitte\sumfahren\sSie\sden\sBereich\sweiträumig
			       |Gefahr\sdurch\sstockenden\sVerkehr
			       |stockender\sVerkehr\szu\serwarten
			       |Fahrbahn\snicht\sbetroffen
			       |Umleitung\sist\sausgeschildert
			       |Verkehrsbehinderung\serwartet
			       |Fahrbahnverengung
			       |veränderte\sVerkehrsführung
			       |für\sLKW-Verkehr\sgesperrt
			       |Ampeln\sausgefallen
			       |Ampeln\sin\sBetrieb
			       |Stau\szu\serwarten
			       |Staugefahr
			       )}{}xg;
		if ($lines[0] eq '') {
		    push @attribs, 'IGNORE';
		}
	    }
	}
	if ($is_removed) {
	    push @attribs, 'REMOVED';
	} elsif (!$old_id2rec || !$old_id2rec->{$rec->{id}}) {
	    push @attribs, 'NEW';
	} elsif ($old_id2rec->{$rec->{id}}->{text} eq $rec->{text}) {
	    push @attribs, 'UNCHANGED';
	} else {
	    push @attribs, 'CHANGED';
	}
	my($sx,$sy) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($rec->{lon},$rec->{lat}));
	(my $text = $rec->{text}) =~ s{\n}{ }g;
	$s .= join(", ", @attribs) . "¦" .
	    ($rec->{place} ne 'Berlin' ? $rec->{place} . ": " : '') .
		$text . "¦" . $rec->{id} . "¦" . $rec->{map_url} . "\tX $sx,$sy\n";
    };
    my %seen_id;
    for my $place (sort { $place2rec->{$a}->{lon} <=> $place2rec->{$b}->{lon} } keys %$place2rec) {
	my $recs = $place2rec->{$place};
	for my $rec (@$recs) {
	    $seen_id{$rec->{id}}++;
	    $handle_rec->($rec, 0);
    	}
    }
    for my $old_id (keys %$old_id2rec) {
	if (!$seen_id{$old_id}) {
	    $handle_rec->($old_id2rec->{$old_id}, 1);
	}
    }
    $s;
}

return 1 if caller;

use File::Temp qw(tempfile);
use Getopt::Long;
use YAML::Syck;

my $old_store_file;
my $new_store_file;
my $out_bbd;
my $do_fetch = 1;
GetOptions("oldstore=s" => \$old_store_file,
	   "newstore=s" => \$new_store_file,
	   "outbbd=s" => \$out_bbd,
	   "fetch!" => \$do_fetch,
	  )
    or die "usage?";

my $old_store;
if ($old_store_file) {
    $old_store = YAML::Syck::LoadFile($old_store_file);
}

my $vmz = VMZTool->new;
my($tmpfh, $file);
if ($do_fetch) {
    ($tmpfh,$file) = tempfile(UNLINK => 1) or die $!;
    eval { $vmz->fetch($file) };
    if ($@) {
	$File::Temp::KEEP_ALL = 1;
	die $@;
    }
} else {
    $file = "$ENV{HOME}/trash/Meldungsliste.jsp?back=true";
}
my %res = $vmz->parse($file);
my $bbd = $vmz->as_bbd($res{place2rec}, $old_store);
if ($new_store_file) {
    YAML::Syck::DumpFile($new_store_file, \%res);
}
if ($out_bbd) {
    open my $ofh, ">", $out_bbd or die $!;
    print $ofh $bbd;
    close $ofh or die $!;
} else {
    print $bbd;
}

__END__

=head1 TODO

 * should the URL be stored in the bbd somewhere?
 * implement process
  * fetch and temporarily store MELDUNGSLISTE_URL
  * parse the fetched data (in case of errors: do not unlink)
  * store the parsed data
  * get old data (either last marked as checked or previous set)
  * call as_bbd and write down the bbd file

=head1 SYNOPSIS

Conversion between old vmz file into new format for "removed"
detection:

    perl -MYAML::Syck=LoadFile,Dump -e '$d = LoadFile(shift); for (@$d) { $seen{$_->{id}} = $_ } print Dump { id2rec => \%seen }' ~/cache/misc/vmz.yaml > /tmp/oldvmz.yaml

First-time usage:

    perl miscsrc/VMZTool.pm -oldstore /tmp/oldvmz.yaml -newstore ~/cache/misc/newvmz.yaml -outbbd ~/cache/misc/diffnewvmz.bbd

Regular usage: TBD

=cut
