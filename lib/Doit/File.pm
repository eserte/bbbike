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

package Doit::File;

use strict;
use warnings;
our $VERSION = '0.023';

use Doit::Log;
use Doit::Util qw(copy_stat new_scope_cleanup);

sub new { bless {}, shift }
sub functions { qw(file_atomic_write) }

sub file_atomic_write {
    my($doit, $file, $code, %opts) = @_;

    if (!defined $file) {
	error "File parameter is missing";
    }
    if (!defined $code) {
	error "Code parameter is missing";
    } elsif (ref $code ne 'CODE') {
	error "Code parameter should be an anonymous subroutine or subroutine reference";
    }

    require File::Basename;
    require Cwd;
    my $dest_dir = Cwd::realpath(File::Basename::dirname($file));

    my $tmp_suffix   = delete $opts{tmpsuffix} || '.tmp';
    my $tmp_dir      = delete $opts{tmpdir}; if (!defined $tmp_dir) { $tmp_dir = $dest_dir }
    my $mode         = delete $opts{mode};
    my $check_change = delete $opts{check_change};
    error "Unhandled options: " . join(" ", %opts) if %opts;

    my($tmp_fh,$tmp_file);
    my(@cleanup_files, @cleanup_fhs);
    my $tempfile_scope = new_scope_cleanup {
	for my $cleanup_fh (@cleanup_fhs) { # required on Windows, otherwise unlink won't work
	    close $cleanup_fh if fileno($cleanup_fh);
	}
	for my $cleanup_file (@cleanup_files) {
	    unlink $cleanup_file if -e $cleanup_file;
	}
    };
    if ($tmp_dir eq '/dev/full') {
	# This is just used for testing error on close()
	$tmp_file = '/dev/full';
	open $tmp_fh, '>', $tmp_file
	    or error "Can't write to $tmp_file: $!";
    } else {
	require File::Temp;
	($tmp_fh,$tmp_file) = File::Temp::tempfile(SUFFIX => $tmp_suffix, DIR => $tmp_dir, EXLOCK => 0);
	push @cleanup_files, $tmp_file;
	push @cleanup_fhs, $tmp_fh;
	if (defined $mode) {
	    $doit->chmod({quiet => 1}, $mode, $tmp_file);
	} else {
	    $doit->chmod({quiet => 1}, 0666 & ~umask, $tmp_file);
	}
	if ($tmp_dir ne $dest_dir) {
	    my @stat_destdir = stat $dest_dir;
	    if ($^O =~ /bsd/ || $^O eq 'darwin' || ($stat_destdir[2] & 02000)) {
		$doit->chown({quiet => 1 }, undef, $stat_destdir[5], $tmp_file);
	    }
	}
    }
    my $same_fs = do {
	my $tmp_dev  = (stat($tmp_file))[0];
	my $dest_dev = (stat($dest_dir))[0];
	$tmp_dev == $dest_dev;
    };

    if ($same_fs) {
	if (-e $file) {
	    copy_stat $file, $tmp_file, ownership => 1, mode => !defined $mode;
	}
    } else {
	require File::Copy; # for move()
    }

    eval { $code->($tmp_fh, $tmp_file) };
    if ($@) {
	error $@;
    }

    if ($] < 5.010001) { $! = 0 }
    $tmp_fh->close
	or error "Error while closing temporary file $tmp_file: $!";
    if ($] < 5.010001 && $! != 0) { # at least perl 5.8.8 and 5.8.9 are buggy and do not detect errors at close time --- 5.10.1 is correct
	error "Error while closing temporary file $tmp_file: $!";
    }

    if ($check_change) {
	require File::Compare;
	if (File::Compare::compare($tmp_file, $file) == 0) {
	    # unchanged
	    return 0;
	}
    }

    if ($same_fs) {
	_make_writeable($doit, $file, 'rename');
	$doit->rename($tmp_file, $file);
    } else {
	my @dest_stat;
	if (-e $file) {
	    @dest_stat = stat($file)
		or warning "Cannot stat $file: $! (cannot preserve permissions)"; # XXX should this be an error?
	    _make_writeable($doit, $file, 'File::Copy::move');
	}
	$doit->move($tmp_file, $file);
	if (@dest_stat) { # In dry-run mode effectively a noop
	    $dest_stat[2] = $mode if defined $mode;
	    copy_stat [@dest_stat], $file, ownership => 1, mode => 1;
	} elsif (defined $mode) {
	    $dest_stat[2] = $mode if defined $mode;
	    copy_stat [@dest_stat], $file, mode => 1;
	}
    }

    return 1;
}

sub _make_writeable {
    my($doit, $file, $for) = @_;
    return if $for eq 'rename' && !Doit::IS_WIN; # don't need to do anything
    my @s = stat($file);
    return if !@s; # not stat-able -> file does not exist yet?
    my $old_mode = $s[2] & 07777;
    return if ($old_mode & 0200); # already writable
    $doit->chmod(($old_mode | 0200), $file);
}

1;

__END__
