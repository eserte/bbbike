# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeBuildUtil;

use strict;
use vars qw($VERSION @EXPORT_OK);
$VERSION = '0.03';

use Exporter 'import';
@EXPORT_OK = qw(get_pmake module_path);

use BBBikeUtil qw(is_in_path);

sub get_pmake () {
    (
     $^O =~ m{bsd}i                             ? "make"         # standard BSD make
     : $^O eq 'darwin' && is_in_path('bsdmake') ? 'bsdmake'      # homebrew bsdmake pacage
     : is_in_path("fmake")                      ? "fmake"        # debian jessie and later
     : is_in_path("freebsd-make")               ? "freebsd-make" # debian wheezy and earlier
     : "pmake"                                                   # self-compiled BSD make, maybe
    );
}

# REPO BEGIN
# REPO NAME module_path /home/eserte/src/srezic-repository 
# REPO MD5 ac5f3ce48a524d09d92085d12ae26e8c
sub module_path {
    my($filename) = @_;
    $filename =~ s{::}{/}g;
    $filename .= ".pm";
    foreach my $prefix (@INC) {
	my $realfilename = "$prefix/$filename";
	if (-r $realfilename) {
	    return $realfilename;
	}
    }
    return undef;
}
# REPO END


1;

__END__
