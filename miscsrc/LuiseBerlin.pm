# -*- perl -*-

#
# $Id: LuiseBerlin.pm,v 1.1 2005/10/15 10:54:42 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

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
	{ name => "Luise-Berlin",
	  callback => sub { launch_street_url(@_) },
	};
    main::status_message("Das Luise-Berlin-Plugin wurde registriert. Im Info-Fenster erscheint jetzt immer ein neuer Link.", "info");
}

sub launch_street_url {
    my(%args) = @_;
    my $strname = $args{street};
    if ($strname =~ /^\(/ || $strname =~ /^\s*$/) {
	main::status_message("Die Straße hat keinen offiziellen Namen", "err");
	return;
    }
    $strname =~ s{\[.*\]}{}g; # remove special [...] parts
    my($street, @cityparts) = Strasse::split_street_citypart($strname);
    if (!@cityparts) {
	my $plz = PLZ->new;
	my @res = $plz->look($street);
	@cityparts = map { $_->[PLZ::LOOK_CITYPART] } @res;
    }
    if (!@cityparts) {
	main::status_message("Die Straße konnte in der BBBike-Datenbank nicht gefunden werden.", "err");
	return;
    }

    my $url = eval {
	do_google_search(street => $street,
			 cityparts => \@cityparts);
    };
    if ($url) {
	main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
	WWWBrowser::start_browser($url);
    } elsif ($@) {
	main::status_message($@, "err");
    } else {
	main::status_message("Die Straße konnte nicht gefunden werden.", "err");
    }
}

sub do_google_search {
    my(%args) = @_;
    my $search = WWW::Search->new("Google", key => $api_key);
    my $street = $args{street};
    my @cityparts = @{ $args{cityparts} };
    $street =~ s{(s)tr\.}{$1traße}ig;
    my @results;
    for my $citypart (@cityparts) {
	my $street_citypart = "$street in $citypart";
	# usage of encode should not be necessary here!
	my $query = encode("utf-8", "allintitle:$street_citypart site:luise-berlin.de");
	#print STDERR $query, "\n";
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

return 1 if caller;

do_search(street => "Heerstr.",
	  cityparts => ["Charlottenburg", "Spandau"],
	 );

__END__
