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
use FindBin;
use lib ("$FindBin::RealBin/../lib");

use Cwd qw(realpath);
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
	    eval q{ use Safe; 1 } ||
		die "ERROR: Can't load any YAML parser (tried YAML::Syck and YAML) and also no success loading Safe.pm: $@";
}

use Msg qw(M Mfmt noautosetup);

my $lang = Msg::get_lang() || 'en';
if ($lang !~ m{^(en|de)$}) {
    $lang = 'en';
}

$Msg::messages =
    { en => {}, # default language
      de => {
	     'Sorry, no data directories found in %s' => 'Sorry, keine Datenverzeichnisse in %s gefunden',
	     'Exit' => 'Beenden',
	     'Lazy drawing (experimental, faster startup)' => 'Verzögertes Zeichnen (experimentell, schnellerer Start)',
	     'Warnings in a window' => 'Warnungen in ein eigenes Fenster',
	     'Advanced mode' => 'Fortgeschrittener Modus',
	     'Choose city/region:' => 'Stadt/Region auswählen:',
	     '(original BBBike data)' => '(originale BBBike-Daten)',
	     'Options' => 'Optionen',
	    },
    }->{$lang};

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

find_datadirs($rootdir);

if (!@bbbike_datadirs) {
    $mw->messageBox(-message => Mfmt('Sorry, no data directories found in %s', $rootdir));
    exit;
}

uniquify_titles();

my $xb = $mw->Button(-text => M"Exit",
		     -command => sub { $mw->destroy },
		    )->pack(-side => 'bottom');
$mw->bind('<Escape>' => sub { $xb->invoke });

my %opt;
$mw->Menubutton(-text => M"Options",
		-menuitems => [[Checkbutton => M"Lazy drawing (experimental, faster startup)",
				-variable => \$opt{'-lazy'},
			       ],
			       [Checkbutton => M"Warnings in a window",
				-variable => \$opt{'-stderrwindow'},
			       ],
			       [Checkbutton => M"Advanced mode",
				-variable => \$opt{'-advanced'},
			       ],
			      ]
	       )->pack(-side => 'bottom', -anchor => 'e');

my $bln = $mw->Balloon;
$mw->Label(-text => M"Choose city/region:")->pack;
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
				    if ($^O eq 'MSWin32') {
					# no forking here
					{ exec @cmd }
					$mw->messageBox(-message => "Can't execute @cmd: $!",
							-icon => 'error');
				    } else {
					if (fork == 0) {
					    exec @cmd;
					    warn "Cannot start @cmd: $!";
					    CORE::exit(1);
					}
					$mw->destroy;
				    }
				},
			       ), -sticky => 'ew');
    $bln->attach($b, -msg => $datadir);
    if (!$adjust_geometry_cb) {
	my $height = 400; $height = $mw->screenheight - 40 if $height > $mw->screenheight;
	$adjust_geometry_cb = $mw->after(50, sub { $p->GeometryRequest($b->Width+20, $height) });
    }
}

MainLoop;

sub find_datadirs {
    my($startdir) = @_;
    for my $dir (bsd_glob(File::Spec->catfile($startdir, '*'))) {
	if (-d $dir) {
	    my $meta = load_meta($dir);
	    if ($meta) {
		$meta->{datadir} = $dir;
		$meta->{dataset_title} = guess_dataset_title_from_dir($dir)
		    if !$meta->{dataset_title};
		push @bbbike_datadirs, $meta;
	    } else {
		my $base_dir = basename($dir);
		if ($base_dir eq 'data-osm') { # Wolfram's convention
		    find_datadirs($dir); # XXX no recursion detection (possible with recursive symlinks...)
		} elsif ($base_dir =~ m{^data}) {
		    push @bbbike_datadirs, { datadir => $dir,
					     dataset_title => guess_dataset_title_from_dir($dir),
					   };
		}
	    }
	}
    }
}

sub guess_dataset_title_from_dir ($) {
    my $dir = shift;
    $dir = basename $dir;
    if ($dir eq 'data') {
	'Berlin ' . M"(original BBBike data)";
    } else {
	my $city = $dir;
	$city =~ s{^data}{};
	$city =~ s{^[^A-Za-z]*}{}; # search for the alphabetic part
	$city = ucfirst $city;
	$city;
    }
}

sub uniquify_titles {
    my %seen_title;
    for my $def (@bbbike_datadirs) {
	push @{ $seen_title{$def->{dataset_title}} }, $def;
    }
    while(my($title, $v) = each %seen_title) {
	if (@$v > 1) {
	    for my $rec (@$v) {
		$rec->{dataset_title} .= " (" . basename($rec->{datadir}) . ")"; # XXX should try harder if the basenames are also same
	    }
	}
    }
}

sub load_meta {
    my $dir = shift;

    my $meta_yml = File::Spec->catfile($dir, 'meta.yml');
    if (-f $meta_yml && defined &LoadFile) {
	my $meta = eval { LoadFile $meta_yml };
	if (!$meta) {
	    warn "WARN: Cannot load $meta_yml: $!, will try another fallback...\n";
	} else {
	    return $meta;
	}
    }

    my $meta_dd = File::Spec->catfile($dir, 'meta.dd');
    if (-f $meta_dd) {
	my $c = Safe->new;
	my $meta = $c->rdo($meta_dd);
	if (!$meta) {
	    warn "WARN: Also cannot load $meta_dd: $!, skipping this possible data directory...\n";
	    return;
	} else {
	    return $meta;
	}
    }

    # Don't warn, we're usually trying every directory under
    # $bbbike_root...
    undef;
}

sub usage () {
    die <<EOF;
usage: $0 [-rootdir directory] [Tk options]
EOF
}

__END__

=head2 TODO

 * store list of lru items into a config file
 * store options into a config file
 * get path to config file (~/.bbbike/bbbike_chooser_options) from a yet-to-written BBBikeUtil function
 * reorder the list to display the list of lru items at the top, with a separator to the other items
 * get a list of further directories from a Web address
 * download and unpack from Web
 * update data from Web

=cut
