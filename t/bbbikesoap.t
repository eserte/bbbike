#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikesoap.t,v 1.2 2003/06/23 22:04:48 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use Data::Dumper;
use Getopt::Long;
use FindBin;
use Carp qw(cluck);

BEGIN {
    if (!eval q{
	use Test;
	use SOAP::Lite;
	use FreezeThaw qw(cmpStr cmpStrHard freeze);
	1;
    }) {
	(my $err = $@) =~ s/\n//g;
	print "# tests only work with the following modules installed: Test, SOAP::Lite and FreezeThaw: $err\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

use vars qw(@bbbikesoap_methods @adr);
BEGIN {
    @bbbikesoap_methods =
	qw(get_address_coords get_address_coords_obj
	   get_route get_route_obj
	   get_route_lengths get_route_lengths_obj
	  );
}

BEGIN {
    if ($] == 5.6) {
	print "# tests do not work on 5.6.0 due to unicode issues...";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

BEGIN { plan tests => 37, todo => [2..1+@bbbikesoap_methods] }

my $tmpdir = "$FindBin::RealBin/tmp/bbbikesoap";

# XXX use probably from BBBikeVar.pm
my $proxy = ($ENV{HOST} =~ /herceg.de/ ?
#	     "http://localhost/soapbbbike" : # modperl is unstable...
	     "http://localhost/~eserte/bbbike/cgi/bbbikesoapserver.cgi" :
#	     "http://bbbikesoap.extra.onlineoffice.de"
#	     "http://194.140.111.226:8080/soapbbbike"
	     "http://mom/soapbbbike"
	    );
my $uri   = "BBBikeSOAP";

my %can;
my $create;
my $test_file = 0;
my $v;

push @adr,
           "{street => 'Stromstrasse'}", # verschiedene Schreibweisen
           "{street => 'Stromstraße'}",
           "{street => 'Stromstr.'}",
           "{street => 'Dudenstr'}",
           "{street => 'Sonntagstr'}",
           "{street => 'Blücherstr.'}",
           "{street => 'Heerstr.', citypart => 'Spandau'}",
           "{street => 'Kurfürstendamm', citypart => 'charlottenburg'}",
           "{street => 'Methfesselstr.'}",
           "{street => 'Alexanderplatz'}",
;

my @adr_complete;
push @adr_complete,
    "{'zip' => '10965','coordtype' => 'hafas','citypart' => 'Kreuzberg','x' => '8982','y' => '8781','street' => 'Dudenstr.'}",
    "{'coordtype' => 'hafas','citypart' => 'Spandau','x' => '1381','y' => '11335','street' => 'Heerstr.'}",
    "{'zip' => '10245','coordtype' => 'hafas','citypart' => 'Friedrichshain','x' => '14535','y' => '11327','street' => 'Sonntagstr.'}",
    ;

if (!GetOptions("create!" => \$create,
		"proxy=s" => \$proxy,
		"uri=s"   => \$uri,
		"v+"      => \$v,
	       )) {
    die "Usage: $0 [-create] [-proxy proxy] [-uri uri] [-v]";
}

if ($create) {
    if (!-d $tmpdir) {
	mkdir($tmpdir,0755) or die "Can't create tmp directory $tmpdir: $!";
    }
}

my $soap = SOAP::Lite->proxy($proxy);
ok(!!$soap, 1);
$soap->uri($uri) if $uri;

# XXX Can does not work??? See "todo" above.
foreach my $method (@bbbikesoap_methods) {
    $can{$method} = $soap->can($method);
    ok(ref $can{$method} eq 'CODE', 1);
}

open(DEBUG_OLD, ">/tmp/test_bbbikesoap.t.old.log");
open(DEBUG_NEW, ">/tmp/test_bbbikesoap.t.new.log");

foreach (@adr) {
    ok(cmp_soap("get_address_coords($_)"), 0, "While checking functional interface with $_");
    ok(cmp_soap("get_address_coords($_, '-coordtype' => 't99')"), 0, "While checking functional interface with $_ and coordtype t99");
}

foreach (@adr_complete) {
    ok(cmp_soap("get_crossings($_)"), 0);
}

ok(cmp_soap("get_route($adr_complete[0], $adr_complete[1])"), 0);

# existing (Astor)
ok(cmp_soap("get_cinema_address(501)"), 0);

# non-existing
ok(cmp_soap("get_cinema_address(471142)"), 0);

ok(cmp_soap("get_nearest_cinema_from_list_by_id($adr_complete[0], [501,502,506])"), 0);

# ignore non existing
ok(cmp_soap("get_nearest_cinema_from_list_by_id($adr_complete[0], [507,471142,508,509])"), 0);

my $res = $soap->get_nearest_cinema(eval $adr_complete[0], 5)->result;
ok(scalar @$res, 5);
ok(cmp_soap("get_nearest_cinema($adr_complete[0], 5)"), 0);

# XXX Chaos... warum stirbt Apache eigentlich fast immer bei den
# _obj-Methoden? Warum stirbt Apache manchmal bei den anderen Methoden,
# aber schafft es anscheinend, ein retry zu machen, so dass OK herauskommt (?)

if (0) {
# object interface
foreach (@adr) {
    ok(cmp_soap("get_address_coords_obj(bless($_, 'BBBikeSOAP::Address'))"), 0, "while checking OO interface with $_");
}
ok(cmp_soap("get_route_obj(bless({'zip' => '10965','coordtype' => 'hafas','citypart' => 'Kreuzberg','x' => '8982','y' => '8781','street' => 'Dudenstr.'}, 'BBBikeSOAP::Hop'), bless({'zip' => '10245','coordtype' => 'hafas','citypart' => 'Friedrichshain','x' => '14535','y' => '11327','street' => 'Sonntagstr.'}, 'BBBikeSOAP::Hop'))"), 0);

ok(cmp_soap("get_route_lengths({'zip' => '10965','coordtype' => 'hafas','citypart' => 'Kreuzberg','x' => '8982','y' => '8781','street' => 'Dudenstr.'},[{'zip' => '10245','coordtype' => 'hafas','citypart' => 'Friedrichshain','x' => '14535','y' => '11327','street' => 'Sonntagstr.'},{'zip' => '10243','coordtype' => 'hafas','citypart' => 'Friedrichshain','x' => '13467','y' => '11787','street' => 'Gubener Str.'}]);"), 0);
}

close DEBUG_OLD;
close DEBUG_NEW;

sub call_soap_method {
    my($method_with_args) = @_;
    my($method) = $method_with_args =~ /\s*(\w+)/;
    $can{$method} = $soap->can($method) unless exists $can{$method};
    my $res = eval "\$soap->$method_with_args";
    if (!ref $res) {
	cluck $@;
    }
    if (ref $res && $res->fault) {
	cluck $res->faultcode, " ", $res->faultstring;
    }
    if (ref $res && !$soap->transport->is_success) {
	cluck "Transport error: " . $soap->transport->status;
    }
    return ref $res ? $res->result : undef;

    # XXX weil can nicht funktioniert, funktioniert der Rest auch nicht...
    $@                               ? warn(join "\n", "--- SYNTAX ERROR ---", $@, '') :
    $can{$method} && !UNIVERSAL::isa($res => 'SOAP::SOM')
                                     ? return $res :
    defined($res) && $res->fault     ? warn(join "\n", "--- SOAP FAULT ---", $res->faultcode, $res->faultstring, '') :
    !$soap->transport->is_success    ? warn(join "\n", "--- TRANSPORT ERROR ---", $soap->transport->status, '') :
                                       warn(join "\n", "--- SOAP RESULT ---", Dumper($res->result), '');
    undef;
}

sub cmp_soap {
    my($soap_method) = @_;
    my $file = ++$test_file;

    if ($create) {
	open(T, ">$tmpdir/$file") or die "Can't create $tmpdir/$file: $!";
	my $obj = call_soap_method($soap_method);
	my $out = Data::Dumper->Dump([$obj],['x']);
	$out = substr($out, 4);
	print T $out;
	if ($v) {
	    print "$soap_method: $out\n";
	}
	close T;
    }

    open(T, "$tmpdir/$file") or die "Can't open $tmpdir/$file: $!. Please use the -create option first and check the results in $tmpdir!\n";
    #binmode T;
    my $buf = join '', <T>;
#warn $buf;
    close T;

    my $old_obj = eval $buf;
    my $new_obj = call_soap_method($soap_method);

    my $old_freeze = freeze($old_obj);
    my $new_freeze = freeze($new_obj);
    my $ret = $old_freeze cmp $new_freeze;
    if ($ret != 0) {
	print DEBUG_OLD freeze($old_freeze), "\n";
	print DEBUG_OLD Data::Dumper->Dumpxs([$old_obj],['x']);
	print DEBUG_NEW freeze($new_freeze), "\n";
	print DEBUG_NEW Data::Dumper->Dumpxs([$new_obj],['x']);
    }
    $ret;
}

__END__
