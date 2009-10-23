# -*- perl -*-

#
# $Id: WWWBrowser.pm,v 2.47 2009/03/01 22:11:28 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2000,2001,2003,2005,2006,2007,2008 Slaven Rezic.
# All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# TODO: check Win32::WebBrowser

package WWWBrowser;

use strict;
use vars qw(@unix_browsers @available_browsers
	    @terminals @available_terminals
	    $VERSION $VERBOSE $initialized $os $fork
	    $ignore_config);

$VERSION = sprintf("%d.%02d", q$Revision: 2.47 $ =~ /(\d+)\.(\d+)/);

@available_browsers = qw(_debian_browser _internal_htmlview
			 _default_gnome _default_kde
			 htmlview
			 seamonkey mozilla firefox galeon konqueror netscape Netscape kfmclient
			 dillo w3m lynx
			 mosaic Mosaic
			 chimera arena tkweb
			 explorer);

@unix_browsers = @available_browsers if !@unix_browsers;

@available_terminals = qw(xterm konsole gnome-terminal rxvt Eterm kvt);

@terminals = @available_terminals if !@terminals;

init();

sub init {
    if (!$initialized) {
	$os = ($^O eq 'MSWin32' || $^O eq 'os2' || $^O eq 'dos' ? 'win' :
	       $^O eq 'darwin'  ? 'macosx' :
	       $^O eq 'MacOS'   ? 'mac' :
	                          'unix');
	if (!defined &main::status_message) {
	    eval 'sub status_message { warn $_[0] }';
	} else {
	    eval 'sub status_message { main::status_message(@_) }';
	}
	$fork = 1;
	$initialized++;
	get_from_config();
    }
}

sub start_browser {
    my $url = shift;
    my(%args) = @_;

    if ($os eq 'win') {
	return start_browser_windows($url, %args);
    }

    if ($os eq 'macosx') {
	exec_bg("open", $url);
	return 1;
    }

    my @browsers = @unix_browsers;
    if ($args{-browser}) {
	unshift @browsers, delete $args{-browser};
    }

    foreach my $browser (@browsers) {
	if ($VERBOSE && $VERBOSE >= 2) {
	    warn "Try $browser ...\n";
	}

	next if ($browser !~ /^_/ && !is_in_path($browser));
	if ($browser =~ /^(lynx|w3m)$/) { # text-orientierte Browser
	    return 1 if open_in_terminal($browser, $url, %args);
	    next;
	}

	if ((!defined $ENV{DISPLAY} || $ENV{DISPLAY} eq '') &&
	    $^O ne 'cygwin') {
	    next;
	}
	# After this point only X11 browsers or cygwin as a special case

	my $url = $url;
	if ($browser eq '_default_gnome') {
	    eval {
		my $cmdline = _get_cmdline_for_url_from_Gnome($url);
		exec_bg($cmdline);
		return 1;
	    };
	} elsif ($browser eq '_default_kde') {
	    # NYI
	} elsif ($browser eq 'konqueror') {
	    return 1 if open_in_konqueror($url, %args);
	} elsif ($browser eq 'galeon') {
	    return 1 if open_in_galeon($url, %args);
	} elsif ($browser eq 'seamonkey') {
	    return 1 if open_in_seamonkey($url, %args);
	} elsif ($browser eq 'mozilla') {
	    return 1 if open_in_mozilla($url, %args);
	} elsif ($browser eq 'opera') {
	    return 1 if open_in_opera($url, %args);
	} elsif ($browser =~ /^mosaic$/i &&
	    $url =~ /^file:/ && $url !~ m|file://|) {
	    $url =~ s|file:/|file://localhost/|;
	} elsif ($browser eq 'kfmclient') {
	    # kfmclient loads kfm, which loads and displays all KDE icons
	    # on the desktop, even if KDE is not running at all.
	    exec_bg("kfmclient", "openURL", $url);
	    return 1 if (!$?)
	} elsif ($browser eq 'netscape') {
	    if ($os eq 'unix') {
		my $lockfile = "$ENV{HOME}/.netscape/lock";
		if (-l $lockfile) {
		    my($host,$pid) = readlink($lockfile) =~ /^(.*):(\d+)$/;
		    # XXX check $host
		    # Check whether Netscape stills lives:
		    if (defined $pid && kill 0 => $pid) {
			if ($args{-oldwindow}) {
			    exec_bg("netscape", "-remote", "openURL($url)");
			} else {
			    exec_bg("netscape", "-remote", "openURL($url,new)");
			}
		        # XXX further options: mailto(to-adresses)
			# XXX check return code?
			return 1;
		    }
		}
		exec_bg("netscape", $url);
		return 1;
	    }
	} elsif ($browser eq '_internal_htmlview') {
	    my $ret = eval {
		htmlview($url);
	    };
	    if ($@) {
		warn $@;
		next;
	    } elsif ($ret) {
		return $ret;
	    }
	} elsif ($browser eq '_debian_browser') {
	    if (-x "/usr/bin/sensible-browser") {
		exec_bg("/usr/bin/sensible-browser", $url);
		return 1;
	    } else {
		if ($ENV{DISPLAY}) {
		    if (-x "/etc/alternatives/gnome-www-browser") { # usually firefox or mozilla
			exec_bg("/etc/alternatives/gnome-www-browser", $url); # use additional args if mozilla, learn args for firefox
			return 1;
		    } elsif (-x "/etc/alternatives/x-www-browser") { # usually dillo
			exec_bg("/etc/alternatives/x-www-browser", $url);
			return 1;
		    }
		} else {
		    if (-x "/etc/alternatives/www-browser") {
			return 1 if open_in_terminal("/etc/alternatives/www-browser", $url, %args);
		    }
		}
	    }
	} else {
	    exec_bg($browser, $url);
	    return 1;
	}
    }

    if ($^O eq 'cygwin') {
	return 1 if start_windows_browser_cygwin($url, %args);
    }

    status_message("Can't find HTML viewer.", "err");

    return 0;
}

sub start_windows_browser_cygwin {
    my($url, %args) = @_;
    system("cmd", "/c", "start", $url);
    if ($? == 0) {
	return 1;
    } else {
	return 0;
    }
}

sub start_browser_windows {
    my($url, %args) = @_;
    my @methods;
    if ($ENV{OS} && $ENV{OS} eq 'Windows_NT') { # NT, 2000, XP, Vista...
	@methods = qw(rundll start win32util explorer);
    } else {
	@methods = qw(win32util start explorer);
    }

    for my $method (@methods) {
        if ($method eq 'rundll') {
	    system("rundll32 url.dll,FileProtocolHandler \"$url\"");
            if ($?/256 == 0) {
	        return 1;
	    }
        } elsif ($method eq 'start') {
	    # XXX There are reports that "start" and Tk programms
	    # do not work well together (slow startup and such).
	    system("start /b \"$url\"");
	    if ($?/256 == 0) {
		return 1;
	    }
	} elsif ($method eq 'explorer') {
	    system("start explorer \"$url\"");
	    # maybe: system("start", "explorer", $url);
	    # or:    system("start explorer \"$url\"");
	    if ($?/256 == 0) {
		return 1;
	    }
	} elsif ($method eq 'win32util' &&
		 eval { require Win32Util; 1 }) {
	    if (eval { Win32Util::start_html_viewer($url) }) {
		return 1;
	    }
	}
    }

    status_message("Can't find HTML viewer.", "err");
    return 0;
}

sub open_in_konqueror {
    my $url = shift;
    my(%args) = @_;
    if (is_in_path("dcop") && is_in_path("konqueror")) {

	# first try old window (if requested)
	if ($args{-oldwindow}) {
	    my $konq_name;
	    foreach my $l (split /\n/, `dcop konqueror KonquerorIface getWindows`) {
		if ($l =~ /(konqueror-mainwindow\#\d+)/) {
		    $konq_name = $1;
		    last;
		}
	    }

	    if (defined $konq_name) {
		system(qw/dcop konqueror/, $konq_name, qw/openURL/, $url);
		return 1 if ($?/256 == 0);
	    }
	}

	# then try to send to running konqueror process:
	system(qw/dcop konqueror KonquerorIface openBrowserWindow/, $url);
	return 1 if ($?/256 == 0);

	# otherwise start a new konqueror
	exec_bg("konqueror", $url);
	return 1; # if ($?/256 == 0);
    }
    0;
}

sub open_in_galeon {
    my $url = shift;
    my(%args) = @_;
    if (is_in_path("galeon")) {

	$url = _guess_and_expand_url($url) if $args{-expandurl};

	# first try old window (if requested)
	if ($args{-oldwindow}) {
	    system("galeon", "-x", $url);
	    return 1 if ($?/256 == 0);
	}

	exec_bg("galeon", "-n", $url);
	return 1 if ($?/256 == 0);
	return 0;
    }
    0;
}

sub _open_in_mozilloid {
    my($cmd, $url, %args) = @_;
    if (is_in_path($cmd)) {
	if ($args{-oldwindow}) {
	    system($cmd, "-remote", "openURL($url)");
	} else {
	    # no new-tab support in older Mozillas (e.g. 1.0)!
	    system($cmd, "-remote", "openURL($url,new-tab)");
	}
	return 1 if ($?/256 == 0);

	# otherwise start a new mozilla process
	exec_bg($cmd, $url);
	return 1; # if ($?/256 == 0);
    }
    0;
}

sub open_in_mozilla {
    _open_in_mozilloid("mozilla", @_);
}

sub open_in_seamonkey {
    _open_in_mozilloid("seamonkey", @_);
}

sub open_in_opera {
    my $url = shift;
    my(%args) = @_;
    if (is_in_path("opera")) {
	if ($args{-oldwindow}) {
	    exec_bg("opera", $url);
	} else {
	    exec_bg("opera", "-newpage", $url);
	}
	return 1; # if ($?/256 == 0);
    }
    0;
}

sub exec_bg {
    my(@cmd) = @_;
    if ($os eq 'unix' || $os eq 'macosx') {
	eval {
	    if (!$fork || fork == 0) {
		exec @cmd;
		warn "Can't exec @cmd: $!";
		if (eval { require POSIX; 1 }) {
		    POSIX::_exit(1);
		} else {
		    CORE::exit(1);
		}
	    }
	};
    } else {
	# XXX use Spawn
	system(join(" ", @cmd) . ($fork ? "&" : ""));
    }
}

sub _get_cmdline_for_url_from_Gnome {
    my($url) = @_;
    (my $url_scheme = $url) =~ s/^([^:]+).*/$1/; # use URI.pm?
    my $curr_section;
    my $default_cmdline;
    my $cmdline;
    if (open(GNOME, "$ENV{HOME}/.gnome/Gnome")) {
	while(<GNOME>) {
	    chomp;
	    if (/^\[(.*)\]/) {
		$curr_section = $1;
	    } elsif (defined $curr_section && $curr_section eq 'URL Handlers' && /^(default|\Q$url_scheme\E)-show=(.*)/) {
		if ($1 eq 'default') {
		    $default_cmdline = $2;
		} else {
		    $cmdline = $2;
		}
	    }
	}
	close GNOME;
    }
    if (!defined $cmdline) {
	$cmdline = $default_cmdline;
    }
    if (!defined $cmdline) {
	die "Can't find command for scheme $url_scheme";
    }
    $cmdline =~ s/%s/$url/g;
    $cmdline;
}

# XXX document get_from_config, $ignore_config, ~/.wwwbrowser
sub get_from_config {
    if (!$ignore_config && $ENV{HOME} && open(CFG, "$ENV{HOME}/.wwwbrowser")) {
	my @browser;
	while(<CFG>) {
	    chomp;
	    next if /^\s*\#/;
	    push @browser, $_;
	}
	close CFG;
	unshift @unix_browsers, @browser;
    }
}

sub _guess_and_expand_url {
    my $url = shift;
    if ($url =~ m|^[a-z]+://|) {
	$url;
    } elsif ($url =~ m|^www|) {
	"http://$url";
    } elsif ($url =~ m|^ftp|) {
	"ftp://$url";
    } else {
	$url;
    }
}

# A port of htmlview to perl.
#
# This may work on linux, but not on *BSD because of different paths.
sub htmlview {
    #!/bin/bash
    #
    # Invoke whatever HTML viewer is installed...
    # Usage:
    #	htmlview [URL]
    #
    # Changes:
    # v2.0.0
    # ------
    # - Allow users to override default settings in
    #   ~/.htmlviewrc and /etc/htmlview.conf.
    #   Users can define X11BROWSER, TEXTBROWSER and
    #   CONSOLE variables to indicate their preferences.
    # - --remote and --local are deprecated, we don't
    #   have any non-browser HTML viewers these days.
    #
    # Christopher Blizzard <blizzard@redhat.com> Aug 09 2002 
    # - prefer mozilla over galeon
    #
    # written by Bernhard Rosenkraenzer <bero@redhat.com>
    # (c) 2000-2002 Red Hat, Inc.
    #
    # This script is in the public domain.

    #XXXunset BROWSER CONSOLE TERMS_KDE TERMS_GNOME TERMS_GENERIC
    #XXX[ -e /etc/htmlview.conf ] && source /etc/htmlview.conf
    #XXX[ -e ~/.htmlviewrc ] && source ~/.htmlviewrc

    return 0 if $^O ne "linux";

    my(@args) = @_;

    my @TERMS_KDE = qw(/usr/bin/konsole /usr/bin/kvt);
    my @TERMS_GNOME = qw(/usr/bin/gnome-terminal);
    my @TERMS_GENERIC = qw(/usr/bin/rxvt /usr/X11R6/bin/xterm /usr/bin/Eterm);
    my @TTYBROWSERS = qw(/usr/bin/links /usr/bin/lynx /usr/bin/w3m);
    my @X11BROWSERS_KDE = qw(/usr/bin/konqueror /usr/bin/kfmbrowser);
    my @X11BROWSERS_GNOME = qw(/usr/bin/mozilla /usr/bin/galeon);
    my @X11BROWSERS_GENERIC = qw(/usr/bin/mozilla /usr/bin/netscape);

    my(@X11BROWSERS, @TERMS);

    my $gnome_is_running;
    if (eval { require Proc::ProcessTable }) {
	require File::Basename;
	for my $p (@{ Proc::ProcessTable->new->table }) {
	    if (File::Basename::basename($p->fname) eq 'gnome-session') {
		$gnome_is_running++;
		last;
	    }
	}
    } elsif (-x "/sbin/pidof") {
	my($out) = `/sbin/pidof gnome-session`;
	$gnome_is_running = $out ? 1 : 0;
    } else {
	warn "Cannot determine whether GNOME is running: neither Proc::ProcessTable nor pidof are available\n";
    }

    if ($gnome_is_running) {
	@X11BROWSERS = (@X11BROWSERS_GENERIC, @X11BROWSERS_GNOME, @X11BROWSERS_KDE);
	@TERMS = (@TERMS_GENERIC, @TERMS_GNOME, @TERMS_KDE);
    } else {
	@X11BROWSERS = (@X11BROWSERS_GENERIC, @X11BROWSERS_KDE, @X11BROWSERS_GNOME);
	@TERMS = (@TERMS_GENERIC, @TERMS_KDE, @TERMS_GNOME);
    }

    if ($ENV{X11BROWSER}) {
	unshift @X11BROWSERS, $ENV{X11BROWSER};
    }
    if ($ENV{TEXTBROWSER}) {
	unshift @TTYBROWSERS, $ENV{TEXTBROWSER};
    }
    if ($ENV{CONSOLE}) {
	unshift @TERMS, $ENV{CONSOLE};
    }

    if ($VERBOSE) {
	require Data::Dumper;
	print STDERR Data::Dumper->new([\@X11BROWSERS, \@TTYBROWSERS, \@TERMS],
				       [qw(X11BROWSERS TTYBROWSERS TERMS)])
	    ->Indent(1)->Useqq(1)->Dump;
    }

 TRY: {
	if (!defined $ENV{DISPLAY} || $ENV{DISPLAY} eq "") {
	    for my $ttybrowser (@TTYBROWSERS) {
		if (is_in_path($ttybrowser)) {
		    system($ttybrowser, @args); # blocks in tty mode
		    last TRY;
		}
	    }

	    die "No valid text mode browser found.\n";
	} else {
	    for my $x11browser (@X11BROWSERS) {
		if (is_in_path($x11browser)) {
		    exec_bg($x11browser, @args);
		    last TRY;
		}
	    }

	    my @console;
	    for my $term (@TERMS) {
		if (is_in_path($term)) {
		    @console = ($term, "-e");
		    last;
		}
	    }

	    if (!@console) {
		die "No CONSOLE found.\n";
	    }

	    for my $ttybrowser (@TTYBROWSERS) {
		if (is_in_path($ttybrowser)) {
		    exec_bg(@console, $ttybrowser, @args);
		    last TRY;
		}
	    }
	}

	die "No valid browser found.\n";
    }

    return 1;
}

sub open_in_terminal {
    my($browser, $url, %args) = @_;

    if (defined $ENV{DISPLAY} && $ENV{DISPLAY} ne "") {
	foreach my $term (@terminals) {
	    if (is_in_path($term)) {
		exec_bg($term,
			($term eq 'gnome_terminal' ? '-x' : '-e'),
			$browser, $url);
		return 1;
	    }
	}
    } else {
	# without X11: not in background!
	system($browser, $url);
	return 1;
    }
    0;
}

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 89d0fdf16d11771f0f6e82c7d0ebf3a8
BEGIN {
    if (eval { require File::Spec; defined &File::Spec::file_name_is_absolute }) {
	*file_name_is_absolute = \&File::Spec::file_name_is_absolute;
    } else {
	*file_name_is_absolute = sub {
	    my $file = shift;
	    my $r;
	    if ($^O eq 'MSWin32') {
		$r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	    } else {
		$r = ($file =~ m|^/|);
	    }
	    $r;
	};
    }
}
# REPO END

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 81c0124cc2f424c6acc9713c27b9a484
sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -f $prog and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    # maybe use $ENV{PATHEXT} like maybe_command in ExtUtils/MM_Win32.pm?
	    return "$_\\$prog"
		if (-x "$_\\$prog.bat" ||
		    -x "$_\\$prog.com" ||
		    -x "$_\\$prog.exe" ||
		    -x "$_\\$prog.cmd");
	} else {
	    return "$_/$prog" if (-x "$_/$prog" && !-d "$_/$prog");
	}
    }
    undef;
}
# REPO END

# XXX Forward compatibility
{
    package Launcher::WWW;
    sub launch {
	WWWBrowser::start_browser(@_);
    }
}

1;

__END__

=head1 NAME

WWWBrowser - platform independent mean to start a WWW browser

=head1 SYNOPSIS

    use WWWBrowser;
    WWWBrowser::start_browser($url, -oldwindow => 1);

=head1 DESCRIPTION

=head2 start_browser($url [, %args])

Start a web browser with the specified URL. The process is started in
background.

The following optional parameters are recognized:

=over 4

=item -oldwindow => $bool

Normally, the URL is loaded into a new window, if possible. With
C<-oldwindow> set to a false window, C<WWWBrowser> will try to re-use
a browser window.

=item -browser => $browser

Use (preferebly) the named browser C<$browser>. See L</CONFIGURATION>
for a some browser specialities. This option will only work for unix.

=back

=head1 CONFIGURATION

For unix, the global variable C<@WWWBrowser::unix_browsers> can be set
to a list of preferred web browsers. The following browsers are
handled specially:

=over 4

=item lynx, w3m

Text oriented browsers, which are opened in an C<xterm>, C<kvt> or
C<gnome-terminal> (if running under X11). If not running under X11,
then no background process is started.

=item kfmclient

Use C<openURL> method of kfm.

=item netscape

Use C<-remote> option to re-use a running netscape process, if
possible.

=item _default_gnome

Look into the C<~/.gnome/Gnome> configuration file for the right browser.

=item _default_kde

NYI.

=back

The following variables can be defined globally in the B<main>
package:

=over 4

=item C<$os>

Short name of operating system (C<win>, C<mac>, C<macosx> or C<unix>).

=item C<&status_messages>

Error handling function (instead of default C<warn>).

=back

=head1 REQUIREMENTS

For Windows, the L<Win32Util|Win32Util> module should be installed in
the path.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=head1 COPYRIGHT

Copyright (C) 1999,2000,2001,2003,2005,2006,2007,2008 Slaven Rezic.
All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Win32Util>.

=cut
