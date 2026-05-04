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
    plan skip_all => 'Image::ExifTool not available';
}

plan tests => 9;

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

my $info_poppler = pdfinfo_with_poppler($filename);
my $info_et_pdf = pdfinfo_with_exiftool($filename);

ok($info_et_pdf, 'pdfinfo_with_exiftool returned data');
is($info_et_pdf->{Author}, 'Slaven Rezic', 'Author matches');
is($info_et_pdf->{Title}, 'BBBike Route', 'Title matches');
is($info_et_pdf->{Creator}, 'Route::PDF version 1.23', 'Creator matches');
like($info_et_pdf->{Producer}, qr/^PDF::Create version \d+\.\d+/, 'Producer matches');
is($info_et_pdf->{Pages}, '1', 'Pages matches');
is($info_et_pdf->{'PDF version'}, '1.2', 'PDF version matches');
is($info_et_pdf->{'File size'}, '515 bytes', 'File size matches');
like($info_et_pdf->{'Page size'}, qr/595 x 842 pts \(A4\)/, 'Page size matches');

diag "pdfinfo_with_poppler: " . Dumper($info_poppler) if $info_poppler;
diag "pdfinfo_with_exiftool: " . Dumper($info_et_pdf);
