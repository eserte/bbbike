#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014 Slaven Rezic. All rights reserved.
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

sub error ($) {
    die colored($_[0], 'white on_red'), "\n";
}

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
my $test_jobs;
my $skip_tests;

GetOptions(
	   'root-deploy-dir=s' => \$root_deploy_dir,
	   'n|dry-run'         => \$dry_run,
	   'test-jobs=i'       => \$test_jobs,
	   'switch!'           => \$do_switch,
	   'skip-tests'        => \$skip_tests,
	  )
    or error "usage: $0 [--root-deploy-dir /path/to/dir] [--dry-run] [--test-jobs ...] [--skip-tests] [--no-switch]";

print STDERR colored("Hopefully everything's already pushed to github", "yellow on_black"), "\n";
print STDERR colored('Prerequisite checks, please stand by...', 'white on_red'), "\n";

my $sudo_validator_pid;
sudo 'echo', 'Initialized sudo password';

my $live_dir    = "$root_deploy_dir/$live_symlink";
my $staging_dir = "$root_deploy_dir/$staging_symlink";
my $red_dir     = "$root_deploy_dir/$red_basedir";
my $blue_dir    = "$root_deploy_dir/$blue_basedir";

error "The 'red' directory '$red_dir' does not exist or is not a directory" if !-d $red_dir;
error "The 'blue' directory '$blue_dir' does not exist or is not a directory" if !-d $blue_dir;
error "Not a symlink: '$live_dir'" if !-l $live_dir;
error "Not a symlink: '$staging_dir'" if !-l $staging_dir;

my $current_live_dir    = File::Spec->rel2abs(readlink($live_dir), dirname($live_dir));
my $current_staging_dir = File::Spec->rel2abs(readlink($staging_dir), dirname($staging_dir));

error "Symlink of '$live_dir' points to '$current_live_dir', which is neither the red nor the blue directory"
    if $current_live_dir ne $red_dir && $current_live_dir ne $blue_dir;
error "Symlink of '$staging_dir' points to '$current_staging_dir', which is neither the red nor the blue directory"
    if $current_staging_dir ne $red_dir && $current_staging_dir ne $blue_dir;

error "Live and staging symlinks point to the same directory '$current_live_dir'"
    if $current_live_dir eq $current_staging_dir;

chdir "$current_live_dir/BBBike"
    or error "Can't chdir to $current_live_dir/BBBike: $!";
if (!run ["git", "status"]) {
    error "git-status in live directory failed, directory not clean?";
}

chdir "$current_staging_dir/BBBike"
    or error "Can't chdir to $current_staging_dir/BBBike: $!";
if (!run ["git", "status"]) {
    error "git-status in staging directory failed, directory not clean?";
}

{
    my $current_branch;
    if (!run ['git', 'branch', '--quiet', '--color=never', '--contains=HEAD'], ">", \$current_branch) {
	error "running git-branch failed";
    }
    $current_branch =~ s{^\* }{};
    chomp $current_branch;
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
    chdir "data"
	or die "Can't change to data subdirectory: $!";
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
} else {
    local $ENV{LANG} = 'C';
    local $ENV{BBBIKE_TEST_SKIP_MAPSERVER} = 1;
    local $ENV{BBBIKE_TEST_SKIP_PALMDOC} = 1;
    local $ENV{BBBIKE_TEST_CGIDIR} = "http://$staging_host/cgi-bin";
    local $ENV{BBBIKE_TEST_HTMLDIR} = "http://$staging_host/BBBike";
    local $ENV{BBBIKE_TEST_FOR_LIVE} = 1;
    if (!run ["prove", ($test_jobs ? "-j$test_jobs" : ()), '-w', '-I', 'Ilib', glob("t/*.t")]) {
	error "test run failed";
    }
}

if ($do_switch) {
    chdir $root_deploy_dir
	or error "Can't chdir to $root_deploy_dir: $!";
    sudo 'ln', '-snf', basename($current_staging_dir), $live_symlink
	or error 'Symlinking the live directory failed';
    if ($current_staging_dir eq $blue_dir) {
	sudo 'ln', '-snf', $red_basedir, $staging_symlink
	    or warn "Symlink the staging directory failed, please check later!\n";
    } else {
	sudo 'ln', '-snf', $blue_basedir, $staging_symlink
	    or warn "Symlink the staging directory failed, please check later!\n";
    }

    chdir "$live_dir/BBBike"
	or error "chdir failed: $!";

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

	chdir "$staging_dir/BBBike"
	    or error "chdir failed: $!";

	my @git_tag_delete_cmd = ('git', 'tag', '-d', $tag_prefix.'/current');
	if ($dry_run) {
	    warn "NOTE: would run the following git tag command on the staging directory\n";
	    warn "      @git_tag_delete_cmd\n";
	} else {
	    print STDERR "+ @git_tag_delete_cmd\n";
	    run \@git_tag_delete_cmd; # don't die on error, may happen on 1st time deployment
	}
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

# XXX first run missing, initial directories and git clones have to be created manually
# Approximately like this:
#     mkdir -p /root/work/bbbike-webserver-red
#     mkdir -p /root/work/bbbike-webserver-blue
#     (cd /root/work/bbbike-webserver-red && git clone git://github.com/eserte/bbbike BBBike && git checkout -b online)
#     (cd /root/work/bbbike-webserver-blue && git clone git://github.com/eserte/bbbike BBBike && git checkout -b online)
# Maybe do some changes to the online branch (html/newstreetform* changes, ignoring t/.prove)
