#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: tkinstall.pl,v 1.1 1999/12/12 13:43:05 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# XXX not tested!!!!

use Tk;
use Tk::DirTree;
use Tk::ROText;
use File::Find;
use File::Copy qw(copy);
use File::Path;
use File::Spec;
use File::Basename;
use FindBin;

my $echo = 1;    # nur schreiben, nichts machen (zum Debuggen)
my $verbose = 1;

$top = new MainWindow;
my $dir;
my $selected = 0;

my $startdir;
if ($^O eq 'MSWin32') {
    $startdir = "C://";
} else {
    foreach my $testdir (qw(/opt /usr/local/lib /usr/lib /usr/local/share /)) {
	if (-d $testdir) {
	    $startdir = $testdir;
	    last;
	}
    }
}

my $dl = $top->Scrolled("DirTree",
			-directory => $startdir,
			-command => sub {
			    $dir = $_[0];
			    $selected = 1;
			})->pack(-fill => "both", -expand => 1);
eval q{ $dl->anchorSet("/$startdir") }; warn $@ if $@;

$top->Button(-text => "Installation beginnen",
	     -command => sub {
		 $dir = $dl->info('anchor');
		 $selected = 1;
	     })->pack;

my $txt = $top->Scrolled('ROText', -scrollbars => "osoe"
			 )->pack(-fill => "both", -expand => 1);
tie *STDOUT, Tk::Text, $txt->Subwidget('rotext');
tie *STDERR, Tk::Text, $txt->Subwidget('rotext');

$top->waitVariable(\$selected);

if (!defined $dir) {
    $top->messageBox(-title => "BBBike-Installation",
		     -type => 'OK',
		     -bitmap => 'error',
		     -message => "Kein Verzeichnis angegeben.\nDie Installation wird abgebrochen.");
    exit();
}

TRY: {
    if (opendir(D, $dir)) {
	while(defined($_ = readdir D)) {
	    my $fullpath = File::Spec->catfile($dir, $_);
	    if (-d $fullpath) {
		if (/^bbbike/i) {
		    $dir = $fullpath;
		    last TRY;
		}
	    }
	}
	closedir D;
    }
    $dir = File::Spec->canonpath("$dir/BBBike");
}

_mkpath([$dir], 1, 0755);
cp_r($FindBin::RealBin, $dir);

$top->messageBox(-title => "BBBike-Installation",
		 -type => 'OK',
		 -bitmap => 'info',
		 -message => "Nun folgt die zweite Stufe der Installation.\n");
$top->destroy;

system("$^X $dir/install.pl -tk");

sub cp_r {
    my($srcdir, $destdir) = @_;
    
    if ($verbose) {
	print STDERR "Recursive copy from $srcdir to $destdir\n";
    }

    my $src2dest = sub {
	my $f = shift;
	$f =~ s/^$srcdir/$destdir/;
	$f;
    };

    my $wanted = sub {
	$top->update;
	if (-d $_) {
	    return if $_ eq '.' || $_ eq '..';
	    _mkpath([$src2dest->($File::Find::name)], 1, 0755);
	} elsif (-f $_) {
	    _copy($_, $src2dest->($File::Find::name));
	} else {
	    print STDERR "Ignore $File::Find::name\n";
	}
    };

    find($wanted, $srcdir);
}

sub _mkpath {
    if ($verbose) {
	print STDERR "mkpath " . join(", ", @{$_[0]}) . "\n";
    }
    unless ($echo) {
	mkpath @_;
    }
}

sub _copy {
    if ($verbose) {
	print STDERR "copy $_[0] $_[1]\n";
    }
    unless ($echo) {
	copy @_;
    }
}

__END__
