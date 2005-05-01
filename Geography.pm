# -*- perl -*-

#
# $Id: Geography.pm,v 1.6 2005/04/29 21:03:01 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2000,2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

package Geography;

sub new {
    my($class, $city, $country, @args) = @_;
    return if !defined $city && !defined $country;
    my $pkg = 'Geography::' . ucfirst(lc($city)) . '_' . uc($country);
    my $obj = eval 'use ' . $pkg . '; ' . $pkg . '->new(@args)';
    if (!$obj) {
	$obj = $class->fallback_constructor($city, $country, @args);
    }
    $obj;
}

sub fallback_constructor {
    my($class, $city, $country, @args) = @_;
    require File::Basename;
    my $geo_dir = File::Basename::dirname(__FILE__). "/Geography";
    my $city_obj;
    if (opendir GEO, $geo_dir) {
	my $search_term = quotemeta $city;
	if (defined $country) {
	    $search_term .= ".*_" . quotemeta $country;
	}
	while(defined(my $f = readdir GEO)) {
	    next if -d $f || $f !~ /\.pm$/;
	    if ($f =~ /^$search_term/i) {
		$f =~ s/\.pm$//;
		my $citypkg = 'Geography::' . $f;
		eval 'require ' . $citypkg;
		die $@ if $@;
		$city_obj = $citypkg->new;
		last;
	    }
	}
	closedir GEO;
	return $city_obj;
    } else {
	die sprintf("Kann das Verzeichnis %s nicht öffnen: %s",
		    $geo_dir, $!);
    }
}

# XXX smarter? look at existing data directories?
sub default {
    Geography->new("Berlin", "DE");
}

1;

__END__
