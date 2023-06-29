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
use URI::Escape qw(uri_escape);

my $dest_dir;
my %c;

sub _need_rebuild ($@) {
    my($dest, @srcs) = @_;
    return 1 if !-e $dest;
    for my $src (@srcs, __FILE__,"$dest_dir/.options") {
	if (!-e $src) {
	    warning "$src does not exist";
	} else {
	    return 1 if -M $src < -M $dest;
	}
    }
    return 0;
}

sub compute_config {
    my($doit, $target_doit, %opts) = @_;

    # configurable
    $c{LOCATION_STYLE}           = delete $opts{LOCATION_STYLE} // 'bbbike'; # or 'vhost'
    $c{HOST}                     = delete $opts{HOST} // 'localhost'; # XXX needs to be determined by bbbike.cgi.config or so
    $c{LOCAL_BBBIKE_DIR}         = delete $opts{LOCAL_BBBIKE_DIR} // realpath(cwd . "/../..");
    $c{BBBIKE_DIR}               = delete $opts{BBBIKE_DIR} // $c{LOCAL_BBBIKE_DIR};
    $c{HTDOCS_DIR}               = delete $opts{HTDOCS_DIR} // $c{BBBIKE_DIR};
    $c{WWW_USER}                 = delete $opts{WWW_USER} // 'www-data';
    die "Unhandled options: " . join(' ', %opts) if %opts;

    # static
    $c{SCOPES}                   = [qw(brb b inner-b wide p)];
    # computed config
    $c{LOCAL_BBBIKE_DATA_DIR}    = "$c{LOCAL_BBBIKE_DIR}/data";
    $c{LOCAL_BBBIKE_MISCSRC_DIR} = "$c{LOCAL_BBBIKE_DIR}/miscsrc";
    $c{MAPSERVER_DIR}            = "$c{HTDOCS_DIR}/mapserver/brb";
    $c{MAPSERVER_RELURL}         = $c{LOCATION_STYLE} eq 'bbbike' ? '/bbbike/mapserver/brb' : '/mapserver/brb';
    $c{MAPSERVER_URL}            = "http://$c{HOST}$c{MAPSERVER_RELURL}";
    $c{MAPSERVER_PROG_RELURL}    = '/cgi-bin/mapserv';
    $c{MAPSERVER_PROG_URL}       = "http://$c{HOST}$c{MAPSERVER_PROG_RELURL}";
    $c{MAPSERVER_PROG_FSPATH}    = '/usr/lib/cgi-bin/mapserv'; # XXX what about non-debian systems?
    $c{MAPSERVER_VERSION}        = get_mapserver_version($target_doit);
    $c{MAPSERVER_DRIVER}         = get_mapserver_driver($target_doit);
    $c{IMAGE_DIR}                = "$c{BBBIKE_DIR}/images";
    $c{BBBIKE_MISCSRC_DIR}       = "$c{BBBIKE_DIR}/miscsrc";
    $c{BBBIKE_HTML_RELURL}       = $c{LOCATION_STYLE} eq 'bbbike' ? '/bbbike/html' : '/BBBike/html';
    $c{BBBIKE_CGI_RELURL}        = $c{LOCATION_STYLE} eq 'bbbike' ? '/bbbike/cgi' : '/cgi-bin';
    $c{BBBIKE_RELURL}            = "$c{BBBIKE_CGI_RELURL}/bbbike.cgi";
    $c{BBBIKE_URL}               = "http://$c{HOST}$c{BBBIKE_RELURL}";
    $c{BBBIKE_RELURL_ENC}        = uri_escape($c{BBBIKE_RELURL});
    $c{BBBIKE_URL_ENC}           = uri_escape($c{BBBIKE_URL});
    $c{BBBIKE_IMAGES_RELURL}     = $c{LOCATION_STYLE} eq 'bbbike' ? '/bbbike/images' : '/BBBike/images';
    $c{IMAGE_SUFFIX}             = 'png';
    $c{FONTS_LIST}               = $^O eq 'freebsd' ? 'fonts-freebsd.list' : 'fonts-debian.list';
    $c{IMGWIDTH}                 = 550;
    $c{IMGHEIGHT}                = 550;
    $c{IMAGECOLOR}               = '225 225 225';
    $c{EDITWARNHTML}             = "<!-- DO NOT EDIT. Created automatically using $FindBin::RealBin/doit.pl -->";
    $c{EDITWARNJS}               = "/* DO NOT EDIT. Created automatically using $FindBin::RealBin/doit.pl */";
    $c{EDITWARNMAP}              = "## DO NOT EDIT. Created automatically using $FindBin::RealBin/doit.pl";

    require BBBikeMapserver;
    $c{ALL_LAYERS} = join ' ', BBBikeMapserver::all_layers();

    require BBBikeVar;
    no warnings 'once';
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
    my @html_files = qw(brb.html brb_init.html brb.js help.html query_header.html query_footer.html radroute_header.html radroute_footer.html);
    for my $html_file (@html_files) {
	my $src = "$html_file-tpl";
	my $dest = "$dest_dir/$html_file";
	if (_need_rebuild($dest, $src)) {
	    run_tt($d, $src, $dest, { %c,
				      EDITWARNHTML => "<!-- DO NOT EDIT. Created automatically from $src -->",
				      EDITWARNJS   => "/* DO NOT EDIT. Created automatically from $src */",
				    });
	}
    }

    $d->ln_nsf("brb_init.html", "$dest_dir/index.html");

    if (_need_rebuild("$dest_dir/radroute_body.html", "$c{LOCAL_BBBIKE_DATA_DIR}/comments_route-orig", "$c{LOCAL_BBBIKE_MISCSRC_DIR}/bbd2mapservhtml.pl", "$c{LOCAL_BBBIKE_MISCSRC_DIR}/grepstrassen")) {
	$d->file_atomic_write("$dest_dir/radroute_body.html", sub {
				  my(undef, $file) = @_;
				  $d->system(<<"EOF" . <<'EOF' . <<"EOF");
$c{LOCAL_BBBIKE_MISCSRC_DIR}/grepstrassen -v -directive 'ignore=' $c{LOCAL_BBBIKE_DATA_DIR}/comments_route-orig |\\
    $c{LOCAL_BBBIKE_MISCSRC_DIR}/grepstrassen -v -directive 'ignore_routelist=' |\\
EOF
    perl -pe 's{(Flaeming-Skate)\s+\(.*\)\t}{$$1\t}' |\
EOF
    $c{LOCAL_BBBIKE_MISCSRC_DIR}/bbd2mapservhtml.pl \\
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

    if (_need_rebuild("$dest_dir/radroute.html", "$dest_dir/radroute_header.html", "$dest_dir/radroute_body.html", "$dest_dir/radroute_footer.html")) {
	$d->file_atomic_write("$dest_dir/radroute.html", sub {
				  my(undef, $file) = @_;
				  $d->system("cat $dest_dir/radroute_header.html $dest_dir/radroute_body.html $dest_dir/radroute_footer.html > $file");
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

sub action_dist_any {
    my $d = shift;
    $d->system('rsync', '-a', 'data/', "$dest_dir/data/");
    $d->system('rsync', '-a', 'graphics/', "$dest_dir/graphics/");
    $d->mkdir("$dest_dir/tmp");
    $d->chmod(0755, "$dest_dir/tmp");
}

# not included in "action_all"
sub action_crontab {
    my $d = shift;
    my $dest = "/tmp/bbbike-mapserver-cleanup"; # XXX
    my $src = "crontab.tpl";
    if (_need_rebuild($dest, $src)) {
	run_tt($d, $src, $dest, \%c);
    }
}

# not included in "action_all"
sub action_httpd_conf {
    my $d = shift;
    my $dest = "/tmp/mapserver-httpd.conf"; # XXX
    my $src = "httpd.conf-tpl";
    if (_need_rebuild($dest, $src)) {
	run_tt($d, $src, $dest, { %c, EDITWARNMAP => "## DO NOT EDIT. Created automatically from $src" });
    }
}

######################################################################

sub action_all {
    my $d = shift;
    action_static_files($d);
    action_map_file($d, "brb");
    action_map_file($d, "brb-ipaq");
    action_html_files($d);
    action_dist_any($d);
}

return 1 if caller;

my $d = Doit->init;
$d->add_component('file');

my @saved_ARGV = @ARGV;

GetOptions(
	   "destdir|dest-dir|dest-directory=s" => \$dest_dir,
	   "host=s" => \my $host,
	   "location-style=s" => \my $location_style,
	   "bbbike-dir=s" => \my $bbbike_dir,
	   "htdocs-dir=s" => \my $htdocs_dir,
	   "target-ssh=s" => \my $target_ssh,
	   'www-user=s' => \my $www_user,
	  ) or die "usage: $0 [--dry-run] [--dest-dir directory] [--host host] [--location-style vhost|bbbike] [--bbbike-dir /path...] [--htdocs-dir /path...] [--target-ssh user\@host] [--www-user username] action ...\n";

if (!defined $dest_dir) {
    error "Currently defining --dest-dir is mandatory!";
}

$d->write_binary("$dest_dir/.options", "@saved_ARGV\n"); # only written if different from previous run

$d->make_path($dest_dir); # XXX may this directory contain files from a previous run?

my $target_doit;
if ($target_ssh) {
    $target_doit = $d->do_ssh_connect($target_ssh);
} else {
    $target_doit = $d;
}

compute_config($d, $target_doit,
	       HOST => $host,
	       LOCATION_STYLE => $location_style,
	       BBBIKE_DIR => $bbbike_dir,
	       HTDOCS_DIR => $htdocs_dir,
	       WWW_USER => $www_user,
	      );

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

=head1 EXAMPLES

A typical local setup (using "bbbike" location style):

    ./doit.pl --dest-dir /tmp/mapserver_dist

A typical production setup (using "vhost" location style):

    ./doit.pl --dest-dir /tmp/remote_mapserver_dist --host bbbike.de --location-style vhost --bbbike-dir /srv/www/bbbike-webserver/BBBike --htdocs-dir /srv/www/bbbike-webserver/public --target-ssh bbbike-prod

=cut
