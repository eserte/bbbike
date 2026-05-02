#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::RealBin/..", "$FindBin::RealBin/../lib";
use Doit;
use Getopt::Long;
use JSON::PP;
use File::Spec;
use BBBikeUtil qw(bbbike_root bbbike_aux_dir);

sub usage {
    my $msg = shift;
    warn "$msg\n" if $msg;
    die <<EOF;
usage: $0 --output-dir directory
EOF
}

my $doit = Doit->init;
$doit->add_component('file');

my $output_dir;
GetOptions(
    "output-dir=s" => \$output_dir,
) or usage();

usage("Missing --output-dir") if !$output_dir;
if (!-d $output_dir) {
    die "Output directory '$output_dir' does not exist.\n";
}

my $root = bbbike_root();
my $aux_dir = bbbike_aux_dir();

my @input_files;
# data/*-orig
push @input_files, glob(File::Spec->catfile($root, "data", "*-orig"));
# data/temp_blockings/bbbike-temp-blockings.pl
push @input_files, File::Spec->catfile($root, "data", "temp_blockings", "bbbike-temp-blockings.pl");
# bbbike-aux/bbd/fragezeichen_lowprio.bbd
if ($aux_dir && -d $aux_dir) {
    push @input_files, File::Spec->catfile($aux_dir, "bbd", "fragezeichen_lowprio.bbd");
}

my @newspaper_urls;
my @bvv_urls;

foreach my $file (@input_files) {
    if (!-f $file) {
        warn "File '$file' not found, skipping...\n";
        next;
    }
    if (open(my $fh, "<", $file)) {
        while (<$fh>) {
            if (/^#:\s*by:?\s+(http\S+(?:morgenpost|tagesspiegel|berliner-zeitung|nd-aktuell|entwicklungsstadt)\.de[^\s\?]+)/) {
                push @newspaper_urls, $1;
            }
            if (m{^#:\s*by:?\s+(https?://(www\.berlin\.de/ba-.*/politik.*/bezirksverordnetenversammlung/online/\S+|bvv-.*\.berlin\.de/pi-r/\S+))}) {
                push @bvv_urls, $1;
            }
        }
        close $fh;
    } else {
        warn "Could not open '$file': $!, skipping...\n";
    }
}

warn "Found " . scalar(@newspaper_urls) . " Newspaper URLs\n";
warn "Found " . scalar(@bvv_urls) . " BVV URLs\n";

my $json_encoder = JSON::PP->new->utf8->canonical->pretty;

my $newspaper_file = File::Spec->catfile($output_dir, "newspaper_urls.json");
$doit->file_atomic_write($newspaper_file, sub {
    my $nfh = shift;
    print $nfh $json_encoder->encode(\@newspaper_urls);
});

my $bvv_file = File::Spec->catfile($output_dir, "bvv_urls.json");
$doit->file_atomic_write($bvv_file, sub {
    my $bfh = shift;
    print $bfh $json_encoder->encode(\@bvv_urls);
});

__END__

=head1 NAME

extract-tampermonkey-urls.pl - extract URLs for Tampermonkey scripts

=head1 SYNOPSIS

    ./extract-tampermonkey-urls.pl --output-dir ~/www/tampermonkey

=head1 DESCRIPTION

This script extracts newspaper and BVV URLs from BBBike data files and
saves them as JSON files. These JSON files are used by Tampermonkey
scripts to highlight links in the browser.

=head2 TAMPERMONKEY SETUP

To use the generated JSON files with the Tampermonkey scripts:

=over 4

=item 1. Install the Tampermonkey extension in your browser (Firefox, Chrome, etc.).

=item 2. Add the scripts from F<misc/tampermonkey/*.user.js> to Tampermonkey.
You can do this by clicking the Tampermonkey icon, choosing "Create a new script...",
and then pasting the content of the C<.user.js> file.

=item 3. Set up a local webserver or use a directory reachable by your browser to host the generated JSON files.
For example, if you have a local webserver running at C<http://localhost/~user/>,
you could set the output directory to C<~/public_html/tampermonkey>.

=item 4. In the Tampermonkey script settings (via the Tampermonkey menu in the browser),
set the C<urlListFile> to the URL of the corresponding JSON file
(e.g., C<http://localhost/~user/tampermonkey/newspaper_urls.json>).
By default, the script looks for a file on C<example.com>, so you I<must> change this setting.

=back

=head1 OPTIONS

=over 4

=item B<--output-dir> I<directory>

The directory where the JSON files will be saved. Mandatory.

=back

=head1 AUTHOR

Slaven Rezic

=cut
