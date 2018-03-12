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

use strict;
use warnings;

{
    package Doit;
    our $VERSION = '0.025_53';

    use constant IS_WIN => $^O eq 'MSWin32';
}

{
    package Doit::Log;

    sub _use_coloring {
	no warnings 'redefine';
	*colored_error = sub ($) { Term::ANSIColor::colored($_[0], 'red on_black')};
	*colored_info  = sub ($) { Term::ANSIColor::colored($_[0], 'green on_black')};
    }
    sub _no_coloring {
	no warnings 'redefine';
	*colored_error = *colored_info = sub ($) { $_[0] };
    }
    {
	my $can_coloring;
	sub _can_coloring {
	    return $can_coloring if defined $can_coloring;
	    # XXX What needs to be done to get coloring on Windows?
	    # XXX Probably should also check if the terminal is ANSI-capable at all
	    # XXX Probably should not use coloring on non-terminals (but
	    #     there could be a --color option like in git to force it)
	    $can_coloring = !Doit::IS_WIN && eval { require Term::ANSIColor; 1 } ? 1 : 0;
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
    our @EXPORT; BEGIN { @EXPORT = qw(info warning error) }

    BEGIN { $INC{'Doit/Log.pm'} = __FILE__ } # XXX hack

    my $current_label = '';

    sub info ($)    { print STDERR colored_info("INFO$current_label:"), " ", $_[0], "\n" }
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
	my $level = delete $opts{__level} || 'auto';
	if ($level eq 'auto') {
	    my $_level = 0;
	    while() {
		my @stackinfo = caller($_level);
		if (!@stackinfo) {
		    $level = $_level - 1;
		    last;
		}
		if ($stackinfo[1] !~ m{([/\\]|^)Doit\.pm$}) {
		    $level = $_level;
		    last;
		}
		$_level++;
	    }
	}
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
    package Doit::ScopeCleanups;
    $INC{'Doit/ScopeCleanups.pm'} = __FILE__; # XXX hack
    use Doit::Log;

    sub new {
	my($class) = @_;
	bless [], $class;
    }

    sub add_scope_cleanup {
	my($self, $code) = @_;
	push @$self, { code => $code };
    }

    sub DESTROY {
	my $self = shift;
	for my $scope_cleanup (@$self) {
	    my($code) = $scope_cleanup->{code};
	    if ($] >= 5.014) {
		eval {
		    $code->();
		};
		if ($@) {
		    # error() will give visual feedback about the problem,
		    # die() would be left unnoticed. Note that
		    # an exception in a DESTROY block is not fatal,
		    # and can be only detected by inspecting $@.
		    error "Scope cleanup failed: $@";
		}
	    } else {
		# And eval {} in older perl versions would
		# clobber an outside $@. See
		# perldoc perl5140delta, "Exception Handling"
		$code->();
	    }
	}
    }
}

{
    package Doit::Util;
    use Exporter 'import';
    our @EXPORT; BEGIN { @EXPORT = qw(in_directory new_scope_cleanup copy_stat get_sudo_cmd) }
    $INC{'Doit/Util.pm'} = __FILE__; # XXX hack
    use Doit::Log;

    sub new_scope_cleanup (&) {
	my($code) = @_;
	my $sc = Doit::ScopeCleanups->new;
	$sc->add_scope_cleanup($code);
	$sc;
    }

    sub in_directory (&$) {
	my($code, $dir) = @_;
	my $scope_cleanup;
	if (defined $dir) {
	    require Cwd;
	    my $pwd = Cwd::getcwd();
	    if (!defined $pwd || $pwd eq '') { # XS variant returns undef, PP variant returns '' --- see https://rt.perl.org/Ticket/Display.html?id=132648
		warning "No known current working directory";
	    } else {
		$scope_cleanup = new_scope_cleanup
		    (sub {
			 chdir $pwd or error "Can't chdir to $pwd: $!";
		     });
	    }
	    chdir $dir
		or error "Can't chdir to $dir: $!";
	}
	$code->();
    }

    # $src may be a source file or an arrayref with stat information
    sub copy_stat ($$;@) {
	my($src, $dest, %preserve) = @_;
	my @stat = ref $src eq 'ARRAY' ? @$src : stat($src);
	error "Can't stat $src: $!" if !@stat;

	my $preserve_default   = !%preserve;
	my $preserve_ownership = exists $preserve{ownership} ? delete $preserve{ownership} : $preserve_default;
	my $preserve_mode      = exists $preserve{mode}      ? delete $preserve{mode}      : $preserve_default;
	my $preserve_time      = exists $preserve{time}      ? delete $preserve{time}      : $preserve_default;

	error "Unhandled preserve values: " . join(" ", %preserve) if %preserve;

	if ($preserve_mode) {
	    chmod $stat[2], $dest
		or warning "Can't chmod $dest to " . sprintf("0%o", $stat[2]) . ": $!";
	}
	if ($preserve_ownership) {
	    chown $stat[4], $stat[5], $dest
		or do {
		    my $save_err = $!; # otherwise it's lost in the get... calls
		    warning "Can't chown $dest to " .
			(getpwuid($stat[4]))[0] . "/" .
			(getgrgid($stat[5]))[0] . ": $save_err";
		};
	}
	if ($preserve_time) {
	    utime $stat[8], $stat[9], $dest
		or warning "Can't utime $dest to " .
		scalar(localtime $stat[8]) . "/" .
		scalar(localtime $stat[9]) .
		": $!";
	}
    }

    sub get_sudo_cmd () {
	return () if $> == 0;
	return ('sudo');
    }

}

{
    package Doit::Win32Util;

    # Taken from http://blogs.perl.org/users/graham_knop/2011/12/using-system-or-exec-safely-on-windows.html
    sub win32_quote_list {
	my (@args) = @_;

	my $args = join ' ', map { _quote_literal($_) } @args;

	if (_has_shell_metachars($args)) {
	    # cmd.exe treats quotes differently from standard
	    # argument parsing. just escape everything using ^.
	    $args =~ s/([()%!^"<>&|])/^$1/g;
	}
	return $args;
    }

    sub _quote_literal {
	my ($text) = @_;

	# basic argument quoting.  uses backslashes and quotes to escape
	# everything.
	#
	# The original code had a \v here, but this is not supported
	# in perl5.8. Also, \v probably matches too many characters here
	# --- restrict to the ones < 0x100
	if ($text ne '' && $text !~ /[ \t\n\x0a\x0b\x0c\x0d\x85"]/) {
	    # no quoting needed
	} else {
	    my @text = split '', $text;
	    $text = q{"};
	    for (my $i = 0; ; $i++) {
		my $bs_count = 0;
		while ( $i < @text && $text[$i] eq "\\" ) {
		    $i++;
		    $bs_count++;
		}
		if ($i > $#text) {
		    $text .= "\\" x ($bs_count * 2);
		    last;
		} elsif ($text[$i] eq q{"}) {
		    $text .= "\\" x ($bs_count * 2 + 1);
		} else {
		    $text .= "\\" x $bs_count;
		}
		$text .= $text[$i];
	    }
	    $text .= q{"};
	}

	return $text;
    }

    # direct port of code from win32.c
    sub _has_shell_metachars {
	my $string = shift;
	my $inquote = 0;
	my $quote = '';

	my @string = split '', $string;
	for my $char (@string) {
	    if ($char eq q{%}) {
		return 1;
	    } elsif ($char eq q{'} || $char eq q{"}) {
		if ($inquote) {
		    if ($char eq $quote) {
			$inquote = 0;
			$quote = '';
		    }
		} else {
		    $quote = $char;
		    $inquote++;
		}
	    } elsif ($char eq q{<} || $char eq q{>} || $char eq q{|}) {
		if ( ! $inquote) {
		    return 1;
		}
	    }
	}
	return;
    }
}

{
    package Doit;

    sub import {
	warnings->import;
	strict->import;
    }

    sub unimport {
	warnings->unimport;
	strict->unimport;
    }

    use Doit::Log;

    my $diff_error_shown;

    sub _new {
	my $class = shift;
	my $self = bless { }, $class;
	$self;
    }
    sub runner {
	my($self) = @_;
	# XXX hmmm, creating now self-refential data structures ...
	$self->{runner} ||= Doit::Runner->new($self);
    }
	    
    sub dryrunner {
	my($self) = @_;
	# XXX hmmm, creating now self-refential data structures ...
	$self->{dryrunner} ||= Doit::Runner->new($self, dryrun => 1);
    }

    sub init {
	my($class) = @_;
	require Getopt::Long;
	my $getopt = Getopt::Long::Parser->new;
	$getopt->configure(qw(pass_through noauto_abbrev));
	$getopt->getoptions(
			    'dry-run|n' => \my $dry_run,
			   );
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

    sub cmd_chmod {
	my($self, @args) = @_;
	my %options; if (@args && ref $args[0] eq 'HASH') { %options = %{ shift @args } }
	my $quiet = delete $options{quiet};
	error "Unhandled options: " . join(" ", %options) if %options;
	my($mode, @files) = @args;
	my @files_to_change;
	for my $file (@files) {
	    my @s = stat($file);
	    if (@s) {
		if (($s[2] & 07777) != $mode) {
		    push @files_to_change, $file;
		}
	    } else {
		push @files_to_change, $file;
	    }
	}
	if (@files_to_change) {
	    my @commands =  {
			     code => sub {
				 my $changed_files = chmod $mode, @files_to_change;
				 if ($changed_files != @files_to_change) {
				     if (@files_to_change == 1) {
					 error "chmod failed: $!";
				     } elsif ($changed_files == 0) {
					 error "chmod failed on all files: $!";
				     } else {
					 error "chmod failed on some files (" . (@files_to_change-$changed_files) . "/" . scalar(@files_to_change) . "): $!";
				     }
				 }
			     },
			     ($quiet ? () : (msg => sprintf("chmod 0%o %s", $mode, join(" ", @files_to_change)))), # shellquote?
			     rv   => scalar @files_to_change,
			    };
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_chown {
	my($self, @args) = @_;
	my %options; if (@args && ref $args[0] eq 'HASH') { %options = %{ shift @args } }
	my $quiet = delete $options{quiet};
	error "Unhandled options: " . join(" ", %options) if %options;
	my($uid, $gid, @files) = @args;

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
		error "User '$uid' does not exist";
	    }
	    $uid = $_uid;
	}
	if (!defined $gid) {
	    $gid = -1;
	} elsif ($gid !~ /^-?\d+$/) {
	    my $_gid = (getgrnam $gid)[2];
	    if (!defined $_gid) {
		error "Group '$gid' does not exist";
	    }
	    $gid = $_gid;
	}

	my @files_to_change;
	if ($uid != -1 || $gid != -1) {
	    for my $file (@files) {
		my @s = stat($file);
		if (@s) {
		    if ($uid != -1 && $s[4] != $uid) {
			push @files_to_change, $file;
		    } elsif ($gid != -1 && $s[5] != $gid) {
			push @files_to_change, $file;
		    }
		} else {
		    push @files_to_change, $file;
		}
	    }
	}

	if (@files_to_change) {
	    my @commands =  {
			     code => sub {
				 my $changed_files = chown $uid, $gid, @files_to_change;
				 if ($changed_files != @files_to_change) {
				     if (@files_to_change == 1) {
					 error "chown failed: $!";
				     } elsif ($changed_files == 0) {
					 error "chown failed on all files: $!";
				     } else {
					 error "chown failed on some files (" . (@files_to_change-$changed_files) . "/" . scalar(@files_to_change) . "): $!";
				     }
				 }
			     },
			     ($quiet ? () : (msg => "chown $uid, $gid, @files_to_change")), # shellquote?
			     rv   => scalar @files_to_change,
			    };
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_cond_run {
	my($self, %opts) = @_;
	my $if      = delete $opts{if};
	my $unless  = delete $opts{unless};
	my $creates = delete $opts{creates};
	my $cmd     = delete $opts{cmd};
	error "Unhandled options: " . join(" ", %opts) if %opts;

	if (!$cmd) {
	    error "cmd is a mandatory option for cond_run";
	}
	if (ref $cmd ne 'ARRAY') {
	    error "cmd must be an array reference";
	}

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
	    my $doit_commands;
	    if (ref $cmd->[0] eq 'ARRAY') {
		$doit_commands = $self->cmd_run(@$cmd);
	    } else {
		$doit_commands = $self->cmd_system(@$cmd);
	    }
	    $doit_commands->set_last_rv(1);
	    $doit_commands;
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_ln_nsf {
	my($self, $oldfile, $newfile) = @_;

	my $doit = 1;
	if (!defined $oldfile) {
	    error "oldfile was not specified for ln_nsf";
	} elsif (!defined $newfile) {
	    error "newfile was not specified for ln_nsf";
	} elsif (-l $newfile) {
	    my $points_to = readlink $newfile
		or error "Unexpected: readlink $newfile failed (race condition?)";
	    if ($points_to eq $oldfile) {
		$doit = 0;
	    }
	} elsif (-d $newfile) {
	    # Theoretically "ln -nsf destination directory" works (not always,
	    # e.g. fails with destination=/), but results are not very useful,
	    # so fail here.
	    error qq{"$newfile" already exists as a directory};
	} else {
	    # probably a file, keep $doit=1
	}

	if ($doit) {
	    my @commands =  {
			     code => sub {
				 system 'ln', '-nsf', $oldfile, $newfile;
				 error "ln -nsf $oldfile $newfile failed" if $? != 0;
			     },
			     msg => "ln -nsf $oldfile $newfile",
			     rv  => 1,
			    };
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_make_path {
	my($self, @directories) = @_;
	my $options = {}; if (ref $directories[-1] eq 'HASH') { $options = pop @directories }
	my @directories_to_create = grep { !-d $_ } @directories;
	if (@directories_to_create) {
	    my @commands =  {
			     code => sub {
				 require File::Path;
				 File::Path::make_path(@directories_to_create, $options)
					 or error $!;
			     },
			     msg => "make_path @directories",
			     rv  => scalar @directories_to_create,
			    };
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_mkdir {
	my($self, $directory, $mode) = @_;
	if (!-d $directory) {
	    my @commands;
	    if (defined $mode) {
		push @commands, {
				 code => sub { mkdir $directory, $mode or error "$!" },
				 msg  => "mkdir $directory with mask $mode",
				 rv   => 1,
				};
	    } else {
		push @commands, {
				 code => sub { mkdir $directory or error "$!" },
				 msg  => "mkdir $directory",
				 rv   => 1,
				};
	    }
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_remove_tree {
	my($self, @directories) = @_;
	my $options = {}; if (ref $directories[-1] eq 'HASH') { $options = pop @directories }
	my @directories_to_remove = grep { -d $_ } @directories;
	if (@directories_to_remove) {
	    my @commands =  {
			     code => sub {
				 require File::Path;
				 File::Path::remove_tree(@directories_to_remove, $options)
					 or error "$!";
			     },
			     msg => "remove_tree @directories_to_remove",
			     rv  => scalar @directories_to_remove,
			    };
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_rename {
	my($self, $from, $to) = @_;
	my @commands;
	push @commands, {
			 code => sub { rename $from, $to or error "$!" },
			 msg  => "rename $from, $to",
			 rv   => 1,
			};
	Doit::Commands->new(@commands);
    }

    sub cmd_copy {
	my($self, @args) = @_;
	my %options; if (@args && ref $args[0] eq 'HASH') { %options = %{ shift @args } }
	my $quiet = delete $options{quiet};
	error "Unhandled options: " . join(" ", %options) if %options;
	if (@args != 2) {
	    error "Expecting two arguments: from and to filenames";
	}
	my($from, $to) = @args;

	my $real_to;
	if (-d $to) {
	    require File::Basename;
	    $real_to = "$to/" . File::Basename::basename($from);
	} else {
	    $real_to = $to;
	}
	if (!-e $real_to || do { require File::Compare; File::Compare::compare($from, $real_to) != 0 }) {
	    my @commands =  {
			     code => sub {
				 require File::Copy;
				 File::Copy::copy($from, $to)
					 or error "Copy failed: $!";
			     },
			     msg => do {
				 if (!-e $real_to) {
				     "copy $from $real_to (destination does not exist)";
				 } else {
				     if ($quiet) {
					 "copy $from $real_to";
				     } else {
					 if (eval { require IPC::Run; 1 }) {
					     my $diff;
					     if (eval { IPC::Run::run(['diff', '-u', $real_to, $from], '>', \$diff); 1 }) {
						 "copy $from $real_to\ndiff:\n$diff";
					     } else {
						 "copy $from $real_to\n(diff not available" . (!$diff_error_shown++ ? ", error: $@" : "") . ")";
					     }
					 } else {
					     my $diffref = _qx('diff', '-u', $real_to, $from);
					     "copy $from $real_to\ndiff:\n$$diffref";
					 }
				     }
				 }
			     },
			     rv => 1,
			    };
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_move {
	my($self, $from, $to) = @_;
	my @commands = {
			code => sub {
			    require File::Copy;
			    File::Copy::move($from, $to)
				    or error "Move failed: $!";
			},
			msg => "move $from $to",
			rv  => 1,
		       };
	Doit::Commands->new(@commands);
    }

    sub _analyze_dollar_questionmark () {
	if ($? == -1) {
	    (
	        msg       => sprintf("Could not execute command: %s", $!),
	        errno     => $!,
	        exitcode  => $?,
	    );
	} elsif ($? & 127) {
	    my $signalnum = $? & 127;
	    my $coredump = ($? & 128) ? 'with' : 'without';
	    (
		msg       => sprintf("Command died with signal %d, %s coredump", $signalnum, $coredump),
		signalnum => $signalnum,
		coredump  => $coredump,
	    );
	} else {
	    my $exitcode = $?>>8;
	    (
		msg      => "Command exited with exit code " . $exitcode,
		exitcode => $exitcode,
	    );
	}
    }

    sub _handle_dollar_questionmark (@) {
	my(%opts) = @_;
	my $prefix_msg = delete $opts{prefix_msg};
	error "Unhandled options: " . join(" ", %opts) if %opts;

	my %res = _analyze_dollar_questionmark;
	my $msg = delete $res{msg};
	if (defined $prefix_msg) {
	    $msg = $prefix_msg.$msg;
	}
	Doit::Exception::throw($msg, %res);
    }

    sub _show_cwd ($) {
	my $flag = shift;
	if ($flag) {
	    require Cwd;
	    " (in " . Cwd::getcwd() . ")";
	} else {
	    "";
	}
    }

    sub cmd_open2 {
	my($self, @args) = @_;
	my %options; if (@args && ref $args[0] eq 'HASH') { %options = %{ shift @args } }
	my $quiet = delete $options{quiet};
	my $info = delete $options{info};
	my $instr = delete $options{instr}; $instr = '' if !defined $instr;
	error "Unhandled options: " . join(" ", %options) if %options;

	@args = Doit::Win32Util::win32_quote_list(@args) if Doit::IS_WIN;

	require IPC::Open2;

	my $code = sub {
	    my($chld_out, $chld_in);
	    my $pid = IPC::Open2::open2($chld_out, $chld_in, @args);
	    print $chld_in $instr;
	    close $chld_in;
	    local $/;
	    my $buf = <$chld_out>;
	    close $chld_out;
	    waitpid $pid, 0;
	    $? == 0
		or _handle_dollar_questionmark($quiet||$info ? (prefix_msg => "open2 command '@args' failed: ") : ());
	    $buf;
	};

	my @commands;
	push @commands, {
			 ($info ? (rv => $code->(), code => sub {}) : (code => $code)),
			 ($quiet ? () : (msg => "@args")),
			};
	Doit::Commands->new(@commands);
    }

    sub cmd_info_open2 {
	my($self, @args) = @_;
	my %options; if (@args && ref $args[0] eq 'HASH') { %options = %{ shift @args } }
	$options{info} = 1;
	$self->cmd_open2(\%options, @args);
    }

    sub cmd_open3 {
	my($self, @args) = @_;
	my %options; if (@args && ref $args[0] eq 'HASH') { %options = %{ shift @args } }
	my $quiet = delete $options{quiet};
	my $info = delete $options{info};
	my $instr = delete $options{instr};
	my $errref = delete $options{errref};
	my $statusref = delete $options{statusref};
	error "Unhandled options: " . join(" ", %options) if %options;

	@args = Doit::Win32Util::win32_quote_list(@args) if Doit::IS_WIN;

	require IO::Select;
	require IPC::Open3;
	require Symbol;

	my $code = sub {
	    my($chld_out, $chld_in, $chld_err);
	    $chld_err = Symbol::gensym();
	    my $pid = IPC::Open3::open3((defined $instr ? $chld_in : undef), $chld_out, $chld_err, @args);
	    if (defined $instr) {
		print $chld_in $instr;
		close $chld_in;
	    }

	    my $sel = IO::Select->new;
	    $sel->add($chld_out);
	    $sel->add($chld_err);

	    my %buf = ($chld_out => '', $chld_err => '');
	    while(my @ready_fhs = $sel->can_read()) {
		for my $ready_fh (@ready_fhs) {
		    my $buf = '';
		    while (sysread $ready_fh, $buf, 1024, length $buf) { }
		    if ($buf eq '') { # eof
			$sel->remove($ready_fh);
			$ready_fh->close;
			last if $sel->count == 0;
		    } else {
			$buf{$ready_fh} .= $buf;
		    }
		}
	    }

	    waitpid $pid, 0;
	    if ($statusref) {
		%$statusref = ( _analyze_dollar_questionmark );
	    } else {
		if ($? != 0) {
		    _handle_dollar_questionmark($quiet||$info ? (prefix_msg => "open3 command '@args' failed: ") : ());
		}
	    }

	    if ($errref) {
		$$errref = $buf{$chld_err};
	    }

	    $buf{$chld_out};
	};

	my @commands;
	push @commands, {
			 ($info ? (rv => $code->(), code => sub {}) : (code => $code)),
			 ($quiet ? () : (msg => "@args")),
			};
	Doit::Commands->new(@commands);
    }

    sub cmd_info_open3 {
	my($self, @args) = @_;
	my %options; if (@args && ref $args[0] eq 'HASH') { %options = %{ shift @args } }
	$options{info} = 1;
	$self->cmd_open3(\%options, @args);
    }

    sub _qx {
	my(@args) = @_;
	@args = Doit::Win32Util::win32_quote_list(@args) if Doit::IS_WIN;

	open my $fh, '-|', @args
	    or error "Error running '@args': $!";
	local $/;
	my $buf = <$fh>;
	close $fh;
	\$buf;
    }

    sub cmd_qx {
	my($self, @args) = @_;
	my %options; if (@args && ref $args[0] eq 'HASH') { %options = %{ shift @args } }
	my $quiet = delete $options{quiet};
	my $info = delete $options{info};
	my $statusref = delete $options{statusref};
	error "Unhandled options: " . join(" ", %options) if %options;

	my $code = sub {
	    my $bufref = _qx(@args);
	    if ($statusref) {
		%$statusref = ( _analyze_dollar_questionmark );
	    } else {
		if ($? != 0) {
		    _handle_dollar_questionmark($quiet||$info ? (prefix_msg => "qx command '@args' failed: ") : ());
		}
	    }
	    $$bufref;
	};

	my @commands;
	push @commands, {
			 ($info ? (rv => $code->(), code => sub {}) : (code => $code)),
			 ($quiet ? () : (msg => "@args")),
			};
	Doit::Commands->new(@commands);
    }

    sub cmd_info_qx {
	my($self, @args) = @_;
	my %options; if (@args && ref $args[0] eq 'HASH') { %options = %{ shift @args } }
	$options{info} = 1;
	$self->cmd_qx(\%options, @args);
    }

    sub cmd_rmdir {
	my($self, $directory) = @_;
	if (-d $directory) {
	    my @commands =  {
			     code => sub { rmdir $directory or error "$!" },
			     msg  => "rmdir $directory",
			    };
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
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
			 rv  => 1,
			};
	Doit::Commands->new(@commands);
    }

    sub cmd_setenv {
	my($self, $key, $val) = @_;
	if (!defined $ENV{$key} || $ENV{$key} ne $val) {
	    my @commands =  {
			     code => sub { $ENV{$key} = $val },
			     msg  => qq{set \$ENV{$key} to "$val", previous value was } . (defined $ENV{$key} ? qq{"$ENV{$key}"} : qq{unset}),
			     rv   => 1,
			    };
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_symlink {
	my($self, $oldfile, $newfile) = @_;
	my $doit;
	if (-l $newfile) {
	    my $points_to = readlink $newfile
		or error "Unexpected: readlink $newfile failed (race condition?)";
	    if ($points_to ne $oldfile) {
		$doit = 1;
	    }
	} elsif (!-e $newfile) {
	    $doit = 1;
	} else {
	    warning "$newfile exists but is not a symlink, will fail later...";
	}
	if ($doit) {
	    my @commands =  {
			     code => sub { symlink $oldfile, $newfile or error "$!" },
			     msg  => "symlink $oldfile $newfile",
			     rv   => 1,
			    };
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_system {
	my($self, @args) = @_;
	my %options; if (@args && ref $args[0] eq 'HASH') { %options = %{ shift @args } }
	my $quiet = delete $options{quiet};
	my $info = delete $options{info};
	my $show_cwd = delete $options{show_cwd};
	error "Unhandled options: " . join(" ", %options) if %options;

	@args = Doit::Win32Util::win32_quote_list(@args) if Doit::IS_WIN;

	my $code = sub {
	    system @args;
	    if ($? != 0) {
		_handle_dollar_questionmark;
	    }
	};

	my @commands;
	push @commands, {
			 ($info
			  ? (
			     rv   => do { $code->(); 1 },
			     code => sub {},
			    )
			  : (
			     rv   => 1,
			     code => $code,
			    )
			 ),
			 ($quiet ? () : (msg  => "@args" . _show_cwd($show_cwd))),
			};
	Doit::Commands->new(@commands);
    }

    sub cmd_info_system {
	my($self, @args) = @_;
	my %options; if (@args && ref $args[0] eq 'HASH') { %options = %{ shift @args } }
	$options{info} = 1;
	$self->cmd_system(\%options, @args);
    }

    sub cmd_touch {
	my($self, @files) = @_;
	my @commands;
	for my $file (@files) {
	    if (!-e $file) {
		push @commands, {
				 code => sub { open my $fh, '>>', $file or error "$!" },
				 msg  => "touch non-existent file $file",
				}
	    } else {
		push @commands, {
				 code => sub { utime time, time, $file or error "$!" },
				 msg  => "touch existent file $file",
				};
	    }
	}
	my $doit_commands = Doit::Commands->new(@commands);
	$doit_commands->set_last_rv(scalar @files);
	$doit_commands;
    }

    sub cmd_create_file_if_nonexisting {
	my($self, @files) = @_;
	my @commands;
	for my $file (@files) {
	    if (!-e $file) {
		push @commands, {
		    code => sub { open my $fh, '>>', $file or error "$!" },
		    msg  => "create empty file $file",
		};
	    }
	}
	if (@commands) {
	    my $doit_commands = Doit::Commands->new(@commands);
	    $doit_commands->set_last_rv(scalar @commands);
	    $doit_commands;
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_unlink {
	my($self, @files) = @_;
	my @files_to_remove;
	for my $file (@files) {
	    if (-e $file || -l $file) {
		push @files_to_remove, $file;
	    }
	}
	if (@files_to_remove) {
	    my @commands =  {
			     code => sub { unlink @files_to_remove or error "$!" },
			     msg  => "unlink @files_to_remove", # shellquote?
			    };
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_unsetenv {
	my($self, $key) = @_;
	if (defined $ENV{$key}) {
	    my @commands =  {
			     code => sub { delete $ENV{$key} },
			     msg  => qq{unset \$ENV{$key}, previous value was "$ENV{$key}"},
			     rv   => 1,
			    };
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
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

	my @files_to_change;
	for my $file (@files) {
	    my @s = stat $file;
	    if (@s) {
		if ($s[8] != $atime || $s[9] != $mtime) {
		    push @files_to_change, $file;
		}
	    } else {
		push @files_to_change, $file; # will fail later
	    }
	}

	if (@files_to_change) {
	    my @commands =  {
			     code => sub {
				 my $changed_files = utime $atime, $mtime, @files;
				 if ($changed_files != @files_to_change) {
				     if (@files_to_change == 1) {
					 error "utime failed: $!";
				     } elsif ($changed_files == 0) {
					 error "utime failed on all files: $!";
				     } else {
					 error "utime failed on some files (" . (@files_to_change-$changed_files) . "/" . scalar(@files_to_change) . "): $!";
				     }
				 }
			     },
			     msg  => "utime $atime, $mtime, @files",
			     rv   => scalar @files_to_change,
			    };
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_write_binary {
	my($self, @args) = @_;
	my %options; if (@args && ref $args[0] eq 'HASH') { %options = %{ shift @args } }
	my $quiet  = delete $options{quiet} || 0;
	my $atomic = exists $options{atomic} ? delete $options{atomic} : 1;
	error "Unhandled options: " . join(" ", %options) if %options;
	if (@args != 2) {
	    error "Expecting two arguments: filename and contents";
	}
	my($filename, $content) = @args;

	my $doit;
	my $need_diff;
	if (!-e $filename) {
	    $doit = 1;
	} elsif (-s $filename != length($content)) {
	    $doit = 1;
	    $need_diff = 1;
	} else {
	    open my $fh, '<', $filename
		or error "Can't open $filename: $!";
	    binmode $fh;
	    local $/;
	    my $file_content = <$fh>;
	    if ($file_content ne $content) {
		$doit = 1;
		$need_diff = 1;
	    }
	}

	if ($doit) {
	    my @commands =  {
			     code => sub {
				 # XXX consider to reuse code for atomic writes:
				 # either from Doit::File::file_atomic_write (problematic, different component)
				 # or share code with change_file
				 my $outfile = $atomic ? "$filename.$$.".time.".tmp" : $filename;
				 open my $ofh, '>', $outfile
				     or error "Can't write to $outfile: $!";
				 if (-e $filename) {
				     Doit::Util::copy_stat($filename, $outfile, ownership => 1, mode => 1);
				 }
				 binmode $ofh;
				 print $ofh $content;
				 close $ofh
				     or error "While closing $outfile: $!";
				 if ($atomic) {
				     rename $outfile, $filename
					 or error "Error while renaming $outfile to $filename: $!";
				 }
			     },
			     rv => 1,
			     ($quiet >= 2
			      ? ()
			      : (msg => do {
				     if ($quiet) {
					 if ($need_diff) {
					     "Replace existing file $filename";
					 } else {
					     "Create new file $filename";
					 }
				     } else {
					 if ($need_diff) {
					     if (eval { require IPC::Run; 1 }) { # no temporary file required
						 my $diff;
						 if (eval { IPC::Run::run(['diff', '-u', $filename, '-'], '<', \$content, '>', \$diff); 1 }) {
						     "Replace existing file $filename with diff:\n$diff";
						 } else {
						     "(diff not available" . (!$diff_error_shown++ ? ", error: $@" : "") . ")";
						 }
					     } else {
						 my $diff;
						 if (eval { require File::Temp; 1 }) {
						     my($tempfh,$tempfile) = File::Temp::tempfile(UNLINK => 1);
						     print $tempfh $content;
						     if (close $tempfh) {
							 my $diffref = _qx('diff', '-u', $filename, $tempfile);
							 $diff = $$diffref;
							 unlink $tempfile;
							 if (length $diff) {
							     $diff = "Replace existing file $filename with diff:\n$diff";
							 } else {
							     $diff = "(diff not available, probably no diff utility installed)";
							 }
						     } else {
							 $diff = "(diff not available, error in tempfile creation ($!))";
						     }
						 } else {
						     $diff = "(diff not available, neither IPC::Run nor File::Temp available)";
						 }
						 $diff;
					     }
					 } else {
					     "Create new file $filename with content:\n$content";
					 }
				     }
				 }
			     )),
			    };
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
    }

    sub cmd_change_file {
	my($self, @args) = @_;
	my %options; if (@args && ref $args[0] eq 'HASH') { %options = %{ shift @args } }
	my $check = delete $options{check};
	my $debug = delete $options{debug};
	if ($check && ref $check ne 'CODE') { error "check parameter should be a CODE reference" }
	error "Unhandled options: " . join(" ", %options) if %options;

	if (@args < 1) {
	    error "Expecting at least a filename and one or more changes";
	}

	my($file, @changes) = @args;
	if (!-e $file) {
	    error "$file does not exist";
	}
	if (!-f $file) {
	    error "$file is not a file";
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
			error "Can specify only one of the following: 'add_after', 'add_after_first', 'add_before', 'add_before_last' (change for $file)\n";
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
			error "Can never happen";
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
			    error "Cannot find '$add' in file";
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
		    error "action is missing";
		}
		if (ref $_->{action} ne 'CODE') {
		    error "action must be a sub reference";
		}
		push @unless_match_actions, $_;
	    } elsif ($_->{match}) {
		if (ref $_->{match} ne 'Regexp') {
		    my $rx = '^' . quotemeta($_->{match}) . '$';
		    $_->{match} = qr{$rx};
		}
		my $consequences = ($_->{action}?1:0) + (defined $_->{replace}?1:0) + (defined $_->{delete}?1:0);
		if ($consequences != 1) {
		    error "Exactly one of the following is missing: action, replace, or delete";
		}
		if ($_->{action}) {
		    if (ref $_->{action} ne 'CODE') {
			error "action must be a sub reference";
		    }
		} elsif (defined $_->{replace}) {
		    # accept
		} elsif (defined $_->{delete}) {
		    # accept
		} else {
		    error "FATAL: should never happen";
		}
		push @match_actions, $_;
	    } else {
		error "match or unless_match is missing";
	    }
	}

	require File::Temp;
	require File::Basename;
	require File::Copy;
	my($tmpfh,$tmpfile) = File::Temp::tempfile('doittemp_XXXXXXXX', UNLINK => 1, DIR => File::Basename::dirname($file));
	File::Copy::copy($file, $tmpfile)
		or error "failed to copy $file to temporary file $tmpfile: $!";
	Doit::Util::copy_stat($file, $tmpfile);

	require Tie::File;
	tie my @lines, 'Tie::File', $tmpfile
	    or error "cannot tie file $file: $!";

	my $no_of_changes = 0;
	for my $match_action (@match_actions) {
	    my $match  = $match_action->{match};
	    for(my $line_i=0; $line_i<=$#lines; $line_i++) {
		if ($debug) { info "change_file check '$lines[$line_i]' =~ '$match'" }
		if ($lines[$line_i] =~ $match) {
		    if (exists $match_action->{replace}) {
			my $replace = $match_action->{replace};
			if ($lines[$line_i] ne $replace) {
			    push @commands, { msg => "replace '$lines[$line_i]' with '$replace' in '$file'" };
			    $lines[$line_i] = $replace;
			    $no_of_changes++;
			}
		    } elsif (exists $match_action->{delete}) {
			if ($match_action->{delete}) {
			    push @commands, { msg => "delete '$lines[$line_i]' in '$file'" };
			    splice @lines, $line_i, 1;
			    $line_i--;
			    $no_of_changes++;
			}
		    } else {
			push @commands, { msg => "matched '$match' on line '$lines[$line_i]' in '$file' -> execute action" };
			my $action = $match_action->{action};
			$action->($lines[$line_i]);
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
	close $tmpfh;

	if ($no_of_changes) {
	    push @commands, {
			     code => sub {
				 if ($check) {
				     # XXX maybe it would be good to pass the Doit::Runner object,
				     #     but unfortunately it's not available at this point ---
				     #     maybe the code sub should generally get it as first argument?
				     $check->($tmpfile)
					 or error "Check on file $file failed";
				 }
				 rename $tmpfile, $file
				     or error "Can't rename $tmpfile to $file: $!";
			     },
			     msg => do {
				 my $diff;
				 if (eval { require IPC::Run; 1 }) {
				     if (!eval { IPC::Run::run(['diff', '-u', $file, $tmpfile], '>', \$diff); 1 }) {
					 $diff = "(diff not available" . (!$diff_error_shown++ ? ", error: $@" : "") . ")";
				     }
				 } else {
				     $diff = `diff -u '$file' '$tmpfile'`;
				 }
				 "Final changes as diff:\n$diff";
			     },
			     rv => $no_of_changes,
			    };
	}

	if ($no_of_changes) {
	    Doit::Commands->new(@commands);
	} else {
	    Doit::Commands->return_zero;
	}
    }

}

{
    package Doit::Commands;
    sub new {
	my($class, @commands) = @_;
	my $self = bless \@commands, $class;
	$self;
    }
    sub return_zero {
	my $class = shift;
	$class->new({ code => sub {}, rv => 0 });
    }
    sub commands { @{$_[0]} }
    sub set_last_rv {
	my($self, $rv) = @_;
	my @commands = $self->commands;
	if (@commands) {
	    $commands[-1]->{rv} = $rv;
	}
    }
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
	my($class, $Doit, %options) = @_;
	my $dryrun = delete $options{dryrun};
	die "Unhandled options: " . join(" ", %options) if %options;
	bless { Doit => $Doit, dryrun => $dryrun, components => [] }, $class;
    }
    sub is_dry_run { shift->{dryrun} }

    sub can_ipc_run { eval { require IPC::Run; 1 } }

    sub install_generic_cmd {
	my($self, $name, @args) = @_;
	$self->{Doit}->install_generic_cmd($name, @args);
	__PACKAGE__->install_cmd($name);
    }

    sub install_cmd {
	shift; # $class unused
	my $cmd = shift;
	my $meth = 'cmd_' . $cmd;
	my $code = sub {
	    my($self, @args) = @_;
	    if ($self->{dryrun}) {
		$self->{Doit}->$meth(@args)->show;
	    } else {
		$self->{Doit}->$meth(@args)->doit;
	    }
	};
	no strict 'refs';
	*{$cmd} = $code;
    }

    sub add_component {
	my($self, $component_or_module) = @_;
	my $module;
	if ($component_or_module =~ /::/) {
	    $module = $component_or_module;
	} else {
	    $module = 'Doit::' . ucfirst($component_or_module);
	}

	for (@{ $self->{components} }) {
	    return if $_->{module} eq $module;
	}

	if (!eval qq{ require $module; 1 }) {
	    Doit::Log::error("Cannot load $module: $@");
	}
	my $o = $module->new
	    or Doit::Log::error("Error while calling $module->new");
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
	push @{ $self->{components} }, { module => $module, path => $INC{$mod_file}, relpath => $mod_file };

	if ($o->can('add_components')) {
	    for my $sub_component ($o->add_components) {
		$self->add_component($sub_component);
	    }
	}
    }

    for my $cmd (
		 qw(chmod chown mkdir rename rmdir symlink unlink utime),
		 qw(make_path remove_tree), # File::Path
		 qw(copy move), # File::Copy
		 qw(run), # IPC::Run
		 qw(qx info_qx), # qx// and variant which even runs in dry-run mode, both using list syntax
		 qw(open2 info_open2), # IPC::Open2
		 qw(open3 info_open3), # IPC::Open3
		 qw(system info_system), # builtin system with variant
		 qw(cond_run), # conditional run
		 qw(touch), # like unix touch
		 qw(ln_nsf), # like unix ln -nsf
		 qw(create_file_if_nonexisting), # does the half of touch
		 qw(write_binary), # like File::Slurper
		 qw(change_file), # own invention
		 qw(setenv unsetenv), # $ENV manipulation
		) {
	__PACKAGE__->install_cmd($cmd);
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

    sub runner { shift->{runner} }

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
		my $start_time = time;
		my $got_pid = Doit::RPC::gentle_retry(
		    code => sub {
			waitpid $pid, &POSIX::WNOHANG;
		    },
		    retry_msg_code => sub {
			my($seconds) = @_;
			if (time - $start_time >= 2) {
			    info "can't reap process $pid, sleep for $seconds seconds";
			}
		    },
		    fast_sleep => 0.01,
		);
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

    sub gentle_retry {
	my(%opts) = @_;
	my $code           = delete $opts{code} || die "code is mandatory";
	my $tries          = delete $opts{tries} || 20;
	my $fast_tries     = delete $opts{fast_tries} || int($tries/2);
	my $slow_sleep     = delete $opts{slow_sleep} || 1;
	my $fast_sleep     = delete $opts{fast_sleep} || 0.1;
	my $retry_msg_code = delete $opts{retry_msg_code};
	my $fail_info_ref  = delete $opts{fail_info_ref};
	die "Unhandled options: " . join(" ", %opts) if %opts;

	for my $try (1..$tries) {
	    my $ret = $code->(fail_info_ref => $fail_info_ref, try => $try);
	    return $ret if $ret;
	    my $sleep_sub;
	    if ($fast_tries && eval { require Time::HiRes; 1 }) {
		$sleep_sub = \&Time::HiRes::sleep;
	    } else {
		$sleep_sub = sub { sleep $_[0] };
	    }
	    my $seconds = $try <= $fast_tries && defined &Time::HiRes::sleep ? $fast_sleep : $slow_sleep;
	    $retry_msg_code->($seconds) if $retry_msg_code;
	    $sleep_sub->($seconds);
	}

	undef;
    }

}

{
    package Doit::RPC::Client;
    our @ISA = ('Doit::RPC');

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
    our @ISA = ('Doit::RPC');

    sub new {
	my($class, $runner, $sockpath, %options) = @_;

	my $debug = delete $options{debug};
	my $excl  = delete $options{excl};
	die "Unhandled options: " . join(" ", %options) if %options;

	bless {
	       runner   => $runner,
	       sockpath => $sockpath,
	       debug    => $debug,
	       excl     => $excl,
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
	if (!$self->{excl} && -e $sockpath) {
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
	    my($rettype, @ret) = $self->runner->call_wrapped_method($context, @data);
	    $d->(" sending result back");
	    $self->send_data($rettype, @ret);
	}
    }

}

{
    package Doit::RPC::SimpleServer;
    our @ISA = ('Doit::RPC');
    
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
	    if (Doit::IS_WIN) {
		open STDOUT, '>', 'CON:' or die $!; # XXX????
	    } else {
		open STDOUT, '>', "/dev/stderr" or die $!; # XXX????
	    }
	    my($rettype, @ret) = $self->runner->call_wrapped_method($context, @data);
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

    our $AUTOLOAD;
    sub AUTOLOAD {
	(my $method = $AUTOLOAD) =~ s{.*::}{};
	my $self = shift;
	$self->call_remote($method, @_); # XXX or use goto?
    }

    sub _can_LANS {
	require POSIX;
	$^O eq 'linux' && (POSIX::uname())[2] !~ m{^([01]\.|2\.[01]\.)} # osvers >= 2.2, earlier versions did not have LANS
    }

}

{
    package Doit::_ScriptTools;

    sub add_components {
	my(@components) = @_;
	q|for my $component_module (qw(| . join(" ", map { qq{$_->{module}} } @components) . q|)) { $d->add_component($component_module) } |;
    }

    sub self_require (;$) {
	my $realscript = shift;
	if (!defined $realscript) { $realscript = $0 }
	if ($realscript ne '-e') { # not a oneliner
	    q{$ENV{DOIT_IN_REMOTE} = 1; } .
	    q{require "} . File::Basename::basename($realscript) . q{"; };
	} else {
	    q{use Doit; };
	}
    }
}

{
    package Doit::Sudo;

    our @ISA = ('Doit::_AnyRPCImpl');

    use Doit::Log;

    my $socket_count = 0;

    sub do_connect {
	my($class, %opts) = @_;
	my @sudo_opts = @{ delete $opts{sudo_opts} || [] };
	my $dry_run = delete $opts{dry_run};
	my $debug = delete $opts{debug};
	my @components = @{ delete $opts{components} || [] };
	my $perl = delete $opts{perl} || $^X;
	die "Unhandled options: " . join(" ", %opts) if %opts;

	my $self = bless { }, $class;

	require File::Basename;
	require IPC::Open2;
	require POSIX;
	require Symbol;

	# Socket pathname, make it possible to find out
	# old outdated sockets easily by including a
	# timestamp. Also need to maintain a $socket_count,
	# if the same script opens multiple sockets quickly.
	my $sock_path = "/tmp/." . join(".", "doit", "sudo", POSIX::strftime("%Y%m%d_%H%M%S", gmtime), $<, $$, (++$socket_count)) . ".sock";

	# Make sure password has to be entered only once (if at all)
	# Using 'sudo --validate' would be more correct, however,
	# mysterious "sudo: ignoring time stamp from the future"
	# errors may happen every now and then. Seen on a
	# debian/jessie system, possibly related to
	# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=762465
	{
	    my @cmd = ('sudo', @sudo_opts, 'true');
	    system @cmd;
	    if ($? != 0) {
		# Possible cases:
		# - sudo is not installed
		# - sudo authentication is not possible or user entered wrong password
		# - true is not installed (hopefully this never happens on Unix systems)
		error "Command '@cmd' failed";
	    }
	}

	# On linux use Linux Abstract Namespace Sockets ---
	# invisible and automatically cleaned up. See man 7 unix.
	my $LANS_PREFIX = $class->_can_LANS ? '\0' : '';

	# Run the server
	my @cmd_worker =
	    (
	     'sudo', @sudo_opts, $perl, "-I".File::Basename::dirname(__FILE__), "-I".File::Basename::dirname($0), "-e",
	     Doit::_ScriptTools::self_require() .
	     q{my $d = Doit->init; } .
	     Doit::_ScriptTools::add_components(@components) .
	     q{Doit::RPC::Server->new($d, "} . $LANS_PREFIX . $sock_path . q{", excl => 1, debug => } . ($debug?1:0) . q{)->run();} .
	     ($LANS_PREFIX ? '' : q<END { unlink "> . $sock_path . q<" }>), # cleanup socket file, except if Linux Abstract Namespace Sockets are used
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

	# Run the client --- must also run under root for socket
	# access.
	my($in, $out);
	my @cmd_comm = ('sudo', @sudo_opts, $perl, "-I".File::Basename::dirname(__FILE__), "-MDoit", "-e",
			q{Doit::Comm->comm_to_sock("} . $LANS_PREFIX . $sock_path . q{", debug => shift)}, !!$debug);
	warn "comm perl cmd: @cmd_comm\n" if $debug;
	my $comm_pid = IPC::Open2::open2($out, $in, @cmd_comm);
	$self->{rpc} = Doit::RPC::Client->new($out, $in, label => "sudo:", debug => $debug);

	$self;
    }

    sub DESTROY { }

}

{
    package Doit::SSH;

    our @ISA = ('Doit::_AnyRPCImpl');

    use Doit::Log;

    sub do_connect {
	require File::Basename;
	require Net::OpenSSH;
	require FindBin;
	my($class, $host, %opts) = @_;
	my $dry_run = delete $opts{dry_run};
	my @components = @{ delete $opts{components} || [] };
	my $debug = delete $opts{debug};
	my $as = delete $opts{as};
	my $forward_agent = delete $opts{forward_agent};
	my $tty = delete $opts{tty};
	my $port = delete $opts{port};
	my $master_opts = delete $opts{master_opts};
	my $dest_os = delete $opts{dest_os};
	$dest_os = 'unix' if !defined $dest_os;
	my $put_to_remote = delete $opts{put_to_remote} || 'rsync_put'; # XXX ideally this should be determined automatically
	$put_to_remote =~ m{^(rsync_put|scp_put)$}
	    or error "Valid values for put_to_remote: rsync_put or scp_put";
	my $perl = delete $opts{perl} || 'perl';
	error "Unhandled options: " . join(" ", %opts) if %opts;

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
	$ssh->error
	    and error "Connection error to $host: " . $ssh->error;
	$self->{ssh} = $ssh;
	{
	    my $remote_cmd;
	    if ($dest_os eq 'MSWin32') {
		$remote_cmd = 'if not exist .doit\lib\ mkdir .doit\lib';
	    } else {
		$remote_cmd = "[ ! -d .doit/lib ] && mkdir -p .doit/lib";
	    }
	    if ($debug) {
		info "Running '$remote_cmd' on remote";
	    }
	    $ssh->system(\%ssh_run_opts, $remote_cmd);
	}
	if ($FindBin::RealScript ne '-e') {
	    no warnings 'once';
	    $ssh->$put_to_remote({verbose => $debug}, "$FindBin::RealBin/$FindBin::RealScript", ".doit/"); # XXX verbose?
	}
	$ssh->$put_to_remote({verbose => $debug}, __FILE__, ".doit/lib/");
	{
	    my %seen_dir;
	    for my $component (
			       @components,
			       ( # add additional RPC components
				$dest_os ne 'MSWin32' ? () :
				do {
				    (my $srcpath = __FILE__) =~ s{\.pm}{/WinRPC.pm};
				    {relpath => "Doit/WinRPC.pm", path => $srcpath},
				}
			       )
			      ) {
		my $from = $component->{path};
		my $to = $component->{relpath};
		my $full_target = ".doit/lib/$to";
		my $target_dir = File::Basename::dirname($full_target);
		if (!$seen_dir{$target_dir}) {
		    my $remote_cmd;
		    if ($dest_os eq 'MSWin32') {
			(my $win_target_dir = $target_dir) =~ s{/}{\\}g;
			$remote_cmd = "if not exist $win_target_dir mkdir $win_target_dir"; # XXX is this equivalent to mkdir -p?
		    } else {
			$remote_cmd = "[ ! -d $target_dir ] && mkdir -p $target_dir";
		    }
		    $ssh->system(\%ssh_run_opts, $remote_cmd);
		    $seen_dir{$target_dir} = 1;
		}
		$ssh->$put_to_remote({verbose => $debug}, $from, $full_target);
	    }
	}

	my $sock_path = (
			 $dest_os eq 'MSWin32'
			 ? join("-", "doit", "ssh", POSIX::strftime("%Y%m%d_%H%M%S", gmtime), int(rand(99999999)))
			 : do {
			     require POSIX;
			     "/tmp/." . join(".", "doit", "ssh", POSIX::strftime("%Y%m%d_%H%M%S", gmtime), $<, $$, int(rand(99999999))) . ".sock";
			 }
			);

	my @cmd;
	if (defined $as) {
	    if ($as eq 'root') {
		@cmd = ('sudo');
	    } else {
		@cmd = ('sudo', '-u', $as);
	    }
	} # XXX add ssh option -t? for password input?

	my @cmd_worker;
	if ($dest_os eq 'MSWin32') {
	    @cmd_worker =
	    (
	     # @cmd not used here (no sudo)
	     $perl, "-I.doit", "-I.doit\\lib", "-e",
	     Doit::_ScriptTools::self_require($FindBin::RealScript) .
	     q{use Doit::WinRPC; } .
	     q{my $d = Doit->init; } .
	     Doit::_ScriptTools::add_components(@components) .
	     # XXX server cleanup? on signals? on END?
	     q{Doit::WinRPC::Server->new($d, "} . $sock_path . q{", debug => } . ($debug?1:0).q{)->run();},
	     "--", ($dry_run? "--dry-run" : ())
	    );
	    @cmd_worker = Doit::Win32Util::win32_quote_list(@cmd_worker);
	} else {
	    @cmd_worker =
	    (
	     @cmd, $perl, "-I.doit", "-I.doit/lib", "-e",
	     Doit::_ScriptTools::self_require($FindBin::RealScript) .
	     q{my $d = Doit->init; } .
	     Doit::_ScriptTools::add_components(@components) .
	     q<sub _server_cleanup { unlink "> . $sock_path . q<" }> .
	     q<$SIG{PIPE} = \&_server_cleanup; > .
	     q<END { _server_cleanup() } > .
	     q{Doit::RPC::Server->new($d, "} . $sock_path . q{", excl => 1, debug => } . ($debug?1:0).q{)->run();},
	     "--", ($dry_run? "--dry-run" : ())
	    );
	}
	warn "remote perl cmd: @cmd_worker\n" if $debug;
	my $worker_pid = $ssh->spawn(\%ssh_run_opts, @cmd_worker); # XXX what to do with worker pid?
	$self->{worker_pid} = $worker_pid;

	my @cmd_comm;
	if ($dest_os eq 'MSWin32') {
	    @cmd_comm =
	    ($perl, "-I.doit\\lib", "-MDoit", "-MDoit::WinRPC", "-e",
	     q{Doit::WinRPC::Comm->new("} . $sock_path . q{", debug => shift)->run},
	     !!$debug,
	    );
	    @cmd_comm = Doit::Win32Util::win32_quote_list(@cmd_comm);
	} else {
	    @cmd_comm =
	    (
	     @cmd, $perl, "-I.doit/lib", "-MDoit", "-e",
	     q{Doit::Comm->comm_to_sock("} . $sock_path . q{", debug => shift);},
	     !!$debug,
	    );
	}
	warn "comm perl cmd: @cmd_comm\n" if $debug;
	my($out, $in, $comm_pid) = $ssh->open2(@cmd_comm);
	$self->{comm_pid} = $comm_pid;
	$self->{rpc} = Doit::RPC::Client->new($in, $out, label => "ssh:$host", debug => $debug);

	$self;
    }

    sub ssh { $_[0]->{ssh} }

    sub DESTROY {
	my $self = shift;
	local $?; # XXX Net::OpenSSH::_waitpid sets $?=0
	if ($self->{ssh}) {
	    $self->{ssh}->disconnect if $self->{ssh}->can('disconnect');
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
	my $sock_err;
	my $sock = Doit::RPC::gentle_retry(
	    code => sub {
		my(%opts) = @_;
		my $sock = IO::Socket::UNIX->new(
		    Type => SOCK_STREAM(),
		    Peer => $peer,
		);
		return $sock if $sock;
		${$opts{fail_info_ref}} = "(peer=$peer, errno=$!)";
		undef;
	    },
	    retry_msg_code => sub {
		my($seconds) = @_;
		$d->("can't connect, sleep for $seconds seconds");
	    },
	    fail_info_ref => \$sock_err,
	);
	if (!$sock) {
	    die "COMM: Can't connect to socket (after $tries retries) $sock_err";
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
