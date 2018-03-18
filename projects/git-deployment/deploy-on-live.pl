#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2016,2017,2018 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;

use Cwd qw(getcwd);
use File::Basename qw(dirname basename);
use File::Spec;
use Getopt::Long;
use IPC::Run 'run';
use POSIX 'strftime';
use Sys::Hostname 'hostname';
use Term::ANSIColor 'colored';

sub sudo (@);

sub error        ($) {  die colored($_[0], 'white on_red'), "\n" }
sub error_no_die ($) { warn colored($_[0], 'white on_red'), "\n" }

sub checked_chdir ($)  { chdir $_[0] or error "Can't chdir to $_[0]: $!" }
sub mkdir_root    ($)  { if (!-d $_[0]) { sudo 'mkdir', $_[0] } }
sub symlink_root  ($$) { if (!-l $_[1]) { sudo 'ln', '-snf', $_[0], $_[1] } }

my $root_deploy_dir = '/root/work';
my $live_symlink    = 'bbbike-webserver';
my $staging_symlink = 'bbbike-webserver-staging';
my $red_basedir     = 'bbbike-webserver-red';
my $blue_basedir    = 'bbbike-webserver-blue';

my $online_branch = 'online';
my $staging_host  = 'bbbike-staging';
my $live_host     = 'localhost';

my $dry_run;
my $do_switch = 1;
my $do_init;
my $do_init_ext;
my $do_init_other;
my $test_jobs;
my $skip_tests;
my $log_dir;
my $with_mapserver;

# prepend extra options from rc file
# stolen from cpan_smoke_modules
my $rc_file = "$ENV{HOME}/.bbbikedeployrc";
if (-r $rc_file) {
    # Quick'n'dirty check if the rc file should be skipped
    if (grep { m{^--?skiprcfile$} } @ARGV) {
	@ARGV = grep { !m{^--?skiprcfile$} } @ARGV;
    } else {
	require Text::ParseWords;
	print STDERR "INFO: Reading extra options from $rc_file... ";
	open my $rcfh, $rc_file
	    or die "$rc_file exists and is readable, but cannot be opened?! Error: $!";
	my @file_ARGV;
	while(<$rcfh>) {
	    chomp;
	    next if /^\s*#/;
	    next if /^\s*$/;
	    push @file_ARGV, Text::ParseWords::shellwords($_);
	}
	print STDERR "extra options: " . (@file_ARGV ? "@file_ARGV" : '<none>') . "\n";
	unshift @ARGV, @file_ARGV;
    }
}

GetOptions(
	   'root-deploy-dir=s' => \$root_deploy_dir,
	   'n|dry-run'         => \$dry_run,
	   'test-jobs=i'       => \$test_jobs,
	   'switch!'           => \$do_switch,
	   'skip-tests'        => \$skip_tests,
	   'init'              => \$do_init,
	   'init-ext'          => \$do_init_ext,
	   'init-other'        => \$do_init_other,
	   'log-dir=s'         => \$log_dir,
	   'with-mapserver'    => \$with_mapserver,
	  )
    or error "usage: $0 [--root-deploy-dir /path/to/dir] [--dry-run] [--test-jobs ...] [--skip-tests] [--no-switch]";

if ($log_dir && !$dry_run) {
    my $log_file = $log_dir . '/bbbike_deploy_' . strftime('%FT%T', localtime) . '.log';
    require File::Tee;
    File::Tee::tee(\*STDOUT, '>>', $log_file);
    File::Tee::tee(\*STDERR, '>>', $log_file);
}

print STDERR colored("Hopefully everything's already pushed to github", "yellow on_black"), "\n";
print STDERR colored('Prerequisite checks, please stand by...', 'white on_red'), "\n";

my $sudo_validator_pid;
sudo 'echo', 'Initialized sudo password';

my $live_dir    = "$root_deploy_dir/$live_symlink";
my $staging_dir = "$root_deploy_dir/$staging_symlink";
my $red_dir     = "$root_deploy_dir/$red_basedir";
my $blue_dir    = "$root_deploy_dir/$blue_basedir";

if ($do_init)       { init() }
if ($do_init_ext)   { init_ext() } # XXX this should be done automatically, and be more efficient than now (i.e. only do something on changes)
if ($do_init_other) { init_other() } # XXX this should be done automatically

error "The 'red' directory '$red_dir' does not exist or is not a directory, please re-run with --init" if !-d $red_dir;
error "The 'blue' directory '$blue_dir' does not exist or is not a directory, please re-run with --init" if !-d $blue_dir;
error "Not a symlink: '$live_dir', please re-run with --init" if !-l $live_dir;
error "Not a symlink: '$staging_dir', please re-run with --init" if !-l $staging_dir;

my $current_live_dir    = File::Spec->rel2abs(readlink($live_dir), dirname($live_dir));
my $current_staging_dir = File::Spec->rel2abs(readlink($staging_dir), dirname($staging_dir));

error "Symlink of '$live_dir' points to '$current_live_dir', which is neither the red nor the blue directory"
    if $current_live_dir ne $red_dir && $current_live_dir ne $blue_dir;
error "Symlink of '$staging_dir' points to '$current_staging_dir', which is neither the red nor the blue directory"
    if $current_staging_dir ne $red_dir && $current_staging_dir ne $blue_dir;

error "Live and staging symlinks point to the same directory '$current_live_dir'"
    if $current_live_dir eq $current_staging_dir;

checked_chdir "$current_live_dir/BBBike";
if (!run ["git", "status"]) {
    error "git-status in live directory failed, directory not clean?";
}

checked_chdir "$current_staging_dir/BBBike";
if (!run ["git", "status"]) {
    error "git-status in staging directory failed, directory not clean?";
}

{
    my $current_branch = get_current_branch();
    if ($current_branch ne $online_branch) {
	error "staging directory is not on expected branch '$online_branch', but on '$current_branch'";
    }
}

# Also done in dry-run mode --- it's assumed that
# git-fetch is a non-destroying cache operation.
if (!run ['git', 'fetch', 'origin']) {
    error "Cannot fetch origin";
}

if ($dry_run) {
    warn "NOTE: would run git merge now...\n";
} else {
    if (!run ['git', 'merge', 'origin/master'], '>', File::Spec->devnull, '<', File::Spec->devnull) {
	error 'merging with origin/master failed';
    }
}

if ($dry_run) {
    warn "NOTE: would create some files in data/ directory...\n";
} else {
    push @INC, "$current_staging_dir/BBBike";
    require BBBikeBuildUtil;
    my $pwd = save_pwd2();
    checked_chdir "data";
    my $pmake = BBBikeBuildUtil::get_pmake();
    my @cmd = ($pmake, ($test_jobs ? "-j$test_jobs" : ()), "live-deployment-targets");
    system @cmd;
    if ($? != 0) {
	die "Command '@cmd' failed";
    }

    # if we have changed files because of the build, then remove them
    system('git', 'checkout', '--', '.');
}

print STDERR colored("Now tests are running...", "white on_green"), "\n";

if ($dry_run) {
    warn "NOTE: would run tests now...\n";
} elsif ($skip_tests) {
    if (!$do_switch) {
	# don't ask
    } else {
	print STDERR "Really skip tests? (y/n) ";
	while () {
	    chomp(my $yn = <STDIN>);
	    if ($yn eq 'y') {
		last;
	    } elsif ($yn eq 'n') {
		warn "OK, aborting deployment...\n";
		exit 1;
	    } else {
		print STDERR "Please answer y or n: ";
	    }
	}
    }
} else {
    local $ENV{LANG} = 'C';
    local $ENV{BBBIKE_TEST_SKIP_MAPSERVER};
    if (!$with_mapserver) {
	$ENV{BBBIKE_TEST_SKIP_MAPSERVER} = 1;
    }
    local $ENV{BBBIKE_TEST_SKIP_PALMDOC} = 1;
    local $ENV{BBBIKE_TEST_CGIDIR} = "http://$staging_host/cgi-bin";
    local $ENV{BBBIKE_TEST_HTMLDIR} = "http://$staging_host/BBBike";
    local $ENV{BBBIKE_TEST_FOR_LIVE} = 1;
    if (!run ["prove", ($test_jobs ? "-j$test_jobs" : ()), '-w', '-I', 'Ilib', glob("t/*.t")]) {
	error "test run failed";
    }
}

if ($do_switch) {
    checked_chdir $root_deploy_dir;
    sudo 'ln', '-snf', basename($current_staging_dir), $live_symlink
	or error 'Symlinking the live directory failed';
    if ($current_staging_dir eq $blue_dir) {
	sudo 'ln', '-snf', $red_basedir, $staging_symlink
	    or warn "Symlink the staging directory failed, please check later!\n";
    } else {
	sudo 'ln', '-snf', $blue_basedir, $staging_symlink
	    or warn "Symlink the staging directory failed, please check later!\n";
    }

    checked_chdir "$live_dir/BBBike";

    if ($dry_run) {
	warn "NOTE: would run quick live tests now...\n";
    } else {
	print STDERR "Run short test suite on live system...\n";
	local $ENV{LANG} = 'C';
	local $ENV{BBBIKE_TEST_SKIP_MAPSERVER} = 1;
	local $ENV{BBBIKE_TEST_SKIP_PALMDOC} = 1;
	local $ENV{BBBIKE_TEST_CGIDIR} = "http://$live_host/cgi-bin";
	local $ENV{BBBIKE_TEST_HTMLDIR} = "http://$live_host/BBBike";
	local $ENV{BBBIKE_TEST_FOR_LIVE} = 1;
	if (!run ["prove", '-w', '-I', 'Ilib', 't/cgihead.t']) {
	    error "cgihead.t test run on live system failed";
	}
    }

    {
	my($live_color) = getcwd =~ m{(red|blue)/BBBike$};
	if (!$live_color) {
	    error "Cannot get 'color' from " . getcwd;
	}
	(my $tag_prefix = hostname) =~ s{[^A-Za-z0-9_-]+}{_}g;
	$tag_prefix = 'deployment/' . $tag_prefix;
	my $today = strftime '%Y%m%d', localtime;
	my $today_tag;
	for my $suffix ('', map { '_'.$_ } (1..9)) {
	    $today_tag = $tag_prefix.'_'.$live_color.'/'.$today.$suffix;
	    my $result;
	    if (!run ['git', 'tag', '-l', $today_tag], ">", \$result) {
		error "'git tag -l $today_tag' command failed";
	    }
	    if ($result eq '') {
		# use this tag
		last;
	    }
	}
	my @git_tag_cmds =
	    (
	     ['git', 'tag', '-a', '-m', 'automatic deployment', $today_tag],
	     ['git', 'tag', '-f', $tag_prefix.'/current'],
	    );
	if ($dry_run) {
	    warn "NOTE: would run the following git tag commands\n";
	    for (@git_tag_cmds) {
		warn "     @$_\n";
	    }
	} else {
	    for my $git_tag_cmd (@git_tag_cmds) {
		print STDERR "+ @$git_tag_cmd\n";
		if (!run $git_tag_cmd) {
		    error "'@$git_tag_cmd' failed";
		}
	    }
	}

	checked_chdir "$staging_dir/BBBike";

	my @git_tag_delete_cmd = ('git', 'tag', '-d', $tag_prefix.'/current');
	if ($dry_run) {
	    warn "NOTE: would run the following git tag command on the staging directory\n";
	    warn "      @git_tag_delete_cmd\n";
	} else {
	    print STDERR "+ @git_tag_delete_cmd\n";
	    run \@git_tag_delete_cmd; # don't die on error, may happen on 1st time deployment
	}

	# only report, don't run with --touch option
	system "$live_dir/BBBike/miscsrc/update-modperl-reload-touchfile.pl";
    }

} else {
    warn "NOTE: skip final switching step...\n";
}

END {
    if ($sudo_validator_pid) {
	kill $sudo_validator_pid;
	undef $sudo_validator_pid;
    }
}

sub init {
    if ($dry_run) {
	warn "NOTE: would run a series of initialization steps...\n";
	return;
    }
    if (!-d $root_deploy_dir) {
	while() {
	    print STDERR colored("Should the root directory be created? (y/n) ", 'white on_red');
	    chomp(my $yn = <STDIN>);
	    if ($yn =~ m{^n}i) {
		error 'OK, exiting deployment';
	    } elsif ($yn !~ m{^y}i) {
		error_no_die 'Please answer y or n';
	    } else {
		last;
	    }
	}
	sudo 'mkdir', '-p', $root_deploy_dir;
    }
    mkdir_root $red_dir;
    mkdir_root $blue_dir;
    symlink_root $red_basedir, $live_dir;
    symlink_root $blue_basedir, $staging_dir;
    for ($red_dir, $blue_dir) {
	sudo 'chgrp', 'adm', $_;
	sudo 'chmod', 'g+rwx', $_;
    }
    if (!-d "$red_dir/BBBike") {
	my $save_pwd = save_pwd2();
	checked_chdir $red_dir;
	run ['git', 'clone', '--depth=1', 'git://github.com/eserte/bbbike', 'BBBike']
	    or die "git-clone failed";
    }
    if (!-d "$blue_dir/BBBike") {
	my $save_pwd = save_pwd2();
	checked_chdir $blue_dir;
	run ['git', 'clone', '--depth=1', 'git://github.com/eserte/bbbike', 'BBBike']
	    or die "git-clone failed";
    }
    for my $dir ($red_dir, $blue_dir) {
	my $save_pwd = save_pwd2();
	checked_chdir "$dir/BBBike";
	my $current_branch = get_current_branch();
	if ($current_branch ne 'online') {
	    if ($current_branch eq 'master') {
		run ['git', 'checkout', '-b', 'online']
		    or die "Cannot create+switch to online branch in $dir/BBBike";
	    } else {
		error "Not on expected branches master or online, but '$current_branch' (in $dir/BBBike)";
	    }
	}
    }
}

sub init_ext {
    if ($dry_run) {
	warn "NOTE: would run initialization of ext modules...\n";
	return;
    }
    for my $dir ($red_dir, $blue_dir) {
	my $save_pw = save_pwd2();
	checked_chdir "$dir/BBBike/ext";
	run ['make', 'all']
	    or die "Error while building ext modules";
	run ['make', 'install']
	    or die "Error while installing ext modules";
    }
}

sub init_other {
    if ($dry_run) {
	warn "NOTE: would run initialization for cgi-bin, tmp, public...\n";
	return;
    }

    for my $dir ($red_dir, $blue_dir) {
	my $cgi_bin = "$dir/cgi-bin";
	mkdir_root $cgi_bin;
	my $save_pwd = save_pwd2();
	checked_chdir $cgi_bin;
	for my $file (qw(
			    bbbike.cgi.config bbbike2.cgi.config bbbike-test.cgi.config bbbike2-test.cgi.config
			    bbbike-snapshot.cgi bbbike-data.cgi bbbike-teaser.pl
			    mapserver_address.cgi mapserver_comment.cgi wapbbbike.cgi
			    qrcode.cgi
		       )) {
	    symlink_root "../BBBike/cgi/$file", $file;
	}
	for my $file (qw(bbbike.cgi bbbike.en.cgi bbbike2.cgi bbbike2.en.cgi bbbike-test.cgi bbbike-test.en.cgi bbbike2-test.cgi)) {
	    symlink_root '../BBBike/cgi/bbbike.cgi', $file;
	}
	for my $file (qw(bbbikegooglemap.cgi bbbikegooglemap2.cgi)) {
	    symlink_root '../BBBike/cgi/bbbikegooglemap.cgi', $file;
	}
	for my $file (qw(bbbikeleaflet.cgi bbbikeleaflet.en.cgi)) {
	    symlink_root '../BBBike/cgi/bbbikeleaflet.cgi', $file;
	}
	if ($with_mapserver && -e "/usr/lib/cgi-bin/mapserv") {
	    symlink_root '/usr/lib/cgi-bin/mapserv', 'mapserv';
	}

	mkdir_root "$dir/BBBike/tmp";
	chmod 0777, "$dir/BBBike/tmp";

	mkdir_root "$dir/BBBike/tmp/www";
	chmod 0777, "$dir/BBBike/tmp/www";

	mkdir_root "$root_deploy_dir/bbbike-persistent-data";
	chmod 0755, "$root_deploy_dir/bbbike-persistent-data";

	mkdir_root "$root_deploy_dir/bbbike-persistent-data/uaprof";
	chmod 0777, "$root_deploy_dir/bbbike-persistent-data/uaprof";

	symlink_root "$root_deploy_dir/bbbike-persistent-data/uaprof", "$dir/BBBike/tmp/uaprof";

	mkdir_root "$dir/public";
	symlink_root '../BBBike', "$dir/public/BBBike";

	if ($with_mapserver) {
	    mkdir_root "$dir/public/mapserver";
	}
    }
}

sub get_current_branch {
    my @cmd = ('git', 'branch', '--quiet', '--color=never', '--contains=HEAD');
    my $branches;
    if (!run [@cmd], ">", \$branches) {
	error "running @cmd failed";
    }
    my($current_branch) = $branches =~ m{^\* (.*)}m;
    if (!defined $current_branch) {
	error "cannot get current branches in directory " . getcwd . ", got '$branches' from @cmd call";
    }
    $current_branch;
}

sub sudo (@) {
    my(@cmd) = @_;
    if (!$dry_run) {
	system 'sudo', '-v';
    }
    if (!$sudo_validator_pid) {
	my $parent = $$;
	$sudo_validator_pid = fork;
	if ($sudo_validator_pid == 0) {
	    # child
	    while() {
		sleep 60; # assumes that sudo timeout is larger than one minute!!!
		if (!kill 0 => $parent) {
		    exit;
		}
		if (!$dry_run) {
		    system 'sudo', '-v';
		}
	    }
	}
    }
    if ($dry_run) {
	warn "Would run 'sudo @cmd'...\n";
	1;
    } else {
	warn "+ sudo @cmd\n";
	system 'sudo', @cmd;
	return ($? == 0);
    }
}

# REPO BEGIN
# REPO NAME save_pwd2 /home/e/eserte/src/srezic-repository 
# REPO MD5 7434e238c5a4a72f68f97f5fe29ba9a6
BEGIN {
    sub save_pwd2 {
	require Cwd;
	bless {cwd => Cwd::getcwd()}, __PACKAGE__ . '::SavePwd2';
    }
    my $DESTROY = sub {
	my $self = shift;
	chdir $self->{cwd}
	    or die "Can't chdir to $self->{cwd}: $!";
    };
    no strict 'refs';
    *{__PACKAGE__.'::SavePwd2::DESTROY'} = $DESTROY;
}
# REPO END

__END__

# The default deployment directory is currently /root/work. But it's
# better to use /srv/www instead:
#
#    deploy-on-live.pl --root-deploy-dir /srv/www
#
# Before the first run, make sure that the current user is in the adm group:
#
#   usermod -a -G adm $USER
#
# ... and logout/login into the shell to make this effective.
#
# Minimum package prerequisites to run this script are:
#
#     sudo aptitude install libipc-run-perl bmake
#
# The very first run should be done with the --init switch (the error
# messages will tell so otherwise)
#
# XXX Maybe do some changes to the online branch (html/newstreetform* changes, ignoring t/.prove)
#
# REGULAR RUNS:
#
# Currently the regular deployment looks like this:
#
#     reset; /root/work/bbbike-webserver-staging/BBBike/projects/git-deployment/deploy-on-live.pl --init-other --test-jobs=3 --log-dir=/var/tmp
# 
# PROBLEMS:
#
# * Test failures which would be fixed by reloading modperl handlers
#
# The problem is that staging + live share the same modperl handlers,
# namely the set from the live directory. So during a normal
# deployment the old code, test-failure causing is used, and the
# switch never happens because of the test failures. In this situation
# the option --skip-tests has to be used.
