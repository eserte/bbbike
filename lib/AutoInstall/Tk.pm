# -*- perl -*-

#
# $Id: Tk.pm,v 1.1 2000/12/01 00:33:42 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package AutoInstall::Tk;

# XXX requirements from CPAN:
# FirstTime::init accepts verbose parameter
# CPAN::load uses verbose parameter for FirstTime::init on demand
# CPAN::install returns 1 or 0 on success

use CPAN;
use CPAN::FirstTime;

if ($CPAN::VERSION <= 1.54) {

eval <<'CPANCODE';
package CPAN::Config;
#-> sub CPAN::Config::load ;
sub load {
    my($self) = shift;
    my(@miss);
    use Carp;
    eval {require CPAN::Config;};       # We eval because of some
                                        # MakeMaker problems
    unless ($dot_cpan++){
      unshift @INC, MM->catdir($ENV{HOME},".cpan");
      eval {require CPAN::MyConfig;};   # where you can override
                                        # system wide settings
      shift @INC;
    }
    return unless @miss = $self->not_loaded;
    # XXX better check for arrayrefs too
    require CPAN::FirstTime;
    my($configpm,$fh,$redo,$theycalled);
    $redo ||= "";
    $theycalled++ if @miss==1 && $miss[0] eq 'inhibit_startup_message';
    if (defined $INC{"CPAN/Config.pm"} && -w $INC{"CPAN/Config.pm"}) {
	$configpm = $INC{"CPAN/Config.pm"};
	$redo++;
    } elsif (defined $INC{"CPAN/MyConfig.pm"} && -w $INC{"CPAN/MyConfig.pm"}) {
	$configpm = $INC{"CPAN/MyConfig.pm"};
	$redo++;
    } else {
	my($path_to_cpan) = File::Basename::dirname($INC{"CPAN.pm"});
	my($configpmdir) = MM->catdir($path_to_cpan,"CPAN");
	my($configpmtest) = MM->catfile($configpmdir,"Config.pm");
	if (-d $configpmdir or File::Path::mkpath($configpmdir)) {
	    if (-w $configpmtest) {
		$configpm = $configpmtest;
	    } elsif (-w $configpmdir) {
		#_#_# following code dumped core on me with 5.003_11, a.k.
		unlink "$configpmtest.bak" if -f "$configpmtest.bak";
		rename $configpmtest, "$configpmtest.bak" if -f $configpmtest;
		my $fh = FileHandle->new;
		if ($fh->open(">$configpmtest")) {
		    $fh->print("1;\n");
		    $configpm = $configpmtest;
		} else {
		    # Should never happen
		    Carp::confess("Cannot open >$configpmtest");
		}
	    }
	}
	unless ($configpm) {
	    $configpmdir = MM->catdir($ENV{HOME},".cpan","CPAN");
	    File::Path::mkpath($configpmdir);
	    $configpmtest = MM->catfile($configpmdir,"MyConfig.pm");
	    if (-w $configpmtest) {
		$configpm = $configpmtest;
	    } elsif (-w $configpmdir) {
		#_#_# following code dumped core on me with 5.003_11, a.k.
		my $fh = FileHandle->new;
		if ($fh->open(">$configpmtest")) {
		    $fh->print("1;\n");
		    $configpm = $configpmtest;
		} else {
		    # Should never happen
		    Carp::confess("Cannot open >$configpmtest");
		}
	    } else {
		Carp::confess(qq{WARNING: CPAN.pm is unable to }.
			      qq{create a configuration file.});
	    }
	}
    }
    local($") = ", ";
    $CPAN::Frontend->myprint(<<END) if $redo && ! $theycalled;
We have to reconfigure CPAN.pm due to following uninitialized parameters:

@miss
END
    $CPAN::Frontend->myprint(qq{
$configpm initialized.
});
    sleep 2;
    CPAN::FirstTime::init($configpm, 1);
}

package CPAN::FirstTime;

sub init {
    my($configpm, $fastread) = @_;
    use Config;
    unless ($CPAN::VERSION) {
	require CPAN::Nox;
    }
    eval {require CPAN::Config;};
    $CPAN::Config ||= {};
    local($/) = "\n";
    local($\) = "";
    local($|) = 1;

    my($ans,$default,$local,$cont,$url,$expected_size);

    #
    # Files, directories
    #

    print qq[

CPAN is the world-wide archive of perl resources. It consists of about
100 sites that all replicate the same contents all around the globe.
Many countries have at least one CPAN site already. The resources
found on CPAN are easily accessible with the CPAN.pm module. If you
want to use CPAN.pm, you have to configure it properly.

If you do not want to enter a dialog now, you can answer 'no' to this
question and I\'ll try to autoconfigure. (Note: you can revisit this
dialog anytime later by typing 'o conf init' at the cpan prompt.)

] unless defined $fastread;

    if (!defined $fastread) {
      my $manual_conf =
	ExtUtils::MakeMaker::prompt("Are you ready for manual configuration?",
				    "yes");
      local $^W;
      if ($manual_conf =~ /^\s*y/i) {
	$fastread = 0;
	*prompt = \&ExtUtils::MakeMaker::prompt;
      }
    }
    if ($fastread) {
      $CPAN::Config->{urllist} ||= [];
      # prototype should match that of &MakeMaker::prompt
      *prompt = sub ($;$) {
	my($q,$a) = @_;
	my($ret) = defined $a ? $a : "";
	printf qq{%s [%s]\n\n}, $q, $ret;
	$ret;
      };
    }
    print qq{

The following questions are intended to help you with the
configuration. The CPAN module needs a directory of its own to cache
important index files and maybe keep a temporary mirror of CPAN files.
This may be a site-wide directory or a personal directory.

};

    my $cpan_home = $CPAN::Config->{cpan_home} || MM->catdir($ENV{HOME}, ".cpan");
    if (-d $cpan_home) {
	print qq{

I see you already have a  directory
    $cpan_home
Shall we use it as the general CPAN build and cache directory?

};
    } else {
	print qq{

First of all, I\'d like to create this directory. Where?

};
    }

    $default = $cpan_home;
    while ($ans = prompt("CPAN build and cache directory?",$default)) {
      eval { File::Path::mkpath($ans); }; # dies if it can't
      if ($@) {
	warn "Couldn't create directory $ans.
Please retry.\n";
	next;
      }
      if (-d $ans && -w _) {
	last;
      } else {
	warn "Couldn't find directory $ans
  or directory is not writable. Please retry.\n";
      }
    }
    $CPAN::Config->{cpan_home} = $ans;

    print qq{

If you want, I can keep the source files after a build in the cpan
home directory. If you choose so then future builds will take the
files from there. If you don\'t want to keep them, answer 0 to the
next question.

};

    $CPAN::Config->{keep_source_where} = MM->catdir($CPAN::Config->{cpan_home},"sources");
    $CPAN::Config->{build_dir} = MM->catdir($CPAN::Config->{cpan_home},"build");

    #
    # Cache size, Index expire
    #

    print qq{

How big should the disk cache be for keeping the build directories
with all the intermediate files?

};

    $default = $CPAN::Config->{build_cache} || 10;
    $ans = prompt("Cache size for build directory (in MB)?", $default);
    $CPAN::Config->{build_cache} = $ans;

    # XXX This the time when we refetch the index files (in days)
    $CPAN::Config->{'index_expire'} = 1;

    print qq{

By default, each time the CPAN module is started, cache scanning
is performed to keep the cache size in sync. To prevent from this,
disable the cache scanning with 'never'.

};

    $default = $CPAN::Config->{scan_cache} || 'atstart';
    do {
        $ans = prompt("Perform cache scanning (atstart or never)?", $default);
    } while ($ans ne 'atstart' && $ans ne 'never');
    $CPAN::Config->{scan_cache} = $ans;

    #
    # prerequisites_policy
    # Do we follow PREREQ_PM?
    #
    print qq{

The CPAN module can detect when a module that which you are trying to
build depends on prerequisites. If this happens, it can build the
prerequisites for you automatically ('follow'), ask you for
confirmation ('ask'), or just ignore them ('ignore'). Please set your
policy to one of the three values.

};

    $default = $CPAN::Config->{prerequisites_policy} || 'follow';
    do {
      $ans =
	  prompt("Policy on building prerequisites (follow, ask or ignore)?",
		 $default);
    } while ($ans ne 'follow' && $ans ne 'ask' && $ans ne 'ignore');
    $CPAN::Config->{prerequisites_policy} = $ans;

    #
    # External programs
    #

    print qq{

The CPAN module will need a few external programs to work
properly. Please correct me, if I guess the wrong path for a program.
Don\'t panic if you do not have some of them, just press ENTER for
those.

};

    my $old_warn = $^W;
    local $^W if $^O eq 'MacOS';
    my(@path) = split /$Config{'path_sep'}/, $ENV{'PATH'};
    local $^W = $old_warn;
    my $progname;
    for $progname (qw/gzip tar unzip make lynx ncftpget ncftp ftp/){
      if ($^O eq 'MacOS') {
          $CPAN::Config->{$progname} = 'not_here';
          next;
      }
      my $progcall = $progname;
      # we don't need ncftp if we have ncftpget
      next if $progname eq "ncftp" && $CPAN::Config->{ncftpget} gt " ";
      my $path = $CPAN::Config->{$progname} 
	  || $Config::Config{$progname}
	      || "";
      if (MM->file_name_is_absolute($path)) {
	# testing existence is not good enough, some have these exe
	# extensions

	# warn "Warning: configured $path does not exist\n" unless -e $path;
	# $path = "";
      } else {
	$path = '';
      }
      unless ($path) {
	# e.g. make -> nmake
	$progcall = $Config::Config{$progname} if $Config::Config{$progname};
      }

      $path ||= find_exe($progcall,[@path]);
      warn "Warning: $progcall not found in PATH\n" unless
	  $path; # not -e $path, because find_exe already checked that
      $ans = prompt("Where is your $progname program?",$path) || $path;
      $CPAN::Config->{$progname} = $ans;
    }
    my $path = $CPAN::Config->{'pager'} || 
	$ENV{PAGER} || find_exe("less",[@path]) || 
	    find_exe("more",[@path]) || ($^O eq 'MacOS' ? $ENV{EDITOR} : 0 )
	    || "more";
    $ans = prompt("What is your favorite pager program?",$path);
    $CPAN::Config->{'pager'} = $ans;
    $path = $CPAN::Config->{'shell'};
    if (MM->file_name_is_absolute($path)) {
	warn "Warning: configured $path does not exist\n" unless -e $path;
	$path = "";
    }
    $path ||= $ENV{SHELL};
    if ($^O eq 'MacOS') {
        $CPAN::Config->{'shell'} = 'not_here';
    } else {
        $path =~ s,\\,/,g if $^O eq 'os2';	# Cosmetic only
        $ans = prompt("What is your favorite shell?",$path);
        $CPAN::Config->{'shell'} = $ans;
    }

    #
    # Arguments to make etc.
    #

    print qq{

Every Makefile.PL is run by perl in a separate process. Likewise we
run \'make\' and \'make install\' in processes. If you have any parameters
\(e.g. PREFIX, INSTALLPRIVLIB, UNINST or the like\) you want to pass to
the calls, please specify them here.

If you don\'t understand this question, just press ENTER.

};

    $default = $CPAN::Config->{makepl_arg} || "";
    $CPAN::Config->{makepl_arg} =
	prompt("Parameters for the 'perl Makefile.PL' command?",$default);
    $default = $CPAN::Config->{make_arg} || "";
    $CPAN::Config->{make_arg} = prompt("Parameters for the 'make' command?",$default);

    $default = $CPAN::Config->{make_install_arg} || $CPAN::Config->{make_arg} || "";
    $CPAN::Config->{make_install_arg} =
	prompt("Parameters for the 'make install' command?",$default);

    #
    # Alarm period
    #

    print qq{

Sometimes you may wish to leave the processes run by CPAN alone
without caring about them. As sometimes the Makefile.PL contains
question you\'re expected to answer, you can set a timer that will
kill a 'perl Makefile.PL' process after the specified time in seconds.

If you set this value to 0, these processes will wait forever. This is
the default and recommended setting.

};

    $default = $CPAN::Config->{inactivity_timeout} || 0;
    $CPAN::Config->{inactivity_timeout} =
	prompt("Timeout for inactivity during Makefile.PL?",$default);

    # Proxies

    print qq{

If you\'re accessing the net via proxies, you can specify them in the
CPAN configuration or via environment variables. The variable in
the \$CPAN::Config takes precedence.

};

    for (qw/ftp_proxy http_proxy no_proxy/) {
	$default = $CPAN::Config->{$_} || $ENV{$_};
	$CPAN::Config->{$_} = prompt("Your $_?",$default);
    }

    #
    # MIRRORED.BY
    #

    conf_sites() unless $fastread;

    unless (@{$CPAN::Config->{'wait_list'}||[]}) {
	print qq{

WAIT support is available as a Plugin. You need the CPAN::WAIT module
to actually use it.  But we need to know your favorite WAIT server. If
you don\'t know a WAIT server near you, just press ENTER.

};
	$default = "wait://ls6.informatik.uni-dortmund.de:1404";
	$ans = prompt("Your favorite WAIT server?\n  ",$default);
	push @{$CPAN::Config->{'wait_list'}}, $ans;
    }

    # We don't ask that now, it will be noticed in time, won't it?
    $CPAN::Config->{'inhibit_startup_message'} = 0;
    $CPAN::Config->{'getcwd'} = 'cwd';

    print "\n\n";
    CPAN::Config->commit($configpm);
}
CPANCODE
}

package AutoInstall::Tk;

sub do_autoinstall_tk {
    my @modules = @_;
    die "No modules" if !@modules;

    use Tk;
    use Text::Wrap qw(wrap $columns);
    use strict;

    $columns = 40;

    my $mw = new MainWindow;
    $mw->withdraw;

    my $title = "Auto-CPAN-Installation";
    my $yn = $mw->messageBox
	(-title => $title,
	 -icon => "warning",
	 -message => "Sollen die Module:\n" .
 	             wrap("  ","  ", join(", ", @modules)) . "\n" .
	             "automatisch vom CPAN installiert werden?",
	 -type => "YesNo");
    if ($yn !~ /yes/i) {
	return -1;
    }

    $yn = $mw->messageBox
	(-title => $title,
	 -icon => "warning",
	 -message => "Internet-Verbindung aktivieren oder auf \"Abbrechen\" klicken",
	 -type => "OkCancel",
	 );
    if ($yn !~ /ok/i) {
	return -2;
    }

    CPAN::install(@modules);

    $mw->messageBox
	(-title => $title,
	 -icon => "info",
	 -message => "Modul-Installation beendet",
	 -type => "OkCancel",
	 );

    $mw->destroy;
    1;
}

return 1 if caller;

package main;

my @modules = @ARGV;
my $r = AutoInstall::Tk::do_autoinstall_tk(@modules);
if ($r < 0) {
    exit(-$r);
}
exit(0);


