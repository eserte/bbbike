# -*- perl -*-

#
# $Id: Update.pm,v 1.27 2009/02/18 23:54:22 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998,2001,2003,2005,2006,2007 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Update;

use strict;
use vars qw($verbose $tmpdir $proxy $VERSION);

use File::Basename;
use BBBikeVar;
use FindBin;

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 89d0fdf16d11771f0f6e82c7d0ebf3a8

BEGIN {
    if (eval { require File::Spec; defined &File::Spec::file_name_is_absolute }) {
	*file_name_is_absolute = \&File::Spec::file_name_is_absolute;
    } else {
	*file_name_is_absolute = sub {
	    my $file = shift;
	    my $r;
	    if ($^O eq 'MSWin32') {
		$r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	    } else {
		$r = ($file =~ m|^/|);
	    }
	    $r;
	};
    }
}
# REPO END

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 1b42243230d92021e6c361e37c9771d1

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

sub update_http {
    my(%args) = @_;
    my $root = delete $args{-root} || die "No root";
    my(@files) = @{$args{-files}};
    my $dest = delete $args{-dest} || die "No destination";
    my(%modified) = %{$args{-modified}};
    my $ua;
    eval {
## Be conservative: sieperl comes only with an ancient libwww (5.51 or so)
# 	require LWP;
# 	LWP->VERSION(5.802); # decoded_content
	require LWP::UserAgent;
	$main::public_test = $main::public_test; # peacify -w
	if ($main::public_test) {
	    warn "Force using Http.pm for -public\n";
	    die;
	}
	$ua = new LWP::UserAgent;
	$ua->agent("$main::progname/$main::VERSION (LWP::UserAgent/$LWP::VERSION) ($^O)");
## sieperl does not have compress::zlib, also decoded_content is not available
# 	if (eval { require Compress::Zlib; 1 }) {
# 	    $ua->default_headers->push_header('Accept-Encoding' => 'gzip');
# 	}
	$main::progname = $main::progname if 0; # peacify -w
	if ($main::proxy) {
	    $ua->proxy(['http', 'ftp'], $main::proxy);
	}
    };
    if ($@ || !$ua) {
	undef $ua;
	require Http;
	Http->VERSION(3.15); # correct handling of Host: ...
	$Http::user_agent = $Http::user_agent if 0; # peacify -w
	$Http::user_agent = "$main::progname/$main::VERSION (Http/$Http::VERSION) ($^O)";
    }
    $main::c = $main::c; # peacify -w
    $main::progress->Init(-dependents => $main::c,
			  -label => "Aktualisierung via Internet");
    my @errors;
    my $i = 0;
    foreach my $file (@files) {
	my $src_file  = $root . "/" . $file;
	$main::progress->Update($i++/$#files, # / help emacs
				-label => "Aktualisiere " . basename($src_file));
	my $dest_file = $dest . "/" . $file . "~";
	my $real_dest_file = $dest . "/" . $file;
	my $h;
	if ($ua) {
	    $h = new HTTP::Headers;
	    if (exists $modified{$file} && -f $real_dest_file) {
		$h->if_modified_since($modified{$file});
	    }
	} else {
	    if (exists $modified{$file} && -f $real_dest_file) {
		$h = {'time' => $modified{$file}};
	    } else {
		$h = {};
	    }
	}
	if ($main::verbose) {
	    print STDERR "$src_file => $dest_file...";
	}
	my($res, $success, $modified);
	my $code;
	if ($ua) {
	    $res = $ua->request(new HTTP::Request('GET', $src_file, $h),
				$dest_file);
	    $code = $res->code;
	    $success = $res->is_success;
	    if ($code == 200) {
		$modified = 1;
	    }
	} else {
	    my(%res) = Http::get('url' => $src_file,
				 %$h,
				);
	    $code = $res{'error'};
	    $success = ($code <  400); # OK or Not-modified
	    $modified = ($code == 200); # OK
	    if ($modified) { # OK
		eval {
		    open(OUT, ">$dest_file~") or die $!;
		    print OUT $res{'content'} or die $!;
		    close OUT or die $!;
		};
		if ($@) {
		    print STDERR "Can't write to $dest_file: $@\n";
		    $success = 0;
		} else {
		    rename "$dest_file~", $dest_file
			or do {
			    warn "Can't rename to $dest_file: $!";
			    $success = 0;
			};
		}
	    }
	}
	my $fatal = $code >= 500;
	if ($modified) {
	    my $tmp = $dest_file . "~~";
	    rename $real_dest_file, $tmp;
	    rename $dest_file, $real_dest_file;
	    unlink $tmp;
	    if ($main::verbose) {
		print STDERR " aktualisiert\n";
	    }
	} else {
	    if ($ua) {
		if ($res->is_error) {
		    print STDERR "\n", $res->as_string;
		    my $text = $res->error_as_HTML;
		    eval {
			require HTML::FormatText;
			require HTML::TreeBuilder;
			my $tree = HTML::TreeBuilder->new->parse($text);
			$text = HTML::FormatText->new(leftmargin => 0, rightmargin => 50)->format($tree);
		    };
		    warn $@ if $@;
		    push @errors, "Fehler beim Übertragen der Datei $src_file:\n" . $text . "\n";
		} else {
		    print STDERR " keine Änderung\n" if $main::verbose;
		}
	    } else {
		if (!$success) {
		    push @errors, "Fehler beim Übertragen der Datei $src_file";
		}
	    }
	}
	last if $fatal;
	unlink $dest_file;
    }
    #main::finish_progress();
    $main::progress->Finish;
    if (@errors) {
	main::status_message(join("\n", @errors), "warn");
    }
}

sub update_rsync {
    my(%args) = @_;
    if (!is_in_path("rsync")) {
	die "rsync wird benötigt";
    }
    my $src  = $args{-src}  || die "-src nicht definiert";
    my $dest = $args{-dest} || die "-dest nicht definiert";
    my $datadir = "$dest/data";
    my @cmd = ("rsync", "-Pvzr", $src, $datadir);
    warn "@cmd";
    system(@cmd);
    if ($?) {
	die "Update mit rsync fehlgeschlagen";
    } else {
	1;
    }
}

sub create_modified_devel {
    my(%args) = @_;
    my $rsync_include = $args{-rsyncinclude};
    my $rootdir = "..";
    my $datadir = $ENV{BBBIKE_DATADIR} || $rootdir . "/data";
    if (!-f "$rootdir/bbbike" || !-d $datadir || !-f "$rootdir/MANIFEST") {
	die "Probably wrong rootdir: $rootdir from `pwd`";
    }

    require Digest::MD5;

    open(MOD, ">$datadir/.modified~") or die "Can't write to .modified~: $!";
    if ($rsync_include) {
	open(RSYNC, ">$datadir/.rsync_include") or die "Can't write to .rsync_include: $!";
    }
    open(MANI, "$rootdir/MANIFEST") or die "Can't open MANIFEST: $!";
    while(<MANI>) {
	if (m|^data/(.*)|) {
	    my $file = $1;
	    next if $file =~ m|^\.|;

	    my $ctx = Digest::MD5->new;
	    open(MD5, "$datadir/$file")
		or die "Can't open $datadir/$file: $!";
	    $ctx->addfile(\*MD5);
	    close MD5;

	    my(@stat) = stat("$datadir/$file");
	    print MOD join("\t", "data/$file", $stat[9], $ctx->hexdigest), "\n";
	    if ($rsync_include) {
		print RSYNC "$file\n";
	    }
	}
    }
    close MANI
	or die "While writing to .modified~: $!";
    close MOD;
    rename "$datadir/.modified~", "$datadir/.modified"
	or die "Can't rename $datadir/.modified~ to $datadir/.modified: $!";
    if ($rsync_include) {
	close RSYNC;
    }
}

sub create_modified {
    my(%args) = @_;
    my $destdir = $args{-dest};
    my $datadir = $destdir . "/data";
    my(@files) = @{$args{-files}};
    my(%modified) = %{$args{-modified}};
    my(%md5) = %{$args{-md5}};
    eval {
	open(MOD, ">$datadir/.modified~") or die $!;
	my @errors;
	foreach my $file (@files) {
	    my(@stat) = stat("$destdir/$file");
	    if (!@stat) {
		push @errors, "$destdir/$file: $!";
		next;
	    }
	    print MOD join("\t", $file, $stat[9], $md5{$file}), "\n"
		or die $!;
	}
	if (@errors) {
	    main::status_message(M("Die folgenden Dateien haben Fehler erzeugt:\n") . join("\n", @errors),
				 "die");
	}
	close MOD or die $!;
    };
    if ($@) {
	warn "Can't write to $datadir/.modified: $@";
    } else {
	rename "$datadir/.modified~", "$datadir/.modified"
	    or warn "Can't rename to $datadir/.modified: $!";
    }
}

sub bbbike_data_update {
    my(%args) = @_;
    my $protocol = $args{-protocol} || "best";

    my $rootdir = "$FindBin::RealBin";

    my $my_die = sub { warn $_[0]; main::status_message($_[0], 'die') };
    my $my_warn = sub { warn $_[0]; main::status_message($_[0], 'info') };

    # sichergehen, dass nicht die Originaldateien überschrieben werden...
    $my_die->("FATAL: das ist ein Original-BBBike-Verzeichnis, welches nicht überschrieben werden kann.")
	if (-e "$rootdir/data/.original" ||
	    -e "$rootdir/data/.archive");
    $my_die->("FATAL: suspicious rootdir: $rootdir")
	if ($rootdir =~ m|/home/e/eserte/src/bbbike|);
    $my_die->("FATAL: Ein Verzeichnis RCS in $rootdir/data gefunden. Update nicht möglich.")
	if (-e "$rootdir/data/RCS");
    $my_die->("FATAL: Ein Verzeichnis CVS in $rootdir/data gefunden. Update nicht möglich. Es wird empfohlen, statt CVS git zu verwenden. Siehe README.")
	if (-e "$rootdir/data/CVS");
    $my_die->("FATAL: Ein Verzeichnis .svn in $rootdir/data gefunden. Update nicht möglich. Subversion wird nicht unterstützt, bitte git verwenden. Siehe README.")
	if (-e "$rootdir/data/.svn"); # will probably never happen
    $my_die->("FATAL: Ein Verzeichnis .git in $rootdir gefunden. Bitte benutze 'git pull' in der Kommandozeile um die BBBike-Daten zu aktualisieren, oder entferne das Verzeichnis $rootdir/.git.")
	if (-e "$rootdir/.git"); # if somebody is using github, or local git

    if (!-w "$rootdir/data") {
	main::status_message("Auf das Datenverzeichnis <$rootdir/data> darf nicht geschrieben werden.\n" .
			     "Versuchen Sie die Update-Funktion als root oder System-Administrator.",
			     "error");
	return;
    }

 TRY_CVS: { # Never reached, see above. CVS is outdated anyway.
	if (-e "$rootdir/data/CVS") {
	    if (!is_in_path("cvs")) {
		last TRY_CVS;
	    }
	    require Cwd;
	    my $old_cwd = Cwd::cwd();
	    eval {
		chdir "$rootdir/data"
		    or main::status_message("Can't chdir to data dir: $!", "die");
		# XXX Do it in background!
		system "cvs", "update";
		if ($? != 0) {
		    main::status_message("cvs update fehlgeschlagen (code $?)", "warn");
		} else {
		    main::status_message("cvs update erfolgreich durchgelaufen", "info");
		}
	    };
	    chdir $old_cwd or $my_warn->($!);
	    main::reload_all();
	    return;
	}
    }

    $my_die->("FATAL: Makefile in datadir detected")
	if (-e "$rootdir/data/Makefile");

 TRY_RSYNC: {
	if ($protocol eq 'rsync') {
	    eval {
		$BBBike::BBBIKE_UPDATE_DATA_RSYNC = $BBBike::BBBIKE_UPDATE_DATA_RSYNC; # peacify -w
		update_rsync(-dest => $rootdir,
			     -src  => $BBBike::BBBIKE_UPDATE_DATA_RSYNC,
			    );
	    };
	    if ($@) {
		if ($protocol ne 'best') {
		    $my_die->($@);
		}
		last TRY_RSYNC;
	    }
	    main::reload_all();
	    return;
	}
    }

    # assume http (or "best")
    my(@files, %modified, %md5);
    my $modfile = "$rootdir/data/.modified";
    if (open(MOD, $modfile)) {
	while(<MOD>) {
	    chomp;
	    my($f, $t, $md5) = split(/\t/);
	    push @files, $f;
	    $modified{$f} = $t;
	    $md5{$f} = $t;
	}
	close MOD;
	update_http(-dest => $rootdir,
		    -root => $BBBike::BBBIKE_UPDATE_WWW,
		    -files => \@files,
		    -modified => \%modified,
		    -md5 => \%md5,
		   );
	create_modified(-dest => $rootdir,
			-files => \@files,
			-modified => \%modified,
			-md5 => \%md5,
		       );
	main::reload_all();
    } else {
	main::status_message("Das Update konnte wegen einer fehlenden Datei ($modfile) nicht durchgeführt werden.", "error");
    }
}

1;

__END__
