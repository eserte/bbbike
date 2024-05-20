# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017,2018,2019,2022,2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Doit::Git; # Convention: all commands here should be prefixed with 'git_'

use strict;
use warnings;
our $VERSION = '0.030';

use Doit::Log;
use Doit::Util qw(in_directory);

sub _pipe_open (@);

sub new { bless {}, shift }
sub functions { qw(git_repo_update git_short_status git_root git_get_commit_hash git_get_commit_files git_get_changed_files git_is_shallow git_current_branch git_config git_get_default_branch) }

sub git_repo_update {
    my($self, %opts) = @_;
    my $repository = delete $opts{repository};
    my @repository_aliases = @{ delete $opts{repository_aliases} || [] };
    my $directory  = delete $opts{directory};
    my $origin     = delete $opts{origin} || 'origin';
    my $branch     = delete $opts{branch};
    my $allow_remote_url_change = delete $opts{allow_remote_url_change};
    my $clone_opts = delete $opts{clone_opts};
    my $refresh    = delete $opts{refresh} || 'always';
    if ($refresh !~ m{^(always|never)$}) { error "refresh may be 'always' or 'never'" }
    my $quiet      = delete $opts{quiet};
    error "Unhandled options: " . join(" ", %opts) if %opts;

    my $has_changes = 0;
    my $do_clone;
    if (!-e $directory) {
	$do_clone = 1;
    } else {
	if (!-d $directory) {
	    error "'$directory' exists, but is not a directory\n";
	}
	if (!-d "$directory/.git") {
	    if (_is_dir_empty($directory)) {
		$do_clone = 1;
	    } else {
		error "No .git directory found in non-empty '$directory', refusing to clone...\n";
	    }
	}
    }
    if (!$do_clone) {
	in_directory {
	    my $actual_repository = eval { $self->info_qx({quiet=>1}, qw(git config --get), "remote.$origin.url") };
	    if (!defined $actual_repository) {
		# Remote does not exist yet --- create it.
		$self->system(qw(git remote add), $origin, $repository);
	    } else {
		chomp $actual_repository;
		if ($actual_repository ne $repository && !grep { $_ eq $actual_repository } @repository_aliases) {
		    my @change_cmd = ('git', 'remote', 'set-url', $origin, $repository);
		    if ($allow_remote_url_change) {
			info "Need to change remote URL for $origin";
			$self->system(@change_cmd);
		    } else {
			error
			    "In $directory: remote $origin does not point to $repository" . (@repository_aliases ? " (or any of the following aliases: @repository_aliases)" : "") . ", but to $actual_repository\n" .
			    "Please run manually\n" .
			    "    cd $directory\n" .
			    "    @change_cmd\n" .
			    "or specify allow_remote_url_change=>1\n";
		    }
		}
	    }

	    my $switch_later;
	    if (defined $branch) { # maybe branch switching necessary?
		if ($branch =~ m{^refs/remotes/(.*)}) { # extract branch with remote
		    $branch = $1;
		}
		my $current_branch = $self->git_current_branch;
		if (!defined $current_branch || $current_branch ne $branch) {
		    if (eval { $self->system({show_cwd=>1,quiet=>$quiet}, qw(git checkout), $branch); 1 }) {
			$has_changes = 1;
		    } else {
			# Cannot switch now to the branch. Maybe a
			# git-fetch has to be done first, as the
			# branch is not yet in the clone --- try
			# later.
			$switch_later = 1;
		    }
		}
		my %info;
		$self->git_current_branch(info_ref => \%info);
		if ($info{detached}) {
		    $switch_later = 1; # because a "git pull" wouldn't update a detached branch
		}
	    }

	    if ($refresh eq 'always') {
		$self->system({show_cwd=>1,quiet=>$quiet}, qw(git fetch), $origin);
		my $status = $self->git_short_status(untracked_files => 'no');
		if ($status =~ m{>$}) {
		    # may actually fail if diverged (status=<>)
		    # or untracked/changed files would get overwritten
		    $self->system({show_cwd=>1,quiet=>$quiet}, qw(git pull), $origin); # XXX actually would be more efficient to do a merge or rebase, but need to figure out how git does it exactly...
		    $has_changes = 1;
		} # else: ahead, diverged, or something else
	    }

	    if ($switch_later) {
		my($commit_before, $branch_before);
		if (!$has_changes) {
		    $commit_before = $self->git_get_commit_hash;
		    $branch_before = $self->git_current_branch;
		}
		if (!eval { $self->system({show_cwd=>1,quiet=>$quiet}, qw(git checkout), $branch) }) {
		    # Possible reason for the failure: $branch exists
		    # as a remote branch in multiple remotes. Try
		    # again by explicitly specifying the remote.
		    # --track exists since approx git 1.5.1
		    $self->system({show_cwd=>1,quiet=>$quiet}, qw(git checkout -b), $branch, qw(--track), "$origin/$branch");
		}
		if ($commit_before
		    && (   $self->git_get_commit_hash ne $commit_before
			|| $self->git_current_branch ne $branch_before
		    )
		) {
		    $has_changes = 1;
		}
	    }
	} $directory;
    } else {
	my @cmd = (qw(git clone --origin), $origin);
	if (defined $branch) {
	    if ($branch =~ m{^refs/remotes/[^/]+/(.*)}) { # extract branch without remote
		$branch = $1;
	    }
	    push @cmd, "--branch", $branch;
	}
	if ($clone_opts) {
	    push @cmd, @$clone_opts;
	}
	push @cmd, $repository, $directory;
	$self->system(@cmd);
	$has_changes = 1;
    }
    $has_changes;
}

sub git_short_status {
    my($self, %opts) = @_;
    my $directory       = delete $opts{directory};
    my $untracked_files = delete $opts{untracked_files};
    if (!defined $untracked_files) {
	$untracked_files = 'normal';
    } elsif ($untracked_files !~ m{^(normal|no)$}) {
	error "only values 'normal' or 'no' supported for untracked_files";
    }
    error "Unhandled options: " . join(" ", %opts) if %opts;

    in_directory {
	local $ENV{LC_ALL} = 'C';

	my $untracked_marker = '';
	{
	    my @cmd = ("git", "status", "--untracked-files=$untracked_files", "--porcelain");
	    my $fh = _pipe_open(@cmd)
		or error "Can't run '@cmd': $!";
	    my $has_untracked;
	    my $has_uncommitted;
	    while (<$fh>) {
		if (m{^\?\?}) {
		    $has_untracked++;
		} else {
		    $has_uncommitted++;
		}
		# Shortcut, exit as early as possible
		if ($has_uncommitted) {
		    if ($has_untracked) {
			return '<<*';
		    } elsif ($untracked_files eq 'no') {
			return '<<';
		    } # else we have to check further, for possible untracked files
		}
	    }
	    if ($has_uncommitted) {
		return '<<';
	    } elsif ($has_untracked) {
		$untracked_marker = '*'; # will be combined later
		last;
	    }
	    close $fh
		or error "Error while running '@cmd': $!";
	}

	{
	    my @cmd = ("git", "status", "--untracked-files=no");
	    my $fh = _pipe_open(@cmd)
		or error "Can't run '@cmd': $!";
	    my $l;
	    $l = <$fh>;
	    $l = <$fh>;
	    if      ($l =~ m{^(# )?Your branch is ahead}) {
		return '<'.$untracked_marker;
	    } elsif ($l =~ m{^(# )?Your branch is behind}) {
		return $untracked_marker.'>';
	    } elsif ($l =~ m{^(# )?Your branch and .* have diverged}) {
		return '<'.$untracked_marker.'>';
	    }
	}

	if (-f ".git/svn/.metadata") {
	    # simple-minded heuristics, works only with svn standard branch
	    # layout
	    my $root_dir = $self->git_root;
	    if (open my $fh_remote, "$root_dir/.git/refs/remotes/trunk") {
		if (open my $fh_local, "$root_dir/.git/refs/heads/master") {
		    chomp(my $sha1_remote = <$fh_remote>);
		    chomp(my $sha1_local = <$fh_local>);
		    if ($sha1_remote ne $sha1_local) {
			my $remote_is_newer;
			if (my $log_fh = _pipe_open('git', 'log', '--pretty=format:%H', 'master..remotes/trunk')) {
			    if (scalar <$log_fh>) {
				$remote_is_newer = 1;
			    }
			}
			my $local_is_newer;
			if (my $log_fh = _pipe_open('git', 'log', '--pretty=format:%H', 'remotes/trunk..master')) {
			    if (scalar <$log_fh>) {
				$local_is_newer = 1;
			    }
			}
			if ($remote_is_newer && $local_is_newer) {
			    return '<'.$untracked_marker.'>';
			} elsif ($remote_is_newer) {
			    return $untracked_marker.'>';
			} elsif ($local_is_newer) {
			    return '<'.$untracked_marker;
			} else {
			    return '?'; # Should never happen
			}
		    }
		}
	    }
	}

	return $untracked_marker;

    } $directory;
}

sub git_root {
    my($self, %opts) = @_;
    my $directory = delete $opts{directory};
    error "Unhandled options: " . join(" ", %opts) if %opts;

    in_directory {
	chomp(my $dir = $self->info_qx({quiet=>1}, 'git', 'rev-parse', '--show-toplevel'));
	$dir;
    } $directory;
}

sub git_get_commit_hash {
    my($self, %opts) = @_;
    my $directory = delete $opts{directory};
    my $commit    = delete $opts{commit};
    error "Unhandled options: " . join(" ", %opts) if %opts;

    in_directory {
	chomp(my $commit = $self->info_qx({quiet=>1}, 'git', 'log', '-1', '--format=%H', (defined $commit ? $commit : ())));
	$commit;
    } $directory;
}

sub git_get_commit_files {
    my($self, %opts) = @_;
    my $directory = delete $opts{directory};
    my $commit    = delete $opts{commit}; if (!defined $commit) { $commit = 'HEAD' }
    error "Unhandled options: " . join(" ", %opts) if %opts;

    my @files;
    in_directory {
	my @cmd = ('git', 'show', $commit, '--pretty=format:', '--name-only');
	my $fh = _pipe_open(@cmd)
	    or error "Error running @cmd: $!";
	my $first = <$fh>;
	if (defined $first && $first ne "\n") { # first line is empty for older git versions (e.g. 1.7.x)
	    chomp $first;
	    push @files, $first;
	}
	while(<$fh>) {
	    chomp;
	    push @files, $_;
	}
	close $fh
	    or error "Error while running @cmd: $!";
    } $directory;
    @files;
}

sub git_get_changed_files {
    my($self, %opts) = @_;
    my $directory        = delete $opts{directory};
    my $ignore_untracked = delete $opts{ignore_untracked};
    error "Unhandled options: " . join(" ", %opts) if %opts;

    my @files;
    in_directory {
	my @cmd = qw(git status --porcelain);
	my $fh = _pipe_open(@cmd)
	    or error "Error running @cmd: $!";
	while(<$fh>) {
	    chomp;
	    next if $ignore_untracked && m{^\?\?};
	    s{^...}{};
	    push @files, $_;
	}
	close $fh
	    or error "Error while running @cmd: $!";
    } $directory;
    @files;
}

sub git_is_shallow {
    my($self, %opts) = @_;
    my $directory = delete $opts{directory};
    error "Unhandled options: " . join(" ", %opts) if %opts;

    my $git_root = $self->git_root(directory => $directory);
    -f "$git_root/.git/shallow" ? 1 : 0;
}

sub git_current_branch {
    my($self, %opts) = @_;
    my $directory = delete $opts{directory};
    my $info_ref  = delete $opts{info_ref};
    error "Unhandled options: " . join(" ", %opts) if %opts;

    in_directory {
	my $git_root = $self->git_root;
	my $fh;
	my $this_head;
	if (open $fh, "<", "$git_root/.git/HEAD") {
	    chomp($this_head = <$fh>);
	    if ($this_head =~ m{refs/heads/(\S+)}) {
		return $1;
	    }
	}

	# fallback to git-status
	$ENV{LC_ALL} = 'C';
	if ($fh = _pipe_open(qw(git status))) {
	    chomp($_ = <$fh>);
	    if (/^On branch (.*)/) {
		if ($info_ref) {
		    $info_ref->{fallback} = 'git-status';
		}
		return $1;
	    }
	    if (/^.* detached at (.*)/) {
		if ($info_ref) {
		    $info_ref->{detached} = 1;
		    $info_ref->{fallback} = 'git-status';
		}
		return $1;
	    }
	    if (/^\Q# Not currently on any branch./) {
		# Probably old git (~ 1.5 ... 1.7)
		if (my $fh2 = _pipe_open(qw(git show-ref))) {
		    while(<$fh2>) {
			chomp;
			if (my($sha1, $ref) = $_ =~ m{^(\S+)\s+refs/remotes/(.*)$}) {
			    if ($sha1 eq $this_head) {
				if ($info_ref) {
				    $info_ref->{detached} = 1;
				    $info_ref->{fallback} = 'git-show-ref';
				}
				return $ref;
			    }
			}
		    }
		    close $fh2
			or warning "Problem while running 'git show-ref': $!";
		} else {
		    warning "Error running 'git show-ref': $!";
		}
	    }
	}

	undef;
    } $directory;
}

sub git_config {
    my($self, %opts) = @_;
    my $directory = delete $opts{directory};
    my $key       = delete $opts{key};
    my $all       = delete $opts{all};
    my $add       = delete $opts{add};
    my $val       = delete $opts{val};
    my $unset     = delete $opts{unset};
    error "Unhandled options: " . join(" ", %opts) if %opts;
    if ($all && defined $val) {
	error "Cannot handle 'all' together with 'val'";
    }
    if ($add) {
	if ($unset) {
	    error "'add' cannot be used together with 'unset'";
	}
	if (!defined $val) {
	    error "'add' must be used together with 'val'";
	}
	if (ref $val eq 'ARRAY') {
	    error "'add' only implemented for single-value 'val'";
	}
    }
    if (ref $val eq 'ARRAY') {
	if (@$val == 0) { # if array is empty, then just fallback to --unset-all
	    $unset = 1;
	    $all = 1;
	}
    }

    in_directory {
	my $ret = eval { $self->info_qx({quiet=>1}, qw(git config --null --get-all), $key) };
	my @old_vals = defined $ret ? split(/\0/, $ret) : ();
	if ($unset) {
	    if ($@) {
		if ($@->{exitcode} == 1) {
		    # already non-existent (or even invalid)
		    0;
		} else {
		    error "git config $key failed with exitcode $@->{exitcode}";
		}
	    } else {
		if ($all) {
		    if (@old_vals) {
			$self->system(qw(git config --unset-all), $key);
			return 1;
		    } else {
			# may not be reached, as getting values above probably exited with exitcode=1
			return 0;
		    }
		} else {
		    my $do_unset = 0;
		    if (defined $val) {
			for my $i (0 .. $#old_vals) {
			    if ($val eq $old_vals[$i]) {
				$do_unset = 1;
				last;
			    }
			}
		    } elsif (@old_vals) {
			$do_unset = 1;
		    } else {
			# may not be reached, as getting values above probably exited with exitcode=1
			$do_unset = 0;
		    }
		    if ($do_unset) {
			eval {
			    $self->system(qw(git config --unset --null), $key, (defined $val ? quotemeta($val) : ()));
			};
			if ($@) {
			    if ($@->{exitcode} == 5) {
				if (@old_vals <= 1) {
				    # "you try to unset an option which does not exist" -> this is accepted
				    return 0;
				} else {
				    error "Multiple values when using 'unset', please specify 'all => 1' if wanted";
				}
			    } else {
				error $@;
			    }
			}
			return 1;
		    } else {
			return 0;
		    }
		}
	    }
	} else {
	    if (!defined $val) {
		if ($all) {
		    @old_vals;
		} else {
		    $old_vals[-1];
		}
	    } else {
		if (ref $val eq 'ARRAY') {
		    my $do_set = @old_vals != @$val;
		    if (!$do_set) {
			for my $i (0 .. $#old_vals) {
			    if ($old_vals[$i] ne $val->[$i]) {
				$do_set = 1;
				last;
			    }
			}
		    }
		    if ($do_set) {
			$self->system(qw(git config --null --replace-all), $key, $val->[0]);
			for my $i (1..$#$val) {
			    $self->system(qw(git config --null --add), $key, $val->[$i]);
			}
			return 1;
		    } else {
			return 0;
		    }
		} else {
		    my $do_set = 1;
		    for my $i (0 .. $#old_vals) {
			if ($val eq $old_vals[$i]) {
			    $do_set = 0;
			    last;
			}
		    }
		    if ($do_set) {
			$self->system(qw(git config --null), ($add ? '--add' : ()), $key, $val);
			return 1;
		    } else {
			return 0;
		    }
		}
	    }
	}
    } $directory;
}

sub git_get_default_branch {
    my($self, %opts) = @_;
    my $directory = delete $opts{directory};
    my $origin    = delete $opts{origin} || 'origin';
    my $method    = delete $opts{method};
    error "Unhandled options: " . join(' ', %opts) if %opts;

    my @methods = (
	ref $method eq 'ARRAY' ? @$method :
	defined $method        ? $method  :
	                         ()
    );
    if (!@methods) { @methods = 'remote' }

    my @error_msgs;
    my $res;

    in_directory {
    TRY_METHODS: while (@methods) {
	    my $method = shift @methods;
	    if ($method eq 'remote') {
		# from https://stackoverflow.com/questions/28666357/git-how-to-get-default-branch#comment126528129_50056710
		chomp(my $info_res = $self->info_qx({quiet=>1}, qw(env LC_ALL=C git remote show), $origin));
		if ($info_res =~ /^\s*HEAD branch:\s+(.*)/m) {
		    $res = $1;
		    last TRY_METHODS;
		} else {
		    push @error_msgs, "method $method: Can't get default branch; git-remote output is:\n$res";
		}
	    } elsif ($method eq 'symbolic-ref') {
		my $parent_ref = 'refs/remotes/' . $origin;
		chomp(my $info_res = eval { $self->info_qx({quiet=>1}, qw(git symbolic-ref), "$parent_ref/HEAD") });
		if (defined $info_res && $info_res ne '') {
		    $res = substr($info_res, length($parent_ref)+1);
		    last TRY_METHODS;
		} else {
		    push @error_msgs, "method $method: Can't get default branch ($@)";
		}
	    } else {
		error "Unhandled git_get_default_branch method '$method'";
	    }
	}
    } $directory;

    if (@error_msgs) {
	error join("\n", @error_msgs);
    }

    $res;
}


# From https://stackoverflow.com/a/4495524/2332415
sub _is_dir_empty {
    my ($dir) = @_;

    opendir my $h, $dir
        or error "Cannot open directory: '$dir': $!";

    while (defined (my $entry = readdir $h)) {
        return unless $entry =~ /^[.][.]?\z/;
    }

    return 1;
}

sub _pipe_open (@) {
    my(@cmd) = @_;
    my $fh;
    if (Doit::IS_WIN && $] < 5.022) {
	open $fh, '-|', Doit::Win32Util::win32_quote_list(@cmd)
	    or return undef;
    } else {
	open $fh, '-|', @cmd
	    or return undef;
    }
    return $fh;
}

1;

__END__
