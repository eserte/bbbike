# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010,2013,2014,2016,2018,2019,2020,2021 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package VMZTool;

use v5.10.0; # named captures, defined-or
use strict;
our $VERSION = '0.11';

use File::Basename qw(basename);
use HTML::FormatText 2;
use HTML::TreeBuilder;
use HTML::Tree;
use JSON::XS qw(decode_json);
use LWP::UserAgent ();
use POSIX qw(strftime);
use URI ();
use URI::Escape qw(uri_escape);
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

use constant EPOCH_NOW => time;
use constant ISO8601_NOW => do {
    my $s = strftime "%FT%T%z", localtime EPOCH_NOW;
    $s =~ s{(\d\d)(\d\d)$}{$1:$2};
    $s;
};
# Brandenburg
use constant BIBER_URL => "https://biberweb.vmz.services/v3/incidents/biber?bbox=10.66,51.2,15.68,53.74&detail=HIGH&lang=de&timeFrom=" . uri_escape(ISO8601_NOW) . "&_=" . (EPOCH_NOW*1000);
# Berlin
use constant VMZ_2021_DATA_URL => 'https://api.viz.berlin.de/daten/baustellen_sperrungen.json';

use constant USE_VMZ_2021_WGET_HACK => 1;

# historical URLs
# the following two are out-of-order
use constant MELDUNGSLISTE_URL => 'http://asp.vmzberlin.com/VMZ_LSBB_MELDUNGEN_WEB/Meldungsliste.jsp?back=true';
use constant MELDUNGSKARTE_URL => 'http://asp.vmzberlin.com/VMZ_LSBB_MELDUNGEN_WEB/Meldungskarte.jsp?back=true&map=true';
# does not work anymore (certificate error, 502 Bad Gateway)
use constant VMZ_RSS_URL => 'http://vmz-info.de/rss/iv';
# former URL: use constant MELDUNGSLISTE_BERLIN_URL_FMT => 'http://www.vmz-info.de/web/guest/home?p_p_id=vizmessages_WAR_vizmessagesportlet_INSTANCE_Him5&p_p_lifecycle=2&p_p_state=normal&p_p_mode=view&p_p_resource_id=ajaxPoiListUrl&p_p_cacheability=cacheLevelPage&p_p_col_id=column-1&p_p_col_pos=1&p_p_col_count=2&_vizmessages_WAR_vizmessagesportlet_INSTANCE_Him5_locale=de_DE&_vizmessages_WAR_vizmessagesportlet_INSTANCE_Him5_url=http%3A%2F%2Fwms.viz.mobilitaetsdienste.de%2Fpoint_list%2F%3Flang%3Dde&timer=@TIMER@&category=trafficmessage&state=BB';
# does not work anymore (certificate error, 502 Bad Gateway)
# @TIMER@ is replaced here:
use constant MELDUNGSLISTE_BERLIN_URL_FMT => 'http://vmz-info.de/web/guest/2?p_p_id=vizmap_WAR_vizmapportlet_INSTANCE_Ds4N&p_p_lifecycle=2&p_p_state=normal&p_p_mode=view&p_p_resource_id=ajaxPoiMapListUrl&p_p_cacheability=cacheLevelPage&p_p_col_id=column-1&p_p_col_count=1&_vizmap_WAR_vizmapportlet_INSTANCE_Ds4N_locale=de_DE&_vizmap_WAR_vizmapportlet_INSTANCE_Ds4N_url=https%3A%2F%2Fservices.mobilitaetsdienste.de%2Fviz%2Fproduction%2Fwms%2F2%2Fwms_list%2F%3Flang%3Dde&timer=@TIMER@&category=publictransportstationairport,trafficmessage&bbox=12.470944447998022,52.00192353741223,14.171078725341772,52.84438224389493';
# former possible alternative, now a 404: https://viz.berlin.de/berlin-de-meldungen-iv?p_p_id=vizmessages_WAR_vizmessagesportlet_INSTANCE_tFN6ILA0izJo&p_p_lifecycle=2&p_p_state=maximized&p_p_mode=view&p_p_resource_id=ajaxPoiListUrl&p_p_cacheability=cacheLevelPage&_vizmessages_WAR_vizmessagesportlet_INSTANCE_tFN6ILA0izJo_locale=de_DE&_vizmessages_WAR_vizmessagesportlet_INSTANCE_tFN6ILA0izJo_url=https%3A%2F%2Fservices.mobilitaetsdienste.de%2Fviz%2Fproduction%2Fwms%2F2%2Fpoint_list%2F%3Flang%3Dde&timer=1518278557974&category=trafficmessage&state=BB
# out-of-order since mid-June 2022
use constant VMZ_2020_AUTH_URL => 'https://viz.berlin.de/wp-admin/admin-ajax.php';
use constant VMZ_2020_DATA_URL => 'https://api.viz.berlin/incidents/streets?detail=high&lat=52.518463&lng=13.4014173&radius=60000';

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

######################################################################
# Fetch methods

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

sub fetch_biber {
    my($self, $file) = @_;
    my $ua = $self->{ua};
    my $resp = $ua->get(BIBER_URL, ':content_file' => $file); # can't use mirror(), we get a java.text.ParseException
    if (!$resp->is_success) {
	die "Failed while fetching " . BIBER_URL . ": " . $resp->as_string;
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

sub fetch_vmz_2020 {
    my($self, $file) = @_;
    my $ua = $self->{ua};

    # Auth
    my $oauth_resp = $ua->post(VMZ_2020_AUTH_URL, [action => 'vizapi_oauth']);
    if (!$oauth_resp->is_success) {
	die "Failed while fetching " . VMZ_2020_AUTH_URL . ": " . $oauth_resp->headers_as_string;
    }
    my $d = eval { decode_json($oauth_resp->decoded_content(charset => "none")) };
    if (!$d) {
	die "Cannot decode JSON from " . VMZ_2020_AUTH_URL . ": $@";
    }
    my $vizapi_token = $d->{token} // die "Cannot get auth token from response";

    # Data
    # for simplicity, don't mirror, always fetch
    my $resp = $ua->get(
			VMZ_2020_DATA_URL,
			Authorization => "Bearer $vizapi_token",
			':content_file' => $file,
		       );
    if (!$resp->is_success) {
	die "Failed while fetching " . VMZ_2020_DATA_URL . ": " . $resp->headers_as_string
    }
}

sub fetch_vmz_2021 {
    my($self, $file) = @_;
    my $ua = $self->{ua};

    if (USE_VMZ_2021_WGET_HACK) {
	my @cmd = ('wget', '-O'.$file, VMZ_2021_DATA_URL);
	system @cmd;
	die "Running '@cmd' failed" if $? != 0 || !-s $file;
    } else {
	my $resp = $ua->get(
			    VMZ_2021_DATA_URL,
			    ':content_file' => $file,
			   );
	if (!$resp->is_success) {
	    die "Failed while fetching " . VMZ_2021_DATA_URL . ":\n" . $resp->dump;
	}
    }
}

######################################################################
# Parse methods

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
	my $type = $record->{iconId} ? lc basename $record->{iconId} : ''; # something like "ROADWORKS" or "INDEFINITION"
	next if $type eq 'airport';

	(my $id = $record->{pointId}) =~ s{^News_id_}{};
	next if $id =~ m{^Airport_id_}; # e.g. Airport_id_SXF, Airport_id_TXL

	my @text_lines;
	if ($rss_data->{$id} && defined $rss_data->{$id}->{description_html}) {
	    my $htmltb = HTML::TreeBuilder->new;
	    my $tree = $htmltb->parse($rss_data->{$id}->{description_html});
	    my $text = $self->{formatter}->format($htmltb);
	    @text_lines = split /\n/, $text;
	    @text_lines = @text_lines[6..$#text_lines];
	} else {
	    @text_lines = $record->{name} . ' (!no rss text!)';
	}
	my $strasse = $rss_data->{$id}->{title};
	my $text = join("\n", $strasse, @text_lines);
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

sub parse_biber {
    my($self, $biber_file) = @_;

    my %id2rec;
    my %place2rec;

    my $get_all_validities = sub {
	my($validities) = @_;
	my %seen;
	my @texts;
	for my $validity (@$validities) {
	    my($timeFromGerman, $timeToGerman);
	    my $timeFrom = $validity->{timeFrom};
	    if ($timeFrom) {
		$timeFromGerman = _iso2german_date($timeFrom);
	    }
	    my $timeTo = $validity->{timeTo};
	    if ($timeTo) {
		$timeToGerman = _iso2german_date($timeTo);
	    }
	    my $text;
	    if ($timeFromGerman && !$timeToGerman) {
		$text = "ab $timeFromGerman";
	    } else {
		$timeToGerman ||= "";
		$text = "$timeFromGerman bis $timeToGerman";
	    }
	    if (!$seen{$text}++) {
		push @texts, $text;
	    }
	}
	join(", ", @texts) . "\n";
    };

    my $data = eval {
	open my $fh, $biber_file
	    or die "Error opening $biber_file: $!";
	local $/;
	decode_json scalar <$fh>;
    };
    if (!$data || $@) {
	die "Error while JSON-decoding 'biber' file '$biber_file': $@";
    }

    for my $element (@$data) {

	my $id;
	if ($element->{messageId}) {
	    # prefer messageId over id: for biber data it's
	    # "LS/721-F/18/087" instead of "LS_721-F_18_087"
	    $id = $element->{messageId};
	} elsif ($element->{id}) {
	    ($id = $element->{id}) =~ s{\@Concert$}{};
	} else {
	    warn "No id or messageId available, skipping element...";
	    next;
	}

	my $place;
	if ($element->{roadSections}) {
	    $place = $element->{roadSections}->[0]->{locationInformation}->{municipalitiy}; # sic!
	} else {
	    $place = $element->{address}->{state};
	}

	my $points = [ { 
			lat => $element->{location}->{coordinates}->[1],
			lon => $element->{location}->{coordinates}->[0],
		       }];
	my $streets = $element->{streets};
	my $text;
	my $description_done;
	my $streets_done;
	if ($element->{details}) {
	    $text .= "$element->{description}\n$element->{details}\n";
	    $description_done++;
	} else {
	    if ($element->{streets}) {
		$text .= "@{ $element->{streets} }\n";
		$streets_done++;
	    }
	    if ($element->{section}) {
		$text .= "$element->{section}\n\n";
	    }
	}
	$text .= $get_all_validities->($element->{validities});
	if (!$description_done && $element->{description}) {
	    $text .= $element->{description};
	}
	if (!$streets_done && $element->{streets}) {
	    $text .= "Strassen: @{ $element->{streets} }\n";
	}
	# text may contain HTML entities
	for ($text) { s{&gt;}{>}g }
	my $rec = 
	    {
	     id      => $id,
	     place   => $place,
	     points  => $points,
	     streets => $streets,
	     text    => $text,
	    };
	$id2rec{$id} = $rec;
	push @{ $place2rec{$place} }, $rec;
    }

    (place2rec => \%place2rec,
     id2rec => \%id2rec,
     parsed_at => scalar(localtime),
    );
}

sub parse_vmz_2020 {
    my($self, $vmz_2020_file) = @_;

    my $json = do { open my $fh, '<:raw', $vmz_2020_file or die $!; local $/; <$fh> };
    my $data = decode_json $json;

    my $place = 'Berlin';

    my %id2rec;
    my %place2rec;

    for my $record (@$data) {
	my $type = $record->{property}->[0]; # "roadwork" or "blockage", there may be a 2nd element, only "future" seen here -> ignored for now

	my $id = $record->{id};
	$id =~ s{\@Concert$}{}; # ignore operatorId, seems to be always the same

	# The validity structure is unclear. The first element has
	# also visible:false set and the second element is the same
	# time span, but visible:true is set. Sometimes the 2nd one is
	# slightly different.
	my $validity = eval {
	    my $timeFrom = $record->{validities}->[0]->{timeFrom};
	    my $timeTo   = $record->{validities}->[0]->{timeTo};
	    $timeFrom = defined $timeFrom ? _iso2german_date($timeFrom) : undef;
	    $timeTo   = defined $timeTo   ? _iso2german_date($timeTo)   : undef;
	    join(" ",
		 (defined $timeFrom ? "vom " . $timeFrom : ()),
		 (defined $timeTo   ? "bis " . $timeTo   : ()),
		);
	};
	if (!$validity) {
	    warn "Cannot parse validity for id $id: $@";
	}

	my $description = $record->{description};
	if ($validity) {
	    # remove less accurate time from description
	    $description =~ s{
				 \s+
				 \(
				 (?:vsl\.\s+)?bis\s+(?:vsl\.\s+)?
				 ((?:Anfang|Mitte|Ende)\s+)?
				 (?:\d{1,2}/\d+|\d{4})
				 \)$
			     }{}x;
	}

	my $text =
	    join(", ", @{ $record->{streets} || ["(!no street!)"] }) . (defined $record->{section} ? " $record->{section}" : "") . ":\n" .
	    $description . 
	    (defined $validity ? ",\n$validity" : "") .
	    "\n";

	if (defined $id) { # currently we cannot use entries without id
	    my $out_record =
		{ place  => $place,
		  id     => $id,
		  points => [ {lon => $record->{location}->{coordinates}->[0], lat => $record->{location}->{coordinates}->[1]} ], # XXX better to use geometry if available
		  type   => $type,
		  #href   => $a_href,
		  text   => $text,
		  strassen => $record->{streets},
		};

	    push @{ $place2rec{$place} }, $out_record;
	    $id2rec{$id} = $out_record;
	}
    }

    (place2rec => \%place2rec,
     id2rec    => \%id2rec,
     parsed_at => scalar(localtime),
    );
}

sub parse_vmz_2021 {
    my($self, $vmz_2021_file) = @_;

    my $json = do { open my $fh, '<:raw', $vmz_2021_file or die $!; local $/; <$fh> };
    my $data = eval { decode_json $json };
    if (!$data || $@) {
	system "cp", $vmz_2021_file, "/tmp/vmz_2021.json";
	die "Failed to parse JSON from '$vmz_2021_file' (a copy was saved to /tmp/vmz_2021.json): $@";
    }

    my $place = 'Berlin';

    my %id2rec;
    my %place2rec;

    if ($data->{type} ne 'FeatureCollection') {
	die "Unexpected GeoJSON type '$data->{type}' (expected FeatureCollection)";
    }

    my $get_first_coordinate;
    $get_first_coordinate = sub {
	my($geometry) = @_;
	if ($geometry->{type} eq 'GeometryCollection') {
	    for my $sub_geometry (@{ $geometry->{geometries} }) {
		my $coordinate = $get_first_coordinate->($sub_geometry);
		return $coordinate if $coordinate;
	    }
	} elsif ($geometry->{type} eq 'Point') {
	    return $geometry->{coordinates};
	} elsif ($geometry->{type} eq 'LineString') {
	    return $geometry->{coordinates}->[0];
	} else {
	    die "Don't know how to handle geometry type '$geometry->{type}'";
	}
    };

    my @records = @{ $data->{features} };
    my %seen_id;
    for my $record (@records) {
	my $properties = $record->{properties};
	my $geometry   = $record->{geometry};

	my $type = $properties->{subtype};

	my $first_coordinate = $get_first_coordinate->($geometry);
	if (!$first_coordinate) {
	    warn "Cannot get coordinate for:\n";
	    require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$record],[qw()])->Indent(1)->Useqq(1)->Sortkeys(1)->Terse(1)->Dump; # XXX
	    next;
	}
	my($lon, $lat) = @$first_coordinate;

	# no id, we need to make something up (based on coordinates of point
	my $coord_for_id = join ",", $Karte::Polar::obj->trim_accuracy($lon, $lat);
	my $validity_from_for_id = join ",", split /\s+/, $properties->{validity}->{from};
	my $id = "viz2021:$coord_for_id,$validity_from_for_id";
	while ($seen_id{$id}) {
	    if (!($id =~ s{-(\d+)$}{"-".($1+1)}e)) {
		$id .= "-1";
	    }
	}
	$seen_id{$id} = 1;

	my $validity = do {
	    my $timeFrom = $properties->{validity}->{from};
	    my $timeTo   = $properties->{validity}->{to};
	    join(" ",
		 (defined $timeFrom ? "vom " . $timeFrom : ()),
		 (defined $timeTo   ? "bis " . $timeTo   : ()),
		);
	};
	if (!$validity) {
	    warn "Cannot parse validity for id $id: $@";
	}

	my $description = $properties->{content};
	if ($validity) {
	    # remove less accurate time from description
	    $description =~ s{
				 \s+
				 \(
				 (?:vsl\.\s+)?bis\s+(?:vsl\.\s+)?
				 ((?:Anfang|Mitte|Ende)\s+)?
				 (?:\d{1,2}/\d+|\d{4})
				 \)$
			     }{}x;
	}

	my $text =
	    ($properties->{street} || "(!no street!)") . (defined $properties->{section} ? " $properties->{section}" : "") .
	    (defined $description ? ":\n$description" : "\n") .
	    (defined $validity ? ",\n$validity" : "") .
	    "\n";

	my $out_record =
	    { place    => $place,
	      id       => $id,
	      points   => [ {lon => $lon, lat => $lat} ],
	      type     => $type,
	      text     => $text,
	      strassen => [ $properties->{street} ],
	    };

	push @{ $place2rec{$place} }, $out_record;
	$id2rec{$id} = $out_record;
    }

    (place2rec => \%place2rec,
     id2rec    => \%id2rec,
     parsed_at => scalar(localtime),
    );
}

######################################################################
# Other
sub as_bbd {
    my($self, $place2rec, $old_store) = @_;
    my $old_id2rec = $old_store ? $old_store->{id2rec} : undef;
    my $s = <<'EOF';
#: #: -*- coding: utf-8 -*-
#: encoding: utf-8
#: title: VMZ
#:
EOF
    my $handle_rec = sub {
	my($rec, $is_removed) = @_;
	my $id = $rec->{id};

	# Check if record should be ignored
	my $do_ignore = 0;
	# XXX Leider können auch Einträge wie "Brücke ... über A10 voll gesperrt" fälschlicherweise ignoriert werden
	if (grep { m{^A(\s|\d)} } @{ $rec->{strassen} }) {
	    $do_ignore = 1;
	} elsif (grep { m{^A\s*\d} } @{ $rec->{streets} || [] }) {
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

sub _iso2german_date {
    my($date) = @_;
    if ($date =~ m{
		      ^
		      (?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2})
		      T
		      (?<H>\d{2}):(?<M>\d{2})
	      }x) {
	if ($+{y} >= 2100) { return undef } # yes, happens, often enough
	my $date = "$+{d}.$+{m}.$+{y}";
	my $time = "$+{H}:$+{M}";
	if ($time eq '00:00') {
	    $date;
	} else {
	    "$date $time Uhr";
	}
    } else {
	undef;
    }
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
my $do_aspurls = 0;
my $do_vmz_2015_urls = 0;
my $do_vmz_2020_urls = 0;
my $do_vmz_2021_urls = 1;
my $do_biberurl = 1;
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
	   "vmz-2015-urls!" => \$do_vmz_2015_urls,
	   "vmz-2020-urls!" => \$do_vmz_2020_urls,
	   "vmz-2021-urls!" => \$do_vmz_2021_urls,
	   "biberurl!" => \$do_biberurl,
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
my($file);
my($mapfile);
my($berlinsummaryfile);
my($vmzrssfile);
my($biberfile);
my($vmz_2020_file);
my($vmz_2021_file);
if ($do_test) {
    my $samples_dir = "$ENV{HOME}/src/bbbike-aux/samples";
    if ($do_aspurls) {
	$file       = "$samples_dir/Meldungsliste.jsp?back=true";
	$mapfile    = "$samples_dir/Meldungskarte.jsp?back=true&map=true";
    }
    if ($do_vmz_2015_urls) {
	$berlinsummaryfile = "$samples_dir/vmz-2016.json";
	$vmzrssfile        = "$samples_dir/vmz-2015.rss";
    }
    if ($do_vmz_2020_urls) {
	$vmz_2020_file = "$samples_dir/viz-2020.json";
    }
    if ($do_vmz_2021_urls) {
	$vmz_2021_file = "$samples_dir/viz-2021.json";
    }
    if ($do_biberurl) {
	$biberfile  = "$samples_dir/biber.json";
    }
} elsif ($do_fetch) {
    eval {
	if ($do_aspurls) {
	    (undef,$file)     = tempfile(UNLINK => 1) or die $!;
	    (undef,$mapfile) = tempfile(UNLINK => 1) or die $!;
	    $vmz->fetch($file);
	    $vmz->fetch_mappage($mapfile);
	}
	if ($do_vmz_2015_urls) {
	    (undef,$berlinsummaryfile) = tempfile(UNLINK => 1) or die $!;
	    (undef,$vmzrssfile) = tempfile(UNLINK => 1) or die $!;
	    $vmz->fetch_berlin_summary($berlinsummaryfile);
	    $vmz->fetch_vmz_rss($vmzrssfile);
	}
	if ($do_vmz_2020_urls) {
	    (undef,$vmz_2020_file) = tempfile(UNLINK => 1) or die $!;
	    $vmz->fetch_vmz_2020($vmz_2020_file);
	}
	if ($do_vmz_2021_urls) {
	    (undef,$vmz_2021_file) = tempfile(UNLINK => 1) or die $!;
	    $vmz->fetch_vmz_2021($vmz_2021_file);
	}
	if ($do_biberurl) {
	    (undef,$biberfile) = tempfile(UNLINK => 1) or die $!;
	    $vmz->fetch_biber($biberfile);
	}
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
if ($biberfile) {
    my %biber_res = $vmz->parse_biber($biberfile);
    while(my($id,$rec) = each %{ $biber_res{id2rec} }) {
	if (!exists $res{id2rec}->{$id}) {
	    $res{id2rec}->{$id} = $rec;
	    push @{ $res{place2rec}->{$rec->{place}} }, $rec;
	}
    }
}
if ($vmz_2020_file || $vmz_2021_file || ($berlinsummaryfile && $vmzrssfile)) {
    my %berlin_res;
    if ($vmz_2021_file) {
	%berlin_res = $vmz->parse_vmz_2021($vmz_2021_file);
    } elsif ($vmz_2020_file) {
	%berlin_res = $vmz->parse_vmz_2020($vmz_2020_file);
    } elsif ($berlinsummaryfile && $vmzrssfile) {
	my %berlin_rss_res = $vmz->parse_vmz_rss($vmzrssfile);
	%berlin_res = $vmz->parse_berlin_summary($berlinsummaryfile, \%berlin_rss_res);
    }
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
    binmode $ofh, ':encoding(utf-8)';
    print $ofh $bbd;
    close $ofh or die $!;
} else {
    binmode STDOUT, ':encoding(utf-8)';
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

Revert (if current download is broken and may be fixed later;
minimizes diffs):

    cd ~/cache/misc
    mv diffnewvmz.bbd newvmz.new.yaml ~/trash
    mv newvmz.yaml newvmz.new.yaml
    mv diffnewvmz.old.bbd diffnewvmz.bbd
    mv newvmz.old.yaml newvmz.yaml

Use old files as in regular, but save new files into temporary
locations (useful for testing).

    perl miscsrc/VMZTool.pm -existsid-current tmp/sourceid-current.yml -existsid-all tmp/sourceid-all.yml -oldstore ~/cache/misc/newvmz.yaml -newstore /tmp/newvmz.yaml -outbbd /tmp/diffnewvmz.bbd

=head1 DESCRIPTION

 * process
  * fetch and temporarily store urls
  * parse the fetched data (in case of errors: do not unlink)
  * store the parsed data
  * get old data (either last marked as checked or previous set)
  * call as_bbd and write down the bbd file

=cut
