#!/usr/bin/env perl
# -*- perl -*-

#
# $Id: install.pl,v 4.9 2003/01/08 17:53:50 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 1999-2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use FindBin;
use lib ("$FindBin::Bin", "$FindBin::Bin/lib"); # XXX necessary???
use Config;
use File::Path;
use File::Basename;
use File::Copy;
use strict;
use Getopt::Long;
use Cwd;

BEGIN {
    if (!eval '
use Msg;
1;
') {
	warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

use vars qw(%config_vars);
BEGIN {
    # one per line ... these are used in the config file
    %config_vars = qw(
       HOMEPAGE		      $homepage
       PROGRAM_TITLE	      $program_title
       MAIN_PROGRAM	      $main_program
       MAIN_PROGRAM_ARGS      @main_program_arguments
       MAIN_DESCRIPTION	      $main_description
       HTML_DOCUMENTATION     $html_documentation
       CONSOLE_PROGRAM	      $console_program
       CLIENT_PROGRAM	      $client_program
       USE_CLIENT_SERVER_MODE $use_client_server_mode
       USE_AUTOSTART	      $use_autostart
       EXTENSIONS	      $extensions
       MODULE_EXT             @module_ext
       WIN_EXTENSIONS         @win_extensions
       DESKTOP_ICON	      $desktop_icon
       UNIX_ICON	      $unix_icon
       UNIX_MINI_ICON	      $unix_mini_icon
       WIN_ICON		      $win_icon
       WIN_WWW_ICON	      $win_www_icon
       DEBUG_SWITCH           $debug_switch
       NO_WPERL               $no_wperl
       EXTRA_LIBDIR           $extra_libdir
    );
}

use strict;
use vars values %config_vars;
use vars qw($is_bbbike);

my $uninstall_mode = ($0 =~ /uninstall\.pl$/ ? 1 : 0);

if ($uninstall_mode) {
    # works right if called through install.pl -uninstall
    eval { do "$FindBin::RealBin/install.pl.config" }; warn $@ if $@;
} else {
    eval { do "$0.config" }; warn $@ if $@;
}
load_Makefile_PL();

# add more dirs

if (!defined $extra_libdir) {
    $extra_libdir = $main_program =~ /^[A-Z]/ ? $main_program : ucfirst($main_program);
}
unshift @INC, "$_/$extra_libdir", "$_/lib/$extra_libdir" for reverse @INC;

my $kde_install   = 'best';
my $gnome_install = 'best';
my $win_install   = 'best';
$desktop_icon = 1 unless defined $desktop_icon;
my $show = 0;
$extensions = 1 unless defined $extensions;
my $onlyextensions = 0;
my $cleanextensions = 0;
my $networkinstall = 0;
my $startinstall = 1;
my $use_tk = 1;
my $debuginstall;
$debuginstall = 0 if defined $debug_switch;
my $auto = 0;
my $perlbat;
my $os;
my $Print_indent = "";
my $debug = 0;

my $start_program;
my @start_args;
my $start_chdir;

if ($^O =~ /os2/i || $^O =~ /MSWin32/i) {
    $os = 'win';
} else {
    $os = 'unix';
}

if ($os eq 'unix') {
    $use_tk = defined $ENV{DISPLAY};
}

*input  = sub { @_ };
*output = sub { @_ };

sub Print (@);
sub Print_shift ();
sub Print_unshift ();

my %optdesc =
  ('desktop'    => M"Desktop-Icon erstellen",
   'show'       => M"Schritte zeigen und nicht ausführen",
   'debuginstall' => M"Debugging-Version erzeugen",
  );
if (@module_ext && $extensions) {
    $optdesc{'extensions'} = M"Erweiterungen compilieren";
}
if ($os eq 'win') {
    $optdesc{'networkinstall'} = M"Netzwerkfähige-Installation für Win32";
    $optdesc{'startinstall'} = M"Eintrag im Startmenü erstellen";
    if (defined $use_autostart) {
	$optdesc{'autostart'} = M"Autostart";
    }
} elsif ($os eq 'unix') {
    #$optdesc{'kdeinstall'}   = 'Menüeinträge für KDE erstellen';
    #$optdesc{'gnomeinstall'} = 'Menüeinträge für GNOME erstellen';
    if (defined $use_client_server_mode) {
	$optdesc{'clientservermode'} = M"Server-Client-Modus verwenden";
    }
}

if (!defined $program_title) {
    $program_title = ucfirst($main_program);
}

my $root_or_user_sub = sub {
    my($opt, $arg, $var) = @_;
    die Mfmt('Argument für %s muss root, user oder best sein', $opt)
	if $arg !~ /^(none|root|user|best)$/;
    $$var = $arg;
};

my @options =
  ('kdeinstall=s' => sub { $root_or_user_sub->(\$kde_install) },
#     sub { my $arg = $_[1];
#  	 die "Argument for kdeinstall must be root, user or best"
#  	     if $arg !~ /^(none|root|user|best)$/;
#  	 $kde_install = $arg;
#       },
   'gnomeinstall=s' => sub { $root_or_user_sub->(\$gnome_install) },
   'wininstall=s'   => sub { $root_or_user_sub->(\$win_install) },

   'desktop!'    => \$desktop_icon,
   'show!'       => \$show,
   'extensions!' => \$extensions,
   'onlyextensions!'  => \$onlyextensions,
   'cleanextensions!' => \$cleanextensions,
   'networkinstall!'  => \$networkinstall,
   'startinstall!'    => \$startinstall,
   'debuginstall!'    => \$debuginstall,
   'uninstall!'       => \$uninstall_mode,
   'clientserver!'    => \$use_client_server_mode,
   'autostart!'       => \$use_autostart,
   'perlbat=s'        => \$perlbat,
   'tk!' => \$use_tk,
   'auto!' => \$auto,
   "debug!" => \$debug,
  );

if ($os eq 'win' && !$use_tk) { # DOS-Console benutzt noch cp-sonstwas :-(
    *input = \&cp850_iso;
    *output = \&iso_cp850;
}

if (!GetOptions(@options)) {
    my @usage_opt;
    for(my $i=0; $i<$#options; $i+=2) {
	push @usage_opt, $options[$i];
    }
    die "Usage: $0 " . join(" ", map { "[-$_]" } @usage_opt) . "\n";
}

$extensions = 1 if ($onlyextensions);

if ($uninstall_mode) {
    exit Uninstall();
}

my($top, $txt, $close_frame);
if ($use_tk) {
    require Tk;
    require Tk::ROText;
    require Tk::Dialog;
    require Tk::ErrorDialog;
    $top = Tk::tkinit();
    $top->title(Mfmt("Installation für %s", $program_title));
    $top->protocol("WM_DELETE_WINDOW" => sub { exit });
    $top->geometry("+" . int($top->screenwidth/2-320) .
		   "+" . int($top->screenheight/2-240));
    my $f = $top->Frame->pack(-expand => 1, -fill => 'both');
    my $gridy = 0;
    for(my $i = 0; $i<=$#options; $i+=2) {
	my($opt, $action) = ($options[$i], $options[$i+1]);
	next if ($os ne 'unix' && $opt =~ /^kde/);
	next if ($os ne 'unix' && $opt eq 'clientservermode');
	next if !($opt =~ /^(.*)!$/ && ref $action eq 'SCALAR');
	$opt = $1;
	next if !exists $optdesc{$opt};
	$f->Label(-text => $optdesc{$opt})->grid(-column => 0, -row => $gridy,
						 -sticky => 'w');
	$f->Checkbutton(-variable => $action
		       )->grid(-column => 1, -row => $gridy,
			       -sticky => 'w');
	$gridy++;
    }
    my $wait = 0;
    my $ff = $f->Frame->grid(-column => 0, -columnspan => 2,
			     -row => $gridy, -sticky => "ew");
    my $ib = $ff->Button(-text => M"Installieren",
			 -command => sub { $wait++ }
			)->pack(-side => "left", -expand => 1);
    $ib->focus;
    $ff->Button(-text => M"Abbrechen",
		-command => sub { Tk::exit() },
	       )->pack(-side => "left", -expand => 1);

    if ($auto) {
	$f->after(10, sub { $ib->invoke });
    }

    $f->waitVariable(\$wait);
    $f->destroy;

    # to prevent segfaults:
    $top->protocol('WM_DELETE_WINDOW' => sub { $top->destroy });

    my $min = sub { $_[0] < $_[1] ? $_[0] : $_[1] };
    # XXX The -width seems to be necessary, otherwise the window
    # will have the size 1x1 pixels (why?)
    $close_frame = $top->Frame(-width => $min->(500,$top->screenwidth),
			       #-height => $min->(50,$top->screenheight),
			      )->pack(-fill => "x", -side => "bottom");
    $txt = $top->Scrolled('ROText', -scrollbars => 'osoe',
			  -wrap => "none",
			  )->pack(-fill => "both");
    tie *STDOUT, 'Tk::Text', $txt->Subwidget('text');
    tie (*STDERR, 'Tk::Text', $txt->Subwidget('text'));
    $txt->update;
    for ($top, $txt) {
	$_->configure(-cursor => 'watch');
    }
}

unless ($onlyextensions) {

    ModuleCheck();
    if ($^O eq 'MSWin32') {
	Win32Install(-type => $win_install);
    }
    if ($os ne "win") { # there's no KDE/GNOME for Windows
	KDEInstall(-type => $kde_install);
	GNOMEInstall(-type => $gnome_install);
    }
}
ModuleExtensions(-clean => $cleanextensions) if $extensions;

if ($use_tk) {
    if ($auto) {
	$top->update;
	$top->tk_sleep(1);
	$top->destroy;
    } else {
	$top->Dialog(-title => Mfmt("%s-Installation", $program_title),
		     -text => M("Die Installation ist beendet.") .
		     ($startinstall
		      ? "\n" .
		      ($os ne 'unix'
		       ? Mfmt("%s kann aus dem Startmenü heraus gestartet werden.", $program_title)
		       : Mfmt("%s kann aus dem Startmenü von KDE oder GNOME heraus gestartet werden.", $program_title))
		      : ""),
		     -buttons => [M"OK"],
		    )->Show if !$show;
	for ($txt, $top) {
	    $_->configure(-cursor => undef);
	}

	my $close_button = $close_frame->Button
	    (-text => M"Fenster schließen",
	     -command => sub { $top->destroy },
	    )->pack(-fill => 'x', -expand => 1, -side => "left");
	if (defined $start_program && !$show) {
	    chdir $start_chdir if defined $start_chdir;
	    my $start_button = $close_frame->Button
		(-text => M"Programm starten",
		 -command => sub {
		     $top->destroy;
		     if ($os eq 'win') {
			 Win32Util::start_cmd($start_program, @start_args);
		     } else {
			 if (!fork) {
			     exec $start_program, @start_args;
			     warn Mfmt("Kann %s nicht starten: %s", $start_program, $!);
			     CORE::exit();
			 }
		     }
		 },
		)->pack(-fill => 'x', -expand => 1, -side => "left");
	}

	Tk::MainLoop();
    }
}

sub ModuleCheck {
    my @missing_mod;
#XXX aus Bundle::XXX extrahieren ... oder aus XXX.pod/PREREQUISITES ...
# oder aus Makefile.PL ...
    # required modules
    for my $module (qw(Tk)) {
	if (!CheckModule($module)) {
	    push @missing_mod, $module;
	}
    }
#XXX    # optional modules
#    my @opt_mod = (
#    for my $modu
    if (@missing_mod) {
	Print
	  M("Die folgenden perl-Module werden benötigt:")."\n",
	  "  " . join(", ", @missing_mod) . "\n",
	  M("Sollen sie aus dem Internet geholt und installiert werden? (j/n) ");
	my $jn = <STDIN>;
	my $yesrx = M"^j";
	if ($jn =~ /$yesrx/i) {
	    require CPAN;
	    if (!$show) {
		foreach my $mod (@missing_mod) {
		    my $obj = CPAN::Shell->expand('Distribution', $mod);
		    if ($obj) {
			eval {
			    $obj->install;
			};
			Print "$@\n" if $@;
		    }
		}
	    }
	}
	Print "\n";
    }
}

sub CheckModule {
    my $module = shift;
    eval 'use ' . $module;
    ($@ ? 0 : 1);
}

sub Win32Install {
    my(%args) = @_;
    my $type = $args{-type} || 'user';
    return if $type eq 'none';

    eval {
	require Win32Util;
    };
    if ($@) { my_die($@) }

    my $public = 0;
    if (($type eq 'root' || $type eq 'best') && Win32Util::is_administrator()){
	$public = 1;
    }

    my($realbin, $perlexe, $wperlexe);
    if ($networkinstall) {
	$realbin = Win32Util::path2unc($FindBin::Bin);
	$perlexe = Win32Util::path2unc($^X);
    } else {
	$realbin = $FindBin::Bin;
	$perlexe = $^X;
    };
    (my $wperlexe = $perlexe) =~ s/\bperl\.exe$/wperl.exe/i;
    if (!-x $wperlexe || $no_wperl || $debuginstall) {
	$wperlexe = $perlexe;
    }
    if ($debuginstall && $debug_switch) {
	unshift @main_program_arguments, $debug_switch;
    }
    my $ico = "$realbin/$win_icon";
    if (defined $perlbat and -f $perlbat) {
	$wperlexe = $perlbat;
    }

    Print M"Windows-Installation ";
    if ($public) {
	Print M"(rechnerweit) ";
    } else {
	Print M"(privat) ";
    }
    Print "...\n";
    Print_shift;

    if (@win_extensions) {
	Print Mfmt("%s in die Registry eintragen ...", $program_title)."\n";
	Print_shift;
	foreach my $ext (@win_extensions) {
	    if (!$ext->{'-icon'}) {
		$ext->{'-icon'} = $ico;
	    }
	    if (!$ext->{'-open'}) {
		$ext->{'-open'} = join(" ",
				       $wperlexe,
				       "$realbin/$main_program",
				       @main_program_arguments,
				       "\"%1\"");
	    }
	    Print $ext->{'-extension'} . " (" . $ext->{'-desc'} . ")\n";
	    if (!$show) {
		Win32Util::install_extension(%$ext);
	    } else {
		warn "-open command: $ext->{-open}\n";
	    }
	}
	Print_unshift;
	Print "\n";
    }

    my %main_shortcut_args =
      (-name => $program_title,
       -path => $wperlexe,
       -args => join(" ", "$realbin/$main_program", @main_program_arguments),
       -icon => $ico,
       -public => $public,
       Description => $main_description,
       WorkingDirectory => $realbin,
      );

    $start_chdir   = $realbin;
    $start_program = $wperlexe;
    @start_args    = ("$realbin/$main_program", @main_program_arguments);

    if ($startinstall) {
	Print Mfmt("Programmgruppe für %s erstellen ...", $program_title)."\n";
	if (!$show) {
	    my @files = (\%main_shortcut_args);

	    if (defined $homepage) {
		push @files,
		    {
		     -name => Mfmt("%s im WWW", $program_title),
		     -icon => "$realbin/$win_www_icon",
		     -url  => $homepage,
		    };
	    }

	    if (defined $html_documentation) {
		push @files,
		    {
		     -name => Mfmt("%s Dokumentation", $program_title),
		     -path => "$realbin/$html_documentation",
		    };
	    }

	    if (defined $console_program) {
		push @files,
		    {
		     -name => Mfmt("Konsolenversion von %s", $program_title),
		     -path => "$perlexe",
		     -args => "-I $realbin/lib $realbin/$console_program",
		     Description =>
		     Mfmt("Version von %s, die ohne Tk " .
			  "in der MSDOS-Eingabeaufforderung läuft",
			  $program_title),
		     WorkingDirectory => "$realbin",
		    };
	    }

	    if ($is_bbbike) { # XXX
		push @files,
		    {
		     -name => 'BikePower',
		     -path => "$wperlexe",
		     -args => "-I $realbin/lib $realbin/tkbikepwr",
		     Description => "BikePower - Leistungsberechnungen für Radfahrer",
		     WorkingDirectory => "$realbin",
		    };
	    }

	    Win32Util::create_program_group
		    (-parent => $program_title,
		     -files => \@files,
		     -public => $public,
		    );
	}
	Print "\n";
    }

    if ($desktop_icon) {
	Print
	  Mfmt("Desktop-Verknüpfung (Shortcut) für %s erstellen ...",$program_title)."\n";
	if (!$show) {
	    Win32Util::create_shortcut(%main_shortcut_args);
	}
	Print "\n";
    }

    if ($use_autostart) {
	Print
	  Mfmt("%s wird nach dem Booten automatisch gestartet ...", $program_title)."\n";
	if (!$show) {
	    Win32Util::create_shortcut(%main_shortcut_args, -autostart => 1);
	}
	Print "\n";
    }

    Print_unshift;

}

sub KDEInstall {      # XXX ersetzt makefile für freebsd-port
    my(%args) = @_;
    my $type = $args{-type} || 'root'; # may be 'root', 'user' or 'best'
    return if $type eq 'none';

    if (!$is_bbbike) {
	Print "KDE-Installation wird noch nicht unterstützt! XXX\n\n";
	return;
    }

    my $r = eval {
	require KDEUtil;
	1;
    };
    return if !$r;

    Print M("KDE-Installation")." ...\n";
    Print_shift;
    my $kde = new KDEUtil;

    my $ret;
    my $old_umask = umask 0022;
    my %kdedirs;
    if ($type eq 'root' || $type eq 'best') {
	%kdedirs = $kde->kde_dirs(undef, 1);
    }

    if ($type eq 'user' || (!defined %kdedirs && $type eq 'best')) {
	my $homedir = _get_homedir();
	if (defined $homedir) {
	    %kdedirs = $kde->kde_dirs("$homedir/.kde", 1);
	}
	Print "$@\n" if $@;
	$type = 'user';
    }

    $type = 'root' if ($type eq 'best');

    if (!defined %kdedirs) {
	Print
	    M"Keine Verzeichnisse für die KDE-Installation gefunden.\n";
	goto KDEEND;
    }

# XXX @main_program_arguments
    my $main_bin = (exists $kdedirs{-bin}
		    ? "$kdedirs{-bin}/$main_program"
		    : "$FindBin::Bin/$main_program"
		   );
    my $client_bin = (exists $kdedirs{-bin}
		      ? "$kdedirs{-bin}/$client_program"
		      : "$FindBin::Bin/$client_program"
		     );

    my($bbbike_kdelnk, $bbbike_doc_kdelnk, $bbbike_www_kdelnk);

# XXX mehr nach KDEUtil.pm verlagern

    if (exists $kdedirs{-applnk}) {
	Print M"Installation der KDE-Verknüpfungen ...\n";
	Print_shift;
	my $applications_dir  = "$kdedirs{-applnk}/Applications";
	if (!-d $applications_dir) {
	    if ($show) {
		Print "mkdir $applications_dir, 0755\n";
	    } else {
		mkdir $applications_dir, 0755;
	    }
	    # copy .directory (see GNOME!)
	}

	# XXX hmmm: .../doc/HTML/default vs. .../doc/HTML/de?
	my $has_docpath = 0;
	if ($type eq 'root' && exists $kdedirs{-doc}) {
	    if ($show) {
		Print M"Dokumentation für DocPath\n";
	    } else {
		my $destdir = $kdedirs{-doc} . "/de";
		if (!-d $destdir) {
		    mkdir $destdir, 0755;
		}
		if (-d $destdir && -w $destdir) {
		    _safe_symlink("$FindBin::Bin/$html_documentation",
				  "$destdir/$html_documentation");
		    if (-l "$destdir/$html_documentation") {
			$has_docpath = 1;
		    }
		}
	    }
	}

	$bbbike_kdelnk     = "$applications_dir/BBBike.kdelnk";
	if ($show) {
	    Print M("BBBike.kdelnk.tmpl nach $applications_dir mit\n" .
		    "  Variablensubstitution kopieren.\n");
	} else {
	    if (open(KDELNK, "$FindBin::Bin/kde/BBBike.kdelnk.tmpl") &&
		open(SAVE,   ">$bbbike_kdelnk")) {
		while(<KDELNK>) {
		    if (/^Exec=/i) {
			if ($use_client_server_mode) {
			    print SAVE "Exec=$^X $client_bin %f\n";
			} else {
			    print SAVE "Exec=$^X $main_bin %f\n";
			}
		    } elsif (/^DocPath=/i) {
			if ($has_docpath) {
			    print SAVE "DocPath=$html_documentation\n";
			}
		    } else {
			print SAVE $_;
		    }
		}
		close SAVE;
		close KDELNK;
	    }
	}

	$bbbike_doc_kdelnk = "$applications_dir/BBBikeDoc.kdelnk";
	if ($show) {
	    Print "BBBikeDoc.kdelnk.tmpl nach $applications_dir mit\n" .
	      "  Variablensubstitution kopieren.\n";
	} else {
	    if (open(KDELNK, "$FindBin::Bin/kde/BBBikeDoc.kdelnk.tmpl") &&
		open(SAVE,   ">$bbbike_doc_kdelnk")) {
		while(<KDELNK>) {
		    if (/^URL=/i) {
			print SAVE "URL=file:$FindBin::Bin/$html_documentation\n";
		    } else {
			print SAVE $_;
		    }
		}
		close SAVE;
		close KDELNK;
	    }
	}

	$bbbike_www_kdelnk = "$applications_dir/BBBikeWWW.kdelnk";
	if ($show) {
	    Print "BBBikeWWW.kdelnk nach $applications_dir kopieren.\n";
	} else {
	    copy("$FindBin::Bin/kde/BBBikeWWW.kdelnk", $bbbike_www_kdelnk);
	    chmod 0644, $bbbike_www_kdelnk;
	}
	Print_unshift;
    }

    if (exists $kdedirs{-mimelnk}) {
	Print
	  "Installation der MIME-Verknüpfung für BBBike-Routen...\n";
	Print_shift;
	my $application_dir = "$kdedirs{-mimelnk}/application";
	if (!-d $application_dir) {
	    if ($show) {
		Print "mkdir $application_dir, 0755\n";
	    } else {
		mkdir $application_dir, 0755;
	    }
	}

	foreach my $mimefile (qw(x-bbbike-route x-bbbike-data x-gpstrack)) {
	    my $dest = "$kdedirs{-mimelnk}/application/$mimefile.kdelnk";
	    if ($show) {
		Print "copy to $dest and chmod 0644\n";
	    } else {
		copy("$FindBin::Bin/kde/$mimefile.kdelnk", $dest);
		chmod 0644, $dest;
	    }
	}

	my $magic = "$kdedirs{-mimelnk}/magic";
	my @old_magic;
	my %has_magic;
	if (open(MAGIC, $magic)) {
	    while(<MAGIC>) {
		if (/application\/x-bbbike-route/) {
		    $has_magic{'route'} = 1;
		} elsif (/application\/x-gpstrack/) {
		    $has_magic{'gpstrack'} = 1;
		}
		push @old_magic, $_;
	    }
	    close MAGIC;
	    if (!($has_magic{'route'} and
		  $has_magic{'gpstrack'})) {
		if ($show) {
		    Print "write BBBike route magic to $magic\n";
		} else {
		    if (open(MAGIC, ">$magic")) {
			print MAGIC join("", @old_magic);
			print MAGIC "# BBBike\n";
			if (!$has_magic{'route'}) {
			    print MAGIC "0\t\tstring\t\\#BBBike\\ route\tapplication/x-bbbike-route\n";
			}
			if (!$has_magic{'gpstrack'}) {
			    print MAGIC "0\t\tstring\tTRK\\ \t\tapplication/x-gpstrack\n";
			}
			print MAGIC "#\n";
			close MAGIC;
		    }
		}
	    }
	}
	Print_unshift;
    }

    if (exists $kdedirs{-icons}) {
	Print "Installation der BBBike-Icons für KDE ...\n";
	Print_shift;
	foreach my $img ($unix_icon,
			 $unix_mini_icon,
			 qw(srtbike_www.xpm)) {
	    my $dest = "$kdedirs{-icons}/$img";
	    if ($show) {
		Print "copy to $dest and chmod 0644\n";
	    } else {
		copy("$FindBin::Bin/images/$img",$dest);
		chmod 0644, $dest;
	    }
	}
	Print_unshift;
    }

    if (exists $kdedirs{-bin}) {
	foreach my $f ($main_bin, $client_bin) {
	    my $thisf = $FindBin::Bin . "/" . basename($f);
	    if ($thisf ne $f) {
		Print "Symbolischen Link von $f nach\n" .
		  "  $thisf erzeugen ...\n";
		if (!$show) {
		    _safe_symlink($thisf, $f, 1);
		}
	    }
	}
    }

    if ($desktop_icon) {
	my $homedir = _get_homedir();
	if (defined $homedir) {
	    my $desktop = "$homedir/Desktop";
	    if (-d $desktop && -w $desktop) {
		my $kdelnk = "$desktop/BBBike.kdelnk";
		if (defined $bbbike_kdelnk && -e $bbbike_kdelnk) {
		    if ($show) {
			Print "Symlink $kdelnk => $bbbike_kdelnk\n";
		    } else {
			_safe_symlink($bbbike_kdelnk, $kdelnk);
		    }
		}
		$kdelnk = "$desktop/BBBikeWWW.kdelnk";
		if (defined $bbbike_www_kdelnk && -e $bbbike_www_kdelnk) {
		    if ($show) {
			Print "Symlink $kdelnk => $bbbike_www_kdelnk\n";
		    } else {
			if (-e $kdelnk) { unlink $kdelnk }
			copy("$FindBin::Bin/kde/BBBikeWWW.kdelnk",
			     $kdelnk);
			chmod 0644, $kdelnk;
		    }
		}
	    }
	}
    }

    if ($show) {
	Print "Restarting kpanel\n";
	Print "Refreshing desktop\n";
    } else {
	#system("kwmcom", "kpanel:restart");
	# XXX this will start the kde filemanager, even if we
	# aren't running kde...
	#$kde->panel->restart;
	#$kde->fm->refreshDesktop;
    }

  KDEEND:
    Print_unshift;
    Print "\n";
    $ret;
}

sub GNOMEInstall {      # XXX unify with KDEInstall/Win32Install
    my(%args) = @_;
    my $type = $args{-type} || 'root'; # may be 'root', 'user' or 'best'
    return if $type eq 'none';

    if (!$is_bbbike) {
	Print "GNOME-Installation wird noch nicht unterstützt! XXX\n\n";
	return;
    }

    Print "GNOME-Installation ...\n";
    Print_shift;

    my $ret;
    my $old_umask = umask 0022;
    my $global_gnomedir;
    if (!is_in_path("gnome-config")) {
	Print "gnome-config nicht gefunden\n";
	goto GNOMEEND;
    }

    chomp($global_gnomedir = `gnome-config --datadir`);
    my $gnomedir;
    if ($type eq 'root' || $type eq 'best') {
	if (-w $global_gnomedir) {
	    $gnomedir = $global_gnomedir;
	}
    }

    if ($type eq 'user' || (!defined $gnomedir && $type eq 'best')) {
	my $homedir = _get_homedir();
	if (defined $homedir and
	    -d "$homedir/.gnome" and
	    -w "$homedir/.gnome") {
	    $gnomedir = "$homedir/.gnome";
	}
	$type = 'user';
    }

    $type = 'root' if ($type eq 'best');

    if (!defined $gnomedir) {
	Print
	  "Keine Verzeichnisse für die GNOME-Installation gefunden.\n";
	goto GNOMEEND;
    }

# XXX @main_program_arguments
    my $main_bin   = "$FindBin::Bin/$main_program";
    my $client_bin = "$FindBin::Bin/$client_program";

    my($bbbike_gnomelnk, $bbbike_doc_gnomelnk, $bbbike_www_gnomelnk);

# XXX GNOMEUtil.pm schreiben

    Print "Installation der GNOME-Verknüpfungen ...\n";
    Print_shift;
    my $applications_dir  = "$gnomedir/apps/Applications";
    if (!-d $applications_dir) {
	if ($show) {
	    Print "mkdir $applications_dir, 0755\n";
	} else {
	    mkdir $applications_dir, 0755;
	}

	if (!-f "$applications_dir/.directory" and
	    -r "$global_gnomedir/apps/Applications/.directory") {
	    if ($show) {
		Print "copy .directory to $applications_dir/.directory";
	    } else {
		copy("$global_gnomedir/apps/Applications/.directory",
		     "$applications_dir/.directory");
	    }
	}

    }
    Print_unshift;#XXX hier?

    # XXX hmmm....
    my %metadata;
    if (!$show and $type eq 'user') {
	eval q{
	    use DB_File;
	    tie %metadata, 'DB_File', "$gnomedir/metadata.db", O_RDWR, 0666;
	};
    }

#      # XXX hmmm: .../doc/HTML/default vs. .../doc/HTML/de?
#      my $has_docpath = 0;
#      if ($type eq 'root' && exists $kdedirs{-doc}) {
#  	    if ($show) {
#  		Print "Dokumentation für DocPath\n";
#  	    } else {
#  		my $destdir = $kdedirs{-doc} . "/de";
#  		if (!-d $destdir) {
#  		    mkdir $destdir, 0755;
#  		}
#  		if (-d $destdir && -w $destdir) {
#  		    _safe_symlink("$FindBin::Bin/$html_documentation",
#  				  "$destdir/$html_documentation");
#  		    if (-l "$destdir/$html_documentation") {
#  			$has_docpath = 1;
#  		    }
#  		}
#  	    }
#  	}

	$bbbike_gnomelnk     = "$applications_dir/BBBike.desktop";
	if ($show) {
	    Print "BBBike.kdelnk.tmpl nach $applications_dir mit\n" .
	      "  Variablensubstitution kopieren.\n";
	} else {
	    if (open(KDELNK, "$FindBin::Bin/kde/BBBike.kdelnk.tmpl") &&
		open(SAVE,   ">$bbbike_gnomelnk")) {
		while(<KDELNK>) {
		    if (/^\[KDE Desktop Entry\]/) {
			print SAVE "[Desktop Entry]\n";
		    } elsif (/\# KDE Config File/) {
			# NOP
		    } elsif (/^Exec=/i) {
			if ($use_client_server_mode) {
			    print SAVE "Exec=$^X $client_bin\n";
			} else {
			    print SAVE "Exec=$^X $main_bin\n";
			}
		    } elsif (/^Icon=/i) {
			my $base = basename($unix_icon);
			print SAVE "Icon=$gnomedir/pixmaps/$base\n";
		    } elsif (/^MiniIcon=/i) {
			my $base = basename($unix_mini_icon);
			print SAVE "MiniIcon=$gnomedir/pixmaps/$base\n";
		    } elsif (/^DocPath=/i) {
#			if ($has_docpath) {
#			    print SAVE "DocPath=$html_documentation\n";
#			}
		    } else {
			print SAVE $_;
		    }
		}
		close SAVE;
		close KDELNK;
	    }
	}

	$bbbike_doc_gnomelnk = "$applications_dir/BBBikeDoc.desktop";
	if ($show) {
	    Print "BBBikeDoc.kdelnk.tmpl nach $applications_dir mit\n" .
	      "  Variablensubstitution kopieren.\n";
	} else {
	    if (open(KDELNK, "$FindBin::Bin/kde/BBBikeDoc.kdelnk.tmpl") &&
		open(SAVE,   ">$bbbike_doc_gnomelnk")) {
		while(<KDELNK>) {
		    if (/^\[KDE Desktop Entry\]/) {
			print SAVE "[Desktop Entry]\n";
		    } elsif (/\# KDE Config File/) {
			# NOP
		    } elsif (/^URL=/i) {
			print SAVE "URL=file:$FindBin::Bin/$html_documentation\n";
		    } else {
			print SAVE $_;
		    }
		}
		close SAVE;
		close KDELNK;
	    }
	}

	$bbbike_www_gnomelnk = "$applications_dir/BBBikeWWW.desktop";
	if ($show) {
	    Print "BBBikeWWW.kdelnk nach $applications_dir kopieren.\n";
	} else {
	    copy("$FindBin::Bin/kde/BBBikeWWW.kdelnk",
		 $bbbike_www_gnomelnk);
	    chmod 0644, $bbbike_www_gnomelnk;
	}

#      if (exists $kdedirs{-mimelnk}) {
#  	Print
#  	  "Installation der MIME-Verknüpfung für BBBike-Routen...\n";
#  	my $application_dir = "$kdedirs{-mimelnk}/application";
#  	if (!-d $application_dir) {
#  	    if ($show) {
#  		Print "mkdir $application_dir, 0755\n";
#  	    } else {
#  		mkdir $application_dir, 0755;
#  	    }
#  	}

#  	foreach my $mimefile (qw(x-bbbike-route x-bbbike-data x-gpstrack)) {
#  	    my $dest = "$kdedirs{-mimelnk}/application/$mimefile.kdelnk";
#  	    if ($show) {
#  		Print "copy to $dest and chmod 0644\n";
#  	    } else {
#  		copy("$FindBin::Bin/kde/$mimefile.kdelnk", $dest);
#  		chmod 0644, $dest;
#  	    }
#  	}

#  	my $magic = "$kdedirs{-mimelnk}/magic";
#  	my @old_magic;
#  	my %has_magic;
#  	if (open(MAGIC, $magic)) {
#  	    while(<MAGIC>) {
#  		if (/application\/x-bbbike-route/) {
#  		    $has_magic{'route'} = 1;
#  		} elsif (/application\/x-gpstrack/) {
#  		    $has_magic{'gpstrack'} = 1;
#  		}
#  		push @old_magic, $_;
#  	    }
#  	    close MAGIC;
#  	    if (!($has_magic{'route'} and
#  		  $has_magic{'gpstrack'})) {
#  		if ($show) {
#  		    Print "write BBBike route magic to $magic\n";
#  		} else {
#  		    if (open(MAGIC, ">$magic")) {
#  			print MAGIC join("", @old_magic);
#  			print MAGIC "# BBBike\n";
#  			if (!$has_magic{'route'}) {
#  			    print MAGIC "0\t\tstring\t\\#BBBike\\ route\tapplication/x-bbbike-route\n";
#  			}
#  			if (!$has_magic{'gpstrack'}) {
#  			    print MAGIC "0\t\tstring\tTRK\\ \t\tapplication/x-gpstrack\n";
#  			}
#  			print MAGIC "#\n";
#  			close MAGIC;
#  		    }
#  		}
#  	    }
#  	}
#      }


    Print "Installation der BBBike-Icons für GNOME ...\n";
    if (!-d "$gnomedir/pixmaps") {
	if ($show) {
	    Print "create pixmaps directory\n";
	} else {
	    mkdir "$gnomedir/pixmaps", 0755;
	}
    }
    foreach my $img ($unix_icon,
		     $unix_mini_icon,
		     qw(srtbike_www.xpm)) {
	my $dest = "$gnomedir/pixmaps/$img";
	if ($show) {
	    Print "copy to $dest and chmod 0644\n";
	} else {
	    copy("$FindBin::Bin/images/$img",$dest);
	    chmod 0644, $dest;
	}
    }

#      if (exists $kdedirs{-bin}) {
#  	foreach my $f ($main_bin, $client_bin) {
#  	    my $thisf = $FindBin::Bin . "/" . basename($f);
#  	    if ($thisf ne $f) {
#  		Print "Symbolischen Link von $f nach\n" .
#  		  "  $thisf erzeugen ...\n";
#  		if (!$show) {
#  		    _safe_symlink($thisf, $f, 1);
#  		}
#  	    }
#  	}
#      }

    if ($desktop_icon) {
	my $homedir = _get_homedir();
	if (defined $homedir) {
	    my $desktop = "$homedir/.gnome-desktop";
	    if (-d $desktop && -w $desktop) {
		my $gnomelnk = "$desktop/BBBike";
		if (defined $bbbike_gnomelnk && -e $bbbike_gnomelnk) {
		    if ($show) {
			Print "Symlink $gnomelnk => $bbbike_gnomelnk\n";
		    } else {
			_safe_symlink($bbbike_gnomelnk, $gnomelnk);
		    }
		    my $base = basename($unix_icon);
		    $metadata{"file\0$desktop/BBBike\0icon-filename\0"} =
			"$gnomedir/pixmaps/$base";
		}

		$gnomelnk = "$desktop/BBBikeWWW";
		if (defined $bbbike_www_gnomelnk && -e $bbbike_www_gnomelnk) {
		    if ($show) {
			Print "Symlink $gnomelnk => $bbbike_www_gnomelnk\n";
		    } else {
			if (-e $gnomelnk) { unlink $gnomelnk }
			copy("$FindBin::Bin/kde/BBBikeWWW.kdelnk",
			     $gnomelnk);
			chmod 0644, $gnomelnk;
		    }
		    $metadata{"file\0$desktop/BBBikeWWW\0icon-filename\0"} =
			"$gnomedir/pixmaps//srtbike_www.xpm";
		}
	    }
	}
    }

  GNOMEEND:
    Print_unshift;
    Print "\n";
    $ret;
}

sub ModuleExtensions {
    my(%args) = @_;
    return unless @module_ext;
    my $currdir = $FindBin::Bin;

    Print Mfmt(
	"\n" .
	"Es wird jetzt versucht, einige Erweiterungen zu installieren,\n" .
	"die die Ausführungsgeschwindigkeit von %s verbessern, aber\n" .
	"nicht unbedingt notwendig sind. Deshalb können Fehler hier\n" .
	 "ignoriert werden.\n\n", $program_title);
    Print_shift;

    foreach my $ext (@module_ext) {
        chdir $currdir;
	Print
	    "Perl-Erweiterung $ext für $program_title installieren ...\n";
	Print_shift;
        eval {
            die "Kann zum Verzeichnis ext/$ext nicht wechseln: $!\n" if !chdir "ext/$ext";
	    if (-f "Makefile" || -f "$ext.c") {
		# vorsichtshalber, falls bereits mit einer anderen
		# Perl-Version compiliert wurde.
		if ($show) {
		    Print "make clean aufrufen\n";
		} else {
		    system($Config{'make'}, 'clean');
		}
	    }
	    if ($show) {
		Print "Makefile.PL erzeugen\n";
	    } else {
		system($^X, "Makefile.PL");
		die "Fehler beim Kommando \"$^X Makefile.PL\" in $ext\n" if $?;
	    }
	    if ($show) {
		Print "make aufrufen\n";
	    } else {
		system($Config{'make'});
		die "Fehler beim Erstellen der Erweiterung $ext.\n" if $?;
	    }
	    if ($show) {
		Print "make install aufrufen\n";
	    } else {
		system($Config{'make'}, "install");
		die "Fehler bei der Installation der Erweiterung $ext.\n"
		  if $?;
	    }
	    if ($args{'-clean'}) {
		if ($show) {
		    Print "make clean aufrufen\n";
		} else {
		    system($Config{'make'}, "clean");
		}
	    }
        };
        Print "$@\n" if $@;
	Print_unshift;
	Print "\n";
    }
    Print_unshift;

    chdir $currdir;
}

sub _get_homedir {
    my $homedir;
    eval {
	local $SIG{__DIE__};
	if ($^O ne 'MSWin32') {
	    $homedir = (getpwuid($<))[7];
	}
    };
    if (!defined $homedir && defined $ENV{HOME}) {
	$homedir = $ENV{HOME};
    }
    $homedir;
}

sub _safe_symlink {
    my($from, $to, $backup) = @_;
    if (-e $to) {
	if ($backup) {
	    my $old = "$to.old";
	    if (-e $old) {
		unlink $old;
	    }
	    move($to, $old);
	} else {
	    unlink $to;
	}
    }
    symlink $from, $to;
}

sub Print (@) {
    if ($use_tk) {
	$txt->insert('end', " " x $Print_indent);
	$txt->insert('end', @_);
	$txt->see('end');
	$txt->update;
    } else {
	print STDERR " " x $Print_indent;
	print STDERR map { output($_) } @_;
    }
}

sub Print_shift   () { $Print_indent+=2 }
sub Print_unshift () { $Print_indent-=2 }

sub my_die {
    my $msg = shift;
    if ($top) {
	$top->Tk::Error($msg);
	die $msg;
    } else {
	die $msg;
    }
}

sub load_Makefile_PL {
    my $file = "$FindBin::Bin/Makefile.PL";
    return unless -r $file;

    $INC{"ExtUtils/MakeMaker.pm"} = "__cheat__";
    package ExtUtils::MakeMaker;
    use vars qw($Makefile_PL @EXPORT @ISA);
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT = qw(WriteMakefile);

    sub WriteMakefile {
	$Makefile_PL = { @_ };
    }

    package main;

    my $origcwd = cwd();
    chdir $FindBin::Bin || warn "Can't chdir to $FindBin::Bin: $!";
    do $file;
    chdir $origcwd || warn "Can't change back to $origcwd: $!";

    my $h = $ExtUtils::MakeMaker::Makefile_PL->{INSTALLER};
    if ($h) {

	while(my($k,$v) = each %config_vars) {

	    if ($debug) {
		print STDERR "  from Makefile.PL: $k => $v\n";
	    }
	    next if eval 'defined ' . $v;
	    next unless exists $h->{$k};

	    my $derefer = substr($v, 0, 1);
	    $derefer = '' if $derefer eq "\$";

	    my $cmd = $v . ' = ' . $derefer . ($derefer?'{':'') .
 	                                          '$h->{$k}'    .
					      ($derefer?'}':'');
	    #warn "$cmd\n";
	    eval $cmd;
	    warn $@ if $@;

	}
    }

    # Sonderfälle
    $h = $ExtUtils::MakeMaker::Makefile_PL;
    if (!defined $program_title && exists $h->{NAME}) {
	$program_title = $h->{NAME};
    }
    if (!defined $main_program && exists $h->{EXE_FILES}) {
	$main_program = $h->{EXE_FILES}[0];
    }
    if (!defined $main_description && exists $h->{ABSTRACT}) {
	$main_description = $h->{ABSTRACT};
    }

}

# Perform a "perl Makefile.PL" installation
# Options:
#   -type => best | public | private
sub perl_install {
    my(%args) = @_;
    my $type = $args{-type} || 'best';

    if ($type eq 'best' && $^O ne 'MSWin32' && $> == 0) {
	# I'm root
	$type = 'public';
    }
    if ($type eq 'best') {
	$type = 'private';
    }

    my @perl_makefile_pl_args = ($^X, "Makefile.PL");
    if ($type eq 'private') {
	push @perl_makefile_pl_args, "PREFIX=$ENV{HOME}";
    }

    # XXX make => $MAKE (nmake, gmake ...)
    if ($show) {
	Print join(" ", @perl_makefile_pl_args), "\n";
	Print "make\nmake install\n";
    } else {
	my $origdir = cwd();
	eval {
	    chdir $FindBin::Bin || die "Can't chdir to $FindBin::Bin: $!";
	    system @perl_makefile_pl_args;
	    die "Can't perl Makefile.PL" if $? != 0;
	    system "make";
	    die "Can't make" if $? != 0;
	    system "make", "install";
	    die "Can't make install" if $? != 0;
	};
	die $@ if $@;
	chdir $origdir;
    }
}

sub Uninstall {
    # this is always in Tk mode
    require Tk;

    # get packlist

    # display packlist and ask for confirmation

    # delete files

    # on Win32: delete registry information
}

# REPO BEGIN
# REPO NAME cp850_iso /home/e/eserte/src/repository 
# REPO MD5 e06507bb1ba9a68e3e63a43d06f0a4ae

=head2 cp850_iso($s)

=for category Conv

Translate string from cp850 encoding to iso-8859-1 encoding. Only
german umlauts are handled.

=cut

sub cp850_iso {
    my $s = shift;
    $s =~ tr/\204\224\201\216\231\232\341\202\370/äöüÄÖÜßé°/;
    $s;
}
# REPO END

# REPO BEGIN
# REPO NAME iso_cp850 /home/e/eserte/src/repository 
# REPO MD5 bbd84cf3c05ae7c539d3b37d5a66286d

=head2 iso_cp850($s)

=for category Conv

Translate string from iso-8859-1 encoding to cp850 encoding. Only
german umlauts are handled.

=cut

sub iso_cp850 {
    my $s = shift;
    $s =~ tr/äöüÄÖÜßé°/\204\224\201\216\231\232\341\202\370/;
    $s;
}
# REPO END

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 1aa226739da7a8178372aa9520d85589

=head2 is_in_path($prog)

=for category File

Return the pathname of $prog, if the program is in the PATH, or undef
otherwise.

DEPENDENCY: file_name_is_absolute

=cut

sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	return "$_/$prog" if -x "$_/$prog";
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

# REPO BEGIN
# REPO NAME tk_sleep /home/e/eserte/src/repository 
# REPO MD5 8ede6fb7c5021ac927456dff1f24aa7a

=head2 tk_sleep

=for category Tk

    $top->tk_sleep($s);

Sleep $s seconds (fractions are allowed). Use this method in Tk
programs rather than the blocking sleep function.

=cut

sub Tk::Widget::tk_sleep {
    my($top, $s) = @_;
    my $sleep_dummy = 0;
    $top->after($s*1000,
                sub { $sleep_dummy++ });
    $top->waitVariable(\$sleep_dummy)
	unless $sleep_dummy;
}
# REPO END

__END__
