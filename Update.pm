# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1998,2001,2003,2005,2006,2007,2012,2013 Slaven Rezic. All rights reserved.
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
use BBBikeUtil qw(is_in_path);
use BBBikeVar;
use FindBin;

sub update_http {
    my(%args) = @_;
    my $root = delete $args{-root} || die "No root";
    my(@files) = @{$args{-files}};
    my $dest = delete $args{-dest} || die "No destination";
    my(%modified) = %{$args{-modified}};
    my $ua;
    eval {
	require LWP::UserAgent;
	$main::public_test = $main::public_test; # peacify -w
	$main::os = $main::os; # peacify -w
	if ($main::public_test) {
	    if ($main::os ne 'win') {
		warn "Force using Http.pm for -public on non-Windows systems\n";
		die;
	    }
	}
	require BBBikeHeavy;
	$ua = BBBikeHeavy::get_uncached_user_agent();
	die "Can't get default user agent" if !$ua;
	$ua->timeout(180);
    };
    if ($@ || !$ua) {
	undef $ua;
	require Http;
	Http->VERSION(3.15); # correct handling of Host: ...
	$Http::user_agent = $Http::user_agent if 0; # peacify -w
	$main::progname = $main::progname if 0; # peacify -w
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

sub create_modified_devel {
    my(%args) = @_;
    my $rootdir = "..";
    my $datadir = $ENV{BBBIKE_DATADIR} || $rootdir . "/data";
    if (!-f "$rootdir/bbbike" || !-d $datadir || !-f "$rootdir/MANIFEST") {
	die "Probably wrong rootdir: $rootdir from `pwd`";
    }

    require Digest::MD5;

    my %old_files;
    if (open my $fh, "$datadir/.modified") {
	while(<$fh>) {
	    chomp;
	    my($file, $timestamp, $md5) = split /\t/;
	    $old_files{$file} = {timestamp => $timestamp, md5 => $md5};
	}
    } else {
	warn "WARN: Cannot load $datadir/.modified: $!";
    }

    open my $ofh, ">", "$datadir/.modified~"
	or die "Can't write to .modified~: $!";

    open my $manifh, "$rootdir/MANIFEST"
	or die "Can't open MANIFEST: $!";
    while(<$manifh>) {
	if (m|^data/(.*)|) {
	    my $file = $1;
	    next if $file =~ m|^\.|;

	    my $md5 = do {
		my $ctx = Digest::MD5->new;
		open my $fh, "$datadir/$file"
		    or die "Can't open $datadir/$file: $!";
		$ctx->addfile($fh);
		$ctx->hexdigest;
	    };

	    my $relfilename = "data/$file";
	    my $use_mtime;
	    if ($old_files{$relfilename} && $md5 eq $old_files{$relfilename}->{md5}) {
		$use_mtime = $old_files{$relfilename}->{timestamp}; # don't change timestamp if possible
	    } else {
		my @stat = stat "$datadir/$file";
		$use_mtime = $stat[9];
	    }
	    print $ofh join("\t", $relfilename, $use_mtime, $md5), "\n";
	}
    }
    close $ofh
	or die "While writing to .modified~: $!";
    rename "$datadir/.modified~", "$datadir/.modified"
	or die "Can't rename $datadir/.modified~ to $datadir/.modified: $!";
}

sub create_modified {
    my(%args) = @_;
    my $destdir = $args{-dest};
    my $datadir = $destdir . "/data";
    my(@files) = @{$args{-files}};
    eval {
	open(MOD, ">$datadir/.modified~") or die $!;
	my @errors;
	foreach my $file (@files) {
	    my(@stat) = stat("$destdir/$file");
	    if (!@stat) {
		push @errors, "$destdir/$file: $!";
		next;
	    }
	    print MOD join("\t", $file, $stat[9], "?"), "\n"
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

    $my_die->("FATAL: Makefile in datadir detected")
	if (-e "$rootdir/data/Makefile");

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
		       );
	main::reload_all();
    } else {
	main::status_message("Das Update konnte wegen einer fehlenden Datei ($modfile) nicht durchgeführt werden.", "error");
    }
}

1;

__END__
