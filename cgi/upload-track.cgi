#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use CGI;
use Cwd qw(realpath);
use POSIX qw(strftime);

my $bbbike_rootdir = realpath "$FindBin::RealBin/..";
my $gps_upload_dir = "$bbbike_rootdir/tmp/www/upload-track";

my $q = CGI->new;
#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$q],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

my $data = $q->param("XForms:Model") || $q->param("POSTDATA");
#warn "GOT request:\n$data\n------------\n"; # debugging

my $isotime = strftime("%Y%m%d_%H%M%S", localtime);
if (!-d $gps_upload_dir) {
    mkdir $gps_upload_dir
	or error("Cannot create $gps_upload_dir: $!", "Store directory missing and cannot be created");
}

my $outfile = "$gps_upload_dir/$isotime.trk.json";
open my $fh, ">", "$outfile~"
    or error("Can't write to $outfile~: $!", "Write error (open)");
print $fh $data;
close $fh
    or error("While writing to $outfile:~ $!", "Write error (close)");

rename "$outfile~", $outfile
    or error("Can't rename $outfile~ to $outfile: $!", "Write error (rename)");

print $q->header('text/plain');
print "OK\n";

sub error {
    my($internal, $external) = @_;
    print $q->header('text/plain');
    print <<EOF;
An error occurred:
-----------------
$external
EOF
    warn $internal, "\n";
    exit;
}

__END__
