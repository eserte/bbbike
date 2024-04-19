#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009,2012,2013,2014,2015,2017,2018,2019,2024 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

if ($^O eq 'MSWin32') {
    require BBBikeWinUtil;
    # call early, as required .dll libraries may
    # be in the PATH
    BBBikeWinUtil::adjust_path();
}

use Cwd qw(realpath);
use File::Basename qw(basename);
use File::Glob qw(bsd_glob);
use File::Spec qw();
use Getopt::Long;
use Tk;
use Tk::Balloon;
use Tk::Pane;

BEGIN {
    eval q{ use BBBikeYAML qw(LoadFile); 1 } ||
	eval q{ use YAML::Syck qw(LoadFile); 1 } ||
	    eval q{ use YAML qw(LoadFile); 1 } ||
		eval q{ use Safe; 1 } ||
		    die "ERROR: Can't load any YAML parser (tried BBBikeYAML, YAML::Syck and YAML) and also no success loading Safe.pm: $@";
}

use BBBikeDir qw(get_data_osm_directory);
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
	     'Close' => 'Schlie�en',
	     'Lazy drawing (experimental, faster startup)' => 'Verz�gertes Zeichnen (experimentell, schnellerer Start)',
	     'Warnings in a window' => 'Warnungen in ein eigenes Fenster',
	     'Advanced mode' => 'Fortgeschrittener Modus',
	     'Choose city/region:' => 'Stadt/Region ausw�hlen:',
	     '(original BBBike data)' => '(originale BBBike-Daten)',
	     'Options' => 'Optionen',
	     'More cities/regions @ bbbike.org' => 'Weitere St�dte/Regionen bei bbbike.org',
	     'Custom extract from extract.bbbike.org' => 'Ma�geschneiderte Region von extract.bbbike.org',
	     'After extracting the region on extract.bbbike.org, download the zip file, extract it on your computer and choose "Open local data directory"'
	     => 'Nach dem Ausschneiden der Region auf extract.bbbike.org, lade die ZIP-Datei herunter, packe sie auf dem Computer aus  und w�hle "Lokales Datenverzeichnis �ffnen"',
	     'Problem: cannot find more data at bbbike.org.' => 'Problem: es konnten keine weiteren Daten bei bbbike.org gefunden werden.',
	     "The download of '%s' was successful." => "Der Download von '%s' war erfolgreich.",
	     "An error occurred while downloading '%s'." => "Ein Fehler beim Downloaden von '%s' ist aufgetreten.",
	     "Open local data directory" => "Lokales Datenverzeichnis �ffnen",
	     "No directory selected" => "Kein Verzeichnis ausgew�hlt",
	     "Directory %s does not exist." => "Verzeichnis %s existiert nicht.",
	     "The directory %s does not look like a bbbike data directory." => "Das Verzeichnis %s ist kein BBBike-Datenverzeichnis.",
	    },
    }->{$lang};

sub usage ();
sub guess_dataset_title_from_dir ($);

my $rootdir = my $this_rootdir = realpath(File::Spec->catfile($FindBin::RealBin, File::Spec->updir));

my $bod = eval {
    require BBBikeOrgDownload;
    BBBikeOrgDownload->new;
};
if (!$bod) {
    warn "WARN: cannot create BBBikeOrgDownload object, no downloads from bbbike.org possible (error: $@)";
}

my $debug;
Getopt::Long::Configure("pass_through");
GetOptions(
	   "rootdir=s" => \$rootdir,
	   "debug!" => \$debug,
	  );

my $mw = tkinit;
$mw->title('BBBike chooser');

$mw->optionAdd('*advOpts*font', '{sans serif} 7');

#$mw->optionAdd('*font', '{sans serif} 10');
#{ my $bg = '#dfdbd7'; $mw->configure(-background => $bg); $mw->optionAdd('*background', $bg) }

@ARGV and usage;

my @bbbike_datadirs = find_all_datadirs();

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
$opt{'-lazy'} = 1;
$mw->Menubutton(Name => 'advOpts',
		-text => M"Options",
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
my $p = $mw->Scrolled("Pane", -sticky => 'nw', -scrollbars => 'ose')->pack(qw(-fill both -expand 1));
fill_chooser();

$mw->WidgetDump if $debug;
#$mw->after(1000,sub{warn "do it"; flash_city_button('Ruegen')});
MainLoop;

sub fill_chooser {
    # clean pane (for the refresh case)
    $_->destroy for _get_chooser_frame()->children;

    my $last_b;
    for my $bbbike_datadir (sort { $a->{dataset_title} cmp $b->{dataset_title} } @bbbike_datadirs) {
	my($dataset_title, $datadir) = @{$bbbike_datadir}{qw(dataset_title datadir)};
	Tk::grid(my $b = $p->Button(-text => $dataset_title,
				    -anchor => 'w',
				    -command => sub {
					start_bbbike_with_datadir($datadir);
				    },
				   ), -sticky => 'ew');
	$bln->attach($b, -msg => $datadir);
	$last_b = $b;
    }
    my $maybe_add_some_padding = do {
	my $vert_sep_done;
	sub {
	    if ($last_b && !$vert_sep_done) { # add some padding
		Tk::grid($p->Frame(-height => 5), -sticky => 'ew');
		$vert_sep_done = 1;
	    }
	};
    };
    if ($bod) {
	$maybe_add_some_padding->();
	Tk::grid($p->Button(-text => M('More cities/regions @ bbbike.org'),
			    -anchor => 'w',
			    -command => \&download_more,
			   ), -sticky => 'ew');
    }
    {
	$maybe_add_some_padding->();
	Tk::grid($p->Button(-text => M('Custom extract from extract.bbbike.org'),
			    -anchor => 'w',
			    -command => \&goto_extract_bbbike_org,
			   ), -sticky => 'ew');
    }
    {
	$maybe_add_some_padding->();
	Tk::grid($p->Button(-text => M('Open local data directory'),
			    -anchor => 'w',
			    -command => \&open_local,
			   ), -sticky => 'ew');
    }
    if ($last_b) {
	create_adjust_geometry_cb($p, $last_b);
    }
}

# Return the frame which has the city buttons as children
sub _get_chooser_frame {
    $p->Subwidget('scrolled')->Subwidget("frame");
}

sub create_adjust_geometry_cb {
    my($p, $b) = @_;
    my $height = 400; $height = $p->screenheight - 40 if $height > $p->screenheight;
    $p->after(50, sub { $p->GeometryRequest($b->Width+22, $height) });
}

sub find_all_datadirs {
    my @dirs;
    {
	my $data_osm_directory = get_data_osm_directory();
	if (-d $data_osm_directory) {
	    push @dirs, find_datadirs($data_osm_directory);
	}
    }
    push @dirs, find_datadirs($rootdir);
    @dirs;
}

sub find_datadirs {
    my($startdir) = @_;
    my @dirs;
    for my $dir (bsd_glob(File::Spec->catfile($startdir, '*'))) {
	if (-d $dir) {
	    my $meta = load_meta($dir);
	    if ($meta) {
		$meta->{datadir} = $dir;
		$meta->{dataset_title} = guess_dataset_title_from_dir($dir)
		    if !$meta->{dataset_title};
		push @dirs, $meta;
	    } else {
		my $base_dir = basename($dir);
		if (   $base_dir eq 'data-osm'    # Wolfram's convention
		    || $base_dir =~ m{^planet_\d} # from extract.bbbike.org
		   ) {
		    push @dirs, find_datadirs($dir); # XXX no recursion detection (possible with recursive symlinks...)
		} elsif ($base_dir =~ m{^data}) {
		    push @dirs, { datadir => $dir,
				  dataset_title => guess_dataset_title_from_dir($dir),
				};
		}
	    }
	}
    }
    @dirs;
}

sub guess_dataset_title_from_dir ($) {
    my $dir = shift;
    my $basedir = basename $dir;
    if ($basedir eq 'data') {
	return 'Berlin ' . M"(original BBBike data)";
    } elsif ($dir =~ m{(.*/planet_\d[^/]+)}) {
	my $extract_toplevel_dir = $1;
	my $dataset_title = eval {
	    require ExtractBBBikeOrg;
	    ExtractBBBikeOrg->get_dataset_title($extract_toplevel_dir);
	};
	return $dataset_title if defined $dataset_title;
    }

    # Fallback
    my $city = $basedir;
    $city =~ s{^data}{};
    $city =~ s{^[^A-Za-z]*}{}; # search for the alphabetic part
    $city = ucfirst $city;
    $city;
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

sub download_more {
    my @cities = eval { $bod->listing };
    if (!@cities) {
	$mw->messageBox(-message => M('Problem: cannot find more data at bbbike.org.') . ($@ ? "\n(Error: $@)" : ""));
	return;
    }
    my $t = $mw->Toplevel(-title => M('More cities/regions @ bbbike.org'));
    $t->Label(-text => M"Choose city/region:")->pack;
    my $p = $t->Scrolled("Pane", -sticky => 'nw', -scrollbars => 'ose')->pack(qw(-fill both -expand 1));
    my $last_b;
    for my $city (@cities) {
	Tk::grid(my $b = $p->Button(-text => $city,
				    -anchor => 'w',
				    -command => [\&download_city, $city, $t],
				   ), -sticky => 'ew');
	$bln->attach($b, -msg => "Download $city");
	$last_b = $b;
    }
    if ($last_b) {
	create_adjust_geometry_cb($p, $last_b);
    }
    $t->Button(-text => M"Close",
	       -command => sub { $t->destroy },
	      )->pack(-side => 'bottom');
}

sub download_city {
    my($city, $t) = @_;
    $t->Busy;
    eval {
	$bod->get_city($city);
    };
    my $err = $@;
    $t->Unbusy;
    if (!$err) {
	$mw->messageBox(-message => Mfmt("The download of '%s' was successful.", $city));
    } else {
	$mw->messageBox(-message => Mfmt("An error occurred while downloading '%s' (error: $err)", $city));
    }
    $t->destroy;

    # refresh:
    @bbbike_datadirs = find_all_datadirs();
    uniquify_titles();
    fill_chooser();
    flash_city_button($city);
}

sub goto_extract_bbbike_org {
    $mw->messageBox(-message => M('After extracting the region on extract.bbbike.org, download the zip file, extract it on your computer and choose "Open local data directory"'));
    require WWWBrowser;
    WWWBrowser::start_browser('http://extract.bbbike.org/?format=bbbike-perltk.zip');
}

sub open_local {
    my $directory = $mw->chooseDirectory;
    if (!defined $directory) {
	$mw->messageBox(-message => M"No directory selected");
	return;
    }
    if (!-d $directory) {
	$mw->messageBox(-message => Mfmt("Directory %s does not exist.", $directory));
	return;
    }

    my $check_bbbike_data_directory_candidates = sub () {
	my $check_bbbike_data_directory = sub ($) {
	    my $directory = shift;
	    -r "$directory/meta.dd" && -r "$directory/strassen";
	};

	if ($check_bbbike_data_directory->($directory)) {
	    return $directory;
	}
	# Maybe it's the planet directory above?
	my $candidate = "$directory/bbbike-data";
	if (-d $candidate && $check_bbbike_data_directory->($candidate)) {
	    return $candidate;
	}
    };

    my $datadir = $check_bbbike_data_directory_candidates->();
    if (!$datadir) {
	$mw->messageBox(-message => Mfmt("The directory %s does not look like a bbbike data directory.", $directory));
    } else {
	start_bbbike_with_datadir($datadir);
    }
}

# Start bbbike with specified data directory and the selected options,
# and close the bbbike_chooser program.
sub start_bbbike_with_datadir {
    my $datadir = shift;

    my @cmd = ($^X, File::Spec->catfile($this_rootdir, 'bbbike'), '-datadir', $datadir,
	       (grep { $opt{$_} } keys %opt),
	      );
    print STDERR "INFO: Starting '@cmd'...\n";
    if ($^O eq 'MSWin32') {
	# Sigh. Windows braindamage.
	require Win32Util;
	# no forking here
	system 1, Win32Util::win32_quote_list(@cmd);
	exit 0;
    } elsif ($ENV{DOCKER_BBBIKE}) {
	# If bbbike_chooser.pl was started as the CMD within a docker
	# container, then it must not exit prematurely as this would
	# finish the container, too. So just withdraw it, but keep it
	# running until bbbike exits.
	my $pid = fork;
	die "fork failed: $!" if !defined $pid;
	if ($pid == 0) {
	    system @cmd;
	    if ($? != 0) {
		die "Problems with @cmd?";
	    }
	    CORE::exit(0);
	}
	$mw->withdraw;
	$mw->update;
	waitpid $pid, 0;
	$mw->destroy;
    } else {
	if (fork == 0) {
	    exec @cmd;
	    warn "Cannot start @cmd: $!";
	    CORE::exit(1);
	}
	$mw->destroy;
    }
}

sub flash_city_button {
    my $city = shift;
    for my $b (_get_chooser_frame()->children) {
	if (eval { $b->cget(-text) eq $city }) {
	    flash_button($b);
	    return;
	}
    }
    warn "WARN: bbbike_chooser.pl: cannot find city '$city' in list of buttons.\n";
}

sub flash_button {
    my $b = shift;
    my $orig_bg = $b->cget(-background);
    my $flash_color = 'red';
    my $i = 6;
    my $change_color_cb;
    $change_color_cb = sub {
	return if !Tk::Exists($b);
	$i--;
	if ($i % 2 == 0) {
	    $b->configure(-background => $orig_bg);
	} else {
	    $b->configure(-background => $flash_color);
	}
	if ($i > 0) {
	    $b->after(200, $change_color_cb);
	}
    };
    $change_color_cb->();
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
