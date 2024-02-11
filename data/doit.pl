#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017,2018,2019,2021,2022,2023,2024 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");
use Doit;
use Doit::Log;
use Doit::Util qw(copy_stat);
use File::Basename qw(dirname basename);
use File::Compare ();
use File::Glob qw(bsd_glob);
use File::Spec ();
use File::Temp qw(tempfile);
use Getopt::Long;
use Cwd qw(realpath cwd);
use POSIX qw(strftime);
use Time::Local qw(timelocal);
use BBBikeUtil qw(s2ms);

my $perl = $^X;
my $valid_date = 'today';

my $bbbikedir        = realpath "$FindBin::RealBin/..";
my $miscsrcdir       = "$bbbikedir/miscsrc";
my $persistenttmpdir = "$bbbikedir/tmp";
my $datadir          = "$bbbikedir/data";
my $bbbikeauxdir     = do { my $dir = "$ENV{HOME}/src/bbbike-aux"; -d $dir && $dir };

my $mapfiles_root_dir = "../mapserver/brb"; # note: in original Makefile.mapfiles also relative
my $mapfiles_data_dir = "$mapfiles_root_dir/data";

chdir $datadir or die "Can't chdir to $datadir: $!";

my $convert_orig_file  = "$miscsrcdir/convert_orig_to_bbd";
my @convert_orig       = ($perl, $convert_orig_file);
my @grepstrassen       = ($perl, "$miscsrcdir/grepstrassen");
my @grepstrassen_valid = (@grepstrassen, '-valid', $valid_date, '-preserveglobaldirectives');
my @replacestrassen    = ($perl, "$miscsrcdir/replacestrassen");
my @check_neighbour    = ($perl, "$miscsrcdir/check_neighbour");
my @check_double       = ($perl, "$miscsrcdir/check_double");
my @check_connected    = ($perl, "$miscsrcdir/check_connected");
my @check_points       = ($perl, "$miscsrcdir/check_points");

my @orig_files = bsd_glob("*-orig");
my @fragezeichen_lowprio_bbd = defined $bbbikeauxdir ? "$bbbikeauxdir/bbd/fragezeichen_lowprio.bbd" : ();
#my @additional_sourceid_files = ('routing_helper-orig', @fragezeichen_lowprio_bbd); # XXX use once everything is migrated to doit.pl
my @additional_sourceid_files;
my @source_targets_sources;

sub _need_rebuild ($@) {
    my($dest, @srcs) = @_;
    return 1 if !-e $dest;
    for my $src (@srcs, __FILE__) {
	if (!-e $src) {
	    warning "$src does not exist";
	} else {
	    return 1 if -M $src < -M $dest;
	}
    }
    return 0;
}

sub _need_daily_rebuild ($) {
    my($dest) = @_;
    my @s = stat($dest);
    return 1 if !@s;
    my $beginning_of_day_epoch = do {
	my @l = localtime;
	timelocal 0,0,0,$l[3],$l[4],$l[5]+1900;
    };
    return $s[9] < $beginning_of_day_epoch;
}

sub _make_writable ($@) {
    my($d, @files) = @_;
    $d->chmod(0644, grep { -e } @files);
}

sub _make_readonly ($@) {
    my($d, @files) = @_;
    $d->chmod(0444, @files);
}

sub _empty_file_error ($) {
    my $f = shift;
    error "Generated file $f is empty" if !-s $f;
}

sub _commit_dest ($$) {
    my($d, $f) = @_;
    _make_writable($d, $f);
    $d->rename("$f~", $f);
    _make_readonly($d, $f);
}

sub _repeat_on_changing_sources {
    my($action, $srcs) = @_;

    my $max_retries = 10; # XXX could be an option?

    my $get_file_modification_times = sub {
        my %mtimes;
        for my $file (@$srcs) {
            my @stat = stat($file);
            $mtimes{$file} = $stat[9] if @stat;
        }
        return %mtimes;
    };

    for my $retry (1..$max_retries) {
        my %initial_mtimes = $get_file_modification_times->();
        eval { $action->() };
	my $err = $@;
        my %final_mtimes = $get_file_modification_times->();

        my @changed_files;
	for my $file (sort keys %final_mtimes) {
	    if ($initial_mtimes{$file} != $final_mtimes{$file}) {
                push @changed_files, $file;
            }
        }

        if (@changed_files) {
	    if ($retry < $max_retries) {
		warning "Files changed during action: @changed_files. Will retry action ($retry/$max_retries).";
	    } else {
		error "Files changed during action: @changed_files. Too many retries ($retry), won't repeat anymore.";
	    }
        } else {
	    if ($err) {
		error $err;
	    }
	    last;
	}
    }
}

{
    my %done;
    sub _set_make_variable {
	my($d, $varref, $makevar) = @_;
	last if $done{$makevar};
	require BBBikeBuildUtil;
	my $pmake = BBBikeBuildUtil::get_pmake(canV => 1);
	chomp(my $varline = $d->info_qx({quiet=>1}, $pmake, "-V$makevar"));
	@$varref = split /\s+/, $varline;
	$done{$makevar} = 1;
    }
    sub _set_variable_source_targets_sources {
	my($d) = @_;
	_set_make_variable($d, \@source_targets_sources, 'SOURCE_TARGETS_SOURCES');
    }
    sub _set_variable_additional_sourceid_files {
	my($d) = @_;
	_set_make_variable($d, \@additional_sourceid_files, 'ADDITIONAL_SOURCEID_FILES');
    }
}

# REPO BEGIN
# REPO NAME slurp /home/e/eserte/src/srezic-repository 
# REPO MD5 241415f78355f7708eabfdb66ffcf6a1
sub slurp ($) {
    my($file) = @_;
    my $fh;
    my $buf;
    open $fh, $file
	or die "Can't slurp file $file: $!";
    local $/ = undef;
    $buf = <$fh>;
    close $fh;
    $buf;
}
# REPO END

sub action_files_with_tendencies {
    my $d = shift;

    # qualitaet
    for my $suffix (qw(s l)) {
	my $dest = "$persistenttmpdir/qualitaet_$suffix";
	my $src = "qualitaet_$suffix-orig";
	if (_need_rebuild $dest, $src) {
	    $d->run(
		    [@convert_orig, qw(-keep-directive valid), $src],
		    '|',
		    [@grepstrassen_valid],
		    '>', "$dest~"
		   );
	    _empty_file_error "$dest~";
	    _commit_dest $d, $dest;
	}
    }

    # handicap
    for my $def (
		 ['s', 'inner', 'routing_helper-orig'],
		 ['l', 'outer', undef],
		) {
	my($suffix, $side_berlin, $routing_helper_orig) = @$def;
	my $dest = "$persistenttmpdir/handicap_$suffix";
	my $src = "handicap_$suffix-orig";
	if (_need_rebuild $dest, $src, 'berlin', "$persistenttmpdir/gesperrt-with-handicaps", ($routing_helper_orig ? $routing_helper_orig : ())) {
	    $d->run(
		    [@convert_orig, qw(-keep-directive valid), $src],
		    '|',
		    [@grepstrassen_valid],
		    '>', "$dest~"
		   );
	    _empty_file_error "$dest~";
	    $d->run(
		    [@grepstrassen, '-catrx', '1s?:q\d'], '<', "$persistenttmpdir/gesperrt-with-handicaps",
		    '|',
		    [@grepstrassen, "-$side_berlin", 'berlin'],
		    '|',
		    [@replacestrassen, '-noglobaldirectives',
		     '-catexpr', 's/.*:(q\d.*)/$1::igndisp;/', 
		     '-nameexpr', 's/(.*)/$1: gegen die Einbahnstraßenrichtung, ggfs. schieben/'],
		    '>>', "$dest~"
		   );
	    $d->run(
		    [@grepstrassen, '-catrx', '2s?:q\d'], '<', "$persistenttmpdir/gesperrt-with-handicaps",
		    '|',
		    [@grepstrassen, "-$side_berlin", 'berlin'],
		    '|',
		    [@replacestrassen, '-noglobaldirectives',
		     '-catexpr', 's/.*:(q\d.*)/$1::igndisp/',
		     '-nameexpr', 's/(.*)/$1: gesperrt, ggfs. schieben/'],
		    '>>', "$dest~"
		   );
	    if ($routing_helper_orig) {
		$d->run(
			[@grepstrassen, qw(-ignoreglobaldirectives -ignorelocaldirectives), '-catrx', '^q\d+[-+]?;?$', $routing_helper_orig],
			'|',
			[@replacestrassen, '-catexpr', 's/;/::igndisp;/'],
			'>>', "$dest~"
		       );
	    }
	    _commit_dest $d, $dest;
	}
    }
}

sub action_check_berlin_ortsteile {
    my $d = shift;
    my $check_file = '.check_berlin_ortsteile';
    my @srcs = qw(berlin_ortsteile berlin);
    if (_need_rebuild $check_file, @srcs) {
	my $output;
	$d->run(['cat', @srcs],
		'|', [$perl, "$miscsrcdir/merge_overlapping_streets.pl", '-'],
		'|', [$perl, "$miscsrcdir/combine_streets.pl", "-"],
		'|', [$perl, '-nle', 'print if /(.*)\t/ && $1 !~ /,/'],
		'>', \$output);
	if ($output ne '') {
	    error "Unexpected output in check_berlin_ortsteile:\n$output\nPlease check borders! Especially check for unchanged coordinates with :B_ON:/:B_OFF: prefix in plz-orig!";
	}
	$d->touch($check_file);
    }
}

sub action_check_gesperrt_double {
    my $d = shift;
    my $check_file = '.check_gesperrt_double';
    my @srcs = qw(gesperrt);
    if (_need_rebuild $check_file, @srcs) {
	my($tmpfh, $tmpfile) = tempfile("bbbike_doit_XXXXXXXX", UNLINK => 1, TMPDIR => 1);
	$d->run([@grepstrassen, '--catrx', '^(1|2)', 'gesperrt'], '>', $tmpfile);
	$d->run([@check_double, '-linesegs', $tmpfile]);
	$d->touch($check_file);
    }
}

sub action_handicap_directed {
    my $d = shift;
    my $dest = 'handicap_directed';
    my @srcs = 'handicap_directed-orig';
    if (_need_rebuild $dest, @srcs) {
	$d->run([@convert_orig, qw(-keep-directive valid), @srcs], '|',
		[@grepstrassen_valid],
		'>', "$dest~");
	_commit_dest $d, $dest;
    }
}

sub action_check_handicap_directed {
    my $d = shift;
    my $dest = '.check_handicap_directed';
    my @against = qw( strassen landstrassen landstrassen2);
    my @srcs = ('handicap_directed', @against);
    if (_need_rebuild $dest, @srcs) {
	$d->system(
		   @check_neighbour,
		   qw(-type standard -data handicap_directed),
		   (map { ('-against', $_) } @against),
		  );
	$d->touch($dest);
    }
}

sub action_check_connected {
    my $d = shift;
    for my $file (qw(ubahn sbahn rbahn)) {
	my $dest = ".check_" . $file . "_connected";
	my $src = "$file-orig"; # check against the -orig file, because this one has possible "ignore_disconnected" directives still in the file; in the final file these are stripped
	if (_need_rebuild $dest, $src) {
	    $d->system(@check_connected, $src);
	    $d->touch($dest);
	}
    }
}

sub action_survey_today {
    my $d = shift;
    my $dest = "$persistenttmpdir/survey_today.bbd";
    my @srcs = (@orig_files, "$persistenttmpdir/bbbike-temp-blockings.bbd");
    if (_need_rebuild $dest, @srcs) {
	my $today = strftime("%Y-%m-%d", localtime);
	$d->run([@grepstrassen, '-directive', "last_checked~$today", @srcs],
		'|',
		[$perl, '-pe', 's/\t(\S+)/\tX/'],
		'>', "$dest~",
	       );
	_commit_dest $d, $dest;
    }
}

sub action_fragezeichen_nextcheck_bbd {
    my $d = shift;
    $d->add_component('file');
    my $dest = "$persistenttmpdir/fragezeichen-nextcheck.bbd";
    my @srcs = (qw(ampeln-orig
		   fragezeichen-orig
		   gesperrt-orig
		   qualitaet_s-orig
		   qualitaet_l-orig
		   handicap_s-orig
		   handicap_l-orig
		 ),
		"$persistenttmpdir/bbbike-temp-blockings-optimized.bbd");
    my @add_deps = ("$persistenttmpdir/XXX-indoor.bbd", "$persistenttmpdir/XXX-outdoor.bbd");
    my @all_srcs = (@srcs, @add_deps);
    if (_need_daily_rebuild $dest || _need_rebuild $dest, @all_srcs) {
	_repeat_on_changing_sources(sub {
	    my $processor = sub {
		my($ofh, $src, $with_next_last_check, $with_nonextcheck) = @_;
		my $relsrc = File::Spec->abs2rel($src);
		$ofh->print(<<"EOF");
############################################################
# source: $relsrc
EOF
		if (!$with_next_last_check) {
		    $ofh->print(<<'EOF');
# (without next_check/last_checked)
EOF
	    }
		if ($with_next_last_check) {
		    $d->run([@grepstrassen, '-directive', 'last_checked~.', '-special', 'nextcheck', $src], '>', '/dev/null');
		    $ofh->print(slurp('/tmp/nextcheck.bbd'));
		    $d->run([@grepstrassen, '-directive', 'next_check~.', '-special', 'nextcheck', $src], '>', '/dev/null');
		    $ofh->print(slurp('/tmp/nextcheck.bbd'));
		}
		if ($with_nonextcheck) {
		    $ofh->print($d->info_qx(@grepstrassen, '-special', 'nonextcheck', $src));
		}
	    };
	    $d->file_atomic_write
		($dest, sub {
		     my $ofh = shift;
		     $ofh->print(<<'EOF');
#: line_dash: 8, 5
#: line_width: 5
#:
EOF
		     for my $src (@srcs) {
			 $processor->($ofh, $src, 1, 0);
		     }
		     $processor->($ofh, "fragezeichen-orig", 0, 1);
		     for my $srcfrag (qw(indoor outdoor)) {
			 $processor->($ofh, "$persistenttmpdir/XXX-$srcfrag.bbd", 1, 1);
		     }
		 }
		);
	}, \@all_srcs);
    }
}

sub action_fragezeichen_nextcheck_org {
    my $d = shift;
    my $dest = "$persistenttmpdir/fragezeichen-nextcheck.org";
    my @srcs = (@orig_files, "$persistenttmpdir/bbbike-temp-blockings-optimized.bbd");
    if (_need_daily_rebuild $dest || _need_rebuild $dest, @srcs) {
	_repeat_on_changing_sources(sub {
	    _make_writable $d, $dest;
	    $d->run([$perl, "$miscsrcdir/fragezeichen2org.pl", @srcs], '>', "$dest~");
	    _empty_file_error "$dest~";
	    _commit_dest $d, $dest;
	}, \@srcs);
    }
}

sub _build_fragezeichen_nextcheck_variant {
    my($d, $dest) = @_;
    my $variant = ($dest =~ m{fragezeichen-nextcheck.org$} ? 'exact-dist' :
		   $dest =~ m{(home-home|without-osm-watch)} ? $1 : die "Cannot recognize variant from destination file '$dest'");
    my $self_target = ($variant eq 'exact-dist' ? 'fragezeichen-nextcheck.org-exact-dist' :
		       basename($dest));
    my $expired_statistics_logfile_base = ($variant eq 'exact-dist' ? 'expired-fragezeichen.log' : "expired-fragezeichen-${variant}.log");
    my @srcs = (@orig_files, "$persistenttmpdir/bbbike-temp-blockings-optimized.bbd");
    my $gps_uploads_dir = "$ENV{HOME}/.bbbike/gps_uploads";
    my @gps_uploads_files = bsd_glob("$gps_uploads_dir/*.bbr");
    my @all_srcs = (@srcs, @gps_uploads_files, $gps_uploads_dir);
    # note: the exact-dist variant is always rebuilt, as there are two actions creating the same target (XXX should be fixed!)
    if ($variant eq 'exact-dist' || _need_daily_rebuild $dest || _need_rebuild $dest, @all_srcs) {
	my $centerc;
	if ($variant eq 'home-home') {
	    require Safe;
	    my $config = Safe->new->rdo("$ENV{HOME}/.bbbike/config");
	    $centerc = $config->{centerc};
	}
	_repeat_on_changing_sources(sub {
	    _make_writable $d, $dest;
	    $d->run([$perl, "$miscsrcdir/fragezeichen2org.pl",
		 "--expired-statistics-logfile=$persistenttmpdir/$expired_statistics_logfile_base",
		 (@gps_uploads_files ? "--plan-dir=$gps_uploads_dir" : ()),
		 "--with-searches-weight",
		 "--max-dist=50",
		 "--dist-dbfile=$persistenttmpdir/dist.db",
		 ($variant eq 'home-home' ? ($centerc ? ("-centerc", $centerc, "-center2c", $centerc) : ()) : ()),
		 ($variant eq 'without-osm-watch' ? ('--filter', 'without-osm-watch') : ()),
		 "--compile-command", "cd @{[ cwd ]} && $^X " . __FILE__ . " " . $self_target,
		 @srcs], ">", "$dest~");
	    _empty_file_error "$dest~";
	    _commit_dest $d, $dest;
	}, \@all_srcs);
    }
}

sub action_fragezeichen_nextcheck_org_exact_dist {
    my $d = shift;
    my $dest = "$persistenttmpdir/fragezeichen-nextcheck.org";
    _build_fragezeichen_nextcheck_variant($d, $dest);
}

sub action_fragezeichen_nextcheck_home_home_org {
    my $d = shift;
    my $dest = "$persistenttmpdir/fragezeichen-nextcheck-home-home.org";
    _build_fragezeichen_nextcheck_variant($d, $dest);
}

sub action_fragezeichen_nextcheck_without_osm_watch_org {
    my $d = shift;
    my $dest = "$persistenttmpdir/fragezeichen-nextcheck-without-osm-watch.org";
    _build_fragezeichen_nextcheck_variant($d, $dest);
}

sub action_sourceid {
    my $d = shift;
    _set_variable_source_targets_sources($d);
    _set_variable_additional_sourceid_files($d);

    for my $variant_def (
        ["sourceid-all.yml",     "bbbike-temp-blockings.bbd"],
        ["sourceid-current.yml", "bbbike-temp-blockings-optimized.bbd"],
    ) {
	my($dest_base, $temp_blockings_base) = @$variant_def;
	my $dest = "$persistenttmpdir/$dest_base";
	my @srcs = ("$persistenttmpdir/$temp_blockings_base", @source_targets_sources, @additional_sourceid_files);
	if (_need_rebuild $dest, @srcs) {
	    _repeat_on_changing_sources(sub {
	        $d->run([$perl, "$miscsrcdir/bbd_to_sourceid_exists", @srcs], '>', "$dest~");
		_empty_file_error "$dest~";
		_commit_dest $d, $dest;
	    }, \@srcs);
	}
    }
}

sub _build_bahnhof_bg {
    my($d, $dest) = @_;
    (my $src = $dest) =~ s/_bg$/-orig/;
    if (_need_rebuild $dest, $src) {
	require Strassen::Core;
	# get U/S out of u/sbahnhof
	my $upperletter = uc((basename($src) =~ /^(.)/)[0]);
	open my $ofh, '>', "$dest~" or error "Can't write to $dest~: $!";
	print $ofh "#: title: Fahrradfreundliche Zugänge bei der ${upperletter}-Bahn\n";
	if ($upperletter eq 'S') {
	    print $ofh "#: note: http://www.s-bahn-berlin.de/fahrplanundnetz/sbahnhof_anzeige.php?ID=103\n";
	}
	print $ofh "#:\n";
	my $s = Strassen->new_stream($src, UseLocalDirectives => 1);
	my $new_s = Strassen->new;
	$s->read_stream(sub {
	    my($r, $dir) = @_;
	    if (my $attrs = $dir->{attributes}) {
		my $attr = $attrs->[0];
		if ($attr =~ s/\s+\((.*)\)//) {
	            $r->[Strassen::NAME()] .= ": $1";
		}
	        $r->[Strassen::CAT()] = $attr;
	        $new_s->push($r);
	    }
	});
	if (!$new_s->count) {
	    error "Unexpected: no bg records found in $src";
	}
	print $ofh $new_s->as_string;
	close $ofh or error $!;
	_empty_file_error "$dest~";
	_commit_dest $d, $dest;
    }
}
sub action_ubahnhof_bg {
    my($d) = @_;
    _build_bahnhof_bg($d, "ubahnhof_bg");
}
sub action_sbahnhof_bg {
    my($d) = @_;
    _build_bahnhof_bg($d, "sbahnhof_bg");
}

sub action_check_exits {
    my($d, @argv) = @_;
    my $check_file = '.check_exits';
    my @srcs = @argv;
    if (_need_rebuild $check_file, 'exits', @srcs) {
	require Strassen::Core;
	my $s = Strassen->new_stream(q{exits});
	my $new_s = Strassen->new;
	$s->read_stream(sub {
	    my $r = shift;
	    $r->[Strassen::COORDS()] = [@{$r->[Strassen::COORDS()]}[0, -1]];
	    $new_s->push($r);
	});
	my(undef, $exits_first_last_file) = tempfile("exits-first-last_XXXXXXXX", TMPDIR => 1, UNLINK => 1);
	$new_s->write($exits_first_last_file);
	$d->run([@check_points, $exits_first_last_file, @srcs]);
	$d->touch($check_file);
    }
}

# run unconditionally
sub action_check_do_check_nearest {
    my($d) = @_;
    require Strassen::Core;
    my $s = Strassen->new("$persistenttmpdir/check_nearest.bbd");
    $s->init;
    my $r = $s->next;
    my($dist) = $r->[Strassen::NAME()] =~ /^\S+\s+(\d+)m/;
    if (!defined $dist) { error "Cannot parse " . $r->[Strassen::NAME()] }
    if ($dist < 20) {
	warning Strassen::arr2line2($r);
	error "Distance $dist m found. Please check and add to @{[ cwd() ]}/check_nearest_ignore, if necessary";
    }
}

######################################################################

sub action_old_bbbike_data {
    my $d = shift;

    require Digest::MD5;
    require Tie::IxHash;

    $d->add_component('file');

    my $old_bbbike_data_dir = "$persistenttmpdir/old-bbbike-data";
    $d->mkdir($old_bbbike_data_dir);

    my @files;
    my %file2mtime;
    my %file2md5;
    {
	open my $fh, '<', '.modified'
	    or error "Can't open .modified: $!";
	while(<$fh>) {
	    chomp;
	    if (my($file, $mtime, $md5) = $_ =~ m{^data/(\S+)\s+(\S+)\s+(\S+)}) {
		push @files, $file;
		$file2mtime{$file} = $mtime;
		$file2md5{$file} = $md5;
	    }
	}
    }

    my $bbbike_ver_less_than = sub ($$) {
	return 0 if $_[0] eq 'future';
	return $_[0] < $_[1];
    };
    my $bbbike_ver_ge_than = sub ($$) {
	return 1 if $_[0] eq 'future';
	return $_[0] >= $_[1];
    };
    my $get_md5 = sub ($) {
	my $destfile = shift;
	my $ctx = Digest::MD5->new;
	open my $fh, $destfile
	    or error "Can't open $destfile: $!";
	$ctx->addfile($fh);
	return $ctx->hexdigest;
    };

    tie my %rules, 'Tie::IxHash',
	(
	 'strassen-NH' =>
	 {
	  bbbikever => sub { $bbbike_ver_less_than->($_[0], 3.17) },
	  files     => qr{^(strassen|landstrassen|landstrassen2)$},
	  action    => sub {
	      my($src_file, $dest_file) = @_;
	      if (_need_rebuild $dest_file, $src_file, $0) {
		  open my $fh, '<', $src_file
		      or error "Can't open $src_file: $!";
		  my $changes = $d->file_atomic_write($dest_file,
						      sub {
							  my $ofh = shift;
							  while(<$fh>) {
							      s{\tNH }{\tN };
							      print $ofh $_;
							  }
						      }, check_change => 1);
		  if (!$changes) {
		      $d->touch($dest_file); # so it's not rebuilt every time
		  }
		  $changes;
	      } else {
		  0;
	      }
	  },
	 },

	 'with-tendencies' =>
	 {
	  bbbikever => sub { $bbbike_ver_ge_than->($_[0], 3.19) },
	  files     => qr{^(handicap|qualitaet)_(s|l)$},
	  action    => sub {
	      my($src_file, $dest_file) = @_;
	      action_files_with_tendencies($d);
	      $src_file = "$persistenttmpdir/" . basename($src_file);
	      if (_need_rebuild $dest_file, $src_file, $0) {
		  _make_writable($d, $dest_file);
		  my $changes = $d->copy($src_file, $dest_file);
		  $d->touch($dest_file);
		  _make_readonly($d, $dest_file);
		  $changes;
	      } else {
		  0;
	      }
	  },
	 },
	);

    for my $bbbike_ver ('3.16', '3.17', '3.18', 'future') {
	my $bbbike_ver_dir = "$old_bbbike_data_dir/$bbbike_ver";
	$d->mkdir($bbbike_ver_dir);
	my @new_modified;
	for my $file (@files) {
	    my $destfile;
	    if ($file =~ m{/}) {
		my $destdir = "$bbbike_ver_dir/" . dirname($file) . "/";
		$d->mkdir($destdir);
		$destfile = $destdir . basename($file);
	    } else {
		$destfile = "$bbbike_ver_dir/" . basename($file);
	    }

	    my $rule_applied;
	    my $changes = 0;
	    while(my($rulename, $rule) = each %rules) {
		if ($rule->{bbbikever}->($bbbike_ver) &&
		    $file =~ $rule->{files}) {
		    #info "apply rule $rulename";
		    $changes += $rule->{action}->($file, $destfile);
		    $rule_applied = 1;
		}
	    }
	    if (!$rule_applied) {
		if (File::Compare::compare($file, $destfile) != 0) {
		    if (!-w $destfile) {
			_make_writable($d, $destfile);
		    }
		    $changes += $d->copy($file, $destfile);
		    copy_stat $file, $destfile;
		}
	    }
	    # XXX efficiency: read old .modified and recalculate checksum only on changes
	    my $md5 = $get_md5->($destfile);
	    my $mtime = $file2md5{$file} eq $md5 ? $file2mtime{$file} : (stat($destfile))[9];
	    push @new_modified, "data/$file\t$mtime\t$md5";
	}

	if ($bbbike_ver_less_than->($bbbike_ver, 3.17)) {
	    my $destfile = "$bbbike_ver_dir/label";
	    $d->copy("label", $destfile);
	    my $label_mtime = 1099869060; # this is the mtime of label in BBBike-3.16/data/.modified
	    $d->utime(undef, $label_mtime, $destfile);
	    my $md5 = $get_md5->($destfile);
	    push @new_modified, "data/label\t$label_mtime\t$md5";
	}

	$d->file_atomic_write("$bbbike_ver_dir/.modified",
			      sub {
				  my $ofh = shift;
				  for (@new_modified) {
				      $ofh->print("$_\n");
				  }
			      }, check_change => 1);
    }
}

sub action_bbbgeojsonp_index_html {
    my $d = shift;
    $d->add_component('file');

    require Geography::Berlin_DE;
    my($lon,$lat) = split /,/, Geography::Berlin_DE->new->center_wgs84;

    my @bbbgeojsonp_targets = @ARGV;
    die "Unexpected: no targets?" if !@bbbgeojsonp_targets;
    $d->file_atomic_write
	("$persistenttmpdir/bbbgeojsonp/index.html", sub {
	     my $ofh = shift;
	     $ofh->print("<ul>\n");
	     for my $target (@bbbgeojsonp_targets) {
		 my $base = basename $target;
		 (my $label = $base) =~ s/\.bbbgeojsonp$//;
		 $ofh->print(<<"EOF");
 <li><a href="/cgi-bin/bbbikeleaflet.cgi?geojsonp_url=/BBBike/tmp/bbbgeojsonp/$base&zoom=12&lat=$lat&lon=$lon">$label</a>
EOF
	     }
	     $ofh->print("</ul>\n");
	     $ofh->print("Last update: " . strftime('%F %T', localtime) . "\n");
	 });
}

sub action_geojson_index_html {
    my $d = shift;
    $d->add_component('file');

    my @geojson_targets = @ARGV;
    die "Unexpected: no targets?" if !@geojson_targets;
    $d->file_atomic_write
	("$persistenttmpdir/geojson/index.html", sub {
	     my $ofh = shift;
	     $ofh->print("<ul>\n");
	     for my $target (@geojson_targets) {
		 my $base = basename $target;
		 (my $label = $base) =~ s/\.geojson$//;
		 $ofh->print(<<"EOF");
 <li><a href="$base">$label</a>
EOF
	     }
	     $ofh->print("</ul>\n");
	     $ofh->print("Last update: " . strftime('%F %T', localtime) . "\n");
	 });
}

######################################################################

# note: not run in action_all
sub action_last_checked_vs_next_check {
    require Strassen::Core;
    binmode STDERR, ":utf8"; # XXX "localize" change?
    my $fails = 0;
    for my $f (bsd_glob("*-orig"), "$persistenttmpdir/bbbike-temp-blockings.bbd") {
	print STDERR "$f... ";
	my $file_fails = 0;
	Strassen->new_stream($f)->read_stream
	    (sub {
		 my($r, $dir) = @_;
		 if ($dir->{last_checked} && $dir->{next_check} && $dir->{last_checked}[0] gt $dir->{next_check}[0]) {
		     print STDERR "\n  $r->[Strassen::NAME()] $dir->{last_checked}[0] $dir->{next_check}[0]";
		     $file_fails++;
		 }
	     });
	print STDERR ($file_fails ? "\n--> ERROR" : "OK"), "\n";
	$fails += $file_fails;
    }
    error "Failures seen\n" if $fails;
}

######################################################################
# Makefile.mapfiles
sub action_mapfiles_tmp_gesperrt30 {
    my($d) = @_;
    my $dest = "/tmp/gesperrt30";
    my $src = "gesperrt";
    if (_need_rebuild $dest, $src) {
	require Strassen::Core;
	require Strassen::Util;
	my $slen = 30;
	my $shorten = sub {
	    my(@p) = (split(/,/, $_[0]), split /,/, $_[1]);
	    my $len = Strassen::Util::strecke([@p[0,1]],[@p[2,3]]);
	    return () if $len <= $slen;
	    my $f = 1-($len-$slen)/$len;
	    return (
		join(",", map { int } ($p[0]+($p[2]-$p[0])*$f,
				       $p[1]+($p[3]-$p[1])*$f))
	    );
	};
	my $s = Strassen->new_stream($src);
	my $news = Strassen->new;
	$s->read_stream(sub {
	    my $r = shift;
	    my @c = @{ $r->[Strassen::COORDS()] };
	    if (@c >= 2) {
		splice @c, 0, 1, $shorten->(@c[0,1]);
	    }
	    if (@c >= 2) {
		splice @c, -1, 1, $shorten->(@c[-1,-2]);
	    }
	    if (@c >= 2) {
		$r->[Strassen::COORDS()] = [@c];
		$news->push($r);
	    }
	});
	$news->write($dest);
    }
}

######################################################################

sub action_forever_until_error {
    my($d, @argv) = @_;

    require Fcntl;
    require File::Glob;
    $d->add_component('git');

    local @ARGV = @argv;
    my $allowed_errors = 1;
    my $forever_interval = 30;
    GetOptions(
	       "allowed-errors=i" => \$allowed_errors,
	       "forever-interval=i" => \$forever_interval,
	      )
	or die "usage?";
    my @cmd = @ARGV;

    my @srcs = (
		File::Glob::bsd_glob(q{*-orig}),
		q{temp_blockings/bbbike-temp-blockings.pl},
		(defined $bbbikeauxdir ? do { my $file = "$bbbikeauxdir/bbd/fragezeichen_lowprio.bbd"; -f $file ? $file : () } : ()),
		(do { my $gps_uploads_dir = "$ENV{HOME}/.bbbike/gps_uploads"; -d $gps_uploads_dir ? $gps_uploads_dir : () }),
	       );

    my $error_count = 0;
    while() {
	next if $d->git_current_branch() ne 'master';
	{
	    open my $LOCK, '>', ".check_forever.lck"
		or die "Can't write lock file: $!";
	    flock $LOCK, &Fcntl::LOCK_EX|&Fcntl::LOCK_NB
		or die "Can't lock: $!";
	    # XXX use system() once statusref is implemented
	    my $t0 = time;
	    $d->qx({quiet => 0, statusref => \my %status}, @cmd);
	    my $t1 = time;
	    print STDERR "Run finished after " . s2ms($t1-$t0) . " minutes (at " . strftime("%F %T", localtime) . ")\n";
	    exit 2 if ($status{signalnum}||0) == 2;
	    $error_count++ if $status{exitcode};
	    exit 1 if $error_count >= $allowed_errors;
	}
    } continue {
	unlink ".check_forever.lck";
	my $t0 = time;
	print STDERR "wait...";
	if ($^O eq q{linux}) {
	    # XXX use system() once statusref is implemented
	    $d->qx({quiet => 1, statusref => \my %status},
		   qw(inotifywait -q -e close_write -e delete -e create -e moved_from -e moved_to -t), $forever_interval,
		   @srcs,
		  );
	    exit 2 if ($status{signalnum}||0) == 2;
	} else {
	    sleep $forever_interval;
	}
	my $t1 = time;
	print STDERR "finished after " . s2ms($t1-$t0) . " minutes (at " . strftime("%F %T", localtime) . ")\n";
    }
}

######################################################################

sub action_doit_update {
    my $d = shift;
    my $doitsrc  = "$ENV{HOME}/src/Doit/lib";
    my $doitdest = "$bbbikedir/lib";
    $d->mkdir("$doitdest/Doit");
    $d->copy("$doitsrc/Doit.pm", "$doitdest/");
    for my $component (qw(Brew File Git)) {
	$d->copy("$doitsrc/Doit/$component.pm", "$doitdest/Doit/");
	$d->change_file("$bbbikedir/MANIFEST",
			{ add_if_missing => "lib/Doit/$component.pm",
			  add_after => qr{^lib/Doit\.pm}, # XXX better would be a sorted insert
			}
		       );
    }
}

######################################################################

sub action_all {
    my $d = shift;
    action_files_with_tendencies($d);
    action_check_berlin_ortsteile($d);
    action_check_gesperrt_double($d);
    action_handicap_directed($d);
    action_check_handicap_directed($d);
    action_check_connected($d);
    action_survey_today($d);
    action_fragezeichen_nextcheck_bbd($d);
    #action_fragezeichen_nextcheck_org($d); # collides with action_fragezeichen_nextcheck_org_exact_dist
    action_fragezeichen_nextcheck_home_home_org($d);
    action_fragezeichen_nextcheck_without_osm_watch_org($d);
    action_sourceid($d);
}

return 1 if caller;

my $d = Doit->init;

# special actions with own argument/option handling
my %action_with_own_opt_handling = map{($_,1)}
    qw(
	  forever_until_error
	  bbbgeojsonp_index_html
	  geojson_index_html
	  check_exits
     );
if ($action_with_own_opt_handling{($ARGV[0]||'')}) {
    (my $action = $ARGV[0]) =~ s{[-.]}{_}g;
    shift;
    my $sub = "action_$action";
    if (!defined &$sub) {
	die "Action '$action' not defined";
    }
    no strict 'refs';
    &$sub($d, @ARGV);
    exit 0;
}

GetOptions or die "usage: $0 [--dry-run] action ...\n";

my @actions = @ARGV;
if (!@actions) {
    @actions = ('all');
}
for my $action (@actions) {
    $action =~ s{[-.]}{_}g;
    my $sub = "action_$action";
    if (!defined &$sub) {
	die "Action '$action' not defined";
    }
    no strict 'refs';
    &$sub($d);
}

__END__
