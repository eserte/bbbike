# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2015 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeCGI::Config;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

sub the_config {
    my(undef, $output_for, $ns) = @_;
    $ns = 'main' if !defined $ns;
    if ($output_for eq 'json') { require JSON::XS }
    my $bool = (
		$output_for eq 'json' ? sub { $_[0] ? JSON::XS::true() : JSON::XS::false() } :
		$output_for eq 'perl' ? sub { !!$_[0] } :
		die 'output_for should be either json or perl'
	       );
    my $var = sub {
	no strict 'refs';
	${$ns.'::'.$_[0]};
    };
    
    +{
      use_apache_session         => $bool->($var->('use_apache_session')),
      apache_session_module      => $var->('apache_session_module'),
      detailmap_module           => $var->('detailmap_module'),
      graphic_format             => $var->('graphic_format'),
      can_gif                    => $bool->($var->('can_gif')),
      can_jpeg                   => $bool->(!$var->('cannot_jpeg')),
      can_pdf                    => $bool->(!$var->('cannot_pdf')),
      bbbikedraw_pdf_module      => $var->('bbbikedraw_pdf_module'),
      can_svg                    => $bool->(!$var->('cannot_svg')),
      can_wbmp                   => $bool->($var->('can_wbmp')),
      can_palmdoc                => $bool->($var->('can_palmdoc')),
      can_gpx                    => $bool->($var->('can_gpx')),
      can_kml                    => $bool->($var->('can_kml')),
      can_mapserver              => $bool->($var->('can_mapserver')),
      can_gpsies_link            => $bool->($var->('can_gpsies_link')),
      show_start_ziel_url        => $bool->($var->('show_start_ziel_url')),
      show_weather               => $bool->($var->('show_weather')),
      use_select                 => $bool->($var->('use_select')),
      use_berlinmap              => $bool->(!$var->('no_berlinmap')),
      use_background_image       => $bool->($var->('use_background_image')),
      with_comments              => $bool->($var->('with_comments')),
      with_cat_display           => $bool->($var->('with_cat_display')),
      use_coord_link             => $bool->($var->('use_coord_link')),
      city                       => $var->('city'),
      use_fragezeichen           => $bool->($var->('use_fragezeichen')),
      use_fragezeichen_routelist => $bool->($var->('use_fragezeichen_routelist')),
      search_algorithm           => $var->('search_algorithm'),
      use_exact_streetchooser    => $bool->($var->('use_exact_streetchooser')),
      use_utf8                   => $bool->($var->('use_utf8')),
      data_is_wgs84              => $bool->($var->('data_is_wgs84')),
      osm_data                   => $bool->($var->('osm_data')),
      bbbike_images              => $var->('bbbike_images'),
      bbbike_html                => $var->('bbbike_html'),
     };
}

sub load_config {
    my($class, $file, $output_for) = @_;
    require Digest::MD5;
    require Cwd;
    my $file_digest = Digest::MD5::md5_hex(Cwd::realpath($file));
    my $ns = 'BBBikeCGI::Config::config_' . $file_digest;
    $class->pre_defaults($ns);
    our $global_file = $file;
    my $code = '{package ' . $ns . '; if (!do $global_file) { die "Failed to load $global_file" }}';
    eval $code;
    die "CODE <$code> failed: $@" if $@;
    $class->post_defaults($ns);
    $class->the_config($output_for, $ns);
}

# Set current defaults as found in bbbike.cgi
sub pre_defaults {
    my($class, $ns) = @_;
    my $var_set = sub {
	no strict 'refs';
	${$ns.'::'.$_[0]} = $_[1];
    };
    $var_set->('cannot_jpeg'                , 1);
    $var_set->('cannot_svg'                 , 1);
    $var_set->('graphic_format'             , 'png');
    $var_set->('city'                       , "Berlin_DE");
    $var_set->('show_start_ziel_url'        , 1);
    $var_set->('show_weather'               , 1);
    $var_set->('use_background_image'       , 1);
    $var_set->('use_coord_link'             , 1);
    $var_set->('use_exact_streetchooser'    , 1);
    $var_set->('use_fragezeichen'           , 0);
    $var_set->('use_fragezeichen_routelist' , 1);
    $var_set->('with_comments'              , 1);
    $var_set->('use_select'                 , 1);
}

sub post_defaults {
    my($class, $ns) = @_;
    my $var_set = sub {
	no strict 'refs';
	${$ns.'::'.$_[0]} = $_[1];
    };
    my $var_get = sub {
	no strict 'refs';
	${$ns.'::'.$_[0]};
    };
    my $use_cgi_bin_layout = $var_get->('use_cgi_bin_layout');
    if (!defined $var_get->('bbbike_html')) {
	$var_set->('bbbike_html', ($use_cgi_bin_layout ? '/BBBike' : '/bbbike') . '/html');
    }
    if (!defined $var_get->('bbbike_images')) {
	$var_set->('bbbike_images', ($use_cgi_bin_layout ? '/BBBike' : '/bbbike') . '/images');
    }
}

1;

__END__
