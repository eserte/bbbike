#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017,2018 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use FindBin;
use lib "$FindBin::RealBin/../lib";
use Doit;
use Doit::Log;
use Doit::Util qw(copy_stat);
use File::Basename qw(dirname basename);
use File::Compare ();
use Getopt::Long;
use Cwd 'realpath';

my $perl = $^X;
my $valid_date = 'today';

my $bbbikedir        = realpath "$FindBin::RealBin/..";
my $miscsrcdir       = "$bbbikedir/miscsrc";
my $persistenttmpdir = "$bbbikedir/tmp";

my $convert_orig_file  = "$miscsrcdir/convert_orig_to_bbd";
my @convert_orig       = ($perl, $convert_orig_file);
my @grepstrassen       = ($perl, "$miscsrcdir/grepstrassen");
my @grepstrassen_valid = (@grepstrassen, '-valid', $valid_date, '-preserveglobaldirectives');
my @replacestrassen    = ($perl, "$miscsrcdir/replacestrassen");
my @check_neighbour    = ($perl, "$miscsrcdir/check_neighbour");

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
	    error "Unexpected output in check_berlin_ortsteile:\n$output\nPlease check borders!";
	}
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
    action_handicap_directed($d);
    action_check_handicap_directed($d);
}

return 1 if caller;

my $d = Doit->init;

GetOptions or die "usage: $0 [--dry-run] action ...\n";

my @actions = @ARGV;
if (!@actions) {
    @actions = ('all');
}
for my $action (@actions) {
    my $sub = "action_$action";
    if (!defined &$sub) {
	die "Action '$action' not defined";
    }
    no strict 'refs';
    &$sub($d);
}

__END__
