# Generated automatically by make_task.pl
# test type: use_ok
use strict;
use warnings;
use Test::More 'no_plan';

sub module_exists ($) {
    my($filename) = @_;
    $filename =~ s{::}{/}g;
    $filename .= ".pm";
    return 1 if $INC{$filename};
    foreach my $prefix (@INC) {
	my $realfilename = "$prefix/$filename";
	if (-r $realfilename) {
	    return 1;
	}
    }
    return 0;
}

use_ok 'Tk', 800.000;
use_ok 'Tk::FireButton';
use_ok 'Tk::Pod', 2.8;
use_ok 'Tk::FontDialog';
use_ok 'Tk::JPEG';
use_ok 'Tie::Watch';
use_ok 'Tk::HistEntry';
use_ok 'Tk::Stderr';
use_ok 'Tk::Date';
use_ok 'Tk::PNG';
use_ok 'Tk::NumEntry', 2.06;
use_ok 'LWP::UserAgent';
use_ok 'LWP::Protocol::https';
use_ok 'XML::LibXML';
use_ok 'XML::Twig';
use_ok 'String::Approx', 2.7;
use_ok 'Storable';
use_ok 'DB_File';
use_ok 'MLDBM';
use_ok 'List::Permutor';
use_ok 'PDF::Create', 1.43;
use_ok 'Win32::API';
use_ok 'Win32::Registry';
use_ok 'Win32::Shortcut';
use_ok 'Class::Accessor';
use_ok 'Array::Heap';
use_ok 'IPC::Run';
use_ok 'Object::Iterate';
use_ok 'Tie::IxHash', 1.23;
use_ok 'CDB_File';
use_ok 'Geo::METAR';
use_ok 'Geo::Coder::Bing', 0.10;
use_ok 'Geo::Coder::OSM';
use_ok 'Text::Unidecode';
use_ok 'CGI', 3.46;
use_ok 'Tie::Handle::Offset';
use_ok 'Search::Dict', 1.07;
use_ok 'Unicode::Collate', 0.60;
