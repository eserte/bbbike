# -*- perl -*-

#
# $Id: LuiseBerlin.pm,v 1.11 2006/02/19 20:55:52 eserte Exp eserte $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

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

use WWW::Search::Google;
use Encode;
use String::Similarity;

use PLZ;
use Strassen::Strasse;
use WWWBrowser;

my $api_key = "pqCq16BQFHJ5jvhg6osutPlLWeSkd9ke";

use vars qw($DEBUG);
$DEBUG = 1;

sub register {
    $main::info_plugins{__PACKAGE__ . ""} =
	{ name => "Luise-Berlin, Straßenlexikon",
	  callback => sub { launch_street_url(@_) },
	};
    $main::info_plugins{__PACKAGE__ . "_bezlex"} =
	{ name => "Luise-Berlin, Bexirkslexikon",
	  callback => sub { launch_bezlex_url(@_) },
	};
    main::status_message("Das Luise-Berlin-Plugin wurde registriert. Der Link erscheint im Info-Fenster.", "info")
	    if !$main::booting;
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
    warn "Translated @$cityparts -> $supercitypart ...\n" if $DEBUG;

    my $short = {"Friedrichshain-Kreuzberg" => "FrKr",
		 'Charlottenburg-Wilmersdorf' => "Chawi",
		 'Mitte' => 'Mitte',
		}->{$supercitypart};
    if (!$short) {
	main::status_message("Für den Bezirk $supercitypart existieren noch keine Einträge im Bezirkslexikon", "err");
	return;
    }

    $street =~ s{(s)tr\.}{$1traße}i;
    # Cannot use BBBikeUtil::umlauts_* here, because of special rules
    # used in the LuiseBerlin html filename generation
    my $kill_umlauts = {"ä" => "ae",
			"ö" => "oe",
			"ü" => "ue",
			"ß" => "ss",
			"Ä" => "Ae",
			"Ö" => "Oe",
			"Ü" => "Ue",
			"é" => "_",
			"è" => "_",
			"á" => "_",
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
    my $my_api_key = $api_key;
    my $google_api_key_file = "$ENV{HOME}/.googleapikey";
    if (open(APIKEY, $google_api_key_file)) {
	$my_api_key = <APIKEY>;
	s{[\r\n\s+]}{}g;
	close APIKEY;
	warn "Loaded Google API key from $google_api_key_file...\n" if $DEBUG;
    }
    my $search = WWW::Search->new("Google", key => $my_api_key);
    my $street = $args{street};
    my @cityparts = @{ $args{cityparts} };
    $street =~ s{(s)tr\.}{$1traße}ig;
    $street =~ s{-}{ }g;
    my @results;
    for my $citypart (@cityparts) {
	my $street_citypart = "$street in $citypart";
	# Unfortunately there seems to be a lot of encoding issues
	# Maybe best to use the ersatz notation for umlauts?
	my $query = qq{allintitle:"}. $street_citypart . qq{" site:luise-berlin.de OR site:berlin-chronik.de OR site:berlingeschichte.de OR site:berliner-lesezeichen.de};
	if ($DEBUG) {
	    use Devel::Peek; Dump $query;
	}
	## Usage of encode should not be necessary here!
	$query = encode("utf-8", $query) if $] == 5.008; # why only this perl version?
	if ($DEBUG) {
	    Dump $query;
	    require Data::Dumper;
	    print STDERR "Google query term: ". Data::Dumper->new([$query],[qw()])->Indent(1)->Useqq(1)->Dump . "\n";
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

        #require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\@results],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

    $results[0]->{url};
}

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    WWWBrowser::start_browser($url);
}

sub kill_umlauts {
    my $s = shift;
    my $kill_umlauts = {"ä" => "ae",
			"ö" => "oe",
			"ü" => "ue",
			"ß" => "ss",
			"Ä" => "Ae",
			"Ö" => "Oe",
			"Ü" => "Ue",
			"é" => "e",
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
			    )
	    or die <<EOF;
usage: $0 [-q] [-f file | street cityparts]

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
