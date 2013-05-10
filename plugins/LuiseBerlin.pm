# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2005,2008,2011 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (de): Straﬂen- und Bezirkslexikon des Luisenst‰dtischen Bildungsvereins (Luise-Berlin.de)
package LuiseBerlin;

# Note that the Google API does not work anymore. I would like the
# Yahoo API, but it does not really work. See
# http://rt.cpan.org/Ticket/Display.html?id=35213
#
# Since 2011-04 the old yahoo websearch api does not work anymore. See
# http://developer.yahoo.com/search/web/V1/webSearch.html

use strict;
use vars qw($VERSION @ISA);
$VERSION = 1.31;

BEGIN {
    if (!caller(2)) {
	eval <<'EOF';
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
EOF
    die $@ if $@;
    }
}

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use Encode;

use PLZ;
use Strassen::Strasse;
use WWWBrowser;

my $api_key = "pqCq16BQFHJ5jvhg6osutPlLWeSkd9ke";

use vars qw($DEBUG
	    $already_tried_String_Similarity
	    $already_tried_WWW_Search_Google
	    $already_tried_Yahoo_Search
	   );
$DEBUG = 1;

use vars qw($icon);

sub register {
## This became unreliable and useless. At 2008-01, I made 
## a test with about ten streets, with and without umlaut:
## no hits! One or two of the search terms were successful
## when entered in Google's search box. So the API seems
## really to be dead. See also
## http://google-code-updates.blogspot.com/2006/12/beyond-soap-search-api.html
## and related pages.
## 
## Haha: I just construct the search and redirect to Google. Smart solution.
    my $is_berlin = $main::city_obj && $main::city_obj->cityname eq 'Berlin';
    if ($is_berlin) {
	_create_image();
	$main::info_plugins{__PACKAGE__ . ""} =
	    { name => "Luise-Berlin, Straﬂenlexikon",
	      callback => sub { launch_street_url(@_) },
	      callback_3 => sub { show_street_menu(@_) },
	      icon => $icon,
	    };
	$main::info_plugins{__PACKAGE__ . "_bezlex"} =
	    { name => "Luise-Berlin, Bexirkslexikon",
	      callback => sub { launch_bezlex_url(@_) },
	      icon => $icon,
	    };
	main::status_message("Das Luise-Berlin-Plugin wurde registriert. Der Link erscheint im Info-Fenster.", "info")
		if !$main::booting;
    } else {
	main::status_message("Das Luise-Berlin-Plugin ist nur f¸r Berlin verf¸gbar.", "err")
		if !$main::booting;
    }
}

sub _create_image {
    if (!defined $icon) {
	# Got from: http://www.luise-berlin.de/petschaft.gif
	# and used white background and scaled to 16x16
	$icon = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAOe2AEREgkxMeU1NdkxMhVFReVJShFJSiFRUf1dXeldXillZeltbfFtbiltb
i1tbjVxci1tblF5efWBgbmBggl9flGFhkGFhlWJilWJilmNjkmNjlGNjlmZmf2Vll2ZmkmZm
lGZmmmZmnGhojWdnmWpqhmlplmtriGtriWpqlWpqlmpql2trm2xslW1tmm9vkm9vmm9vnG9v
nnBwl3BwmHBwmXJyl3NzmXNzn3NzoHR0n3V1n3V1oXd3kXZ2mnV1o3d3oXh4m3l5oXt7knp6
nnt7nHt7pXt7qXx8qn19pX19qH5+oX9/oH9/qH9/qYKCoIGBqYGBqoGBroKCqoODpIODrYSE
p4SEqYSEq4WFpoaGqIiInYeHqoeHr4eHsYiIsImJs4yMtIyMto6OrY+Pt5GRtJOTspOTs5OT
tZOTtpSUtJSUtZaWtpeXsZeXtpiYuZmZuJmZupqaspubt5ubvJubvpycup2dsp+fvKCgvqOj
xaWlv6enwaioxaqqxqurx6uryK2txq2tx66uxq+vxa+vya+vzLCwxrCwx7CwybCwyrOzyLa2
zra20L6+0r+/08DA0cPD18TE1snJ2MvL3M3N2M3N3M7O5c/P4tLS4tPT3dPT39PT4djY6dnZ
49/f5uDg5uPj7uXl7unp8Onp8+zs8+3t8+3t9e/v9fDw9fHx9fLy9fPz+PT09vT0+PT0+fb2
+vf3+vf3+/r6/Pz8/f39/v///wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEKAP8ALAAAAAAQABAAAAj+AGsJrIXpy4os
V6DQCTVwYKsuRxyIQfEiRgkQf2YNhBWCSw8DMN6kYdLigRRFA8PcKJBh0qpVrmp1qmKliaZa
lyAYQKFnyhoSg2S9YsWGgRpVY5B8qGRKkCUhtQ5xoPRJho5IUc6oqNX06SgnErTUynEATqNN
arg6PeGCgIAttdpsgiSJ0x21lkwAUSACUy0ytBg9CSCHKyBLPGDFKRQhVocfYBylWOLJlB/E
AusgSBQoD59SWLzY2YMEzQRDSmwssFCGgqhamWiw+LGI1KlToOYMILKjz8BHGABc2FDER4IK
NUbgaVjLkZEZOIYEaeBBAyLmAlMBomLGTRJCqBoCBgQAOw==
EOF
    }
}

sub find_street {
    my($strname) = @_;
    if ($strname =~ /^\(/ || $strname =~ /^\s*$/) {
	main::status_message("Die Straﬂe <$strname> hat keinen offiziellen Namen", "err");
	return;
    }
    $strname =~ s{\[.*\]}{}g; # remove special [...] parts
    $strname =~ s{:\s+.*}{}g; # also remove everything after ":"
    my($street, @subcityparts) = Strasse::split_street_citypart($strname);
    if (!@subcityparts) {
	my $plz = PLZ->new;
	my @res = $plz->look($street);
	@subcityparts = map { $_->[PLZ::LOOK_CITYPART] } @res;
    }
    if (!@subcityparts) {
	main::status_message("Die Straﬂe <$strname> konnte in der BBBike-Datenbank nicht gefunden werden.", "err");
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
    warn "Translated @$cityparts -> $supercitypart ...\n" if $DEBUG;

    my $short = {"Friedrichshain-Kreuzberg" => "FrKr",
		 'Charlottenburg-Wilmersdorf' => "Chawi",
		 'Mitte' => 'Mitte',
		}->{$supercitypart};
    if (!$short) {
	main::status_message("F¸r den Bezirk $supercitypart existieren noch keine Eintr‰ge im Bezirkslexikon", "err");
	return;
    }

    $street =~ s{(s)tr\.}{$1traﬂe}i;
    # Cannot use BBBikeUtil::umlauts_* here, because of special rules
    # used in the LuiseBerlin html filename generation
    my $kill_umlauts = {"‰" => "ae",
			"ˆ" => "oe",
			"¸" => "ue",
			"ﬂ" => "ss",
			"ƒ" => "Ae",
			"÷" => "Oe",
			"‹" => "Ue",
			"È" => "_",
			"Ë" => "_",
			"Î" => "_",
			"·" => "_",
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
    my($street, $cityparts);
    if ($args{cityparts}) {
	($street, $cityparts) = ($args{street}, $args{cityparts});
    } else {
	($street, $cityparts) = find_street($args{street});
    }

    if (!defined $street) {
	return;
    }

    my $url = eval {
## XXX Yahoo search sometimes works, e.g. if there are no umlauts in the
## search term. But the street entries in luise-berlin ceased to exist
## since 2008-12, so it's probably better to always fallback to Google
## Search and use the Google cache.
# 	do_yahoo_search(street => $street,
# 			cityparts => $cityparts);
    };
    if ($url) {
	start_browser($url);
    } elsif ($@) {
	main::status_message($@, "err");
    } else {
	#main::status_message("Die Straﬂe <$street> konnte ¸ber die Google-Such-API nicht gefunden werden.", "info");
	my $fallback_url = "http://www.google.com/search?";
	require CGI;
	CGI->import('-oldstyle_urls');
	my @queries = construct_queries(street => $street, cityparts => $cityparts);
	my $qs = CGI->new({ 'q' => $queries[0]->{query} })->query_string;
	start_browser($fallback_url . $qs);
    }
}

sub construct_queries {
    my(%args) = @_;
    my @queries;
    my $street = $args{street};
    my @cityparts = @{ $args{cityparts} };
    $street =~ s{(s)tr\.}{$1traﬂe}ig;
    $street =~ s{-}{ }g;
    for my $citypart (@cityparts) {
	my $street_citypart = "$street in $citypart";
	# Unfortunately there seems to be a lot of encoding issues
	# Maybe best to use the ersatz notation for umlauts?
	my $query = qq{allintitle:"}. $street_citypart . qq{" } .
	    ## Adding "www." does not help but seems to make things
	    ## worse. E.g. did not find Baerwaldstraﬂe in Kreuzberg, maybe
	    ## because the search string was too long?
	    #join(" OR ", map { ("site:$_", "site:www.$_") }
	    join(" OR ", map { "site:$_" }
		 qw(luise-berlin.de
		    berlinchronik.de
		    berlin-chronik.de
		    berlingeschichte.de
		    berlin-geschichte.de
		    berliner-lesezeichen.de
		    berlin-topographie.de
		    berlinische-monatsschrift.de
		    berlinvisite.de
		    berlin-visite.de
		    berlin-ehrungen.de
		    berlinhistory.de
		  ));
	push @queries, { query => $query, street_citypart => $street_citypart };
    }
    @queries;
}

# Since 2011-04 the old yahoo websearch api does not work anymore. See
# http://developer.yahoo.com/search/web/V1/webSearch.html
sub do_yahoo_search {
    my(%args) = @_;

    if (!eval q{ use Yahoo::Search; 1 }) {
	return if $already_tried_Yahoo_Search;
	$already_tried_Yahoo_Search = 1;
	require BBBikeHeavy;
	BBBikeHeavy::perlmod_install_advice("Yahoo::Search");
	return;
    }
    if (!eval q{ use String::Similarity; 1 }) {
	return if $already_tried_String_Similarity;
	$already_tried_String_Similarity = 1;
	require BBBikeHeavy;
	BBBikeHeavy::perlmod_install_advice("String::Similarity");
	return;
    }

    my @queries = construct_queries(%args);
    my @results;
    for my $query_def (@queries) {
	my($query, $street_citypart) = @{$query_def}{qw(query street_citypart)};
	if ($DEBUG) {
	    require Devel::Peek; Devel::Peek::Dump($query);
	}
	my @raw_results = Yahoo::Search->Results(Doc => $query,
						 AppId => "BBBike_LuiseBerlin_" . $BBBike::VERSION,
						);
	for my $result (@raw_results) {
	    my $cooked_title = $result->Title; # XXX strip HTML entities
	    push @results, { title        => $result->Title,
			     cooked_title => $cooked_title,
			     url          => $result->Url,
			     similarity   => String::Similarity::similarity($cooked_title, $street_citypart),
			   };
	}
    }
    @results = sort { $b->{similarity} <=> $a->{similarity} } @results;
    if ($DEBUG && $DEBUG >= 2) {
        require Data::Dumper;
	print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\@results],[qw()])->Indent(1)->Useqq(1)->Dump;
    }

    $results[0]->{url};
}

# Google no longer provides an API
# See also http://search.cpan.org/~lbrocard/WWW-Search-Google-0.23/Google.pm
sub do_google_search {
    return;

    my(%args) = @_;

    if (!eval q{ use WWW::Search::Google; 1 }) {
	return if $already_tried_WWW_Search_Google;
	$already_tried_WWW_Search_Google = 1;
	require BBBikeHeavy;
	BBBikeHeavy::perlmod_install_advice("WWW::Search::Google");
	return;
    }
    if (!eval q{ use String::Similarity; 1 }) {
	return if $already_tried_String_Similarity;
	$already_tried_String_Similarity = 1;
	require BBBikeHeavy;
	BBBikeHeavy::perlmod_install_advice("String::Similarity");
	return;
    }

    my $my_api_key = $api_key;
    my $google_api_key_file = "$ENV{HOME}/.googleapikey";
    if (open(APIKEY, $google_api_key_file)) {
	$my_api_key = <APIKEY>;
	$my_api_key =~ s{[\r\n\s+]}{}g;
	close APIKEY;
	warn "Loaded Google API key from $google_api_key_file...\n" if $DEBUG;
    }
    my $search = WWW::Search->new("Google", key => $my_api_key);
    my @queries = construct_queries(%args);
    my @results;
    for my $query_def (@queries) {
	my($query, $street_citypart) = @{$query_def}{qw(query street_citypart)};
	if ($DEBUG) {
	    require Devel::Peek; Devel::Peek::Dump($query);
	}
	## Usage of encode should not be necessary here!
	$query = encode("utf-8", $query) if $] == 5.008 || $] >= 5.010; # why only these perl versions?
	if ($DEBUG) {
	    Dump $query;
	    require Data::Dumper;
	    print STDERR "Google query term:\n$query\n";
	}
	$search->native_query($query);
	while(my $result = $search->next_result) {
	    (my $cooked_title = $result->title) =~ s{<b>}{}g;
	    ($cooked_title = $cooked_title) =~ s{</b>}{}g;
	    decode("utf-8", $cooked_title);
	    push @results, { title        => $result->title,
			     url          => $result->url,
			     cooked_title => $cooked_title,
			     similarity   => String::Similarity::similarity($cooked_title, $street_citypart),
			   };
	}
	
    }
    @results = sort { $b->{similarity} <=> $a->{similarity} } @results;
    if ($DEBUG && $DEBUG >= 2) {
        require Data::Dumper;
	print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\@results],[qw()])->Indent(1)->Useqq(1)->Dump;
    }

    $results[0]->{url};
}

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    WWWBrowser::start_browser($url);
}

sub kill_umlauts {
    my $s = shift;
    my $kill_umlauts = {"‰" => "ae",
			"ˆ" => "oe",
			"¸" => "ue",
			"ﬂ" => "ss",
			"ƒ" => "Ae",
			"÷" => "Oe",
			"‹" => "Ue",
			"È" => "e",
			"Ë" => "e",
			"Î" => "e",
			"·" => "a",
		       };
    my $left_part = join "", keys %$kill_umlauts;
    $s =~ s{([$left_part])}{$kill_umlauts->{$1}}ge;
    $s;
}

sub show_street_menu {
    my(%args) = @_;
    my $w = $args{widget};
    if (Tk::Exists($w->{"LuiseBerlinStreetMenu"})) {
	$w->{"LuiseBerlinStreetMenu"}->destroy;
    }
    my $link_menu = $w->Menu(-title => "Luise-Berlin",
			     -tearoff => 0);
    $link_menu->command
	(-label => "Straﬂeneingabe",
	 -command => sub {
	     enter_dialog();
	 }
	);
    $w->{"LuiseBerlinStreetMenu"} = $link_menu;

    my $e = $w->XEvent;
    $link_menu->Post($e->X, $e->Y);
    Tk->break;
}

sub enter_dialog {
    my $tl = $main::top->Toplevel(-title => "Straﬂeneingabe Luise-Berlin");
    my $str;
    my $citypart;
    my $e = $tl->LabEntry(-label => "Straﬂe", -labelPack => [-side => "left"], -textvariable => \$str)->pack;
    $tl->LabEntry(-label => "Bezirk (optional)", -labelPack => [-side => "left"], -textvariable => \$citypart)->pack;
    $tl->Button(-text => "Suche",
		-command => sub {
		    launch_street_url(street => $str,
				      cityparts => [$citypart],
				     );
		})->pack;
    $e->focus;
}

return 1 if caller;

die "The command line interface does not work anymore, as Google and Yahoo search APIs do not work anymore";

sub batch {
    my($file) = @_;
    require LWP::UserAgent;
    require File::Temp;
    my $tempdir = File::Temp::tempdir("luiseberlin_XXXXXXXX", TMPDIR => 1); # no cleanup
    my @urls;
    my @failures;
    open my $fh, "<", $file
	or die "Can't open $file: $!";
    binmode $fh; # assume iso-8859-1
    while(<$fh>) {
	chomp;
	my($str,$citypart) = split /[\t\|]/, $_;
	if (defined $citypart && $citypart ne "") {
	    $str .= " ($citypart)";
	}

	my($street, $cityparts) = find_street($str);
	if (defined $street) {
	    print STDERR "Do google search for $street/$cityparts...\n";
	    my $url = eval {
		do_google_search(street => $street,
				 cityparts => $cityparts);
	    };
	    if ($url) {
		push @urls, [$str, $url];
	    } else {
		push @failures, [$str, "Not found via Google"];
	    }
	} else {
	    push @failures, [$str, "No citypart match"];
	}
    }
    close $fh;

    my $ua = LWP::UserAgent->new;
    my $i = 0;
    for my $urldef (@urls) {
	my($str, $url) = @$urldef;
	print STDERR "Street: $str, URL: $url...\n";
	my $resp = $ua->get($url);
	if ($resp->is_success) {
	    $i++;
	    my $outfile = sprintf "%s/%04d.html", $tempdir, $i;
	    open my $ofh, ">", $outfile
		or die "Cannot write to $outfile";
	    binmode $ofh;
	    print $ofh $resp->content;
	    close $ofh or die $!;
	}
    }

    if (@failures) {
	require Data::Dumper;
	print STDERR Data::Dumper->new([\@failures],[qw(failures)])->Indent(1)->Useqq(1)->Dump;
    }
}

{
    require Getopt::Long;

    no strict 'refs';
    *{"main::status_message"} = sub {
	my($msg, $severity) = @_;
	if ($severity eq 'die') {
	    die "$msg\n";
	} else {
	    warn "$msg\n";
	}
    };

    my $file;
    my $disclaimer = <<EOF;
NOTE that the Google Search API does not work anymore
and the Yahoo Search API (or the perl module Yahoo::Search)
has serious problems with umlauts.
EOF
    Getopt::Long::GetOptions("f|file=s" => \$file,
			     "q" => sub { $DEBUG = 0 },
			     "debug!" => sub { $DEBUG = 2 },
			    )
	    or die <<EOF;
$disclaimer

usage: $0 [-q] [-debug] [-f file | street cityparts]

-f file: batch processing, where file is a Berlin.coords.data-styled
         file (street "|" citypath ...) 
EOF
    if ($file) {
	batch($file);
    } else {
	warn $disclaimer;
	my $street = shift @ARGV;
	my @cityparts = @ARGV;
	my $url = do_yahoo_search(street => $street,
				  cityparts => [@cityparts],
				 );
	print "$url\n";
    }
}

__END__
