#!/usr/bin/perl

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin",
	);

use LWP::UserAgent;
use HTML::TreeBuilder;
use URI::http;

use TelbuchDBApprox;

my $request;
# output gathered by the httpproxy:
$request = bless( {
                    '_protocol' => 'HTTP/1.1',
                    '_content' => 'orderby=PLZ&searchort=Berlin',
                    '_uri' => bless( do{\(my $o = 'http://www.cash-pool.de/result.asp')}, 'URI::http' ),
                    '_headers' => bless( {
                                           'proxy-connection' => 'keep-alive',
                                           'user-agent' => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.6) Gecko/20040113',
                                           'cache-control' => 'no-cache',
                                           'keep-alive' => '300',
                                           'accept' => 'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,ima
ge/png,image/jpeg,image/gif;q=0.2,*/*;q=0.1',
                                           'accept-language' => 'hr,de;q=0.8,en-us;q=0.5,en;q=0.3',
                                           'accept-encoding' => 'gzip,deflate',
                                           'content-length' => '28',
                                           'host' => 'www.cash-pool.de',
                                           'accept-charset' => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
                                           'content-type' => 'application/x-www-form-urlencoded',
                                           'pragma' => 'no-cache',
                                           'referer' => 'http://www.cash-pool.de/'
                                         }, 'HTTP::Headers' ),
                    '_method' => 'POST'
                  }, 'HTTP::Request' );

my $ua = LWP::UserAgent->new;
my $resp = $ua->request($request);

if (!$resp->is_success) {
    die "Failed to get list: " . $resp->content;
}

my $p = HTML::TreeBuilder->new;
$p->parse($resp->content);
$p->eof;
my $t = $p->look_down('_tag', 'td',
		      class => "td3");
die "Can't find table" if !$t;

my @rec;
my $tr = $t->parent;
while(1) {
    my @this_rec;
    for my $td ($tr->descendents) {
	push @this_rec, join "", $td->content_list;
    }
    push @rec, \@this_rec;
    $tr = $tr->right;
    last if !$tr;
    last if ($tr->descendents)[0]->attr("class") eq "tdhead2";
}

my $tb = TelbuchDBApprox->new;

for my $rec (@rec) {
    my($res) = $tb->search($rec->[1], $rec->[2]);
    if (defined $res->{Coord}) {
	print "$rec->[0], $rec->[1], $rec->[2] $rec->[3]\tX $res->{Coord}\n";
    }
}
