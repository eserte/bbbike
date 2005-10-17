# -*- perl -*-

#
# $Id: LuiseBerlin.pm,v 1.4 2005/10/17 20:48:06 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package LuiseBerlin;

use strict;
use vars qw($VERSION @ISA);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use WWW::Search::Google;
use Encode;
use String::Similarity;

use PLZ;
use Strassen::Strasse;
use WWWBrowser;

my $api_key = "pqCq16BQFHJ5jvhg6osutPlLWeSkd9ke";

sub register {
    $main::info_plugins{__PACKAGE__} =
	{ name => "Luise-Berlin, Straßenlexikon",
	  callback => sub { launch_street_url(@_) },
	};
    $main::info_plugins{__PACKAGE__ . "_bezlex"} =
	{ name => "Luise-Berlin, Bexirkslexikon",
	  callback => sub { launch_bezlex_url(@_) },
	};
    main::status_message("Das Luise-Berlin-Plugin wurde registriert. Im Info-Fenster erscheint jetzt immer ein neuer Link.", "info");
}

sub find_street {
    my($strname) = @_;
    if ($strname =~ /^\(/ || $strname =~ /^\s*$/) {
	main::status_message("Die Straße hat keinen offiziellen Namen", "err");
	return;
    }
    $strname =~ s{\[.*\]}{}g; # remove special [...] parts
    my($street, @subcityparts) = Strasse::split_street_citypart($strname);
    if (!@subcityparts) {
	my $plz = PLZ->new;
	my @res = $plz->look($street);
	@subcityparts = map { $_->[PLZ::LOOK_CITYPART] } @res;
    }
    if (!@subcityparts) {
	main::status_message("Die Straße konnte in der BBBike-Datenbank nicht gefunden werden.", "err");
	return;
    }

    require Geography::Berlin_DE;
    my %cityparts = map { (Geography::Berlin_DE->subcitypart_to_citypart->{$_},1) } @subcityparts;

    ($street, [ keys %cityparts ]);
}

sub launch_bezlex_url {
    my(%args) = @_;
    my($street, $cityparts) = find_street($args{street});
    if (!defined $street) {
	return;
    }

    require Geography::Berlin_DE;
    my %supercityparts = map { (Geography::Berlin_DE->get_supercitypart_for_citypart($_),1) } @$cityparts;

    my($supercitypart) = (keys %supercityparts)[0]; # use the first only
    warn "Translated @$cityparts -> $supercitypart ...\n";

    my $short = {"Friedrichshain-Kreuzberg" => "FrKr",
		 'Charlottenburg-Wilmersdorf' => "Chawi",
		 'Mitte' => 'Mitte',
		}->{$supercitypart};
    if (!$short) {
	main::status_message("Für den Bezirk $supercitypart existieren noch keine Einträge im Bezirkslexikon", "err");
	return;
    }

    $street =~ s{(s)tr\.}{$1traße}i;
    my $kill_umlauts = {"ä" => "ae",
			"ö" => "oe",
			"ü" => "ue",
			"ß" => "ss",
			"Ä" => "Ae",
			"Ö" => "Oe",
			"Ü" => "Ue",
			"é" => "_",
			" " => "_",
		       };
    my $left_part = join "", keys %$kill_umlauts;
    $street =~ s{([$left_part])}{$kill_umlauts->{$1}}ge;
    my $url = "http://www.luise-berlin.de/lexikon/" . $short .
	"/" . lc(substr($street,0,1)) .
	    "/" . $street . ".htm";
    start_browser($url);
}

sub launch_street_url {
    my(%args) = @_;
    my($street, $cityparts) = find_street($args{street});

    if (!defined $street) {
	return;
    }

    my $url = eval {
	do_google_search(street => $street,
			 cityparts => $cityparts);
    };
    if ($url) {
	start_browser($url);
    } elsif ($@) {
	main::status_message($@, "err");
    } else {
	main::status_message("Die Straße konnte über Google nicht gefunden werden.", "err");
    }
}

sub do_google_search {
    my(%args) = @_;
    my $search = WWW::Search->new("Google", key => $api_key);
    my $street = $args{street};
    my @cityparts = @{ $args{cityparts} };
    $street =~ s{(s)tr\.}{$1traße}ig;
    $street =~ s{-}{ }g;
    my @results;
    for my $citypart (@cityparts) {
	my $street_citypart = "$street in $citypart";
	# usage of encode should not be necessary here!
	my $query = qq{allintitle:"$street_citypart" site:luise-berlin.de OR site:berlin-chronik.de OR site:berlingeschichte.de};
	use Devel::Peek; Dump $query;
	my $query = encode("utf-8", $query);
	Dump $query;
	require Data::Dumper;
	print STDERR "Google query term: ". Data::Dumper->new([$query],[qw()])->Indent(1)->Useqq(1)->Dump . "\n";
	$search->native_query($query);
	while(my $result = $search->next_result) {
	    (my $cooked_title = $result->title) =~ s{<b>}{}g;
	    ($cooked_title = $cooked_title) =~ s{</b>}{}g;
	    decode("utf-8", $cooked_title);
	    push @results, { title        => $result->title,
			     url          => $result->url,
			     cooked_title => $cooked_title,
			     similarity   => similarity $cooked_title, $street_citypart,
			   };
	}
	
    }
    @results = sort { $b->{similarity} <=> $a->{similarity} } @results;

        #require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\@results],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

    $results[0]->{url};
}

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    WWWBrowser::start_browser($url);
}

return 1 if caller;

do_search(street => "Heerstr.",
	  cityparts => ["Charlottenburg", "Spandau"],
	 );

__END__
