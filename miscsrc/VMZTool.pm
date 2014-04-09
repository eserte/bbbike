# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010,2013,2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package VMZTool;

use strict;
our $VERSION = '0.05';

use File::Basename qw(basename);
use HTML::FormatText 2;
use HTML::TreeBuilder;
use HTML::Tree;
use JSON::XS qw(decode_json);
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
use constant MELDUNGSKARTE_URL => 'http://asp.vmzberlin.com/VMZ_LSBB_MELDUNGEN_WEB/Meldungskarte.jsp?back=true&map=true';

# @TIMER@ is replaced here:
#use constant MELDUNGSLISTE_BERLIN_URL_FMT => 'http://www.vmz-info.de/web/guest/home?p_p_id=vizmessages_WAR_vizmessagesportlet_INSTANCE_Him5&p_p_lifecycle=2&p_p_state=normal&p_p_mode=view&p_p_resource_id=ajaxPoiListUrl&p_p_cacheability=cacheLevelPage&p_p_col_id=column-1&p_p_col_pos=1&p_p_col_count=2&_vizmessages_WAR_vizmessagesportlet_INSTANCE_Him5_locale=de_DE&_vizmessages_WAR_vizmessagesportlet_INSTANCE_Him5_url=http%3A%2F%2Fwms.viz.mobilitaetsdienste.de%2Fpoint_list%2F%3Flang%3Dde&timer=@TIMER@&category=trafficmessage&state=BB';
use constant MELDUNGSLISTE_BERLIN_URL_FMT => 'http://vmz-info.de/web/guest/2?p_p_id=vizmap_WAR_vizmapportlet_INSTANCE_Ds4N&p_p_lifecycle=2&p_p_state=normal&p_p_mode=view&p_p_resource_id=ajaxPoiMapListUrl&p_p_cacheability=cacheLevelPage&p_p_col_id=column-1&p_p_col_count=1&_vizmap_WAR_vizmapportlet_INSTANCE_Ds4N_locale=de_DE&_vizmap_WAR_vizmapportlet_INSTANCE_Ds4N_url=https%3A%2F%2Fservices.mobilitaetsdienste.de%2Fviz%2Fproduction%2Fwms%2F2%2Fwms_list%2F%3Flang%3Dde&timer=@TIMER@&category=publictransportstationairport,trafficmessage&bbox=12.470944447998022,52.00192353741223,14.171078725341772,52.84438224389493';

use constant VMZ_RSS_URL => 'http://vmz-info.de/rss/iv';

sub _trim ($);

my $date_rx = qr{[0123]\d\.[01]\d\.\d{4}};
my $time_rx = qr{[012]\d:[0-5]\d Uhr};
my $de_num_rx = qr{(ein|einen|zwei|drei|vier|fünf|\d)}; # für Fahrstreifen

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->{ua} = LWP::UserAgent->new;
    $self->{xmlp} = XML::LibXML->new;
    $self->{formatter} = HTML::FormatText->new(leftmargin => 0, rightmargin => 60);
    $self->{existsid_current} = {};
    $self->{existsid_old} = {};
    {
	my $timer = time * 1000;
	(my $meldungsliste_berlin_url = MELDUNGSLISTE_BERLIN_URL_FMT) =~ s{\@TIMER\@}{$timer};
	$self->{meldungsliste_berlin_url} = $meldungsliste_berlin_url;
    }
    eval { require Hash::Util; Hash::Util::lock_keys($self) }; warn $@ if $@;
    $self;
}

sub set_existsid_current {
    my($self, $existsid_current_ref) = @_;
    $self->{existsid_current} = $existsid_current_ref;
}

sub set_existsid_old {
    my($self, $existsid_old_ref) = @_;
    $self->{existsid_old} = $existsid_old_ref;
}

sub fetch {
    my($self, $file) = @_;
    my $ua = $self->{ua};
    my $resp = $ua->mirror(MELDUNGSLISTE_URL, $file);
    if (!$resp->is_success) {
	die "Failed while fetching " . MELDUNGSLISTE_URL . ": " . $resp->as_string;
    }
}

sub fetch_mappage {
    my($self, $file) = @_;
    my $ua = $self->{ua};
    my $resp = $ua->mirror(MELDUNGSKARTE_URL, $file);
    if (!$resp->is_success) {
	die "Failed while fetching " . MELDUNGSKARTE_URL . ": " . $resp->as_string;
    }
}

sub fetch_berlin_summary {
    my($self, $file) = @_;
    my $ua = $self->{ua};
    my $meldungsliste_berlin_url = $self->{meldungsliste_berlin_url};
    my $resp = $ua->mirror($meldungsliste_berlin_url, $file);
    if (!$resp->is_success) {
	die "Failed while fetching $meldungsliste_berlin_url: " . $resp->as_string;
    }
}

sub fetch_vmz_rss {
    my($self, $file) = @_;
    my $ua = $self->{ua};
    my $resp = $ua->mirror(VMZ_RSS_URL, $file);
    if (!$resp->is_success) {
	die "Failed while fetching " . VMZ_RSS_URL . ": " . $resp->as_string;
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
    my $p = $self->{xmlp};
    while ($payload =~ m{(.*?)(?:<br><b>|\s+</font>\s+</body>)}gs) {
	my $chunk = '<html><body><b>'.$1.'</body></html>';
	$chunk =~ s{&}{&amp;}g;
	$chunk =~ s{<>}{&lt;&gt;}g;
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
		_trim $_;
	    }
	    $record->{text} = join("\n", @lines);
	    my $formatted_text;
	    
	    my @strassen;
	    for(my $line_i = $#lines; $line_i >= 0; $line_i--) { # typically 2nd last line, so start from end
		local $_ = $lines[$line_i];
		if (m{^Stra(?:ss|ß)en:\s*(.*)}) {
		    @strassen = split /\s*,\s*/, $1;
		    $formatted_text = $1 . ($line_i >= 1 ? ": " . join("\n", @lines[0..$line_i-1]) : "");
		    $record->{strassen} = \@strassen;
		    last;
		}
	    }
	    if ($lines[-1] =~ m{^($date_rx)(?:\s($time_rx))?\sbis\s($date_rx)(?:\s($time_rx))?}) {
		@{$record}{qw(from_date from_time to_date to_time)} = ($1,$2,$3,$4);
		$formatted_text .= ", $lines[-1]";
	    } else {
		warn "Cannot parse date/time from $lines[-1]";
	    }

	    $record->{formatted_text} = $formatted_text;

	    push @records, $record;
	}

	$place2rec{$place} = \@records;
    }

    (place2rec => \%place2rec,
     id2rec    => \%id2rec,
     parsed_at => scalar(localtime),
    );
}

sub parse_mappage {
    my($self, $file, $data) = @_;
    open my $fh, $file or die "Can't open $file: $!";
    while(<$fh>) {
	if (m{new GInfoWindowTab\("Aktuell","(.*)"\)}) {
	    my $chunk = '<html><body>'.$1.'</body></html>';
	    my $htmltb = HTML::TreeBuilder->new;
	    my $tree = $htmltb->parse($chunk);
	    my $text = $self->{formatter}->format($tree);
	    _trim $text;
	    if ($text =~ s{Stand der Daten: \d+\.\d+\.\d{4} \d{2}:\d{2}:\d{2} \((.*?)\)}{}) {
		my $id = $1;
		if (exists $data->{id2rec}->{$id}) {
		    $data->{id2rec}->{$id}->{detailed_text} = $text;
		} else {
		    warn "Strange: id $id does not occur in dataset";
		}
	    } else {
		warn "WARN: cannot parse 'Stand der Daten' out of text";
	    }
	}
    }
}

sub parse_vmz_rss {
    my($self, $vmz_rss_file) = @_;
    my $root = $self->{xmlp}->parse_file($vmz_rss_file)->documentElement;
    $root->setNamespaceDeclURI(undef, undef);
    my %res;
    for my $item_node ($root->findnodes('/rss/channel/item')) {
	my $guid = $item_node->findvalue('guid');
	if (!$guid) {
	    warn "Cannot find guid for item '" . $item_node->serialize . "', skipping...";
	    next;
	}
	(my $id = $guid) =~ s{http://www.viz-info.de/}{};
	$res{$id} = {
		     title => $item_node->findvalue('title'),
		     pubdate => $item_node->findvalue('pubdate'),
		     description_html => $item_node->findvalue('description'),
		    };

    }
    %res;
}

sub parse_berlin_summary {
    my($self, $summary_file, $rss_data) = @_;

    my $json = do { open my $fh, '<:raw', $summary_file or die $!; local $/; <$fh> };
    my $summary_data = decode_json $json;

    my $place = 'Berlin';

    my %id2rec;
    my %place2rec;

    for my $record (@{ $summary_data->{list} }) {
	my $type = lc basename $record->{iconId}; # something like "ROADWORKS" or "INDEFINITION"
	next if $type eq 'airport';

	(my $id = $record->{pointId}) =~ s{^News_id_}{};

	my $htmltb = HTML::TreeBuilder->new;
	my $tree = $htmltb->parse($rss_data->{$id}->{description_html});
	my $strasse = $rss_data->{$id}->{title};
	my $text = $self->{formatter}->format($htmltb);
	my @text_lines = split /\n/, $text;
	@text_lines = @text_lines[6..$#text_lines];
	$text = join("\n", $strasse, @text_lines);
	$text =~ s{^\n+}{}; $text =~ s{\n+$}{};
	$text =~ s{^\s*Abschnitt:\s+}{}m;
	$text =~ s{^\s*Stand:\s+\d+\.\d+\.\d+\s+\d+:\d+\s+}{}sm;

	if (defined $id) { # currently we cannot use entries without id
	    my $record = { place  => $place,
			   id     => $id,
			   points => [ {lon => $record->{x}, lat => $record->{y}} ],
			   type   => $type,
			   #href   => $a_href,
			   text   => $text,
			   strassen => [$strasse],
			 };
	    push @{ $place2rec{$place} }, $record;
	    $id2rec{$id} = $record;
	}
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
	my $id = $rec->{id};

	# Check if record should be ignored
	my $do_ignore = 0;
	if (grep { m{^A(\s|\d)} } @{ $rec->{strassen} }) {
	    $do_ignore = 1;
	} elsif (grep { m{Tunnel Tiergarten Spreebogen} } @{ $rec->{strassen} }) { # Berlin specialities
	    $do_ignore = 1;
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
		$lines[0] =~ s{(,\s*)?\b
			       (Fahrbahn\s(teilweise\s)?auf\s$de_num_rx\sFahrstreifen\sje\sRichtung\sverengt
			       |Fahrbahn\s(teilweise\s)?auf\s$de_num_rx\sFahrstreifen\sverengt
			       |Fahrbahn\s(teilweise\s)?je\sRichtung\sauf\s$de_num_rx\sFahrstreifen\sverengt
			       |Fahrbahn\svon\s$de_num_rx\sauf\s$de_num_rx\sFahrstreifen\sreduziert
			       |Fahrbahn\svon\s$de_num_rx\sFahrstreifen\sreduziert
			       |$de_num_rx\sFahrstreifen\sje\sRichtung\sgesperrt
			       |($de_num_rx|linker|rechter|mittlerer)\sFahrstreifen\sgesperrt
			       |veränderte\sVerkehrsführung\sim\sBaustellenbereich
			       |Fahrstreifenverschwenkung\sund\sFahrbahnverengung
			       |Fahrstreifenverschwenkung
			       |Fahrbahnverengung\swegen\s\S+
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
			       |Bauarbeiten
			       |Baustelle
			       )}{}xgi;
		if ($lines[0] eq '') {
		    $do_ignore = 1;
		}
	    }
	}
	if ($do_ignore && $self->{existsid_current}->{$id}) {
	    $do_ignore = 0; # because it's "INUSE"
	}

	# Gather attributes
	my @attribs;
	if ($do_ignore) {
	    push @attribs, 'IGNORE';
	}
	if ($is_removed) {
	    push @attribs, 'REMOVED';
	} elsif (!$old_id2rec || !$old_id2rec->{$id}) {
	    push @attribs, 'NEW';
	} elsif ($old_id2rec->{$id}->{text} eq $rec->{text}) {
	    push @attribs, 'UNCHANGED';
	} else {
	    push @attribs, 'CHANGED';
	}
	my $text = $rec->{formatted_text} || $rec->{detailed_text} || $rec->{text};
	$text =~ s{\n}{ }g;
	my @coords;
	if ($rec->{points}) {
	    @coords =
		map { "$_->[0],$_->[1]" }
		    map { [$Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($_->{lon},$_->{lat}))] }
			@{ $rec->{points} };
	} else {
	    my($sx,$sy) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($rec->{lon},$rec->{lat}));
	    @coords = "$sx,$sy";
	}
	$s .= join(", ", @attribs) . "¦" .
	    ($rec->{place} ne 'Berlin' ? $rec->{place} . ": " : '') .
		$text . "¦" . $id . "¦" . $rec->{map_url} . "¦" . ($self->{existsid_current}->{$id} ? 'INUSE' : $self->{existsid_old}->{$id} ? 'WAS_INUSE' : '') .
		    "\tX @coords\n";
    };
    my %seen_id;
    for my $place (sort { $place2rec->{$a}->[0]->{lon} <=> $place2rec->{$b}->[0]->{lon} } keys %$place2rec) {
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

sub _trim ($) {
    $_[0] =~ s{^ +}{};
    $_[0] =~ s{ +$}{};
    $_[0] =~ s{ +}{ }g;
}

return 1 if caller;

use File::Temp qw(tempfile);
use Getopt::Long;
use BBBikeYAML;

my $old_store_file;
my $new_store_file;
my $out_bbd;
my $do_fetch = 1;
my $do_test;
my $do_aspurls = 1;
my $existsid_current_file; # typically bbbike/tmp/bbbike-temp-blockings-optimized-existsid.yml
my $existsid_all_file; # typically bbbike/tmp/bbbike-temp-blockings-existsid.yml
GetOptions("oldstore=s" => \$old_store_file,
	   "newstore=s" => \$new_store_file,
	   "outbbd=s" => \$out_bbd,
	   "existsid-current=s" => \$existsid_current_file,
	   "existsid-all=s" => \$existsid_all_file,
	   "fetch!" => \$do_fetch,
	   "test!" => \$do_test,
	   "aspurls!" => \$do_aspurls,
	  )
    or die "usage?";

my $old_store;
if ($old_store_file) {
    $old_store = BBBikeYAML::LoadFile($old_store_file);
}

my %existsid_current;
my %existsid_old;
if ($existsid_current_file) {
    %existsid_current = %{ BBBikeYAML::LoadFile($existsid_current_file) };
}
if ($existsid_all_file) {
    my $existsid_all = BBBikeYAML::LoadFile($existsid_all_file);
    while(my($k,$v) = each %$existsid_all) {
	if (!$existsid_current{$k}) {
	    $existsid_old{$k} = 1;
	}
    }
}

my $vmz = VMZTool->new;
if ($existsid_current_file || $existsid_all_file) {
    $vmz->set_existsid_current(\%existsid_current);
    $vmz->set_existsid_old    (\%existsid_old);
}
my($tmpfh, $file);
my($tmp2fh, $mapfile);
my($tmp3fh, $berlinsummaryfile);
my($tmp4fh, $vmzrssfile);
if ($do_test) {
    my $samples_dir = "$ENV{HOME}/src/bbbike-aux/samples";
    if ($do_aspurls) {
	$file       = "$samples_dir/Meldungsliste.jsp?back=true";
	$mapfile    = "$samples_dir/Meldungskarte.jsp?back=true&map=true&x=52.1034702789087&y=14.270757485947728&zoom=13&meldungId=LS%2FO-SG33-F%2F10%2F027";
    }
    $berlinsummaryfile = "$samples_dir/vmz-2014.json";
    $vmzrssfile        = "$samples_dir/vmz-2014.rss";
} elsif ($do_fetch) {
    ($tmpfh,$file)     = tempfile(UNLINK => 1) or die $!;
    ($tmp2fh,$mapfile) = tempfile(UNLINK => 1) or die $!;
    ($tmp3fh,$berlinsummaryfile) = tempfile(UNLINK => 1) or die $!;
    ($tmp4fh,$vmzrssfile) = tempfile(UNLINK => 1) or die $!;
    eval {
	if ($do_aspurls) {
	    $vmz->fetch($file);
	    $vmz->fetch_mappage($mapfile);
	}
	$vmz->fetch_berlin_summary($berlinsummaryfile);
	$vmz->fetch_vmz_rss($vmzrssfile);
    };
    if ($@) {
	$File::Temp::KEEP_ALL = 1;
	die $@;
    }
    
}
my %res;
if ($file && $mapfile) {
    %res = $vmz->parse($file);
    $vmz->parse_mappage($mapfile, \%res);
} elsif (-r $new_store_file) {
    my $res = BBBikeYAML::LoadFile($new_store_file);
    %res = %$res;
}
if ($berlinsummaryfile && $vmzrssfile) {
    my %berlin_rss_res = $vmz->parse_vmz_rss($vmzrssfile);
    my %berlin_res = $vmz->parse_berlin_summary($berlinsummaryfile, \%berlin_rss_res);
    while(my($id,$rec) = each %{ $berlin_res{id2rec} }) {
	if (!exists $res{id2rec}->{$id}) {
	    $res{id2rec}->{$id} = $rec;
	    push @{ $res{place2rec}->{$rec->{place}} }, $rec;
	}
    }
}
my $bbd = $vmz->as_bbd($res{place2rec}, $old_store);
if ($new_store_file && $do_fetch) {
    BBBikeYAML::DumpFile($new_store_file, \%res);
}
if ($out_bbd) {
    open my $ofh, ">", $out_bbd or die $!;
    print $ofh $bbd;
    close $ofh or die $!;
} else {
    print $bbd;
}

__END__

=head1 NAME

VMZTool - parse road work information for Berlin and Brandenburg

=head1 SYNOPSIS

Conversion between old vmz file into new format for "removed"
detection:

    perl -MYAML::XS=LoadFile,Dump -e '$d = LoadFile(shift); for (@$d) { $seen{$_->{id}} = $_ } print Dump { id2rec => \%seen }' ~/cache/misc/vmz.yaml > /tmp/oldvmz.yaml

Test usage:

    echo "---" > /tmp/oldvmz.yaml
    perl miscsrc/VMZTool.pm -test -oldstore /tmp/oldvmz.yaml -newstore /tmp/newvmz.yaml -outbbd /tmp/diffnewvmz.bbd

First-time usage:

    perl miscsrc/VMZTool.pm -oldstore /tmp/oldvmz.yaml -newstore ~/cache/misc/newvmz.yaml -outbbd ~/cache/misc/diffnewvmz.bbd

Regular usage (make sure that the both existsid files are up-to-date,
see the appropriate targets in data/Makefile):

    perl miscsrc/VMZTool.pm -existsid-current tmp/sourceid-current.yml -existsid-all tmp/sourceid-all.yml -oldstore ~/cache/misc/newvmz.yaml -newstore ~/cache/misc/newvmz.yaml.new -outbbd ~/cache/misc/diffnewvmz.bbd
    mv ~/cache/misc/newvmz.yaml ~/cache/misc/newvmz.yaml.old
    mv ~/cache/misc/newvmz.yaml.new ~/cache/misc/newvmz.yaml

=head1 DESCRIPTION

 * process
  * fetch and temporarily store MELDUNGSLISTE_URL
  * parse the fetched data (in case of errors: do not unlink)
  * store the parsed data
  * get old data (either last marked as checked or previous set)
  * call as_bbd and write down the bbd file

=head1 NOTES

Two VMZ sources are used: the first (MELDUNGSLISTE_URL and
VMZ_RSS_URL) contains records in Berlin and Brandenburg. The 2nd
(VMZ_RSS_URL) may contain additional records in Berlin. If
records appear in both sources, then the first one is used.

=cut
