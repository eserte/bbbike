#!/usr/bin/perl

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Getopt::Long;

my $do_validate;
GetOptions("validate!" => \$do_validate)
    or die "usage!";

my $schema;
if ($do_validate) {
    require Kwalify;
    require YAML::Syck;
    my $schema_file = "$FindBin::RealBin/../misc/bbd.kwalify";
    $schema = YAML::Syck::LoadFile($schema_file);
}

use Strassen::Core;

my $data_file = shift or die "bbd file?";
my $s = Strassen->new($data_file, UseLocalDirectives => 1);
my $res = { global_directives => $s->get_global_directives, data => [] };
my $data = $res->{data};

$s->init;
while() {
    my $r = $s->next;
    last if !@{ $r->[Strassen::COORDS] };
    push @$data, { name => $r->[Strassen::NAME],
		   category => $r->[Strassen::CAT],
		   coords => [map {
		       my($x,$y) = split /,/, $_;
		       +{ 'x' => $x, 'y' => $y };
		   } @{ $r->[Strassen::COORDS] }],
		   directives => $s->get_directives,
		 };
}

if ($schema) {
    print STDERR "Validating $data_file... ";
    Kwalify::validate($schema, $res);
    print STDERR "OK\n";
} else {
    require YAML::Syck;
    print YAML::Syck::Dump($res);
}
