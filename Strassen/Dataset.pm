# -*- perl -*-

#
# $Id: Dataset.pm,v 1.10 2004/03/22 23:48:20 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::Dataset;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

use vars qw(%file %net %crossings %obj @comments_types);

# XXX don't hardcode for Berlin!
%file =
    ('str' =>
     {
      's'  => ['strassen',	"landstrassen",		"landstrassen2"],
      'u'  => ['ubahn',		undef,			undef],
      'b'  => ['sbahn',		'sbahn',		undef],
      'r'  =>  'rbahn',
      'w'  => ['wasserstrassen','wasserumland',		'wasserumland2'],
      'f'  =>  'flaechen',
      'v'  =>  'sehenswuerdigkeit',
      'z'  => ['plz',		undef,			undef],
      'g'  => ['berlin',	undef,			undef],
      'e'  =>  'faehren',
#XXX maybe change radwege_exact=>radwege and radwege=>radwege_display?
      'rw' => ['radwege_exact',	undef,			undef],
      'q'  => ['qualitaet_s',	'qualitaet_l',		'qualitaet_l'],
      'h'  => ['handicap_s',	'handicap_l',		'handicap_l'],
      'nl' => ['nolighting',	undef,			undef],
      'comm' => 'comments',
     },
     'p' =>
     {
      'lsa'    => ['ampeln',	undef,		undef],
      'u'      => ['ubahnhof',	undef,		undef],
      'b'      => ['sbahnhof',	'sbahnhof',	undef],
      'r'      =>  'rbahnhof',
      'o'      => [undef,	'orte',		'orte2'],
      'sperre' =>  'gesperrt',
      'obst'   =>  'obst',
      'pl'     => ['plaetze',	undef,		undef],
      'vf'     =>  'vorfahrt',
      'kn'     => ['kneipen',	undef,		undef],
      'ki'     => ['kinos',	undef,		undef],
      'rest'   => ['restaurants',undef,		undef],
      'hoehe'  =>  'hoehe',
     },
    );

@comments_types = qw(cyclepath ferry misc mount path route tram kfzverkehr);

my %scope2inx = (city   => 0,
		 region => 1,
		 wideregion => 2,
		);

sub file { \%file }

sub datadir { () }

sub Strassen_Module      { "Strassen::Core" }
sub Strassen_Class       { "Strassen" }
sub MultiStrassen_Module { "Strassen::MultiStrassen" }
sub MultiStrassen_Class  { "MultiStrassen" }

# XXX in the future this will do something sensible like using a
# specific directory or similar
sub new { bless {}, $_[0] }

=item get($linetype, $type, $scoperef, %args)

C<$linetype> is either C<str> for streets or C<p> for points. For
C<$type> see above in the source code. C<$scoperef> is either C<city>,
C<region> or C<wideregion>. Additional args may be: C<-cache> (set to
false if you do not want to use the internal cache).

=cut

sub get {
    my($self, $linetype, $type, $scoperef, %args) = @_;
    $scoperef = _normalize_scoperef($scoperef);
    my $key = "$linetype-$type-" . join("-", @$scoperef);
    if ($obj{$key} && !(defined $args{-cache} && !$args{-cache})) {
	return $obj{$key};
    }
    if (@$scoperef == 0) {
	warn "No scopes given";
	return undef;
    }
    my $obj;
    my @type_files;

    if (@$scoperef == 1) {
	eval q{ require } . $self->Strassen_Module;
	die $@ if $@;
    } else {
	eval q{ require } . $self->MultiStrassen_Module;
	die $@ if $@;
    }

    local @Strassen::datadirs = @Strassen::datadirs;
    my @new_datadirs = $self->datadir;
    if (@new_datadirs) {
	@Strassen::datadirs = @new_datadirs;
    }

    my $file = $self->file;
    if (UNIVERSAL::isa($file->{$linetype}{$type}, "ARRAY")) {
	@type_files = @{ $file->{$linetype}{$type} };
    } else {
	@type_files = map { $file->{$linetype}{$type} } (0..2);
    }
    if (@$scoperef == 1) {
	my $filename = $type_files[$scope2inx{$scoperef->[0]}];
	if (!defined $filename) {
	    die "No filename for linetype=$linetype, type=$type, scope=@$scoperef defined";
	}
	$obj = $self->Strassen_Class->new($filename);
    } else {
	my @filenames = grep { defined $_ } @type_files[map { $scope2inx{$_} } @$scoperef];
	if (!@filenames) {
	    die "No filenames for linetype=$linetype, type=$type, scopes=@$scoperef defined";
	}
	$obj = $self->MultiStrassen_Class->new(@filenames);
    }

    # Add Inaccessible member to strassen only
    # XXX Shouldn't be hardcoded
    if ($linetype eq 'str' && $type eq 's') {
	my $inacc_str;
	eval {
	    $inacc_str = $self->Strassen_Class->new("inaccessible_strassen");
	    $obj->{Inaccessible} = $inacc_str;
	};
    }

    if ($obj) {
	$obj{$key} = $obj;
    }
    $obj;
}

=item get_net($linetype, $type, $scoperef, %args)

See the C<get> method for a description of C<$linetype>, C<$type>, and
C<$scoperef>. Additional arguments may be: C<-cache>, C<-makenetargs>
(passed to the underlying C<make_net> method call), and C<-nettype>
(the specific type of the net, e.g. C<cat> for a net by category).

=cut

sub get_net {
    my($self, $linetype, $type, $scoperef, %args) = @_;
    $scoperef = _normalize_scoperef($scoperef);
    my $nettype = $args{-nettype} || "std";
    my $key = "$linetype-$type-$nettype-" . join("-", @$scoperef);
    if ($net{$key} && !(defined $args{-cache} && !$args{-cache})) {
	return $net{$key};
    }
    my $obj = $self->get($linetype, $type, $scoperef, %args);
    require Strassen::StrassenNetz;
    my $net = StrassenNetz->new($obj);
    my @args = $args{-makenetargs} ? @{$args{-makenetargs}} : ();
    if ($nettype eq 'std') {
	$net->make_net(@args);
    } elsif ($nettype eq 'cat') {
	$net->make_net_cat(@args);
    } else {
	die "NYI: make net for net type $nettype";
    }
    $net{$key} = $net;
    $net;
}

=item get_crossings($linetype, $type, $scoperef, %args)

See the C<get> method for a description of C<$linetype>, C<$type>, and
C<$scoperef>. Additional arguments may be: C<-cache>,
C<-makecrossingsargs> (passed to the underlying C<all_crossings>
method call), and C<-crossingstype> (the specific type of the
crossings hash, e.g. C<hashpos>).

=cut

sub get_crossings {
    my($self, $linetype, $type, $scoperef, %args) = @_;
    $scoperef = _normalize_scoperef($scoperef);
    my $crossingstype = $args{-crossingstype} || "hash";
    my $key = "$linetype-$type-$crossingstype-" . join("-", @$scoperef);
    if ($crossings{$key} && !(defined $args{-cache} && !$args{-cache})) {
	return $crossings{$key};
    }
    my @args = $args{-makecrossingsargs} ? @{$args{-makecrossingsargs}} : ();
    my $s = $self->get($linetype, $type, $scoperef);
    require Strassen::Kreuzungen;
    my $crossings = Kreuzungen->new(UseCache => 1, # XXX
				    Strassen => $s,
				    # XXX WantPos
				   );
    $crossings{$key} = $crossings;
    $crossings;
}

sub _normalize_scoperef {
    my $scoperef = shift;
    if (!UNIVERSAL::isa($scoperef, "ARRAY")) {
	$scoperef = [$scoperef];
    }
    for(my $i = 0; $i <= $#{$scoperef}; $i++) {
	if ($scoperef->[$i] eq 'all') {
	    return [qw(city region wideregion)];
	} elsif ($scoperef->[$i] eq 'jwd') { # an old alias
	    $scoperef->[$i] = "wideregion";
	}
    }
    @$scoperef = sort @$scoperef;
    $scoperef;
}

1;

__END__
