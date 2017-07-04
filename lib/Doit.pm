#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;

{
    package Doit::Log;

    sub _use_coloring {
	no warnings 'redefine';
	*colored_error = sub ($) { Term::ANSIColor::colored($_[0], 'red on_black')};
	*colored_info  = sub ($) { Term::ANSIColor::colored($_[0], 'green on_black')};
	*colored_note  = sub ($) { Term::ANSIColor::colored($_[0], 'yellow on_black')};
    }
    sub _no_coloring {
	no warnings 'redefine';
	*colored_error = *colored_info = *colored_note = sub ($) { $_[0] };
    }
    {
	my $can_coloring;
	sub _can_coloring {
	    return $can_coloring if defined $can_coloring;
	    $can_coloring = eval { require Term::ANSIColor; 1 } ? 1 : 0;
	}
    }

    BEGIN {
	if (_can_coloring()) {
	    _use_coloring();
	} else {
	    _no_coloring();
	}
    }

    use Exporter 'import';
    our @EXPORT; BEGIN { @EXPORT = qw(info note warning error) }

    BEGIN { $INC{'Doit/Log.pm'} = __FILE__ } # XXX hack

    my $current_label = '';

    sub info ($)    { print STDERR colored_info("INFO$current_label:"), " ", $_[0], "\n" }
    sub note ($)    { print STDERR colored_note("NOTE$current_label:"), " ", $_[0], "\n" }
    sub warning ($) { print STDERR colored_error("WARN$current_label:"), " ", $_[0], "\n" }
    sub error ($)   { require Carp; Carp::croak(colored_error("ERROR$current_label:"), " ", $_[0]) }

    sub set_label ($) {
	my $label = shift;
	if (defined $label) {
	    $current_label = " $label";
	} else {
	    $current_label = '';
	}
    }
}

{
    package Doit::Exception;
    use overload '""' => 'stringify';
    use Exporter 'import';
    our @EXPORT_OK = qw(throw);
    $INC{'Doit/Exception.pm'} = __FILE__; # XXX hack

    sub new {
	my($class, $msg, %opts) = @_;
	my $level = delete $opts{__level} || 1;
	($opts{__package}, $opts{__filename}, $opts{__line}) = caller($level);
	bless {
	       __msg  => $msg,
	       %opts,
	      }, $class;
    }
    sub stringify {
	my $self = shift;
	my $msg = $self->{__msg};
	$msg = 'Died' if !defined $msg;
	if ($msg !~ /\n\z/) {
	    $msg .= ' at ' . $self->{__filename} . ' line ' . $self->{__line} . ".\n";
	}
	$msg;
    }

    sub throw { die Doit::Exception->new(@_) }
}

{
    package Doit;

    our $VERSION = '0.01';

    sub import {
	warnings->import;
	strict->import;
    }

    sub unimport {
	warnings->unimport;
	strict->unimport;
    }

    use Doit::Log;

    sub _new {
	my $class = shift;
	my $self = bless { }, $class;
	# XXX hmmm, creating now self-refential data structures ...
	$self->{runner}    = Doit::Runner->new($self);
	$self->{dryrunner} = Doit::Runner->new($self, 1);
	$self;
    }
    sub runner    { shift->{runner} }
    sub dryrunner { shift->{dryrunner} }

    sub init {
	my($class) = @_;
	require Getopt::Long;
	Getopt::Long::Configure('pass_through');
	Getopt::Long::GetOptions('dry-run|n' => \my $dry_run);
	Getopt::Long::Configure('no_pass_through'); # XXX or restore old value?
	my $doit = $class->_new;
	if ($dry_run) {
	    $doit->dryrunner;
	} else {
	    $doit->runner;
	}
    }

    sub install_generic_cmd {
	my($self, $name, $check, $code, $msg) = @_;
	if (!$msg) {
	    $msg = sub { my($self, $args) = @_; $name . ($args ? " @$args" : '') };
	}
	my $cmd = sub {
	    my($self, @args) = @_;
	    my @commands;
	    my $addinfo = {};
	    if ($check->($self, \@args, $addinfo)) {
		push @commands, {
				 code => sub { $code->($self, \@args, $addinfo) },
				 msg  => $msg->($self, \@args, $addinfo),
				};
	    }
	    Doit::Commands->new(@commands);
	};
	no strict 'refs';
	*{"cmd_$name"} = $cmd;
    }

    sub _copy_stat {
	my($src, $dest) = @_;
	my @stat = ref $src eq 'ARRAY' ? @$src : stat($src);
	die "Can't stat $src: $!" if !@stat;

	chmod $stat[2], $dest
	    or warn "Can't chmod $dest to " . sprintf("0%o", $stat[2]) . ": $!";
	chown $stat[4], $stat[5], $dest
	    or do {
		my $save_err = $!; # otherwise it's lost in the get... calls
		warn "Can't chown $dest to " .
		    (getpwuid($stat[4]))[0] . "/" .
		    (getgrgid($stat[5]))[0] . ": $save_err";
	    };
	utime $stat[8], $stat[9], $dest
	    or warn "Can't utime $dest to " .
	    scalar(localtime $stat[8]) . "/" .
	    scalar(localtime $stat[9]) .
	    ": $!";
    }

    sub cmd_chmod {
	my($self, $mode, @files) = @_;
	my @files_to_change;
	for my $file (@files) {
	    my @s = stat($file);
	    if (@s) {
		if (($s[2] & 07777) != $mode) {
		    push @files_to_change, $file;
		}
	    }
	}
	my @commands;
	if (@files_to_change) {
	    push @commands, {
			     code => sub { chmod $mode, @files_to_change or die $! },
			     msg  => sprintf "chmod 0%o %s", $mode, join(" ", @files_to_change), # shellquote?
			    };
	}
	Doit::Commands->new(@commands);
    }

    sub cmd_chown {
	my($self, $uid, $gid, @files) = @_;

	if (!defined $uid) {
	    $uid = -1;
	} elsif ($uid !~ /^-?\d+$/) {
	    my $_uid = (getpwnam $uid)[2];
	    if (!defined $_uid) {
		# XXX problem: in dry-run mode the user/group could be
		# created in _this_ pass, so this error would happen
		# while in wet-run everything would be fine. Good solution?
		# * do uid/gid resolution _again_ in the command if it failed here?
		# * maintain a virtual list of created users/groups while this run, and
		#   use this list as a fallback?
		die "User '$uid' does not exist";
	    }
	    $uid = $_uid;
	}
	if (!defined $gid) {
	    $gid = -1;
	} elsif ($gid !~ /^-?\d+$/) {
	    my $_gid = (getpwnam $gid)[2];
	    if (!defined $_gid) {
		die "Group '$gid' does not exist";
	    }
	    $gid = $_gid;
	}

	my @files_to_change;
	if ($uid != -1 || $gid != -1) {
	    for my $file (@files) {
		my @s = stat($file);
		if (@s) {
		    if ($uid != -1 && $s[4] != $uid) {
			push @files_to_change, @files;
		    } elsif ($gid != -1 && $s[5] != $gid) {
			push @files_to_change, @files;
		    }
		}
	    }
	}

	my @commands;
	if (@files_to_change) {
	    push @commands, {
			     code => sub { chown $uid, $gid, @files_to_change or die $! },
			     msg  => "chown $uid, $gid, @files_to_change", # shellquote?
			    };
	}
	
	Doit::Commands->new(@commands);
    }

    sub cmd_cond_run {
	my($self, %opts) = @_;
	my $if      = delete $opts{if};
	my $unless  = delete $opts{unless};
	my $creates = delete $opts{creates};
	my $cmd     = delete $opts{cmd};
	die "Unhandled options: " . join(" ", %opts) if %opts;

	my $doit = 1;
	if ($if && !$if->()) {
	    $doit = 0;
	}
	if ($doit && $unless && $unless->()) {
	    $doit = 0;
	}
	if ($doit && $creates && -e $creates) {
	    $doit = 0;
	}

	if ($doit) {
	    $self->cmd_run(@$cmd);
	} else {
	    Doit::Commands->new();
	}
    }

    sub cmd_make_path {
	my($self, @directories) = @_;
	my $options = {}; if (ref $directories[-1] eq 'HASH') { $options = pop @directories }
	my @directories_to_create = grep { !-d $_ } @directories;
	my @commands;
	if (@directories_to_create) {
	    push @commands, {
			     code => sub {
				 require File::Path;
				 File::Path::make_path(@directories_to_create, $options)
					 or die $!;
			     },
			     msg => "make_path @directories",
			    };
	}
	Doit::Commands->new(@commands);
    }

    sub cmd_mkdir {
	my($self, $directory, $mask) = @_;
	my @commands;
	if (!-d $directory) {
	    if (defined $mask) {
		push @commands, {
				 code => sub { mkdir $directory, $mask or die $! },
				 msg  => "mkdir $directory with mask $mask",
				};
	    } else {
		push @commands, {
				 code => sub { mkdir $directory or die $! },
				 msg  => "mkdir $directory",
				};
	    }
	}
	Doit::Commands->new(@commands);
    }

    sub cmd_remove_tree {
	my($self, @directories) = @_;
	my $options = {}; if (ref $directories[-1] eq 'HASH') { $options = pop @directories }
	my @directories_to_remove = grep { -d $_ } @directories;
	my @commands;
	if (@directories_to_remove) {
	    push @commands, {
			     code => sub {
				 require File::Path;
				 File::Path::remove_tree(@directories_to_remove, $options)
					 or die $!;
			     },
			     msg => "remove_tree @directories_to_remove",
			    };
	}
	Doit::Commands->new(@commands);
    }

    sub cmd_rename {
	my($self, $from, $to) = @_;
	my @commands;
	push @commands, {
			 code => sub { rename $from, $to or die $! },
			 msg  => "rename $from, $to",
			};
	Doit::Commands->new(@commands);
    }

    sub cmd_copy {
	my($self, $from, $to) = @_;
	my @commands;
	my $real_to;
	if (-d $to) {
	    require File::Basename;
	    $real_to = "$to/" . File::Basename::basename($from);
	} else {
	    $real_to = $to;
	}
	if (!-e $real_to || do { require File::Compare; File::Compare::compare($from, $real_to) != 0 }) {
	    push @commands, {
			     code => sub {
				 require File::Copy;
				 File::Copy::copy($from, $to)
					 or die "Copy failed: $!";
			     },
			     msg => do {
				 if (-e $real_to) {
				     my $diff;
				     if (eval { require IPC::Run; 1 }) {
					 IPC::Run::run(['diff', '-u', $to, $from], '>', \$diff);
					 "copy $from $to\ndiff:\n$diff";
				     } else {
					 $diff = `diff -u '$to' '$from'`;
					 "copy $from $to\ndiff:\n$diff";
				     }
				 } else {
				     "copy $from $to (destination does not exist)\n";
				 }
			     },
			     rv => 1,
			    };
	}
	Doit::Commands->new(@commands);
    }

    sub cmd_move {
	my($self, $from, $to) = @_;
	my @commands = {
			code => sub {
			    require File::Copy;
			    File::Copy::move($from, $to)
				    or die "Move failed: $!";
			},
			msg => "move $from $to",
		       };
	Doit::Commands->new(@commands);
    }

    sub cmd_rmdir {
	my($self, $directory) = @_;
	my @commands;
	if (-d $directory) {
	    push @commands, {
			     code => sub { rmdir $directory or die $! },
			     msg  => "rmdir $directory",
			    };
	}
	Doit::Commands->new(@commands);
    }

    sub _handle_dollar_questionmark () {
	if ($? & 127) {
	    my $signalnum = $? & 127;
	    my $coredump = ($? & 128) ? 'with' : 'without';
	    Doit::Exception::throw(
				   sprintf("Command died with signal %d, %s coredump", $signalnum, $coredump),
				   signalnum => $signalnum,
				   coredump  => $coredump,
			          );
	} else {
	    my $exitcode = $?>>8;
	    Doit::Exception::throw(
				   "Command exited with exit code " . $exitcode,
				   exitcode => $exitcode,
			          );
	}
    }

    sub cmd_run {
	my($self, @args) = @_;
	my @commands;
	push @commands, {
			 code => sub {
			     require IPC::Run;
			     my $success = IPC::Run::run(@args);
			     if (!$success) {
				 _handle_dollar_questionmark;
			     }
			 },
			 msg  => do {
			     my @print_cmd;
			     for my $arg (@args) {
				 if (ref $arg eq 'ARRAY') {
				     push @print_cmd, @$arg;
				 } else {
				     push @print_cmd, $arg;
				 }
			     }
			     join " ", @print_cmd;
			 },
			};
	Doit::Commands->new(@commands);
    }

    sub cmd_symlink {
	my($self, $oldfile, $newfile) = @_;
	my $doit;
	if (-l $newfile) {
	    my $points_to = readlink $newfile
		or die "Unexpected: readlink $newfile failed (race condition?)";
	    if ($points_to ne $oldfile) {
		$doit = 1;
	    }
	} elsif (!-e $newfile) {
	    $doit = 1;
	} else {
	    warn "$newfile exists but is not a symlink, will fail later...";
	}
	my @commands;
	if ($doit) {
	    push @commands, {
			     code => sub { symlink $oldfile, $newfile or die $! },
			     msg  => "symlink $oldfile $newfile",
			    };
	}
	Doit::Commands->new(@commands);
    }

    sub cmd_system {
	my($self, @args) = @_;
	my @commands;
	push @commands, {
			 code => sub {
			     system @args;
			     if ($? != 0) {
				 _handle_dollar_questionmark;
			     }
			 },
			 msg  => "@args",
			};
	Doit::Commands->new(@commands);
    }

    sub cmd_touch {
	my($self, @files) = @_;
	my @commands;
	for my $file (@files) {
	    if (!-e $file) {
		push @commands, {
				 code => sub { open my $fh, '>>', $file or die $! },
				 msg  => "touch non-existent file $file",
				}
	    } else {
		push @commands, {
				 code => sub { utime time, time, $file or die $! },
				 msg  => "touch existent file $file",
				};
	    }
	}
	Doit::Commands->new(@commands);
    }

    sub cmd_create_file_if_nonexisting {
	my($self, @files) = @_;
	my @commands;
	for my $file (@files) {
	    if (!-e $file) {
		push @commands, {
		    code => sub { open my $fh, '>>', $file or die $! },
		    msg  => "create empty file $file",
		};
	    }
	}
	Doit::Commands->new(@commands);
    }

    sub cmd_unlink {
	my($self, @files) = @_;
	my @files_to_remove;
	for my $file (@files) {
	    if (-e $file || -l $file) {
		push @files_to_remove, $file;
	    }
	}
	my @commands;
	if (@files_to_remove) {
	    push @commands, {
			     code => sub { unlink @files_to_remove or die $! },
			     msg  => "unlink @files_to_remove", # shellquote?
			    };
	}
	Doit::Commands->new(@commands);
    }

    sub cmd_utime {
	my($self, $atime, $mtime, @files) = @_;
	my $now;
	if (!defined $atime) {
	    $atime = ($now ||= time);
	}
	if (!defined $mtime) {
	    $mtime = ($now ||= time);
	}
	my @commands;
	push @commands, {
			 code => sub { utime $atime, $mtime, @files or die $! },
			 msg  => "utime $atime, $mtime, @files",
			};
	Doit::Commands->new(@commands);
    }

    sub cmd_write_binary {
	my($self, $filename, $content) = @_;

	my $doit;
	my $need_diff;
	if (!-e $filename) {
	    $doit = 1;
	} elsif (-s $filename != length($content)) {
	    $doit = 1;
	    $need_diff = 1;
	} else {
	    open my $fh, '<', $filename
		or die "Can't open $filename: $!";
	    binmode $fh;
	    local $/;
	    my $file_content = <$fh>;
	    if ($file_content ne $content) {
		$doit = 1;
		$need_diff = 1;
	    }
	}

	my @commands;
	if ($doit) {
	    push @commands, {
			     code => sub {
				 open my $ofh, '>', $filename
				     or die "Can't write to $filename: $!";
				 binmode $ofh;
				 print $ofh $content;
				 close $ofh
				     or die "While closing $filename: $!";
			     },
			     msg => do {
				 if ($need_diff) {
				     if (eval { require IPC::Run; 1 }) {
					 my $diff;
					 IPC::Run::run(['diff', '-u', $filename, '-'], '<', \$content, '>', \$diff);
					 "Replace existing file $filename with diff:\n$diff";
				     } else {
					 my $diff;
					 if (eval { require File::Temp; 1 }) {
					     my($tempfh,$tempfile) = File::Temp::tempfile(UNLINK => 1);
					     print $tempfh $content;
					     if (close $tempfh) {
						 $diff = `diff -u '$filename' '$tempfile'`;
						 unlink $tempfile;
					     } else {
						 $diff = "(diff not available, error in tempfile creation ($!))";
					     }
					 } else {
					     $diff = "(diff not available, neither IPC::Run nor File::Temp available)";
					 }
					 "Replace existing file $filename with diff:\n$diff";
				     }
				 } else {
				     "Create new file $filename with content:\n$content";
				 }
			     },
			    };
	}
	Doit::Commands->new(@commands);
    }

    sub cmd_change_file {
	my($self, $file, @changes) = @_;
	if (!-e $file) {
	    die "$file does not exist";
	}
	if (!-f $file) {
	    die "$file is not a file";
	}

	my $debug;
	if (@changes && $changes[0]->{debug}) {
	    $debug = $changes[0]->{debug};
	    shift @changes;
	}

	my @commands;

	for (@changes) {
	    if ($_->{add_if_missing}) {
		my $line = delete $_->{add_if_missing};
		$_->{unless_match} = $line;
		if (defined $_->{add_after}       ||
		    defined $_->{add_after_first} ||
		    defined $_->{add_before}      ||
		    defined $_->{add_before_last}
		   ) {
		    my $defines =
			(defined $_->{add_after}       || 0) +
			(defined $_->{add_after_first} || 0) +
			(defined $_->{add_before}      || 0) +
			(defined $_->{add_before_last} || 0)
			;
		    if ($defines != 1) {
			die "Can specify only one of the following: 'add_after', 'add_after_first', 'add_before', 'add_before_last' (change for $file)\n";
		    }
		    my $add;
		    my $do_after;
		    my $reverse;
		    if (defined $_->{add_after}) {
			$add = delete $_->{add_after};
			$reverse = 1;
			$do_after = 1;
		    } elsif (defined $_->{add_after_first}) {
			$add = delete $_->{add_after_first};
			$reverse = 0;
			$do_after = 1;
		    } elsif (defined $_->{add_before}) {
			$add = delete $_->{add_before};
			$reverse = 0;
			$do_after = 0;
		    } elsif (defined $_->{add_before_last}) {
			$add = delete $_->{add_before_last};
			$reverse = 1;
			$do_after = 0;
		    } else {
			die "Can never happen";
		    }
		    qr{$add}; # must be a regexp
		    $_->{action} = sub {
			my $arrayref = $_[0];
			my $found = 0;
			my $from = $reverse ? $#$arrayref : 0;
			my $to   = $reverse ? 0 : $#$arrayref;
			my $inc  = $reverse ? -1 : +1;
			for(my $i=$from; ($reverse ? $i>=$to : $i<=$to); $i+=$inc) {
			    if ($arrayref->[$i] =~ $add) {
				if ($do_after) {
				    splice @$arrayref, $i+1, 0, $line;
				} else {
				    splice @$arrayref, $i, 0, $line;
				}
				$found = 1;
				last;
			    }
			}
			if (!$found) {
			    die "Cannot find '$add' in file";
			}
		    };
		} else {
		    $_->{action} = sub { my $arrayref = $_[0]; push @$arrayref, $line };
		}
	    }
	}

	my @match_actions;
	my @unless_match_actions;
	for (@changes) {
	    if ($_->{unless_match}) {
		if (ref $_->{unless_match} ne 'Regexp') {
		    my $rx = '^' . quotemeta($_->{unless_match}) . '$';
		    $_->{unless_match} = qr{$rx};
		}
		if (!$_->{action}) {
		    die "action is missing";
		}
		if (ref $_->{action} ne 'CODE') {
		    die "action must be a sub reference";
		}
		push @unless_match_actions, $_;
	    } elsif ($_->{match}) {
		if (ref $_->{match} ne 'Regexp') {
		    die "match must be a regexp";
		}
		if ($_->{action}) {
		    if (ref $_->{action} ne 'CODE') {
			die "action must be a sub reference";
		    }
		} elsif (defined $_->{replace}) {
		    # accept
		} else {
		    die "action or replace is missing";
		}
		push @match_actions, $_;
	    } else {
		die "match or unless_match is missing";
	    }
	}

	require File::Temp;
	require File::Basename;
	require File::Copy;
	my($tmfh,$tmpfile) = File::Temp::tempfile('doittemp_XXXXXXXX', UNLINK => 1, DIR => File::Basename::dirname($file));
	File::Copy::copy($file, $tmpfile)
		or die "failed to copy $file to temporary file $tmpfile: $!";
	_copy_stat $file, $tmpfile;

	require Tie::File;
	tie my @lines, 'Tie::File', $tmpfile
	    or die "cannot tie file $file: $!";

	my $no_of_changes = 0;
	for my $match_action (@match_actions) {
	    my $match  = $match_action->{match};
	    for my $line (@lines) {
		if ($debug) { info "change_file check '$line' =~ '$match'" }
		if ($line =~ $match) {
		    if (exists $match_action->{replace}) {
			my $replace = $match_action->{replace};
			if ($line ne $replace) {
			    push @commands, { msg => "replace '$line' with '$replace' in '$file'" };
			    $line = $replace;
			    $no_of_changes++;
			}
		    } else {
			push @commands, { msg => "matched '$match' on line '$line' in '$file' -> execute action" };
			my $action = $match_action->{action};
			$action->($line);
			$no_of_changes++;
		    }
		}
	    }
	}
    ITER: for my $unless_match_action (@unless_match_actions) {
	    my $match  = $unless_match_action->{unless_match};
	    for my $line (@lines) {
		if ($line =~ $match) {
		    next ITER;
		}
	    }
	    push @commands, { msg => "did not find '$match' in '$file' -> execute action" };
	    my $action = $unless_match_action->{action};
	    $action->(\@lines);
	    $no_of_changes++;
	}

	untie @lines;

	if ($no_of_changes) {
	    push @commands, {
			     code => sub {
				 rename $tmpfile, $file
				     or die "Can't rename $tmpfile to $file: $!";
			     },
			     msg => do {
				 my $diff;
				 if (eval { require IPC::Run; 1 }) {
				     IPC::Run::run(['diff', '-u', $file, $tmpfile], '>', \$diff);
				 } else {
				     $diff = `diff -u '$file' '$tmpfile'`;
				 }
				 "Final changes as diff:\n$diff";
			     },
			     rv => $no_of_changes,
			    };
	} else {
	    # Dummy command, just to set return value to 0 (otherwise it would be undef)
	    push @commands, {
			     code => sub {},
			     rv => 0,
			    };
	}

	Doit::Commands->new(@commands);
    }

}

{
    package Doit::Commands;
    sub new {
	my($class, @commands) = @_;
	my $self = bless \@commands, $class;
	$self;
    }
    sub commands { @{$_[0]} }
    sub doit {
	my($self) = @_;
	my $rv;
	for my $command ($self->commands) {
	    if (exists $command->{msg}) {
		Doit::Log::info($command->{msg});
	    }
	    if (exists $command->{code}) {
		my $this_rv = $command->{code}->();
		if (exists $command->{rv}) {
		    $rv = $command->{rv};
		} else {
		    $rv = $this_rv;
		}
	    }
	}
	$rv;
    }
    sub show {
	my($self) = @_;
	my $rv;
	for my $command ($self->commands) {
	    if (exists $command->{msg}) {
		Doit::Log::info($command->{msg} . " (dry-run)");
	    }
	    if (exists $command->{code}) {
		if (exists $command->{rv}) {
		    $rv = $command->{rv};
		} else {
		    # Well, in dry-run mode we have no real return value...
		}
	    }
	}
	$rv;
    }
}

{
    package Doit::Runner;
    sub new {
	my($class, $X, $dryrun) = @_;
	bless { X => $X, dryrun => $dryrun, components => [] }, $class;
    }
    sub is_dry_run { shift->{dryrun} }

    sub can_ipc_run { eval { require IPC::Run; 1 } }

    sub install_generic_cmd {
	my($self, $name, @args) = @_;
	$self->{X}->install_generic_cmd($name, @args);
	install_cmd($name); # XXX hmmmm
    }

    sub install_cmd ($) {
	my $cmd = shift;
	my $meth = 'cmd_' . $cmd;
	my $code = sub {
	    my($self, @args) = @_;
	    if ($self->{dryrun}) {
		$self->{X}->$meth(@args)->show;
	    } else {
		$self->{X}->$meth(@args)->doit;
	    }
	};
	no strict 'refs';
	*{$cmd} = $code;
    }

    sub add_component {
	my($self, $component) = @_;
	for (@{ $self->{components} }) {
	    return if $_->{component} eq $component;
	}

	my $module = 'Doit::' . ucfirst($component);
	if (!eval qq{ require $module; 1 }) {
	    die "Cannot load $module: $@";
	}
	my $o = $module->new
	    or die "Error while calling $module->new";
	for my $function ($o->functions) {
	    my $fullqual = $module.'::'.$function;
	    my $code = sub {
		my($self, @args) = @_;
		$self->$fullqual(@args);
	    };
	    no strict 'refs';
	    *{$function} = $code;
	}
	my $mod_file = do {
	    (my $relpath = $module) =~ s{::}{/};
	    $relpath .= '.pm';
	};
	push @{ $self->{components} }, { component => $component, module => $module, path => $INC{$mod_file}, relpath => $mod_file };

	if ($o->can('add_components')) {
	    for my $sub_component ($o->add_components) {
		$self->add_component($sub_component);
	    }
	}
    }

    for my $cmd (
		 qw(chmod chown mkdir rename rmdir symlink system unlink utime),
		 qw(make_path remove_tree), # File::Path
		 qw(copy move), # File::Copy
		 qw(run), # IPC::Run
		 qw(cond_run), # conditional run
		 qw(touch), # like unix touch
		 qw(create_file_if_nonexisting), # does the half of touch
		 qw(write_binary), # like File::Slurper
		 qw(change_file), # own invention
		) {
	install_cmd $cmd;
    }

    sub call_wrapped_method {
	my($self, $context, $method, @args) = @_;
	my @ret;
	if ($context eq 'a') {
	    @ret    = eval { $self->$method(@args) };
	} else {
	    $ret[0] = eval { $self->$method(@args) };
	}
	if ($@) {
	    ('e', $@);
	} else {
	    ('r', @ret);
	}
    }

    # XXX call vs. call_with_runner ???
    sub call {
	my($self, $sub, @args) = @_;
	$sub = 'main::' . $sub if $sub !~ /::/;
	no strict 'refs';
	&$sub(@args);
    }

    sub call_with_runner {
	my($self, $sub, @args) = @_;
	$sub = 'main::' . $sub if $sub !~ /::/;
	no strict 'refs';
	&$sub($self, @args);
    }

    # XXX does this belong here?
    sub do_ssh_connect {
	my($self, $host, %opts) = @_;
	my $remote = Doit::SSH->do_connect($host, dry_run => $self->is_dry_run, components => $self->{components}, %opts);
	$remote;
    }

    # XXX does this belong here?
    sub do_sudo {
	my($self, %opts) = @_;
	my $sudo = Doit::Sudo->do_connect(dry_run => $self->is_dry_run, components => $self->{components}, %opts);
	$sudo;
    }
}

{
    package Doit::RPC;

    require Storable;
    require IO::Handle;

    use Doit::Log;

    sub new {
	die "Please use either Doit::RPC::Client, Doit::RPC::Server or Doit::RPC::SimpleServer";
    }

    sub receive_data {
	my($self) = @_;
	my $fh = $self->{infh};
	my $buf;
	my $ret = read $fh, $buf, 4;
	if (!defined $ret) {
	    die "receive_data failed (getting length): $!";
	} elsif (!$ret) {
	    return; # eof
	}
	my $length = unpack("N", $buf);
	read $fh, $buf, $length or die "receive_data failed (getting data): $!";
	@{ Storable::thaw($buf) };
    }

    sub send_data {
	my($self, @cmd) = @_;
	my $fh = $self->{outfh};
	my $data = Storable::nfreeze(\@cmd);
	print $fh pack("N", length($data)) . $data;
    }

    {
	my $done_POSIX_warning;
	sub _reap_process {
	    my($self, $pid) = @_;
	    return if !defined $pid;
	    if (eval { require POSIX; defined &POSIX::WNOHANG }) {
		if ($self->{debug}) {
		    info "Reaping process $pid...";
		}
		my $got_pid = waitpid $pid, &POSIX::WNOHANG;
		if (!$got_pid) {
		    warning "Could not reap process $pid...";
		}
	    } else {
		if (!$done_POSIX_warning++) {
		    warning "Can't require POSIX, cannot reap zombies..."
		}
	    }
	}
    }

}

{
    package Doit::RPC::Client;
    use vars '@ISA'; @ISA = ('Doit::RPC');

    sub new {
	my($class, $infh, $outfh, %options) = @_;

	my $debug = delete $options{debug};
	my $label = delete $options{label};
	die "Unhandled options: " . join(" ", %options) if %options;

	$outfh->autoflush(1);
	bless {
	       infh  => $infh,
	       outfh => $outfh,
	       label => $label,
	       debug => $debug,
	      }, $class;
    }

    # Call for every command on client
    sub call_remote {
	my($self, @args) = @_;
	my $context = wantarray ? 'a' : 's'; # XXX more possible context (void...)?
	$self->send_data($context, @args);
	my($rettype, @ret) = $self->receive_data(@args);
	if (defined $rettype && $rettype eq 'e') {
	    die $ret[0];
	} elsif (defined $rettype && $rettype eq 'r') {
	    if ($context eq 'a') {
		return @ret;
	    } else {
		return $ret[0];
	    }
	} else {
	    die "Unexpected return type " . (defined $self->{label} ? "in connection '$self->{label}' " : "") . (defined $rettype ? "'$rettype'" : "<undefined>") . " (should be 'e' or 'r')";
	}
    }
}

{
    package Doit::RPC::Server;
    use vars '@ISA'; @ISA = ('Doit::RPC');

    sub new {
	my($class, $runner, $sockpath, %options) = @_;

	my $debug = delete $options{debug};
	die "Unhandled options: " . join(" ", %options) if %options;

	bless {
	       runner   => $runner,
	       sockpath => $sockpath,
	       debug    => $debug,
	      }, $class;
    }

    sub run {
	my($self) = @_;

	require IO::Socket::UNIX;
	IO::Socket::UNIX->VERSION('1.18'); # autoflush
	IO::Socket::UNIX->import(qw(SOCK_STREAM));
	use IO::Select;

	my $d;
	if ($self->{debug}) {
	    $d = sub ($) {
		Doit::Log::info("WORKER: $_[0]");
	    };
	} else {
	    $d = sub ($) { };
	}

	$d->("Start worker ($$)...");
	my $sockpath = $self->{sockpath};
	if (-e $sockpath) {
	    $d->("unlink socket $sockpath");
	    unlink $sockpath;
	}
	my $sock = IO::Socket::UNIX->new(
					 Type  => SOCK_STREAM(),
					 Local => $sockpath,
					 Listen => 1,
					) or die "WORKER: Can't create socket: $!";
	$d->("socket was created");

	my $sel = IO::Select->new($sock);
	$d->("waiting for client");
	my @ready = $sel->can_read();
	die "WORKER: unexpected filehandle @ready" if $ready[0] != $sock;
	$d->("accept socket");
	my $fh = $sock->accept;
	$self->{infh} = $self->{outfh} = $fh;
	while () {
	    $d->(" waiting for line from comm");
	    my($context, @data) = $self->receive_data;
	    if (!defined $context) {
		$d->(" got eof");
		$fh->close;
		return;
	    } elsif ($data[0] =~ m{^exit$}) {
		$d->(" got exit command");
		$self->send_data('r', 'bye-bye');
		$fh->close;
		return;
	    }
	    $d->(" calling method $data[0]");
	    my($rettype, @ret) = $self->{runner}->call_wrapped_method($context, @data);
	    $d->(" sending result back");
	    $self->send_data($rettype, @ret);
	}
    }

}

{
    package Doit::RPC::SimpleServer;
    use vars '@ISA'; @ISA = ('Doit::RPC');
    
    sub new {
	my($class, $runner, $infh, $outfh, %options) = @_;
	my $debug = delete $options{debug};
	die "Unhandled options: " . join(" ", %options) if %options;

	$infh  = \*STDIN if !$infh;
	$outfh = \*STDOUT if !$outfh;
	$outfh->autoflush(1);
	bless {
	       runner => $runner,
	       infh   => $infh,
	       outfh  => $outfh,
	       debug  => $debug,
	      }, $class;
    }

    sub run {
	my $self = shift;
	while() {
	    my($context, @data) = $self->receive_data;
	    if (!defined $context) {
		return;
	    } elsif ($data[0] =~ m{^exit$}) {
		$self->send_data('r', 'bye-bye');
		return;
	    }
	    open my $oldout, ">&STDOUT" or die $!;
	    open STDOUT, '>', "/dev/stderr" or die $!; # XXX????
	    my($rettype, @ret) = $self->{runner}->call_wrapped_method($context, @data);
	    open STDOUT, ">&", $oldout or die $!;
	    $self->send_data($rettype, @ret);
	}
    }
}

{
    package Doit::_AnyRPCImpl;
    sub call_remote {
	my($self, @args) = @_;
	$self->{rpc}->call_remote(@args);
    }

    use vars '$AUTOLOAD';
    sub AUTOLOAD {
	(my $method = $AUTOLOAD) =~ s{.*::}{};
	my $self = shift;
	$self->call_remote($method, @_); # XXX or use goto?
    }

}

{
    package Doit::_ScriptTools;

    sub add_components {
	my(@components) = @_;
	q|for my $component (qw(| . join(" ", map { qq{$_->{component}} } @components) . q|)) { $d->add_component($component) } |;
    }

    sub self_require {
	if ($0 ne '-e') { # not a oneliner
	    q{require "} . File::Basename::basename($0) . q{"; };
	} else {
	    q{use Doit; };
	}
    }
}

{
    package Doit::Sudo;

    use vars '@ISA'; @ISA = ('Doit::_AnyRPCImpl');

    sub do_connect {
	my($class, %opts) = @_;
	my @sudo_opts = @{ delete $opts{sudo_opts} || [] };
	my $dry_run = delete $opts{dry_run};
	my $debug = delete $opts{debug};
	my @components = @{ delete $opts{components} || [] };
	die "Unhandled options: " . join(" ", %opts) if %opts;

	my $self = bless { }, $class;

	require File::Basename;
	require IPC::Open2;
	require Symbol;
	#my @cmd = ('sudo', @sudo_opts, $^X, "-I".File::Basename::dirname(__FILE__), "-I".File::Basename::dirname($0), "-e", q{require "} . File::Basename::basename($0) . q{"; Doit::RPC::SimpleServer->new(Doit->init)->run();}, "--", ($dry_run? "--dry-run" : ()));
	#my($in, $out) = (Symbol::gensym(), Symbol::gensym());
	my @cmd_worker =
	    (
	     'sudo', @sudo_opts, $^X, "-I".File::Basename::dirname(__FILE__), "-I".File::Basename::dirname($0), "-e",
	     Doit::_ScriptTools::self_require() .
	     q{my $d = Doit->init; } .
	     Doit::_ScriptTools::add_components(@components) .
	     q{Doit::RPC::Server->new($d, "/tmp/.doit.sudo.$<.sock", debug => } . ($debug?1:0) . q{)->run();},
	     "--", ($dry_run? "--dry-run" : ())
	    );
	my $worker_pid = fork;
	if (!defined $worker_pid) {
	    die "fork failed: $!";
	} elsif ($worker_pid == 0) {
	    warn "worker perl cmd: @cmd_worker\n" if $debug;
	    exec @cmd_worker;
	    die "Failed to run '@cmd_worker': $!";
	}
	my($in, $out);
	my @cmd_comm = ('sudo', @sudo_opts, $^X, "-I".File::Basename::dirname(__FILE__), "-MDoit", "-e", q{Doit::Comm->comm_to_sock("/tmp/.doit.sudo.$<.sock", debug => shift)}, !!$debug);
	warn "comm perl cmd: @cmd_comm\n" if $debug;
	my $comm_pid = IPC::Open2::open2($out, $in, @cmd_comm);
	$self->{rpc} = Doit::RPC::Client->new($out, $in, label => "sudo:");
	$self;
    }

    sub DESTROY { }

}

{
    package Doit::SSH;

    use vars '@ISA'; @ISA = ('Doit::_AnyRPCImpl');

    use Doit::Log;

    sub do_connect {
	require File::Basename;
	require Net::OpenSSH;
	my($class, $host, %opts) = @_;
	my $dry_run = delete $opts{dry_run};
	my @components = @{ delete $opts{components} || [] };
	my $debug = delete $opts{debug};
	my $as = delete $opts{as};
	my $forward_agent = delete $opts{forward_agent};
	my $tty = delete $opts{tty};
	my $port = delete $opts{port};
	my $master_opts = delete $opts{master_opts};
	die "Unhandled options: " . join(" ", %opts) if %opts;

	my $self = bless { host => $host, debug => $debug }, $class;
	my %ssh_run_opts = (
	    ($forward_agent ? (forward_agent => $forward_agent) : ()),
	    ($tty           ? (tty           => $tty)           : ()),
	);
	my %ssh_new_opts = (
	    ($forward_agent ? (forward_agent => $forward_agent) : ()),
	    ($master_opts   ? (master_opts   => $master_opts)   : ()),
	);
	my $ssh = Net::OpenSSH->new($host, %ssh_new_opts);
	$ssh->error and die "Connection error to $host: " . $ssh->error;
	$self->{ssh} = $ssh;
	{
	    my $remote_cmd = "[ ! -d .doit/lib ] && mkdir -p .doit/lib";
	    if ($debug) {
		info "Running '$remote_cmd' on remote";
	    }
	    $ssh->system(\%ssh_run_opts, $remote_cmd);
	}
	if ($0 ne '-e') {
	    $ssh->rsync_put({verbose => $debug}, $0, ".doit/"); # XXX verbose?
	}
	$ssh->rsync_put({verbose => $debug}, __FILE__, ".doit/lib/");
	{
	    my %seen_dir;
	    for my $component (@components) {
		my $from = $component->{path};
		my $to = $component->{relpath};
		my $full_target = ".doit/lib/$to";
		my $target_dir = File::Basename::dirname($full_target);
		if (!$seen_dir{$target_dir}) {
		    $ssh->system(\%ssh_run_opts, "[ ! -d $target_dir ] && mkdir -p $target_dir");
		    $seen_dir{$target_dir} = 1;
		}
		$ssh->rsync_put({verbose => $debug}, $from, $full_target);
	    }
	}
	my @cmd;
	if (defined $as) {
	    if ($as eq 'root') {
		@cmd = ('sudo');
	    } else {
		@cmd = ('sudo', '-u', $as);
	    }
	} # XXX add ssh option -t? for password input?
	if (0) {
	    push @cmd, ("perl", "-I.doit", "-I.doit/lib", "-e", q{require "} . File::Basename::basename($0) . q{"; Doit::RPC::SimpleServer->new(Doit->init)->run();}, "--", ($dry_run? "--dry-run" : ()));
	    warn "remote perl cmd: @cmd\n" if $debug;
	    my($out, $in, $pid) = $ssh->open2(\%ssh_run_opts, @cmd);
	    $self->{rpc} = Doit::RPC::Client->new($in, $out);
	} else {
	    # XXX better path for sock!
	    my @cmd_worker =
		(
		 @cmd, "perl", "-I.doit", "-I.doit/lib", "-e",
		 Doit::_ScriptTools::self_require() .
		 q{my $d = Doit->init; } .
		 Doit::_ScriptTools::add_components(@components) .
		 q{Doit::RPC::Server->new($d, "/tmp/.doit.$<.sock", debug => } . ($debug?1:0).q{)->run();},
		 "--", ($dry_run? "--dry-run" : ())
		);
	    warn "remote perl cmd: @cmd_worker\n" if $debug;
	    my $worker_pid = $ssh->spawn(\%ssh_run_opts, @cmd_worker); # XXX what to do with worker pid?
	    $self->{worker_pid} = $worker_pid;
	    my @cmd_comm = (@cmd, "perl", "-I.doit/lib", "-MDoit", "-e", q{Doit::Comm->comm_to_sock("/tmp/.doit.$<.sock", debug => shift)}, !!$debug);
	    warn "comm perl cmd: @cmd_comm\n" if $debug;
	    my($out, $in, $comm_pid) = $ssh->open2(@cmd_comm);
	    $self->{comm_pid} = $comm_pid;
	    $self->{rpc} = Doit::RPC::Client->new($in, $out, label => "ssh:$host");
	}
	$self;
    }

    sub ssh { $_[0]->{ssh} }

    sub DESTROY {
	my $self = shift;
	if ($self->{ssh}) {
	    delete $self->{ssh};
	}
	if ($self->{rpc}) {
	    $self->{rpc}->_reap_process($self->{comm_pid});
	    $self->{rpc}->_reap_process($self->{worker_pid});
	}
    }

}

{
    package Doit::Comm;

    sub comm_to_sock {
	my(undef, $peer, %options) = @_;
	die "Please specify path to unix domain socket" if !defined $peer;
	my $debug = delete $options{debug};
	die "Unhandled options: " . join(" ", %options) if %options;

	my $infh = \*STDIN;
	my $outfh = \*STDOUT;

	require IO::Socket::UNIX;
	IO::Socket::UNIX->VERSION('1.18'); # autoflush
	IO::Socket::UNIX->import(qw(SOCK_STREAM));

	my $d;
	if ($debug) {
	    $d = sub ($) {
		Doit::Log::info("COMM: $_[0]");
	    };
	} else {
	    $d = sub ($) { };
	}

	$d->("Start communication process (pid $$)...");

	my $tries = 20;
	my $sock;
	{
	    my $sleep;
	    for my $try (1..$tries) {
		$sock = IO::Socket::UNIX->new(
					      Type => SOCK_STREAM(),
					      Peer => $peer,
					     );
		last if $sock;
		if (eval { require Time::HiRes; 1 }) {
		    $sleep = \&Time::HiRes::sleep;
		} else {
		    $sleep = sub { sleep $_[0] };
		}
		my $seconds = $try < 10 && defined &Time::HiRes::sleep ? 0.1 : 1;
		$d->("can't connect, sleep for $seconds seconds");
		$sleep->($seconds);
	    }
	}
	if (!$sock) {
	    die "COMM: Can't connect to socket (after $tries retries): $!";
	}
	$d->("socket to worker was created");

	my $get_and_send = sub ($$$$) {
	    my($infh, $outfh, $inname, $outname) = @_;

	    my $length_buf;
	    read $infh, $length_buf, 4 or die "COMM: reading data from $inname failed (getting length): $!";
	    my $length = unpack("N", $length_buf);
	    $d->("starting getting data from $inname, length is $length");
	    my $buf = '';
	    while (1) {
		my $got = read($infh, $buf, $length, length($buf));
		last if $got == $length;
		die "COMM: Unexpected error $got > $length" if $got > $length;
		$length -= $got;
	    }
	    $d->("finished reading data from $inname");

	    print $outfh $length_buf;
	    print $outfh $buf;
	    $d->("finished sending data to $outname");
	};

	$outfh->autoflush(1);
	$d->("about to enter loop");
	while () {
	    $d->("seen eof from local"), last if eof($infh);
	    $get_and_send->($infh, $sock, "local", "worker");
	    $get_and_send->($sock, $outfh, "worker", "local");
	}
	$d->("exited loop");
    }

}

1;

__END__
