# -*- perl -*-

#
# $Id: Enscript.pm,v 1.11 2009/10/24 20:16:31 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998,2007 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.sourceforge.net/projects/srezic
#

package Tk::Enscript;
use Tk;
use Text::Tabs;
require Exporter;

use strict;
use vars qw(%media %postscript_to_x11_font
	    $VERSION @ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(enscript);

$VERSION = sprintf "%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/;

parse_cfg();

sub enscript {
    my($top, %args) = @_;

    my $external = $args{-external};

    if (!$args{'-columns'}) {
	$args{'-columns'} = 1;
    }

    if (defined $external and $external eq 'best') {
	if (_is_in_path("enscript")) {
	    $external = "enscript";
	} elsif (_is_in_path("a2ps")) {
	    $external = "a2ps";
	} else {
	    undef $external;
	}
    }
    if (defined $external) {
	if ($external eq 'enscript') {
	    return ext_enscript(%args);
	} elsif ($external eq 'a2ps') {
	    return ext_a2ps(%args);
	} else {
	    die "Unknown external program $external";
	}
    }

    my $fontname = $args{-font};
    my $output   = $args{-output} || "/tmp/enscript.%d.ps";
    my $filename = $args{-file};
    my $text     = $args{-text};

    my $media    = $args{-media} || 'A4';
    die "Unknown media $media" if !exists $media{$media};
    my %media_desc = %{$media{$media}};

    my $width  = $args{-width}  || $media_desc{Width};
    my $height = $args{-height} || $media_desc{Height};

    my $t = $top->Toplevel;
    my $c = $t->Canvas(-width => $width, -height => $height);
    $t->withdraw;

    my($llx, $lly, $urx, $ury);
    ($llx, $lly, $urx, $ury) = @{$args{-bbox}} if exists $args{-bbox};

    $llx = $args{-llx} || $media_desc{LLX};
    $lly = $args{-lly} || $media_desc{LLY};
    $urx = $args{-urx} || $media_desc{URX};
    $ury = $args{-ury} || $media_desc{URY};

    my $uly = $height - $ury;	# XXX unsure
    my $lry = $height - $lly;

    my $y = $uly;

    my $font = x11_font_to_tk_font($t, postscript_to_x11_font($fontname || 'Courier12'));

    my $page = 0;
    my $line;

    my $ps_output_sub = sub {
	$c->update;
	$c->postscript(-file => sprintf($output, $page),
		       -pagewidth => $width,
		       -pageheight => $height,
		       -width => $width,
		       -height => $height);
	$y = $uly;
	$page++;
	$c->delete('all');
    };

    if (defined $filename) {
	$text = _read_file($filename);
    }

    my $try_again = 0;
    foreach $line (split(/\n/, $text)) {
	$line = expand($line);
	my $i;
	my @text_args = ($llx, $y,
			 -width => $urx-$llx,
			 -text => $line, -anchor => 'nw',
			);
	eval {
	    $i = $c->createText(@text_args,
				-font => $font,
			       );
	};
	warn $@ if $@;
	if (!defined $i) {
	    warn "Can't get font <$font>, fallback to default font.\n";
	    $i = $c->createText(@text_args);
	}
	$y = ($c->bbox($i))[3];
	if ($y > $lry && !$try_again) {
	    $c->delete($i);
	    $ps_output_sub->();
	    $try_again++;
	    redo;
	}
	$try_again = 0;
    }

    $ps_output_sub->();
    $c->destroy;

    ($output, $page-1);		# gibt Output-Dateiname und Anzahl der Seiten zurück
}

sub _read_file {
    my $filename = shift;
    my $text;
    open(F, $filename) or die "Can't open $filename: $!";
    local($/) = undef;
    $text = <F>;
    close F;
    $text;
}

sub parse_cfg {
    my $cfg_file = shift;
    my @cfg_files = (Tk->findINC('enscript.cfg'));
    if (!defined $cfg_file) {
	my $home_dir = eval { local $SIG{__DIE__};
			      (getpwuid($<))[7];
			  } || $ENV{'HOME'} || '';
	my $pers_cfg_file = "$home_dir/.enscriptrc";
	if (-f $pers_cfg_file && -r $pers_cfg_file) {
	    $cfg_file = $pers_cfg_file;
	}
    }
    if (defined $cfg_file) {
	push @cfg_files, $cfg_file;
    }
    if (!@cfg_files) {
	die "Can't found any configuration enscript.cfg.";
    }

    %media = ();
    %postscript_to_x11_font = ();

    for my $cfg_file (@cfg_files) {
	open(CFG, $cfg_file)
	    or die "Can't open config file <$cfg_file>: $!";
	while(<CFG>) {
	    s/\s*\#.*//;
	    next if /^\s*$/;
	    if (/^\s*Media:\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
		$media{$1} = {Width  => $2,
			      Height => $3,
			      LLX    => $4,
			      LLY    => $5,
			      URX    => $6,
			      URY    => $7};
	    } elsif (/^\s*FontMap:\s*(\S+)\s+(.*)/) {
		$postscript_to_x11_font{$1} = $2;
	    } else {
		#warn "Can't parse $_";
	    }
	}
	close CFG;
    }
}

sub postscript_to_x11_font {
    my($psfont) = @_;
    my $x11font;
    if ($psfont !~ /^(.*?)(\d+)?$/) {
	die "Can't parse postscript font $psfont";
    }
    my($font, $size) = (lc($1), $2);
    if (!defined $size) { $size = 10 }
    my $x11font_fmt = $postscript_to_x11_font{$font};
    if (!defined $x11font_fmt) {
	die "No X11 font for $font defined";
    }
    $x11font = sprintf($x11font_fmt, $size*10);
    $x11font;
}

sub x11_font_to_tk_font {
    my($t, $x11font) = @_;

    my $Font;
    if ($Tk::VERSION >= 800.012) {
	require Tk::X11Font;
	$Font = 'Tk::X11Font';
    } else {
	require Tk::Font;
	$Font = 'Tk::Font';
    }

    my $font = new $Font($t, $x11font);

    $font;
}

sub ext_enscript {
    my(%args) = @_;
    my @cmd = ("enscript");
    if ($args{'-columns'}) {
	push @cmd, "--columns", $args{'-columns'};
    }
    if ($args{'-header'}) {
	push @cmd, "--header", $args{'-header'};
    }
    if ($args{'-font'}) {
	push @cmd, "--font", $args{'-font'};
    }
    if ($args{'-output'}) {
	push @cmd, "--output", $args{'-output'};
    }
    print STDERR "Cmd: " . join(" ", @cmd) . "\n" if $args{-verbose};
    if ($args{'-file'}) {
	system(@cmd, $args{'-file'});
    } else {
	require IO::Pipe;
	my $pipe = IO::Pipe->new;
	$pipe->writer(@cmd);
	$pipe->print($args{'-text'});
	$pipe->close;
    }
    ($args{'-output'}, 1);
}

sub ext_a2ps {
    my(%args) = @_;

    die "Sorry, a2ps is not supported anymore\n";

    my @cmd = ("a2ps", #"-8",
	       "--output=-");
    if ($args{'-columns'} =~ /^[12]$/) {
	push @cmd, "--columns=" . $args{'-columns'};
    }
    if ($args{'-font'} and $args{'-font'} =~ /(\d+)$/) {
	push @cmd, "--font-size=". $1;
    }
    if ($args{'-header'}) {
	push @cmd, "--header=".$args{'-header'};
    } else {
	push @cmd, "--no-header";
    }
    # "-nP" würde ich auch gerne setzen, existiert aber nicht?!
#XXX?    push @cmd, "-ns", "-nu", "-nL";

    my $tmpfile;
    if (!$args{'-file'}) {
	$tmpfile = "/tmp/tkenscript-a2ps.$$.txt"; # XXX better solution?
	open(TMP, ">$tmpfile")
	  or die "Can't write to tempory file $tmpfile: $!";
	print TMP $args{'-text'};
	close TMP;
	$args{'-file'} = $tmpfile;
    }
    push @cmd, $args{'-file'};
    require IO::Pipe;
    my $pipe = IO::Pipe->new;
    print STDERR "Cmd: " . join(" ", @cmd) . "\n" if $args{-verbose};
    $pipe->reader(@cmd);
    open(OUT, ">$args{-output}") or die "Can't write to $args{-output}: $!";
    while(<$pipe>) {
	print OUT $_;
    }
    close OUT;
    $pipe->close;

    unlink $tmpfile if defined $tmpfile;

    ($args{'-output'}, 1);
}

sub _is_in_path {
    my($prog) = @_;
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	return $_ if -x "$_/$prog";
    }
    undef;
}

1;

=head1 NAME

Tk::Enscript - a text-to-postscript converter using Tk::Canvas

=head1 SYNOPSIS

    use Tk::Enscript;

    enscript($top,
	     -text   => $text,
	     -media  => 'A4',
	     -output => "/tmp/bla.%d.ps",
    );

=head1 DESCRIPTION

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 COPYRIGHT

Copyright (c) 1998 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<enscript(1)>, L<a2ps(1)>, L<Tk::Canvas>

=cut

