#!/usr/bin/perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2001,2003,2014 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

use CGI::Carp qw(fatalsToBrowser);

# NOTE: Should be same as in bbbike.cgi
use FindBin;
use lib (grep { -d }
	 (#"/home/e/eserte/src/bbbike",
	  "$FindBin::RealBin/..", # falls normal installiert
	  "$FindBin::RealBin/../lib",
	  "$FindBin::RealBin/../BBBike", # falls in .../cgi-bin/... installiert
	  "$FindBin::RealBin/../BBBike/lib",
	  "$FindBin::RealBin/BBBike", # weitere Alternative
	  "$FindBin::RealBin/BBBike/lib",
	  "$FindBin::RealBin",
	  "/home/e/eserte/lib/perl", # only for TU Berlin
	 )
	);

use CGI qw(:standard);
use strict;
use Cwd qw(abs_path);

use vars qw(%cap %comment);

$| = 1;

print header("text/plain"),
      ;

print <<EOF;
# -*- perl -*-

EOF

check_layout();
check_inline();
check_agrep();
check_gd_img_formats();
check_pdf();
check_svg();
check_mapserver();

use Data::Dumper;
foreach my $key (sort keys %cap) {
    my $out = Data::Dumper->Dump([$cap{$key}],["*$key"]);
    if (exists $comment{$key}) {
	$out =~ s/$/ # $comment{$key}/;
    }
    print $out;
}

print <<EOF;

1;
EOF

sub check_agrep {

    foreach my $key (qw(agrep string_approx)) {
	$cap{'can_' . $key} = 0;
    }

    if (is_in_path("agrep")) {
	my $usage = `agrep 2>&1 --invalid`;

	# check for agrep 3.x
	if ($usage =~ /usage: agrep \[-@/) {
	    $cap{'can_agrep'} = 1;
	}
    }

    if (eval q{ require String::Approx; String::Approx->VERSION(2.7); 1 }) {
	$cap{'can_string_approx'} = 1;
    }
}

sub check_layout {

    foreach my $key (qw(cgi_bin_layout)) {
	$cap{'use_' . $key} = 0;
    }

    if (-d "$FindBin::RealBin/BBBike" &&
	-d "$FindBin::RealBin/lib" &&
	-d "$FindBin::RealBin/data") {
	$cap{'use_cgi_bin_layout'} = 1;
    }

}

sub check_gd_img_formats {

    foreach my $key (qw(image gif png wbmp jpeg xpm ppm)) {
	$cap{'can_' . $key} = 0;
    }

    if (!eval q{ require GD; 1 } &&
	!eval q{ require PDF::Create; PDF::Create->VERSION(1.06) }) {
	return;
    }
    $cap{'can_image'} = 1;

    if (eval q{ require GD; 1 }) {
	if ($GD::VERSION < 1.20) {
	    $cap{'can_gif'} = 1;
	}
	if ($GD::VERSION > 1.37 && GD::Image->can('gif')) {
	    $cap{'can_gif'} = 1;
	}
	if ($GD::VERSION >= 1.20) {
	    $cap{'can_png'} = 1;
	    $cap{'graphic_format'} = 'png';
	}
	if (GD::Image->can('wbmp')) {
	    $cap{'can_wbmp'} = 1;
	}
	if (!GD::Image->can('jpeg')) {
	    $cap{'cannot_jpeg'} = 1;
	}
	if (eval q{ require GD::Convert; 1 }) {
	    if (GD::Image->can('xpm')) {
		$cap{'can_xpm'} = 1;
	    }
	    if (GD::Image->can('ppm')) {
		$cap{'can_ppm'} = 1;
	    }
	    if (eval q{ GD::Convert->import("gif=any"); 1}) {
		$cap{'can_gif'} = 1;
	    }
	}
    }

    if (eval q{ require PDF::Create; PDF::Create->VERSION(1.06) }) {
    }
}

sub check_inline {

    foreach my $key (qw(inline)) {
	$cap{'can_' . $key} = 0;
    }

    if (eval q{ require Inline::C; Inline->VERSION(0.40); 1 }) {
	eval <<EOF;
	use Inline C => 'int inline_test() { return 1; }';
EOF
        if (defined &inline_test && inline_test()) {
	    $cap{'can_inline'} = 1;
	}
    }
}

sub check_pdf {
    if (!eval { require PDF::Create; PDF::Create->VERSION(1.06); 1}) {
	$cap{'cannot_pdf'} = 1;
    } else {
	$cap{'cannot_pdf'} = 0;
    }
}

sub check_svg {
    if (!eval { require SVG; 1}) {
	$cap{'cannot_svg'} = 1;
    } else {
	$cap{'cannot_svg'} = 0;
    }
}

sub check_svg {
    if (eval { require Palm::PalmDoc; require BBBikePalm; 1}) {
	$cap{'can_palmdoc'} = 1;
    }
}

sub check_mapserver {
    if (-d "$FindBin::RealBin/../mapserver/brb") {
	$cap{'can_mapserver'} = 1; # maybe always set to one if there is an external mapserver instance
	$cap{'mapserver_dir'} = abs_path("$FindBin::RealBin/../mapserver/brb");
	$cap{'mapserver_prog_relurl'} = undef;
	$comment{'mapserver_prog_relurl'} = "EDIT!";
	$cap{'mapserver_prog_url'} = undef;
	$comment{'mapserver_prog_url'} = "EDIT!";
    }
    if (-e "$FindBin::RealBin/miscsrc/bbd2esri") {
	$cap{'bbd2esri_prog'} = "$FindBin::RealBin/miscsrc/bbd2esri";
    } else {
	$cap{'bbd2esri_prog'} = undef;
	$comment{'bbd2esri_prog'} = "EDIT!";
    }
}

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 1b42243230d92021e6c361e37c9771d1

=head2 is_in_path($prog)

=for category File

Return the pathname of $prog, if the program is in the PATH, or undef
otherwise.

DEPENDENCY: file_name_is_absolute

=cut

sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -f $prog and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    return "$_\\$prog"
		if (-x "$_\\$prog.bat" ||
		    -x "$_\\$prog.com" ||
		    -x "$_\\$prog.exe");
	} else {
	    return "$_/$prog" if (-x "$_/$prog");
	}
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 a77759517bc00f13c52bb91d861d07d0

=head2 file_name_is_absolute($file)

=for category File

Return true, if supplied file name is absolute. This is only necessary
for older perls where File::Spec is not part of the system.

=cut

sub file_name_is_absolute {
    my $file = shift;
    my $r;
    eval {
        require File::Spec;
        $r = File::Spec->file_name_is_absolute($file);
    };
    if ($@) {
	if ($^O eq 'MSWin32') {
	    $r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	} else {
	    $r = ($file =~ m|^/|);
	}
    }
    $r;
}
# REPO END

# No __END__ !

