#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: vconfig.pl,v 1.4 2003/01/08 21:07:41 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use Config;
use Getopt::Long;

$verbose = 0;
GetOptions("v!" => \$verbose);

$makefile = "Makefile"; # GNUmakefile

@x11_lib_paths = qw(/usr/X11R6/lib /usr/local/lib /usr/lib);
@x11_inc_paths = qw(/usr/X11R6/include /usr/local/include /usr/include);

@v_lib_paths = qw(/usr/X11R6/lib /usr/local/lib /usr/lib
		  /usr/lib/v /usr/local/v/lib);
@v_libs = qw(Vm Vx V);
@v_inc_paths = qw(/usr/X11R6/include /usr/local/include /usr/include
		  /usr/include /usr/local/v/include);

my($vlibpath, $vlibshortname, $vlibname) =
    search_lib(-lib  => \@v_libs,
	       -path => \@v_lib_paths);
my($vincpath) =
    search_inc(-inc  => ["v/v_defs.h"],
	       -path => \@v_inc_paths);

my($x11libpath, $x11incpath) = ("", "");
eval {
    $x11libpath =
    search_lib(-lib  => ['Xaw'],
	       -path => \@x11_lib_paths);
    $x11incpath =
    search_inc(-inc  => ['X11/Xfuncproto.h'],
	       -path => \@x11_inc_paths);
};
if ($@ && $^O ne 'cygwin') {
    die $@;
}
my $archname = $Config{'archname'};

my $guilibs;
if ($^O eq 'cygwin') {
    $guilibs = "-L/lib/w32api -lcomctl32 -lgdi32";
} else {
    $guilibs = "-lXaw -lXmu -lXt -lXext -lX11";
}

if ($verbose) {
    warn "-L$vlibpath -l$vlibshortname -I$vincpath\n";
    warn "-L$x11libpath -I$x11incpath\n" if defined $x11libpath;
    warn "$guilibs\n";
}

my $allsrc;
if ($Config{'archname'} =~ /bsd/i) {
    # pmake
    $allsrc = '${.TARGET:T:R}.cpp';
} else {
    # gmake
    $allsrc = '$<';
}

do { mkdir $Config{'archname'}, 0775 or die "Can't create directory: $!" }
    if !-d $Config{'archname'};

open(IN, "$makefile.in") or
    die "Can't open $makefile.in: $!";
open(OUT, ">$makefile") or
    die "Can't write to $makefile: $!";
while(<IN>) {
    foreach my $subst (qw(vlibpath vlibshortname vlibname vincpath
			  x11libpath x11incpath archname allsrc guilibs)) {
	my $subst_str = eval "\$$subst";
	s/\@$subst@/$subst_str/g;
    }
    print OUT $_;
}
close OUT;
close IN;

sub search_lib {
    my(%args) = @_;

    my(@check_libs)      = @{ $args{-lib}  };
    my(@check_lib_paths) = @{ $args{-path} };

    my($libpath, $libshortname, $libname);
 SEARCHLIB: {
	foreach my $lib (@check_libs) {
	    foreach my $lib_path (@check_lib_paths) {
		foreach my $ext ('.so', '.a') {
		    $libshortname = $lib;
		    $libname      = "lib" . $lib . $ext;
		    my $checkpath = "$lib_path/$libname";
		    warn "Check $checkpath...\n" if ($verbose);
		    if (-e $checkpath) {
			if (-r $checkpath) {
			    $libpath = $lib_path;
			    last SEARCHLIB;
			} else {
			    warn "$checkpath exists, but is not readable!\n";
			}
		    }
		}
	    }
	}
    }
    if (!defined $libpath) {
	die "Can't find library @check_libs in @v_lib_paths";
    }
    ($libpath, $libshortname, $libname);
}

sub search_inc {
    my(%args) = @_;

    my(@check_incs)      = @{ $args{-inc}  };
    my(@check_inc_paths) = @{ $args{-path} };

    my($incpath);
  SEARCHINC: {
      foreach my $inc (@check_incs) {
	  foreach my $inc_path (@check_inc_paths) {
	      my $checkpath = "$inc_path/$inc";
	      warn "Check $checkpath...\n" if ($verbose);
	      if (-e $checkpath) {
		  if (-r $checkpath) {
		      $incpath = $inc_path;
		      last SEARCHINC;
		  } else {
		      warn "$checkpath exists, but is not readable!\n";
		  }
	      }
	  }
      }
  }
    if (!defined $incpath) {
	die "Can't find include @check_incs in @v_inc_paths";
    }
    ($incpath);
}


__END__
