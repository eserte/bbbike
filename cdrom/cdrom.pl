#!/usr/bin/env perl
# -*- perl -*-

#
# $Id: cdrom.pl,v 1.7 2000/08/09 07:03:01 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use 5.005; # lookbehind

use File::Path;
use Getopt::Long;

$^W = 1;

my(%makerule) = qw(perl 1
		   bbbike 1
		   bbbikecommon 1
		   diplom 1
		   windows 1
		   compile 1
		   freebsd 1
		   linux 1);
my $is_diplom = 0;
my $verbose = 1;
my $latex_rebuild = 1;
my $mingwperl = 1;
my $mingwperl_version = "5.00555";

my(@getoptarg);
foreach my $rule (keys %makerule) {
    my $rule1 = $rule;
    push @getoptarg, $rule;
    push @getoptarg, sub {
	%makerule = ();
	$makerule{$rule1} = 1;
    };
}

usage() if (!GetOptions(@getoptarg,
			"v|verbose!" => \$verbose,
			"f!" => \$force,
			"latexrebuild!" => \$latex_rebuild,
			"dip!" => \$is_diplom,
			"asperl" => sub { $mingwperl = 0; },
			"mingver=s" => \$mingwperl_version,
			"destdir=s" => \$destdir,
			));

sub usage {
    die "Usage: $0\n" . 
	join("\n", map { "\t-$_" } keys %makerule) .
	"\n\t-f (force creation on non-FreeBSD systems)" .
	"\n\t-v (be verbose)" .
	"\n\t-latexrebuild (for documentation: do LaTeX rebuild)" .
	"\n\t-dip (make cdrom for diplom)\n";
}

umask 022;

if (!defined $destdir) {
    $destdir = "/servertmp/cdrom";
}

$diplomsrc = "$ENV{HOME}/lv/diplom/BBBike";

mkpath(["$destdir"], 1, 0755);

# which task on which architecture?
%archtask =
    ('bbbike' => 'freebsd',
     'windows' => 'freebsd',
     'bbbikecommon' => 'freebsd',
     'diplom' => 'freebsd', # (nicht mehr) wegen LaTeX2HTML
    );


# für linux & freebsd notwendig
if ($makerule{"perl"}) {
    warn "Copy perl distribution for $^O...\n" if $verbose;
    system("./perlinstall.pl", $destdir);
}

if ($makerule{"bbbike"} && ($^O eq $archtask{"bbbike"} || $force)) {
    warn "Copy BBBike distribution ...\n" if $verbose;
    chomp(my $version = `cd ..; make echoversion`);
    system("cd ..; make DIST_CP=cp distdir");
    system("rm -rf $destdir/BBBike");
    system("cp -fR ../BBBike-$version $destdir/BBBike");
    
    warn "Copy BBBike miscsrc ...\n" if $verbose;
    mkpath(["$destdir/BBBike/miscsrc"], 1, 0755);
    system("cp -f ../miscsrc/* $destdir/BBBike/miscsrc");
}

# und eine Windows-Installation über Samba
if ($makerule{"windows"} && ($^O eq $archtask{"windows"} || $force)) {
    warn "Copy perl distribution for windows ...\n" if $verbose;
    my $windir = "/calvin/c";
    my $winperldir;
    if ($mingwperl) {
	$winperldir = "$windir/mingwperl";
    } else {
	$winperldir = "$windir/Perl";
    }

    system("mount | grep -q $windir");
    if ($?) {
	warn "WARNING! $windir is not mounted!";
    }

    mkpath(["$destdir/windows"], 1, 0755);
    if ($mingwperl) {
	system("cp -fR $winperldir/$mingwperl_version/bin $destdir/windows/bin");
	system("cp -fR $winperldir/$mingwperl_version/lib $destdir/windows/lib");
	system("cp -fR $winperldir/site/$mingwperl_version/lib $destdir/windows/lib/site");
	system("rm -rf $destdir/windows/lib/site/Pod/html");
	system("rm -rf $destdir/windows/lib/site/Pod/*.pod");
    } else {
	system("cp -fR $winperldir/5.005/bin $destdir/windows/bin");
	system("cp -fR $winperldir/5.005/lib $destdir/windows/lib");
	system("cp -fR $winperldir/site $destdir/windows/lib/site");
    }

}

if ($makerule{"bbbikecommon"} && ($^O eq $archtask{"bbbikecommon"} || $force)) {
    warn "Copy misc files for BBBike ...\n" if $verbose;
    system("cp -fp unix/bbbike.sh $destdir"); # startup für Unix
    system("cp -fp ../README $destdir/README"); # für Unix
    write_dos_file("../README", "$destdir/README.txt"); # für Windows
    system("cp -fp ../README.html $destdir"); # deutsch und HTML
    system("cp -fp ../README.en.html $destdir"); # englisch und HTML
    if ($is_diplom) {
	write_dos_file("windows/autorun.inf.diplom", "$destdir/autorun.inf");
	open(IDX, "index.html") or
	    die "Can't read index.html: $!";
	open(OUT, ">$destdir/index.html") or
	    die "Can't write to $destdir: $!";
	while(<IDX>) {
	    if (/#SIZE:\s+(.*)#/) {
		my $file = $1;
		my $size = -s "$diplomsrc/$1";
		$size = sprintf("%d KB", $size/1024);
		s/#SIZE.*#/$size/;
	    }
	    print OUT $_;
	}
	close OUT;
	close IDX;
	#system("cp -f index.html $destdir");
    } else {
	write_dos_file("windows/autorun.inf", "$destdir/autorun.inf");
    }
    write_dos_file("windows/bbbike.bat", "$destdir/bbbike.bat");
    write_dos_file("windows/perl.bat" , "$destdir/windows/perl.bat");
    write_dos_file("windows/setup.bat" , "$destdir/setup.bat");
    write_dos_file("windows/setup.pl" , "$destdir/setup.pl");

    if (!$mingwperl) {
	fix_winperlbinpath("$destdir/bbbike.bat");
	fix_winperlbinpath("$destdir/windows/perl.bat");
	fix_winperlbinpath("$destdir/setup.bat");
    }
}
    
if ($makerule{"diplom"} && ($^O eq $archtask{"diplom"} || $force) && $is_diplom) {
    warn "Copy diplom documentation ...\n" if $verbose;
    my $diplomdest = "$destdir/doc";
    mkpath(["$diplomdest/code",
	    "$diplomdest/screenshots",
	    "$diplomdest/diplom/resources"], 1, 0755);
    system("cp -f $diplomsrc/code/* $diplomdest/code");
    system("cp -fR $diplomsrc/resources $diplomdest");
    my(@targets) = qw(diplom.ps diplom.ps.gz diplom.ps.bz2
		      diplom.pdf diplom.txt);
    if ($latex_rebuild) {
	system("cd $diplomsrc/doc; make force; make force; make force");
    }
    system("cd $diplomsrc/doc; make " . join(" ", @targets) . " html");
    foreach my $doc (qw(diplom.dvi), @targets) {
	system("cp -f $diplomsrc/doc/$doc $diplomdest");
	system("chmod a+r $diplomdest");
    }
    system("cp -fR $diplomsrc/doc/diplom $diplomdest/html");
    system("cp -f $diplomsrc/doc/screenshots/* $diplomdest/screenshots");

    warn "Change bbbike source for diplom dist...\n" if $verbose;
    rename "$destdir/BBBike/bbbike", "$destdir/BBBike/bbbike.tmp";
    open(B, "$destdir/BBBike/bbbike.tmp") or die "Can't open tmp file: $!";
    open(O, ">$destdir/BBBike/bbbike") or die "Can't write to bbbike: $!";
    while(<B>) {
	s/\$diplom *= *0/\$diplom=1/;
	s/\$do_www *= *1/\$do_www=0/;
	print O $_;
    }
    close O;
    close B;
    unlink "$destdir/BBBike/bbbike.tmp";
}

if ($makerule{"compile"}) {
    warn "Compile XS bits for $^O ...\n" if $verbose;
    foreach my $mod (qw(BBBikeXS VirtArray)) {
	if ($^O =~ /freebsd/i) {
	    system("cd $destdir/BBBike/ext/$mod; " .
		   "$destdir/freebsd/bin/perl Makefile.PL; make install");
	} elsif ($^O =~ /linux/i) {
	    system("cd $destdir/BBBike/ext/$mod; " .
		   "$destdir/linux/bin/perl Makefile.PL; make install");
	} else {
	    die "Can't do that for $^O";
	}
    }
}

sub write_dos_file {
    my($from, $to) = @_;
    if (open(F, $from)) {
	if (open(T, ">$to")) {
	    local($/) = undef;
	    my $buf = <F>;
	    $buf =~ s/(?<=[^\015])\012/\015\012/sg;
	    print T $buf;
	    close T;
	} else {
	    warn "Can't write to $to: $!";
	}
	close F;
    } else {
	warn "Can't read from $from: $!";
    }
}

sub fix_winperlbinpath {
    my($file) = @_;
    rename $file, "$file~";
    open(F, "$file~") or die "Can't open $file~: $!";
    open(W, ">$file") or die "Can't write to $file: $!";
    while(<F>) {
	s/MSWin32-x86/MSWin32-x86-object/i;
	print W $_;
    }
    close W;
    close F;
}

__END__
