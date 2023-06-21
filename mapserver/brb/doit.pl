#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2023 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use FindBin;
use lib ("$FindBin::RealBin/../..", "$FindBin::RealBin/../../lib");
use Doit;
use Doit::Log;
use Doit::Util qw(copy_stat);
use Cwd qw(cwd realpath);
use Getopt::Long;
use Template;

use BBBikeVar;

my $dest_dir;
my %c;

sub _need_rebuild ($@) {
    my($dest, @srcs) = @_;
    return 1 if !-e $dest;
    for my $src (@srcs, __FILE__) {
	if (!-e $src) {
	    warning "$src does not exist";
	} else {
	    return 1 if -M $src < -M $dest;
	}
    }
    return 0;
}

sub compute_config {
    my($d) = @_;

    $c{SCOPES} = [qw(brb b inner-b wide p)];
    $c{LOCAL_BBBIKE_DIR} = realpath(cwd . "/../..");
    # computed config
    $c{BBBIKE_DATA_DIR}  = "$c{LOCAL_BBBIKE_DIR}/data";
    $c{BBBIKE_MISCSRC_DIR} = "$c{LOCAL_BBBIKE_DIR}/miscsrc";
    $c{MAPSERVER_DIR}    = "$c{LOCAL_BBBIKE_DIR}/mapserver/brb";
    $c{MAPSERVER_RELURL} = '/bbbike/mapserver/brb'; # XXX on live system /mapserver/brb; needs to be determined using bbbike cgi config or so
    $c{HOST}             = 'localhost'; # XXX needs to be determined by bbbike.cgi.config or so
    $c{MAPSERVER_URL}    = "http://$c{HOST}$c{MAPSERVER_RELURL}";
#	--define MAPSERVER_PROG_RELURL="$(MAPSERVER_PROG_RELURL)" \
#	--define MAPSERVER_PROG_URL="$(MAPSERVER_PROG_URL)" \
#	--define MAPSERVER_PROG_FSPATH="$(MAPSERVER_PROG_FSPATH)"
    $c{MAPSERVER_VERSION} = get_mapserver_version($d);
    $c{MAPSERVER_DRIVER}  = get_mapserver_driver($d);
    $c{IMAGE_DIR}         = "$c{LOCAL_BBBIKE_DIR}/images";
    $c{BBBIKE_HTML_RELURL} = "/bbbike/html"; # XXX on live system different; needs to be determined using bbbike cgi config or so
#	--define BBBIKE_URL="$(BBBIKE_URL)" \
#	--define BBBIKE_RELURL_ENC=`perl -MURI::Escape -e 'print uri_escape(shift)' $(BBBIKE_RELURL)` \
#	--define BBBIKE_URL_ENC=`perl -MURI::Escape -e 'print uri_escape(shift)' $(BBBIKE_URL)`
    $c{BBBIKE_CGI_RELURL} = '/bbbike/cgi'; # XXX on live system different; needs to be determined using bbbike cgi config or so
    $c{BBBIKE_RELURL}     = "$c{BBBIKE_CGI_RELURL}/bbbike.cgi";
    $c{BBBIKE_IMAGES_RELURL} = "/bbbike/images"; # XXX on live system different; needs to be determined using bbbike cgi config or so
#	--define BBBIKE_MISCSRC_DIR="$(BBBIKE_MISCSRC_DIR)"
    $c{IMAGE_SUFFIX} = 'png';
    $c{FONTS_LIST} = $^O eq 'freebsd' ? 'fonts-freebsd.list' : 'fonts-debian.list';
#	--define WWW_USER="$(WWW_USER)" \
#	--define ALL_LAYERS="$(ALL_LAYERS)" \
#	--define EMAIL="$(EMAIL)" \
#	--define BBBIKE_SF_WWW="$(BBBIKE_SF_WWW)"
    $c{IMGWIDTH}   = 550;
    $c{IMGHEIGHT}  = 550;
    $c{IMAGECOLOR} = '225 225 225';
    $c{EDITWARNHTML} = "<!-- DO NOT EDIT. Created automatically using $FindBin::RealBin/doit.pl -->";
#	--define EDITWARNJS="/* DO NOT EDIT. Created automatically from ${.ALLSRC:M*tpl} */"
    $c{EDITWARNMAP} = "## DO NOT EDIT. Created automatically using $FindBin::RealBin/doit.pl";
#	--define SMALLDEVICE=0 \
#	--define SCOPES_STRING="$(SCOPES)" \

    # from BBBikeVar.pm
    $c{BBBIKE_MAPSERVER_URL}    = $BBBike::BBBIKE_MAPSERVER_URL;
    $c{BBBIKE_MAPSERVER_DIRECT} = $BBBike::BBBIKE_MAPSERVER_DIRECT;
    $c{BBBIKE_SF_WWW}           = $BBBike::BBBIKE_SF_WWW;
    $c{EMAIL}                   = $BBBike::EMAIL;
}

sub run_tt {
    my($d, $src, $dest, $vars) = @_;
    my $tt = Template->new;
    $d->file_atomic_write
	($dest, sub {
	     my(undef, $tmpdest) = @_;
	     $tt->process($src, $vars, $tmpdest)
		 || error($tt->error . "\n");
	 });
}

{
    my $shp2map_v_output;
    sub _get_cached_shp2map_v_output {
	my($d) = @_;
	if (!defined $shp2map_v_output) {
	    my $prog = $d->which('shp2map') ? 'shp2map' : 'shp2img';
	    $shp2map_v_output = $d->info_qx({quiet=>1}, $prog, '-v');
	}
	$shp2map_v_output;
    }
}

sub get_mapserver_version {
    my($d) = @_;
    my $out = _get_cached_shp2map_v_output($d);
    if ($out =~ /mapserver version (\d+\.\d+)/i) {
	return $1;
    } else {
	error "Cannot get mapserver version using shp2img or shp2map";
    }
}

sub get_mapserver_driver {
    my($d) = @_;
    my $out = _get_cached_shp2map_v_output($d);
    if ($out =~ /SUPPORTS=AGG/) {
	return 'AGG';
    } else {
	return 'GD';
    }
}

######################################################################

sub action_map_file {
    my($d, $mapbasename) = @_;
    my $src = "$mapbasename.map-tpl";
    my $dest = "$dest_dir/.$mapbasename.map";
    if (_need_rebuild($dest, $src, "brb.map-inc")) {
	run_tt($d, $src, $dest, { %c, EDITWARNMAP => "## DO NOT EDIT. Created automatically from $src" });
    }
    for my $scope (@{ $c{SCOPES} }) {
	my $dest_scope = "$dest_dir/$mapbasename-$scope.map";
	if (_need_rebuild($dest_scope, $dest, "$FindBin::RealBin/mkroutemap")) {
	    $d->system("$FindBin::RealBin/mkroutemap", '-force', '-scope', $scope, $dest, $dest_scope);
	}
    }
    $d->ln_nsf("$mapbasename.map", "$dest_dir/$mapbasename-brb.map");
}

sub action_html_files {
    my($d) = @_;
    my @html_files = qw(brb.html brb_init.html brb.js help.html query_header.html query_footer.html);
    for my $html_file (@html_files) {
	my $src = "$html_file-tpl";
	my $dest = "$dest_dir/$html_file";
	if (_need_rebuild($dest, $src)) {
	    run_tt($d, $src, $dest, { %c, EDITWARNHTML => "<!-- DO NOT EDIT. Created automatically from $src -->" });
	}
    }

    $d->ln_nsf("brb_init.html", "$dest_dir/index.html");

    if (_need_rebuild("$dest_dir/radroute_body.html", "$c{BBBIKE_DATA_DIR}/comments_route-orig", "$c{BBBIKE_MISCSRC_DIR}/bbd2mapservhtml.pl", "$c{BBBIKE_MISCSRC_DIR}/grepstrassen")) {
	$d->file_atomic_write("$dest_dir/radroute_body.html", sub {
				  my(undef, $file) = @_;
				  $d->system(<<"EOF" . <<'EOF' . <<"EOF");
$c{BBBIKE_MISCSRC_DIR}/grepstrassen -v -directive 'ignore=' $c{BBBIKE_DATA_DIR}/comments_route-orig |\\
    $c{BBBIKE_MISCSRC_DIR}/grepstrassen -v -directive 'ignore_routelist=' |\\
EOF
    perl -pe 's{(Flaeming-Skate)\s+\(.*\)\t}{$$1\t}' |\
EOF
    $c{BBBIKE_MISCSRC_DIR}/bbd2mapservhtml.pl \\
	-bbbikeurl $c{BBBIKE_CGI_RELURL}/bbbike.cgi \\
	-email $c{EMAIL} \\
	-linklist -preferalias -partialhtml \\
	-headlines \\
	-mapscale 1:40000 \\
	-center city=Berlin_DE -centernearest \\
	-althandling \\
	-distinguishdirections \\
	> $file
EOF
			      });
    }

    if (_need_rebuild("$dest_dir/radroute.html", "$FindBin::RealBin/radroute_header.html", "$dest_dir/radroute_body.html", "$FindBin::RealBin/radroute_footer.html")) {
	$d->file_atomic_write("$dest_dir/radroute.html", sub {
				  my(undef, $file) = @_;
				  $d->system("cat $FindBin::RealBin/radroute_header.html $dest_dir/radroute_body.html $FindBin::RealBin/radroute_footer.html > $file");
			      });
    }
    $d->chmod(0644, "$dest_dir/radroute.html");
}

sub action_static_files {
    my($d) = @_;

    my @distfiles = qw(
			   Makefile
			   doit.pl
			   brb-ipaq.map-tpl
			   brb.css
			   brb.html-tpl
			   brb.js-tpl
			   brb.map-tpl
			   brb.map-inc
			   brb_init.html-tpl
			   cleanup
			   crontab.tpl
			   empty.html
			   help.html-tpl
			   mkroutemap
			   query.html
			   query_footer.html-tpl
			   query_footer2.html
			   query_header.html-tpl
			   query_header2.html
			   std.inc
		     );
    if (-e 'brb.map-localinc') {
	push @distfiles, 'brb.map-localinc';
    }
    push @distfiles, $c{FONTS_LIST};

    for my $file (@distfiles) {
	my $dest_file = "$dest_dir/$file";
	$d->copy($file, $dest_file);
	copy_stat $file, $dest_file;
    }
}

######################################################################

sub action_all {
    my $d = shift;
    action_static_files($d);
    action_map_file($d, "brb");
    action_map_file($d, "brb-ipaq");
    action_html_files($d);
}

return 1 if caller;

my $d = Doit->init;
$d->add_component('file');

GetOptions(
	   "destdir|dest-dir|dest-directory=s" => \$dest_dir,
	  ) or die "usage: $0 [--dry-run] [--dest-dir directory] action ...\n";

if (!defined $dest_dir) {
    error "Currently defining --dest-dir is mandatory!";
}
$d->make_path($dest_dir); # XXX may this directory contain files from a previous run?

compute_config($d);

my @actions = @ARGV;
if (!@actions) {
    @actions = ('all');
}
for my $action (@actions) {
    $action =~ s{[-.]}{_}g;
    my $sub = "action_$action";
    if (!defined &$sub) {
	die "Action '$action' not defined";
    }
    no strict 'refs';
    &$sub($d);
}

__END__
