# -*- perl -*-

#
# $Id: Msg.pm,v 1.9 2009/09/20 19:36:29 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2003,2008,2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Msg;
use strict;
use FindBin;
use File::Basename;

use vars qw($messages $lang $lang_messages $VERSION @EXPORT @EXPORT_OK
	    $caller_file $frommain $noautosetup $DEBUG);
use base qw(Exporter);
@EXPORT = qw(M Mfmt);
@EXPORT_OK = qw(frommain noautosetup);

$VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

BEGIN {
    if ($ENV{PERL_MSG_DEBUG}) {
	$DEBUG = 1;
    }
}

# XXX this is obfuscated... try something better
CALLER_FILE: {
    if (!$frommain) {
	my $caller_file_i = 0;
	do {
	    $caller_file = (caller($caller_file_i))[1];
	    last CALLER_FILE if ($caller_file !~ m,(^\(eval \d+\)|/Msg\.pm)$,);
	    if (!defined $caller_file_i) {
		$caller_file_i = 0;
	    } else {
		$caller_file_i++;
	    }
	} while (defined $caller_file);
    }
}
if (!defined $caller_file || -l $caller_file) {
    $caller_file = "$FindBin::RealBin/$FindBin::RealScript";
}
$caller_file =~ s/\.(pl|PL|plx|cgi)$//g; # strip extension

if ($DEBUG) {
    warn "caller_file is $caller_file\n";
}

# Stolen from CGI::Carp
sub import {
    my $pkg = shift;
    my(%routines);
    grep($routines{$_}++,@_,@EXPORT);
    $frommain++ if $routines{'frommain'};
    $noautosetup++ if $routines{'noautosetup'};
    my($oldlevel) = $Exporter::ExportLevel;
    $Exporter::ExportLevel = 1;
    Exporter::import($pkg,keys %routines);
    $Exporter::ExportLevel = $oldlevel;
}

=head2 setup_file([$dir, [$lang]])

This is called automatically on using the Msg module. The defaults
(base directory containing the message files and the current language)
can be overwritten. The current language is determined by either the
LC_ALL, LC_MESSAGES, or LANG environment variables (in this order). A
value of "C" or "POSIX" is ignored. [XXX yet unspecified for Win32?].

=cut

sub setup_file (;$$) {
    my $default_dir = dirname($caller_file) . "/msg/" . basename($caller_file);
    # Argument handling
    my $base = shift || $default_dir; #$FindBin::RealBin . "/msg/";

    $lang = get_lang();

    require Safe;
    my $safe = Safe->new;
    $safe->share(qw($lang_messages));

    %$messages = ();

 TRY: {
	my @candidates = ("$base/$lang");
	foreach my $f (@candidates) {
	    if ($DEBUG) {
		warn "Try candidate message file $f...\n";
	    }
	    if (-r $f && -f $f) {
		$safe->rdo($f);
		if (ref $lang_messages) {
		    $messages = $lang_messages;
		    if ($DEBUG) {
			warn "... success!\n";
		    }
		    last TRY;
		}
	    }
	}

	#warn "Can't find any message file of @candidates\n";
    }
    $messages;
}

sub get_lang {
    my $lang;
    my %ignore = (C => 1, POSIX => 1);
    for my $env (qw(LC_ALL LC_MESSAGES LANG)) {
	if (exists $ENV{$env} && !$ignore{$ENV{$env}}) {
	    $lang = $ENV{$env};
	    last;
	}
    }
    if (!defined $lang) {
	$lang = "";
    } else {
	# normalize language
	$lang =~ s/^([^_.-]+).*/$1/; # XXX better use I18N::LangTags
    }
    if ($DEBUG) {
	warn "Use language $lang\n";
    }
    $lang;
}

=head2 M($msg)

Return a language dependent version of $msg.

=cut

sub M ($) {
    if (exists $messages->{$_[0]}) {
	$messages->{$_[0]};
    } else {
	$_[0];
    }
}

sub Mfmt {
    sprintf M(shift), @_;
}

setup_file() unless $noautosetup;

1;

__END__
