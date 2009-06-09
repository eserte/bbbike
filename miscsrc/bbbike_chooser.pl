#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;

use Cwd qw(realpath);
use FindBin;
use File::Basename qw(basename);
use File::Glob qw(bsd_glob);
use File::Spec qw();
use Getopt::Long;
use Tk;
use Tk::Balloon;
use Tk::Pane;

BEGIN {
    eval q{ use YAML::Syck qw(LoadFile); 1 } ||
	eval q{ use YAML qw(LoadFile); 1 } ||
	    die "Can't load a YAML loader: $@";
}

sub usage ();
sub guess_dataset_title_from_dir ($);

my $rootdir = my $this_rootdir = realpath(File::Spec->catfile($FindBin::RealBin, File::Spec->updir));

Getopt::Long::Configure("pass_through");
GetOptions("rootdir=s" => \$rootdir);

my $mw = tkinit;

#$mw->optionAdd('*font', '{sans serif} 10');
#{ my $bg = '#dfdbd7'; $mw->configure(-background => $bg); $mw->optionAdd('*background', $bg) }

@ARGV and usage;

my @bbbike_datadirs;

for my $dir (bsd_glob(File::Spec->catfile($rootdir, '*'))) {
    if (-d $dir) {
	my $meta_yml = File::Spec->catfile($dir, 'meta.yml');
	if (-f $meta_yml) {
	    my $meta = eval { LoadFile $meta_yml };
	    if (!$meta) {
		warn "WARN: Cannot load $meta_yml: $!, skipping this possible data directory...\n";
	    } else {
		$meta->{datadir} = $dir;
		$meta->{dataset_title} = guess_dataset_title_from_dir($dir)
		    if !$meta->{dataset_title};
		push @bbbike_datadirs, $meta;
	    }
	} elsif (basename($dir) =~ m{^data}) {
	    push @bbbike_datadirs, { datadir => $dir,
				     dataset_title => guess_dataset_title_from_dir($dir),
				   };
	}
    }
}

if (!@bbbike_datadirs) {
    $mw->messageBox(-message => "Sorry, no data directories found in $rootdir");
    exit;
}

my $xb = $mw->Button(-text => 'Exit',
		     -command => sub { $mw->destroy },
		    )->pack(-side => 'bottom');
$mw->bind('<Escape>' => sub { $xb->invoke });

my %opt;
$mw->Menubutton(-text => 'Options',
		-menuitems => [[Checkbutton => 'Lazy drawing (experimental, faster startup)',
				-variable => \$opt{'-lazy'},
			       ],
			       [Checkbutton => 'Warnings in a window',
				-variable => \$opt{'-stderrwindow'},
			       ],
			       [Checkbutton => 'Advanced mode',
				-variable => \$opt{'-advanced'},
			       ],
			      ]
	       )->pack(-side => 'bottom', -anchor => 'e');

my $bln = $mw->Balloon;
$mw->Label(-text => 'Choose your city/region:')->pack;
my $p = $mw->Scrolled("Pane", -sticky => 'nw', -scrollbars => 'ose')->pack(qw(-fill both));
my $adjust_geometry_cb;
for my $bbbike_datadir (sort { $a->{dataset_title} cmp $b->{dataset_title} } @bbbike_datadirs) {
    my($dataset_title, $datadir) = @{$bbbike_datadir}{qw(dataset_title datadir)};
    Tk::grid(my $b = $p->Button(-text => $dataset_title,
				-anchor => 'w',
				-command => sub {
				    my @cmd = ($^X, File::Spec->catfile($this_rootdir, 'bbbike'), '-datadir', $datadir,
					       (grep { $opt{$_} } keys %opt),
					      );
				    if (fork == 0) {
					exec @cmd;
					warn "Cannot start @cmd: $!";
					CORE::exit(1);
				    }
				    $mw->destroy;
				},
			       ), -sticky => 'ew');
    $bln->attach($b, -msg => $datadir);
    if (!$adjust_geometry_cb) {
	my $height = 400; $height = $mw->screenheight - 40 if $height > $mw->screenheight;
	$adjust_geometry_cb = $mw->after(50, sub { $p->GeometryRequest($b->Width+20, $height) });
    }
}

MainLoop;

sub guess_dataset_title_from_dir ($) {
    my $dir = shift;
    $dir = basename $dir;
    if ($dir eq 'data') {
	'Berlin (original BBBike data)';
    } else {
	my $city = $dir;
	$city =~ s{^data}{};
	$city =~ s{^[^A-Za-z]*}{}; # search for the alphabetic part
	$city = ucfirst $city;
	$city;
    }
}

sub usage () {
    die <<EOF;
usage: $0 [-rootdir directory] [Tk options]
EOF
}

__END__

=head2 TODO

 * german localization
 * store list of lru items into a config file
 * store options into a config file
 * get path to config file (~/.bbbike/bbbike_chooser_options) from a yet-to-written BBBikeUtil function
 * reorder the list to display the list of lru items at the top, with a separator to the other items
 * get a list of further directories from a Web address
 * download and unpack from Web
 * update data from Web

=cut
