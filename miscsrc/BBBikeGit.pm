#!/usr/bin/perl

package BBBikeGit;

use strict;
use warnings;

=head1 NAME

BBBikeGit - return patchnum

=head1 SYNOPSIS

  require BBBikeGit;
  %git_info = BBBikeGit::git_info();

=head1 DESCRIPTION

This module returns information about the current git version and
locally applied patches to the source code.

=head1 AUTHOR

Original authors of make_patchnum.pl: Yves Orton, Kenichi Ishigaki,
Max Maischein

Changes to BBBikeGit: Slaven Rezic

=head1 COPYRIGHT

Same terms as Perl itself.

=cut

use BBBikeUtil qw(save_pwd bbbike_root is_in_path);

our $VERBOSE;

sub _path_to { bbbike_root . "/$_[0]" }

sub _read_file {
    my $file = _path_to(@_);
    return "" unless -e $file;
    open my $fh, '<', $file
        or die "Failed to open for read '$file':$!";
    return do { local $/; <$fh> };
}

sub _backtick {
    # only for git.  If we're in a -Dmksymlinks build-dir, we need to
    # cd to src so git will work .  Probably a better way.
    my $command = shift;
    if (wantarray) {
        my @result;
	save_pwd {
	    chdir bbbike_root or die "Can't chdir to bbbike's root: $!";
	    @result = `$command`;
	    warn "$command: \$?=$?\n" if $?;
	    print "#> $command ->\n @result\n" if !$? and $VERBOSE;
	};
        chomp @result;
        return @result;
    } else {
        my $result;
	save_pwd {
	    chdir bbbike_root or die "Can't chdir to bbbike's root: $!";
	    $result = `$command`;
	    $result="" if ! defined $result;
	    warn "$command: \$?=$?\n" if $?;
	    print "#> $command ->\n $result\n" if !$? and $VERBOSE;
	};
        chomp $result;
        return $result;
    }
}

sub git_info {
    my %git_info;
    return if !is_in_path('git');

    my @unpushed_commits;
    my ($read, $branch, $snapshot_created, $commit_id, $describe)= ("") x 5;
    my ($changed, $extra_info, $commit_title, $new_patchnum, $status)= ("") x 5;

    if (my $patch_file= _read_file(".patch")) {
	($branch, $snapshot_created, $commit_id, $describe) = split /\s+/, $patch_file;
	$git_info{'snapshot_date'} = $snapshot_created;
	$commit_title = "Snapshot of:";
    } elsif (-d bbbike_root . "/.git") {
	# git branch | awk 'BEGIN{ORS=""} /\*/ { print $2 }'
	($branch) = map { /\* ([^(]\S*)/ ? $1 : () } _backtick("git branch");
	my ($remote,$merge);
	if (length $branch) {
	    $merge= _backtick("git config branch.$branch.merge");
	    $merge =~ s!^refs/heads/!!;
	    $remote= _backtick("git config branch.$branch.remote");
	}
	$commit_id = _backtick("git rev-parse HEAD");
	$describe = _backtick("git describe");
	my $commit_created = _backtick(qq{git log -1 --pretty="format:%ci"});
	$new_patchnum = "describe: $describe";
	$git_info{'commit_date'} = $commit_created;
	if (length $branch && length $remote) {
	    @unpushed_commits = map { (split /\s/, $_)[1] } grep {/\+/} _backtick("git cherry $remote/$merge");
	    if (@unpushed_commits) {
		$commit_title = "Local Commit:";
		my $ancestor = _backtick("git rev-parse $remote/$merge");
		$git_info{ancestor} = $ancestor;
		$git_info{remote_branch} = "$remote/$merge";
		$git_info{unpushed} = \@unpushed_commits;
	    }
	}
	# XXX The "changed" logic does not work here. Should probably
	# look at "git status" result.
	if ($changed) {	       # not touched since init'd. never true.
	    $changed = 'true';
	    $commit_title =  "Derived from:";
	    $status='"uncommitted-changes"'
	} else {
	    $status='/*clean-working-directory-maybe*/'
	}
	$commit_title ||= "Commit id:";
    }

    $git_info{branch} = $branch;
    $git_info{commit_id} = $commit_id;
    $git_info{commit_id_title} = $commit_title;
    $git_info{describe} = $describe;
    $git_info{patchnum} = $describe;
    $git_info{uncommited_changes} = $status;

    %git_info;
}

return 1 if caller;

require Data::Dumper;
require Getopt::Long;

Getopt::Long::GetOptions("v" => \$VERBOSE)
    or die "usage: $0 [-v]";

my %git_info = git_info();
print Data::Dumper::Dumper(\%git_info);

