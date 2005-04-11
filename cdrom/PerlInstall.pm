# -*- perl -*-

#
# $Id: PerlInstall.pm,v 1.1 1999/09/30 22:37:47 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package PerlInstall;
use Config;
use ExtUtils::Packlist;
use File::Spec;
use File::Find qw(find);
use strict;

sub new {
    my $self = {};
    bless $self, $_[0];
    foreach (qw(executable exe_shlibs)) {
	my $meth = "get_" . $_;
	$self->$meth();
    }
    $self;
}

sub get_executable {
    my $self = shift;
    my $exe = $^X;
    if (!File::Spec->file_name_is_absolute($exe)) {
	chomp($exe = `which $exe`);
    }
    $self->{Executable} = $exe;
}

sub get_exe_shlibs {
    my $self = shift;
    if ($^O =~ /(freebsd|linux)/i) {
	$self->_ldd_output;
    } else {
	$self->{ShLib} = []; # XXX
    }
}

sub get_std_perl_libs {
    my $self = shift;
    $self->{FindFiles} = {};
    find(sub { _wanted($self) }, $Config{'installprivlib'});
    find(sub { _wanted($self) }, $Config{'installarchlib'});
    @{ $self->{StdLibs} } = keys %{ $self->{FindFiles} };
}

sub get_custom_perl_libs {
    my($self, $mod) = @_;
    my(@mod);
    if (ref $mod eq 'ARRAY') {
	@mod = @$mod;
    } else {
	@mod = $mod;
    }
    $self->{CustomLibs} = [] if !ref $self->{CustomLibs};
    foreach $mod (@mod) {
	(my $modpath = $mod) =~ s|::|/|g;

	my $pl;
	my $plf = "$Config{'installsitearch'}/auto/$modpath/.packlist";
	if (-f $plf) {
	    $pl = new ExtUtils::Packlist $plf;
	} else {
	    $plf = "$Config{'installsitelib'}/auto/$modpath/.packlist";
	    if (-f $plf) {
		$pl = new ExtUtils::Packlist $plf;
	    }
	}

	if (!$pl) {
	    warn "No packlist for $mod found\n";
	} else {
	    push @{ $self->{CustomLibs} }, keys %{ $pl };
	}
    }
}

sub _ldd_output {
    my $self = shift;
    $self->{ShLib} = [];
    open(LDD, "ldd $self->{Executable}|");
    while(<LDD>) {
	if (/=>\s+(\S+)/) {
	    push @{ $self->{ShLib} }, $1;
	}
    }
    close LDD;
}

sub _wanted {
    my $self = shift;
    if (-f $_) {
	$self->{FindFiles}{$File::Find::name} = 1;
    }
}

sub set_assignment {
    my($self, $assign_def) = @_;
    $self->{AssignmentDef} = $assign_def;
}

sub translate_path {
    my($self, $file, $warn) = @_;
    for(my $i=0; $i<$#{ $self->{AssignmentDef} }; $i+=2) {
	my $from = $self->{AssignmentDef}[$i];
	my $to   = $self->{AssignmentDef}[$i+1];
	if ($file =~ /$from/) {
	    #warn "$file from $from to $to";
	    $file =~ s/$from/$to/;
	    return $file;
	}
    }
    if ($warn) {
	warn "Untranslated: $file\n";
    }
    undef;
}

1;

__END__
