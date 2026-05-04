#!/usr/bin/perl -w
use strict;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin");
use Test::More;
use BBBikeTest;
use File::Temp qw(tempfile);
use Data::Dumper;

eval { require PDF::Create; };
if ($@) {
    plan skip_all => 'PDF::Create not installed';
}

my $info_et = pdfinfo_with_exiftool(__FILE__);
if (!$info_et) {
    plan skip_all => 'exiftool not available';
}

plan tests => 8;

my($fh, $filename) = tempfile(SUFFIX => ".pdf", UNLINK => 1);
close $fh;

my $pdf = PDF::Create->new(
    'filename'     => $filename,
    'Author'       => 'Slaven Rezic',
    'Title'        => 'BBBike Route',
    'Creator'      => 'Route::PDF version 1.23',
);
$pdf->new_page('MediaBox' => [ 0, 0, 595, 842 ]);
$pdf->close;

my $info = pdfinfo($filename);
my $info_et_pdf = pdfinfo_with_exiftool($filename);

ok($info_et_pdf, 'pdfinfo_with_exiftool returned data');
is($info_et_pdf->{Author}, $info->{Author}, 'Author matches');
is($info_et_pdf->{Title}, $info->{Title}, 'Title matches');
is($info_et_pdf->{Creator}, $info->{Creator}, 'Creator matches');
is($info_et_pdf->{Producer}, $info->{Producer}, 'Producer matches');
is($info_et_pdf->{Pages}, $info->{Pages}, 'Pages matches');
is($info_et_pdf->{'PDF version'}, $info->{'PDF version'}, 'PDF version matches');
is($info_et_pdf->{'File size'}, $info->{'File size'}, 'File size matches');

diag "pdfinfo: " . Dumper($info);
diag "pdfinfo_with_exiftool: " . Dumper($info_et_pdf);
