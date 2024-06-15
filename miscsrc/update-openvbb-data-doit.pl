#!/usr/bin/env perl
# -*- perl -*-

use FindBin;
use lib "$FindBin::RealBin/..";
use BBBikeUtil qw(bbbike_root);
my $bbbike_root;
BEGIN { $bbbike_root = bbbike_root }
use lib "$bbbike_root/lib", "$bbbike_root/plugins";

use Doit; # install from CPAN or do "git clone https://github.com/eserte/doit.git ~/src/Doit"
use Doit::Log;

use File::Temp qw(tempdir);
use Getopt::Long;
use List::Util qw(first);
use LWP::UserAgent;
use XML::LibXML;

return 1 if caller;

my $rss_feed = 'https://daten.berlin.de/taxonomy/term/477/all/feed';
my $min_stops_size = 5_000_000;
my $max_stops_size = 8_000_000; 

my $doit = Doit->init;
GetOptions(
    "precheck" => \my $precheck,
    "persistent-tmp" => \my $persistent_tmp,
)
    or die "usage: $0 [--dry-run] [--precheck] [--persistent-tmp]\n";

if ($precheck) {
    precheck();
    exit;
}

$doit->add_component('lwp');
$doit->add_component('git');

{
    my @changed_bbbike_files = $doit->git_get_changed_files(directory => $bbbike_root);
    if (first { $_ eq 'plugins/FahrinfoQuery.pm' } @changed_bbbike_files) {
	error "plugins/FahrinfoQuery.pm has uncommitted changes";
    }
}

my $tempdir;
if ($persistent_tmp) {
    $tempdir = "/tmp/update-openvbb-data-test";
    $doit->mkdir($tempdir);
} else {
    $tempdir = tempdir("update-openvbb-data-XXXXXXXX", TMPDIR => 1, CLEAN => 1);
}
$doit->lwp_mirror($rss_feed, "$tempdir/verkehr.rss");

my $rss_doc = XML::LibXML->load_xml(location => "$tempdir/verkehr.rss");
my $items = $rss_doc->find('/rss/channel/item[./title/.="VBB-Fahrplandaten via GTFS"]');
my $intermediate_link = $items->[0]->findvalue('./link');
if (!$intermediate_link) {
    error "No suitable link found in $rss_feed";
}

$doit->lwp_mirror($intermediate_link, "$tempdir/vbb-fahrplandaten-gtfs");
my $intermediate_doc = XML::LibXML->load_html(location => "$tempdir/vbb-fahrplandaten-gtfs", recover => 2);
my $openvbb_data_url = $intermediate_doc->findvalue('//div[@class="download-btn"]/a/@href');

## XXX not needed: resolve the redirect location
#my $ua = LWP::UserAgent->new;
#my $res = $ua->head($openvbb_data_url);
#$openvbb_data_url = $res->request->url;

$doit->lwp_mirror($openvbb_data_url, "$tempdir/GTFS.zip");
my $openvbb_download_size = int((-s "$tempdir/GTFS.zip")/1024/1024);

my $found_stops;
my $zip_list = $doit->info_qx("unzip", "-l", "$tempdir/GTFS.zip");
for my $zip_list_line (split /\n/, $zip_list) {
    if ($zip_list_line =~ /^\s*(\d+)\s+.*\s+stops\.txt$/) {
	my $stops_size = $1;
	if ($stops_size < $min_stops_size) {
	    error "Unusual stops.txt size (expected at least $min_stops_size): $zip_list_line";
	}
	if ($stops_size > $max_stops_size) {
	    error "Unusual stops.txt size (expected at most $max_stops_size): $zip_list_line";
	}
	$found_stops = 1;
	last;
    }
}
if (!$found_stops) {
    error "Did not found stops.txt in ZIP file. Contents:\n$zip_list";
}

my $this_year = (localtime())[5]+1900;
my $this_month = sprintf "%02d", (localtime())[4]+1;
my $old_year;
open my $fh, "$bbbike_root/plugins/FahrinfoQuery.pm" or error $!;
open my $ofh, ">", "$tempdir/FahrinfoQuery.pm" or error $!;
while(<$fh>) {
    if (/^#\s+Copyright / && !/\Q$this_year/) {
	s/(?= Slaven Rezic)/,$this_year/;
    }
    s/^(\$VERSION = ').*(';)/$1${this_year}.${this_month}$2/;
    s/^(my \$openvbb_download_size = ').*(';)/$1${openvbb_download_size}MB$2/;
    /^my \$openvbb_year = (\d+);/ and $old_year = $1;
    s/^(my \$openvbb_year = ).*(;)/$1${this_year}$2/;
    if (/^my \$openvbb_index = (\d+);/) {
	my $old_index = $1;
	my $new_index = $old_year != $this_year ? 1 : $old_index + 1;
	s/^(my \$openvbb_index = ).*(;)/$1${new_index}$2/;
    }
    s/^(my \$openvbb_data_url = ').*(';)/$1${openvbb_data_url}$2/;

    print $ofh $_;
}
if (!eval { $doit->info_system('diff', '-u', "$bbbike_root/plugins/FahrinfoQuery.pm", "$tempdir/FahrinfoQuery.pm") }) {
    $doit->copy("$tempdir/FahrinfoQuery.pm", "$bbbike_root/plugins/FahrinfoQuery.pm");
    $doit->system($^X, "-I$bbbike_root", "-I$bbbike_root/lib", "-I$bbbike_root/plugins", "-c", "$bbbike_root/plugins/FahrinfoQuery.pm");
    info "Please restart BBBike and test the VBB plugin";
} else {
    info "No changes needed";
}

sub precheck {
    require FahrinfoQuery;
    FahrinfoQuery::_check_download_url();
}

__END__
