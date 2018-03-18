# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017,2018 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Doit::Git; # Convention: all commands here should be prefixed with 'git_'

use strict;
use warnings;
our $VERSION = '0.025';

use Doit::Log;
use Doit::Util qw(in_directory);

sub _pipe_open (@);

sub new { bless {}, shift }
sub functions { qw(git_repo_update git_short_status git_root git_get_commit_hash git_get_commit_files git_get_changed_files git_is_shallow git_current_branch git_config) }

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
			    "    @change_cmd\n" .
			    "or specify allow_remote_url_change=>1\n";
		    }
		}
	    }

	    my $switch_later;
	    if (defined $branch) { # maybe branch switching necessary?
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
		$self->system({show_cwd=>1,quiet=>$quiet}, qw(git checkout), $branch);
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
    error "Unhandled options: " . join(" ", %opts) if %opts;

    in_directory {
	chomp(my $commit = $self->info_qx({quiet=>1}, 'git', 'log', '-1', '--format=%H'));
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
    my $directory = delete $opts{directory};
    error "Unhandled options: " . join(" ", %opts) if %opts;

    my @files;
    in_directory {
	my @cmd = qw(git status --porcelain);
	my $fh = _pipe_open(@cmd)
	    or error "Error running @cmd: $!";
	while(<$fh>) {
	    chomp;
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
    my $val       = delete $opts{val};
    my $unset     = delete $opts{unset};
    error "Unhandled options: " . join(" ", %opts) if %opts;
    if (defined $val && $unset) {
	error "Don't specify both 'unset' and 'val'";
    }

    in_directory {
	no warnings 'uninitialized'; # $old_val may be undef
	chomp(my($old_val) = eval { $self->info_qx({quiet=>1}, qw(git config), $key) });
	if ($unset) {
	    if ($@) {
		if ($@->{exitcode} == 1) {
		    # already non-existent (or even invalid)
		    0;
		} else {
		    error "git config $key failed with exitcode $@->{exitcode}";
		}
	    } else {
		$self->system(qw(git config --unset), $key, (defined $val ? $val : ()));
		1;
	    }
	} else {
	    if (!defined $val) {
		$old_val;
	    } else {
		if (!defined $old_val || $old_val ne $val) {
		    $self->system(qw(git config), $key, $val);
		    1;
		} else {
		    0;
		}
	    }
	}
    } $directory;
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
