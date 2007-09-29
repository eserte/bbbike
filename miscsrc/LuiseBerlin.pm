# -*- perl -*-

#
# $Id: LuiseBerlin.pm,v 1.20 2007/09/29 21:10:39 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (de): Straﬂen- und Bezirkslexikon des Luisenst‰dtischen Bildungsvereins (Luise-Berlin.de)
package LuiseBerlin;

use strict;
use vars qw($VERSION @ISA);
$VERSION = sprintf("%d.%02d", q$Revision: 1.20 $ =~ /(\d+)\.(\d+)/);

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

BEGIN {
    if (!eval q{ use WWW::Search::Google; 1 }) {
	require BBBikeHeavy;
	BBBikeHeavy::perlmod_install_advice("WWW::Search::Google");
	return;
    }
    if (!eval q{ use String::Similarity; 1 }) {
	require BBBikeHeavy;
	BBBikeHeavy::perlmod_install_advice("String::Similarity");
	return;
    }
}

use Encode;

use PLZ;
use Strassen::Strasse;
use WWWBrowser;

my $api_key = "pqCq16BQFHJ5jvhg6osutPlLWeSkd9ke";

use vars qw($DEBUG);
$DEBUG = 1;

use vars qw($icon);

sub register {
    _create_image();
    $main::info_plugins{__PACKAGE__ . ""} =
	{ name => "Luise-Berlin, Straﬂenlexikon",
	  callback => sub { launch_street_url(@_) },
	  icon => $icon,
	};
    $main::info_plugins{__PACKAGE__ . "_bezlex"} =
	{ name => "Luise-Berlin, Bexirkslexikon",
	  callback => sub { launch_bezlex_url(@_) },
	  icon => $icon,
	};
    main::status_message("Das Luise-Berlin-Plugin wurde registriert. Der Link erscheint im Info-Fenster.", "info")
	    if !$main::booting;
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
	main::status_message("Die Straﬂe <$street> konnte ¸ber Google nicht gefunden werden.", "err");
    }
}

sub do_google_search {
    my(%args) = @_;
    my $my_api_key = $api_key;
    my $google_api_key_file = "$ENV{HOME}/.googleapikey";
    if (open(APIKEY, $google_api_key_file)) {
	$my_api_key = <APIKEY>;
	$my_api_key =~ s{[\r\n\s+]}{}g;
	close APIKEY;
	warn "Loaded Google API key from $google_api_key_file...\n" if $DEBUG;
    }
    my $search = WWW::Search->new("Google", key => $my_api_key);
    my $street = $args{street};
    my @cityparts = @{ $args{cityparts} };
    $street =~ s{(s)tr\.}{$1traﬂe}ig;
    $street =~ s{-}{ }g;
    my @results;
    for my $citypart (@cityparts) {
	my $street_citypart = "$street in $citypart";
	# Unfortunately there seems to be a lot of encoding issues
	# Maybe best to use the ersatz notation for umlauts?
	my $query = qq{allintitle:"}. $street_citypart . qq{" } .
	    join(" OR ", map { ("site:$_", "site:www.$_") }
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
	if ($DEBUG) {
	    use Devel::Peek; Dump $query;
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
			     similarity   => similarity $cooked_title, $street_citypart,
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
		       };
    my $left_part = join "", keys %$kill_umlauts;
    $s =~ s{([$left_part])}{$kill_umlauts->{$1}}ge;
    $s;
}

return 1 if caller;

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
    Getopt::Long::GetOptions("f|file=s" => \$file,
			     "q" => sub { $DEBUG = 0 },
			     "debug!" => sub { $DEBUG = 2 },
			    )
	    or die <<EOF;
usage: $0 [-q] [-debug] [-f file | street cityparts]

-f file: batch processing, where file is a Berlin.coords.data-styled
         file (street "|" citypath ...) 
EOF
    if ($file) {
	batch($file);
    } else {
	my $street = shift @ARGV;
	my @cityparts = @ARGV;
	my $url = do_google_search(street => $street,
				   cityparts => [@cityparts],
				  );
	print "$url\n";
    }
}

__END__
