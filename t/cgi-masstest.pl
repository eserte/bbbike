#!perl -w
use strict;
use WWW::Mechanize;
use WWW::Mechanize::FormFiller;
use URI::URL;
use Tie::File;
use Fcntl 'O_RDONLY';
use Getopt::Long;
use FindBin;
use Safe;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");
use Strassen::Util;

my($cgi, $datadir, $streetlist, $plz, $imagetype);

my $city = "b";
my $fork = 4;
if (!GetOptions("city=s" => \$city,
		"fork=i" => \$fork,
		"cgi=s"  => \$cgi,
	       )) {
    die "usage: $0 [-city b|m] [-fork number_of_processes]";
}

if ($city eq 'm') { # München
    $datadir = "$FindBin::RealBin/../projects/radlstadtplan_muenchen/data_Muenchen_DE";
    $streetlist = "$datadir/strassenliste";
    if (!defined $cgi) {
	$cgi = 'http://www/%7Eeserte/radlstadtplan/cgi-bin/radlstadtplan.cgi';
    }
    $imagetype = "ascii";
} else { # $city eq 'b'
    $datadir = "$FindBin::RealBin/../data";
    $streetlist = "$datadir/Berlin.coords.data";
    if (!defined $cgi) {
	if (defined $ENV{BBBIKE_TEST_CGIURL}) {
	    $cgi = $ENV{BBBIKE_TEST_CGIURL};
	} elsif (defined $ENV{BBBIKE_TEST_CGIDIR}) {
	    $cgi = $ENV{BBBIKE_TEST_CGIDIR} . "/bbbike.cgi";
	} else {
	    $cgi = 'http://www/bbbike/cgi/bbbike.cgi';
	}
    }
    require PLZ;
    $plz = PLZ->new($streetlist);
    $imagetype = "png";
}

for my $i (1 .. $fork) {
    if ($i == $fork || fork == 0) {
	warn "Process $$ started...\n";

	tie my @streets, "Tie::File", $streetlist, mode => O_RDONLY
	    or die "Can't open $streetlist: $!";

	my $agent = WWW::Mechanize->new();
	my $formfiller = WWW::Mechanize::FormFiller->new();
	$agent->env_proxy();

	while(1) {
	    eval {
	    BLOCK: {
		    $agent->get($cgi);
		    $agent->form(1)
			if $agent->forms and scalar @{$agent->forms};
		    my $start = $streets[rand $#streets];
		    my $ziel  = $streets[rand $#streets];
		    if ($plz) {
			$^W = 0;

			my @f;
			@f = split "\Q$PLZ::sep\E", $start;
			next if ($f[PLZ::FILE_COORD()] eq '');
			$start = $f[0];

			@f = split "\Q$PLZ::sep\E", $ziel;
			next if ($f[PLZ::FILE_COORD()] eq '');
			$ziel  = $f[0];
		    }
		    print STDERR "$start => $ziel ... " .
			($fork > 1 ? "\n" : "");

		    $agent->current_form->value('start', $start);
		    $agent->current_form->value('ziel',  $ziel);
		    $agent->submit();
		    $agent->response->is_success or do {
			warn "Error on first submit";
			next;
		    };

		    if ($agent->content =~ /genaue.*stra.*e.*w.*hlen/i) {
			$agent->submit();
			$agent->response->is_success or do {
			    warn "Error after 'Genaue ...straße wählen' page";
			    next;
			};
		    }

		    if ($agent->content !~ /genaue kreuzung angeben/i) {
			# Intermediate page
			$agent->submit();
			$agent->response->is_success or do {
			    warn "Error on submit";
			    next;
			};
		    }

		    $agent->submit();
		    $agent->response->is_success or do {
			warn "Error on second submit";
			next;
		    };
		    $agent->current_form->value('imagetype', $imagetype);
		    $agent->submit();
		    $agent->response->is_success or do {
			warn "Error on third submit";
			next;
		    };
		    if ($imagetype eq 'ascii') {
			$agent->response->content_type eq 'text/plain' or do {
			    warn "Unexpected content type " . $agent->response->content_type;
			    next;
			}
		    } elsif ($imagetype eq 'png') {
			$agent->response->content_type eq 'image/png' or do {
			    warn "Unexpected content type " . $agent->response->content_type;
			    next;
			}
		    }

		    if ($fork == 1) {
			$agent->back;
			my $uri = $agent->uri;
			$uri .= "&output_as=perldump";
			$agent->get($uri);
			$agent->response->is_success or do {
			    warn "Error on perldump";
			    next;
			};
			my $pd = $agent->content;
			my $cpt = Safe->new;
			my $out = $cpt->reval($pd);
			my $route_len = $out->{Len};
			my $direct_len = Strassen::Util::strecke_s($out->{Path}->[0], $out->{Path}->[-1]);
			printf STDERR "%.1f km (+%d%%)", $route_len/1000, ($route_len/$direct_len*100 - 100);
		    }
		}
		if ($fork == 1) {
		    print STDERR "\n";
		}
	    };
	    if ($@) {
		warn "Request failed: $@\nCurrent agent URL: " . $agent->uri;
	    }
	}
    }
}
